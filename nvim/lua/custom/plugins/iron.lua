return {
  'Vigemus/iron.nvim',
  config = function()
    local iron = require 'iron.core'
    local view = require 'iron.view'
    local common = require 'iron.fts.common'

    iron.setup {
      config = {
        scratch_repl = true,
        repl_definition = {
          sh = {
            command = {
              'zsh',
            },
          },
          python = {
            command = {
              'python3',
            },
            format = common.bracketed_paste_python,
            block_deviders = {
              '# %%',
              '#%%',
            },
          },
        },
        repl_filetype = function(bufnr, ft)
          return ft
        end,
        repl_open_cmd = view.split.horizontal.botright(0.4),
      },
      keymaps = {
        toggle_repl = '<leader>rr',
        restart_repl = '<leader>rR',
        send_motion = '<leader>rsc',
        visual_send = '<leader>rsc',
        send_file = '<leader>rsf',
        send_line = '<leader>rsl',
        send_paragraph = '<leader>rsp',
        send_until_cursor = '<leader>rsu',
        send_mark = '<leader>rsm',
        send_code_block = '<leader>rsb',
        send_code_block_and_move = '<leader>rsn',
        mark_motion = '<leader>rmc',
        mark_visual = '<leader>rmc',
        remove_mark = '<leader>rmd',
        cr = '<leader>rs<cr>',
        interrupt = '<leader>rs <leader>',
        exit = '<leader>rsq',
        clear = '<leader>rcl',
      },
      highlight = {
        italic = true,
      },
      ignore_blank_lines = true,
    }

    vim.keymap.set('n', '<leader>rf', '<cmd>IronFocus<cr>')
    vim.keymap.set('n', '<leader>rh', '<cmd>IronHide<cr>')
  end,
}
