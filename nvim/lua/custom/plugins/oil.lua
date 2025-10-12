return {
  'stevearc/oil.nvim',
  lazy = false, -- load eagerly so FileType=oil autocmds are predictable
  opts = {
    default_file_explorer = true, -- keep netrw available
    view_options = {
      show_hidden = false, -- list files that start with “.”
    },
    --  🚨  These keymaps live ONLY inside an Oil buffer
    keymaps = {
      ['s'] = false, -- free `s` for Flash
      ['-'] = false, -- free `-` for Flash
      ['<BS>'] = 'actions.parent', -- Backspace → parent dir
      ['<leader>s'] = 'actions.change_sort', -- <leader>s → sort toggle
      ['g.'] = 'actions.toggle_hidden',
      ['<leader><C-s>'] = false,
      ['<leader><C-h>'] = false,
      ['<leader><C-l>'] = false,
      ['<C-h>'] = false,
      ['<C-k>'] = false,
      ['<C-l>'] = false,
      ['<C-j>'] = false,
      ['yp'] = {
        desc = 'Copy filepath to system clipboard',
        callback = function()
          require('oil.actions').copy_entry_path.callback()
          vim.fn.setreg('+', vim.fn.getreg(vim.v.register))
        end,
      },
      -- (optional) keep `gs` mapped to sort as an alias:
      -- ["gs"] = "actions.change_sort",
    },
  },
  config = function(_, opts)
    require('oil').setup(opts)
  end,
}
