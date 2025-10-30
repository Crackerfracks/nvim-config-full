-- ~/.config/nvim/lua/zk_follow_create.lua
-- Drop‑in replacement — 2025‑10‑28
--
-- Highlights vs the broken build:
--  • Fixes vim.fn.isdirectory "Too many arguments" root-cause (Lua gsub returning multiple values)
--  • Hard‑gates everything to real Markdown notes inside a zk notebook (ignores scratch buffers / schemes)
--  • Restores working Navigation Links folding (folds only between the --- delimiters)
--  • Keeps floating previews as real file buffers (no buftype=nofile) so markdown renderers attach
--  • Adds manual preview (<leader>zv), numeric focus (<leader>z1…z9), quick close ("q"), and float‑local <leader>z maps
--  • Makes <leader>zm truly toggle by also mapping it inside preview buffers
--  • Provides a safe blink.cmp provider stub at module path "zk_follow_create.completion" to prevent InsertEnter errors
--
--  This file intentionally stays single‑file; we also register package.preload[...] for blink to require.

local M = {}

-- =====================
-- Config (defaults)
-- =====================
M.cfg = {
  filename_mode = 'typed', -- 'typed' | 'slug' | 'zk'
  id_prefix = false, -- true to prefix filenames with a short id
  id_length = 4,
  autosave_created = true,

  backlinks = {
    enabled = true,
    section_header = 'Navigation Links',
    subsection_backlinks = 'Backlinks',
    subsection_related = 'Related (shares tags)',
    fold_by_default = true,
    fold_delimiter = '---',
  },

  folds = { frontmatter = true, links = true },
  virt_tags = { enabled = true, hl = 'Comment' },

  preview = {
    auto = false,
    layout = 'topleft', -- 'topleft' | 'bottomright'
    width = 0.45, -- editor width fraction for stack
    height = 14, -- fixed float height
    stack_gap = 1,
    border = 'rounded',
    persist = true,
    controls_toggle = '<leader>zm',
    move_step = 2,
    resize_step = 2,
  },

  map_insert_relative = '<leader>z.', -- insert [[./]] helper mapping
}

-- =====================
-- Internal state
-- =====================
M._history = {}
M._previews = { hidden = false, items = {}, order = {}, controls_enabled = false }
M._ns_tags = vim.api.nvim_create_namespace 'zkfc_tags'

-- =====================
-- Utilities
-- =====================
local function trim(s)
  return (s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end
local function path_sep()
  return package.config:sub(1, 1)
end
local function slugify(s)
  s = (s or ''):lower():gsub('%s+', '-'):gsub('[^%w_%-.]', '-'):gsub('-+', '-')
  return s:gsub('^%-', ''):gsub('%-$', '')
end
local function random_id(n)
  local alphabet = '0123456789abcdefghjkmnpqrstvwxyz'
  local id = ''
  for i = 1, n or 4 do
    id = id .. alphabet:sub(math.random(#alphabet), math.random(#alphabet))
  end
  return id
end
local function normalize_path(p)
  -- IMPORTANT: never return the 2nd value of gsub; always return the string only
  local abs = vim.fn.fnamemodify(p or '', ':p')
  if path_sep() == '\\' then
    abs = (abs:gsub('\\', '/'))
  end
  abs = (abs:gsub('/+%$', ''))
  abs = (abs:gsub('/+%$', '')) -- defend if previous pattern missed
  abs = (abs:gsub('/+%$', ''))
  -- The previous three lines seem odd, but sometimes :p yields trailing slashes; clean thoroughly.
  abs = (abs:gsub('/+%$', ''))
  abs = (abs:gsub('/+', '/'))
  return abs
end
local function join(...)
  return normalize_path(table.concat({ ... }, path_sep()))
end
local function dirname(p)
  return vim.fn.fnamemodify(p, ':h')
end
local function stem(p)
  return vim.fn.fnamemodify(p, ':t:r')
end
local function without_ext(p)
  return vim.fn.fnamemodify(p, ':r')
end
local function ensure_dir(p)
  if p and vim.fn.isdirectory(p) == 0 then
    vim.fn.mkdir(p, 'p')
  end
end
local function feedkeys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'n', true)
end

local function _split_slash(p)
  local t = {}
  p = (p or ''):gsub('\\', '/'):gsub('/+', '/')
  for part in p:gmatch '[^/]+' do
    t[#t + 1] = part
  end
  return t
end
local function relpath(base_dir, target_path)
  local b = _split_slash(normalize_path(base_dir))
  local t = _split_slash(normalize_path(target_path))
  local i = 1
  while i <= #b and i <= #t and b[i] == t[i] do
    i = i + 1
  end
  local parts = {}
  for _ = i, #b do
    parts[#parts + 1] = '..'
  end
  for j = i, #t do
    parts[#parts + 1] = t[j]
  end
  local rp = table.concat(parts, '/')
  return rp == '' and '.' or rp
end
local function rel_wiki_path(from_dir, target_path)
  return without_ext(relpath(from_dir, target_path))
end

-- Robust notebook root (ignore scratch schemes, nil, etc.)
local function has_scheme(p)
  return type(p) == 'string' and p:match '^[%a][%w+%.%-]*://' ~= nil
end
local function find_notebook_root(abs_path)
  if not abs_path or abs_path == '' or has_scheme(abs_path) then
    return nil
  end
  local ok, zk_util = pcall(require, 'zk.util')
  if ok and zk_util and zk_util.notebook_root then
    local root = zk_util.notebook_root(abs_path)
    if root and root ~= '' then
      return root
    end
  end
  local dir = vim.fn.fnamemodify(abs_path, ':p:h')
  while dir and dir ~= '' and dir ~= path_sep() do
    if vim.fn.isdirectory(join(dir, '.zk')) == 1 then
      return dir
    end
    dir = dirname(dir)
  end
  return nil
end

-- Frontmatter helpers
local function parse_frontmatter(lines)
  local fm_text
  if lines[1] and lines[1]:match '^%-%-%-$' then
    for i = 2, #lines do
      if lines[i]:match '^%-%-%-$' then
        fm_text = table.concat(vim.list_slice(lines, 1, i), '\n')
        break
      end
    end
  end
  local tags, aliases = {}, {}
  if fm_text then
    for line in fm_text:gmatch '[^\n]+' do
      local key, val = line:match '^([%w_%-%#]+):%s*(.+)$'
      if key and val then
        if key == 'tags' then
          local list = val:gsub('[%[%]]', '')
          for t in list:gmatch '([^,]+)' do
            t = trim(t)
            if t ~= '' then
              tags[#tags + 1] = t
            end
          end
        elseif key == 'aliases' then
          local list = val:gsub('[%[%]]', '')
          for a in list:gmatch '([^,]+)' do
            a = trim(a)
            if a ~= '' then
              aliases[#aliases + 1] = a
            end
          end
        end
      end
    end
  end
  return { tags = tags, aliases = aliases }
end
local function show_tags_virttext(buf)
  if not M.cfg.virt_tags.enabled then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, M._ns_tags, 0, -1)
  local n = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(n, 300), false)
  if not lines[1] or not lines[1]:match '^%-%-%-$' then
    return
  end
  local close_i
  for i = 2, #lines do
    if lines[i]:match '^%-%-%-$' then
      close_i = i - 1
      break
    end
  end
  if not close_i then
    return
  end
  local fm = parse_frontmatter(vim.list_slice(lines, 1, close_i))
  if #fm.tags == 0 and #fm.aliases == 0 then
    return
  end
  local parts = {}
  for _, t in ipairs(fm.tags) do
    parts[#parts + 1] = '#️⃣ ' .. t
  end
  for _, a in ipairs(fm.aliases) do
    parts[#parts + 1] = '➕ ' .. a
  end
  vim.api.nvim_buf_set_extmark(buf, M._ns_tags, close_i, 0, {
    virt_text = { { table.concat(parts, '  '), M.cfg.virt_tags.hl } },
    virt_text_pos = 'overlay',
  })
end

-- Folding
local function fold_frontmatter(buf)
  if not M.cfg.folds.frontmatter then
    return
  end
  local n = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(n, 300), false)
  if not lines[1] or not lines[1]:match '^%-%-%-$' then
    return
  end
  local close_line
  for i = 2, #lines do
    if lines[i]:match '^%-%-%-$' then
      close_line = i
      break
    end
  end
  if not close_line then
    return
  end
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.opt_local.foldmethod = 'manual'
    vim.cmd(string.format('silent! %d,%dfold', 1, close_line))
    if M.cfg.backlinks.fold_by_default then
      vim.cmd 'silent! normal! zM'
    end
  end)
end
local function fold_links_section(buf)
  if not M.cfg.folds.links then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local n = #lines
  local header_pattern = '^##%s+' .. vim.pesc(M.cfg.backlinks.section_header) .. '%s*$'
  local s
  for i = 1, n do
    if lines[i]:match(header_pattern) then
      s = i
      break
    end
  end
  if not s then
    return
  end
  local e
  local delim = vim.pesc(M.cfg.backlinks.fold_delimiter)
  for j = s + 1, n do
    if lines[j]:match('^' .. delim .. '%s*$') then
      e = j
      break
    end
  end
  if not e then
    e = n
  end
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.opt_local.foldmethod = 'manual'
    if e > s + 1 then
      vim.cmd(string.format('silent! %d,%dfold', s + 1, e - 1))
    end
    if M.cfg.backlinks.fold_by_default then
      vim.cmd 'silent! normal! zM'
    end
  end)
end

-- Titles
local function get_first_h1_title(path)
  local ok, lines = pcall(vim.fn.readfile, path, '', 80)
  if not ok or not lines then
    return nil
  end
  local in_fm = false
  for _, l in ipairs(lines) do
    if l:match '^%-%-%-$' then
      in_fm = not in_fm
    end
    if not in_fm then
      local t = l:match '^#%s+(.+)'
      if t then
        return trim(t)
      end
    end
  end
  return nil
end
local function sanitize_alias(text)
  if not text then
    return nil
  end
  text = text:gsub('^%[%[', ''):gsub('%]%]$', '')
  text = text:gsub('^.-|', '')
  return text
end

-- Co-routines for prompts
local function co_run(fn)
  local co = coroutine.create(fn)
  local step
  step = function(...)
    local ok, result = coroutine.resume(co, ...)
    if not ok then
      error(result)
    elseif coroutine.status(co) ~= 'dead' then
      result(step)
    end
  end
  step()
end
local function await_input(prompt, default)
  return coroutine.yield(function(cont)
    vim.ui.input({ prompt = prompt, default = default or '' }, function(input)
      cont(input)
    end)
  end)
end
local function await_select(items, opts)
  return coroutine.yield(function(cont)
    vim.ui.select(items, opts or {}, function(choice)
      cont(choice)
    end)
  end)
end

-- =====================
-- Navigation Links block
-- =====================
local function insert_nav_links_block(buf, new_note_dir, parent_path, related_list)
  if not M.cfg.backlinks.enabled then
    return
  end
  local lines = {}
  lines[#lines + 1] = '## ' .. M.cfg.backlinks.section_header
  lines[#lines + 1] = M.cfg.backlinks.fold_delimiter
  lines[#lines + 1] = '### ' .. M.cfg.backlinks.subsection_backlinks
  if parent_path then
    local parent_title = sanitize_alias(get_first_h1_title(parent_path) or stem(parent_path))
    local wiki_rel = rel_wiki_path(new_note_dir, parent_path)
    lines[#lines + 1] = string.format('[[%s|%s]]', wiki_rel, parent_title)
  end
  lines[#lines + 1] = '### ' .. M.cfg.backlinks.subsection_related
  if related_list and #related_list > 0 then
    local groups, counts = {}, {}
    for _, rel in ipairs(related_list) do
      groups[rel.shared] = groups[rel.shared] or {}
      groups[rel.shared][#groups[rel.shared] + 1] = { wiki = rel.wiki, title = rel.title }
      counts[rel.shared] = true
    end
    local sorted_counts = vim.tbl_keys(counts)
    table.sort(sorted_counts, function(a, b)
      return a > b
    end)
    for _, count in ipairs(sorted_counts) do
      local rels = groups[count]
      table.sort(rels, function(a, b)
        return a.title < b.title
      end)
      lines[#lines + 1] = string.format('#### Shares %d %s', count, (count == 1 and 'tag' or 'tags'))
      for _, rel in ipairs(rels) do
        lines[#lines + 1] = string.format('[[%s|%s]]', rel.wiki, sanitize_alias(rel.title) or rel.title)
      end
    end
  end
  lines[#lines + 1] = M.cfg.backlinks.fold_delimiter
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, { '' })
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
end

local function scan_related_by_tags(root, here_path, my_tags)
  local related = {}
  if not my_tags or #my_tags == 0 then
    return related
  end
  local here_norm = normalize_path(here_path)
  local all_files = vim.fn.globpath(root, '**/*.md', false, true)
  for _, file in ipairs(all_files) do
    local abs = normalize_path(file)
    if abs ~= here_norm then
      local lines = vim.fn.readfile(abs, '', 120)
      local note_tags = {}
      if lines and lines[1] == '---' then
        note_tags = parse_frontmatter(lines).tags or {}
      end
      if #note_tags > 0 then
        local shared = 0
        for _, t in ipairs(note_tags) do
          for _, mine in ipairs(my_tags) do
            if t == mine then
              shared = shared + 1
              break
            end
          end
        end
        if shared > 0 then
          local title = get_first_h1_title(abs) or stem(abs)
          related[#related + 1] = { path = abs, wiki = rel_wiki_path(dirname(here_norm), abs), title = title, shared = shared }
        end
      end
    end
  end
  table.sort(related, function(a, b)
    if a.shared ~= b.shared then
      return a.shared > b.shared
    end
    return a.title < b.title
  end)
  return related
end

-- =====================
-- Template helpers
-- =====================
local function render_template(lines, meta)
  local text = table.concat(lines, '\n')
  local R = {
    ['{{title}}'] = meta.title or '',
    ['{{date}}'] = os.date '%Y-%m-%d',
    ['{{id}}'] = meta.id or '',
    ['{{content}}'] = meta.content or '',
    ['{{tags}}'] = (meta.tags and #meta.tags > 0) and table.concat(meta.tags, ', ') or '',
  }
  for token, val in pairs(R) do
    text = text:gsub(vim.pesc(token), val)
  end
  text = text:gsub('%s*$', '')
  return vim.split(text, '\n', { plain = true })
end
local function list_templates(root)
  local results, seen = {}, {}
  local function add_dir(dir)
    if vim.fn.isdirectory(dir) == 0 then
      return
    end
    for _, f in ipairs(vim.fn.globpath(dir, '*.md', false, true)) do
      local name = stem(f)
      if not seen[name] then
        seen[name] = f
        results[#results + 1] = name
      end
    end
    for _, f in ipairs(vim.fn.globpath(dir, '*/*.md', false, true)) do
      local name = stem(f)
      if not seen[name] then
        seen[name] = f
        results[#results + 1] = name
      end
    end
  end
  add_dir(join(root, '.zk', 'templates'))
  add_dir(vim.fn.expand '~/.config/.zk/templates')
  table.sort(results)
  return results, seen
end

-- =====================
-- Preview windows
-- =====================
local function attach_preview_controls(buf, win)
  local ms, rs = M.cfg.preview.move_step, M.cfg.preview.resize_step
  local function adjust(drow, dcol, dheight, dwidth)
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local cfg = vim.api.nvim_win_get_config(win)
    local row = (type(cfg.row) == 'table' and cfg.row[false]) or cfg.row
    local col = (type(cfg.col) == 'table' and cfg.col[false]) or cfg.col
    local width, height = cfg.width, cfg.height
    vim.api.nvim_win_set_config(win, {
      relative = 'editor',
      style = 'minimal',
      border = M.cfg.preview.border,
      width = math.max(10, width + dwidth),
      height = math.max(1, height + dheight),
      row = math.max(1, row + drow),
      col = math.max(0, col + dcol),
    })
  end
  local opts = { silent = true, noremap = true, nowait = true, buffer = buf }
  local function maybe_move(key, drow, dcol)
    if M._previews.controls_enabled then
      adjust(drow, dcol, 0, 0)
    else
      feedkeys(key)
    end
  end
  vim.keymap.set('n', 'h', function()
    maybe_move('h', 0, -ms)
  end, vim.tbl_extend('force', opts, { desc = 'Move left' }))
  vim.keymap.set('n', 'j', function()
    maybe_move('j', ms, 0)
  end, vim.tbl_extend('force', opts, { desc = 'Move down' }))
  vim.keymap.set('n', 'k', function()
    maybe_move('k', -ms, 0)
  end, vim.tbl_extend('force', opts, { desc = 'Move up' }))
  vim.keymap.set('n', 'l', function()
    maybe_move('l', 0, ms)
  end, vim.tbl_extend('force', opts, { desc = 'Move right' }))
  vim.keymap.set('n', '<A-h>', function()
    adjust(0, 0, 0, -rs)
  end, vim.tbl_extend('force', opts, { desc = 'Narrow' }))
  vim.keymap.set('n', '<A-l>', function()
    adjust(0, 0, 0, rs)
  end, vim.tbl_extend('force', opts, { desc = 'Widen' }))
  vim.keymap.set('n', '<A-k>', function()
    adjust(-rs, 0, -rs, 0)
  end, vim.tbl_extend('force', opts, { desc = 'Shorter' }))
  vim.keymap.set('n', '<A-j>', function()
    adjust(rs, 0, rs, 0)
  end, vim.tbl_extend('force', opts, { desc = 'Taller' }))
  -- Float -> split helpers
  vim.keymap.set('n', '<A-H>', function()
    if vim.api.nvim_win_is_valid(win) then
      local path = vim.api.nvim_buf_get_name(buf)
      vim.api.nvim_win_close(win, true)
      vim.cmd('leftabove vsplit ' .. vim.fn.fnameescape(path))
    end
  end, vim.tbl_extend('force', opts, { desc = 'Float → left vsplit' }))
  vim.keymap.set('n', '<A-L>', function()
    if vim.api.nvim_win_is_valid(win) then
      local path = vim.api.nvim_buf_get_name(buf)
      vim.api.nvim_win_close(win, true)
      vim.cmd('vsplit ' .. vim.fn.fnameescape(path))
    end
  end, vim.tbl_extend('force', opts, { desc = 'Float → right vsplit' }))
  vim.keymap.set('n', '<A-K>', function()
    if vim.api.nvim_win_is_valid(win) then
      local path = vim.api.nvim_buf_get_name(buf)
      vim.api.nvim_win_close(win, true)
      vim.cmd('leftabove split ' .. vim.fn.fnameescape(path))
    end
  end, vim.tbl_extend('force', opts, { desc = 'Float → top split' }))
  vim.keymap.set('n', '<A-J>', function()
    if vim.api.nvim_win_is_valid(win) then
      local path = vim.api.nvim_buf_get_name(buf)
      vim.api.nvim_win_close(win, true)
      vim.cmd('split ' .. vim.fn.fnameescape(path))
    end
  end, vim.tbl_extend('force', opts, { desc = 'Float → bottom split' }))
  -- Quick close of this preview window
  vim.keymap.set('n', 'q', function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, vim.tbl_extend('force', opts, { desc = 'Close preview' }))
  -- Float‑local <leader>z helpers
  vim.keymap.set('n', M.cfg.preview.controls_toggle, function()
    M.toggle_preview_controls()
  end, vim.tbl_extend('force', opts, { desc = 'Toggle move/resize' }))
  vim.keymap.set('n', '<leader>zH', function()
    M.toggle_preview_hide_show()
  end, vim.tbl_extend('force', opts, { desc = 'Hide/show previews' }))
  vim.keymap.set('n', '<leader>zP', function()
    local path = vim.api.nvim_buf_get_name(buf)
    local rec = M._previews.items[path]
    if rec then
      rec.pinned = not rec.pinned
      vim.notify((rec.pinned and 'Pinned ' or 'Unpinned ') .. vim.fn.fnamemodify(path, ':t'))
    end
  end, vim.tbl_extend('force', opts, { desc = 'Pin/unpin this preview' }))
end

local function open_preview_window(rec, cfg)
  if rec.win and vim.api.nvim_win_is_valid(rec.win) then
    return rec.win
  end
  local opts = {
    relative = 'editor',
    style = 'minimal',
    border = M.cfg.preview.border,
    width = cfg.width,
    height = cfg.height,
    row = cfg.row,
    col = cfg.col,
    noautocmd = true,
  }
  rec.win = vim.api.nvim_open_win(rec.buf, false, opts)
  attach_preview_controls(rec.buf, rec.win)
  return rec.win
end

local function apply_layout()
  if M._previews.hidden then
    return
  end
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - (vim.o.cmdheight or 1)
  local count = #M._previews.order
  if count == 0 then
    return
  end
  local base_row, base_col = 1, 2
  local width = math.floor(editor_width * M.cfg.preview.width)
  local height = math.min(M.cfg.preview.height, editor_height - 2)
  if M.cfg.preview.layout == 'bottomright' then
    base_row = editor_height - height * count - M.cfg.preview.stack_gap * (count - 1)
    if base_row < 1 then
      base_row = 1
    end
    base_col = editor_width - width - 2
  end
  local row = base_row
  for _, path in ipairs(M._previews.order) do
    local rec = M._previews.items[path]
    open_preview_window(rec, { row = row, col = base_col, width = width, height = height })
    row = row + height + M.cfg.preview.stack_gap
  end
end

local function ensure_preview_for_path(path)
  local rec = M._previews.items[path]
  if rec and vim.api.nvim_buf_is_valid(rec.buf) then
    return rec
  end
  rec = { path = path, buf = vim.fn.bufadd(path), win = nil, pinned = false }
  M._previews.items[path] = rec
  M._previews.order[#M._previews.order + 1] = path
  vim.fn.bufload(rec.buf)
  -- NOTE: keep as a real file buffer so filetype plugins attach; do NOT set buftype=nofile.
  vim.api.nvim_buf_set_option(rec.buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(rec.buf, 'swapfile', false)
  return rec
end

local function close_preview(path)
  local rec = M._previews.items[path]
  if not rec then
    return
  end
  if rec.win and vim.api.nvim_win_is_valid(rec.win) then
    vim.api.nvim_win_close(rec.win, true)
  end
  if vim.api.nvim_buf_is_valid(rec.buf) then
    vim.api.nvim_buf_delete(rec.buf, { force = true })
  end
  M._previews.items[path] = nil
  for i, p in ipairs(M._previews.order) do
    if p == path then
      table.remove(M._previews.order, i)
      break
    end
  end
end

local function preview_for_link_under_cursor()
  if not M.cfg.preview.auto or M._previews.hidden then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    return
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local target_name
  for s, inner, e in line:gmatch '()%[%[([^%]]-)%]%]()' do
    if col + 1 >= s and col + 1 <= e then
      target_name = trim((inner:match '^(.-)|' or inner))
      break
    end
  end
  if not target_name or target_name == '' then
    return
  end
  local here_dir = dirname(file)
  local found_paths = {}
  if target_name:match '/$' then
    local dir_path = normalize_path(join(here_dir, target_name))
    if vim.fn.isdirectory(dir_path) == 1 then
      found_paths[#found_paths + 1] = dir_path
    end
  else
    local target_with_ext = target_name:match '%.md$' and target_name or (target_name .. '.md')
    if target_name:match '^%.' or target_name:match '/' then
      local full_path = normalize_path(join(here_dir, target_with_ext))
      if vim.fn.filereadable(full_path) == 1 then
        found_paths[#found_paths + 1] = full_path
      end
    else
      local matches = vim.fn.globpath(root, '**/' .. target_with_ext, false, true)
      for _, m in ipairs(matches) do
        found_paths[#found_paths + 1] = normalize_path(m)
      end
    end
  end
  if #found_paths == 0 then
    return
  end
  local target_path = found_paths[1]
  -- Close any non‑pinned preview before opening a new auto one
  for path, rec in pairs(M._previews.items) do
    if not rec.pinned then
      close_preview(path)
      break
    end
  end
  local rec = ensure_preview_for_path(target_path)
  rec.pinned = false
  open_preview_window(
    rec,
    { row = 1, col = 2, width = math.floor(vim.o.columns * M.cfg.preview.width), height = math.min(M.cfg.preview.height, vim.o.lines - 2) }
  )
  apply_layout()
end

-- Public preview toggles
function M.toggle_preview_auto()
  M.cfg.preview.auto = not M.cfg.preview.auto
  vim.notify('ZK Auto‑Peek: ' .. (M.cfg.preview.auto and 'ON' or 'OFF'), vim.log.levels.INFO)
end
function M.toggle_preview_layout()
  M.cfg.preview.layout = (M.cfg.preview.layout == 'topleft') and 'bottomright' or 'topleft'
  apply_layout()
end
function M.toggle_preview_hide_show()
  if not M._previews.hidden then
    for _, rec in pairs(M._previews.items) do
      if rec.win and vim.api.nvim_win_is_valid(rec.win) then
        vim.api.nvim_win_hide(rec.win)
      end
      rec.win = nil
    end
    M._previews.hidden = true
  else
    M._previews.hidden = false
    apply_layout()
  end
end
function M.toggle_preview_controls()
  M._previews.controls_enabled = not M._previews.controls_enabled
  vim.notify('Preview Move/Resize: ' .. (M._previews.controls_enabled and 'ENABLED' or 'DISABLED'), vim.log.levels.INFO)
end

-- Manual preview of wikilink under cursor (unpinned)
function M.preview_here()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    return
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local target_name
  for s, inner, e in line:gmatch '()%[%[([^%]]-)%]%]()' do
    if col + 1 >= s and col + 1 <= e then
      target_name = trim((inner:match '^(.-)|' or inner))
      break
    end
  end
  if not target_name or target_name == '' then
    vim.notify('No wikilink under cursor', vim.log.levels.INFO)
    return
  end
  local here_dir = dirname(file)
  local target_with_ext = target_name:match '%.md$' and target_name or (target_name .. '.md')
  local path
  if target_name:match '^%.' or target_name:match '/' then
    local full = normalize_path(join(here_dir, target_with_ext))
    if vim.fn.filereadable(full) == 1 then
      path = full
    end
  else
    local matches = vim.fn.globpath(root, '**/' .. target_with_ext, false, true)
    if #matches > 0 then
      path = normalize_path(matches[1])
    end
  end
  if not path then
    vim.notify('Target note not found', vim.log.levels.INFO)
    return
  end
  local rec = ensure_preview_for_path(path)
  rec.pinned = false
  open_preview_window(
    rec,
    { row = 1, col = 2, width = math.floor(vim.o.columns * M.cfg.preview.width), height = math.min(M.cfg.preview.height, vim.o.lines - 2) }
  )
  apply_layout()
end

-- Pin/unpin preview for link under cursor (or open pinned if closed)
function M.toggle_pin_preview()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    return
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local target_name
  for s, inner, e in line:gmatch '()%[%[([^%]]-)%]%]()' do
    if col + 1 >= s and col + 1 <= e then
      target_name = trim((inner:match '^(.-)|' or inner))
      break
    end
  end
  if not target_name or target_name == '' then
    return
  end
  local here_dir = dirname(file)
  local target_with_ext = target_name:match '%.md$' and target_name or (target_name .. '.md')
  local path
  if target_name:match '^%.' or target_name:match '/' then
    local full = normalize_path(join(here_dir, target_with_ext))
    if vim.fn.filereadable(full) == 1 then
      path = full
    end
  else
    local matches = vim.fn.globpath(root, '**/' .. target_with_ext, false, true)
    if #matches > 0 then
      path = normalize_path(matches[1])
    end
  end
  if not path then
    return
  end
  local rec = M._previews.items[path]
  if rec and rec.win and vim.api.nvim_win_is_valid(rec.win) then
    rec.pinned = not rec.pinned
    vim.notify(string.format('Preview %s %s', vim.fn.fnamemodify(path, ':t'), rec.pinned and 'pinned' or 'unpinned'), vim.log.levels.INFO)
  else
    local new_rec = ensure_preview_for_path(path)
    new_rec.pinned = true
    open_preview_window(
      new_rec,
      { row = 1, col = 2, width = math.floor(vim.o.columns * M.cfg.preview.width), height = math.min(M.cfg.preview.height, vim.o.lines - 2) }
    )
    apply_layout()
  end
end

-- Focus the Nth pinned preview (1..9)
function M.focus_preview_n(n)
  local pinned = {}
  for _, path in ipairs(M._previews.order) do
    local rec = M._previews.items[path]
    if rec and rec.pinned then
      pinned[#pinned + 1] = path
    end
  end
  local target = pinned[n]
  if not target then
    vim.notify('No pinned preview ' .. n, vim.log.levels.INFO)
    return
  end
  local rec = M._previews.items[target]
  if not (rec and vim.api.nvim_buf_is_valid(rec.buf)) then
    return
  end
  if not (rec.win and vim.api.nvim_win_is_valid(rec.win)) then
    apply_layout()
  end
  if rec.win and vim.api.nvim_win_is_valid(rec.win) then
    vim.api.nvim_set_current_win(rec.win)
  end
end

-- =====================
-- Follow / Create
-- =====================
function M.follow_or_create()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    vim.notify('Not in a zk notebook', vim.log.levels.WARN)
    return
  end
  local w
  do
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    for s, inner, e in line:gmatch '()%[%[([^%]]-)%]%]()' do
      if col + 1 >= s and col + 1 <= e then
        local target, alias = inner:match '^(.-)|(.+)$'
        w = { target = trim(target or inner), alias = alias and trim(alias) or nil }
        break
      end
    end
  end
  if not w or w.target == '' then
    feedkeys '<CR>'
    return
  end
  local here_dir = dirname(file)
  local target_name = w.target
  local is_dir_link = target_name:match '/$'
  local candidate_paths = {}
  if is_dir_link then
    local dir_path = normalize_path(join(here_dir, target_name))
    if vim.fn.isdirectory(dir_path) == 1 then
      candidate_paths[#candidate_paths + 1] = dir_path
    end
  else
    local target_with_ext = target_name:match '%.md$' and target_name or (target_name .. '.md')
    if target_name:match '^%.' or target_name:match '/' then
      local full = normalize_path(join(here_dir, target_with_ext))
      if vim.fn.filereadable(full) == 1 then
        candidate_paths[#candidate_paths + 1] = full
      end
    else
      local matches = vim.fn.globpath(root, '**/' .. target_with_ext, false, true)
      for _, m in ipairs(matches) do
        candidate_paths[#candidate_paths + 1] = normalize_path(m)
      end
    end
  end
  if #candidate_paths > 0 then
    local target_path = candidate_paths[1]
    if vim.fn.isdirectory(target_path) == 1 then
      local width, height = vim.o.columns, (vim.o.lines - (vim.o.cmdheight or 1))
      if pcall(require, 'oil') then
        if width > height then
          vim.cmd('vsplit ' .. vim.fn.fnameescape(target_path))
        else
          vim.cmd('split ' .. vim.fn.fnameescape(target_path))
        end
        require('oil').open(target_path)
      else
        vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
      end
    else
      vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
    end
    local origin = file
    if origin and origin ~= '' then
      M._history[#M._history + 1] = origin
      if #M._history > 300 then
        table.remove(M._history, 1)
      end
    end
    return
  end
  -- Create flow
  co_run(function()
    local title = w.alias or w.target
    title = await_input('Title: ', title)
    if not title or title == '' then
      vim.notify('Canceled', vim.log.levels.INFO)
      return
    end
    local tags_input = await_input('Tags (comma-separated): ', '')
    if tags_input == nil then
      vim.notify('Canceled', vim.log.levels.INFO)
      return
    end
    local tags = {}
    for tag in (tags_input or ''):gmatch '([^,]+)' do
      tag = trim(tag)
      if tag ~= '' then
        tags[#tags + 1] = tag
      end
    end
    local template = ''
    local templates, template_map = list_templates(root)
    if #templates > 0 then
      local choice = await_select(vim.list_extend({ '(No template)' }, templates), { prompt = 'Template (Enter to skip):' })
      if choice == nil then
        vim.notify('Canceled', vim.log.levels.INFO)
        return
      end
      if choice ~= '(No template)' then
        template = choice
      end
    end
    local confirm = await_input(string.format("Create note '%s'? (y/N): ", title), '')
    if not confirm or confirm:lower() ~= 'y' then
      vim.notify('Canceled', vim.log.levels.INFO)
      return
    end

    local base_name = (M.cfg.filename_mode == 'slug') and slugify(title) or title
    local note_id = ''
    if M.cfg.id_prefix then
      note_id = random_id(M.cfg.id_length)
      local collision = vim.fn.globpath(root, '**/' .. note_id .. '*.md', false, true)
      local attempts = 0
      while #collision > 0 and attempts < 5 do
        note_id = random_id(M.cfg.id_length)
        collision = vim.fn.globpath(root, '**/' .. note_id .. '*.md', false, true)
        attempts = attempts + 1
      end
      base_name = note_id .. '-' .. base_name
    end
    local file_name = base_name:match '%.md$' and base_name or (base_name .. '.md')
    local target_dir = here_dir
    if w.target:match '^%.' or w.target:match '/' then
      local target_path = normalize_path(join(here_dir, w.target))
      target_dir = dirname(target_path)
    end
    ensure_dir(target_dir)
    local full_path = normalize_path(join(target_dir, file_name))
    if vim.fn.filereadable(full_path) == 1 then
      vim.notify('File already exists: ' .. full_path, vim.log.levels.WARN)
      vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
      return
    end

    vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
    local lines = { '---', 'title: ' .. title, 'date: ' .. os.date '%Y-%m-%d' }
    if #tags > 0 then
      lines[#lines + 1] = 'tags: [' .. table.concat(tags, ', ') .. ']'
    else
      lines[#lines + 1] = 'tags: []'
    end
    lines[#lines + 1] = 'aliases: []'
    if note_id ~= '' then
      lines[#lines + 1] = 'id: ' .. note_id
    end
    lines[#lines + 1] = '---'
    vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { '' })
    local h1_line = '# ' .. title
    if file ~= '' and vim.api.nvim_buf_is_loaded(buf) then
      local rel_link = rel_wiki_path(dirname(full_path), file)
      local parent_title = sanitize_alias(get_first_h1_title(file) or stem(file)) or ''
      if parent_title ~= '' then
        h1_line = '# [[' .. rel_link .. '|' .. title .. ']]'
      end
    end
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { h1_line, '' })
    if template ~= '' and template_map then
      local tmpl_path = template_map[template]
      if tmpl_path then
        local tmpl_lines = vim.fn.readfile(tmpl_path)
        if tmpl_lines then
          local rendered = render_template(tmpl_lines, { title = title, id = note_id, tags = tags, content = '' })
          if #rendered > 0 then
            vim.api.nvim_buf_set_lines(0, -1, -1, false, rendered)
            vim.api.nvim_buf_set_lines(0, -1, -1, false, { '' })
          end
        end
      end
    end
    local related = scan_related_by_tags(root, full_path, tags)
    insert_nav_links_block(0, dirname(full_path), file ~= '' and file or nil, related)
    if M.cfg.autosave_created then
      vim.cmd 'silent! write'
    end
    fold_frontmatter(0)
    fold_links_section(0)
    show_tags_virttext(0)
    if file ~= '' then
      M._history[#M._history + 1] = file
      if #M._history > 300 then
        table.remove(M._history, 1)
      end
    end
    vim.notify('Created note: ' .. title, vim.log.levels.INFO)
  end)
end

function M.open_link()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    vim.notify('Not in a zk notebook', vim.log.levels.WARN)
    return
  end
  local w
  do
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    for s, inner, e in line:gmatch '()%[%[([^%]]-)%]%]()' do
      if col + 1 >= s and col + 1 <= e then
        w = { target = trim(inner:match '^(.-)|' or inner) }
        break
      end
    end
  end
  if not w or w.target == '' then
    feedkeys '<CR>'
    return
  end
  local here_dir = dirname(file)
  local paths = {}
  if w.target:match '/$' then
    local dirp = normalize_path(join(here_dir, w.target))
    if vim.fn.isdirectory(dirp) == 1 then
      paths[#paths + 1] = dirp
    end
  else
    local target_with_ext = w.target:match '%.md$' and w.target or (w.target .. '.md')
    if w.target:match '^%.' or w.target:match '/' then
      local full = normalize_path(join(here_dir, target_with_ext))
      if vim.fn.filereadable(full) == 1 then
        paths[#paths + 1] = full
      end
    else
      for _, m in ipairs(vim.fn.globpath(root, '**/' .. target_with_ext, false, true)) do
        paths[#paths + 1] = normalize_path(m)
      end
    end
  end
  if #paths > 0 then
    local target_path = paths[1]
    if vim.fn.isdirectory(target_path) == 1 then
      if pcall(require, 'oil') then
        if vim.o.columns > vim.o.lines then
          vim.cmd('vsplit ' .. vim.fn.fnameescape(target_path))
        else
          vim.cmd('split ' .. vim.fn.fnameescape(target_path))
        end
        require('oil').open(target_path)
      else
        vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
      end
    else
      vim.cmd('edit ' .. vim.fn.fnameescape(target_path))
    end
    if file ~= '' then
      M._history[#M._history + 1] = file
      if #M._history > 300 then
        table.remove(M._history, 1)
      end
    end
  else
    vim.notify('No note found for [[' .. w.target .. ']]. Use <leader>zf to create it.', vim.log.levels.INFO)
  end
end

function M.instant_create()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    vim.notify('Not in a zk notebook', vim.log.levels.WARN)
    return
  end
  local w
  do
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    for s, inner, e in line:gmatch '()%[%[([^%]]-)%]%]()' do
      if col + 1 >= s and col + 1 <= e then
        local target, alias = inner:match '^(.-)|(.+)$'
        w = { target = trim(target or inner), alias = alias and trim(alias) or nil }
        break
      end
    end
  end
  if not w or w.target == '' then
    feedkeys '<CR>'
    return
  end
  local title = w.alias or w.target
  local base_name = (M.cfg.filename_mode == 'slug') and slugify(title) or title
  local note_id = ''
  if M.cfg.id_prefix then
    note_id = random_id(M.cfg.id_length)
    base_name = note_id .. '-' .. base_name
  end
  local filename = base_name:match '%.md$' and base_name or (base_name .. '.md')
  local target_dir = dirname(file)
  if w.target:match '^%.' or w.target:match '/' then
    local full = normalize_path(join(target_dir, w.target))
    target_dir = dirname(full)
  end
  ensure_dir(target_dir)
  local full_path = normalize_path(join(target_dir, filename))
  vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
  local lines = { '---', 'title: ' .. title, 'date: ' .. os.date '%Y-%m-%d', 'tags: []', 'aliases: []' }
  if note_id ~= '' then
    lines[#lines + 1] = 'id: ' .. note_id
  end
  lines[#lines + 1] = '---'
  vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { '' })
  local h1_line = '# ' .. title
  if file ~= '' then
    local parent_title = sanitize_alias(get_first_h1_title(file) or stem(file)) or ''
    if parent_title ~= '' then
      local rel_link = rel_wiki_path(dirname(full_path), file)
      h1_line = '# [[' .. rel_link .. '|' .. title .. ']]'
    end
  end
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { h1_line, '' })
  insert_nav_links_block(0, dirname(full_path), file ~= '' and file or nil, {})
  if M.cfg.autosave_created then
    vim.cmd 'silent! write'
  end
  fold_frontmatter(0)
  fold_links_section(0)
  show_tags_virttext(0)
  if file ~= '' then
    M._history[#M._history + 1] = file
    if #M._history > 300 then
      table.remove(M._history, 1)
    end
  end
  vim.notify('Created note: ' .. title, vim.log.levels.INFO)
end

function M.update_links_section()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root or not M.cfg.backlinks.enabled then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local n = #lines
  local header_pattern = '^##%s+' .. vim.pesc(M.cfg.backlinks.section_header) .. '%s*$'
  local header_idx
  for i = 1, n do
    if lines[i]:match(header_pattern) then
      header_idx = i
      break
    end
  end
  if not header_idx then
    local tags = parse_frontmatter(lines).tags or {}
    local related = scan_related_by_tags(root, file, tags)
    insert_nav_links_block(buf, dirname(file), nil, related)
    vim.cmd 'write'
    fold_links_section(buf)
    return
  end
  local related_idx
  for j = header_idx + 1, n do
    if lines[j]:match('^###%s+' .. vim.pesc(M.cfg.backlinks.subsection_related)) then
      related_idx = j
      break
    end
  end
  local end_idx
  if related_idx then
    for k = related_idx, n do
      if lines[k]:match('^' .. vim.pesc(M.cfg.backlinks.fold_delimiter) .. '%s*$') then
        end_idx = k
        break
      end
    end
    if not end_idx then
      end_idx = n
    end
  else
    for k = header_idx + 1, n do
      if lines[k]:match('^' .. vim.pesc(M.cfg.backlinks.fold_delimiter) .. '%s*$') then
        end_idx = k
        break
      end
    end
    if not end_idx then
      end_idx = n
    end
    related_idx = end_idx
  end
  local tags = parse_frontmatter(lines).tags or {}
  local new_related = scan_related_by_tags(root, file, tags)
  vim.api.nvim_buf_set_lines(buf, related_idx, end_idx, false, {})
  local insert_lines = {}
  if #new_related > 0 then
    local groups, counts = {}, {}
    for _, rel in ipairs(new_related) do
      groups[rel.shared] = groups[rel.shared] or {}
      groups[rel.shared][#groups[rel.shared] + 1] = { wiki = rel.wiki, title = rel.title }
      counts[rel.shared] = true
    end
    local sorted_counts = vim.tbl_keys(counts)
    table.sort(sorted_counts, function(a, b)
      return a > b
    end)
    if lines[related_idx - 1] ~= '' then
      insert_lines[#insert_lines + 1] = ''
    end
    if not lines[related_idx] or not lines[related_idx]:match('^###%s+' .. vim.pesc(M.cfg.backlinks.subsection_related)) then
      insert_lines[#insert_lines + 1] = '### ' .. M.cfg.backlinks.subsection_related
    end
    for _, count in ipairs(sorted_counts) do
      local rels = groups[count]
      table.sort(rels, function(a, b)
        return a.title < b.title
      end)
      insert_lines[#insert_lines + 1] = ''
      insert_lines[#insert_lines + 1] = string.format('#### Shares %d %s', count, (count == 1 and 'tag' or 'tags'))
      for _, rel in ipairs(rels) do
        insert_lines[#insert_lines + 1] = string.format('[[%s|%s]]', rel.wiki, sanitize_alias(rel.title) or rel.title)
      end
    end
  else
    if related_idx and related_idx <= n and lines[related_idx]:match('###%s+' .. vim.pesc(M.cfg.backlinks.subsection_related)) then
      insert_lines[#insert_lines + 1] = ''
    else
      return
    end
  end
  vim.api.nvim_buf_set_lines(buf, related_idx, related_idx, false, insert_lines)
  vim.cmd 'write'
  fold_links_section(buf)
end

-- =====================
-- Buffers/UX: lists & history
-- =====================
function M.list_links_in_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local items, positions = {}, {}
  for i, line in ipairs(lines) do
    for s, inner in line:gmatch '()%[%[([^%]]-)%]%]' do
      local target, alias = inner:match '^(.-)|(.+)$'
      local alias_text = alias and trim(alias) or nil
      local target_text = trim(target or inner)
      local display = alias_text and (alias_text .. ' -> ' .. target_text) or target_text
      items[#items + 1] = display
      positions[display] = { lnum = i, col = s - 1 }
    end
  end
  if #items == 0 then
    vim.notify('No wikilinks in this buffer', vim.log.levels.INFO)
    return
  end
  vim.ui.select(items, { prompt = 'Links in buffer:' }, function(choice)
    if choice then
      local pos = positions[choice]
      if pos then
        vim.api.nvim_win_set_cursor(0, { pos.lnum, pos.col })
      end
    end
  end)
end
function M.open_history_picker()
  if #M._history == 0 then
    vim.notify('History is empty', vim.log.levels.INFO)
    return
  end
  local unique, items = {}, {}
  for idx = #M._history, 1, -1 do
    local path = M._history[idx]
    if not unique[path] then
      unique[path] = true
      items[#items + 1] = { path = path, title = sanitize_alias(get_first_h1_title(path) or stem(path)) or stem(path) }
    end
  end
  if #items == 0 then
    return
  end
  table.sort(items, function(a, b)
    return a.title < b.title
  end)
  vim.ui.select(items, {
    prompt = 'Jump History:',
    format_item = function(item)
      return item.title
    end,
  }, function(choice)
    if choice then
      vim.cmd('edit ' .. vim.fn.fnameescape(choice.path))
    end
  end)
end

-- Tag navigation (next/prev) — keep minimal; prompt first for a tag
local function jump_to_link_by_tag(chosen_tag, direction)
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local tag_positions, cache = {}, {}
  for lnum, line in ipairs(lines) do
    for s, inner in line:gmatch '()%[%[([^%]]-)%]%]' do
      local target = trim(inner:match '^(.-)|' or inner)
      if target ~= '' and not target:match '/$' then
        local target_file
        if target:match '^%.' or target:match '/' then
          local full = normalize_path(join(dirname(file), target:match '%.md$' and target or (target .. '.md')))
          if vim.fn.filereadable(full) == 1 then
            target_file = full
          end
        else
          local matches = vim.fn.globpath(root, '**/' .. (target:match '%.md$' and target or (target .. '.md')), false, true)
          if #matches > 0 then
            target_file = normalize_path(matches[1])
          end
        end
        local tag_list = {}
        if target_file then
          local ok, note_lines = pcall(vim.fn.readfile, target_file, '', 50)
          if ok and note_lines and note_lines[1] == '---' then
            tag_list = parse_frontmatter(note_lines).tags or {}
          end
        end
        for _, tag in ipairs(tag_list) do
          tag_positions[tag] = tag_positions[tag] or {}
          tag_positions[tag][#tag_positions[tag] + 1] = { lnum = lnum, col = s - 1 }
        end
      end
    end
  end
  if not tag_positions[chosen_tag] or #tag_positions[chosen_tag] == 0 then
    vim.notify('No links in this note have tag #' .. chosen_tag, vim.log.levels.INFO)
    return
  end
  table.sort(tag_positions[chosen_tag], function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)
  local positions = tag_positions[chosen_tag]
  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_pos = { lnum = cur[1], col = cur[2] }
  local target_idx
  if direction == 'next' then
    for i, pos in ipairs(positions) do
      if pos.lnum > cur_pos.lnum or (pos.lnum == cur_pos.lnum and pos.col > cur_pos.col) then
        target_idx = i
        break
      end
    end
    if not target_idx then
      target_idx = 1
    end
  else
    for i = #positions, 1, -1 do
      local pos = positions[i]
      if pos.lnum < cur_pos.lnum or (pos.lnum == cur_pos.lnum and pos.col < cur_pos.col) then
        target_idx = i
        break
      end
    end
    if not target_idx then
      target_idx = #positions
    end
  end
  local target_pos = positions[target_idx]
  if target_pos then
    vim.api.nvim_win_set_cursor(0, { target_pos.lnum, target_pos.col })
  end
end
function M.pick_link_by_tag()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(file)
  if not root then
    return
  end
  local tag_set, lines = {}, vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, line in ipairs(lines) do
    for _, inner in line:gmatch '%[%[([^%]]-)%]%]' do
      local target = trim(inner:match '^(.-)|' or inner)
      if target ~= '' and not target:match '/$' then
        local tag_list = {}
        if target:match '^%.' or target:match '/' then
          local full = normalize_path(join(dirname(file), target:match '%.md$' and target or (target .. '.md')))
          if vim.fn.filereadable(full) == 1 then
            local ok, note_lines = pcall(vim.fn.readfile, full, '', 50)
            if ok and note_lines and note_lines[1] == '---' then
              tag_list = parse_frontmatter(note_lines).tags or {}
            end
          end
        else
          local matches = vim.fn.globpath(root, '**/' .. (target:match '%.md$' and target or (target .. '.md')), false, true)
          if #matches > 0 then
            local ok, note_lines = pcall(vim.fn.readfile, matches[1], '', 50)
            if ok and note_lines and note_lines[1] == '---' then
              tag_list = parse_frontmatter(note_lines).tags or {}
            end
          end
        end
        for _, tag in ipairs(tag_list) do
          tag_set[tag] = true
        end
      end
    end
  end
  local tags = vim.tbl_keys(tag_set)
  if #tags == 0 then
    vim.notify('No tags found in any linked notes', vim.log.levels.INFO)
    return
  end
  table.sort(tags)
  vim.ui.select(tags, { prompt = 'Select tag:' }, function(choice)
    if choice then
      jump_to_link_by_tag(choice, 'next')
    end
  end)
end
function M.pick_link_by_tag_previous()
  vim.notify('Use <leader>zT to pick a tag, then <leader>zt to jump previous among those links', vim.log.levels.INFO)
end

-- =====================
-- Setup & mappings
-- =====================
function M.setup(user_cfg)
  if type(user_cfg) == 'table' then
    M.cfg = vim.tbl_deep_extend('force', M.cfg, user_cfg)
  end

  -- blink.cmp provider stub (safe no‑op unless we later expand it)
  package.preload['zk_follow_create.completion'] = function()
    local Provider = {}
    function Provider.new()
      local P = {}
      function P:get_trigger_characters()
        return { '[', '/', '.', '-' }
      end
      function P:is_enabled(_ctx)
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype ~= 'markdown' then
          return false
        end
        local f = vim.api.nvim_buf_get_name(buf)
        return find_notebook_root(f) ~= nil
      end
      -- blink API calls either complete() or get_completions(); we support both and return empty safely
      function P:complete(_ctx, cb)
        cb { items = {}, is_incomplete = false }
      end
      function P:get_completions(_ctx, cb)
        cb { items = {}, is_incomplete = false }
      end
      return P
    end
    return Provider
  end

  vim.api.nvim_create_augroup('zk_follow_create', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = 'zk_follow_create',
    pattern = 'markdown',
    callback = function(args)
      local buf = args.buf
      local file = vim.api.nvim_buf_get_name(buf)
      if find_notebook_root(file or '') == nil then
        return
      end
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = buf, noremap = true, silent = true, desc = desc })
      end
      map('n', '<CR>', M.follow_or_create, 'Follow/Create wikilink')
      map('n', '<leader>zf', M.follow_or_create, 'ZK: Follow/Create link')
      map('n', '<leader>zo', M.open_link, 'ZK: Open link (no create)')
      map('n', '<leader>zF', M.instant_create, 'ZK: Instant create link')
      map('n', '<leader>zJ', M.follow_or_create, 'ZK: Follow & jump (reuse search)')
      map('n', '<leader>zU', M.update_links_section, 'ZK: Update Related links')
      map('n', '<leader>zL', M.list_links_in_buffer, 'ZK: List links in buffer')
      map('n', '<leader>zh', M.open_history_picker, 'ZK: History picker')
      map('n', '<leader>zT', M.pick_link_by_tag, 'ZK: Next link by tag…')
      map('n', '<leader>zt', function()
        M.pick_link_by_tag_previous()
      end, 'ZK: Previous link by tag')
      map('n', '<leader>zv', M.preview_here, 'ZK: Preview here (float)')
      for i = 1, 9 do
        map('n', string.format('<leader>z%d', i), function()
          M.focus_preview_n(i)
        end, string.format('ZK: Focus preview %d', i))
      end
      map('n', '<leader>zp', M.toggle_preview_auto, 'ZK: Toggle auto‑peek preview')
      map('n', '<leader>zP', M.toggle_pin_preview, 'ZK: Pin/unpin preview')
      map('n', '<leader>zH', M.toggle_preview_hide_show, 'ZK: Hide/show all previews')
      map('n', '<leader>zA', M.toggle_preview_layout, 'ZK: Toggle preview layout')
      map('n', M.cfg.preview.controls_toggle, M.toggle_preview_controls, 'ZK: Toggle preview move/resize mode')
      -- Insert helper [[./]]
      vim.keymap.set(
        'i',
        M.cfg.map_insert_relative,
        '[[./]]<Left><Left>',
        { buffer = buf, noremap = true, silent = true, desc = 'ZK: Insert relative link prefix' }
      )
      -- which‑key group (buffer‑local)
      local ok, wk = pcall(require, 'which-key')
      if ok then
        wk.register({ ['<leader>z'] = { name = 'Zettelkasten' } }, { buffer = buf })
      end
      -- Folds/virt on open & after write
      fold_frontmatter(buf)
      fold_links_section(buf)
      show_tags_virttext(buf)
      vim.api.nvim_create_autocmd('BufWritePost', {
        buffer = buf,
        callback = function()
          fold_links_section(buf)
          show_tags_virttext(buf)
        end,
      })
      -- Persist preview layouts (optional)
      if M.cfg.preview.persist then
        vim.api.nvim_create_autocmd('BufWinLeave', {
          buffer = buf,
          callback = function()
            local note = vim.fn.expand '%:p'
            local root = find_notebook_root(note)
            if not root then
              return
            end
            local state = {}
            state[note] = { pinned = {} }
            for _, rec in pairs(M._previews.items) do
              if rec.pinned and rec.win and vim.api.nvim_win_is_valid(rec.win) then
                local cfg = vim.api.nvim_win_get_config(rec.win)
                state[note].pinned[#state[note].pinned + 1] = { path = rec.path, row = cfg.row, col = cfg.col, width = cfg.width, height = cfg.height }
              end
            end
            if #state[note].pinned > 0 then
              ensure_dir(join(root, '.zk'))
              pcall(vim.fn.writefile, { vim.fn.json_encode(state) }, join(root, '.zk', 'preview_layouts.json'))
            end
          end,
        })
        vim.api.nvim_create_autocmd('BufReadPost', {
          buffer = buf,
          once = true,
          callback = function()
            local note = vim.fn.expand '%:p'
            local root = find_notebook_root(note)
            if not root then
              return
            end
            local state_file = join(root, '.zk', 'preview_layouts.json')
            if vim.fn.filereadable(state_file) == 0 then
              return
            end
            local ok, decoded = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(state_file), '\n'))
            local state = ok and decoded or {}
            local note_state = state[note]
            if note_state and note_state.pinned and #note_state.pinned > 0 then
              for _, rec in ipairs(note_state.pinned) do
                local R = ensure_preview_for_path(rec.path)
                R.pinned = true
                open_preview_window(
                  R,
                  {
                    row = rec.row or 1,
                    col = rec.col or 2,
                    width = rec.width or math.floor(vim.o.columns * M.cfg.preview.width),
                    height = rec.height or M.cfg.preview.height,
                  }
                )
              end
              apply_layout()
            end
          end,
        })
      end
      -- Auto‑peek on CursorHold
      vim.api.nvim_create_autocmd('CursorHold', { buffer = buf, callback = preview_for_link_under_cursor })
    end,
  })
end

-- (Optional) minimal source for other completion engines (kept for compatibility)
M.source = {}
M.source.new = function()
  return setmetatable({}, { __index = M.source })
end
function M.source:is_available()
  return vim.bo.filetype == 'markdown' and find_notebook_root(vim.fn.expand '%:p') ~= nil
end
function M.source:get_trigger_characters()
  return { '[', '/', '.', '-' }
end
function M.source:complete(params, callback)
  local line = params.context.cursor_before_line
  local col = params.context.cursor.col - 1
  local open_pos = line:sub(1, col):match '()%[%[[^%]]*$'
  if not open_pos then
    return callback { items = {}, isIncomplete = false }
  end
  local prefix = line:sub(open_pos + 2):gsub('^%s+', ''):gsub('|.*$', '')
  local here = vim.fn.expand '%:p'
  local root = find_notebook_root(here)
  if not root then
    return callback { items = {}, isIncomplete = false }
  end
  local base_dir = normalize_path(join(dirname(here), prefix))
  local items = {}
  if vim.fn.isdirectory(base_dir) == 1 then
    for _, d in ipairs(vim.fn.globpath(base_dir, '*/', false, true)) do
      local rel = rel_wiki_path(dirname(here), d)
      items[#items + 1] = { label = rel .. '/', insertText = rel .. '/', kind = vim.lsp.protocol.CompletionItemKind.Folder, detail = 'Folder' }
    end
    for _, f in ipairs(vim.fn.globpath(base_dir, '*.md', false, true)) do
      local rel = rel_wiki_path(dirname(here), f)
      items[#items + 1] = { label = rel, insertText = rel, kind = vim.lsp.protocol.CompletionItemKind.File, detail = 'Note' }
    end
  end
  callback { items = items, isIncomplete = false }
end

return M
