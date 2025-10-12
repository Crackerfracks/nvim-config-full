return {
  dir = vim.fn.stdpath 'config' .. '/lua/numhi',
  name = 'numhi.nvim', -- can stay
  dependencies = {
    'hsluv/hsluv-lua',
  },
  lazy = false,
  opts = { -- <- still merged into the second arg
    palettes = {
      'VID',
      'PAS',
      'EAR',
      'MET',
      'CYB',
    },
    key_leader = '<leader><leader>',
    statusline = true,
  },
  config = function(_, opts) -- ② call the *real* module yourself
    require('numhi').setup(opts)
  end,
}
