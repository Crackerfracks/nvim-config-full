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
  config = function()
    local legendary = require 'legendary'
    legendary.setup {
      extensions = {
        which_key = {
          auto_register = true,
        }, -- new location
        lazy_nvim = true,
      },
    }
  end,
}
