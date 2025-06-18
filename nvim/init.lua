-- DO NOT DELETE THIS LINE - THIS FILE LIVES @ filepath="~/.config/nvim/init.lua"
--
-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ','
vim.g.loaded_netrw = 1 -- hard-disable netrw runtime files
vim.g.loaded_netrwPlugin = 1

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true
-- [[ Setting options ]]
-- See `:help vim.opt`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.opt.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.opt.showmode = false

-- vim.o.lazyredraw = true

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.opt.breakindent = true

-- Fix indents to use four spaces everywhere because fuck not doing that
vim.o.expandtab = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250
-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 250

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = {
  tab = '» ',
  trail = '·',
  nbsp = '␣',
}

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = true
vim.opt.cursorcolumn = false

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

vim.keymap.set('n', '<leader>lz', function()
  local v = not vim.go.lazyredraw
  vim.go.lazyredraw = v
  print('lazyredraw = ' .. tostring(v))
end, { desc = 'Toggle lazyredraw' })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- nvumi Natural Language calculator
vim.keymap.set('n', '<leader><leader>on', '<CMD>Nvumi<CR>', {
  desc = '[O]pen [N]vumi',
})

-- Remapping the hyphen ('-') for Jump To Line in flash.nvim
vim.keymap.set({
  'n',
  'x',
  'o',
}, '<leader>-', '-')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, {
  desc = 'Open diagnostic [Q]uickfix list',
})

vim.api.nvim_set_keymap('n', '<leader><leader>as', ':ASToggle<CR>', {})

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', {
  desc = 'Exit terminal mode',
})

-- BEGIN <leader>pv backup
-- From ThePrimeagen’s tutorial "pv" -> bring up netrw’s file explorer:
-- vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open netrw file explorer" })
-- END <leader>pv backup

vim.keymap.set('n', '<leader>pv', function()
  local dir = vim.fn.expand '%:p:h' -- current file’s directory
  if dir == '' then
    dir = vim.loop.cwd() -- fallback: CWD
  end
  require('oil').open(dir) -- Oil handles both cases
end, {
  desc = 'Open Oil file-explorer',
})

-- Join line below to current line, keep cursor
vim.keymap.set('n', 'J', 'mzJ`z', {
  desc = 'Join with next line, re-center cursor',
})

-- Scroll half page + center plus other scroll'n'center niceties

vim.keymap.set('n', '<C-d>', '<C-d>zz', {
  desc = 'Scroll down half page and center',
})
vim.keymap.set('n', '<C-u>', '<C-u>zz', {
  desc = 'Scroll up half page and center',
})
-- Scroll up/down by whitespace between paragraphs, and center.
vim.keymap.set('n', '{', '{zz', {
  desc = 'Move up by whitespace between paragraphs.',
})
vim.keymap.set('n', '}', '}zz', {
  desc = 'Move down by whitespace between parargraphs',
})

-- Search next/prev, center
vim.keymap.set('n', 'n', 'nzzzv', {
  desc = 'Next search result, center screen',
})
vim.keymap.set('n', 'N', 'Nzzzv', {
  desc = 'Previous search result, center screen',
})

-- Paste over highlighted text without overwriting default register
vim.keymap.set('x', '<leader>p', '"_dP', {
  desc = 'Paste over selection without overwriting register',
})

-- Yank to system clipboard
-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.keymap.set('n', '<leader>y', '"+y', {
  desc = 'Yank line to system clipboard',
})
vim.keymap.set('v', '<leader>y', '"+y', {
  desc = 'Yank selection to system clipboard',
})
vim.keymap.set('n', '<leader>Y', '"+Y', {
  desc = 'Yank to end of line to system clipboard',
})

-- Delete to void register
vim.keymap.set('n', '<leader><leader>d', '"_d', {
  desc = 'Delete into void register',
})
vim.keymap.set('v', '<leader><leader>d', '"_d', {
  desc = 'Delete selection into void register',
})

-- Format buffer
vim.keymap.set('n', '<leader><leader><leader>f', function()
  vim.lsp.buf.format()
end, {
  desc = 'Format buffer via LSP',
})

-- Quick substitution
vim.keymap.set('n', '<leader><leader><leader>s', ':%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>', {
  desc = 'Search & replace word under cursor',
})

-- Make file executable
vim.keymap.set('n', '<leader>x', '<cmd>!chmod +x %<CR>', {
  silent = true,
  desc = 'Make current file executable',
})

-- ─── helpers ────────────────────────────────────────────────────────────────
local state = vim.fn.stdpath 'state' -- ~/.local/state/nvim
local roots = {
  swap = state .. '/swap-tree',
  undo = state .. '/undo-tree',
  back = state .. '/backup-tree',
}

for _, dir in pairs(roots) do
  vim.fn.mkdir(dir, 'p')
end

-- Build   ~/.local/state/nvim/swap-tree/<full/real/dir>   on the fly
local function tree_dir(root, absfile)
  local rel = absfile:gsub('^/', '') -- kill leading slash
  local dir = root .. '/' .. vim.fn.fnamemodify(rel, ':h')
  vim.fn.mkdir(dir, 'p') -- mkdir -p
  return dir
end

-- ——— Assorted fixes —————————————————————————————————————————————————————————

-- ─── autocmds ───────────────────────────────────────────────────────────────
vim.api.nvim_create_autocmd({
  'BufReadPre',
  'BufNewFile',
}, {
  callback = function(ev)
    local full = vim.fn.fnamemodify(ev.file, ':p')
    if full == '' then
      return
    end

    vim.opt_local.directory = {
      tree_dir(roots.swap, full),
    } -- swap
    vim.opt_local.undodir = {
      tree_dir(roots.undo, full),
    } -- undo
    vim.opt_local.backupdir = {
      tree_dir(roots.back, full),
    } -- backups
    vim.opt_local.undofile = true -- keep undo
  end,
})

vim.g.virtual_text_enabled = true

function ToggleVirtualText()
  vim.g.virtual_text_enabled = not vim.g.virtual_text_enabled
  vim.diagnostic.config {
    virtual_text = vim.g.virtual_text_enabled,
  }
  print('Virtual text ' .. (vim.g.virtual_text_enabled and 'enabled' or 'disabled'))
end

vim.api.nvim_set_keymap('n', '<leader><leader>vt', ':lua ToggleVirtualText()<CR>', {
  noremap = true,
  silent = true,
})
-- KICKSTART KEYMAPS
-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
-- vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
-- vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
-- vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
-- vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    lazyrepo,
    lazypath,
  }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to force a plugin to be loaded.
  --

  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`. This is equivalent to the following Lua:
  --    require('gitsigns').setup({ ... })
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = {
          text = '+',
        },
        change = {
          text = '~',
        },
        delete = {
          text = '_',
        },
        topdelete = {
          text = '‾',
        },
        changedelete = {
          text = '~',
        },
      },
    },
  },

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      -- this setting is independent of vim.opt.timeoutlen
      delay = 0,
      icons = {
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        {
          '<leader><leader><leader>c',
          group = '[C]ode',
          mode = {
            'n',
            'x',
          },
        },
        {
          '<leader><leader><leader>d',
          group = '[D]ocument',
        },
        {
          '<leader><leader><leader>r',
          group = '[R]ename',
        },
        {
          '<leader><leader><leader>S',
          group = '[S]earch',
        },
        {
          '<leader><leader><leader>w',
          group = '[W]orkspace',
        },
        {
          '<leader><leader><leader>t',
          group = '[T]oggle',
        },
        {
          '<leader><leader><leader>h',
          group = 'Git [H]unk',
          mode = {
            'n',
            'v',
          },
        },
      },
      keys = {
        scroll_down = '<A-d>',
        scroll_up = '<A-u>',
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      {
        'nvim-telescope/telescope-ui-select.nvim',
      },
      -- Useful for getting pretty icons, but requires a Nerd Font.
      {
        'nvim-tree/nvim-web-devicons',
        enabled = vim.g.have_nerd_font,
      },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        -- pickers = {}
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader><leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader><leader>sk', builtin.keymaps, {
        desc = '[S]earch [K]eymaps',
      })
      vim.keymap.set('n', '<leader><leader>sf', builtin.find_files, {
        desc = '[S]earch [F]iles',
      })
      vim.keymap.set('n', '<leader><leader>ss', builtin.builtin, {
        desc = '[S]earch [S]elect Telescope',
      })
      vim.keymap.set('n', '<leader><leader>sw', builtin.grep_string, {
        desc = '[S]earch current [W]ord',
      })
      vim.keymap.set('n', '<leader><leader>sg', builtin.live_grep, {
        desc = '[S]earch by [G]rep',
      })
      vim.keymap.set('n', '<leader><leader>sd', builtin.diagnostics, {
        desc = '[S]earch [D]iagnostics',
      })
      vim.keymap.set('n', '<leader><leader>sr', builtin.resume, {
        desc = '[S]earch [R]esume',
      })
      vim.keymap.set('n', '<leader><leader>sR.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader><leader><leader>', builtin.buffers, {
        desc = '[ ] Find existing buffers',
      })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, {
        desc = '[/] Fuzzily search in current buffer',
      })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader><leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, {
        desc = '[S]earch [/] in Open Files',
      })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader><leader>sn', function()
        builtin.find_files {
          cwd = vim.fn.stdpath 'config',
        }
      end, {
        desc = '[S]earch [N]eovim files',
      })
    end,
    optional = true,
    opts = function(_, opts)
      local function flash(prompt_bufnr)
        require('flash').jump {
          pattern = '^',
          label = { after = { 0, 0 } },
          search = {
            mode = 'search',
            exclude = {
              function(win)
                return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'TelescopeResults'
              end,
            },
          },
          action = function(match)
            local picker = require('telescope.actions.state').get_current_picker(prompt_bufnr)
            picker:set_selection(match.pos[1] - 1)
          end,
        }
      end
      opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
        mappings = {
          n = { s = flash },
          i = { ['<c-s>'] = flash },
        },
      })
    end,
  },

  -- LSP Plugins
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        {
          path = '${3rd}/luv/library',
          words = {
            'vim%.uv',
          },
        },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'williamboman/mason.nvim', opts = {} },
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      {
        'j-hui/fidget.nvim',
        opts = {},
      },

      -- Allows extra capabilities provided by nvim-cmp
      -- 'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', {
          clear = true,
        }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, {
              buffer = event.buf,
              desc = 'LSP: ' .. desc,
            })
          end

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- Find references for the word under your cursor.
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('<leader>Dt', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('<leader>Ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')

          -- Fuzzy find all the symbols in your current workspace.
          --  Similar to document symbols, except searches over your entire project.
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('<leader>Rn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', {
            'n',
            'x',
          })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', {
              clear = false,
            })
            vim.api.nvim_create_autocmd({
              'CursorHold',
              'CursorHoldI',
            }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({
              'CursorMoved',
              'CursorMovedI',
            }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', {
                clear = true,
              }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds {
                  group = 'kickstart-lsp-highlight',
                  buffer = event2.buf,
                }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map('<leader><leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled {
                bufnr = event.buf,
              })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Change diagnostic symbols in the sign column (gutter)
      -- if vim.g.have_nerd_font then
      --   local signs = { ERROR = '', WARN = '', INFO = '', HINT = '' }
      --   local diagnostic_signs = {}
      --   for type, icon in pairs(signs) do
      --     diagnostic_signs[vim.diagnostic.severity[type]] = icon
      --   end
      --   vim.diagnostic.config { signs = { text = diagnostic_signs } }
      -- end

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('blink.cmp').get_lsp_capabilities())

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        -- clangd = {},
        -- gopls = {},
        -- pyright = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},
        pylsp = {
          settings = {
            pylsp = {
              pyflakes = {
                enabled = false,
              },
              pycodestyle = {
                enabled = false,
              },
              autopep8 = {
                enabled = false,
              },
              yapf = {
                enabled = false,
              },
              mccabe = {
                enabled = false,
              },
              pylsp_mypy = {
                enabled = false,
              },
              pylsp_black = {
                enabled = false,
              },
              pylsp_isort = {
                enabled = false,
              },
            },
          },
        },

        lua_ls = {
          -- cmd = { ... },
          -- filetypes = { ... },
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              diagnostics = {
                globals = {
                  'vim',
                },
                disable = {
                  'missing-fields',
                },
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file('', true),
              },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      --
      -- `mason` had to be setup earlier: to configure its options see the
      -- `dependencies` table for `nvim-lspconfig` above.
      --
      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        -- Lua
        'stylua',
        -- Shell
        'shfmt',
        -- Web / markup
        'prettier',
        'prettierd',
        'markdownlint',
        -- Python
        'ruff',
        -- C / C++
        'clang-format',
        -- JSON & friends
        'fixjson',
        'jsonlint',
        -- JS standard style
        'standardjs',
      })
      require('mason-tool-installer').setup {
        ensure_installed = ensure_installed,
      }

      require('mason-lspconfig').setup {
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },
  {
    'L3MON4D3/LuaSnip', -- snippet engine
    config = function()
      local ls = require 'luasnip'

      ls.config.set_config {
        enable_autosnippets = true,
        history = true,
        updateevents = 'TextChanged,TextChangedI',
      }
      local home = vim.fn.stdpath 'config' .. '/lua/snippets'

      require('luasnip.loaders.from_lua').lazy_load {
        paths = { vim.fn.stdpath 'config' .. '/lua/snippets' },
      }

      vim.keymap.set({ 'i' }, '<S-CR>', function()
        ls.expand()
      end, { silent = true })

      --
      vim.keymap.set({ 'i', 's' }, '<Tab>', function()
        ls.jump(1)
      end, { silent = true })

      -- Jump backwards within a snippet
      vim.keymap.set({ 'i', 's' }, '<S-Tab>', function()
        ls.jump(-1)
      end, { silent = true })
    end,
  },
  { -- TokyoNight colorscheme with full default options, updated to be transparent.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      require('tokyonight').setup {
        style = 'night', -- Available styles: "night", "storm", "moon", "day"
        light_style = 'day', -- The theme is used when vim.o.background is set to light
        transparent = true, -- Enable transparent background
        terminal_colors = true, -- Configure the colors used in the terminal
        styles = {
          comments = {
            italic = true,
          },
          keywords = {
            bold = false,
          },
          functions = {
            bold = true,
          },
          variables = {
            italic = true,
          },
          sidebars = 'dark',
          floats = 'dark',
        },
        day_brightness = 0.3,
        dim_inactive = true,
        lualine_bold = false,
        on_colors = function(colors)
          -- Customize colors if needed
        end,
        on_highlights = function(highlights, colors)
          -- Customize highlights if needed
        end,
        cache = true,
        plugins = {
          all = package.loaded.lazy == nil,
          auto = true,
        },
      }
      vim.cmd.colorscheme 'tokyonight-night'
      -- Optional: Customize highlights further (for example, disable italics on comments)
      vim.cmd.hi 'Comment gui=none'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = {
    'nvim-lua/plenary.nvim',
  }, opts = {
    signs = false,
  } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup {
        n_lines = 500,
      }
      -- require('mini.sessions').setup{ autoread = true }
      -- require('mini.map').setup() -- <-<-<-<- You disabled this for 'petertriho/nvim-scrollbar' -- <-<-<-<- You disabled this for 'petertriho/nvim-scrollbar'
      require('mini.icons').setup()
      require('mini.move').setup {
        -- No need to copy this inside `setup()`. Will be used automatically.

        -- Module mappings. Use `''` (empty string) to disable one.
        mappings = {
          -- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
          left = '<M-S-h>',
          right = '<M-S-l>',
          down = '<M-S-j>',
          up = '<M-S-k>',

          -- Move current line in Normal mode
          line_left = '<M-S-h>',
          line_right = '<M-S-l>',
          line_down = '<M-S-j>',
          line_up = '<M-S-k>',
        },

        -- Options which control moving behavior
        options = {
          -- Automatically reindent selection during linewise vertical move
          reindent_linewise = true,
        },
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup {
        mappings = {
          add = '<leader>sa', -- Add surrounding in Normal and Visual modes
          delete = '<leader>sd', -- Delete surrounding
          find = '<leader>sf', -- Find surrounding (to the right)
          find_left = '<leader>sF', -- Find surrounding (to the left)
          highlight = '<leader>sh', -- Highlight surrounding
          replace = '<leader>sr', -- Replace surrounding
          update_n_lines = '<leader>sn', -- Update `n_lines`

          suffix_last = '<leader>l', -- Suffix to search with "prev" method
          suffix_next = '<leader>n', -- Suffix to search with "next" method
        },
      }

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      statusline.setup {
        use_icons = vim.g.have_nerd_font,
      }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'python',
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
      },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = {
          'ruby',
        },
      },
      indent = {
        enable = true,
        disable = {
          'ruby',
        },
      },
    },
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },

  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  require 'kickstart.plugins.debug',
  require 'kickstart.plugins.indent_line',
  require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  require 'kickstart.plugins.neo-tree',
  -- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'norg',
  callback = function()
    vim.opt_local.conceallevel = 2
  end,
})

-----------------------------------------------------------------------
-- 🪞  Auto‑mirror Kickstart files → ~/Documents/NVIM_CONFIG_MIRRORS
--      + build a single Markdown “bundle” of the entire config
-----------------------------------------------------------------------
do
  ------------------------------------------------------------
  -- 1.  Path helpers
  ------------------------------------------------------------
  local mirror_root = vim.fn.expand '~/Documents/NVIM_CONFIG_MIRRORS'
  vim.fn.mkdir(mirror_root, 'p') -- ensure tree exists

  local BUNDLE = mirror_root .. '/user_neovim_config_complete_collection_w-filepaths.md'

  ------------------------------------------------------------
  -- 2.  Map  <source‑abs‑path> → <dest‑abs‑path>  (one‑way)
  ------------------------------------------------------------
  local mirrors = {
    [vim.fn.expand(vim.fn.stdpath 'config' .. '/init.lua')] = mirror_root .. '/init(home-dotconfig-nvim).lua',

    [vim.fn.expand(vim.fn.stdpath 'config' .. '/lua/custom/plugins/init.lua')] = mirror_root
      .. '/lua/custom/plugins/init(home-dotconfig-nvim-lua-custom-plugins).lua',

    [vim.fn.expand(vim.fn.stdpath 'config' .. '/lua/numhi/core.lua')] = mirror_root .. '/lua/numhi/core(home-dotconfig-nvim-lua-numhi).lua',

    [vim.fn.expand(vim.fn.stdpath 'config' .. '/lua/numhi/init.lua')] = mirror_root .. '/lua/numhi/init(home-dotconfig-nvim-lua-numhi).lua',

    [vim.fn.expand(vim.fn.stdpath 'config' .. '/lua/numhi/palettes.lua')] = mirror_root .. '/lua/numhi/palettes(home-dotconfig-nvim-lua-numhi).lua',

    [vim.fn.expand(vim.fn.stdpath 'config' .. '/lua/numhi/ui.lua')] = mirror_root .. '/lua/numhi/ui(home-dotconfig-nvim-lua-numhi).lua',
  }

  ------------------------------------------------------------
  -- 3.  Utility: read a file & strip fully‑commented lines
  ------------------------------------------------------------
  local function read_code_without_full_comments(path)
    local cleaned, inside_block = {}, false
    for line in io.lines(path) do
      local ltrim = line:match '^%s*(.*)$' or ''
      -- handle long‑form block comments --[[ ... ]]
      if ltrim:find '^%-%-%[%[' then
        inside_block = true
      elseif inside_block and ltrim:find '%]%]' then
        inside_block = false
      elseif not inside_block and not ltrim:find '^%-%-' then
        table.insert(cleaned, line)
      end
    end
    return cleaned
  end

  ------------------------------------------------------------
  -- 4.  Build / overwrite the bundle‑markdown
  ------------------------------------------------------------
  local function rebuild_markdown_bundle()
    local md_parts = {}
    for src, _ in pairs(mirrors) do
      if vim.fn.filereadable(src) == 1 then
        table.insert(md_parts, ('```lua %s'):format(src))
        vim.list_extend(md_parts, read_code_without_full_comments(src))
        table.insert(md_parts, '```')
        table.insert(md_parts, '') -- blank line between fences
      end
    end
    local fh = assert(io.open(BUNDLE, 'w'))
    fh:write(table.concat(md_parts, '\n'))
    fh:close()
  end

  ------------------------------------------------------------
  -- 5.  Autocmds for every mirrored file
  ------------------------------------------------------------
  for src, dst in pairs(mirrors) do
    vim.api.nvim_create_autocmd('BufWritePost', {
      pattern = src,
      callback = function()
        -- 5.1 one‑way copy of the single file
        local dst_dir = vim.fn.fnamemodify(dst, ':h')
        vim.fn.mkdir(dst_dir, 'p')
        vim.fn.system { 'cp', '--', src, dst }

        -- 5.2 rebuild the aggregate Markdown bundle
        rebuild_markdown_bundle()
      end,
      desc = 'Mirror ' .. vim.fn.fnamemodify(src, ':t') .. ' + rebuild bundle',
    })
  end

  -- 6.  Ensure the bundle exists on startup (optional, cheap)
  -- rebuild_markdown_bundle()
end
-----------------------------------------------------------------------

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
