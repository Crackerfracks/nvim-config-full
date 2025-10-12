--DO NOT DELETE LINE - THIS FILE LIVES @ filepath="~/.config/nvim/lua/numhi/core.lua"
--[[-------------------------------------------------------------------
Heavy-lifting logic: extmarks, colour maths, history, labels, notes,
metadata persistence
---------------------------------------------------------------------]]
local C        = {}
local palettes = require("numhi.palettes").base
local hsluv    = require("hsluv")
local ui       = require("numhi.ui")
local api      = vim.api
local fn       = vim.fn
local unpack_  = table.unpack or unpack

--------------------------------------------------------------------- }}
--  Internal state ---------------------------------------------------
---------------------------------------------------------------------
local ns_ids        = {}        -- palette → namespace id
local State                         -- back-pointer filled by setup()
local _loaded_bufs   = {}         -- avoid double-loading metadata

---------------------------------------------------------------------
--  Small helpers ----------------------------------------------------
---------------------------------------------------------------------
local function has_visual_marks()
  return fn.line("'<") ~= 0 and fn.line("'>") ~= 0
end

local function slot_to_color(pal, slot)
  local base_hex = palettes[pal][((slot - 1) % 10) + 1]
  if slot <= 10 then return base_hex end
  local k       = math.floor((slot - 1) / 10)
  local h, s, l = unpack_(hsluv.hex_to_hsluv("#" .. base_hex))
  l             = math.max(15, math.min(95, l + (k * 6 - 3)))
  return hsluv.hsluv_to_hex { h, s, l }:sub(2)
end

local function contrast_fg(hex)
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  local yiq = r * 0.299 + g * 0.587 + b * 0.114
  return (yiq > 0.55) and "#000000" or "#ffffff"
end

local function ensure_hl(pal, slot)
  local group = ("NumHi_%s_%d"):format(pal, slot)
  if fn.hlexists(group) == 0 then
    local bg = slot_to_color(pal, slot)
    api.nvim_set_hl(0, group, { bg = "#" .. bg, fg = contrast_fg(bg) })
  end
  return group
end

local function ensure_note_hl()
  if fn.hlexists("NumHiNoteSign") == 0 then
    api.nvim_set_hl(0, "NumHiNoteSign", { fg = "#ffaa00", bg = "NONE" })
  end
  if fn.hlexists("NumHiNoteVirt") == 0 then
    api.nvim_set_hl(0, "NumHiNoteVirt", { fg = "#ffaa00", bg = "NONE" })
  end
end

local function line_len(buf, l)
  local txt = api.nvim_buf_get_lines(buf, l, l + 1, true)[1]
  return txt and #txt or 0
end

local function index_of(t, val)
  for i, v in ipairs(t) do if v == val then return i end end
end

-- echo / notify helper ----------------------------------------------
local function echo(chunks, hl)
  if type(chunks) == "string" then chunks = { { chunks, hl } } end
  local msg = ""
  for _, c in ipairs(chunks) do msg = msg .. c[1] end
  if vim.notify then
    vim.notify(msg, vim.log.levels.INFO, { title = "NumHi" })
  else
    api.nvim_echo(chunks, false, {})
  end
end

---------------------------------------------------------------------
--  Notes metadata helpers ------------------------------------------
---------------------------------------------------------------------
local function note_store(buf)
  State.notes[buf] = State.notes[buf] or {}
  return State.notes[buf]
end

local function get_note(buf, id)  return note_store(buf)[id]      end
local function set_note(buf, id, note, tags)
  note_store(buf)[id] = { note = note, tags = tags or {} }
end

---------------------------------------------------------------------
--  On-disk persistence ----------------------------------------------
---------------------------------------------------------------------
local function meta_path(buf)
  local name = api.nvim_buf_get_name(buf)
  if name == "" then return nil end
  local dir  = fn.stdpath("data") .. "/numhi"
  fn.mkdir(dir, "p")
  name = name:gsub("[\\/]", "%%")  -- sanitise
  return dir .. "/" .. name .. ".json"
end

local function save_metadata(buf)
  local path = meta_path(buf)
  if not path then return end
  local marks = {}
  for pal, ns in pairs(ns_ids) do
    local em = api.nvim_buf_get_extmarks(buf, ns, 0, -1,
      { details = true })
    for _, m in ipairs(em) do
      local id, sr, sc, details = m[1], m[2], m[3], m[4]
      marks[#marks + 1] = {
        pal      = pal,
        slot     = tonumber(details.hl_group:match("_(%d+)$")),
        sr       = sr, sc = sc,
        er       = details.end_row, ec = details.end_col,
        id       = id,
        label    = (State.labels[pal] or {})[tonumber(details.hl_group:match("_(%d+)$"))],
        note     = (note_store(buf)[id] or {}).note,
        tags     = (note_store(buf)[id] or {}).tags,
      }
    end
  end
  fn.writefile({ fn.json_encode(marks) }, path)
end

local function clamp_col(buf, row, col)
  return math.min(col, line_len(buf, row))
end

local function load_metadata(buf)
  if _loaded_bufs[buf] then return end
  _loaded_bufs[buf] = true
  local path = meta_path(buf)
  if not path or fn.filereadable(path) == 0 then return end
  local ok, data = pcall(fn.readfile, path)
  if not ok or not data or #data == 0 then return end
  local ok2, marks = pcall(fn.json_decode, table.concat(data, "\n"))
  if not ok2 or type(marks) ~= "table" then return end
  for _, m in ipairs(marks) do
    local ns = ns_ids[m.pal]
    local hl = ensure_hl(m.pal, m.slot)

    local sr, sc = m.sr, clamp_col(buf, m.sr, m.sc)
    local er, ec = m.er, clamp_col(buf, m.er, m.ec)
    if sc == ec then ec = ec + 1 end  -- never zero-width

    local vt = nil
    if State.show_tags and m.tags and #m.tags > 0 then
      vt = { { "#" .. table.concat(m.tags, " #"), hl } }
    end
    local id = api.nvim_buf_set_extmark(buf, ns, sr, sc, {
      end_row = er, end_col = ec, hl_group = hl,
      sign_text = "✎", sign_hl_group = hl,
      virt_text = vt,
      virt_text_pos = "eol",
    })
    if m.note then set_note(buf, id, m.note, m.tags or {}) end
    State.labels[m.pal] = State.labels[m.pal] or {}
    if m.label then State.labels[m.pal][m.slot] = m.label end
  end
end

---------------------------------------------------------------------
--  Tag-display helpers ---------------------------------------------
---------------------------------------------------------------------
local function tags_as_string(tags)
  if not tags or #tags == 0 then return "" end
  return "#" .. table.concat(tags, " #")
end

local function apply_tag_virt(buf, ns, id, show)
  local note = get_note(buf, id)
  if not note then return end
  local vt = show and tags_as_string(note.tags) or nil

  local pos = api.nvim_buf_get_extmark_by_id(buf, ns, id, { details = true })
  if not pos or not pos[1] then return end

  local slot = tonumber(pos[3].hl_group:match("_(%d+)$"))
  local pal  = pos[3].hl_group:match("NumHi_(.-)_") or State.active_palette
  local hl   = ensure_hl(pal, slot)

  api.nvim_buf_set_extmark(
    buf, ns, pos[1], pos[2],
    {
      id       = id,
      end_row  = pos[3].end_row,
      end_col  = pos[3].end_col,
      hl_group = pos[3].hl_group,
      sign_text      = "✎",
      sign_hl_group  = hl,
      virt_text      = vt and { { vt, hl } } or nil,
      virt_text_pos  = "eol",
    }
  )
end

local function refresh_all_tag_vt(buf)
  local show = State.show_tags
  for pal, ns in pairs(ns_ids) do
    for id, _ in pairs(note_store(buf)) do
      apply_tag_virt(buf, ns, id, show)
    end
  end
end

---------------------------------------------------------------------
--  Setup ------------------------------------------------------------
---------------------------------------------------------------------
function C.setup(top)
  State = top.state
  State.notes = State.notes or {}
  State.show_tags = State.show_tags or false

  for _, pal in ipairs(State.opts.palettes) do
    ns_ids[pal] = api.nvim_create_namespace("numhi_" .. pal)
  end
  ensure_note_hl()

  api.nvim_create_autocmd("BufReadPost", {
    callback = function(ev) vim.schedule(function() load_metadata(ev.buf) end) end,
  })
end

---------------------------------------------------------------------
--  Word-range fallback ---------------------------------------------
---------------------------------------------------------------------
local function word_range()
  local lnum, col = unpack(api.nvim_win_get_cursor(0))
  local line      = api.nvim_get_current_line()
  if col >= #line or not line:sub(col + 1, col + 1):match("[%w_]") then
    return col, col + 1
  end
  local s, e = col, col
  while s > 0         and line:sub(s,     s    ):match("[%w_]") do s = s - 1 end
  while e < #line - 1 and line:sub(e + 2, e + 2):match("[%w_]") do e = e + 1 end
  return s, e + 1
end

---------------------------------------------------------------------
--  Labels -----------------------------------------------------------
---------------------------------------------------------------------
local function get_label(pal, slot)
  State.labels[pal] = State.labels[pal] or {}
  local label       = State.labels[pal][slot]
  if not label then
    vim.ui.input(
      { prompt = ("NumHi %s-%d label (empty = none): "):format(pal, slot) },
      function(input)
        if input and input ~= "" then State.labels[pal][slot] = input end
      end
    )
  end
  return State.labels[pal][slot]
end

---------------------------------------------------------------------
--  Highlight action -------------------------------------------------
---------------------------------------------------------------------
-- mark table layout:
--   { buf, id, slot, sr, sc, er, ec, note, tags }
local function store_mark(buf, id, slot, sr, sc, er, ec, note, tags)
  return { buf, id, slot, sr, sc, er, ec, note, tags }
end

function C.highlight(slot)
  slot = tonumber(slot)
  if not slot or slot < 1 or slot > 99 then return end

  local pal   = State.active_palette
  local ns    = ns_ids[pal]
  local group = ensure_hl(pal, slot)
  local marks = {}

  local v_ok  = has_visual_marks()
  local mode  = fn.mode()

  local start_row, start_col, end_row, end_col

  if v_ok or mode:match("^[vV]") then
    local p1 = { unpack(fn.getpos("'<"), 2, 3) }
    local p2 = { unpack(fn.getpos("'>"), 2, 3) }
    p1[1], p1[2] = p1[1] - 1, p1[2] - 1
    p2[1], p2[2] = p2[1] - 1, p2[2] - 1
    if (p2[1] < p1[1]) or (p2[1] == p1[1] and p2[2] < p1[2]) then p1, p2 = p2, p1 end
    start_row, start_col, end_row, end_col = p1[1], p1[2], p2[1], p2[2] + 1
    api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  else
    local lnum, _ = unpack(api.nvim_win_get_cursor(0))
    start_row, end_row = lnum - 1, lnum - 1
    start_col, end_col = word_range()
  end

  local id = api.nvim_buf_set_extmark(
    0, ns, start_row, start_col,
    {
      end_row  = end_row,
      end_col  = end_col,
      hl_group = group,
    }
  )
  table.insert(marks, store_mark(0, id, slot, start_row, start_col, end_row, end_col))

  get_label(pal, slot)

  table.insert(State.history, { pal = pal, slot = slot, marks = marks })
  State.redo_stack = {}
  if #State.history > State.opts.history_max then table.remove(State.history, 1) end

  save_metadata(0)
end

---------------------------------------------------------------------
--  Digit-collector --------------------------------------------------
---------------------------------------------------------------------
function C.collect_digits()
  local digits = ""
  local function prompt()
    local pal = State.active_palette
    local txt = (#digits > 0) and digits or "_"
    local hl  = (#digits > 0) and ensure_hl(pal, tonumber(digits)) or "Comment"
    echo(string.format("NumHi %s ◈ slot: %s (1-99)  <CR>:confirm  <BS>:clear  <Esc>:cancel", pal, txt), hl)
  end
  prompt()
  while true do
    local ok, ch = pcall(fn.getchar)
    if not ok then return end
    if type(ch) == "number" then ch = fn.nr2char(ch) end
    if ch:match("%d") and #digits < 2 then
      digits = digits .. ch
      prompt()
    elseif ch == "\b" or ch == "\127" then
      digits = ""
      prompt()
    elseif ch == "\27" then -- ESC
      echo("")
      return
    elseif ch == "\r" then
      local num = digits
      api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
      vim.schedule(function() C.highlight(num) end)
      echo("")
      return
    else
      echo("")  -- cancel
      return
    end
  end
end

---------------------------------------------------------------------
--  Erase under cursor ----------------------------------------------
---------------------------------------------------------------------
function C.erase_under_cursor()
  local pal  = State.active_palette
  local ns   = ns_ids[pal]
  local l, c = unpack(api.nvim_win_get_cursor(0))
  local ids  = api.nvim_buf_get_extmarks(
    0, ns, { l - 1, c }, { l - 1, c + 1 }, { overlap = true, details = true })
  if #ids == 0 then return end

  local marks = {}
  for _, m in ipairs(ids) do
    local id, sr, sc, det = m[1], m[2], m[3], m[4]
    local note_tbl = note_store(0)[id]
    table.insert(marks, store_mark(0, id,
      tonumber(det.hl_group:match("_(%d+)$")),
      sr, sc, det.end_row, det.end_col,
      note_tbl and note_tbl.note, note_tbl and note_tbl.tags))

    api.nvim_buf_del_extmark(0, ns, id)
    -- keep note in memory for undo/redo
  end
  table.insert(State.history, { pal = pal, slot = nil, marks = marks })
  State.redo_stack = {}
  save_metadata(0)
end

---------------------------------------------------------------------
--  Undo / redo ------------------------------------------------------
---------------------------------------------------------------------
local function recreate_mark(mark, pal)
  local buf, _, slot, sr, sc, er, ec, note, tags = unpack(mark)
  local ns   = ns_ids[pal]
  local hl   = ensure_hl(pal, slot)
  local vt = nil
  if tags and #tags > 0 and State.show_tags then
    vt = { { tags_as_string(tags), hl } }
  end
  local id   = api.nvim_buf_set_extmark(buf, ns, sr, sc, {
    end_row = er, end_col = ec, hl_group = hl,
    sign_text = (note and "✎" or nil), sign_hl_group = hl,
    virt_text = vt,
    virt_text_pos = "eol",
  })
  if note then set_note(buf, id, note, tags) end
  mark[2] = id  -- update stored id for possible further undo/redo
end

function C.undo()
  local entry = table.remove(State.history)
  if not entry then return end
  for _, m in ipairs(entry.marks) do
    local buf, id = m[1], m[2]
    local pal = entry.pal or State.active_palette
    local ns  = ns_ids[pal]
    -- cache note before deleting
    local note_tbl = note_store(buf)[id]
    if note_tbl then
      m[8], m[9] = note_tbl.note, note_tbl.tags
    end
    api.nvim_buf_del_extmark(buf, ns, id)
  end
  table.insert(State.redo_stack, entry)
  save_metadata(0)
end

function C.redo()
  local entry = table.remove(State.redo_stack)
  if not entry then return end
  for _, m in ipairs(entry.marks) do recreate_mark(m, entry.pal) end
  table.insert(State.history, entry)
  save_metadata(0)
end

---------------------------------------------------------------------
--  Palette cycle ----------------------------------------------------
---------------------------------------------------------------------
function C.cycle_palette(step)
  local list = State.opts.palettes
  local idx  = index_of(list, State.active_palette) or 1
  State.active_palette = list[((idx - 1 + step) % #list) + 1]

  local chunks = { { "NumHi → palette " .. State.active_palette .. "  ", "ModeMsg" } }
  for n = 1, 10 do
    local hl = ensure_hl(State.active_palette, n)
    table.insert(chunks, { tostring((n % 10 == 0) and 0 or n), hl })
    if n < 10 then table.insert(chunks, { " ", "" }) end
  end
  echo(chunks)
end

---------------------------------------------------------------------
--  Hover label ------------------------------------------------------
---------------------------------------------------------------------
function C.show_label_under_cursor()
  local l, c = unpack(api.nvim_win_get_cursor(0))
  for _, pal in ipairs(State.opts.palettes) do
    local marks = api.nvim_buf_get_extmarks(
      0, ns_ids[pal], { l - 1, c }, { l - 1, c + 1 },
      { details = true, overlap = true })
    if #marks > 0 then
      local id     = marks[1][1]
      local slot   = tonumber(marks[1][4].hl_group:match("_(%d+)$"))
      local label  = State.labels[pal] and State.labels[pal][slot] or ""
      local note   = get_note(0, id)
      ensure_hl(pal, slot)
      ui.tooltip(pal, slot, label, note and note.note or nil, note and note.tags or nil)
      return
    end
  end
end

---------------------------------------------------------------------
--  Toggle tag display ----------------------------------------------
---------------------------------------------------------------------
function C.toggle_tag_display()
  State.show_tags = not State.show_tags
  refresh_all_tag_vt(0)
end

---------------------------------------------------------------------
--  Note editor ------------------------------------------------------
---------------------------------------------------------------------
function C.edit_note()
  local l, c = unpack(api.nvim_win_get_cursor(0))

  for _, pal in ipairs(State.opts.palettes) do
    local ns     = ns_ids[pal]
    local marks  = api.nvim_buf_get_extmarks(
      0, ns, { l - 1, c }, { l - 1, c }, { details = true, overlap = true })
    if #marks > 0 then
      local m        = marks[1]
      local id       = m[1]
      local slot     = tonumber(m[4].hl_group:match("_(%d+)$"))
      local note_tbl = get_note(0, id) or { note = "", tags = {} }
      local src_buf  = api.nvim_get_current_buf()

      local bufname = ("NumHiNote:%d"):format(id)
      local buf     = fn.bufnr(bufname)
      if buf == -1 then
        buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_name(buf, bufname)
        api.nvim_buf_set_option(buf, 'buftype', 'acwrite')
        api.nvim_buf_set_option(buf, 'filetype', 'markdown')
        api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
        if note_tbl.note ~= "" then
          api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(note_tbl.note, "\n"))
        end
      end

      local width  = math.floor(vim.o.columns * 0.5)
      local height = math.max(3, math.floor(vim.o.lines * 0.3))
      local anchor = (l + height + 2 > vim.o.lines) and 'SW' or 'NW'
      local win = api.nvim_open_win(buf, true, {
        relative = 'cursor',
        row = (anchor == 'NW') and 1 or 0,
        col = 0,
        width  = width,
        height = height,
        style  = 'minimal',
        border = 'rounded',
        anchor = anchor,
      })

      local function save()
        local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
        local content = table.concat(lines, "\n")
        local tags = {}
        for _, line in ipairs(lines) do
          for tag in line:gmatch('#(%w+)') do tags[#tags + 1] = tag end
        end
        set_note(src_buf, id, content, tags)
        apply_tag_virt(src_buf, ns, id, State.show_tags)
        api.nvim_buf_set_option(buf, "modified", false)
        save_metadata(src_buf)
      end

      api.nvim_create_autocmd({ 'BufWriteCmd' }, {
        buffer = buf,
        nested = true,
        callback = function() save() end,
      })
      api.nvim_create_autocmd({ 'BufLeave', 'WinClosed' }, {
        buffer = buf,
        nested = true,
        callback = function(ev)
          save()
          if ev.event ~= "BufLeave" and api.nvim_win_is_valid(win) then
            api.nvim_win_close(win, true)
          end
        end,
      })

      -- 'q' to write & quit
      api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>write | close<CR>", { silent = true })

      return
    end
  end
  echo("No NumHi highlight under cursor")
end

---------------------------------------------------------------------
--  Expose utils -----------------------------------------------------
---------------------------------------------------------------------
C.ensure_hl = ensure_hl
function C.ns_for(pal) return ns_ids[pal] end

return C

