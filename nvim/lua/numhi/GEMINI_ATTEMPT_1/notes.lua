-- ~/.config/nvim/lua/numhi/notes.lua

local api = vim.api
local fn = vim.fn
local utils = require("numhi.utils")

local N = {}

-- References to core module's state and config (will be set by core.setup_notes_module)
local M_CORE_STATE = nil
local M_CORE_SAVE_FN = nil
local M_CORE_ADD_HISTORY_FN = nil

-- To keep track of the currently open note window, if any
local active_note_window_info = {
  winid = nil,
  bufnr = nil,
  highlight_uuid = nil,
  original_note_content = "", -- To check for changes
}

--- Initializes this notes module with references from core.
function N.initialize(core_state_ref, core_save_data_fn_ref, core_add_history_fn_ref)
  M_CORE_STATE = core_state_ref
  M_CORE_SAVE_FN = core_save_data_fn_ref
  M_CORE_ADD_HISTORY_FN = core_add_history_fn_ref
end

--- Saves the note content from the active note buffer and closes the window.
local function save_and_close_note_window()
  if not active_note_window_info.winid or not api.nvim_win_is_valid(active_note_window_info.winid) then
    active_note_window_info = {} -- Clear stale info
    return
  end

  local bufnr = active_note_window_info.bufnr
  local highlight_uuid = active_note_window_info.highlight_uuid

  local current_content_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_content_str = table.concat(current_content_lines, "\n")

  -- Only save if content changed or if it's a new note without an ID yet
  local buffer_key = utils.get_buffer_storage_key(api.nvim_get_current_buf()) -- Assuming current buf is where highlight is
  if not buffer_key or not M_CORE_STATE.highlights_by_buffer[buffer_key] or not M_CORE_STATE.highlights_by_buffer[buffer_key][highlight_uuid] then
      utils.notify_message("NumHi: Could not find original highlight to save note against.", vim.log.levels.ERROR)
      api.nvim_win_close(active_note_window_info.winid, true) -- Force close, don't save
      active_note_window_info = {}
      return
  end
  
  local hl_obj = M_CORE_STATE.highlights_by_buffer[buffer_key][highlight_uuid]
  local existing_note_id = hl_obj and hl_obj.note_id

  if current_content_str ~= active_note_window_info.original_note_content or not existing_note_id then
    local note_id_to_use = existing_note_id
    local ts = os.time()
    local new_note_obj

    if note_id_to_use and M_CORE_STATE.notes_by_id[note_id_to_use] then -- Update existing note
      M_CORE_STATE.notes_by_id[note_id_to_use].content = current_content_str
      M_CORE_STATE.notes_by_id[note_id_to_use].updated_at = ts
      new_note_obj = M_CORE_STATE.notes_by_id[note_id_to_use]
      M_CORE_ADD_HISTORY_FN({
        action = "update_note",
        note_uuid = note_id_to_use,
        data_before = { content = active_note_window_info.original_note_content },
        data_after = { content = current_content_str }
      })
    else -- Create new note
      note_id_to_use = utils.uuid()
      new_note_obj = {
        uuid = note_id_to_use,
        content = current_content_str,
        created_at = ts,
        updated_at = ts,
        highlight_uuid = highlight_uuid, -- Link back to the highlight
      }
      M_CORE_STATE.notes_by_id[note_id_to_use] = new_note_obj
      hl_obj.note_id = note_id_to_use -- Link highlight to this new note
      M_CORE_ADD_HISTORY_FN({action = "create_note", note_uuid = note_id_to_use, data = new_note_obj})
    end
    hl_obj.updated_at = ts


    -- Extract tags from note content
    local new_tags = {}
    for _, line in ipairs(current_content_lines) do
      for tag in line:gmatch("#([%w_%-]+)") do -- Allow hyphens and underscores in tags
        table.insert(new_tags, tag)
      end
    end
    hl_obj.tags = new_tags -- Replace existing tags with those from the note

    M_CORE_SAVE_FN() -- This function should save both highlights and notes
    utils.echo_message("NumHi: Note saved.", "MoreMsg")
  end

  if api.nvim_win_is_valid(active_note_window_info.winid) then
    api.nvim_win_close(active_note_window_info.winid, true) -- True to force close scratch buffer
  end
  active_note_window_info = {} -- Clear
end

--- Opens a floating window to edit a note for a given highlight.
---@param highlight_obj table The highlight object from core's state.
---@param buffer_key string The storage key for the buffer containing the highlight.
function N.edit_note_for_highlight(highlight_obj, buffer_key)
  if not M_CORE_STATE or not M_CORE_SAVE_FN then
    utils.notify_message("NumHi Notes module not initialized by Core.", vim.log.levels.ERROR)
    return
  end

  if active_note_window_info.winid and api.nvim_win_is_valid(active_note_window_info.winid) then
    -- If trying to open for the same highlight, focus it. Otherwise, close old and open new.
    if active_note_window_info.highlight_uuid == highlight_obj.uuid then
      api.nvim_set_current_win(active_note_window_info.winid)
      return
    else
      api.nvim_win_close(active_note_window_info.winid, true) -- force close previous
      active_note_window_info = {}
    end
  end

  local note_id = highlight_obj.note_id
  local note_content = ""
  if note_id and M_CORE_STATE.notes_by_id[note_id] then
    note_content = M_CORE_STATE.notes_by_id[note_id].content
  end
  active_note_window_info.original_note_content = note_content

  local note_bufnr = api.nvim_create_buf(false, true) -- false=not listed, true=scratch
  api.nvim_buf_set_option(note_bufnr, "buftype", "acwrite")
  api.nvim_buf_set_option(note_bufnr, "bufhidden", "wipe")
  api.nvim_buf_set_option(note_bufnr, "swapfile", false)
  api.nvim_buf_set_option(note_bufnr, "filetype", "markdown")
  local category_label = (M_CORE_STATE.category_labels[highlight_obj.palette_id] and
                          M_CORE_STATE.category_labels[highlight_obj.palette_id][highlight_obj.slot]) or ""
  api.nvim_buf_set_name(note_bufnr, string.format("NumHiNote://%s/%s-%d%s",
      highlight_obj.uuid:sub(1,8), highlight_obj.palette_id, highlight_obj.slot,
      category_label ~= "" and ("-" .. category_label) or ""))

  if note_content ~= "" then
    api.nvim_buf_set_lines(note_bufnr, 0, -1, false, vim.split(note_content, "\n", {plain = true, trimempty = false}))
  end

  -- Window dimensions and positioning
  local width = math.floor(vim.o.columns * M_CORE_STATE.plugin_config.note_window_width_ratio)
  local height = math.floor(vim.o.lines * M_CORE_STATE.plugin_config.note_window_height_ratio)

  -- Position relative to the highlight's end line in the main window
  -- Ensure the main window (window 0 assumed for now) is the one with the highlight
  local main_winid =储存光标位置的窗口 or api.nvim_get_current_win() -- Use current window as reference
  local highlight_end_screenpos = api.nvim_win_text_height({
      window = main_winid,
      start_line = 0, -- Not directly used by text_height, but it needs a table
      end_line = highlight_obj.end_line,
      text_width = vim.api.nvim_win_get_width(main_winid) -- approximate
  })
  
  local win_cfg = {
    relative = "win",
    win = main_winid, 
    -- Try to position below the highlight. end_line is 0-indexed.
    row = math.min(highlight_obj.end_line + 1, api.nvim_win_get_height(main_winid) - height -1),
    col = math.floor((api.nvim_win_get_width(main_winid) - width) / 2), -- Centered horizontally
    width = width,
    height = height,
    style = "minimal",
    border = M_CORE_STATE.plugin_config.note_border,
    title = string.format("Note: %s-%d %s", highlight_obj.palette_id, highlight_obj.slot, category_label),
    title_pos = "center",
    zindex = 150, -- Higher than default extmark priority
  }
  
  -- Adjust if window would go off screen
  if win_cfg.row + height >= api.nvim_win_get_height(main_winid) then
      win_cfg.row = math.max(0, highlight_obj.start_line - height -1) -- Try above highlight
  end
  if win_cfg.row < 0 then win_cfg.row = 0 end -- Clamp to top
  if win_cfg.col < 0 then win_cfg.col = 0 end -- Clamp to left

  local note_winid = api.nvim_open_win(note_bufnr, true, win_cfg) -- true to enter
  api.nvim_win_set_option(note_winid, "winhl", "Normal:NumHiNoteBackground,FloatBorder:NumHiNoteBorder")
  -- Define NumHiNoteBackground and NumHiNoteBorder if custom styling is needed
  if fn.hlexists("NumHiNoteBackground") == 0 then
      api.nvim_set_hl(0, "NumHiNoteBackground", {bg = fn.hlexists("NormalFloat") > 0 and fn.synIDattr(fn.synIDtrans(fn.hlID("NormalFloat")), "bg#") or "#2E3440",
                                                 fg = fn.hlexists("NormalFloat") > 0 and fn.synIDattr(fn.synIDtrans(fn.hlID("NormalFloat")), "fg#") or "#D8DEE9"})
  end
   if fn.hlexists("NumHiNoteBorder") == 0 then
      api.nvim_set_hl(0, "NumHiNoteBorder", {fg = fn.hlexists("FloatBorder") > 0 and fn.synIDattr(fn.synIDtrans(fn.hlID("FloatBorder")), "fg#") or "#4C566A"})
  end


  active_note_window_info.winid = note_winid
  active_note_window_info.bufnr = note_bufnr
  active_note_window_info.highlight_uuid = highlight_obj.uuid
  -- active_note_window_info.original_note_content is already set

  -- Keymaps local to the note buffer
  api.nvim_buf_set_keymap(note_bufnr, "n", "<Esc>", "<Cmd>lua require('numhi.notes')._internal_save_and_close()<CR>", { noremap = true, silent = true, nowait = true })
  api.nvim_buf_set_keymap(note_bufnr, "i", "<Esc>", "<Esc><Cmd>lua require('numhi.notes')._internal_save_and_close()<CR>", { noremap = true, silent = true, nowait = true })
  api.nvim_buf_set_keymap(note_bufnr, "n", "<C-s>", "<Cmd>lua require('numhi.notes')._internal_save_and_close()<CR>", { noremap = true, silent = true, nowait = true })
  api.nvim_buf_set_keymap(note_bufnr, "i", "<C-s>", "<Esc><Cmd>lua require('numhi.notes')._internal_save_and_close()<CR>", { noremap = true, silent = true, nowait = true })
  -- Optional: close without saving
  -- api.nvim_buf_set_keymap(note_bufnr, "n", "<C-q>", "<Cmd>lua require('numhi.notes')._internal_close_without_saving()<CR>", { noremap = true, silent = true, nowait=true })

  -- Autocmd for auto-saving if configured
  if M_CORE_STATE.plugin_config.auto_save_notes then
    api.nvim_create_autocmd({ "BufLeave", "WinClosed" }, {
      buffer = note_bufnr,
      once = true, -- Important to make it once per window instance
      callback = function(args)
        -- Check if the window being closed is our active note window
        if args.match == active_note_window_info.bufnr or (args.event == "WinClosed" and args.id == active_note_window_info.winid) then
          if api.nvim_buf_is_valid(active_note_window_info.bufnr) and api.nvim_win_is_valid(active_note_window_info.winid) then
             -- Check if buffer is modified before saving, to avoid saving unchanged notes repeatedly
             if api.nvim_buf_get_option(active_note_window_info.bufnr, "modified") then
                save_and_close_note_window()
             else
                if api.nvim_win_is_valid(active_note_window_info.winid) then
                  api.nvim_win_close(active_note_window_info.winid, true)
                end
                active_note_window_info = {} -- Clear
             end
          else
            active_note_window_info = {} -- Clear if already invalid
          end
        end
      end,
    })
  end
  api.nvim_command("startinsert")
end

--- Publicly callable save and close (e.g., for keymaps)
function N._internal_save_and_close()
    save_and_close_note_window()
end

function N._internal_close_without_saving()
    if active_note_window_info.winid and api.nvim_win_is_valid(active_note_window_info.winid) then
        api.nvim_win_close(active_note_window_info.winid, true)
    end
    active_note_window_info = {}
    utils.echo_message("NumHi: Note closed without saving.", "WarningMsg")
end

--- Deletes a note and optionally unlinks it from its highlight.
---@param note_uuid string
---@param highlight_uuid_to_unlink string? If provided, this highlight's note_id will be cleared.
function N.delete_note(note_uuid, highlight_uuid_to_unlink)
  if not M_CORE_STATE or not M_CORE_SAVE_FN then return end

  if M_CORE_STATE.notes_by_id[note_uuid] then
    local original_note = utils.deepcopy(M_CORE_STATE.notes_by_id[note_uuid])
    M_CORE_STATE.notes_by_id[note_uuid] = nil
    utils.echo_message("NumHi: Note " .. note_uuid:sub(1,8) .. " deleted.", "ModeMsg")

    if highlight_uuid_to_unlink then
      local buffer_key = nil
      -- Find the buffer_key for this highlight_uuid
      for bkey, highlights in pairs(M_CORE_STATE.highlights_by_buffer) do
        if highlights[highlight_uuid_to_unlink] then
          buffer_key = bkey
          break
        end
      end
      if buffer_key and M_CORE_STATE.highlights_by_buffer[buffer_key][highlight_uuid_to_unlink] then
        M_CORE_STATE.highlights_by_buffer[buffer_key][highlight_uuid_to_unlink].note_id = nil
        M_CORE_STATE.highlights_by_buffer[buffer_key][highlight_uuid_to_unlink].updated_at = os.time()
      end
    end
    
    M_CORE_ADD_HISTORY_FN({
        action = "delete_note",
        note_uuid = note_uuid,
        data = original_note,
        unlinked_highlight_uuid = highlight_uuid_to_unlink
    })
    M_CORE_SAVE_FN()
  end
end


return N

