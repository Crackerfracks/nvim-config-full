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
