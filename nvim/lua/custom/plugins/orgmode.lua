-----------------------------------------------------------------------
-- orgmode.nvim — Org‑mode core  +  capture
-----------------------------------------------------------------------

return {
  -- visual polish FIRST, so org-menu picks it up
  {
    'danilshvalov/org-modern.nvim',
    lazy = true, -- loads automatically when an org buffer opens
    config = false,
  },

  -- pretty outline symbols
  {
    'nvim-orgmode/org-bullets.nvim', -- <- single canonical repo
    lazy = true,
  },

  -- fuzzy finding / refiling
  {
    'nvim-orgmode/telescope-orgmode.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
      require('telescope').load_extension 'orgmode'
      vim.keymap.set('n', '<leader><leader>ff', '<cmd>Telescope orgmode search_headings<CR>', { desc = 'Find Org heading' })

      vim.keymap.set('n', '<leader><leader>fr', '<cmd>Telescope orgmode refile_heading<CR>', { desc = 'Refile Org item (move under new heading)' })
    end,
  },
  -- =============== CORE =============================================
  {
    'nvim-orgmode/orgmode',
    version = '*',
    lazy = false, -- we want <leader>oa immediately
    dependencies = {
      'danilshvalov/org-modern.nvim',
      'nvim-orgmode/org-bullets.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      ----------------------------------------------------------------
      -- 1. Helpers
      ----------------------------------------------------------------
      local Menu = require 'org-modern.menu' -- pretty menu window

      ----------------------------------------------------------------
      -- 2. Core setup
      ----------------------------------------------------------------
      require('orgmode').setup {
        -- ---------- FILE LOCATIONS ----------------------------------
        org_agenda_files = { '~/org/**/*' },
        org_default_notes_file = '~/org/refile.org',
        org_startup_folded = 'showeverything',
        org_hide_leading_stars = true,
        org_agenda_skip_scheduled_if_done = true,
        org_agenda_skip_deadline_if_done = true,

        --- KEYWORDS & TAGS ----------------------------------------------
        org_todo_keywords = {
          'TODO(t)',
          'IN_PROGRESS(i)',
          'BLOCKED(b)',
          'ICEBOXED(I)',
          'DUE_EoD(D)',
          'WAIT(w)',
          '|',
          'DONE(d)',
          'PAUSED(p)',
          'FAILED(f)',
          'CANCEL(c)',
        },
        org_todo_keyword_faces = {
          TODO = ':foreground #91330a :weight bold',
          IN_PROGRESS = ':background #947616 :foreground #004635 :weight bold :underline on',
          BLOCKED = ': background #323232 :foreground #960000 :slant italic :underline on',
          ICEBOXED = ':background #006e6e :foreground #f9e2af :weight bold :slant italic',
          DUE_EoD = ':background #b40000 :foreground #f9e2af :weight bold :underline on',
          DONE = ':background #1e4030 :foreground #00a000 :weight bold :slant italic :underline on',
          PAUSED = ':foreground #763e25 :weight bold :slant italic',
          FAILED = ':background #000000 :foreground #646464 :weight bold',
          WAIT = ':foreground #f9e2af :slant italic',
        },
        -- ---------- CAPTURE TEMPLATES -------------------------------
        -- Tags *must* be colon-delimited words :like_this:  (no spaces)
        org_capture_templates = {
          -- General Task inbox (catch-all)
          T = { description = 'TODO List (General)', target = '~/org/todolist.org', template = '* TODO %?  :todolist:\n  %u' },

          -- Personal
          p = {
            description = 'Personal Task',
            target = '~/org/personal/personal.org',
            template = '* TODO %?  :personal:\n  %u\n',
          },

          -- AI-Freelance
          f = {
            description = 'AI-Freelance Task',
            target = '~/org/freelance/freelnce.org',
            template = '* TODO %?  :freelnce:\n  %u\n',
          },

          -- Coding / plugin dev (generic)
          c = { description = 'Coding Task', target = '~/org/code/codenote.org', template = '* TODO %?  :coding:\n  %u\n' },

          -- Neovim-config specific
          n = {
            description = 'Neovim-config Task',
            target = '~/org/nvim/nvim-cfg.org',
            template = '* TODO %?  :nvim-cfg:\n  %u\n',
          },

          -- Log entry
          l = { description = 'Event Log', target = '~/org/eventlog.org', template = '* %?  :eventlog:\n  %U' },

          -- Reminder / Tickler
          r = {
            description = 'Reminder',
            target = '~/org/rminders.org',
            template = '* TODO %? :rminders:\n  SCHEDULED: %^t\n',
          },

          -- Grocery item
          g = { description = 'Grocery Lists', target = '~/org/grcrylst.org', template = '* TODO Buy %?  :grcrylst:\n' },

          -- Journal entry
          j = {
            description = 'Journal Entries',
            target = '~/org/jrnlntry.org',
            template = '* %<%Y-%m-%d %a> %U  :jrnlntry:\n  %?',
          },

          -- Meeting notes
          m = { description = 'Meeting Notes', target = '~/org/meetnote.org', template = '* %?  :meetnote:\n  %U\n  %i' },

          -- Bookmark / reading list
          b = { description = 'Bookmarks', target = '~/org/bookmark.org', template = '* %? :bookmark:\n  %U\n  %a' },

          -- Idea / Brainstorm
          i = { description = 'Ideas - Project', target = '~/org/pjctidea.org', template = '* %?  :pjctidea:\n  %u\n  %i' },

          -- Manual Time-track
          tt = { description = 'Time Tracking', target = '~/org/timetrck.org', template = '* %U %?  :timetrck:' },
        },
        -- One block per *tag* defined above
        org_agenda_custom_commands = {
          O = {
            description = 'Dashboard (all contexts)',
            types = {
              { type = 'tags_todo', match = 'personal', org_agenda_overriding_header = '🏠 PERSONAL' },
              { type = 'tags_todo', match = 'freelnce', org_agenda_overriding_header = '💼 AI-FREELANCE' },
              { type = 'tags_todo', match = 'codenote', org_agenda_overriding_header = '🛠  CODING' },
              { type = 'tags_todo', match = 'nvim-cfg', org_agenda_overriding_header = '⚙️  NVIM-CONFIG' },
              { type = 'tags_todo', match = 'todolist', org_agenda_overriding_header = '📋 GENERAL' },
              { type = 'agenda', span = 'day', org_agenda_overriding_header = '🗓 TODAY' },
            },
          },
        },
        ui = {
          menu = {
            handler = function(data)
              Menu:new({
                window = {
                  border = 'single',
                  margin = { 1, 1, 1, 1 },
                  padding = { 0, 2, 0, 2 },
                },
              }):open(data)
            end,
          },
        },
      }
      require('org-bullets').setup { symbols = { '◉', '○', '✸', '✿' } }
      ----------------------------------------------------------------
      -- 3. Key convenience
      ----------------------------------------------------------------
      vim.keymap.set('n', '<leader>oo', '<Cmd>Org agenda O<CR>', { desc = 'Open Org Dashboard' })

      require('blink.cmp').setup {
        sources = {
          per_filetype = {
            org = { 'orgmode' },
          },
          providers = {
            orgmode = {
              name = 'Orgmode',
              module = 'orgmode.org.autocompletion.blink',
              fallbacks = {
                'buffer',
              },
            },
          },
        },
      }
    end,
  },
}
