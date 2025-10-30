-- 󰒋 BEGIN conform.nvim plugin block  ──────────────────────────────────────────
return {
  'stevearc/conform.nvim',
  event = 'BufWritePre', -- auto-format on save
  opts = {
    -- run formatter, else fall back to any LSP that does formatting
    format_on_save = function(bufnr)
      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end
      return { timeout_ms = 1000, lsp_format = 'fallback' }
    end,
    --- Which formatter(s) to run per filetype ------------------------
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff' }, -- uses the Ruff formatter  :contentReference[oaicite:0]{index=0}
      sh = { 'shfmt' },
      json = { 'fixjson' },
      jsonc = { 'fixjson' },
      markdown = { 'rumdl', 'mdsf' },
      javascript = { 'standardjs' }, -- standardjs is built-in  :contentReference[oaicite:1]{index=1}
      typescript = { 'standardjs' },
      -- yaml = { 'prettierd' },
      -- html = { 'prettierd' },
      -- css = { 'prettierd' },
      c = { 'clang_format' },
      cpp = { 'clang_format' },
    },

    --- Per-formatter tweaks ------------------------------------------
    formatters = {
      clang_format = { prepend_args = { '--style', '{BasedOnStyle: llvm, IndentWidth: 8}' } }, -- Linux style  :contentReference[oaicite:2]{index=2}
      shfmt = { prepend_args = { '-i', '4' } },
      fixjson = { prepend_args = { '--indent', '4' } },
    },
  },
  vim.api.nvim_create_user_command('FormatDisable', function(args)
    if args.bang then
      -- FormatDisable! will disable formatting just for this buffer
      vim.b.disable_autoformat = true
    else
      vim.g.disable_autoformat = true
    end
  end, {
    desc = 'Disable autoformat-on-save',
    bang = true,
  }),
  vim.api.nvim_create_user_command('FormatEnable', function()
    vim.b.disable_autoformat = false
    vim.g.disable_autoformat = false
  end, {
    desc = 'Re-enable autoformat-on-save',
  }),
}
