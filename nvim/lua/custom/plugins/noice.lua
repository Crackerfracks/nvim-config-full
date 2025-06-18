return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  opts = {
    -- ── existing options ─────────────────────────────────────────────
    lsp = {
      override = {
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true,
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = false,
    },

    -- ── ✨ new bit: route msg_showmode → nvim-notify ─────────────────
    routes = {
      {
        view = 'notify', -- use nvim-notify popup
        filter = {
          event = 'msg_showmode',
        }, -- only “-- INSERT --”, “-- VISUAL --”, etc.
      },
    },
  },
  dependencies = {
    'MunifTanjim/nui.nvim',
    'rcarriga/nvim-notify',
  },
}
