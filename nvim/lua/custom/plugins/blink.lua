return {
  'saghen/blink.cmp',
  -- optional: provides snippets for the snippet source
  dependencies = 'rafamadriz/friendly-snippets',

  -- use a release tag to download pre-built binaries
  version = '*',
  -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
  build = 'cargo build --release',
  -- If you use nix, you can build from source using latest nightly rust with:
  -- build = 'nix run .#build-plugin',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    signature = { enabled = true },
    -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept, C-n/C-p for up/down)
    -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys for up/down)
    -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
    --
    -- All presets have the following mappings:
    -- C-space: Open menu or open docs if already open
    -- C-e: Hide menu
    -- C-k: Toggle signature help
    -- See the full "keymap" documentation for information on defining your own keymap.
    keymap = {
      -- set to 'none' to disable the 'default' preset
      preset = 'default',

      ['<Up>'] = {},
      ['<Down>'] = {},

      ['<C-space>'] = {
        'show',
        'show_documentation',
        'hide_documentation',
      },
      ['<C-e>'] = {
        'hide',
        'fallback',
      },
      ['<Tab>'] = {
        'snippet_forward',
        function() -- sidekick next edit suggestion
          return require('sidekick').nes_jump_or_apply()
        end,
        -- function ()
        --   return vim.lsp.inline_completion.get()
        -- end,
        'fallback',
      },
      ['<S-CR>'] = {
        'accept',
        'fallback',
      },
      ['<S-Tab>'] = {
        'snippet_backward',
        'fallback',
      },
      ['<A-k>'] = {
        'select_prev',
        'fallback',
      },
      ['<A-j>'] = {
        'select_next',
        'fallback',
      },
      ['<C-k>'] = {
        'select_prev',
        'fallback_to_mappings',
      },
      ['<C-j>'] = {
        'select_next',
        'fallback_to_mappings',
      },
      ['<C-b>'] = {
        'scroll_documentation_up',
        'fallback',
      },
      ['<C-f>'] = {
        'scroll_documentation_down',
        'fallback',
      },
      ['<C-n>'] = {
        'show_signature',
        'hide_signature',
        'fallback',
      },
    },
    appearance = {
      -- Sets the fallback highlight groups to nvim-cmp's highlight groups
      -- Useful for when your theme doesn't support blink.cmp
      -- Will be removed in a future release
      use_nvim_cmp_as_default = true,
      -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono',
    },
    -- Default list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      per_filetype = {
        org = { 'orgmode' },
        markdown = {
          'lsp',
          'path',
          'snippets',
          'buffer',
        },
      },
      default = {
        'lazydev',
        'lsp',
        'path',
        'snippets',
        'buffer',
      },
      providers = {
        -- orgmode = {
        --   name = 'Orgmode',
        --   module = 'orgmode.org.autocompletion.blink',
        --   fallbacks = {
        --     'buffer',
        --   },
        -- },
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          -- make lazydev completions top priority (see `:h blink.cmp`)
          score_offset = 100,
        },
      },
    },
    -- Adding in the providers finally lol
    -- Blink.cmp uses a Rust fuzzy matcher by default for typo resistance and significantly better performance
    -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
    -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
    --
    -- See the fuzzy documentation for more information
    fuzzy = {
      implementation = 'prefer_rust_with_warning',
    },
  },
  opts_extend = {
    'sources.default',
  },
}
