return {
  'olimorris/codecompanion.nvim',
  -- dependencies = {
  --   'nvim-lua/plenary.nvim',
  --   'nvim-treesitter/nvim-treesitter',
  -- },
  -- config = function()
  --   require('codecompanion').setup {
  --     adapters = {
  --       openai = function()
  --         return require('codecompanion.adapters').extend('openai', {
  --           env = {
  --             api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
  --           },
  --           schema = {
  --             model = {
  --               default = 'o3-mini',
  --             },
  --           },
  --         })
  --       end,
  --       openai_high = function()
  --         return require('codecompanion.adapters').extend('openai', {
  --           env = {
  --             api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
  --           },
  --           schema = {
  --             model = {
  --               default = 'o3-mini-high',
  --             },
  --           },
  --         })
  --       end,
  --       openai_gpt4 = function()
  --         return require('codecompanion.adapters').extend('openai', {
  --           env = {
  --             api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
  --           },
  --           schema = {
  --             model = {
  --               default = 'gpt-4o',
  --             },
  --           },
  --         })
  --       end,
  --       openai_gpt4mini = function()
  --         return require('codecompanion.adapters').extend('openai', {
  --           env = {
  --             api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
  --           },
  --           schema = {
  --             model = {
  --               default = '4o-mini',
  --             },
  --           },
  --         })
  --       end,
  --       anthropic_claude_3_5 = function()
  --         return require('codecompanion.adapters').extend('anthropic', {
  --           env = {
  --             api_key = vim.env.ANTHROPIC_API_KEY or '<YOUR_ANTHROPIC_API_KEY>',
  --           },
  --           schema = {
  --             model = {
  --               default = 'claude-3-5-haiku-latest',
  --             },
  --           },
  --         })
  --       end,
  --       anthropic_claude_3_7 = function()
  --         return require('codecompanion.adapters').extend('anthropic', {
  --           env = {
  --             api_key = vim.env.ANTHROPIC_API_KEY or '<YOUR_ANTHROPIC_API_KEY>',
  --           },
  --           schema = {
  --             model = {
  --               default = 'claude-3-7-sonnet-latest',
  --             },
  --           },
  --         })
  --       end,
  --     },
  --     strategies = {
  --       chat = {
  --         adapter = 'openai',
  --       },
  --       inline = {
  --         adapter = 'openai',
  --       },
  --     },
  --     display = {
  --       chat = {
  --         window = {
  --           layout = 'vertical', -- default side buffer layout
  --           position = 'right', -- appears on the right side
  --           border = 'single',
  --           height = 0.8,
  --           width = 0.5,
  --           relative = 'editor',
  --         },
  --       },
  --     },
  --   }
  --   local map = vim.keymap.set
  --   -- Toggle CodeCompanion chat interface (double leader cc)
  --   map(
  --     {
  --       'n',
  --       'v',
  --     },
  --     '<leader><leader>cc',
  --     function()
  --       require('codecompanion').toggle()
  --     end,
  --     {
  --       desc = 'Toggle CodeCompanion chat',
  --     }
  --   )
  --   -- Open CodeCompanion Action Palette (double leader cca)
  --   map(
  --     {
  --       'n',
  --       'v',
  --     },
  --     '<leader><leader>cca',
  --     '<CMD>CodeCompanionActions<CR>',
  --     {
  --       desc = 'Open CodeCompanion Action Palette',
  --     }
  --   )
  --   -- Inline assistant on selection (visual mode) and current line (normal mode)
  --   map('v', '<leader><leader>cci', ":'<,'>CodeCompanion ", {
  --     desc = 'Inline assistant on selection',
  --   })
  --   map('n', '<leader><leader>cci', ':CodeCompanion ', {
  --     desc = 'Inline assistant on current line',
  --   })
  -- end
  opts = {
    adapters = {
      openai = function()
        return require('codecompanion.adapters').extend('openai', {
          env = {
            api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
          },
          schema = {
            model = {
              default = 'o3-mini',
            },
          },
        })
      end,
      openai_high = function()
        return require('codecompanion.adapters').extend('openai', {
          env = {
            api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
          },
          schema = {
            model = {
              default = 'o3-mini-high',
            },
          },
        })
      end,
      openai_gpt4 = function()
        return require('codecompanion.adapters').extend('openai', {
          env = {
            api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
          },
          schema = {
            model = {
              default = 'gpt-4o',
            },
          },
        })
      end,
      openai_gpt4mini = function()
        return require('codecompanion.adapters').extend('openai', {
          env = {
            api_key = vim.env.OPENAI_API_KEY or '<YOUR_OPENAI_API_KEY>',
          },
          schema = {
            model = {
              default = '4o-mini',
            },
          },
        })
      end,
      anthropic_claude_3_5 = function()
        return require('codecompanion.adapters').extend('anthropic', {
          env = {
            api_key = vim.env.ANTHROPIC_API_KEY or '<YOUR_ANTHROPIC_API_KEY>',
          },
          schema = {
            model = {
              default = 'claude-3-5-haiku-latest',
            },
          },
        })
      end,
      anthropic_claude_3_7 = function()
        return require('codecompanion.adapters').extend('anthropic', {
          env = {
            api_key = vim.env.ANTHROPIC_API_KEY or '<YOUR_ANTHROPIC_API_KEY>',
          },
          schema = {
            model = {
              default = 'claude-3-7-sonnet-latest',
            },
          },
        })
      end,
    },
    strategies = {
      chat = {
        adapter = 'openai',
      },
      inline = {
        adapter = 'openai',
      },
    },
    display = {
      chat = {
        window = {
          layout = 'vertical', -- default side buffer layout
          position = 'right', -- appears on the right side
          border = 'single',
          height = 0.8,
          width = 0.5,
          relative = 'editor',
        },
      },
    },
  },
  -- Toggle CodeCompanion chat interface (double leader cc)
  vim.keymap.set(
    {
      'n',
      'v',
    },
    '<leader><leader>cc',
    function()
      require('codecompanion').toggle()
    end,
    {
      desc = 'Toggle CodeCompanion chat',
    }
  ),
  -- Open CodeCompanion Action Palette (double leader cca)
  vim.keymap.set(
    {
      'n',
      'v',
    },
    '<leader><leader>cca',
    '<CMD>CodeCompanionActions<CR>',
    {
      desc = 'Open CodeCompanion Action Palette',
    }
  ),
  -- Inline assistant on selection (visual mode) and current line (normal mode)
  vim.keymap.set('v', '<leader><leader>cci', ":'<,'>CodeCompanion ", {
    desc = 'Inline assistant on selection',
  }),
  vim.keymap.set('n', '<leader><leader>cci', ':CodeCompanion ', {
    desc = 'Inline assistant on current line',
  }),
}
