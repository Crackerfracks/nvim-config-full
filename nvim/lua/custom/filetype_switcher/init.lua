--------------------------------------------------------------------------------
-- File-type Switcher  •  lua/custom/filetype_switcher/init.lua
--------------------------------------------------------------------------------
local M = {}

-- ❶ Collect every known & aliased file-type ------------------------------
local function list_filetypes()
  local seen, out = {}, {}

  -- core + plugins: syntax/{ft}.vim                                       -- nvim_get_runtime_file docs
  for _, p in ipairs(vim.api.nvim_get_runtime_file("syntax/*.vim", true)) do
    seen[vim.fn.fnamemodify(p, ":t:r")] = true
  end

  -- aliases exposed by vim.filetype.languages                             -- filetype.lua table
  for ft, _ in pairs((vim.filetype or {}).languages or {}) do
    seen[ft] = true
  end

  for ft in pairs(seen) do out[#out + 1] = ft end
  table.sort(out)
  return out
end

-- ❷ Telescope picker ------------------------------------------------------
local function telescope_picker(opts)
  opts = opts or {}
  local finders, actions, action_state, conf =
    require("telescope.finders"),
    require("telescope.actions"),
    require("telescope.actions.state"),
    require("telescope.config").values

  require("telescope.pickers").new(opts, {
    prompt_title = "Set &buffer file-type",
    finder       = finders.new_table { results = list_filetypes() },
    sorter       = conf.generic_sorter(opts),

    attach_mappings = function(_, map)
      actions.select_default:replace(function(bufnr)
        local sel = action_state.get_selected_entry()
        actions.close(bufnr)
        if sel then
          vim.bo.filetype = sel[1]
          vim.notify("filetype → " .. sel[1], vim.log.levels.INFO,
                     { title = "File-type Switcher" })
        end
      end)
      return true
    end,
  }):find()
end

-- ❸ Ex-command & key-map --------------------------------------------------
function M.setup()
  vim.api.nvim_create_user_command(
    "FiletypeSwitch",
    function(arg)
      if arg.args ~= "" then
        vim.bo.filetype = arg.args
        vim.notify("filetype → " .. arg.args, vim.log.levels.INFO)
      else
        telescope_picker({})
      end
    end,
    { nargs = "?", complete = "filetype",
      desc = "Set current buffer’s file-type" }
  )

  -- <leader><leader>sf  (“switch file-type”)
  vim.keymap.set("n", "<leader><leader>Sf", telescope_picker,
    { desc = "Switch buffer file-type (Telescope)" })
end

M.setup()
return M

