-- ── File-type Switcher (local plugin) ────────────────────────────────────
return {
  dir = vim.fn.stdpath 'config' .. '/lua/custom/filetype_switcher',
  name = 'filetype-switcher.nvim',
  lazy = false, -- load immediately
  dependencies = {
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require 'custom.filetype_switcher'
  end,
}
