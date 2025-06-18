return {
  'CWood-sdf/pineapple',
  -- Pineapple writes its own dependency list into this file as you install themes
  dependencies = require 'pineapple_registry.pineapple',
  opts = {
    installedRegistry = 'pineapple_registry.pineapple',
    colorschemeFile = 'after/plugin/theme.lua',
  },
  cmd = 'Pineapple',
  vim.keymap.set('n', '<leader><leader>cs', '<cmd>Pineapple<CR>', { desc = 'Pineapple Theme Browser' }),
}
