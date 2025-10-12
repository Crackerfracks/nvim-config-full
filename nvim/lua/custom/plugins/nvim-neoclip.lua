return {
  'AckslD/nvim-neoclip.lua',
  dependencies = {
    {
      'kkharji/sqlite.lua',
      module = 'sqlite',
    }, -- persistence  :contentReference[oaicite:0]{index=0}
    {
      'nvim-telescope/telescope.nvim',
    }, -- picker UI   :contentReference[oaicite:1]{index=1}
  },
  config = function()
    ------------------------------------------------------------------
    -- 1. Core plugin settings (tweak to taste)
    ------------------------------------------------------------------
    require('neoclip').setup {
    history = 1000, -- keep 1 000 items in RAM
    enable_persistent_history = true, -- save to sqlite
      continuous_sync = true, -- manual db_push/db_pull
      preview = true, -- show a preview pane
    }

    ------------------------------------------------------------------
    -- 2. Load the Telescope extension *once* and alias it locally
    ------------------------------------------------------------------
    local telescope = require 'telescope'
    telescope.load_extension 'neoclip' -- :contentReference[oaicite:2]{index=2}
    local clip = telescope.extensions.neoclip -- exposes .default() .plus() .macro()

    ------------------------------------------------------------------
    -- 3. Key‑maps – all silent/non‑recursive with nice descriptions
    ------------------------------------------------------------------
    local map = vim.keymap.set
    local opts = {
      noremap = true,
      silent = true,
    }

    -- Yank history picker (unnamed/") – think “Fuzzy Yank”
    map(
      {
        'n',
        'v',
      },
      '<leader>fy',
      clip.default,
      vim.tbl_extend('force', opts, {
        desc = 'Neoclip • open yank history picker',
      })
    )

    -- System clipboard (+ register) only
    map(
      {
        'n',
        'v',
      },
      '<leader>fY',
      clip.plus,
      vim.tbl_extend('force', opts, {
        desc = 'Neoclip • +‑register history',
      })
    )

    -- Utility helpers that ship with neoclip
    map(
      'n',
      '<leader>fc',
      require('neoclip').clear_history,
      vim.tbl_extend('force', opts, {
        desc = 'Neoclip • clear history',
      })
    ) -- :contentReference[oaicite:4]{index=4}
    map(
      'n',
      '<leader>fs',
      require('neoclip').db_push,
      vim.tbl_extend('force', opts, {
        desc = 'Neoclip • push DB → disk',
      })
    ) -- :contentReference[oaicite:5]{index=5}
    map(
      'n',
      '<leader>fS',
      require('neoclip').db_pull,
      vim.tbl_extend('force', opts, {
        desc = 'Neoclip • pull DB ← disk',
      })
    ) -- :contentReference[oaicite:6]{index=6}
  end,
}
