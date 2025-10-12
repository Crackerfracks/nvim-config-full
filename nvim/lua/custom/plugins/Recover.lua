return {
  'chrisbra/Recover.vim',
  event = 'VeryLazy', -- load on first file‑open
  init = function()
    -- optional: skip the standard prompt entirely and let the plugin handle it
    vim.opt.shortmess:append 'A'
  end,
}
