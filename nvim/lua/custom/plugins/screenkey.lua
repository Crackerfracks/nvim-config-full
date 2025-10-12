--------------------------------------------------------------------------------
-- Screenkey.nvim – custom settings -------------------------------------------
--------------------------------------------------------------------------------
-- NOTE: paste the whole block; no further edits required
return {
  'NStefan002/screenkey.nvim',
  lazy = false,
  version = '*',
  config = function()
    ---------------------------------------------------------------------------
    -- 1.  Window in TOP‑RIGHT corner (anchor = "NE") -------------------------
    ---------------------------------------------------------------------------
    local W = require 'screenkey'
    W.setup {
      win_opts = {
        -- . Put the *north‑east* corner of the float at the very top‑right cell.
        row = 0, -- 0 == first editor row :contentReference[oaicite:0]{index=0}
        col = vim.o.columns - 1, -- right‑most screen column
        relative = 'editor',
        anchor = 'NE', -- <‑‑ key bit ☝︎ :contentReference[oaicite:1]{index=1}
        width = 100,
        height = 1,
        border = 'single',
        title = 'Keyboard Input',
        title_pos = 'center',
        style = 'minimal',
        focusable = false,
        noautocmd = false,
        zindex = 60, -- keep it above most pop‑ups
      },

      ------------------------------------------------------------------------
      -- 2.  Make every keypress trigger a redraw ----------------------------
      ------------------------------------------------------------------------
      -- Screenkey already intercepts <Esc>, <CR> … but some plugins feed
      -- input through low‑level APIs that never reach it.  By piggy‑backing
      -- on Neovim ≥ 0.10’s `vim.on_key()` we can refresh on *all* input
      -- (the callback fires *before* mappings are applied) :contentReference[oaicite:2]{index=2}
      ------------------------------------------------------------------------
      -- redrawing      = true,   -- (fictional option to remind ourselves)
      compress_after = 6, -- disable time‑based compression entirely
      clear_after = 10, -- keep the previous behaviour
      group_mappings = true, -- treat “gg”, “cc”, etc. as a single combo :contentReference[oaicite:3]{index=3}
      disable = {
        filetypes = {},
        buftypes = {},
        events = false,
      },
    }

    -- Force‑redraw hook
    -- local ns = vim.api.nvim_create_namespace("screenkey_force_redraw")
    -- vim.on_key(function()
    --   if W.is_active() then
    --     vim.schedule(W.redraw)                -- run outside low‑level input
    --   end
    -- end, ns)

    --------------------------------------------------------------------------
    -- 3.  Keybinding: <leader><leader><leader> toggles Screenkey ------------
    --------------------------------------------------------------------------
    vim.keymap.set(
      'n',
      '<leader><leader><leader>K',
      W.toggle,
      {
        desc = 'Toggle Screenkey',
      } -- helpful for which‑key lists
    )
  end,
}
