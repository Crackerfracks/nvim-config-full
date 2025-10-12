--DO NOT DELETE LINE - THIS FILE LIVES @ filepath="~/.config/nvim/lua/numhi/init.lua"
--[[-------------------------------------------------------------------
Numeric-Palette Highlighter — public façade
---------------------------------------------------------------------]]
local M = {}

-- ---------- defaults -----------------------------------------------
local default_opts = {
  palettes     = { "VID", "PAS", "EAR", "MET", "CYB" },
  key_leader   = "<leader><leader>",
  statusline   = true,
  history_max  = 500,
  hover_delay  = 400,            -- ms before label popup
}

M.state = {
  active_palette = "VID",
  history        = {},
  redo_stack     = {},
  labels         = {},           -- pal → slot → string
  opts           = {},
}

local core

-- ---------- setup ---------------------------------------------------
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})
  M.state.opts = opts
  core = require("numhi.core")
  core.setup(M)

  if opts.statusline then M.attach_statusline() end
  M.create_keymaps()
  M.create_hover_autocmd()
end
-----------------------------------------------------------------------
--  Thin wrappers -----------------------------------------------------
-----------------------------------------------------------------------
for _, f in ipairs {
  "highlight",
  "erase_under_cursor",
  "undo",
  "redo",
  "cycle_palette",
} do
  M[f] = function(...) return core[f](...) end
end
-----------------------------------------------------------------------
--  keymaps -----------------------------------------------------------
-----------------------------------------------------------------------
function M.create_keymaps()
  local leader = M.state.opts.key_leader       -- defaults to "<leader><leader>"
  local function map(lhs, rhs, desc, mode)
    vim.keymap.set(mode or { "n", "v" }, lhs, rhs,
      { silent = true, desc = desc })
  end

  -- 1. bring up digit-collector on  <leader><leader><CR>
  map(leader .. "<CR>", function() require("numhi.core").collect_digits() end,
      "NumHi: highlight with slot")

  -- 2. erase mark under cursor
  map(leader .. "0<CR>", M.erase_under_cursor, "NumHi: erase mark under cursor")

  -- 3. undo / redo
  map(leader .. "u", M.undo,               "NumHi: undo")
  map(leader .. "<C-r>", M.redo,           "NumHi: redo")

  -- (New) Edit note for highlight under cursor
  map(leader .. "n", function() require("numhi.core").edit_note() end,
      "NumHi: edit note for highlight")

  -- 4. palette cycle  (keep on p – only in Normal mode)
  vim.keymap.set("n", leader .. "p",
    function() M.cycle_palette(1) end,
    { silent = true, desc = "NumHi: next palette" })
end

-----------------------------------------------------------------------
--  Status-line component --------------------------------------------
-----------------------------------------------------------------------
function M.status_component()
  local pal = M.state.active_palette
  -- Create a colored block for palette: use slot 1's color as swatch
  local base_hl = core.ensure_hl(pal, 1)
  local swatch = string.format("%%#%s#▉%%*", base_hl)
  -- Build digit indicators as before
  local parts = {}
  for n = 1, 10 do
    local hl = core.ensure_hl(pal, n)
    table.insert(parts, string.format("%%#%s#%s%%*", hl, (n % 10 == 0) and "0" or tostring(n)))
  end
  -- Return something like "[█ PAL 1234567890]"
  return string.format("[%s %s %s] ", swatch, pal, table.concat(parts, ""))
end

-----------------------------------------------------------------------
--  Attach to user’s status-line impls (Mini / lualine / vanilla) -----
-----------------------------------------------------------------------
function M.attach_statusline()
  vim.schedule(function()   -- <-- wrap everything that follows
    -- 1. Mini.statusline
    local ok_mini, mini = pcall(require, "mini.statusline")
    if ok_mini then
      local orig = mini.section_window
      mini.section_window = function() return M.status_component() .. (orig and orig() or "") end
      return
    end

    -- 2. lualine (Kickstart default)
    local ok_lualine, lualine = pcall(require, "lualine")
    if ok_lualine then
      local comp = function() return M.status_component() end
      -- schedule so we run *after* user’s lualine.setup
      vim.schedule(function()
        local cfg = lualine.get_config and lualine.get_config() or {}
        cfg.sections             = cfg.sections             or {}
        cfg.sections.lualine_c   = cfg.sections.lualine_c   or {}
        table.insert(cfg.sections.lualine_c, 1, comp)
        lualine.setup(cfg)
      end)
      return
    end

    -- 3. plain string statusline
    vim.o.statusline = "%{%v:lua.require'numhi'.status_component()%}" .. vim.o.statusline
  end)
end

-- vim.api.nvim_create_autocmd("CursorHold", {
--   callback = function()
--     local pal  = require("numhi").state.active_palette
--     local ns   = require("numhi.core").ns_for(pal)     -- helper you expose
--     local l,c  = unpack(vim.api.nvim_win_get_cursor(0))
--     local m    = vim.api.nvim_buf_get_extmarks(0, ns,
--                  {l-1,c}, {l-1,c+1}, { details = true })[1]
--     if not m   then return end
--     local ud   = m[4].user_data
--     require("numhi.ui").tooltip(pal, ud.slot, ud.label, ud.note)
--   end,
-- })

vim.keymap.set("n", "<leader><CR>",
  function()
    local pal = require("numhi").state.active_palette
    local ns  = require("numhi.core").ns_for(pal)
    local l,c = unpack(vim.api.nvim_win_get_cursor(0))
    local id  = vim.api.nvim_buf_get_extmarks(0, ns,
               {l-1,c}, {l-1,c+1}, {})[1]
    if not id then return end
    vim.ui.input({ prompt = "NumHi note: " }, function(txt)
      if not txt then return end
      vim.api.nvim_buf_set_extmark(0, ns, l-1, c,
        { id = id, user_data = { note = txt }, })
    end)
  end,
  { desc = "NumHi: attach note to highlight" })
-----------------------------------------------------------------------
--  Hover label autocmd ----------------------------------------------
-----------------------------------------------------------------------
function M.create_hover_autocmd()
  vim.api.nvim_create_autocmd("CursorHold", {
    desc     = "NumHi: show label under cursor",
    callback = core.show_label_under_cursor,
  })
  vim.opt.updatetime = math.min(vim.opt.updatetime:get(), M.state.opts.hover_delay)
end

return M

