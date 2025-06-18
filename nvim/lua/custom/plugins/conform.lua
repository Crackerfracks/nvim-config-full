-- 󰒋 BEGIN conform.nvim plugin block  ──────────────────────────────────────────
return {
  'stevearc/conform.nvim',
  event = 'BufWritePre', -- auto-format on save
  opts = {
    -- run formatter, else fall back to any LSP that does formatting
    format_on_save = { lsp_fallback = true, async = false, timeout_ms = 1000 },

    --- Which formatter(s) to run per filetype ------------------------
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff' }, -- uses the Ruff formatter  :contentReference[oaicite:0]{index=0}
      sh = { 'shfmt' },
      json = { 'fixjson', 'prettier' },
      jsonc = { 'fixjson' },
      markdown = { 'mdformat', 'alex' },
      javascript = { 'prettier', 'standardjs' }, -- standardjs is built-in  :contentReference[oaicite:1]{index=1}
      typescript = { 'prettier', 'standardjs' },
      yaml = { 'prettier' },
      html = { 'prettier' },
      css = { 'prettier' },
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
}
