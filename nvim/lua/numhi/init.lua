--DO NOT DELETE LINE - THIS FILE LIVES @ filepath="~/.config/nvim/lua/numhi/init.lua"
--[[-------------------------------------------------------------------
Numeric-Palette Highlighter — public façade
---------------------------------------------------------------------]]
local M = {}
local core
-----------------------------------------------------------------------
--  Defaults & state --------------------------------------------------
-----------------------------------------------------------------------
local default_opts = {
  palettes     = {
    "VID",
    "PAS",
    "EAR",
    "MET",
    "CYB"
  },
  key_leader   = "<leader><leader>",  -- root; NumHi adds an extra 'n'
  statusline   = true,
  history_max  = 500,
  hover_delay  = 400,
}

M.state = {
  active_palette = "VID",
  history        = {},
  redo_stack     = {},
  labels         = {},
  notes          = {},
  show_tags      = false,
  show_note_lines = false,
  note_mode      = "hover",
  opts           = {},
}

-----------------------------------------------------------------------
--  Setup -------------------------------------------------------------
-----------------------------------------------------------------------
function M.setup(opts)
  opts = vim.tbl_deep_extend(
    "force",
    default_opts,
    opts
    or
    {}
  )
  
  M.state.opts = opts
  core = require("numhi.core")
  core.setup(M)

  if
    opts.statusline
  then M.attach_statusline()
  end

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
  "toggle_tag_display",
  "collect_digits",
  "edit_note",
  "show_label_under_cursor",
  "toggle_note_lines",
  "search_by_tag",
  "cycle_note_mode"
}
  do
  M[f] = function(...)
    return core[f](...)
  end
end

-----------------------------------------------------------------------
--  Keymaps -----------------------------------------------------------
-----------------------------------------------------------------------
function M.create_keymaps()
  local leader_root = M.state.opts.key_leader .. "n"  -- << all NumHi under <leader><leader>n
  local map = function(
    lhs,
    rhs,
    desc,
    mode
  )
    vim.keymap.set(
      mode
      or
      {
        "n",
        "v"
      },
      lhs,
      rhs,
      {
        silent = true,
        desc = desc
      }
    )
  end

  -- Highlight / erase
  map(
    leader_root .. "<CR>",
    function()
      core.collect_digits()
    end,
    "NumHi: highlight with slot"
  )
  map(
    leader_root .. "0<CR>",
    M.erase_under_cursor,
    "NumHi: erase mark under cursor"
  )

  -- Undo / redo
  map(
    leader_root .. "u",
    M.undo,
    "NumHi: undo"
  )
  map(
    leader_root .. "<C-r>",
    M.redo,
    "NumHi: redo"
  )

  -- Notes & tags
  map(
    leader_root .. "nn",
    function()
      core.edit_note()
    end,
    "NumHi: create / edit note")
  map(
    leader_root .. "nt",
    function()
      core.toggle_tag_display()
    end,
    "NumHi: toggle tag display"
  )
  map(
    leader_root .. "nl",
    function()
      core.toggle_note_lines()
    end,
    "NumHi: toggle inline notes"
  )
  map(
    leader_root .. "ns",
    function()
      core.search_by_tag()
    end,
    "NumHi: search by tag"
  )
  map(
    leader_root .. "nm",
    function()
      core.cycle_note_mode()
    end,
    "NumHi: cycle note mode"
  )

  -- Palette cycle
  vim.keymap.set(
    "n",
    leader_root .. "p",
    function()
      M.cycle_palette(1) 
    end,
    {
      silent = true,
      desc = "NumHi: next palette"
    }
  )
end

-----------------------------------------------------------------------
--  Status-line component --------------------------------------------
-----------------------------------------------------------------------
function M.status_component()
  local pal = M.state.active_palette
  
  local base_hl = core.ensure_hl(
    pal,
    1
  )
  
  local swatch = string.format(
    "%%#%s#▉%%*",
    base_hl
  )
  
  local parts = {}
  for n = 1, 10 do
    local hl = core.ensure_hl(
      pal,
      n
    )
    parts[#parts + 1] = string.format(
      "%%#%s#%s%%*",
      hl,
      (n % 10 == 0) and "0"
      or
      tostring(n))
  end

  return string.format(
    "[%s %s %s]%%*",
    swatch,
    pal,
    table.concat(
      parts,
      ""
    )
  )
end

-----------------------------------------------------------------------
--  Attach statusline -------------------------------------------------
-----------------------------------------------------------------------
local function attach_to_mini()
  local ok, mini = pcall(
    require,
    "mini.statusline"
  )
  if not ok 
    or mini.__numhi_patched 
  then
    return ok
  end
  mini.__numhi_patched = true
  local orig = mini.section_location
  mini.section_location = function()
    return 
      M.status_component() .. (
      orig and orig()
      or ""
    )
  end
  return 
    true
end

function M.attach_statusline()
  if attach_to_mini()
  then
    return
  end

  local function attach_lualine()
    local ok, lualine = pcall(
      require,
      "lualine"
    )
    if
      not ok
      or lualine.__numhi_patched
    then 
      return
        ok
    end
    lualine.__numhi_patched = true
    local comp = function()
      return M.status_component()
    end
    vim.schedule(function()
      local cfg = lualine.get_config and lualine.get_config() or {}
      cfg.sections = cfg.sections or {}
      cfg.sections.lualine_c = cfg.sections.lualine_c or {}
      table.insert(
        cfg.sections.lualine_c,
        1,
        comp
      )
      lualine.setup(cfg)
    end)
    return true
  end

  if attach_lualine() then return end
  vim.o.statusline = "%{%v:lua.require'numhi'.status_component()%}" .. vim.o.statusline
end

-----------------------------------------------------------------------
--  Hover autocmd -----------------------------------------------------
-----------------------------------------------------------------------
function M.create_hover_autocmd()
  vim.api.nvim_create_autocmd("CursorHold", {
    desc     = "NumHi: show label under cursor",
    callback = core.show_label_under_cursor,
  })
  vim.opt.updatetime = math.min(
    vim.opt.updatetime:get(),
    M.state.opts.hover_delay
  )
end

return M

