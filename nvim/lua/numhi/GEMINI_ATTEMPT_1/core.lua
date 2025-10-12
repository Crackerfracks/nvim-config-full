-- ~/.config/nvim/lua/numhi/core.lua

local utils = require("numhi.utils")
local storage = require("numhi.storage")
-- local notes_manager = require("numhi.notes") -- Will be used later
local api = vim.api
local fn = vim.fn

local C = {} -- This table will be returned by the module

-- Module-level reference to the global plugin state from init.lua
-- This will be populated by C.setup()
local M_STATE_REF = nil

--- Helper to get the buffer key for storage.
-- Uses M_STATE_REF if initialized, otherwise falls back (though it shouldn't be needed before setup).
local function get_buffer_key(bufnr)
  return storage.get_buffer_storage_key(bufnr or 0)
end

--- Adds an operation to the undo history stored in the global state.
local function add_history_entry(entry)
  if not M_STATE_REF then return end -- Guard against calls before setup
  table.insert(M_STATE_REF.history, entry)
  if #M_STATE_REF.history > M_STATE_REF.plugin_config.history_max then
    table.remove(M_STATE_REF.history, 1)
  end
  M_STATE_REF.redo_stack = {} -- Clear redo stack on new action
end
C.add_history_entry = add_history_entry -- Expose for notes.lua if needed directly

--- Saves all current data to disk using the global state.
local function save_all_data()
  if not M_STATE_REF then return end -- Guard
  storage.save_all_highlights(M_STATE_REF.highlights_by_buffer, M_STATE_REF.plugin_config)
  storage.save_all_notes(M_STATE_REF.notes_by_id, M_STATE_REF.plugin_config)
  -- TODO: Save category_labels if they become persistent.
end
C.save_all_data = save_all_data -- Expose for notes.lua

--- Applies extmarks for a given buffer from the loaded highlight data.
---@param bufnr number
function C.apply_highlights_to_buffer(bufnr)
  if not M_STATE_REF then return end
  local buffer_key = get_buffer_key(bufnr)
  if not buffer_key or not M_STATE_REF.highlights_by_buffer[buffer_key] then
    return
  end

  for _, hl_obj in pairs(M_STATE_REF.highlights_by_buffer[buffer_key]) do
    local ns_id = M_STATE_REF.ns_ids[hl_obj.palette_id]
    if ns_id then
      local hl_group = utils.ensure_hl_group(hl_obj.palette_id, hl_obj.slot, M_STATE_REF.plugin_config)
      local line_text_at_end = utils.get_line_text(bufnr, hl_obj.end_line)
      local hl_eol_val = false
      if line_text_at_end then
          hl_eol_val = (hl_obj.end_col == -1 or hl_obj.end_col >= #line_text_at_end -1) -- end_col from data is inclusive
      end

      local extmark_opts = {
        end_row = hl_obj.end_line,
        end_col = hl_obj.end_col + 1, -- Convert inclusive end_col from data to exclusive for API
        hl_group = hl_group,
        hl_eol = hl_eol_val,
        priority = M_STATE_REF.plugin_config.highlight_priority,
        user_data = { numhi_uuid = hl_obj.uuid },
      }
      api.nvim_buf_set_extmark(bufnr, ns_id, hl_obj.start_line, hl_obj.start_col, extmark_opts)
    end
  end
end

--- Loads all data for the current project into the global state.
function C.load_all_project_data()
  if not M_STATE_REF then return end
  M_STATE_REF.highlights_by_buffer = storage.load_all_highlights(M_STATE_REF.plugin_config) or {}
  M_STATE_REF.notes_by_id = storage.load_all_notes(M_STATE_REF.plugin_config) or {}
  -- TODO: Load category_labels if they are persistent.
end

--- Setup function, called from init.lua
---@param global_state_from_init table The M.state object from init.lua
function C.setup(global_state_from_init)
  M_STATE_REF = global_state_from_init

  M_STATE_REF.active_palette_id = M_STATE_REF.plugin_config.palettes[1] or ""

  for _, pal_id in ipairs(M_STATE_REF.plugin_config.palettes) do
    M_STATE_REF.ns_ids[pal_id] = api.nvim_create_namespace("numhi_" .. pal_id)
    M_STATE_REF.category_labels[pal_id] = M_STATE_REF.category_labels[pal_id] or {}
  end

  C.load_all_project_data()

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(bufnr) then
      local buffer_key_for_apply = get_buffer_key(bufnr) -- Renamed to avoid conflict
      if buffer_key_for_apply then
        C.apply_highlights_to_buffer(bufnr)
      end
    end
  end
end

--- Gets or prompts for a category label for a given palette and slot.
---@param palette_id string
---@param slot_number number
---@return string The label string (can be empty).
local function get_category_label(palette_id, slot_number)
  if not M_STATE_REF then return "" end
  M_STATE_REF.category_labels[palette_id] = M_STATE_REF.category_labels[palette_id] or {}
  local label = M_STATE_REF.category_labels[palette_id][slot_number]

  if label == nil then -- Use nil to check if it was explicitly prompted for and set to empty
    local prompt_text = string.format("NumHi Label for %s-%d (leave empty for none):", palette_id, slot_number)
    -- This is synchronous for simplicity in this step.
    -- For a truly non-blocking UI, vim.ui.input's async nature needs careful handling.
    local input_label = fn.input(prompt_text)
    if input_label ~= nil then
        M_STATE_REF.category_labels[palette_id][slot_number] = input_label
        label = input_label
        -- TODO: Persist category_labels if they are meant to be project-wide and not just session-local
        -- save_all_data() -- Or a more specific save_category_labels()
    else -- User cancelled input (e.g. <Esc>)
        M_STATE_REF.category_labels[palette_id][slot_number] = "" -- Store empty so we don't ask again this session
        label = ""
    end
  end
  return label
end

--- Creates a new highlight based on current selection or word under cursor.
---@param slot_number number The palette slot number (1-99).
function C.create_highlight(slot_number)
  if not M_STATE_REF then return end
  slot_number = tonumber(slot_number)
  if not slot_number or slot_number < 1 or slot_number > M_STATE_REF.plugin_config.max_slots_per_palette then
    utils.echo_message("NumHi: Invalid slot number: " .. tostring(slot_number), "ErrorMsg")
    return
  end

  local bufnr = 0 -- Current buffer
  local buffer_key = get_buffer_key(bufnr)
  if not buffer_key then
    utils.echo_message("NumHi: Cannot highlight in unnamed buffer.", "WarningMsg")
    return
  end

  local palette_id = M_STATE_REF.active_palette_id
  local ns_id = M_STATE_REF.ns_ids[palette_id]
  if not ns_id then
    utils.echo_message("NumHi: Active palette not initialized: " .. palette_id, "ErrorMsg")
    return
  end

  local start_pos, end_pos_inclusive
  local visual_start, visual_end = utils.get_visual_selection_range()

  if visual_start and visual_end then
    start_pos = visual_start
    end_pos_inclusive = visual_end
  else
    local word_s, word_e = utils.get_word_under_cursor_range(bufnr, 0)
    if word_s == nil or word_e == nil then -- Ensure both are returned
      utils.echo_message("NumHi: Could not determine word under cursor.", "WarningMsg")
      return
    end
    local cursor_pos = utils.get_cursor_pos_0_indexed(0)
    start_pos = { line = cursor_pos.line, col = word_s }
    end_pos_inclusive = { line = cursor_pos.line, col = word_e }
  end
  
  if not start_pos or start_pos.line == nil or start_pos.col == nil or
     not end_pos_inclusive or end_pos_inclusive.line == nil or end_pos_inclusive.col == nil then
     utils.echo_message("NumHi: Invalid range for highlight.", "ErrorMsg")
     return
  end
  
  -- Clear existing NumHi highlights in the exact same range before applying a new one
  for _, p_id_to_check in ipairs(M_STATE_REF.plugin_config.palettes) do
      local ns_id_to_check = M_STATE_REF.ns_ids[p_id_to_check]
      if ns_id_to_check then
          local existing_marks = api.nvim_buf_get_extmarks(bufnr, ns_id_to_check,
              {start_pos.line, start_pos.col},
              {end_pos_inclusive.line, end_pos_inclusive.col + 1}, -- API uses exclusive end_col
              {details = true})
          for _, mark in ipairs(existing_marks) do
              local mark_details = mark[4] -- Contains end_row, end_col, user_data
              if mark[2] == start_pos.line and mark[3] == start_pos.col and
                 mark_details.end_row == end_pos_inclusive.line and
                 mark_details.end_col == end_pos_inclusive.col + 1 then -- Compare with API's exclusive end_col
                api.nvim_buf_del_extmark(bufnr, ns_id_to_check, mark[1])
                if M_STATE_REF.highlights_by_buffer[buffer_key] and mark_details.user_data and mark_details.user_data.numhi_uuid then
                     M_STATE_REF.highlights_by_buffer[buffer_key][mark_details.user_data.numhi_uuid] = nil
                end
              end
          end
      end
  end

  local highlight_uuid = utils.uuid()
  local category_lbl = get_category_label(palette_id, slot_number)
  local hl_group = utils.ensure_hl_group(palette_id, slot_number, M_STATE_REF.plugin_config)
  
  local created_extmark_ids_for_undo = {} -- Store {ns_id, extmark_id} for precise undo

  for l = start_pos.line, end_pos_inclusive.line do
    local current_line_text = utils.get_line_text(bufnr, l)
    local line_len_chars = current_line_text and #current_line_text or 0

    local mark_start_col = (l == start_pos.line) and start_pos.col or 0
    local mark_end_col_exclusive -- This is exclusive for nvim_buf_set_extmark
    if l == end_pos_inclusive.line then
      mark_end_col_exclusive = math.min(end_pos_inclusive.col + 1, line_len_chars)
    else
      mark_end_col_exclusive = line_len_chars
    end
    
    if mark_start_col >= mark_end_col_exclusive and not (mark_start_col == 0 and mark_end_col_exclusive == 0 and line_len_chars == 0) then
      goto next_line_in_create
    end

    local extmark_id = api.nvim_buf_set_extmark(bufnr, ns_id, l, mark_start_col, {
      end_row = l,
      end_col = mark_end_col_exclusive,
      hl_group = hl_group,
      hl_eol = (mark_end_col_exclusive == line_len_chars and line_len_chars > 0),
      priority = M_STATE_REF.plugin_config.highlight_priority,
      user_data = { numhi_uuid = highlight_uuid },
    })
    table.insert(created_extmark_ids_for_undo, {ns_id = ns_id, id = extmark_id, line = l, start_col = mark_start_col, end_col_exclusive = mark_end_col_exclusive, hl_group = hl_group})
    ::next_line_in_create::
  end
  
  if #created_extmark_ids_for_undo == 0 then
      utils.echo_message("NumHi: No valid segments to highlight.", "WarningMsg")
      return
  end

  local ts = os.time()
  local highlight_obj = {
    uuid = highlight_uuid,
    palette_id = palette_id,
    slot = slot_number,
    start_line = start_pos.line,
    start_col = start_pos.col,
    end_line = end_pos_inclusive.line,
    end_col = end_pos_inclusive.col, -- Store inclusive end_col
    tags = {},
    note_id = nil,
    created_at = ts,
    updated_at = ts,
  }

  M_STATE_REF.highlights_by_buffer[buffer_key] = M_STATE_REF.highlights_by_buffer[buffer_key] or {}
  M_STATE_REF.highlights_by_buffer[buffer_key][highlight_uuid] = highlight_obj

  add_history_entry({
    action = "create",
    buffer_key = buffer_key,
    highlight_uuid = highlight_uuid,
    created_extmarks_info = created_extmark_ids_for_undo, -- For precise undo
  })

  save_all_data()

  if M_STATE_REF.plugin_config.echo_on_highlight then
    local display_label = M_STATE_REF.category_labels[palette_id] and M_STATE_REF.category_labels[palette_id][slot_number] or category_lbl or ""
    local msg = string.format("NumHi: Highlighted %s-%d", palette_id, slot_number)
    if display_label ~= "" then msg = msg .. " (" .. display_label .. ")" end
    utils.echo_message(msg, hl_group)
  end
  if M_STATE_REF.plugin_config.notify_on_highlight_create then
     local display_label = M_STATE_REF.category_labels[palette_id] and M_STATE_REF.category_labels[palette_id][slot_number] or category_lbl or ""
    utils.notify_message(string.format("NumHi Highlighted: %s-%d%s", palette_id, slot_number, display_label ~= "" and " ("..display_label..")" or ""), vim.log.levels.INFO, "NumHi")
  end
  
  if fn.mode(false):find("^[vV]") then
      api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  end
end

--- Gets information about the NumHi highlight at the current cursor position.
---@param bufnr number
---@param winid number
---@return table|nil Highlight object from M_STATE_REF.highlights_by_buffer or nil.
function C.get_highlight_info_at_cursor(bufnr, winid)
  if not M_STATE_REF then return nil end
  local pos = utils.get_cursor_pos_0_indexed(winid)
  local buffer_key = get_buffer_key(bufnr)

  if not buffer_key or not M_STATE_REF.highlights_by_buffer[buffer_key] then
    return nil
  end
  
  for uuid, hl_obj in pairs(M_STATE_REF.highlights_by_buffer[buffer_key]) do
    local mark_start = {line = hl_obj.start_line, col = hl_obj.start_col}
    local mark_end_inclusive = {line = hl_obj.end_line, col = hl_obj.end_col}
    if utils.is_position_within_extmark(pos, mark_start, mark_end_inclusive) then
      return hl_obj
    end
  end
  return nil
end
C.get_highlight_info_at_cursor = C.get_highlight_info_at_cursor -- Expose for UI

--- Deletes the NumHi highlight(s) under the cursor.
function C.delete_highlight_at_cursor()
  if not M_STATE_REF then return end
  local bufnr = 0
  local winid = 0
  local buffer_key = get_buffer_key(bufnr)
  if not buffer_key then return end

  local hl_info_to_delete = C.get_highlight_info_at_cursor(bufnr, winid)
  if not hl_info_to_delete then
    utils.echo_message("NumHi: No highlight under cursor.", "WarningMsg")
    return
  end

  local uuid_to_delete = hl_info_to_delete.uuid
  -- Deepcopy before modification/deletion from state
  local original_hl_obj = utils.deepcopy(M_STATE_REF.highlights_by_buffer[buffer_key][uuid_to_delete])
  
  local deleted_extmark_infos = {} -- Store {ns_id, extmark_id} for precise undo

  -- Remove all extmarks associated with this UUID across all NumHi namespaces
  for pal_id_iter, ns_id_iter in pairs(M_STATE_REF.ns_ids) do
      local all_marks_in_ns = api.nvim_buf_get_extmarks(bufnr, ns_id_iter, 0, -1, {details = true})
      for _, mark_iter in ipairs(all_marks_in_ns) do
          if mark_iter[4] and mark_iter[4].user_data and mark_iter[4].user_data.numhi_uuid == uuid_to_delete then
              api.nvim_buf_del_extmark(bufnr, ns_id_iter, mark_iter[1])
              table.insert(deleted_extmark_infos, {
                  ns_id = ns_id_iter, id = mark_iter[1], -- Neovim extmark id
                  line = mark_iter[2], start_col = mark_iter[3],
                  end_row = mark_iter[4].end_row, end_col_exclusive = mark_iter[4].end_col,
                  hl_group = mark_iter[4].hl_group, hl_eol = mark_iter[4].hl_eol,
                  user_data_uuid = uuid_to_delete -- for re-associating during redo
              })
          end
      end
  end

  M_STATE_REF.highlights_by_buffer[buffer_key][uuid_to_delete] = nil -- Remove from in-memory store
  utils.echo_message(string.format("NumHi: Deleted highlight %s-%d.", original_hl_obj.palette_id, original_hl_obj.slot), "ModeMsg")

  add_history_entry({
    action = "delete",
    buffer_key = buffer_key,
    highlight_uuid = uuid_to_delete,
    original_highlight_data = original_hl_obj, -- Store the full object for redo
    deleted_extmarks_info = deleted_extmark_infos,
  })

  if original_hl_obj.note_id and M_STATE_REF.plugin_config.delete_mark_prompts_for_note then
    local note_content_preview = "Note exists."
    if M_STATE_REF.notes_by_id[original_hl_obj.note_id] then
        note_content_preview = M_STATE_REF.notes_by_id[original_hl_obj.note_id].content:sub(1,30)
        if #M_STATE_REF.notes_by_id[original_hl_obj.note_id].content > 30 then note_content_preview = note_content_preview .. "..." end
    end

    vim.ui.select({ "Yes, delete note", "No, keep note (unlinked)" }, {
      prompt = "Highlight had a note: \"".. note_content_preview .. "\". Delete associated note?",
      format_item = function(item) return item end,
    }, function(choice)
      if choice and choice == "Yes, delete note" then
        if M_STATE_REF.notes_by_id[original_hl_obj.note_id] then
            local original_note_obj_for_history = utils.deepcopy(M_STATE_REF.notes_by_id[original_hl_obj.note_id])
            M_STATE_REF.notes_by_id[original_hl_obj.note_id] = nil
            add_history_entry({ -- Separate history entry for note deletion
                action = "delete_note_associated",
                note_uuid = original_hl_obj.note_id,
                original_note_data = original_note_obj_for_history,
                parent_highlight_uuid = uuid_to_delete,
            })
            utils.echo_message("NumHi: Note deleted.", "ModeMsg")
        end
      else
         utils.echo_message("NumHi: Note kept (unlinked).", "ModeMsg")
      end
      save_all_data() -- Save after note decision
    end)
  else
      save_all_data() -- Save if no note or no prompt
  end
end

function C.undo()
  if not M_STATE_REF or #M_STATE_REF.history == 0 then
    utils.echo_message("NumHi: Nothing to undo.", "WarningMsg")
    return
  end

  local entry = table.remove(M_STATE_REF.history)
  local bufnr = entry.buffer_key and fn.bufnr(entry.buffer_key) or 0 -- Get bufnr from buffer_key

  if entry.action == "create" then
    local hl_obj_to_remove = M_STATE_REF.highlights_by_buffer[entry.buffer_key] and M_STATE_REF.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid]
    if hl_obj_to_remove then
      -- Use the stored extmark info if available, otherwise reconstruct from hl_obj_to_remove
      local extmarks_to_delete = entry.created_extmarks_info or {}
      if #extmarks_to_delete > 0 then
          for _, em_info in ipairs(extmarks_to_delete) do
              api.nvim_buf_del_extmark(bufnr, em_info.ns_id, em_info.id)
          end
      else -- Fallback if created_extmarks_info wasn't stored properly
          for _, ns_id_iter in pairs(M_STATE_REF.ns_ids) do
             local all_marks_in_ns = api.nvim_buf_get_extmarks(bufnr, ns_id_iter, 0, -1, {details = true})
             for _, mark_iter in ipairs(all_marks_in_ns) do
                 if mark_iter[4] and mark_iter[4].user_data and mark_iter[4].user_data.numhi_uuid == entry.highlight_uuid then
                     api.nvim_buf_del_extmark(bufnr, ns_id_iter, mark_iter[1])
                 end
             end
          end
      end
      M_STATE_REF.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid] = nil
      table.insert(M_STATE_REF.redo_stack, {action="undo_create", buffer_key=entry.buffer_key, original_highlight_data = hl_obj_to_remove, created_extmarks_info = entry.created_extmarks_info})
      utils.echo_message("NumHi: Undid highlight creation.", "ModeMsg")
    end
  elseif entry.action == "delete" then
    local hl_obj_to_restore = entry.original_highlight_data
    if hl_obj_to_restore then
      M_STATE_REF.highlights_by_buffer[entry.buffer_key] = M_STATE_REF.highlights_by_buffer[entry.buffer_key] or {}
      M_STATE_REF.highlights_by_buffer[entry.buffer_key][hl_obj_to_restore.uuid] = hl_obj_to_restore
      -- Re-apply based on stored extmark infos if possible, or full re-application
      if entry.deleted_extmarks_info and #entry.deleted_extmarks_info > 0 then
          for _, em_info in ipairs(entry.deleted_extmarks_info) do
              api.nvim_buf_set_extmark(bufnr, em_info.ns_id, em_info.line, em_info.start_col, {
                  -- id = em_info.id, -- Do not reuse ID, let nvim assign
                  end_row = em_info.end_row, end_col = em_info.end_col_exclusive,
                  hl_group = em_info.hl_group, hl_eol = em_info.hl_eol,
                  user_data = { numhi_uuid = em_info.user_data_uuid },
                  priority = M_STATE_REF.plugin_config.highlight_priority
              })
          end
      else
          C.apply_highlights_to_buffer(bufnr) -- General re-apply if specific info is missing
      end
      table.insert(M_STATE_REF.redo_stack, {action="undo_delete", buffer_key=entry.buffer_key, highlight_uuid = hl_obj_to_restore.uuid, deleted_extmarks_info = entry.deleted_extmarks_info})
      utils.echo_message("NumHi: Undid highlight deletion.", "ModeMsg")
    end
  elseif entry.action == "delete_note_associated" then
    if entry.original_note_data and entry.note_uuid then
        M_STATE_REF.notes_by_id[entry.note_uuid] = entry.original_note_data
        -- Also re-link to highlight if parent_highlight_uuid is present
        if entry.parent_highlight_uuid and M_STATE_REF.highlights_by_buffer[get_buffer_key(bufnr)] and M_STATE_REF.highlights_by_buffer[get_buffer_key(bufnr)][entry.parent_highlight_uuid] then
            M_STATE_REF.highlights_by_buffer[get_buffer_key(bufnr)][entry.parent_highlight_uuid].note_id = entry.note_uuid
        end
        table.insert(M_STATE_REF.redo_stack, {action="undo_delete_note", note_uuid = entry.note_uuid, original_note_data = entry.original_note_data, parent_highlight_uuid = entry.parent_highlight_uuid})
        utils.echo_message("NumHi: Undid note deletion.", "ModeMsg")
    end
  end
  save_all_data()
end

function C.redo()
  if not M_STATE_REF or #M_STATE_REF.redo_stack == 0 then
    utils.echo_message("NumHi: Nothing to redo.", "WarningMsg")
    return
  end
  local entry = table.remove(M_STATE_REF.redo_stack)
  local bufnr = entry.buffer_key and fn.bufnr(entry.buffer_key) or 0

  if entry.action == "undo_create" then -- Redo the creation
    local hl_obj_to_restore = entry.original_highlight_data
    if hl_obj_to_restore then
      M_STATE_REF.highlights_by_buffer[entry.buffer_key] = M_STATE_REF.highlights_by_buffer[entry.buffer_key] or {}
      M_STATE_REF.highlights_by_buffer[entry.buffer_key][hl_obj_to_restore.uuid] = hl_obj_to_restore
      -- Re-apply using stored extmark details if available
      if entry.created_extmarks_info and #entry.created_extmarks_info > 0 then
           for _, em_info in ipairs(entry.created_extmarks_info) do
              api.nvim_buf_set_extmark(bufnr, em_info.ns_id, em_info.line, em_info.start_col, {
                  end_row = em_info.line, -- Assuming single-line segments from stored info
                  end_col = em_info.end_col_exclusive,
                  hl_group = em_info.hl_group,
                  user_data = {numhi_uuid = hl_obj_to_restore.uuid},
                  priority = M_STATE_REF.plugin_config.highlight_priority
              })
           end
      else
          C.apply_highlights_to_buffer(bufnr) -- General re-apply
      end
      add_history_entry({action="create", buffer_key=entry.buffer_key, highlight_uuid=hl_obj_to_restore.uuid, created_extmarks_info = entry.created_extmarks_info})
      utils.echo_message("NumHi: Redid highlight creation.", "ModeMsg")
    end
  elseif entry.action == "undo_delete" then -- Redo the deletion
     local hl_obj_to_delete = M_STATE_REF.highlights_by_buffer[entry.buffer_key] and M_STATE_REF.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid]
     if hl_obj_to_delete then
        -- Use stored deleted_extmarks_info to know which specific extmarks were part of this highlight object
        local extmarks_to_delete_on_redo = entry.deleted_extmarks_info or {}
        if #extmarks_to_delete_on_redo > 0 then
            for _, em_info in ipairs(extmarks_to_delete_on_redo) do
                 -- Need to find current Neovim extmark ID by UUID and range, as original ID is gone
                 local current_marks = api.nvim_buf_get_extmarks(bufnr, em_info.ns_id, {em_info.line, em_info.start_col}, {em_info.end_row, em_info.end_col_exclusive}, {details = true})
                 for _, m in ipairs(current_marks) do
                     if m[4] and m[4].user_data and m[4].user_data.numhi_uuid == entry.highlight_uuid then
                         api.nvim_buf_del_extmark(bufnr, em_info.ns_id, m[1])
                     end
                 end
            end
        else -- Fallback if specific extmark info wasn't available for redo
            for _, ns_id_iter in pairs(M_STATE_REF.ns_ids) do
                local all_marks_in_ns = api.nvim_buf_get_extmarks(bufnr, ns_id_iter, 0, -1, {details = true})
                for _, mark_iter in ipairs(all_marks_in_ns) do
                    if mark_iter[4] and mark_iter[4].user_data and mark_iter[4].user_data.numhi_uuid == entry.highlight_uuid then
                        api.nvim_buf_del_extmark(bufnr, ns_id_iter, mark_iter[1])
                    end
                end
            end
        end
        M_STATE_REF.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid] = nil
        add_history_entry({action="delete", buffer_key=entry.buffer_key, highlight_uuid=entry.highlight_uuid, original_highlight_data=hl_obj_to_delete, deleted_extmarks_info = entry.deleted_extmarks_info})
        utils.echo_message("NumHi: Redid highlight deletion.", "ModeMsg")
     end
  elseif entry.action == "undo_delete_note" then
    if entry.original_note_data and M_STATE_REF.notes_by_id[entry.note_uuid] then -- Note was restored by undo
        local original_note_data_for_history = utils.deepcopy(M_STATE_REF.notes_by_id[entry.note_uuid])
        M_STATE_REF.notes_by_id[entry.note_uuid] = nil -- Redo: delete the note again
         if entry.parent_highlight_uuid and M_STATE_REF.highlights_by_buffer[get_buffer_key(bufnr)] and M_STATE_REF.highlights_by_buffer[get_buffer_key(bufnr)][entry.parent_highlight_uuid] then
            M_STATE_REF.highlights_by_buffer[get_buffer_key(bufnr)][entry.parent_highlight_uuid].note_id = nil
        end
        add_history_entry({action="delete_note_associated", note_uuid = entry.note_uuid, original_note_data = original_note_data_for_history, parent_highlight_uuid = entry.parent_highlight_uuid })
        utils.echo_message("NumHi: Redid note deletion.", "ModeMsg")
    end
  end
  save_all_data()
end

function C.cycle_palette(direction)
  if not M_STATE_REF then return end
  local palettes = M_STATE_REF.plugin_config.palettes
  local current_idx = utils.index_of(palettes, M_STATE_REF.active_palette_id)
  if not current_idx then current_idx = 1 end

  local new_idx = (current_idx - 1 + direction)
  if new_idx < 0 then new_idx = #palettes - 1 elseif new_idx >= #palettes then new_idx = 0 end
  M_STATE_REF.active_palette_id = palettes[new_idx + 1]

  local ui_module_ref = require("numhi.ui")
  ui_module_ref.show_palette_notification(M_STATE_REF.active_palette_id, M_STATE_REF.plugin_config)

  if M_STATE_REF.plugin_config.statusline then
    pcall(function() require("lualine").refresh() end)
    -- TODO: Add refresh for other statuslines if needed, or a general event.
  end
end

function C.get_active_palette()
  if not M_STATE_REF then return "" end
  return M_STATE_REF.active_palette_id
end
C.get_category_labels_for_palette = function(palette_id) -- Exposed for UI module
    if not M_STATE_REF then return {} end
    return M_STATE_REF.category_labels[palette_id] or {}
end

function C.collect_digits_for_highlight()
  if not M_STATE_REF then return end
  local digits = ""
  local current_palette = M_STATE_REF.active_palette_id

  local function update_prompt()
    local slot_preview = (#digits > 0) and digits or "__"
    local prompt_msg_parts = {
      { "NumHi ", "Title" },
      { current_palette, utils.ensure_hl_group(current_palette, 1, M_STATE_REF.plugin_config) },
      { " Slot: ", "Comment" },
      { slot_preview, (#digits > 0 and tonumber(digits)) and utils.ensure_hl_group(current_palette, tonumber(digits) or 1, M_STATE_REF.plugin_config) or "Comment" },
      { string.format(" (1-%d)", M_STATE_REF.plugin_config.max_slots_per_palette), "Comment" },
    }
    utils.echo_message(prompt_msg_parts)
  end
  update_prompt()

  local key_input
  while true do
    key_input = fn.getchar()
    if type(key_input) == "number" then key_input = fn.nr2char(key_input) end

    if key_input == "\r" or key_input == "\n" then -- Enter
      if #digits > 0 then
        local slot_to_use = tonumber(digits)
        if slot_to_use then
          if fn.mode(false):find("^[vV]") then
             api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
             vim.schedule(function() C.create_highlight(slot_to_use) end)
          else
             C.create_highlight(slot_to_use)
          end
        else
          utils.echo_message("NumHi: Invalid slot number.", "ErrorMsg")
        end
      else
        utils.echo_message("NumHi: No slot entered.", "WarningMsg")
      end
      utils.echo_message("") -- Clear prompt
      return
    elseif key_input == "\x1b" or key_input == "\x03" then -- Escape or Ctrl-C
      utils.echo_message("NumHi: Highlight cancelled.", "WarningMsg")
      utils.echo_message("")
      return
    elseif key_input:match("%d") then
      if #digits < (M_STATE_REF.plugin_config.max_slots_per_palette >= 100 and 3 or 2) then
        digits = digits .. key_input
        update_prompt()
      end
    elseif key_input == "\x7f" or key_input == "\b" then -- Backspace
      if #digits > 0 then
        digits = digits:sub(1, #digits - 1)
        update_prompt()
      end
    end
  end
end

function C.on_buf_enter(bufnr)
  if not M_STATE_REF then return end
  bufnr = bufnr or api.nvim_get_current_buf()
  local buffer_key_for_event = get_buffer_key(bufnr) -- Renamed
  if buffer_key_for_event then
    -- Data for the whole project should ideally be loaded once at setup.
    -- C.load_all_project_data() -- This might be too much on every BufEnter.
    -- Ensure data is present if it was somehow missed or if loading per project makes sense here.
    if M_STATE_REF.highlights_by_buffer == nil or next(M_STATE_REF.highlights_by_buffer) == nil then
        C.load_all_project_data()
    end
    C.apply_highlights_to_buffer(bufnr)
  end
end

function C.on_buf_write(bufnr)
  if not M_STATE_REF then return end
  bufnr = bufnr or api.nvim_get_current_buf()
  if get_buffer_key(bufnr) then
    save_all_data()
  end
end

return C
