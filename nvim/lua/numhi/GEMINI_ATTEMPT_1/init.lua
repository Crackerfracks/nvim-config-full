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
  -- M.config holds the fully merged configuration for the plugin instance
  M.config = vim.tbl_deep_extend("force", utils_module.deepcopy(config_defaults), user_opts or {})

  -- CRITICAL  FIX: Populate M.state.plugin_config with the merged M.config
  M.state.plugin_config = M.config

  M.state.active_palette_id = M.config.palettes[1] or ""
  -- Initialize other state components as needed
  M.state.highlights_by_buffer = {}
  M.state.notes_by_id = {}
  M.state.category_labels = {} -- These might be loaded by core from storage later
  M.state.history = {}
  M.state.redo_stack = {}
  M.state.ns_ids = {} -- This will be populated by core_module.setup

  -- Initialize other modules
  core_module = require("numhi.core")
  notes_module = require("numhi.notes")
  ui_module = require("numhi.ui")
  storage_module = require("numhi.storage")

  -- Pass the main M.state object to core.setup.
  -- Core will use state.plugin_config and also populate parts of state (like ns_ids).
  core_module.setup(M.state)

  -- Notes module needs reference to the shared M.state and specific core functions.
  notes_module.initialize(M.state, core_module.save_all_data, core_module.add_history_entry)

  -- UI module needs reference to the shared M.state and specific core functions.
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

