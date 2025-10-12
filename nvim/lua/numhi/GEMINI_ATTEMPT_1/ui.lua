-- ~/.config/nvim/lua/numhi/ui.lua

local api = vim.api
local fn = vim.fn
local utils = require("numhi.utils")

local UI = {}

local M_CORE_STATE = nil -- Will be set by core.setup_ui_module
local M_CORE_GET_HIGHLIGHT_INFO_FN = nil
local M_CORE_GET_CATEGORY_LABEL_FN = nil

local current_tooltip_winid = nil
local current_tooltip_timer = nil

--- Initializes this UI module with references from core.
function UI.initialize(core_state_ref, core_get_highlight_info_fn, core_get_category_label_fn)
  M_CORE_STATE = core_state_ref
  M_CORE_GET_HIGHLIGHT_INFO_FN = core_get_highlight_info_fn
  M_CORE_GET_CATEGORY_LABEL_FN = core_get_category_label_fn -- For fetching category label by pal+slot
end

--- Shows a notification using vim.notify or utils.echo_message as fallback.
---@param message string The message to display.
---@param level string|number Optional, e.g., vim.log.levels.INFO.
---@param title string? Optional title for vim.notify.
function UI.notify(message, level, title)
  if M_CORE_STATE and M_CORE_STATE.plugin_config and M_CORE_STATE.plugin_config.prefer_vim_notify ~= false and vim.notify then
    level = level or vim.log.levels.INFO
    local opts = {}
    if title then opts.title = title end
    vim.notify(message, level, opts)
  else
    utils.echo_message(message, level == vim.log.levels.ERROR and "ErrorMsg" or (level == vim.log.levels.WARN and "WarningMsg" or "MoreMsg"))
  end
end

--- Formats and echoes/notifies information about a highlight.
---@param hl_info table The highlight object from core.get_highlight_info_at_cursor().
function UI.display_highlight_info(hl_info)
  if not hl_info then
    utils.echo_message("") -- Clear previous if any
    return
  end

  local palette_id = hl_info.palette_id
  local slot = hl_info.slot
  -- Fetch the dynamic category label
  local category_label = (M_CORE_STATE and M_CORE_STATE.category_labels[palette_id] and M_CORE_STATE.category_labels[palette_id][slot]) or ""

  local msg_parts = {
    { "NumHi ", "Title" },
    { palette_id .. "-" .. tostring(slot), utils.ensure_hl_group(palette_id, slot, M_CORE_STATE.plugin_config) },
  }
  if category_label and category_label ~= "" then
    table.insert(msg_parts, { " (" .. category_label .. ")", "Comment" })
  end
  if hl_info.tags and #hl_info.tags > 0 then
    table.insert(msg_parts, { " Tags: ", "Comment" })
    table.insert(msg_parts, { table.concat(hl_info.tags, ", "), "String" })
  end
  if hl_info.note_id and M_CORE_STATE and M_CORE_STATE.notes_by_id[hl_info.note_id] then
    local note_preview = M_CORE_STATE.notes_by_id[hl_info.note_id].content:gsub("\n", " "):sub(1, 30)
    table.insert(msg_parts, { " Note: ", "Comment" })
    table.insert(msg_parts, { note_preview .. (#M_CORE_STATE.notes_by_id[hl_info.note_id].content > 30 and "..." or ""), "String" })
  end

  utils.echo_message(msg_parts)
end

--- Shows a transient notification for palette changes.
---@param new_palette_id string
---@param plugin_config table
function UI.show_palette_notification(new_palette_id, plugin_config)
  local chunks = { { "NumHi Palette: ", "Title" } }
  local base_hl_for_palette_name = utils.ensure_hl_group(new_palette_id, 1, plugin_config)
  table.insert(chunks, { new_palette_id, base_hl_for_palette_name })
  table.insert(chunks, { " [", "Comment" })

  for i = 1, 10 do
    local slot_hl = utils.ensure_hl_group(new_palette_id, i, plugin_config)
    table.insert(chunks, { "▉", slot_hl }) -- Using a block character for swatch
    if i < 10 then table.insert(chunks, { "", "" }) end -- No space, let hl groups touch
  end
  table.insert(chunks, { "]", "Comment" })

  if vim.notify then
    local title_str = "NumHi Palette Change"
    local msg_str_for_notify = new_palette_id .. " ["
    for i=1,10 do msg_str_for_notify = msg_str_for_notify .. "S" .. i .. (i==10 and "" or " ") end
    msg_str_for_notify = msg_str_for_notify .. "]"
    -- vim.notify doesn't directly support richly colored segments like echo.
    -- So, we show a simpler message or use a custom float via nvim-notify's features if integrated.
    -- For now, a simple vim.notify message:
    vim.notify(table.concat({new_palette_id, "active"}, " "), vim.log.levels.INFO, {
        title = title_str,
        icon = "🎨", -- Example icon
        timeout = 2000, -- ms
        -- We could build a more complex message for nvim-notify if it's a dependency later
        -- by rendering the swatches into the message string if it supports Pango markup or similar.
        -- Or, use its API to create a custom notification layout.
    })
    -- Fallback to echo if notify is too plain for the swatches:
    utils.echo_message(chunks)
    vim.defer_fn(function() utils.echo_message("") end, 2000) -- Clear echo after a delay

  else
    utils.echo_message(chunks)
    vim.defer_fn(function() utils.echo_message("") end, 2000) -- Clear echo after a delay
  end
end

--- Shows a hover tooltip for the highlight under the cursor.
function UI.show_hover_tooltip()
  if not M_CORE_STATE or not M_CORE_GET_HIGHLIGHT_INFO_FN or not M_CORE_GET_CATEGORY_LABEL_FN then return end

  local hl_info = M_CORE_GET_HIGHLIGHT_INFO_FN(0, 0) -- current buf, current win
  if not hl_info then
    UI.close_tooltip() -- Close any existing tooltip if no highlight is found
    return
  end

  -- If tooltip for the same highlight is already showing, refresh its timer or do nothing
  if current_tooltip_winid and api.nvim_win_is_valid(current_tooltip_winid) then
      local current_hl_uuid = api.nvim_win_get_var(current_tooltip_winid, "numhi_tooltip_hl_uuid")
      if current_hl_uuid == hl_info.uuid then
          if current_tooltip_timer then current_tooltip_timer:again() end -- Refresh timer
          return
      else
          UI.close_tooltip() -- Close old tooltip for different highlight
      end
  end


  local palette_id = hl_info.palette_id
  local slot = hl_info.slot
  local category_label = (M_CORE_STATE.category_labels[palette_id] and M_CORE_STATE.category_labels[palette_id][slot]) or ""

  local lines_to_display = {}
  local line1 = string.format("%s-%d", palette_id, slot)
  if category_label and category_label ~= "" then
    line1 = line1 .. " (" .. category_label .. ")"
  end
  table.insert(lines_to_display, line1)

  if hl_info.note_id and M_CORE_STATE.notes_by_id[hl_info.note_id] then
    local note_content = M_CORE_STATE.notes_by_id[hl_info.note_id].content
    local note_preview = vim.split(note_content, "\n", {plain = true, trimempty = true})[1] or ""
    note_preview = note_preview:sub(1, M_CORE_STATE.plugin_config.tooltip_note_preview_length or 50)
    if #note_preview < #(vim.split(note_content, "\n", {plain = true, trimempty = true})[1] or "") or #vim.split(note_content, "\n", {plain = true, trimempty = true}) > 1 then
        note_preview = note_preview .. "..."
    end
    if note_preview ~= "" then table.insert(lines_to_display, "📝 " .. note_preview) end
  end

  if hl_info.tags and #hl_info.tags > 0 then
    table.insert(lines_to_display, "🏷️ " .. table.concat(hl_info.tags, ", "):sub(1, M_CORE_STATE.plugin_config.tooltip_tags_preview_length or 50))
  end

  local max_width = 0
  for _, line_str in ipairs(lines_to_display) do
    if #line_str > max_width then max_width = #line_str end
  end
  max_width = math.max(15, math.min(max_width, 70)) -- Clamp width

  local tooltip_bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(tooltip_bufnr, 0, -1, false, lines_to_display)
  api.nvim_buf_set_option(tooltip_bufnr, "filetype", "numhi_tooltip") -- For potential custom syntax

  local win_opts = {
    relative = "cursor",
    row = 1, -- Below cursor line
    col = 1, -- To the right of cursor column
    width = max_width,
    height = #lines_to_display,
    style = "minimal",
    border = M_CORE_STATE.plugin_config.tooltip_border or "rounded",
    focusable = false,
    zindex = 200,
  }

  current_tooltip_winid = api.nvim_open_win(tooltip_bufnr, false, win_opts)
  api.nvim_win_set_var(current_tooltip_winid, "numhi_tooltip_hl_uuid", hl_info.uuid) -- Store UUID for check

  -- Highlight first line with the actual highlight color
  local hl_group_for_first_line = utils.ensure_hl_group(palette_id, slot, M_CORE_STATE.plugin_config)
  api.nvim_buf_add_highlight(tooltip_bufnr, -1, hl_group_for_first_line, 0, 0, -1)
  api.nvim_win_set_option(current_tooltip_winid, "winhl", "Normal:NumHiTooltipBackground,FloatBorder:NumHiTooltipBorder")
   if fn.hlexists("NumHiTooltipBackground") == 0 then
      api.nvim_set_hl(0, "NumHiTooltipBackground", {bg = fn.hlexists("Tooltip")>0 and fn.synIDattr(fn.synIDtrans(fn.hlID("Tooltip")), "bg#") or "#3B4252",
                                                 fg = fn.hlexists("Tooltip")>0 and fn.synIDattr(fn.synIDtrans(fn.hlID("Tooltip")), "fg#") or "#E5E9F0"})
  end
   if fn.hlexists("NumHiTooltipBorder") == 0 then
      api.nvim_set_hl(0, "NumHiTooltipBorder", {fg = fn.hlexists("FloatBorder")>0 and fn.synIDattr(fn.synIDtrans(fn.hlID("FloatBorder")), "fg#") or "#4C566A"})
  end


  -- Auto-close timer
  if current_tooltip_timer then current_tooltip_timer:close() end
  current_tooltip_timer = vim.loop.new_timer()
  current_tooltip_timer:start(M_CORE_STATE.plugin_config.hover_delay_close or 3000, 0, vim.schedule_wrap(function()
    UI.close_tooltip()
  end))
end

--- Closes the currently active tooltip, if any.
function UI.close_tooltip()
  if current_tooltip_timer then
    current_tooltip_timer:stop()
    current_tooltip_timer:close()
    current_tooltip_timer = nil
  end
  if current_tooltip_winid and api.nvim_win_is_valid(current_tooltip_winid) then
    local buf_to_delete = api.nvim_win_get_buf(current_tooltip_winid)
    api.nvim_win_close(current_tooltip_winid, true) -- true to force close scratch buffer
    if buf_to_delete and api.nvim_buf_is_valid(buf_to_delete) then
        -- api.nvim_buf_delete(buf_to_delete, {force = true}) -- Fails if still attached, close takes care of it
    end
  end
  current_tooltip_winid = nil
end


--- Generates the string for the statusline component.
---@return string
function UI.get_statusline_component()
  if not M_CORE_STATE or M_CORE_STATE.active_palette_id == "" then
    return ""
  end

  local active_pal = M_CORE_STATE.active_palette_id
  local plugin_config = M_CORE_STATE.plugin_config

  -- Base color of the active palette for a general swatch
  local palette_swatch_hl = utils.ensure_hl_group(active_pal, 1, plugin_config)
  local palette_swatch_char = string.format("%%#%s#▉%%*", palette_swatch_hl) -- Block character

  local parts = { palette_swatch_char, " ", active_pal, " " }

  -- Show first few slots (e.g., 1-5 or 1-10)
  local num_slots_to_show = plugin_config.statusline_slot_count or 5
  for i = 1, num_slots_to_show do
    local slot_hl = utils.ensure_hl_group(active_pal, i, plugin_config)
    local slot_char = (i % 10 == 0) and "0" or tostring(i % 10) -- Single digit representation
    table.insert(parts, string.format("%%#%s#%s%%*", slot_hl, slot_char))
  end

  return table.concat(parts, "") .. " "
end


-- Placeholder for Telescope highlight picker
function UI.pick_highlight(callback)
  UI.notify("Picker for existing highlights: Not yet implemented.", vim.log.levels.WARN, "NumHi")
  -- TODO: Implement Telescope integration
  -- 1. Collect all highlights from M_CORE_STATE.highlights_by_buffer
  -- 2. Format them for display (e.g., "file:line palette-slot label tags")
  -- 3. Use telescope.nvim's API to show a picker
  -- 4. On selection, call the callback with the highlight_uuid
  if callback then callback(nil) end
end

-- Placeholder for Telescope palette/color picker
function UI.pick_palette_color(callback)
  UI.notify("Picker for palette/color: Not yet implemented.", vim.log.levels.WARN, "NumHi")
  -- TODO: Implement Telescope integration
  -- 1. List palettes
  -- 2. On palette selection, list its slots (1-10, 11-20, etc.) with color swatches
  -- 3. On selection, call callback(palette_id, slot_number)
  if callback then callback(nil, nil) end
end

-- Placeholder for Telescope category label picker
function UI.pick_category_label(current_palette_id, current_slot, callback)
  UI.notify("Picker for category labels: Not yet implemented.", vim.log.levels.WARN, "NumHi")
  -- TODO: Implement Telescope integration
  -- 1. Get all unique labels from M_CORE_STATE.category_labels
  -- 2. Display them in Telescope
  -- 3. On selection, call callback(selected_label_string)
  if callback then callback(nil) end
end


return UI

