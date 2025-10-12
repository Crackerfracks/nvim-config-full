-- ~/.config/nvim/lua/numhi/utils.lua

local api = vim.api
local fn = vim.fn
local hsluv = require("hsluv") -- Ensure hsluv-lua is correctly installed and findable

local M = {}

--- Returns the 0-indexed start and end positions of the last visual selection.
---@return {line: number, col: number}|nil, {line: number, col: number}|nil
function M.get_visual_selection_range()
  local mode = fn.mode(false)
  if not (mode:find("^[vV]") or fn.line("'<") > 0) then
    return nil, nil
  end

  local p1 = fn.getpos("'<") -- {bufnum, lnum, col, off}
  local p2 = fn.getpos("'>")

  -- Check if visual marks are valid
  if p1[2] == 0 or p2[2] == 0 then
    return nil, nil -- Marks not set
  end

  local start_line = p1[2] - 1
  local start_col = p1[3] - 1
  local end_line = p2[2] - 1
  local end_col = p2[3] - 1 -- Position of the character, inclusive

  -- Ensure start is before end
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end
  return { line = start_line, col = start_col }, { line = end_line, col = end_col }
end

--- Returns the 0-indexed start and end column of the word under the cursor.
---@param bufnr number Buffer handle (0 for current).
---@param winid number Window handle (0 for current).
---@return number|nil, number|nil start_col (0-indexed), end_col (0-indexed, inclusive)
function M.get_word_under_cursor_range(bufnr, winid)
  bufnr = bufnr or 0
  winid = winid or 0
  local lnum, col = unpack(api.nvim_win_get_cursor(winid))
  lnum = lnum - 1 -- to 0-indexed
  -- col is 0-indexed

  local line_text = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
  if not line_text or col >= #line_text then -- Cursor past EOL or on empty line
    if line_text and #line_text > 0 and col > 0 then -- if at EOL, select char before
        if line_text:sub(col, col):match("%s") then return col, col end -- if space, just space
        return col -1, col -1
    end
    return col, col -- Highlight single character/point if at EOL or empty line
  end

  local s, e = col, col

  -- Expand left
  while s > 0 and line_text:sub(s, s):match("[^%s%p]+") do
    s = s - 1
  end
  if not line_text:sub(s + 1, s + 1):match("[^%s%p]+") then -- If current char is not a word char
    s = col
  else
    s = s + 1 -- move back to the first word character
  end


  -- Expand right
  while e < #line_text -1 and line_text:sub(e + 2, e + 2):match("[^%s%p]+") do
    e = e + 1
  end
   if not line_text:sub(e + 1, e + 1):match("[^%s%p]+") then -- If current char is not a word char
    e = col
  end

  -- Adjust if initial char was not a word char (e.g. space, punctuation)
  if not line_text:sub(col + 1, col + 1):match("[^%s%p]+") then
    return col, col
  end

  return s, e
end


--- Gets text of a specific line.
---@param bufnr number
---@param lnum_0_indexed number
---@return string|nil
function M.get_line_text(bufnr, lnum_0_indexed)
  local lines = api.nvim_buf_get_lines(bufnr, lnum_0_indexed, lnum_0_indexed + 1, false)
  return lines and lines[1]
end

--- Returns current cursor position {line, col} (0-indexed).
---@param winid number Window ID (0 for current).
---@return {line: number, col: number}
function M.get_cursor_pos_0_indexed(winid)
  winid = winid or 0
  local pos = api.nvim_win_get_cursor(winid)
  return { line = pos[1] - 1, col = pos[2] }
end

--- Checks if a 0-indexed position {line, col} is within a 0-indexed extmark range.
--- For single-line marks: inclusive start_col, inclusive end_col.
--- For multi-line marks:
---   - if line > start_line and line < end_line: true
---   - if line == start_line: col >= start_col
---   - if line == end_line: col <= end_col
---@param pos {line:number, col:number} The position to check.
---@param mark_start {line:number, col:number} Mark start position.
---@param mark_end {line:number, col:number} Mark end position.
---@return boolean
function M.is_position_within_extmark(pos, mark_start, mark_end)
  if pos.line < mark_start.line or pos.line > mark_end.line then
    return false
  end
  if pos.line == mark_start.line then
    if pos.line == mark_end.line then -- Single line highlight
      return pos.col >= mark_start.col and pos.col <= mark_end.col
    else -- Start of a multi-line highlight
      return pos.col >= mark_start.col
    end
  end
  if pos.line == mark_end.line then -- End of a multi-line highlight
    return pos.col <= mark_end.col
  end
  -- Middle of a multi-line highlight
  return true
end


--- Echoes a message to the Neovim command line.
--- Can accept a plain string or a list of {text, hl_group} chunks.
---@param chunks_or_string string | table[] Either a string or {{msg:string, hl_group?:string}, ...}
---@param hl_group string? Optional highlight group if chunks_or_string is a plain string.
function M.echo_message(chunks_or_string, hl_group)
  local chunks
  if type(chunks_or_string) == "string" then
    chunks = { { chunks_or_string, hl_group } }
  else
    chunks = chunks_or_string
  end

  if not chunks or #chunks == 0 or (chunks[1] and chunks[1][1] == "") then
    api.nvim_echo({}, false, {}) -- Clear cmdline quietly
  else
    api.nvim_echo(chunks, false, {})
  end
end

--- Shows a notification using vim.notify.
---@param message string The message to display.
---@param level string? Optional, e.g., "INFO", "ERROR", "WARN" (vim.log.levels).
---@param title string? Optional title for the notification.
function M.notify_message(message, level, title)
  level = level or vim.log.levels.INFO
  local opts = {}
  if title then
    opts.title = title
  end
  vim.notify(message, level, opts)
end

--- Tries to determine the project root.
--- Looks for .git, .hg, .svn, or uses current buffer's directory.
---@return string|nil Path to project root or nil.
function M.get_project_root()
  local current_buf_path = fn.expand("%:p:h")
  if current_buf_path == "" then current_buf_path = fn.getcwd() end

  local function find_root_marker(start_path, markers)
    local path = start_path
    for _ = 1, 64 do -- Limit depth to avoid infinite loops on weird filesystems
      for _, marker in ipairs(markers) do
        if fn.isdirectory(path .. "/" .. marker) == 1 or fn.filereadable(path .. "/" .. marker) == 1 then
          return path
        end
      end
      local parent = fn.fnamemodify(path, ":h")
      if parent == path or parent == "" then -- Reached filesystem root or an error
        return nil
      end
      path = parent
    end
    return nil
  end

  local vcs_markers = { ".git", ".hg", ".svn", "_darcs" }
  local project_root = find_root_marker(current_buf_path, vcs_markers)

  return project_root or current_buf_path -- Fallback to current file's directory
end

--- Ensures a directory exists, creating it if necessary.
---@param path string The full path to the directory.
---@return boolean success True if directory exists or was created, false otherwise.
function M.ensure_dir_exists(path)
  if fn.isdirectory(path) == 0 then
    -- vim.fn.mkdir returns 0 on success, -1 on failure (usually).
    -- Some versions might return other non-zero for specific errors.
    local success_code = fn.mkdir(path, "p", 0755) -- Explicitly set permissions
    if success_code ~= 0 then
      M.notify_message(
        string.format("NumHi: mkdir failed for '%s'. Return code: %s", path, tostring(success_code)),
        vim.log.levels.ERROR,
        "NumHi Storage Error"
      )
      -- You can add more debug here, e.g., try to write a test file to parent dir
      -- local parent_dir = fn.fnamemodify(path, ":h")
      -- local test_file = parent_dir .. "/numhi_write_test.txt"
      -- local test_write_ok = pcall(fn.writefile, {"test"}, test_file)
      -- M.notify_message("NumHi: Test write to " .. parent_dir .. " " .. (test_write_ok and "succeeded" or "FAILED"), vim.log.levels.DEBUG)
      -- if test_write_ok then fn.delete(test_file) end
      return false
    end
    M.notify_message("NumHi: Successfully created directory: " .. path, vim.log.levels.INFO)
    return true
  end
  return true
end

--- Generates a simple UUID v4.
---@return string
function M.uuid()
  -- From https://gist.github.com/jcxplorer/c1c872f68609db33f99b
  local T = {}
  for i = 1, 16 do
    local n = math.random(0, 255)
    T[i] = string.char(n)
  end
  T[7] = string.char(bit.band(T[7]:byte(1), 0x0f) + 0x40) -- Set version to 4
  T[9] = string.char(bit.band(T[9]:byte(1), 0x3f) + 0x80) -- Set variant
  local hex = ""
  for i = 1, 16 do
    hex = hex .. string.format("%02x", T[i]:byte(1))
  end
  return string.format("%s-%s-%s-%s-%s",
    hex:sub(1, 8), hex:sub(9, 12), hex:sub(13, 16),
    hex:sub(17, 20), hex:sub(21, 32))
end

--- Finds the index of a value in a list-like table.
---@param tbl table The table to search.
---@param val any The value to find.
---@return number|nil The index or nil if not found.
function M.index_of(tbl, val)
  for i, v in ipairs(tbl) do
    if v == val then
      return i
    end
  end
  return nil
end

--- Deep copies a Lua table. Handles nested tables, not functions or userdata.
--- Uses vim.deepcopy if available (Neovim 0.7+).
---@param original_table table
---@return table
function M.deepcopy(original_table)
  if vim.deepcopy then
    return vim.deepcopy(original_table)
  end
  -- Simple fallback for older Neovim or if vim.deepcopy is not trusted for some reason
  local copy = {}
  for k, v in pairs(original_table) do
    if type(v) == "table" then
      copy[k] = M.deepcopy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

--- Converts a palette ID and slot number into a final hex color string.
--- Uses hsluv for generating shades based on config.
---@param palette_id string E.g., "VID".
---@param slot_number number E.g., 1, 12, 25.
---@param current_config table The merged (default + user) plugin configuration.
---@return string Hex color string (e.g., "ff5555", without '#').
function M.slot_to_hex(palette_id, slot_number, current_config)
  local palette_def = current_config.palette_definitions[palette_id]
  if not palette_def then
    M.notify_message("Unknown palette: " .. palette_id, vim.log.levels.ERROR, "NumHi Error")
    return "000000" -- Fallback color
  end

  local base_color_index = ((slot_number - 1) % 10) + 1
  local base_hex = palette_def[base_color_index]
  if not base_hex then
     M.notify_message("Invalid base color index for slot " .. slot_number .. " in palette " .. palette_id, vim.log.levels.WARN, "NumHi Warning")
     base_hex = palette_def[1] or "ffffff" -- Fallback to first color or white
  end

  local shade_tier = math.floor((slot_number - 1) / 10)

  if shade_tier == 0 then -- Base color (slots 1-10)
    return base_hex
  end

  -- For slots > 10, generate lighter/darker shades
  -- This example implements lighter shades for tiers 1, 2, ...
  -- Darker shades could be tier -1, -2, ... or higher slot numbers like 91-99
  local h, s, l = unpack(hsluv.hex_to_hsluv("#" .. base_hex))

  local shade_config = current_config.shade_config
  local L_MAX = 98 -- Max lightness to avoid pure white where fg contrast is impossible
  local L_MIN = 10 -- Min lightness to avoid pure black

  if slot_number > 10 and slot_number <= 10 + shade_config.count_per_base * 10 then -- Lighter shades
    -- shade_tier 1 for slots 11-19, tier 2 for 21-29, etc.
    -- Each tier applies the light_step cumulatively
    l = math.min(L_MAX, l + shade_tier * shade_config.light_step)
  -- Example for darker shades (e.g., slots 91-99 could be tier 1 dark for base colors 1-9)
  -- elseif slot_number >= 91 and slot_number <= 99 then -- Darker shades
  --   local dark_tier = math.floor((slot_number - 91) / 1) + 1 -- Or some other logic
  --   l = math.max(L_MIN, l - dark_tier * shade_config.dark_step)
  else
    -- If slot is out of defined shading tiers, could cycle lightness or clamp
    -- For simplicity, let's just use the highest defined lighter shade for now
     l = math.min(L_MAX, l + shade_config.count_per_base * shade_config.light_step)
  end

  return hsluv.hsluv_to_hex({ h, s, l }):sub(2) -- Strip '#'
end

--- Calculates a contrasting foreground (black or white) for a given background hex color.
---@param bg_hex_string string Background hex color (e.g., "ff5555", without '#').
---@return string Foreground hex color ("#000000" or "#ffffff").
function M.contrast_fg(bg_hex_string)
  local r = tonumber(bg_hex_string:sub(1, 2), 16) / 255
  local g = tonumber(bg_hex_string:sub(3, 4), 16) / 255
  local b = tonumber(bg_hex_string:sub(5, 6), 16) / 255
  -- Formula for perceived brightness (YIQ)
  local yiq = r * 0.299 + g * 0.587 + b * 0.114
  return (yiq >= 0.5) and "#000000" or "#ffffff" -- Threshold might need adjustment
end

--- Ensures a highlight group (e.g., "NumHi_VID_1") exists with correct fg/bg colors.
---@param palette_id string The palette ID (e.g., "VID").
---@param slot_number number The slot number (1-99).
---@param current_config table The full plugin configuration table.
---@return string The name of the highlight group.
function M.ensure_hl_group(palette_id, slot_number, current_config)
  local group_name = string.format("NumHi_%s_%d", palette_id, slot_number)
  -- Check if highlight group already exists to avoid re-defining it unnecessarily
  -- Note: hlexists might not be perfectly efficient if called extremely frequently,
  -- but for on-demand highlight creation/application, it's generally fine.
  -- A cache could be used if this becomes a bottleneck.
  if fn.hlexists(group_name) == 0 then
    local bg_hex = M.slot_to_hex(palette_id, slot_number, current_config)
    local fg_hex = M.contrast_fg(bg_hex)
    api.nvim_set_hl(0, group_name, { bg = "#" .. bg_hex, fg = fg_hex })
  end
  return group_name
end


return M

