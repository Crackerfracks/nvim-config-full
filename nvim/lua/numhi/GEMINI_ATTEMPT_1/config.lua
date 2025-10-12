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

