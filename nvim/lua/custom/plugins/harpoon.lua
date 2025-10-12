return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    local harpoon = require 'harpoon'

    local ui = harpoon.ui
    local list = harpoon:list()
    -- REQUIRED: Initialize Harpoon with necessary settings
    harpoon:setup {
      settings = {
        save_on_toggle = false, -- Save Harpoon list when toggling the UI
        sync_on_ui_close = false, -- Sync Harpoon list to disk when closing the UI
        key = function()
          return vim.loop.cwd() -- Use the current working directory as the key
        end,
      },
    }
    -- END REQUIRED

    -- Add file to Harpoon list
    vim.keymap.set('n', '<leader><leader><leader>a', function()
      harpoon:list():add()
    end, {
      desc = 'Add file to Harpoon',
    })

    -- Toggle the Harpoon quick menu with the current list
    vim.keymap.set('n', '<leader>e', function()
      ui:toggle_quick_menu(list, {
        on_select = function(_, item, _)
          local buf = vim.fn.bufnr(item.value, true)
          vim.fn.bufload(buf, {
            force = true,
          })
          vim.api.nvim_set_current_buf(buf)
          ui:close_menu()
        end,
      })
    end, {
      desc = 'Harpoon menu (force)',
    })

    -- quick jumps, like lots of public configs
    for i = 1, 6 do
      vim.keymap.set('n', ('<leader>%d'):format(i), function()
        list:select(i)
      end, {
        desc = ('Harpoon to file %d'):format(i),
      })
    end

    -- Toggle previous & next buffers stored within Harpoon list
    vim.keymap.set('n', '<C-S-P>', function()
      harpoon:list():prev()
    end, {
      desc = 'Navigate to Previous Harpoon Mark',
    })
    vim.keymap.set('n', '<C-S-N>', function()
      harpoon:list():next()
    end, {
      desc = 'Navigate to Next Harpoon Mark',
    })
  end,
}
