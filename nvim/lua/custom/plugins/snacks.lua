return {
  'folke/snacks.nvim',
  lazy = false,
  priority = 1000,
  version = '*',
  ---@type snacks.Config:
  dependencies = {
    'nvim-orgmode/orgmode', -- already present
    'nvim-lua/plenary.nvim', -- snacks utilities
    'nvim-tree/nvim-web-devicons',
    'echasnovski/mini.icons', -- pretty glyphs for the buttons
  },
  opts = {
    animate = {
      enabled = false,
      easing = 'outInBounce',
      duration = 5,
      fps = 120,
    },
    bigfile = {
      enabled = true,
    },
    dashboard = {
      enabled = true,
    },
    indent = {
      enabled = false,
    },
    input = {
      enabled = true,
    },
    notifier = {
      enabled = true,
    },
    picker = {
      enabled = true,
    },
    quickfile = {
      enabled = true,
    },
    scroll = {
      enabled = false,
    },
    statuscolumn = {
      enabled = true,
    },
    words = {
      enabled = true,
    },
    image = {
      enabled = true,
    },
    styles = {
      notification = {
        -- For line-wrapping in notifications, uncomment:
        -- wo = { wrap = true },
      },
    },
  },
  keys = {
    {
      '<leader>z',
      function()
        require('snacks').zen()
      end,
      desc = 'Toggle Zen Mode',
    },
    {
      '<leader>Z',
      function()
        require('snacks').zen.zoom()
      end,
      desc = 'Toggle Zoom',
    },
    {
      '<leader><leader>.',
      function()
        require('snacks').scratch()
      end,
      desc = 'Toggle Scratch Buffer',
    },
    {
      '<leader><leader>Ss',
      function()
        require('snacks').scratch.select()
      end,
      desc = 'Select Scratch Buffer',
    },
    {
      '<leader><leader><leader>n',
      function()
        require('snacks').notifier.show_history()
      end,
      desc = 'Notification History',
    },
    {
      '<leader>bd',
      function()
        require('snacks').bufdelete()
      end,
      desc = 'Delete Buffer',
    },
    {
      '<leader>cR',
      function()
        require('snacks').rename.rename_file()
      end,
      desc = 'Rename File',
    },
    {
      '<leader>gB',
      function()
        require('snacks').gitbrowse()
      end,
      desc = 'Git Browse',
      mode = {
        'n',
        'v',
      },
    },
    {
      '<leader>gb',
      function()
        require('snacks').git.blame_line()
      end,
      desc = 'Git Blame Line',
    },
    {
      '<leader>gf',
      function()
        require('snacks').lazygit.log_file()
      end,
      desc = 'Lazygit Current File History',
    },
    {
      '<leader>gg',
      function()
        require('snacks').lazygit()
      end,
      desc = 'Lazygit',
    },
    {
      '<leader>gl',
      function()
        require('snacks').lazygit.log()
      end,
      desc = 'Lazygit Log (cwd)',
    },
    {
      '<leader>un',
      function()
        require('snacks').notifier.hide()
      end,
      desc = 'Dismiss All Notifications',
    },
    {
      '<c-/>',
      function()
        require('snacks').terminal()
      end,
      desc = 'Toggle Terminal',
    },
    {
      '<c-_>',
      function()
        require('snacks').terminal()
      end,
      desc = 'which_key_ignore',
    },
    {
      ']]',
      function()
        require('snacks').words.jump(vim.v.count1)
      end,
      desc = 'Next Reference',
      mode = {
        'n',
        't',
      },
    },
    {
      '[[',
      function()
        require('snacks').words.jump(-vim.v.count1)
      end,
      desc = 'Prev Reference',
      mode = {
        'n',
        't',
      },
    },
    {
      '<leader>N',
      desc = 'Neovim News',
      function()
        require('snacks').win {
          file = vim.api.nvim_get_runtime_file('doc/news.txt', false)[1],
          width = 0.6,
          height = 0.6,
          wo = {
            spell = false,
            wrap = true,
            signcolumn = 'yes',
            statuscolumn = ' ',
            conceallevel = 3,
          },
        }
      end,
    },
  },
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Put debugging/inspection helpers in globalspace
        _G.dd = function(...)
          require('snacks.debug').inspect(...)
        end
        _G.bt = function()
          require('snacks.debug').backtrace()
        end

        -- Override the built-in `print` to show objects with snacks' pretty printing
        vim.print = _G.dd

        -- Some helpful toggles
        local toggle = require 'snacks.toggle'

        toggle
          .option('spell', {
            name = 'Spelling',
          })
          :map '<leader>us'
        toggle
          .option('wrap', {
            name = 'Wrap',
          })
          :map '<leader>uw'
        toggle.option('relativenumber', { name = 'Relative Number' }):map '<leader>uL'
        toggle.diagnostics():map '<leader>ud'
        toggle.line_number():map '<leader>ul'
        toggle
          .option('conceallevel', {
            off = 0,
            on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
          })
          :map '<leader>uc'
        toggle.treesitter():map '<leader>uT'
        toggle
          .option('background', {
            off = 'light',
            on = 'dark',
            name = 'Dark Background',
          })
          :map '<leader>ub'
        toggle.inlay_hints():map '<leader>uh'
        toggle.indent():map '<leader>ug'
        toggle.dim():map '<leader>uD'
      end,
    })
  end,
}
