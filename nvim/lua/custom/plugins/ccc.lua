return {
  'uga-rosa/ccc.nvim',
  config = function()
    assert(vim.o.termguicolors == true)
    local ccc = require 'ccc'
    local mapping = ccc.mapping

    ccc.setup {
      -- Settings go here, bitch.
      highlighter = {
        auto_enable = true,
        lsp = true,
      },
      inputs = {
        ccc.input.rgb,
        ccc.input.hsl,
        ccc.input.hwb,
        ccc.input.lab,
        ccc.input.lch,
        ccc.input.oklab,
        ccc.input.oklch,
        ccc.input.cmyk,
        ccc.input.hsluv,
        ccc.input.okhsl,
        ccc.input.hsv,
        ccc.input.okhsv,
        ccc.input.xyz,
      },
      output = {
        ccc.output.hex,
        ccc.output.hex_short,
        ccc.output.css_rgb,
        ccc.output.css_rgba,
        ccc.output.css_hsl,
        ccc.output.css_hwb,
        ccc.output.css_lab,
        ccc.output.css_lch,
        ccc.output.css_oklab,
        ccc.output.css_oklch,
      },
      pickers = {
        -- ccc.picker.trailing_whitespace {
        --   ---@type table<string, string>
        --   --- Keys are filetypes, values are colors (6-digit hex)
        --   palette = {},
        --   ---@type string
        --   --- Default color. 6-digit hex representation.
        --   default_color = '#db7093',
        --   ---@type string[]|true
        --   --- List of filetypes for which highlighting is enabled or true.
        --   enable = true,
        --   ---@type string[]|fun(bufnr: number): boolean
        --   --- Used only when enable is true. List of filetypes to disable
        --   --- highlighting or a function that returns true when you want
        --   --- to disable it.
        --   disable = {},
        -- },
        ccc.picker.hex,
        ccc.picker.css_rgb,
        ccc.picker.css_hsl,
        ccc.picker.css_hwb,
        ccc.picker.css_lab,
        ccc.picker.css_lch,
        ccc.picker.css_oklab,
        ccc.picker.css_oklch,
        ccc.picker.custom_entries {
          red = '#ff0000',
          green = '#00ff00',
        },
      },
    }
    local map = vim.keymap.set
    map(
      {
        'n',
      },
      '<leader>cp',
      '<CMD>CccPick<CR>',
      {
        desc = '(hover enabled) Open Color Picker.',
      }
    )
  end,
}
