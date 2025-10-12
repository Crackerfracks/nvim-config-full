-----------------------------------------------------------------------

-- legendary.nvim — key legends + bootstrap dashboards
-----------------------------------------------------------------------
return {
  'mrjones2014/legendary.nvim',
  version = '*',
  lazy = false,
  dependencies = {
    'folke/which-key.nvim',
    'folke/snacks.nvim',
    'MunifTanjim/nui.nvim',
  },
  opts = {
    extensions = {
      which_key = {
        auto_register = true,
      }, -- new location
      lazy_nvim = true,
    },
    vim.keymap.set('n', '<leader><leader><leader><CR>', '<CMD>Legendary<CR>', {
      desc = 'Search commands w/Legendary',
    }),
  },
  -- config = function()
  --   local legendary = require 'legendary'
  --   legendary.setup {
  --     extensions = {
  --       which_key = {
  --         auto_register = true,
  --       }, -- new location
  --       lazy_nvim = true,
  --     },
  --   }
  -- end,
}
