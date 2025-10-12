Okay, I've reviewed the search results. Here's a summary of relevant findings:

- **PDF Highlighting/Annotation in Neovim:**
  - `wbthomason/pdf-scribe.nvim` () can extract annotations (highlight, underline, pop-up) and metadata from PDFs. It uses LuaJIT and Poppler. It's designed to create and update plain-text notes based on PDF content and annotations. This doesn't seem to be about _adding_ highlights directly _from_ Neovim onto a PDF visual representation _within_ Neovim, but rather about working with existing annotations and metadata. The user's latest stance is "I’m not interested in either of those two bits of functionality [web or PDF related]" due to lack of robust viewers. So, PDF features will remain a low-priority "Advanced Idea."
- **Neovim Notification Libraries:**
  - `rcarriga/nvim-notify` () is a popular, fancy, and configurable notification manager. It supports updating existing notifications and can be used asynchronously. This aligns with the user's request for a notification system like `nvim-notify` or `snacks.nvim`.
- **Side-car Data Storage:**
  - The common convention is to store plugin data in a file under `vim.fn.stdpath('data')` or `vim.fn.stdpath('cache')`. For Neovim, `vim.fn.stdpath('data')` often resolves to `~/.local/share/nvim/` and `vim.fn.stdpath('cache')` to `~/.cache/nvim/`. Creating a subdirectory for the plugin (e.g., `~/.local/share/nvim/numhi/`) is a good practice. The user specifically requested JSON/YAML in a hidden directory in the _working directory_ of the annotated file. This is a different approach (project-local storage vs. global plugin data/cache). I'll need to clarify if "hidden directory" means a dot-prefixed directory (e.g., `.numhi_data/`) within the project.
- **Telescope/FZF Customization:**
  - Telescope is highly extendable. You can change mappings for pickers using `attach_mappings` to perform custom actions with the selected entry. `fzf-lua` is another alternative that is now default in LazyVim. The user specifically mentioned Telescope/FZF, so I should aim for Telescope integration. There are examples of creating custom pickers with finders, sorters, and previewers.
- **Non-destructive URL/Link Stripping:**
  - While no specific plugin for _just_ non-destructive stripping was immediately found, plugins like `jakewvincent/mkdnflow.nvim` () deal with Markdown link manipulation, which could offer ideas. This feature seems more about text processing within a buffer, possibly using Lua patterns or Tree-sitter queries to identify URLs and then replace them with placeholder text or store them elsewhere, with a command to restore them. This is a more involved feature that might be best handled by a dedicated function or a separate small utility if it's complex. For now, I will focus on the core highlighting and notes.

Based on this, I will proceed with the plugin development. The PDF aspect will be kept in mind as a future possibility but not a primary goal for now, aligning with the user's mixed signals but leaning towards the "not interested for now" part due to viewer limitations. The storage will be project-local as requested.

Let's begin with the first file, `config.lua`. This file will centralize default configurations and palette data, making it easier for other modules to access them.

---

## File 1: `lua/numhi/config.lua`

### Design:

This file will replace the existing `palettes.lua` and also hold the default configuration options for the NumHi plugin. This centralizes static data and default settings, making it easier to manage and for other modules to reference.

1.  **`M.default_opts` Table:**

    - This table will store all default configurable options for the plugin.
    - Based on `NumHi_OverviewOfDesiredFeatures.md`, `Project Numhi context bomb starter text.md`, and the existing `init.lua`:
      - `palettes`: A list of palette IDs (e.g., `{"VID", "PAS", "EAR", "MET", "CYB"}`).
      - `palette_definitions`: A table holding the actual color hex codes for each palette and its 10 base slots. This will absorb the contents of the old `palettes.lua`.
      - `key_leader`: Default key leader for NumHi mappings (e.g., `"<leader><leader>"`).
      - `statusline`: Boolean to enable/disable statusline component.
      - `history_max`: Maximum number of undo/redo operations.
      - `hover_delay`: Milliseconds before a hover tooltip appears.
      - `storage_dir_name`: Name for the project-local hidden directory for storing notes/highlights (e.g., `".numhi_data"`).
      - `notes_file_name`: Name of the JSON/YAML file for notes within the storage directory (e.g., `notes.json`).
      - `tags_file_name`: Name of the file for tags (e.g., `tags.json`).
      - `note_window_width_ratio`: Ratio of `vim.o.columns` for the note window width (e.g., `0.6`).
      - `note_window_height_ratio`: Ratio of `vim.o.lines` for the note window height (e.g., `0.4`).
      - `shade_step_light`: Percentage step for generating lighter shades (e.g., `6` for +6L in HSLuv).
      - `shade_step_dark`: Percentage step for generating darker shades (e.g., `5` for -5L in HSLuv).
      - `echo_on_highlight`: Boolean, whether to echo highlight info upon creation.
      - `notify_on_highlight`: Boolean, whether to use `vim.notify` for highlight info.
      - `auto_save_notes`: Boolean, whether to auto-save notes when closing the note window or losing focus.
      - `s_reader_font_size`, `s_reader_colors`, `s_reader_spacing`: For the S-Reader mode (advanced feature, define defaults).

2.  **Palette Structure (`palette_definitions`):**

    - The structure will be `M.default_opts.palette_definitions[PALETTE_ID] = { "hex1", "hex2", ..., "hex10" }`.
    - Hex codes will be strings _without_ the leading `#`.
    - The user mentioned reviewing palettes for "oversimilarity." I will use the provided palettes but add a comment noting this concern for the user to adjust if needed.

3.  **`M.state` Placeholder (Conceptual):**

    - While the actual runtime state will be managed in `init.lua` or `core.lua`, `config.lua` will only define the _default structure_ of options. The actual merged options (defaults + user overrides) will be stored in a state table elsewhere.

4.  **Return Value:**
    - The module will return the `M.default_opts` table. Other modules will `require` this file to get these defaults and palette data. The main `init.lua` will handle merging user options with these defaults.

This approach keeps the configuration static and clearly separated from runtime state, improving maintainability.

```lua
-- ~/.config/nvim/lua/numhi/config.lua

---@class NumHiDefaultOptions
---@field palettes string[] List of palette IDs (e.g., {"VID", "PAS", ...}).
---@field palette_definitions table<string, string[]> Hex color codes for each palette's 10 base slots.
---@field key_leader string Default key leader for NumHi mappings.
---@field statusline boolean Enable/disable statusline component.
---@field history_max number Maximum number of undo/redo operations.
---@field hover_delay number Milliseconds before a hover tooltip appears.
---@field storage_dir_name string Name for the project-local hidden directory (e.g., ".numhi_data").
---@field highlights_file_name string Name of the JSON file for highlights within the storage directory.
---@field notes_file_name string Name of the JSON file for notes within the storage directory.
---@field note_window_width_ratio number Ratio of vim.o.columns for the note window width.
---@field note_window_height_ratio number Ratio of vim.o.lines for the note window height.
---@field note_border string Border style for note window (see :h nvim_open_win).
---@field shade_config table { light_step = number, dark_step = number, count_per_base = number }
---                           light_step: HSLuv 'L' increment for lighter shades.
---                           dark_step: HSLuv 'L' decrement for darker shades.
---                           count_per_base: how many light/dark shades per base color (e.g., 10 means base, 9 lighter, 9 darker if possible).
---@field echo_on_highlight boolean Whether to echo highlight info upon creation/cursor hover.
---@field notify_on_highlight_create boolean Whether to use vim.notify when a highlight is created.
---@field auto_save_notes boolean Whether to auto-save notes when closing the note window or BufLeave.
---@field s_reader_font_size number Default font size for S-Reader mode.
---@field s_reader_colors table {fg = string, bg = string} Default colors for S-Reader mode.
---@field s_reader_spacing number Default spacing for S-Reader mode.
---@field highlight_priority number Default priority for extmarks.
---@field delete_mark_prompts_for_note boolean Whether deleting a mark prompts to delete or keep the associated note.
---@field default_markdown_export_template string Default template for Markdown export.
---@field max_slots_per_palette number Maximum number of highlight slots per palette.

local M = {}

---@type NumHiDefaultOptions
M.default_opts = {
  palettes = { "VID", "PAS", "EAR", "MET", "CYB" },
  palette_definitions = {
    -- User reported potential "oversimilarity" in some palettes, especially Earthen.
    -- These may need review and adjustment by the user for better visual distinction.
    VID = { "ff5555", "f1fa8c", "50fa7b", "8be9fd", "bd93f9", "ff79c6", "ffb86c", "8affff", "caffbf", "ffaec9" },
    PAS = { "f8b5c0", "f9d7a1", "f9f1a7", "b8e8d0", "a8d9f0", "d0c4f7", "f5bde6", "c9e4de", "fcd5ce", "e8c8ff" },
    EAR = { "80664d", "a67c52", "73624b", "4d6658", "6d8a6d", "8c7156", "665746", "997950", "595e4a", "726256" },
    MET = { "d4af37", "b87333", "c0c0c0", "8c7853", "b08d57", "aaa9ad", "e6be8a", "9fa2a6", "cd7f32", "a97142" },
    CYB = { "ff2079", "00e5ff", "9dff00", "ff6f00", "ff36ff", "00f6ff", "b4ff00", "ff8c00", "ff40ff", "00ffff" },
  },
  key_leader = "<leader><leader>", -- Example: <Space><Space>
  statusline = true,
  history_max = 100,
  hover_delay = 350, -- ms
  storage_dir_name = ".numhi_data",
  highlights_file_name = "highlights.json", -- Stores highlight definitions (extmark data, linking to notes)
  notes_file_name = "notes.json",          -- Stores note content, mapping highlight_id to note_text
                                           -- Tags could be part of highlights.json or a separate tags.json
  note_window_width_ratio = 0.6,
  note_window_height_ratio = 0.4,
  note_border = "rounded",
  shade_config = {
    light_step = 6, -- Increase Lightness by this amount for each lighter shade
    dark_step = 5,  -- Decrease Lightness by this amount for each darker shade
    count_per_base = 9, -- How many lighter/darker shades to generate (e.g. 9 means total 1+9+9=19 effective colors per base)
                       -- Slots 1-10 are base, 11-19 are lighter1-lighter9, 21-29 darker1-darker9 etc.
                       -- Slot numbers will map to these: e.g. slot 1 is base[1], slot 11 is lighter1 of base[1], slot 21 is darker1 of base[1]
  },
  max_slots_per_palette = 99, -- Max slot number user can input
  echo_on_highlight = true,
  notify_on_highlight_create = false, -- Set to true to use vim.notify on highlight creation
  auto_save_notes = true,
  s_reader_font_size = 12,
  s_reader_colors = { fg = "#FFFFFF", bg = "#000000" },
  s_reader_spacing = 1.5,
  highlight_priority = 100, -- https://neovim.io/doc/user/api.html#nvim_buf_set_extmark()
  delete_mark_prompts_for_note = true,
  default_markdown_export_template = "## Highlights for {filename}\n\n{highlights_content}\n",
}

return M
```

---

Next, I will work on `lua/numhi/utils.lua`. This will hold common helper functions that might be used by multiple modules, like color conversion, string manipulation, or Neovim API wrappers, to avoid code duplication and potential circular dependencies if they were in `core.lua` and also needed by `ui.lua` or `notes.lua`.

### Design: `lua/numhi/utils.lua`

This module will house utility functions that are broadly useful across the NumHi plugin.

1.  **Color Utilities:**

    - `slot_to_hex(palette_id, slot_number, config)`: Converts a palette ID and slot number into a final hex color string (without '#'). This will use `hsluv-lua` for generating shades based on `config.default_opts.palette_definitions` and `config.default_opts.shade_config`.
      - Slots 1-10: Direct from `palette_definitions`.
      - Slots 11-19 (or up to `10 + count_per_base`): Lighter shades of base color 1.
      - Slots 21-29: Lighter shades of base color 2 (or could be darker shades of base 1, need to decide mapping).
      - The user's description mentions "11-20 lighter shades". The existing code has `k = math.floor((slot - 1) / 10)` and `l + (k * 6 - 3)`. This means slots 11-19 are lighter versions of base 1-10 (slot 11 is lighter of base_color_1, slot 12 of base_color_2... slot 21 of base_color_1 again but even lighter). The request "1-10 base colours, 11-20 lighter shades" and the current code `palettes[pal][((slot - 1) % 10) + 1]` suggests a modulo approach for the base color.
      - Let's refine the slot mapping:
        - `base_color_index = ((slot - 1) % 10) + 1`
        - `shade_tier = math.floor((slot - 1) / 10)` (0 for base, 1 for first set of shades, 2 for second, etc.)
        - If `shade_tier == 0`: use base color.
        - If `shade_tier > 0`: generate `shade_tier`-th lighter shade. (e.g. tier 1 = slots 11-20, tier 2 = slots 21-30, etc.)
        - The user also mentioned `11-20 lighter shades …`. This is ambiguous. Let's assume slots 1-10 are base, slots 11-20 are the first tier of lighter shades for base colors 1-10 respectively. Slots 21-30 are the second tier, etc. Darker shades are not explicitly requested for the 11-20 range but could be an extension (e.g. slots 91-99 for darker versions). For now, focus on lighter for 11+.
    - `contrast_fg(bg_hex_string)`: Calculates a contrasting foreground (black or white) for a given background hex color. This is already in the user's `core.lua` and can be moved here.
    - `ensure_hl_group(palette_id, slot_number, config, state)`: Creates or ensures a highlight group (e.g., `NumHi_VID_1`) exists with the correct foreground and background colors. This also uses `slot_to_hex` and `contrast_fg`. The `state` argument will hold the plugin's runtime configuration.

2.  **Extmark/Buffer Utilities:**

    - `get_visual_selection_range()`: Returns `start_pos {line, col}, end_pos {line, col}` (0-indexed) for the last visual selection. Handles cases where marks might not be set.
    - `get_word_under_cursor_range(bufnr, winid)`: Returns `start_col, end_col` (0-indexed) for the word under the cursor. The user's `core.lua` has `word_range`, which seems to be 0-indexed for columns.
    - `get_line_text(bufnr, lnum_0_indexed)`: Gets text of a specific line.
    - `get_cursor_pos_0_indexed()`: Returns `{line, col}` 0-indexed.
    - `is_position_within_extmark(pos_0_indexed, mark_start_pos_0_indexed, mark_end_pos_0_indexed)`: Checks if `{line, col}` is within the extmark's range (inclusive start, exclusive end for columns on the same line).

3.  **UI Utilities:**

    - `echo_message(chunks_or_string, hl_group)`: A wrapper around `vim.api.nvim_echo` to simplify showing messages. Handles plain strings or pre-formatted chunks. This is in the user's `core.lua`.
    - `notify_message(message, level, opts)`: A wrapper for `vim.notify`. `level` could be `vim.log.levels.INFO`, `ERROR`, etc. `opts` for title.

4.  **Filesystem Utilities:**

    - `get_project_root()`: Tries to determine the project root (e.g., by finding a `.git` directory or using LSP information if available). This is important for project-local storage.
    - `ensure_dir_exists(path)`: Creates a directory if it doesn't exist.

5.  **General Lua Utilities:**
    - `uuid()`: Generates a simple UUID string for unique highlight/note IDs.
    - `index_of(tbl, val)`: Finds the index of a value in a list-like table. (From user's `core.lua`)
    - `deepcopy(orig_table)`: A simple deepcopy for tables (needed for history or state manipulation). `vim.deepcopy()` is available in Nvim 0.7+.

This module will depend on `hsluv` (which the user has in their dependencies) and the `config.lua` module for default palette definitions and shade configurations.

```lua
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
    return fn.mkdir(path, "p") == 0 -- mkdir returns 0 on success
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
```

Next, I will create `lua/numhi/storage.lua`. This module will be responsible for loading and saving highlight and note data to/from the filesystem, using JSON as the storage format in a project-local hidden directory.

### Design: `lua/numhi/storage.lua`

This module will handle all file I/O operations for NumHi, specifically for persisting highlights and notes. It will use JSON format and store data in a project-local directory (e.g., `.numhi_data/` inside the current project).

1.  **Core Data Structures (Conceptual - for storage format):**

    - **Highlights File (`highlights.json`):** An object where keys are buffer file paths (full paths). Each value is another object where keys are `highlight_uuid`s. Each highlight entry will store:
      - `uuid`: Unique ID for the highlight.
      - `palette_id`: e.g., "VID".
      - `slot`: Slot number (1-99).
      - `label`: User-defined label for this `palette_id`+`slot` combination (this might be better stored globally or per-project rather than per-highlight if it's truly for the color category). The request "Echo line shows palette-code + slot + custom label" and "naming each color on the first use" suggests the label is tied to the palette-slot, not individual highlight instance. Let's clarify: `user_data` in context bomb has `label` for gutter. The user's `core.lua` `get_label` stores `State.labels[pal][slot]`. This is a category label. So, highlights themselves won't store the label directly, but the `palette_id` and `slot` will allow lookup.
      - `start_line`, `start_col`, `end_line`, `end_col`: 0-indexed range.
      - `tags`: An array of strings.
      - `created_at`: Timestamp.
      - `updated_at`: Timestamp.
      - `note_id`: A UUID linking to a note in `notes.json` (if a note exists).
    - **Notes File (`notes.json`):** An object where keys are `note_uuid`s (matching `note_id` in highlights). Each value is an object:
      - `uuid`: The note's own UUID.
      - `content`: The Markdown string content of the note.
      - `created_at`: Timestamp.
      - `updated_at`: Timestamp.
      - `highlight_uuids`: An array of highlight UUIDs this note is attached to (initially one, but could support attaching one note to multiple highlights in the future, though current request is "unique note to any individual highlight"). For now, let's assume one-to-one, so perhaps `highlight_uuid` (singular). The request "attach a **single Markdown note** to each highlight" and "notes must be **unique** to the specific highlight they attach to" confirms one-to-one. So, `highlight_uuid` is fine.

2.  **Functions:**

    - `get_storage_path(config)`:
      - Determines the project root using `utils.get_project_root()`.
      - Constructs the path to `.numhi_data` (or `config.storage_dir_name`).
      - Uses `utils.ensure_dir_exists()` to create it if it doesn't exist.
      - Returns the path to this storage directory.
    - `load_data_for_buffer(bufnr, config, state)`:
      - Gets the full path of the current buffer.
      - Constructs paths to `highlights.json` and `notes.json` within the project's storage directory.
      - Reads and parses these JSON files.
      - Populates `state.highlights_by_buffer[buffer_path]` and `state.notes_by_id` (or similar structures in the global plugin state).
      - Handles file-not-found or JSON parsing errors gracefully (e.g., return empty data).
      - This function will be called when a buffer is loaded or when the plugin initializes.
    - `save_data_for_buffer(bufnr, config, state)`:
      - Gets the full path of the current buffer.
      - Retrieves highlight and relevant note data from the plugin's runtime `state`.
      - Serializes this data to JSON.
      - Writes to `highlights.json` and `notes.json` in the project's storage directory.
      - This needs to be efficient. Writing the whole file for every change might be too slow for `highlights.json`. It might be better to save only the data for the current buffer into its own file within the storage directory, e.g., `storage_dir/<escaped_buffer_filepath>.json`. Or, if keeping a single `highlights.json`, ensure atomic writes or careful merging.
      - The user's request mentions "side-car **per project** (or global)". Let's stick to per-project for now. A single `highlights.json` and `notes.json` per project seems manageable. We'd update the relevant buffer's entries in the project-wide `highlights.json`.
    - `add_or_update_highlight(buffer_path, highlight_data, config, state)`: Adds/updates a single highlight in `state` and queues/triggers a save.
    - `remove_highlight(buffer_path, highlight_uuid, config, state)`: Removes a highlight from `state` and queues/triggers a save. Also handles associated note (prompt for deletion based on config).
    - `add_or_update_note(note_data, config, state)`: Adds/updates a note in `state` and queues/triggers a save.
    - `remove_note(note_uuid, config, state)`: Removes a note.

3.  **JSON Handling:**

    - Will use `vim.fn.json_encode()` and `vim.fn.json_decode()`. Need to handle potential errors.

4.  **Error Handling and Edge Cases:**

    - Permissions issues when creating directories or files.
    - Corrupt JSON files.
    - Buffer not having a file path (e.g., scratch buffers) - highlights for these might be in-memory only or stored under a special key. The request "local files" implies named files.

5.  **Dependencies:**
    - `utils.lua` for `get_project_root`, `ensure_dir_exists`, `uuid`.
    - `config.lua` for storage directory/file names.

This module forms the persistence layer, crucial for making highlights and notes useful across sessions. The user mentioned an issue: "Notes not actually persisted across sessions. No file I/O; data stays only in extmark memory." This module directly addresses that.

```lua
-- ~/.config/nvim/lua/numhi/storage.lua

local utils = require("numhi.utils")
local api = vim.api
local fn = vim.fn

local M = {}

-- Internal helper to get the full path to a specific data file (highlights or notes)
---@param file_type "highlights" | "notes"
---@param plugin_config table The NumHi plugin's current configuration.
---@param project_root_override string? Optional project root to use instead of auto-detecting.
---@return string|nil Path to the data file, or nil if project root cannot be determined.
local function get_data_file_path(file_type, plugin_config, project_root_override)
  local project_root = project_root_override or utils.get_project_root()
  if not project_root then
    utils.notify_message("NumHi: Could not determine project root for storage.", vim.log.levels.WARN)
    return nil
  end

  local storage_dir = project_root .. "/" .. plugin_config.storage_dir_name
  if not utils.ensure_dir_exists(storage_dir) then
    utils.notify_message("NumHi: Could not create storage directory: " .. storage_dir, vim.log.levels.ERROR)
    return nil
  end

  local file_name
  if file_type == "highlights" then
    file_name = plugin_config.highlights_file_name
  elseif file_type == "notes" then
    file_name = plugin_config.notes_file_name
  else
    utils.notify_message("NumHi: Unknown data file type requested: " .. file_type, vim.log.levels.ERROR)
    return nil
  end

  return storage_dir .. "/" .. file_name
end

--- Reads data from a JSON file.
---@param file_path string Full path to the JSON file.
---@return table Parsed JSON data as a Lua table, or an empty table on error/file not found.
local function read_json_file(file_path)
  if fn.filereadable(file_path) == 0 then
    return {} -- File doesn't exist, return empty data
  end

  local content_lines, read_err = fn.readfile(file_path, "b") -- Read as binary to handle potential encoding issues better
  if read_err or not content_lines then
    utils.notify_message("NumHi: Error reading file: " .. file_path .. (read_err and (": " .. read_err) or ""), vim.log.levels.ERROR)
    return {}
  end

  local content_str = table.concat(content_lines, "\n")
  if content_str == "" then return {} end -- Empty file

  local ok, data = pcall(fn.json_decode, content_str)
  if not ok or type(data) ~= "table" then
    utils.notify_message("NumHi: Error decoding JSON from " .. file_path .. (data and (": " .. tostring(data)) or ""), vim.log.levels.ERROR)
    -- Potentially try to back up the corrupted file here
    return {}
  end
  return data
end

--- Writes data to a JSON file.
---@param file_path string Full path to the JSON file.
---@param data table Lua table to serialize and write.
---@return boolean True on success, false on failure.
local function write_json_file(file_path, data)
  local json_string, encode_err = pcall(fn.json_encode, data)
  if not json_string or encode_err then -- encode_err will be true if pcall caught an error
     utils.notify_message("NumHi: Error encoding data to JSON for " .. file_path .. (encode_err and (": " .. tostring(encode_err)) or ""), vim.log.levels.ERROR)
    return false
  end

  -- Atomically write by writing to a temp file then renaming
  local temp_file_path = file_path .. ".tmp"
  local write_ok, write_err = pcall(fn.writefile, {json_string}, temp_file_path, "b")

  if not write_ok then
    utils.notify_message("NumHi: Error writing to temporary file: " .. temp_file_path .. (write_err and (": " .. tostring(write_err)) or ""), vim.log.levels.ERROR)
    fn.delete(temp_file_path) -- Attempt to clean up temp file
    return false
  end

  -- Rename temp file to actual file path
  -- On Windows, os.rename might fail if the destination exists.
  -- Lua's os.rename behavior is platform-dependent for overwriting.
  -- A safer approach might be to delete original then rename, or use platform-specific move.
  -- For now, let's assume os.rename overwrites or Neovim's fn.rename handles it.
  -- fn.rename() is not available in Lua 5.1 context directly without vim.loop or os.rename
  local rename_ok, rename_err
  if fn.has("win32") then
    -- On Windows, delete target first if it exists
    if fn.filereadable(file_path) == 1 then
      fn.delete(file_path)
    end
  end
  rename_ok, rename_err = pcall(fn.rename, temp_file_path, file_path)

  if not rename_ok then
     utils.notify_message("NumHi: Error renaming temp file to " .. file_path .. (rename_err and (": " .. rename_err) or ""), vim.log.levels.ERROR)
    fn.delete(temp_file_path) -- Attempt to clean up temp file
    return false
  end

  return true
end

--- Loads all highlights for the current project.
---@param plugin_config table The NumHi plugin's current configuration.
---@return table A table mapping buffer paths to their highlight data.
function M.load_all_highlights(plugin_config)
  local highlights_file = get_data_file_path("highlights", plugin_config)
  if not highlights_file then return {} end
  return read_json_file(highlights_file)
end

--- Saves all highlights for the current project.
---@param all_highlights_data table Data for all highlights in the project.
---@param plugin_config table The NumHi plugin's current configuration.
---@return boolean Success status.
function M.save_all_highlights(all_highlights_data, plugin_config)
  local highlights_file = get_data_file_path("highlights", plugin_config)
  if not highlights_file then return false end
  return write_json_file(highlights_file, all_highlights_data)
end

--- Loads all notes for the current project.
---@param plugin_config table The NumHi plugin's current configuration.
---@return table A table mapping note UUIDs to their note data.
function M.load_all_notes(plugin_config)
  local notes_file = get_data_file_path("notes", plugin_config)
  if not notes_file then return {} end
  return read_json_file(notes_file)
end

--- Saves all notes for the current project.
---@param all_notes_data table Data for all notes.
---@param plugin_config table The NumHi plugin's current configuration.
---@return boolean Success status.
function M.save_all_notes(all_notes_data, plugin_config)
  local notes_file = get_data_file_path("notes", plugin_config)
  if not notes_file then return false end
  return write_json_file(notes_file, all_notes_data)
end


--- Gets the buffer-specific key for storing/retrieving highlights.
--- Currently uses the full buffer path.
--- Returns nil if buffer is not associated with a file.
---@param bufnr number Buffer handle (0 for current).
---@return string|nil Buffer path or nil.
function M.get_buffer_storage_key(bufnr)
  bufnr = bufnr or 0
  local buf_name = api.nvim_buf_get_name(bufnr)
  if buf_name == "" then
    -- For unnamed buffers, we might not save, or save under a special key if desired.
    -- For now, only save for named buffers.
    return nil
  end
  return fn.fnamemodify(buf_name, ":p") -- Get full path
end


-- Example of how these might be integrated into plugin state management:
-- (This part would typically be in core.lua or init.lua)
--
-- local plugin_state = {
--   highlights_by_buffer = {}, -- Keyed by full buffer path
--   notes_by_id = {},          -- Keyed by note_uuid
--   config = {},               -- Loaded plugin config
-- }
--
-- function load_for_buffer(bufnr)
--   local buffer_key = M.get_buffer_storage_key(bufnr)
--   if not buffer_key then return end
--
--   -- This assumes highlights_by_buffer and notes_by_id are already populated
--   -- for the entire project by an initial load call (e.g., in plugin setup).
--   -- Or, if loading lazily per buffer from separate files:
--   -- plugin_state.highlights_by_buffer[buffer_key] = M.load_highlights_for_buffer_file(buffer_key, plugin_state.config)
--   -- apply_extmarks_from_loaded_data(bufnr, plugin_state.highlights_by_buffer[buffer_key] or {})
-- end

-- function save_all_data_for_project()
--   M.save_all_highlights(plugin_state.highlights_by_buffer, plugin_state.config)
--   M.save_all_notes(plugin_state.notes_by_id, plugin_state.config)
-- end

return M
```

Next, I will focus on `lua/numhi/core.lua`. This is where the main highlighting logic, extmark management, palette cycling, and history (undo/redo) will reside. It will use `config.lua` for settings, `utils.lua` for helpers, and `storage.lua` for persistence triggers.

### Design: `lua/numhi/core.lua`

This module is the engine of NumHi. It handles the creation, deletion, and management of highlights (extmarks), palette operations, and undo/redo history.

1.  **State Management (within `core.lua` or passed from `init.lua`):**

    - `active_palette`: Current palette ID.
    - `highlight_history`: For undo. Stores `{buffer_key, palette_id, slot, extmark_id, uuid, note_id, tags, range_data, user_data_backup}`.
    - `redo_stack`: For redo.
    - `ns_ids`: Table mapping `palette_id` to `namespace_id` for extmarks.
    - `category_labels`: Table mapping `palette_id -> slot_number -> label_string`.
    - `highlights_data`: In-memory representation of all highlights loaded from storage, keyed by buffer path, then by highlight UUID. `plugin_state.highlights_by_buffer[buffer_path][highlight_uuid] = {data}`.
    - `notes_data`: In-memory representation of notes, keyed by note UUID. `plugin_state.notes_by_id[note_uuid] = {data}`.
    - `plugin_config`: The merged plugin configuration.

2.  **Initialization (`C.setup(plugin_config, plugin_state)`):**

    - Store references to global plugin config and state.
    - Create Neovim namespaces for each palette ID defined in `plugin_config.palettes`. Store these in `ns_ids`.
    - Load existing highlights and notes for the project using `storage.load_all_highlights` and `storage.load_all_notes`.
    - (Potentially) Apply highlights to currently open and relevant buffers.

3.  **Highlight Creation (`C.create_highlight(slot_number, custom_label_override)`):**

    - Determine range: visual selection (from `utils.get_visual_selection_range`) or word under cursor (from `utils.get_word_under_cursor_range`).
    - Get current `active_palette` and `bufnr`.
    - Generate a UUID for the new highlight using `utils.uuid()`.
    - Prompt for category label if this `palette_id`+`slot` is new for the session or if no label exists in `category_labels`, using `vim.ui.input`. Store it.
    - Get the highlight group name using `utils.ensure_hl_group()`.
    - Create extmark(s) using `api.nvim_buf_set_extmark()`.
      - The `user_data` for the extmark should be minimal, perhaps just the `highlight_uuid`. `user_data = { numhi_uuid = "..." }`. Other data (palette, slot, tags, note_id) will be in the `highlights_data` table, linked by this UUID. This keeps extmark data light.
      - Support multi-line highlights by iterating lines in visual selection.
      - `hl_eol = true` if the highlight extends to the end of the line.
      - Set `priority` from config.
    - Store highlight metadata in `highlights_data[buffer_key][highlight_uuid]`: `{ uuid, palette_id, slot, start_line, start_col, end_line, end_col, tags = {}, note_id = nil, created_at, updated_at }`.
    - Add to `highlight_history` for undo.
    - Trigger save using `storage.save_all_highlights()`.
    - Echo/notify based on config.

4.  **Highlight Deletion (`C.delete_highlight_at_cursor()` or `C.delete_highlight_by_uuid(uuid)`):**

    - Find highlight(s) at cursor or by UUID. This involves checking all NumHi namespaces.
    - For each found highlight:
      - Get its UUID from `user_data`.
      - Remove extmark using `api.nvim_buf_del_extmark()`.
      - Retrieve full highlight data from `highlights_data`.
      - Add to `highlight_history` for undo (as a "delete" operation type).
      - If `note_id` exists and `config.delete_mark_prompts_for_note` is true:
        - Prompt user: "Delete associated note?" (Yes/No/Keep Unlinked).
        - If Yes, call `notes.delete_note(note_id)`.
        - If Keep Unlinked, mark the note as orphaned or handle as needed.
      - Remove from `highlights_data`.
    - Trigger save.

5.  **Highlight Information (`C.get_highlight_info_at_cursor()`):**

    - Iterate through all NumHi namespaces (`ns_ids`).
    - Use `api.nvim_buf_get_extmarks()` for the cursor position. Check if the cursor is _within_ any part of an existing highlight (use `utils.is_position_within_extmark`).
    - If a highlight is found:
      - Extract `highlight_uuid` from its `user_data`.
      - Retrieve full data from `highlights_data`.
      - Retrieve category label from `category_labels`.
      - Return a comprehensive info table: `{ palette_id, slot, label, tags, note_id, range, uuid }`.
    - This will be used by UI functions for echo/tooltips.

6.  **Palette Cycling (`C.cycle_palette(direction)`):**

    - Update `active_palette`.
    - Show transient notification (calls a `ui.show_palette_notification` function).
    - Update statusline component if enabled.

7.  **Undo/Redo (`C.undo()`, `C.redo()`):**

    - `undo`: Pop from `highlight_history`. If it was a creation, delete the extmark and restore data to `redo_stack`. If it was a deletion, re-create the extmark and data.
    - `redo`: Similar logic with `redo_stack`.
    - These operations need to carefully manage both extmarks and the data in `highlights_data` and potentially `notes_data`.
    - Trigger save after undo/redo.

8.  **Loading/Applying Highlights for a Buffer (`C.apply_highlights_to_buffer(bufnr)`):**

    - Called on `BufEnter` or after initial load.
    - Get `buffer_key` using `storage.get_buffer_storage_key()`.
    - Retrieve highlights for this `buffer_key` from `highlights_data`.
    - Iterate and re-apply extmarks using `api.nvim_buf_set_extmark()`. Ensure `id` field in extmark options is _not_ set if we want Neovim to assign new ones, or manage IDs carefully if they need to be stable across reloads (UUIDs are for data, extmark IDs are integers assigned by Neovim per buffer session). Storing Neovim's extmark ID is fragile. It's better to re-apply based on stored ranges and get new extmark IDs, linking them via the UUID in `user_data`.

9.  **Tag Management (`C.add_tag_to_highlight_at_cursor(tag_string)`, `C.remove_tag_from_highlight_at_cursor(tag_string)`):**

    - Find highlight at cursor.
    - Update its `tags` array in `highlights_data`.
    - Trigger save.
    - Update visual representation if multi-color/corner swatches are implemented (advanced).

10. **Digit Collector (`C.collect_digits_for_highlight()`):**
    - Similar to the user's existing code but calls `C.create_highlight(slot_number)`.
    - Uses `utils.echo_message` for prompting.

This structure aims to separate concerns: `core` manages the logic and in-memory state, `storage` handles disk I/O, `utils` provides stateless helpers, and `config` provides static data.

```lua
-- ~/.config/nvim/lua/numhi/core.lua

local utils = require("numhi.utils")
local storage = require("numhi.storage")
-- local notes_manager = require("numhi.notes") -- Will be used later
local api = vim.api
local fn = vim.fn

local C = {}

-- Module-level state, initialized by setup
local M = {
  plugin_config = {}, -- Merged (default + user) options
  ns_ids = {}, -- palette_id -> namespace_id
  active_palette_id = "",
  -- In-memory data stores
  highlights_by_buffer = {}, -- buffer_key -> { highlight_uuid -> highlight_obj }
  notes_by_id = {},          -- note_uuid -> note_obj
  category_labels = {},      -- palette_id -> slot_num -> label_string
  -- History for undo/redo
  -- Each entry: {action="create"|"delete"|"update_note"|"update_tags", buffer_key, data=highlight_or_note_obj_before_change}
  -- For "create", data is the created highlight_uuid. For "delete", data is the full highlight_obj.
  history = {},
  redo_stack = {},
}

local function get_buffer_key(bufnr)
  return storage.get_buffer_storage_key(bufnr or 0)
end

--- Adds an operation to the undo history.
local function add_history_entry(entry)
  table.insert(M.history, entry)
  if #M.history > M.plugin_config.history_max then
    table.remove(M.history, 1)
  end
  M.redo_stack = {} -- Clear redo stack on new action
end

--- Saves all current data to disk.
local function save_all_data()
  storage.save_all_highlights(M.highlights_by_buffer, M.plugin_config)
  storage.save_all_notes(M.notes_by_id, M.plugin_config)
  -- TODO: Save category_labels if they are meant to be persistent per project.
  -- For now, category_labels are session-local or need manual setup.
end

--- Applies extmarks for a given buffer from the loaded highlight data.
---@param bufnr number
function C.apply_highlights_to_buffer(bufnr)
  local buffer_key = get_buffer_key(bufnr)
  if not buffer_key or not M.highlights_by_buffer[buffer_key] then
    return
  end

  for _, hl_obj in pairs(M.highlights_by_buffer[buffer_key]) do
    local ns_id = M.ns_ids[hl_obj.palette_id]
    if ns_id then
      local hl_group = utils.ensure_hl_group(hl_obj.palette_id, hl_obj.slot, M.plugin_config)
      -- We need to re-create the extmark. The original extmark ID is not persistent.
      -- The UUID is the persistent link.
      local extmark_opts = {
        end_row = hl_obj.end_line,
        end_col = hl_obj.end_col,
        hl_group = hl_group,
        hl_eol = (hl_obj.end_col == -1 or hl_obj.end_col >= #utils.get_line_text(bufnr, hl_obj.end_line)),
        priority = M.plugin_config.highlight_priority,
        user_data = { numhi_uuid = hl_obj.uuid },
        -- Neovim assigns a new extmark_id here
      }
      api.nvim_buf_set_extmark(bufnr, ns_id, hl_obj.start_line, hl_obj.start_col, extmark_opts)
    end
  end
end

--- Loads data for the current session.
function C.load_all_project_data()
    M.highlights_by_buffer = storage.load_all_highlights(M.plugin_config) or {}
    M.notes_by_id = storage.load_all_notes(M.plugin_config) or {}
    -- TODO: Load category_labels if they are persistent.
end


--- Setup function, called from init.lua
---@param plugin_opts table User-provided options, merged with defaults.
function C.setup(plugin_opts)
  M.plugin_config = plugin_opts
  M.active_palette_id = M.plugin_config.palettes[1] or ""

  for _, pal_id in ipairs(M.plugin_config.palettes) do
    M.ns_ids[pal_id] = api.nvim_create_namespace("numhi_" .. pal_id)
    M.category_labels[pal_id] = M.category_labels[pal_id] or {}
  end

  C.load_all_project_data()

  -- Apply to currently open buffers that are named
  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(bufnr) and get_buffer_key(bufnr) then
      C.apply_highlights_to_buffer(bufnr)
    end
  end
end

--- Gets or prompts for a category label for a given palette and slot.
---@param palette_id string
---@param slot_number number
---@return string The label string (can be empty).
local function get_category_label(palette_id, slot_number)
  M.category_labels[palette_id] = M.category_labels[palette_id] or {}
  local label = M.category_labels[palette_id][slot_number]

  if not label then
    local prompt_text = string.format("NumHi Label for %s-%d (leave empty for none):", palette_id, slot_number)
    local input = vim.ui.input({ prompt = prompt_text, default = "" }, function(text)
      -- Callback is async, so we can't directly return the value here.
      -- The label will be set if user provides input.
      -- For immediate use, it might be initially empty then fill in.
      -- This is a common challenge with vim.ui.input.
      -- For now, this means the first application might not have the label in `user_data`
      -- if it's fetched synchronously after this call.
      if text ~= nil then -- Can be empty string
        M.category_labels[palette_id][slot_number] = text
        -- If we need to update extmarks that were just created with this new label,
        -- we'd need a mechanism to do that.
      end
    end)
    -- Due to async nature, for the very first creation, label might be effectively ""
    -- until the callback fires. Subsequent creations will find it.
    -- For simplicity here, we'll proceed with potentially no label on first go.
    -- A more robust solution would involve yielding or a promise if label is critical for first extmark.
    return "" -- Or a placeholder until callback
  end
  return label
end


--- Creates a new highlight based on current selection or word under cursor.
---@param slot_number number The palette slot number (1-99).
function C.create_highlight(slot_number)
  slot_number = tonumber(slot_number)
  if not slot_number or slot_number < 1 or slot_number > M.plugin_config.max_slots_per_palette then
    utils.echo_message("NumHi: Invalid slot number: " .. tostring(slot_number), "ErrorMsg")
    return
  end

  local bufnr = 0 -- Current buffer
  local buffer_key = get_buffer_key(bufnr)
  if not buffer_key then
    utils.echo_message("NumHi: Cannot highlight in unnamed buffer.", "WarningMsg")
    return
  end

  local palette_id = M.active_palette_id
  local ns_id = M.ns_ids[palette_id]
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
    if not word_s then
      utils.echo_message("NumHi: Could not determine word under cursor.", "WarningMsg")
      return
    end
    local cursor_pos = utils.get_cursor_pos_0_indexed(0)
    start_pos = { line = cursor_pos.line, col = word_s }
    end_pos_inclusive = { line = cursor_pos.line, col = word_e }
  end

  -- Ensure start_pos and end_pos_inclusive are valid
  if not start_pos or start_pos.line == nil or start_pos.col == nil or
     not end_pos_inclusive or end_pos_inclusive.line == nil or end_pos_inclusive.col == nil then
     utils.echo_message("NumHi: Invalid range for highlight.", "ErrorMsg")
     return
  end

  -- Clear existing NumHi highlights in the exact same range before applying a new one
  -- This prevents trivial overlaps from the same plugin. More complex overlap handling is a future feature.
  for _, p_id in ipairs(M.plugin_config.palettes) do
      local existing_marks = api.nvim_buf_get_extmarks(bufnr, M.ns_ids[p_id],
          {start_pos.line, start_pos.col},
          {end_pos_inclusive.line, end_pos_inclusive.col + 1}, -- +1 for end_col exclusive
          {details = true})
      for _, mark in ipairs(existing_marks) do
          -- Check if the mark exactly matches the range
          local mark_details = mark[4]
          if mark[2] == start_pos.line and mark[3] == start_pos.col and
             mark_details.end_row == end_pos_inclusive.line and
             mark_details.end_col == end_pos_inclusive.col + 1 then -- Stored end_col is exclusive for set_extmark
            api.nvim_buf_del_extmark(bufnr, M.ns_ids[p_id], mark[1])
            if M.highlights_by_buffer[buffer_key] and mark_details.user_data and mark_details.user_data.numhi_uuid then
                 M.highlights_by_buffer[buffer_key][mark_details.user_data.numhi_uuid] = nil
            end
          end
      end
  end


  local highlight_uuid = utils.uuid()
  local category_lbl = get_category_label(palette_id, slot_number) -- May be async, see note in function
  local hl_group = utils.ensure_hl_group(palette_id, slot_number, M.plugin_config)

  local created_extmark_ids = {}

  -- Handle multi-line highlights from visual selection
  for l = start_pos.line, end_pos_inclusive.line do
    local current_line_text = utils.get_line_text(bufnr, l)
    local line_len_chars = current_line_text and #current_line_text or 0

    local mark_start_col = (l == start_pos.line) and start_pos.col or 0
    local mark_end_col -- This is exclusive for nvim_buf_set_extmark
    if l == end_pos_inclusive.line then
      mark_end_col = math.min(end_pos_inclusive.col + 1, line_len_chars)
    else
      mark_end_col = line_len_chars -- Highlight to actual EOL content
    end

    -- Ensure start_col is not past end_col for empty selections or weird ranges
    if mark_start_col >= mark_end_col and not (mark_start_col == 0 and mark_end_col == 0 and line_len_chars == 0) then
      if l == start_pos.line and l == end_pos_inclusive.line then -- single line, potentially empty selection
         -- utils.echo_message("NumHi: Skipping empty or invalid range on line " .. (l+1), "WarningMsg")
         goto next_line -- skip this line if range is invalid
      end
      -- For multi-line, if a line becomes invalid, might need more robust logic, but for now skip
      -- utils.echo_message("NumHi: Corrected invalid range on line " .. (l+1), "WarningMsg")
      if mark_start_col >= line_len_chars and line_len_chars > 0 then mark_start_col = line_len_chars -1 end
      mark_end_col = mark_start_col + 1
      if mark_start_col < 0 then mark_start_col = 0 end
      if mark_end_col > line_len_chars then mark_end_col = line_len_chars end
      if mark_start_col >= mark_end_col then goto next_line end
    end

    local extmark_id = api.nvim_buf_set_extmark(bufnr, ns_id, l, mark_start_col, {
      -- id = extmark_id_to_reuse, -- Let Neovim assign new ID
      end_row = l, -- Each segment is one line for simplicity here
      end_col = mark_end_col, -- end_col is exclusive
      hl_group = hl_group,
      hl_eol = (mark_end_col == line_len_chars and line_len_chars > 0), -- Only if it reaches true EOL
      priority = M.plugin_config.highlight_priority,
      user_data = { numhi_uuid = highlight_uuid }, -- Link all segments to the same highlight object
      -- strict = false, -- Allow adjustments if range is slightly off
    })
    table.insert(created_extmark_ids, extmark_id) -- Store Neovim's assigned ID, mostly for immediate undo
    ::next_line::
  end

  if #created_extmark_ids == 0 then
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
    end_col = end_pos_inclusive.col, -- Store inclusive end_col for data consistency
    tags = {},
    note_id = nil,
    created_at = ts,
    updated_at = ts,
    -- `extmark_neovim_ids` are transient for the session, not for persistent storage.
    -- They are useful if an undo operation needs to know exactly which extmarks to remove.
    -- However, for reapplying on load, we use the range data.
  }

  M.highlights_by_buffer[buffer_key] = M.highlights_by_buffer[buffer_key] or {}
  M.highlights_by_buffer[buffer_key][highlight_uuid] = highlight_obj

  add_history_entry({
    action = "create",
    buffer_key = buffer_key,
    highlight_uuid = highlight_uuid,
    -- For undoing creation, we need enough info to remove it by UUID and its extmarks
    -- The extmark IDs themselves are tricky as they change if buffer is reloaded.
    -- So, undoing a create really means finding the extmark by UUID from user_data and removing it.
  })

  save_all_data()

  if M.plugin_config.echo_on_highlight then
    local display_label = M.category_labels[palette_id] and M.category_labels[palette_id][slot_number] or category_lbl or ""
    local msg = string.format("NumHi: Highlighted %s-%d", palette_id, slot_number)
    if display_label ~= "" then msg = msg .. " (" .. display_label .. ")" end
    utils.echo_message(msg, hl_group)
  end
  if M.plugin_config.notify_on_highlight_create then
     local display_label = M.category_labels[palette_id] and M.category_labels[palette_id][slot_number] or category_lbl or ""
    utils.notify_message(string.format("NumHi: Highlighted %s-%d%s", palette_id, slot_number, display_label ~= "" and " ("..display_label..")" or ""), vim.log.levels.INFO, "NumHi")
  end

  -- Clear visual selection after highlighting
  if fn.mode(false):find("^[vV]") then
      api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  end
end

--- Gets information about the NumHi highlight at the current cursor position.
--- Searches all NumHi namespaces.
---@param bufnr number
---@param winid number
---@return table|nil Highlight object from M.highlights_by_buffer or nil.
function C.get_highlight_info_at_cursor(bufnr, winid)
  local pos = utils.get_cursor_pos_0_indexed(winid)
  local buffer_key = get_buffer_key(bufnr)

  if not buffer_key or not M.highlights_by_buffer[buffer_key] then
    return nil
  end

  -- Iterate through this buffer's highlights first (more efficient)
  for uuid, hl_obj in pairs(M.highlights_by_buffer[buffer_key]) do
    local mark_start = {line = hl_obj.start_line, col = hl_obj.start_col}
    local mark_end_inclusive = {line = hl_obj.end_line, col = hl_obj.end_col}
    if utils.is_position_within_extmark(pos, mark_start, mark_end_inclusive) then
      return hl_obj -- Return the stored highlight object
    end
  end

  -- Fallback: Check extmarks directly if in-memory cache is out of sync (should not happen ideally)
  -- This part is more for robustness or if we didn't have a full in-memory cache.
  -- For now, relying on M.highlights_by_buffer is preferred.
  -- If performance becomes an issue with many highlights, optimize the search.
  -- Example of direct extmark check:
  -- for pal_id, ns_id in pairs(M.ns_ids) do
  --   local marks = api.nvim_buf_get_extmarks(bufnr, ns_id, {pos.line, pos.col}, {pos.line, pos.col + 1}, {details = true})
  --   if marks and #marks > 0 then
  --     local mark_data = marks[1][4] -- user_data is in details
  --     if mark_data and mark_data.user_data and mark_data.user_data.numhi_uuid then
  --       local uuid = mark_data.user_data.numhi_uuid
  --       if M.highlights_by_buffer[buffer_key] and M.highlights_by_buffer[buffer_key][uuid] then
  --         return M.highlights_by_buffer[buffer_key][uuid]
  --       end
  --     end
  --   end
  -- end

  return nil
end


--- Deletes the NumHi highlight(s) under the cursor.
function C.delete_highlight_at_cursor()
  local bufnr = 0
  local winid = 0
  local buffer_key = get_buffer_key(bufnr)
  if not buffer_key then return end

  local hl_info = C.get_highlight_info_at_cursor(bufnr, winid)
  if not hl_info then
    utils.echo_message("NumHi: No highlight under cursor.", "WarningMsg")
    return
  end

  local uuid_to_delete = hl_info.uuid
  local original_hl_obj = utils.deepcopy(M.highlights_by_buffer[buffer_key][uuid_to_delete])

  -- Remove all extmarks associated with this UUID
  for _, ns_id in pairs(M.ns_ids) do
      -- Iterate all marks in this namespace and remove if UUID matches
      local all_marks_in_ns = api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {details = true})
      for _, mark in ipairs(all_marks_in_ns) do
          if mark[4] and mark[4].user_data and mark[4].user_data.numhi_uuid == uuid_to_delete then
              api.nvim_buf_del_extmark(bufnr, ns_id, mark[1])
          end
      end
  end

  M.highlights_by_buffer[buffer_key][uuid_to_delete] = nil
  utils.echo_message(string.format("NumHi: Deleted highlight %s-%d.", original_hl_obj.palette_id, original_hl_obj.slot), "ModeMsg")

  add_history_entry({
    action = "delete",
    buffer_key = buffer_key,
    highlight_uuid = uuid_to_delete,
    data = original_hl_obj, -- Store the full object for redo
  })

  -- Handle associated note
  if original_hl_obj.note_id and M.plugin_config.delete_mark_prompts_for_note then
    local note_content_preview = "Note exists." -- TODO: Get actual preview if notes_manager is ready
    if M.notes_by_id[original_hl_obj.note_id] then
        note_content_preview = M.notes_by_id[original_hl_obj.note_id].content:sub(1,30) .. "..."
    end

    vim.ui.select({ "Yes, delete note", "No, keep note (unlinked for now)" }, {
      prompt = "Highlight had a note: \"".. note_content_preview .. "\". Delete it too?",
      format_item = function(item) return item end,
    }, function(choice)
      if choice and choice == "Yes, delete note" then
        -- notes_manager.delete_note(original_hl_obj.note_id) -- Call when notes_manager is implemented
        if M.notes_by_id[original_hl_obj.note_id] then
            local original_note_obj = utils.deepcopy(M.notes_by_id[original_hl_obj.note_id])
            M.notes_by_id[original_hl_obj.note_id] = nil
            add_history_entry({
                action = "delete_note_with_highlight", -- special type for combined undo
                note_uuid = original_hl_obj.note_id,
                data = original_note_obj,
            })
            utils.echo_message("NumHi: Note deleted.", "ModeMsg")
            save_all_data() -- Save after note decision
        end
      else
        -- Note kept, maybe mark as orphaned in future if needed
         utils.echo_message("NumHi: Note kept (currently unlinked).", "ModeMsg")
         save_all_data() -- Save after potential non-deletion of note
      end
    end)
  else
      save_all_data() -- Save if no note or no prompt
  end
end


function C.undo()
  local entry = table.remove(M.history)
  if not entry then
    utils.echo_message("NumHi: Nothing to undo.", "WarningMsg")
    return
  end

  if entry.action == "create" then
    -- To undo creation, we delete the highlight that was just created.
    -- This needs more careful thought: C.delete_highlight_by_uuid(entry.highlight_uuid)
    -- but C.delete_highlight_by_uuid itself adds to history.
    -- For now, a simplified undo:
    local hl_obj = M.highlights_by_buffer[entry.buffer_key] and M.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid]
    if hl_obj then
      for _, ns_id in pairs(M.ns_ids) do
         local all_marks_in_ns = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {details = true})
         for _, mark in ipairs(all_marks_in_ns) do
             if mark[4] and mark[4].user_data and mark[4].user_data.numhi_uuid == entry.highlight_uuid then
                 api.nvim_buf_del_extmark(0, ns_id, mark[1])
             end
         end
      end
      M.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid] = nil
      table.insert(M.redo_stack, {action="delete_undo", buffer_key=entry.buffer_key, data=hl_obj}) -- Store full obj for redo
      utils.echo_message("NumHi: Undid highlight creation.", "ModeMsg")
    end
  elseif entry.action == "delete" then
    -- To undo deletion, we re-create the highlight.
    local hl_obj_to_restore = entry.data
    if hl_obj_to_restore then
      M.highlights_by_buffer[entry.buffer_key] = M.highlights_by_buffer[entry.buffer_key] or {}
      M.highlights_by_buffer[entry.buffer_key][hl_obj_to_restore.uuid] = hl_obj_to_restore
      C.apply_highlights_to_buffer(fn.bufnr(entry.buffer_key)) -- Re-apply this one
      table.insert(M.redo_stack, {action="create_undo", buffer_key=entry.buffer_key, highlight_uuid=hl_obj_to_restore.uuid})
      utils.echo_message("NumHi: Undid highlight deletion.", "ModeMsg")
    end
  elseif entry.action == "delete_note_with_highlight" then
    -- Restore note
    if entry.data and entry.note_uuid then
        M.notes_by_id[entry.note_uuid] = entry.data
        utils.echo_message("NumHi: Undid note deletion.", "ModeMsg")
        -- The highlight deletion would be a separate history entry to undo
    end
  end
  save_all_data()
end

function C.redo()
  local entry = table.remove(M.redo_stack)
  if not entry then
    utils.echo_message("NumHi: Nothing to redo.", "WarningMsg")
    return
  end

  if entry.action == "delete_undo" then -- This means we undid a create, so redo is create
    local hl_obj_to_restore = entry.data
    if hl_obj_to_restore then
      M.highlights_by_buffer[entry.buffer_key] = M.highlights_by_buffer[entry.buffer_key] or {}
      M.highlights_by_buffer[entry.buffer_key][hl_obj_to_restore.uuid] = hl_obj_to_restore
      C.apply_highlights_to_buffer(fn.bufnr(entry.buffer_key))
      add_history_entry({action="create", buffer_key=entry.buffer_key, highlight_uuid=hl_obj_to_restore.uuid})
      utils.echo_message("NumHi: Redid highlight creation.", "ModeMsg")
    end
  elseif entry.action == "create_undo" then -- This means we undid a delete, so redo is delete
     local hl_obj_to_delete = M.highlights_by_buffer[entry.buffer_key] and M.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid]
     if hl_obj_to_delete then
        for _, ns_id in pairs(M.ns_ids) do
            local all_marks_in_ns = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {details = true})
            for _, mark in ipairs(all_marks_in_ns) do
                if mark[4] and mark[4].user_data and mark[4].user_data.numhi_uuid == entry.highlight_uuid then
                    api.nvim_buf_del_extmark(0, ns_id, mark[1])
                end
            end
        end
        M.highlights_by_buffer[entry.buffer_key][entry.highlight_uuid] = nil
        add_history_entry({action="delete", buffer_key=entry.buffer_key, highlight_uuid=entry.highlight_uuid, data=hl_obj_to_delete})
        utils.echo_message("NumHi: Redid highlight deletion.", "ModeMsg")
     end
  end
  save_all_data()
end

function C.cycle_palette(direction)
  local palettes = M.plugin_config.palettes
  local current_idx = utils.index_of(palettes, M.active_palette_id)
  if not current_idx then current_idx = 1 end

  local new_idx = (current_idx - 1 + direction) % #palettes
  if new_idx < 0 then new_idx = new_idx + #palettes end
  M.active_palette_id = palettes[new_idx + 1]

  -- utils.echo_message("NumHi: Active palette -> " .. M.active_palette_id, "MoreMsg")
  -- Delegate notification to ui.lua for richer popups later
  local ui_module = require("numhi.ui") -- require here to avoid circular dep if ui needs core
  ui_module.show_palette_notification(M.active_palette_id, M.plugin_config)

  -- TODO: Trigger statusline update if component is active
  if M.plugin_config.statusline then
      -- This might require a global refresh function for statusline or specific integration
      -- For lualine, it might auto-refresh if it detects option changes or via its API.
      -- For mini.statusline, need to ensure its redraw is triggered.
      -- For now, this is a placeholder.
      pcall(function() require("lualine").refresh() end)
      -- For mini.statusline, it seems to rebuild on events like OptionSet, WinEnter, etc.
      -- A manual trigger might be `mini.statusline.update()` if available, or forcing an event.
  end
end

function C.get_active_palette()
    return M.active_palette_id
end

function C.get_category_labels_for_palette(palette_id)
    return M.category_labels[palette_id] or {}
end

--- Entry point for user to input digits and then highlight.
function C.collect_digits_for_highlight()
  local digits = ""
  local current_palette = M.active_palette_id

  local function update_prompt()
    local slot_preview = (#digits > 0) and digits or "__"
    local prompt_msg = {
      { "NumHi ", "Title" },
      { current_palette, utils.ensure_hl_group(current_palette, 1, M.plugin_config) }, -- Show palette with its base color
      { " Slot: ", "Comment" },
      { slot_preview, (#digits > 0 and tonumber(digits)) and utils.ensure_hl_group(current_palette, tonumber(digits) or 1, M.plugin_config) or "Comment" },
      { " (1-"..tostring(M.plugin_config.max_slots_per_palette)..")", "Comment" },
    }
    utils.echo_message(prompt_msg)
  end

  update_prompt()

  vim.fn.getcharstr(false) -- Clear previous input?
  -- Using a loop with getchar() for interactive input
  -- This is a simplified version. A more robust input might use vim.ui.input or a floating window.
  local key
  while true do
    key = fn.getchar()
    if type(key) == "number" then key = fn.nr2char(key) end

    if key == "\r" or key == "\n" then -- Enter
      if #digits > 0 then
        local slot_to_use = tonumber(digits)
        if slot_to_use then
          -- For visual mode, need to exit it first for get_visual_selection_range to work correctly if called from normal mode after this.
          -- Or, C.create_highlight should handle visual mode directly.
          if fn.mode(false):find("^[vV]") then
             api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
             -- Schedule the highlight to allow mode change and visual marks to settle
             vim.schedule(function() C.create_highlight(slot_to_use) end)
          else
             C.create_highlight(slot_to_use)
          end
        else
          utils.echo_message("NumHi: Invalid slot number entered.", "ErrorMsg")
        end
        utils.echo_message("") -- Clear prompt
        return
      else
        utils.echo_message("NumHi: No slot number entered.", "WarningMsg")
        utils.echo_message("") -- Clear prompt
        return
      end
    elseif key == "\x1b" or key == "\x03" then -- Escape or Ctrl-C
      utils.echo_message("NumHi: Highlight cancelled.", "WarningMsg")
      utils.echo_message("") -- Clear prompt
      return
    elseif key:match("%d") then
      if #digits < (M.plugin_config.max_slots_per_palette >= 100 and 3 or 2) then -- Allow 2 or 3 digits
        digits = digits .. key
        update_prompt()
      end
    elseif key == "\x7f" or key == "\b" then -- Backspace
      if #digits > 0 then
        digits = digits:sub(1, #digits - 1)
        update_prompt()
      end
    else
      -- Ignore other keys or beep
      -- fn.feedkeys(api.nvim_replace_termcodes("<Ignore>", true, true, true), "n")
    end
  end
end

--- Function to be called on BufEnter to load/apply highlights
function C.on_buf_enter(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    -- Ensure data for the whole project is loaded if not already
    -- This might be redundant if C.setup already did a full load.
    -- C.load_all_project_data()

    -- Apply highlights specific to this buffer
    if get_buffer_key(bufnr) then
        C.apply_highlights_to_buffer(bufnr)
    end
end

--- Function to be called on BufWritePost to save data
function C.on_buf_write(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    if get_buffer_key(bufnr) then
        -- This saves ALL project data, which might be too much on every write.
        -- Consider a more targeted save or a debounce mechanism if performance issues arise.
        save_all_data()
    end
end

--- Getter for the entire plugin state, mainly for other modules like UI
function C.get_internal_state_DO_NOT_MODIFY()
    return M
end

return C
```

Next, `lua/numhi/notes.lua` for managing notes and their floating windows.

### Design: `lua/numhi/notes.lua`

This module will handle the creation, display, editing, and deletion of notes associated with highlights.

1.  **State (References to `core.M` state):**

    - Needs access to `M.notes_by_id` for note content.
    - Needs access to `M.highlights_by_buffer` to link notes to highlights.
    - Needs `M.plugin_config` for window styling, auto-save behavior.

2.  **Core Functions:**

    - `N.edit_note_for_highlight(highlight_uuid)`: (Or triggered by cursor position, finding the highlight via `core.get_highlight_info_at_cursor`)

      - Retrieve the `highlight_obj` using `highlight_uuid` (or from cursor).
      - If `highlight_obj.note_id` exists, load content from `M.notes_by_id[highlight_obj.note_id].content`.
      - If no `note_id`, it's a new note.
      - Create a scratch buffer (`api.nvim_create_buf(false, true)`).
      - Set buffer options: `buftype=acwrite`, `bufhidden=wipe`, `filetype=markdown`.
      - Populate buffer with existing note content or leave empty for new note.
      - Open a floating window using `api.nvim_open_win()`:
        - Positioned "underneath the lowest edge of the highlight" (requires `highlight_obj.end_line`).
        - Dimensions from `M.plugin_config.note_window_width_ratio`, `note_window_height_ratio`.
        - Border style from `M.plugin_config.note_border`.
        - Set `winblend` for transparency if desired.
        - `title = "NumHi Note: "..palette_id.."-"..slot.." ("..label..")"`.
      - Store `bufnr` and `winid` of the note window, perhaps in a temporary module state `M.active_note_window = {bufnr, winid, highlight_uuid, note_id}`.
      - Set up autocommands for the note buffer:
        - `BufWriteCmd` (if explicit save is mapped): Get content, create/update note in `M.notes_by_id`, update `highlight_obj.note_id` if new, save all data via `core`'s save function, then close window.
        - `BufLeave` or `WinClosed` (for auto-save if `config.auto_save_notes` is true): Similar save logic.
      - Keymaps local to the note buffer:
        - `<Esc>` or a save key (e.g., `<C-s>`) to trigger save and close.
        - `<C-q>` to close without saving (if not auto-saving on BufLeave).

    - `N.create_or_update_note(highlight_uuid, note_content_lines)`:

      - Internal function called by the save mechanism.
      - Retrieves `highlight_obj`.
      - If `highlight_obj.note_id` and `M.notes_by_id[highlight_obj.note_id]` exists, update its content and `updated_at`.
      - Else (new note):
        - Generate `new_note_uuid` using `utils.uuid()`.
        - Create `note_obj = { uuid = new_note_uuid, content = table.concat(note_content_lines, "\n"), created_at, updated_at, highlight_uuid = highlight_uuid }`.
        - Store in `M.notes_by_id[new_note_uuid]`.
        - Update `M.highlights_by_buffer[buffer_key][highlight_uuid].note_id = new_note_uuid`.
        - Update `M.highlights_by_buffer[buffer_key][highlight_uuid].updated_at`.
      - Triggers `core.save_all_data()`.
      - Adds to `core.history` for undo/redo.

    - `N.delete_note(note_uuid, associated_highlight_uuid)`:

      - Removes note from `M.notes_by_id`.
      - If `associated_highlight_uuid` is provided, find the highlight and set its `note_id = nil`.
      - Triggers `core.save_all_data()`.
      - Adds to `core.history`.

    - `N.get_note_content(note_uuid)`:
      - Returns content string from `M.notes_by_id`.

3.  **Floating Window Management:**

    - Ensure only one note window is open at a time, or manage multiple if that's a desired future feature (current request implies one).
    - The positioning needs to be robust: if highlight is at bottom of screen, window should open above. `api.nvim_open_win` with `relative = 'cursor'` or `relative = 'win'` and careful `row`/`col` calculation based on highlight's `end_row` and `end_col` will be needed. The `row` for `nvim_open_win` is relative to the anchor. If anchor is cursor, `row=1` is below cursor line.
    - The user's `core.lua edit_note()` attempts this but had issues. The `NumHi_OverviewOfDesiredFeatures.md` states "Sidebar overview of all highlights...". This is a different UI element not yet designed but to keep in mind. The current request is for a floating window _under the highlight_.

4.  **Tag Extraction (from user's `core.lua` `edit_note`):**
    - When saving the note, parse for tags (e.g., `#tagword`).
    - Update `M.highlights_by_buffer[buffer_key][highlight_uuid].tags` with these extracted tags. This seems like a good place for this logic.

This module will integrate closely with `core.lua` for data and `utils.lua` for UI helpers (like window creation parameters).

```lua
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
```

Now for `lua/numhi/ui.lua`. This will handle user interface elements like echo messages, notifications (using `vim.notify`), the palette transient popup, and serve as a placeholder for future pickers.

### Design: `lua/numhi/ui.lua`

This module will manage various user interface components for NumHi.

1.  **State & Dependencies:**

    - Needs access to `M_CORE_STATE.plugin_config` for styling, durations, etc.
    - Needs `utils.lua` for base echo/notify wrappers if not directly implementing here.
    - `core.lua` for palette info, highlight info.

2.  **Echo/Notification Wrappers (Refined from `utils.lua` or used directly):**

    - `U.echo_highlight_info(hl_info)`: Formats and echoes information about a highlight (palette, slot, label, tags).
      - `hl_info` is the object returned by `core.get_highlight_info_at_cursor()`.
    - `U.notify(message, level, title)`: A wrapper for `vim.notify`.

3.  **Palette Notification (`U.show_palette_notification(palette_id, plugin_config)`):**

    - Called by `core.cycle_palette()`.
    - Shows a transient message (e.g., using `vim.notify` or a custom floating window if `nvim-notify` is not desired as a hard dependency).
    - Displays the new active palette name and its 10 base color swatches.
      - Swatches can be characters like '▉' colored with the respective highlight group.
      - Example: `NumHi → palette VID [▉▉▉▉▉▉▉▉▉▉]` where each block is colored.
    - The user's `core.lua` `cycle_palette` function already has logic for this kind of message using `echo()`. This can be adapted to use `vim.notify` or a temporary float.

4.  **Highlight Label Tooltip (`U.show_hover_tooltip(hl_info)`):**

    - Called by `CursorHold` autocmd via `core.lua`.
    - `hl_info` comes from `core.get_highlight_info_at_cursor()`.
    - Displays a small floating window near the cursor with palette, slot, label, and first line of note (if any).
    - Auto-closes after `plugin_config.hover_delay` or if cursor moves significantly.
    - The user's `ui.lua` `tooltip` function is a good base.

5.  **Picker Placeholders/Integration Points:**

    - `U.pick_highlight(callback)`: Placeholder for Telescope/FZF integration to select an existing highlight.
      - `callback(selected_highlight_uuid)` would be called.
      - Source: `M_CORE_STATE.highlights_by_buffer`.
      - Display: `filename:line_num palette-slot label tags note_preview`.
    - `U.pick_palette_color(callback)`: Placeholder for selecting a palette and slot.
      - `callback(palette_id, slot_number)`.
      - Display: Palette name, then swatches for slots 1-10, 11-20, etc.
    - `U.pick_category_label(current_palette_id, current_slot, callback)`: Placeholder for picking a previously used category label for a given palette/slot.
      - `callback(selected_label_string)`.
      - Source: `M_CORE_STATE.category_labels`.

6.  **Statusline Component (`U.get_statusline_component()`):**
    - Generates the string for the statusline (active palette, swatches).
    - The user's `init.lua` `status_component` function is a good base. This logic will live here.

This UI module will make the plugin more interactive and user-friendly. The picker functions will initially be stubs, with Telescope/FZF integration being a more advanced step.

```lua
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
  current_tooltip_timer:start(M_CORE_STATE.plugin_config.hover_delay_close or 3000, 0, vim.schedule_ πολλ(function()
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
```

Finally, `lua/numhi/init.lua` to tie everything together, handle setup, and create keymaps.

### Design: `lua/numhi/init.lua` (Main Facade)

This is the main entry point for the plugin. It will handle setup, merging user options with defaults, initializing other modules, and setting up keymaps and autocommands.

1.  **Module Structure (`M`):**

    - `M.config`: Stores the merged configuration (defaults + user options). Initialized during `setup`.
    - `M.state`: Stores the runtime state of the plugin. This was conceptualized in `core.lua` as `M_CORE_STATE`. `init.lua` will own this top-level state object and pass it to other modules or have them register parts of it.
      - `active_palette_id`
      - `highlights_by_buffer` (buffer_key -> { highlight_uuid -> highlight_obj })
      - `notes_by_id` (note_uuid -> note_obj)
      - `category_labels` (palette_id -> slot_num -> label_string)
      - `history`, `redo_stack`
      - `ns_ids` (managed by core)

2.  **`M.setup(user_opts)`:**

    - Loads default options from `require("numhi.config").default_opts`.
    - Performs a deep merge of `user_opts` into the defaults, storing the result in `M.config`.
    - Initializes `M.state` (e.g., `M.state.active_palette_id = M.config.palettes`).
    - Calls setup functions for other modules, passing `M.config` and relevant parts of `M.state` or the whole `M.state` object:
      - `require("numhi.core").setup(M.config, M.state)` (Core will populate `M.state.ns_ids`, load data, etc.)
      - `require("numhi.notes").initialize(M.state, require("numhi.core").save_all_data, require("numhi.core").add_history_entry)` (Pass necessary core functions/state to notes module)
      - `require("numhi.ui").initialize(M.state, require("numhi.core").get_highlight_info_at_cursor, require("numhi.core").get_category_labels_for_palette)`
    - Calls `M.create_keymaps()`.
    - Calls `M.create_autocmds()`.
    - If `M.config.statusline` is true, calls `M.attach_statusline()`.

3.  **`M.create_keymaps()`:**

    - Reads `M.config.key_leader`.
    - Sets up keymaps for:
      - Highlighting (triggering digit collector or direct highlight if a number is passed). User's old `init.lua` mapped `<leader><leader><CR>` to `core.collect_digits()`. This should be `core.collect_digits_for_highlight()`.
      - Erasing highlight under cursor: `core.delete_highlight_at_cursor()`.
      - Undo/Redo: `core.undo()`, `core.redo()`.
      - Cycle palette: `core.cycle_palette(1)` (next) and `core.cycle_palette(-1)` (prev).
      - Edit/Create Note: `notes.edit_note_for_highlight()` (needs to get highlight from cursor via core).
      - Commands for pickers (e.g., `:NumHiListHighlights`, `:NumHiPickColor`). These will call functions in `ui.lua`.
      - Navigation commands (next/prev highlight of same color/palette/any).

4.  **`M.create_autocmds()`:**

    - `CursorHold`: To show hover tooltip (calls `ui.show_hover_tooltip()`). `vim.opt.updatetime` should be respected or set reasonably.
    - `BufEnter`: To apply existing highlights to the buffer (calls `core.on_buf_enter(bufnr)`).
    - `BufWritePost`: To save highlight/note data for the project (calls `core.on_buf_write(bufnr)`).
    - `VimLeavePre`: To ensure data is saved before exiting.

5.  **`M.attach_statusline()`:**

    - Integrates `ui.get_statusline_component()` with common statusline plugins (Lualine, mini.statusline) or the default `vim.o.statusline`. The user's existing `init.lua` has good examples for this.

6.  **Public API Functions (Wrappers around core/notes/ui):**

    - These will be thin wrappers that call the respective functions in other modules. This keeps `init.lua` as a clean facade.
    - `M.highlight(slot_or_visual_mode_indicator)`
    - `M.erase_highlight()`
    - `M.edit_note()`
    - `M.cycle_palette(direction)`
    - `M.undo_highlight_action()`
    - `M.redo_highlight_action()`

7.  **User Commands:**
    - `:NumHiSaveData` -> `core.save_all_data()`
    - `:NumHiLoadData` -> `core.load_all_project_data()` and re-apply to all buffers.
    - `:NumHiListHighlights` -> `ui.pick_highlight()` (or a dedicated list command).
    - `:NumHiCyclePalette` -> `core.cycle_palette(1)`
    - `:NumHiSetLabel {palette_code} {slot_number} {label_text}` (for manually setting category labels).

This structure aims for a clean separation of concerns, with `init.lua` orchestrating the plugin's setup and user interactions, while delegating the heavy lifting to specialized modules.

```lua
-- ~/.config/nvim/lua/numhi/init.lua

local api = vim.api
local fn = vim.fn

local M = {}

-- Holds the merged (default + user) configuration
M.config = {}

-- Holds the runtime state of the plugin
M.state = {
  active_palette_id = "",
  highlights_by_buffer = {}, -- buffer_key -> { highlight_uuid -> highlight_obj }
  notes_by_id = {},          -- note_uuid -> note_obj
  category_labels = {},      -- palette_id -> slot_num -> label_string
  history = {},
  redo_stack = {},
  ns_ids = {}, -- Populated by core.setup
  -- Keep track of the buffer associated with the active note window, if any.
  active_note_buffer_details = { bufnr = nil, winid = nil, highlight_uuid = nil }
}

-- References to other modules (initialized in setup)
local core_module = nil
local notes_module = nil
local ui_module = nil
local storage_module = nil -- Though mostly used by core
local utils_module = require("numhi.utils") -- Utils can be required directly

--- Main setup function for the plugin.
---@param user_opts table User-provided configuration options.
function M.setup(user_opts)
  local config_defaults = require("numhi.config").default_opts
  M.config = vim.tbl_deep_extend("force", utils_module.deepcopy(config_defaults), user_opts or {})

  M.state.active_palette_id = M.config.palettes[1] or ""
  -- Initialize other state components as needed
  M.state.highlights_by_buffer = {}
  M.state.notes_by_id = {}
  M.state.category_labels = {}
  M.state.history = {}
  M.state.redo_stack = {}

  -- Initialize other modules
  core_module = require("numhi.core")
  notes_module = require("numhi.notes")
  ui_module = require("numhi.ui")
  storage_module = require("numhi.storage") -- Primarily for direct use if needed, core handles most calls

  -- Core needs access to the shared state and config.
  -- Core will also populate M.state.ns_ids and load initial data.
  core_module.setup(M.config, M.state)

  -- Notes module needs reference to shared state and core functions for saving and history.
  notes_module.initialize(M.state, core_module.save_all_data, core_module.add_history_entry)

  -- UI module needs reference to shared state and core functions for info retrieval.
  ui_module.initialize(M.state, core_module.get_highlight_info_at_cursor, core_module.get_category_label_for_palette)

  M.create_keymaps()
  M.create_autocmds()
  M.create_user_commands()

  if M.config.statusline then
    M.attach_statusline()
  end

  utils_module.echo_message("NumHi loaded successfully!", "MoreMsg")
end

--- Creates default keymappings for the plugin.
function M.create_keymaps()
  local leader = M.config.key_leader
  local keymap_opts = { silent = true, noremap = true }

  -- Highlight with digit collector
  vim.keymap.set({"n", "v"}, leader .. "<CR>", function() core_module.collect_digits_for_highlight() end,
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Highlight with slot" }))

  -- Erase highlight under cursor
  vim.keymap.set("n", leader .. "0<CR>", function() core_module.delete_highlight_at_cursor() end,
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Erase highlight under cursor" }))
  vim.keymap.set("n", leader .. "00", function() core_module.delete_highlight_at_cursor() end,  -- Alternative mapping
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Erase highlight under cursor" }))


  -- Undo / Redo NumHi actions
  vim.keymap.set("n", leader .. "u", function() core_module.undo() end,
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Undo last action" }))
  vim.keymap.set("n", leader .. "<C-r>", function() core_module.redo() end,
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Redo last action" }))

  -- Palette cycling
  vim.keymap.set("n", leader .. "p", function() core_module.cycle_palette(1) end,
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Next palette" }))
  vim.keymap.set("n", leader .. "P", function() core_module.cycle_palette(-1) end,
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Previous palette" }))

  -- Edit/Create Note for highlight under cursor
  local function edit_note_action()
    local hl_info = core_module.get_highlight_info_at_cursor(0,0)
    if hl_info then
      local buffer_key = storage_module.get_buffer_storage_key(0)
      notes_module.edit_note_for_highlight(hl_info, buffer_key)
    else
      utils_module.echo_message("NumHi: No highlight under cursor to attach a note.", "WarningMsg")
    end
  end
  vim.keymap.set({"n", "v"}, leader .. "n", edit_note_action,
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Edit/Create Note for highlight" }))
  vim.keymap.set({"n", "v"}, leader .. "<Enter>", edit_note_action, -- Alternative as per user transcript
    vim.tbl_extend("force", keymap_opts, { desc = "NumHi: Edit/Create Note for highlight" }))

  -- TODO: Keymaps for pickers (e.g., list highlights, pick color)
  -- vim.keymap.set("n", leader .. "lh", function() ui_module.pick_highlight(function(uuid) if uuid then print("Selected UUID: " .. uuid) end end) end,
  --   vim.tbl_extend("force", keymap_opts, { desc = "NumHi: List/Pick Highlight" }))
end

--- Creates autocommands for the plugin.
function M.create_autocmds()
  local group = api.nvim_create_augroup("NumHiUserEvents", { clear = true })

  api.nvim_create_autocmd("CursorHold", {
    group = group,
    pattern = "*",
    desc = "NumHi: Show highlight label/tooltip on hover.",
    callback = function()
      -- Only show tooltip if not in command-line mode or other disruptive modes
      if fn.mode():find("^[nc]") == nil then -- Not normal or command-line mode
         ui_module.show_hover_tooltip()
      else
         ui_module.close_tooltip() -- Close if mode changed to something disruptive
      end
    end,
  })
  -- Adjust updatetime if hover_delay is shorter than current updatetime
  vim.opt.updatetime = math.min(vim.opt.updatetime:get(), M.config.hover_delay)

  api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    desc = "NumHi: Load and apply highlights for the entered buffer.",
    callback = function(args)
      -- Debounce or delay this slightly if it causes issues on rapid buffer switches
      vim.schedule(function()
          if core_module and core_module.on_buf_enter then
            core_module.on_buf_enter(args.buf)
          end
      end)
    end,
  })

  api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*",
    desc = "NumHi: Save highlight and note data for the project.",
    callback = function(args)
      if core_module and core_module.on_buf_write then
         core_module.on_buf_write(args.buf)
      end
    end,
  })

  api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    pattern = "*",
    desc = "NumHi: Ensure all data is saved before exiting.",
    callback = function()
      if core_module and core_module.save_all_data then
        core_module.save_all_data()
        utils_module.echo_message("NumHi: Data saved.", "MoreMsg")
      end
    end,
  })
end

--- Creates user-facing commands.
function M.create_user_commands()
    api.nvim_create_user_command("NumHiSaveData", function()
        if core_module and core_module.save_all_data then
            core_module.save_all_data()
            utils_module.echo_message("NumHi: All data saved.", "MoreMsg")
        end
    end, { desc = "NumHi: Manually save all highlight and note data for the project." })

    api.nvim_create_user_command("NumHiLoadData", function()
        if core_module and core_module.load_all_project_data then
            core_module.load_all_project_data()
            -- Re-apply to all relevant buffers
            for _, bufnr in ipairs(api.nvim_list_bufs()) do
                if api.nvim_buf_is_loaded(bufnr) and storage_module.get_buffer_storage_key(bufnr) then
                    core_module.apply_highlights_to_buffer(bufnr)
                end
            end
            utils_module.echo_message("NumHi: All data reloaded and highlights reapplied.", "MoreMsg")
        end
    end, { desc = "NumHi: Manually reload all highlight and note data." })

    -- Example for a future picker command
    -- api.nvim_create_user_command("NumHiListHighlights", function()
    --     if ui_module and ui_module.pick_highlight then
    --         ui_module.pick_highlight(function(uuid)
    --             if uuid then
    --                 -- TODO: Logic to jump to the selected highlight
    --                 print("Selected highlight UUID: " .. uuid)
    --             end
    --         end)
    --     end
    -- end, { desc = "NumHi: List and pick from existing highlights in the project." })
end

--- Attaches the NumHi component to the statusline.
function M.attach_statusline()
  vim.schedule(function() -- Ensure it runs after user's statusline might have been setup
    -- Try mini.statusline
    local mini_ok, mini_statusline = pcall(require, "mini.statusline")
    if mini_ok and mini_statusline.section_location then -- Check for a known field
      local current_win_section = mini_statusline.section_location()
      if type(current_win_section) == "function" then -- If it's a function, wrap it
          local original_win_section = current_win_section
          mini_statusline.section_location = function(...)
              return ui_module.get_statusline_component() .. original_win_section(...)
          end
      elseif type(current_win_section) == "string" then -- If it's a string, prepend
          mini_statusline.section_location = ui_module.get_statusline_component() .. current_win_section
      else -- Fallback: try to set a common section like 'c' or 'x'
          local MiniStatusline = package.loaded["mini.statusline"]
          if MiniStatusline and MiniStatusline.config and MiniStatusline.config.sections then
              table.insert(MiniStatusline.config.sections.active.location, 1, ui_module.get_statusline_component())
          end
      end
      -- mini.statusline usually updates on events, or a manual refresh might be needed if available
      pcall(function() MiniStatusline.update() end)
      return
    end

    -- Try Lualine
    local lualine_ok, lualine = pcall(require, "lualine")
    if lualine_ok and lualine.setup then
      local lualine_config = lualine.get_config and lualine.get_config() or {}
      lualine_config.sections = lualine_config.sections or { lualine_c = {} }
      lualine_config.sections.lualine_c = lualine_config.sections.lualine_c or {}
      -- Add to an existing section or create one, e.g., lualine_c
      table.insert(lualine_config.sections.lualine_c, 1, {
        function() return ui_module.get_statusline_component() end,
        cond = nil, -- Always show, or add condition
        color = {}, -- Let the component handle its own colors
      })
      lualine.setup(lualine_config)
      return
    end

    -- Fallback to vim.o.statusline
    -- This is a bit more involved as it needs to be a Vim expression
    -- Create a global Lua function that Vim's statusline can call
    _G.NumHiGetStatuslineComponentForVim = function()
      if ui_module then return ui_module.get_statusline_component() else return "" end
    end
    -- Prepend to existing statusline if it's not empty
    if vim.o.statusline ~= "" then
      vim.o.statusline = "%!v:lua._G.NumHiGetStatuslineComponentForVim()" .. vim.o.statusline
    else
      vim.o.statusline = "%!v:lua._G.NumHiGetStatuslineComponentForVim()"
    end
  end)
end


--- Public API function to get the statusline component string.
--- Useful if users want to manually integrate it into their custom statusline.
---@return string
function M.get_statusline_str()
    if ui_module then
        return ui_module.get_statusline_component()
    end
    return ""
end

return M
```

This set of files (`config.lua`, `utils.lua`, `storage.lua`, `core.lua`, `notes.lua`, `ui.lua`, and `init.lua`) provides a more robust and feature-rich foundation for the NumHi plugin.

**Key improvements and features addressed:**

- **Configuration (`config.lua`):** Centralized and more comprehensive.
- **Utilities (`utils.lua`):** Common functions are now shared, improving modularity (e.g., color math, selection helpers).
- **Persistence (`storage.lua`):** JSON-based storage in a project-local directory (`.numhi_data/`) for highlights and notes, addressing a major previous issue.
- **Core Logic (`core.lua`):**
  - Manages highlights with UUIDs.
  - Extmark `user_data` now only stores the `numhi_uuid`, making it lighter and more robust.
  - Applies highlights on `BufEnter`.
  - Saves data on `BufWritePost` and `VimLeavePre`.
  - Basic undo/redo for highlight creation/deletion.
  - Handles category labels.
  - `get_highlight_info_at_cursor` is designed to work when the cursor is anywhere within the highlight.
  - Clears exact-match highlights before applying a new one to prevent simple overlaps.
- **Notes (`notes.lua`):**
  - Manages floating note windows.
  - Positions note window below the highlight (with basic adjustment if it goes off-screen).
  - Auto-saves notes (configurable).
  - Extracts tags (e.g., `#tag`) from note content and associates them with the highlight.
  - Handles linking notes to highlights via UUIDs.
- **UI (`ui.lua`):**
  - Provides functions for consistent user feedback (echo, notify).
  - Implements hover tooltips for highlights.
  - Rich palette change notifications.
  - Statusline component logic.
  - Placeholders for future picker integrations.
- **Initialization (`init.lua`):**
  - Orchestrates the setup of all modules.
  - Sets up keymaps and autocommands.
  - Provides statusline integration.
- **Issue Fixes Addressed (from user's list):**
  - "Notes not actually persisted": Addressed by `storage.lua`.
  - "Echo line only on first byte": `core.get_highlight_info_at_cursor` and `ui.show_hover_tooltip` are designed to check the cursor's relation to the full highlight span.
  - "Opening note a second time => E95": `notes.lua` logic checks for existing note window for the same highlight.
  - Statusline component integration improved.

**Further Work / Not Yet Implemented from "Desired Features" / "Personal Perspective":**

- **Advanced Pickers (Telescope/FZF):** Stubs are in `ui.lua`. Requires specific Telescope API usage.
- **Markdown Export (`export.lua`):** This module is not yet created.
- **Grow/Shrink Commands:** Not implemented. Would involve modifying existing extmark ranges.
- **Dot-repeat:** Requires `vim.o.opfunc` or similar, more advanced.
- **Highlight Navigation Commands:** (next/prev of same color/palette/any). Requires functions in `core.lua` to find and jump to extmarks.
- **Note Reordering/Sorting in a list view:** Requires a dedicated UI for listing notes.
- **Overlap/Blend Indicator:** Advanced visual feature.
- **S-Reader Mode:** Advanced feature.
- **Custom Tree-sitter jumps / `flash.nvim` integration / remote operator:** These are advanced and somewhat outside the direct scope of core highlighting/notes, but noted.
- **Precise URL stripping:** Separate utility.
- **Refined error handling and edge case management:** Present but can always be improved.
- **Comprehensive testing.**

This provides a solid, refactored base that addresses many of the user's core requirements and pain points. The next steps would involve creating `export.lua`, implementing the picker UIs, and then tackling the more advanced features. The user should place these files in their `~/.config/nvim/lua/numhi/` directory and update their main Neovim config to `require("numhi").setup(opts)`.
