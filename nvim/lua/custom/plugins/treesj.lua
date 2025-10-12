return {
  'Wansmer/treesj',
  keys = { '<space>m', '<space>j', '<space>s' },
  opts = {},
  vim.keymap.set('n', '<leader>M', function()
    require('treesj').toggle { split = { recursive = true } }
  end),
}
