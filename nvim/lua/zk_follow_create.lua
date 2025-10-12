-- ~/.config/nvim/lua/zk_follow_create.lua
-- ZK follow/create + previews + backlinks + folds + blink.cmp provider
-- Hotfix: correct YAML closing '---', ensure blank line before H1, dedupe H1, fold timing.

local M = {}

-- =========================== CONFIG ===========================
M.cfg = {
  filename_mode = 'typed', -- 'typed' | 'slug' | 'zk'
  id_prefix = false,
  id_length = 4,

  backlinks = {
    enabled = true,
    section_header = 'Links',
    subsection_backlinks = 'Backlinks',
    fold_by_default = true,
  },

  telescope_templates = true,
  map_enter = true,
  map_namespace = true,

  preview = {
    auto = false,
    layout = 'topleft', -- 'topleft' | 'bottomright'
    center_active = false,
    width = 0.45,
    height = 14,
    stack_gap = 1,
    border = 'rounded',
  },

  folds = { frontmatter = true, links = true },
  virt_tags = { enabled = true, hl = 'Comment' },

  autosave_created = true,
  log_file = nil,
}

-- =========================== STATE ============================
M._history, M._previews = {}, { hidden = false, items = {}, order = {} }
M._ns_tags = vim.api.nvim_create_namespace 'zkfc_tags'

-- =========================== UTILS ============================
local function trim(s)
  return (s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end
local function slugify(s)
  s = (s or ''):lower():gsub('%s+', '-'):gsub('[^%w_%-%.]', '-'):gsub('%-+', '-')
  return s:gsub('^%-', ''):gsub('%-$', '')
end
local function random_id(n)
  local a = '0123456789abcdefghjkmnpqrstvwxyz'
  local t = {}
  for i = 1, n do
    local k = math.random(#a)
    t[i] = a:sub(k, k)
  end
  return table.concat(t)
end
local function path_sep()
  return package.config:sub(1, 1)
end
local function normalize_path(p)
  local abs = vim.fn.fnamemodify(p, ':p')
  if path_sep() == '\\' then
    abs = abs:gsub('\\', '/')
  end
  return abs:gsub('/+$', '')
end
local function join(...)
  return normalize_path(table.concat({ ... }, path_sep()))
end
local function dirname(p)
  return vim.fn.fnamemodify(p, ':h')
end
local function basename(p)
  return vim.fn.fnamemodify(p, ':t')
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
  p = (p or ''):gsub('\\', '/'):gsub('/+', '/')
  local t = {}
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

local function find_notebook_root(abs_path)
  local ok, util = pcall(require, 'zk.util')
  if ok and util and util.notebook_root then
    local root = util.notebook_root(abs_path)
    if root and root ~= '' then
      return root
    end
  end
  if vim.env.ZK_NOTEBOOK_DIR and vim.fn.isdirectory(vim.env.ZK_NOTEBOOK_DIR) == 1 then
    return vim.env.ZK_NOTEBOOK_DIR
  end
  local dir = vim.fn.fnamemodify(abs_path, ':p:h')
  while dir and dir ~= path_sep() do
    if vim.fn.isdirectory(join(dir, '.zk')) == 1 then
      return dir
    end
    dir = dirname(dir)
  end
  return nil
end

local function get_first_h1_title(path)
  local ok, lines = pcall(vim.fn.readfile, path, '', 80)
  if not ok or not lines then
    return nil
  end
  for _, l in ipairs(lines) do
    local t = l:match '^#%s+(.+)'
    if t then
      return trim(t)
    end
  end
  return nil
end

-- ==================== COROUTINE "AWAIT" =======================
local function co_run(fn)
  local co = coroutine.create(fn)
  local dead = false
  local function step(...)
    if dead then
      return
    end
    local ok, yielded = coroutine.resume(co, ...)
    if not ok then
      dead = true
      return vim.schedule(function()
        error(yielded)
      end)
    end
    if coroutine.status(co) == 'dead' then
      dead = true
      return
    end
    local thunk = yielded
    if type(thunk) ~= 'function' then
      dead = true
      return
    end
    thunk(step)
  end
  step()
end

local function await_input(prompt, def)
  return coroutine.yield(function(cont)
    local done = false
    local function once(v)
      if done then
        return
      end
      done = true
      cont(v or '')
    end
    if vim.ui and vim.ui.input then
      vim.ui.input({ prompt = prompt, default = def or '' }, once)
    else
      once(vim.fn.input(prompt, def or ''))
    end
  end)
end

local function await_select(items, opts)
  return coroutine.yield(function(cont)
    local once = false
    local function done(v)
      if once then
        return
      end
      once = true
      cont(v)
    end
    local used = false
    if M.cfg.telescope_templates then
      local ok, pickers = pcall(require, 'telescope.pickers')
      if ok then
        used = true
        local finders = require 'telescope.finders'
        local conf = require('telescope.config').values
        local actions = require 'telescope.actions'
        local action_state = require 'telescope.actions.state'
        pickers
          .new({}, {
            prompt_title = (opts and opts.prompt) or 'Select',
            finder = finders.new_table { results = items },
            sorter = conf.generic_sorter {},
            previewer = conf.file_previewer {},
            attach_mappings = function(pb, _)
              actions.select_default:replace(function()
                local e = action_state.get_selected_entry()
                actions.close(pb)
                done(e and (e[1] or e.value or e))
              end)
              return true
            end,
          })
          :find()
      end
    end
    if not used then
      if vim.ui and vim.ui.select then
        vim.ui.select(items, opts or {}, done)
      else
        done(items[1])
      end
    end
  end)
end

local function await_confirm(msg)
  return coroutine.yield(function(c)
    c(vim.fn.confirm(msg, '&Yes\n&No', 1) == 1)
  end)
end

-- ================== WIKILINK PARSING =========================
local function wikilink_at_cursor(buf)
  buf = buf or 0
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ''
  for s, inner, e in line:gmatch '()%[%[([^%]]-)%]%]()' do
    if col + 1 >= s and col + 1 <= e then
      local tgt, alias = inner:match '^(.-)|(.+)$'
      return { target = trim(tgt or inner), alias = alias and trim(alias) or nil }
    end
  end
  return nil
end
local function split_anchor(t)
  local p, a = t:match '^(.-)#(.+)$'
  return p or t, a
end
local function should_ignore_target(t)
  return (not t or t == '' or t:match '^%a+://')
end

local function resolve_dir_and_basename(root, here_dir, target)
  local composed = normalize_path(join(here_dir, target))
  local has_ext = composed:lower():sub(-3) == '.md'
  local base = has_ext and stem(basename(composed)) or basename(composed)
  local dir = dirname(composed)
  local root_abs = normalize_path(root)
  if dir:sub(1, #root_abs) ~= root_abs then
    dir = root_abs
  end
  return dir, base, has_ext
end

local function find_existing(root, here_dir, target_no_anchor)
  local dir, base = resolve_dir_and_basename(root, here_dir, target_no_anchor)
  local matches = {}
  local exact = normalize_path(join(dir, base .. '.md'))
  if vim.fn.filereadable(exact) == 1 then
    matches[#matches + 1] = exact
  end
  if #matches == 0 then
    local slug = slugify(base)
    local function add(d)
      if vim.fn.isdirectory(d) == 0 then
        return
      end
      for _, p in ipairs(vim.fn.globpath(d, '**/*-' .. slug .. '.md', false, true)) do
        matches[#matches + 1] = p
      end
      for _, p in ipairs(vim.fn.globpath(d, '**/' .. slug .. '.md', false, true)) do
        matches[#matches + 1] = p
      end
    end
    add(dir)
    if #matches == 0 then
      add(root)
    end
  end
  local seen, uniq = {}, {}
  for _, p in ipairs(matches) do
    if not seen[p] then
      uniq[#uniq + 1] = p
      seen[p] = true
    end
  end
  return uniq
end

-- ================== FRONTMATTER / TAGS ========================
local function parse_frontmatter(lines)
  local fm = nil
  if lines[1] and lines[1]:match '^%-%-%-$' then
    for i = 2, #lines do
      if lines[i]:match '^%-%-%-$' then
        fm = table.concat({ unpack(lines, 1, i) }, '\n')
        break
      end
    end
  end
  local tags, aliases = {}, {}
  if fm then
    for line in fm:gmatch '[^\n]+' do
      local key, val = line:match '^([%w_%-]+):%s*(.+)$'
      if key and val then
        if key == 'tags' then
          local list = val:gsub('[%[%]]', '')
          for t in list:gmatch '[^,%s]+' do
            tags[#tags + 1] = t
          end
        elseif key == 'aliases' then
          local list = val:gsub('[%[%]]', '')
          for a in list:gmatch '[^,%s].-[^,%s]*' do
            aliases[#aliases + 1] = a
          end
        end
      end
    end
  end
  return { yaml = fm, tags = tags, aliases = aliases }
end

local function show_tags_virttext(buf)
  if not M.cfg.virt_tags.enabled then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, M._ns_tags, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(200, vim.api.nvim_buf_line_count(buf)), false)
  if not lines[1] or not lines[1]:match '^%-%-%-$' then
    return
  end
  local close_i = nil
  for i = 2, #lines do
    if lines[i]:match '^%-%-%-$' then
      close_i = i - 1
      break
    end
  end
  if not close_i then
    return
  end
  local fm = parse_frontmatter(lines)
  if fm.tags and #fm.tags > 0 then
    local virt = { { 'tags: ', M.cfg.virt_tags.hl }, { table.concat(fm.tags, ', '), M.cfg.virt_tags.hl } }
    vim.api.nvim_buf_set_extmark(buf, M._ns_tags, close_i, 0, { virt_text = virt, virt_text_pos = 'eol' })
  end
end

local function fold_frontmatter(buf)
  if not M.cfg.folds.frontmatter then
    return
  end
  local n = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(300, n), false)
  if not lines[1] or not lines[1]:match '^%-%-%-$' then
    return
  end
  local close_line = nil
  for i = 2, #lines do
    if lines[i]:match '^%-%-%-$' then
      close_line = i
      break
    end
  end
  if not close_line then
    return
  end
  vim.schedule(function()
    if not vim.api.nvim_buf_is_loaded(buf) then
      return
    end
    pcall(vim.api.nvim_buf_call, buf, function()
      vim.opt_local.foldmethod = 'manual'
      vim.cmd(string.format('silent! %d,%dfold', 1, close_line))
      vim.cmd 'silent! normal! zM'
    end)
  end)
end

local function fold_links_section(buf)
  if not M.cfg.folds.links then
    return
  end
  local n = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, n, false)
  local s = nil
  for i = 1, n do
    if lines[i]:match('^##%s+' .. vim.pesc(M.cfg.backlinks.section_header) .. '%s*$') then
      s = i
      break
    end
  end
  if not s then
    return
  end
  vim.schedule(function()
    if not vim.api.nvim_buf_is_loaded(buf) then
      return
    end
    pcall(vim.api.nvim_buf_call, buf, function()
      vim.opt_local.foldmethod = 'manual'
      vim.cmd(string.format('silent! %d,%dfold', s, n))
      vim.cmd 'silent! normal! zM'
    end)
  end)
end

-- ================== BACKLINKS / RELATED =======================
local function insert_backlinks_section(new_buf, new_dir, src_path, tag_related)
  if not M.cfg.backlinks.enabled then
    return
  end
  local src_title = get_first_h1_title(src_path) or stem(src_path)
  local wiki_rel = rel_wiki_path(new_dir, src_path)

  local tail = vim.api.nvim_buf_line_count(new_buf)
  local lastline = vim.api.nvim_buf_get_lines(new_buf, tail - 1, tail, false)[1] or ''
  if lastline:match '%S' then
    vim.api.nvim_buf_set_lines(new_buf, tail, tail, false, { '' })
  end

  local lines = {
    '## ' .. M.cfg.backlinks.section_header,
    '',
    '### ' .. M.cfg.backlinks.subsection_backlinks,
    ('[[%s|%s]]'):format(wiki_rel, src_title),
  }

  if tag_related and tag_related.list and #tag_related.list > 0 then
    lines[#lines + 1] = ''
    lines[#lines + 1] = '### Related (shares tags)'
    for _, rel in ipairs(tag_related.list) do
      lines[#lines + 1] = ('[[%s|%s]]'):format(rel.wiki, rel.title)
    end
  end

  vim.api.nvim_buf_set_lines(new_buf, -1, -1, false, { '' })
  vim.api.nvim_buf_set_lines(new_buf, -1, -1, false, lines)
  -- NOTE: fold is now applied by the caller AFTER all inserts are done.
end

local function scan_related_by_tags(root, here_path, tags)
  if not tags or #tags == 0 then
    return { list = {} }
  end
  local out, glob = {}, vim.fn.globpath(root, '**/*.md', false, true)
  local here = normalize_path(here_path)
  for _, f in ipairs(glob) do
    local abs = normalize_path(f)
    if abs ~= here then
      local lines = vim.fn.readfile(abs, '', 120)
      if lines and lines[1] == '---' then
        local fm = parse_frontmatter(lines)
        if fm.tags and #fm.tags > 0 then
          local shared = 0
          for _, t in ipairs(fm.tags) do
            for _, mine in ipairs(tags) do
              if t == mine then
                shared = shared + 1
                break
              end
            end
          end
          if shared > 0 then
            out[#out + 1] = { path = abs, wiki = rel_wiki_path(dirname(here), abs), title = get_first_h1_title(abs) or stem(abs), shared = shared }
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.shared == b.shared then
      return a.title < b.title
    end
    return a.shared > b.shared
  end)
  return { list = out }
end

-- ============== TEMPLATES / NEW NOTE CONTENT ==================
local function render_template(lines, meta)
  local s = table.concat(lines, '\n')
  local rep = {
    ['{{title}}'] = meta.title or '',
    ['{{date}}'] = os.date(meta.date_fmt or '!%Y-%m-%d'),
    ['{{id}}'] = meta.id or '',
    ['{{content}}'] = meta.content or '',
    ['{{tags}}'] = (meta.tags and #meta.tags > 0) and table.concat(meta.tags, ', ') or '',
  }
  for k, v in pairs(rep) do
    s = s:gsub(k, v)
  end
  s = s:gsub('%s*$', '')
  return vim.split(s, '\n', { plain = true })
end

local function list_templates(root)
  local out, seen = {}, {}
  local function add_dir(dir)
    if vim.fn.isdirectory(dir) == 0 then
      return
    end
    for _, f in ipairs(vim.fn.globpath(dir, '*.md', false, true)) do
      local name = stem(f)
      if not seen[name] then
        out[#out + 1] = name
        seen[name] = true
      end
    end
    for _, f in ipairs(vim.fn.globpath(dir, '*/*.md', false, true)) do
      local rel = f:sub(#dir + 2):gsub('%.md$', '')
      if not seen[rel] then
        out[#out + 1] = rel
        seen[rel] = true
      end
    end
  end
  add_dir(vim.fn.expand '~/.config/.zk/templates')
  if root then
    add_dir(join(root, '.zk', 'templates'))
  end
  table.sort(out)
  return out
end

-- ---------- FIX: robust writer (YAML footer, spacing, H1 de-dup) ----------
local function write_new_note_at(path, title, parent_src_path, tags, template)
  ensure_dir(dirname(path))
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()

  local id = M.cfg.id_prefix and random_id(M.cfg.id_length) or ''
  local lines = {}

  -- YAML frontmatter (open)
  lines[#lines + 1] = '---'
  lines[#lines + 1] = ('title: %s'):format(title)
  lines[#lines + 1] = ('date: %s'):format(os.date '!%Y-%m-%d')
  lines[#lines + 1] = ('tags: [%s]'):format(tags and table.concat(tags, ', ') or '')
  lines[#lines + 1] = 'aliases: []'
  if id ~= '' then
    lines[#lines + 1] = ('id: %s'):format(id)
  end
  -- YAML frontmatter (close) + one blank line
  lines[#lines + 1] = '---'
  lines[#lines + 1] = ''

  -- Our canonical H1 (linked to parent if any)
  if parent_src_path and parent_src_path ~= '' then
    local wiki_rel = rel_wiki_path(dirname(path), parent_src_path)
    lines[#lines + 1] = ('# [[%s|%s]]'):format(wiki_rel, title)
  else
    lines[#lines + 1] = ('# %s'):format(title)
  end
  lines[#lines + 1] = '' -- blank line after H1

  -- Optional template
  if template and template ~= '' then
    local roots = { vim.fn.expand '~/.config/.zk/templates', join(find_notebook_root(path) or '', '.zk', 'templates') }
    for _, root in ipairs(roots) do
      local full = join(root, template .. '.md')
      if vim.fn.filereadable(full) == 1 then
        local tlines = render_template(vim.fn.readfile(full), { title = title, id = id, tags = tags })
        -- If template's first non-empty line duplicates H1 ('# Title' or '# [[..|Title]]'), drop it.
        local first_idx = nil
        for i, l in ipairs(tlines) do
          if trim(l) ~= '' then
            first_idx = i
            break
          end
        end
        if first_idx then
          local first = tlines[first_idx]
          local dup_plain = first:match('^#%s+' .. vim.pesc(title) .. '%s*$')
          local dup_link = first:match('^#%s+%[%[[^%]]-%|' .. vim.pesc(title) .. '%]%]%s*$')
          if dup_plain or dup_link then
            table.remove(tlines, first_idx)
          end
        end
        for _, L in ipairs(tlines) do
          lines[#lines + 1] = L
        end
        break
      end
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Fold FM & show tags after buffer has content
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if M.cfg.folds.frontmatter then
      fold_frontmatter(buf)
    end
    if M.cfg.virt_tags.enabled then
      show_tags_virttext(buf)
    end
  end)

  return buf
end

local function log_created(path, title)
  if not M.cfg.log_file then
    return
  end
  local line = os.date '!%Y-%m-%dT%H:%M:%SZ' .. '\t' .. (title or '') .. '\t' .. path .. '\n'
  pcall(vim.fn.writefile, { line }, M.cfg.log_file, 'a')
end

-- ===================== HISTORY ================================
local function _push_history(path)
  if not path or path == '' then
    return
  end
  table.insert(M._history, 1, { path = path, ts = os.time() })
  if #M._history > 200 then
    table.remove(M._history)
  end
end

-- ===================== OPEN / FOLLOW ==========================
local function open_file(path, opts)
  if not path or path == '' then
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  _push_history(path)

  local target_header = true
  if opts and opts.anchor then
    vim.schedule(function()
      vim.fn.search('\\c^\\s*#\\+\\s*' .. vim.pesc(opts.anchor), 'w')
    end)
    target_header = false
  end

  if target_header then
    vim.schedule(function()
      local line = vim.fn.search('^#\\s\\+', 'w')
      if line > 0 then
        vim.api.nvim_win_set_cursor(0, { line, 2 })
      end
      if opts and opts.follow_mode == 'jump_to_last_search' then
        local last = vim.fn.getreg '/'
        if last and last ~= '' then
          vim.cmd 'normal! n'
        end
      end
    end)
  end
end

-- ===================== CREATE FLOW ============================
local function list_note_tags(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(200, vim.api.nvim_buf_line_count(buf)), false)
  local fm = parse_frontmatter(lines)
  return fm.tags
end

local function create_note_flow(root, here_dir, target_no_anchor, display_title, opts)
  opts = opts or {}
  local mode = M.cfg.filename_mode
  local dir, base = resolve_dir_and_basename(root, here_dir, target_no_anchor)
  local title = display_title or base

  co_run(function()
    local chosen_title, tags_line, template = title, '', ''
    if not opts.instant then
      local input = await_input('Title: ', chosen_title)
      if input ~= '' then
        chosen_title = input
      end
      tags_line = await_input('Tags (comma separated): ', '')
      local templates = list_templates(root)
      if #templates > 0 then
        template = await_select(templates, { prompt = 'Template (Enter to skip):' }) or ''
      end
      if not await_confirm(("Create note '%s' in %s?"):format(chosen_title, dir)) then
        return
      end
    end

    local tags = {}
    for t in (tags_line or ''):gmatch '[^,]+' do
      t = trim(t)
      if t ~= '' then
        tags[#tags + 1] = t
      end
    end
    if #tags == 0 then
      tags = nil
    end
    local fname
    if mode == 'typed' then
      fname = base .. '.md'
    elseif mode == 'slug' then
      fname = slugify(chosen_title)
      if M.cfg.id_prefix then
        fname = random_id(M.cfg.id_length) .. '-' .. fname
      end
      fname = fname .. '.md'
    else
      fname = base .. '.md'
    end

    local final_path = normalize_path(join(dir, fname))
    local src_path = vim.api.nvim_buf_get_name(0)

    local buf = write_new_note_at(final_path, chosen_title, src_path, tags, (template ~= '' and template or nil))

    -- Now compute related and insert full Links block, then fold
    local related = scan_related_by_tags(root, final_path, tags)
    insert_backlinks_section(buf, dirname(final_path), src_path, related)
    if M.cfg.autosave_created then
      pcall(vim.cmd, 'silent noautocmd write')
    end
    fold_links_section(buf)

    _push_history(final_path)
    log_created(final_path, chosen_title)
    vim.notify(('Created: %s  (%s)'):format(chosen_title, final_path))
  end)
end

-- ===================== PUBLIC FLOWS ===========================
function M.follow_or_create(opts)
  local here = vim.fn.expand '%:p'
  local root = find_notebook_root(here)
  if not root then
    return vim.notify('ZK: notebook root not found.', vim.log.levels.ERROR)
  end
  local w = wikilink_at_cursor()
  if not w or should_ignore_target(w.target) then
    return
  end

  local path_part, anchor = split_anchor(w.target)
  local here_dir = dirname(here)
  local target_no_ext = path_part:gsub('%.md$', '')
  local found = find_existing(root, here_dir, target_no_ext)

  if #found >= 1 then
    if #found == 1 then
      return open_file(found[1], { anchor = anchor, follow_mode = (opts and opts.follow_mode) })
    end
    local items = {}
    for _, p in ipairs(found) do
      items[#items + 1] = relpath(root, p)
    end
    return co_run(function()
      local pick = await_select(items, { prompt = 'Open note:' })
      if pick then
        open_file(join(root, type(pick) == 'string' and pick or pick.label), { anchor = anchor, follow_mode = (opts and opts.follow_mode) })
      end
    end)
  elseif anchor then
    return vim.notify("Won't create anchor-only: file not found for [[" .. path_part .. '#' .. anchor .. ']]', vim.log.levels.WARN)
  else
    local default_title = w.alias or stem(path_part:match '([^/]+)$' or path_part):gsub('_', ' '):gsub('-', ' ')
    return create_note_flow(root, here_dir, target_no_ext, default_title, opts or {})
  end
end

function M.instant_create()
  return M.follow_or_create { instant = true }
end
function M.follow_only()
  return M.follow_or_create { follow_mode = 'file' }
end
function M.follow_jump_to_last_searched()
  return M.follow_or_create { follow_mode = 'jump_to_last_search' }
end

-- ===================== LINK UTILITIES (unchanged from last) =================
local function all_wikilinks_in_buffer(buf)
  buf = buf or 0
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local out = {}
  for i, l in ipairs(lines) do
    for inner in l:gmatch '%[%[([^%]]-)%]%]' do
      local tgt, alias = inner:match '^(.-)|(.+)$'
      out[#out + 1] = { line = i, col = (l:find('%[%[' .. vim.pesc(inner) .. '%]%]') or 1) - 1, target = trim(tgt or inner), alias = alias }
    end
  end
  return out
end

function M.links_picker()
  local links = all_wikilinks_in_buffer(0)
  if #links == 0 then
    return vim.notify 'No wikilinks in buffer'
  end
  local items = {}
  for _, L in ipairs(links) do
    items[#items + 1] = string.format('%4d:%-3d  %s', L.line, L.col, L.alias and (L.alias .. ' -> ' .. L.target) or L.target)
  end
  co_run(function()
    local pick = await_select(items, { prompt = 'Wikilinks:' })
    if not pick then
      return
    end
    local ln, cn = pick:match '^%s*(%d+):(%d+)'
    if ln then
      vim.api.nvim_win_set_cursor(0, { tonumber(ln), tonumber(cn) })
    end
  end)
end

function M.links_by_tag_picker()
  local here = vim.fn.expand '%:p'
  local root = find_notebook_root(here)
  if not root then
    return vim.notify('ZK: notebook root not found.', vim.log.levels.ERROR)
  end
  local links = all_wikilinks_in_buffer(0)
  if #links == 0 then
    return vim.notify 'No wikilinks in buffer'
  end
  local tag_set, link_meta = {}, {}
  local here_dir = dirname(here)
  for _, L in ipairs(links) do
    local target_no_ext = (L.target:gsub('%.md$', ''))
    local found = find_existing(root, here_dir, target_no_ext)
    if found[1] then
      local fm = parse_frontmatter(vim.fn.readfile(found[1], '', 120))
      link_meta[#link_meta + 1] = { link = L, tags = fm.tags or {} }
      for _, t in ipairs(fm.tags or {}) do
        tag_set[t] = true
      end
    end
  end
  local tags = {}
  for t, _ in pairs(tag_set) do
    tags[#tags + 1] = t
  end
  table.sort(tags)
  if #tags == 0 then
    return vim.notify 'No tags found on linked notes'
  end
  co_run(function()
    local pick = await_select(tags, { prompt = 'Filter by tag:' })
    if not pick then
      return
    end
    local t = pick
    local row = vim.api.nvim_win_get_cursor(0)[1]
    for _, Lm in ipairs(link_meta) do
      if vim.tbl_contains(Lm.tags, t) and Lm.link.line >= row then
        vim.api.nvim_win_set_cursor(0, { Lm.link.line, Lm.link.col })
        return
      end
    end
    for _, Lm in ipairs(link_meta) do
      if vim.tbl_contains(Lm.tags, t) then
        vim.api.nvim_win_set_cursor(0, { Lm.link.line, Lm.link.col })
        return
      end
    end
  end)
end

-- ===================== PREVIEWS (same behavior as last) ====================
local function notifications_present()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= '' then
      local b = vim.api.nvim_win_get_buf(w)
      local ft = vim.bo[b].filetype
      if ft == 'notify' or ft == 'noice' then
        return true
      end
    end
  end
  return false
end

local function preview_positions(layout, count, width_frac, height, gap)
  local cols = vim.o.columns
  local lines = vim.o.lines - (vim.o.cmdheight or 1)
  local w = math.max(20, math.floor(cols * width_frac))
  local h = math.min(height, lines - 2)
  local pos = {}
  if layout == 'topleft' then
    local row, col = 1, 2
    for i = 1, count do
      pos[i] = { row = row, col = col, width = w, height = h }
      row = row + h + gap
    end
  else
    local col = cols - w - 2
    local row = lines - h - 1
    for i = 1, count do
      pos[i] = { row = row, col = col, width = w, height = h }
      row = row - (h + gap)
    end
  end
  return pos
end

local function ensure_preview_for_path(path)
  local it = M._previews.items[path]
  if it and vim.api.nvim_buf_is_valid(it.buf) and (it.win and vim.api.nvim_win_is_valid(it.win)) then
    return it
  end
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = (vim.bo[buf].filetype ~= '' and vim.bo[buf].filetype) or 'markdown'
  local rec = { buf = buf, win = nil, pinned = false, centered = false }
  M._previews.items[path] = rec
  table.insert(M._previews.order, 1, path)
  return rec
end

local function open_preview_window(rec, cfg)
  if rec.win and vim.api.nvim_win_is_valid(rec.win) then
    return rec.win
  end
  local opts =
    { relative = 'editor', style = 'minimal', border = M.cfg.preview.border, width = cfg.width, height = cfg.height, row = cfg.row, col = cfg.col, noautocmd = true }
  rec.win = vim.api.nvim_open_win(rec.buf, false, opts)
  vim.wo[rec.win].wrap = true
  vim.wo[rec.win].cursorline = false
  vim.wo[rec.win].signcolumn = 'no'
  vim.keymap.set('n', 'q', function()
    if rec.pinned then
      vim.api.nvim_win_hide(rec.win)
    else
      vim.api.nvim_win_close(rec.win, true)
      rec.win = nil
    end
  end, { buffer = rec.buf, nowait = true, silent = true })
  return rec.win
end

local function apply_layout()
  if M._previews.hidden then
    return
  end
  local layout = (notifications_present() and 'bottomright') or M.cfg.preview.layout
  local paths = {}
  for _, p in ipairs(M._previews.order) do
    local r = M._previews.items[p]
    if r and (r.pinned or (r.win and vim.api.nvim_win_is_valid(r.win))) then
      paths[#paths + 1] = p
    end
  end
  if #paths == 0 then
    return
  end
  local slots = preview_positions(layout, #paths, M.cfg.preview.width, M.cfg.preview.height, M.cfg.preview.stack_gap)
  for i, p in ipairs(paths) do
    local r = M._previews.items[p]
    local s = slots[i]
    open_preview_window(r, s)
    vim.api.nvim_win_set_config(r.win, vim.tbl_extend('keep', { relative = 'editor', style = 'minimal', border = M.cfg.preview.border }, s))
  end
end

local function preview_for_link_under_cursor()
  if not M.cfg.preview.auto then
    return
  end
  local here = vim.fn.expand '%:p'
  local root = find_notebook_root(here)
  if not root then
    return
  end
  local here_dir = dirname(here)
  local w = wikilink_at_cursor()
  if not w or should_ignore_target(w.target) then
    return
  end
  local path_part = (w.target:gsub('%.md$', ''))
  local found = find_existing(root, here_dir, path_part)
  if not found[1] then
    return
  end
  local rec = ensure_preview_for_path(found[1])
  open_preview_window(rec, preview_positions(M.cfg.preview.layout, 1, M.cfg.preview.width, M.cfg.preview.height, M.cfg.preview.stack_gap)[1])
  apply_layout()
end

function M.toggle_preview_auto()
  M.cfg.preview.auto = not M.cfg.preview.auto
  vim.notify('ZK Preview auto-peek: ' .. (M.cfg.preview.auto and 'ON' or 'OFF'))
end
function M.toggle_preview_layout()
  M.cfg.preview.layout = (M.cfg.preview.layout == 'topleft') and 'bottomright' or 'topleft'
  apply_layout()
end
function M.toggle_preview_center_active()
  M.cfg.preview.center_active = not M.cfg.preview.center_active
  vim.notify('ZK Preview center-active: ' .. (M.cfg.preview.center_active and 'ON' or 'OFF'))
end
function M.toggle_preview_hide_show()
  M._previews.hidden = not M._previews.hidden
  if M._previews.hidden then
    for _, rec in pairs(M._previews.items) do
      if rec.win and vim.api.nvim_win_is_valid(rec.win) then
        vim.api.nvim_win_hide(rec.win)
      end
    end
  else
    apply_layout()
  end
end
function M.pin_current_preview()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  for _, rec in pairs(M._previews.items) do
    if rec.buf == buf and win == rec.win then
      rec.pinned = not rec.pinned
      vim.notify('ZK Preview pin: ' .. (rec.pinned and 'ON' or 'OFF'))
      apply_layout()
      return
    end
  end
  vim.notify 'Not in a ZK preview window'
end
vim.api.nvim_create_autocmd('WinEnter', {
  callback = function()
    if not M.cfg.preview.center_active then
      return
    end
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    for _, rec in pairs(M._previews.items) do
      if rec.buf == buf and win == rec.win then
        local cols = vim.o.columns
        local lines = vim.o.lines - (vim.o.cmdheight or 1)
        local w = math.floor(cols * math.min(0.7, M.cfg.preview.width + 0.15))
        local h = math.min(lines - 4, M.cfg.preview.height + 4)
        vim.api.nvim_win_set_config(
          rec.win,
          { relative = 'editor', style = 'minimal', border = M.cfg.preview.border, width = w, height = h, row = math.floor((lines - h) / 2), col = math.floor(
            (cols - w) / 2
          ) }
        )
        rec.centered = true
        return
      end
    end
  end,
})
vim.api.nvim_create_autocmd('WinLeave', {
  callback = function()
    local changed = false
    for _, rec in pairs(M._previews.items) do
      if rec.centered then
        rec.centered = false
        changed = true
      end
    end
    if changed then
      apply_layout()
    end
  end,
})

-- ===================== HISTORY PICKER (unchanged) =============
function M.history_picker()
  if #M._history == 0 then
    return vim.notify 'ZK history is empty'
  end
  local items = {}
  for _, it in ipairs(M._history) do
    items[#items + 1] = { display = os.date('%Y-%m-%d %H:%M', it.ts) .. '  ' .. it.path, path = it.path }
  end
  co_run(function()
    local pick = await_select(items, { prompt = 'Recent ZK jumps:' })
    local path = nil
    if type(pick) == 'table' then
      path = pick.path or pick.value or pick[1]
    elseif type(pick) == 'string' then
      local s = pick:match '%d%d:%d%d%s%s(.*)$'
      path = s or pick
    end
    if path and path ~= '' then
      open_file(path)
    end
  end)
end

-- ===================== UPDATE RELATED (fold after) ============
function M.update_links_section()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  if path == '' then
    return
  end
  local root = find_notebook_root(path)
  if not root then
    return
  end
  local tags = list_note_tags(buf)

  local n = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, n, false)
  local links_s = nil
  for i = 1, n do
    if lines[i]:match('^##%s+' .. vim.pesc(M.cfg.backlinks.section_header) .. '%s*$') then
      links_s = i
      break
    end
  end
  if not links_s then
    return
  end
  local related_hdr = nil
  for i = links_s + 1, n do
    if lines[i]:match '^###%s+Related%s*%(' then
      related_hdr = i
      break
    end
  end
  if related_hdr then
    local end_at = n
    for i = related_hdr + 1, n do
      if lines[i]:match '^###%s+' or lines[i]:match '^##%s+' then
        end_at = i - 1
        break
      end
    end
    vim.api.nvim_buf_set_lines(buf, related_hdr, end_at, false, {})
  end

  local related = scan_related_by_tags(root, path, tags)
  if related and #related.list > 0 then
    local insert_at = n
    for i = n, 1, -1 do
      if lines[i]:match('^##%s+' .. vim.pesc(M.cfg.backlinks.section_header) .. '%s*$') then
        insert_at = i
        break
      end
    end
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, { '', '### Related (shares tags)' })
    for _, rel in ipairs(related.list) do
      vim.api.nvim_buf_set_lines(buf, insert_at + 1, insert_at + 1, false, { ('[[%s|%s]]'):format(rel.wiki, rel.title) })
    end
  end
  fold_links_section(buf)
end

-- ===================== MAPPINGS / SETUP =======================
local function on_enter_expr()
  local w = wikilink_at_cursor()
  if w then
    vim.schedule(function()
      M.follow_or_create()
    end)
    return ''
  end
  return '\r'
end
local function register_which_key()
  local ok, wk = pcall(require, 'which-key')
  if ok then
    wk.add { { '<leader>z', group = 'ZK' } }
  end
end

-- blink.cmp provider (unchanged)
local function inside_wikilink_ctx(line, col)
  local left = line:sub(1, col)
  local open = left:match '()%[%[[^%]]*$'
  if not open then
    return nil
  end
  return left:sub(open + 1):gsub('^%s+', ''):gsub('|.*$', '')
end
local function list_rel_candidates(root, here_dir, prefix)
  local dir = select(1, resolve_dir_and_basename(root, here_dir, prefix))
  local base_dir = normalize_path(dir)
  local results = {}
  local function emit(p, is_dir)
    local rel = rel_wiki_path(here_dir, p)
    if is_dir then
      rel = rel .. '/'
    end
    results[#results + 1] = { label = rel, insert_text = rel, kind = is_dir and 19 or 17, detail = is_dir and 'Folder' or 'Note' }
  end
  if vim.fn.isdirectory(base_dir) == 1 then
    for _, d in ipairs(vim.fn.globpath(base_dir, '*/', false, true)) do
      emit(d, true)
    end
    for _, f in ipairs(vim.fn.globpath(base_dir, '*.md', false, true)) do
      emit(f, false)
    end
  end
  return results
end
local ProviderClass = {}
ProviderClass.__index = ProviderClass
function ProviderClass.new()
  return setmetatable({}, ProviderClass)
end
function ProviderClass:is_available(ctx)
  local buf = ctx and ctx.buf or vim.api.nvim_get_current_buf()
  return vim.bo[buf].filetype == 'markdown'
end
function ProviderClass:get_trigger_characters()
  return { '[', '/', '.', '-' }
end
function ProviderClass:get_completions(ctx, cb)
  local buf = (ctx and ctx.buf) or vim.api.nvim_get_current_buf()
  local row, col
  if ctx and ctx.row and ctx.col then
    row, col = ctx.row, ctx.col
  else
    local p = vim.api.nvim_win_get_cursor(0)
    row = p[1] - 1
    col = p[2]
  end
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
  local prefix = inside_wikilink_ctx(line, col)
  if not prefix then
    return cb { is_incomplete = false, items = {} }
  end
  local here = vim.api.nvim_buf_get_name(buf)
  local root = find_notebook_root(here)
  if not root then
    return cb { is_incomplete = false, items = {} }
  end
  local here_dir = dirname(here)
  cb { is_incomplete = false, items = list_rel_candidates(root, here_dir, prefix) }
end
package.loaded['zk_follow_create.completion'] = {
  new = function()
    return ProviderClass.new()
  end,
}

function M.setup(user_cfg)
  if type(user_cfg) == 'table' then
    M.cfg = vim.tbl_deep_extend('force', M.cfg, user_cfg)
  end
  local grp = vim.api.nvim_create_augroup('zk_follow_create', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    group = grp,
    callback = function(args)
      local buf = args.buf
      if M.cfg.map_enter then
        vim.keymap.set(
          'n',
          '<CR>',
          (function()
            return on_enter_expr
          end)(),
          { buffer = buf, expr = true, desc = 'ZK: follow/create [[link]]' }
        )
      end
      if M.cfg.map_namespace then
        vim.keymap.set('n', '<leader>zf', function()
          require('zk_follow_create').follow_or_create()
        end, { buffer = buf, desc = 'ZK: follow/create link' })
        vim.keymap.set('n', '<leader>zF', function()
          require('zk_follow_create').instant_create()
        end, { buffer = buf, desc = 'ZK: instant create' })
        vim.keymap.set('n', '<leader>zo', function()
          require('zk_follow_create').follow_only()
        end, { buffer = buf, desc = 'ZK: open linked note' })
        vim.keymap.set('n', '<leader>zJ', function()
          require('zk_follow_create').follow_jump_to_last_searched()
        end, { buffer = buf, desc = 'ZK: follow + jump to last /' })

        vim.keymap.set('n', '<leader>zh', function()
          require('zk_follow_create').history_picker()
        end, { buffer = buf, desc = 'ZK: history' })
        vim.keymap.set('n', '<leader>zL', function()
          require('zk_follow_create').links_picker()
        end, { buffer = buf, desc = 'ZK: list wikilinks' })
        vim.keymap.set('n', '<leader>zT', function()
          require('zk_follow_create').links_by_tag_picker()
        end, { buffer = buf, desc = 'ZK: next link by tag' })
        vim.keymap.set('n', '<leader>zU', function()
          require('zk_follow_create').update_links_section()
        end, { buffer = buf, desc = 'ZK: update Related links' })

        vim.keymap.set('n', '<leader>zp', function()
          require('zk_follow_create').toggle_preview_auto()
        end, { buffer = buf, desc = 'ZK Preview: auto-peek' })
        vim.keymap.set('n', '<leader>zP', function()
          require('zk_follow_create').pin_current_preview()
        end, { buffer = buf, desc = 'ZK Preview: pin/unpin' })
        vim.keymap.set('n', '<leader>zH', function()
          require('zk_follow_create').toggle_preview_hide_show()
        end, { buffer = buf, desc = 'ZK Preview: hide/show' })
        vim.keymap.set('n', '<leader>zA', function()
          require('zk_follow_create').toggle_preview_layout()
        end, { buffer = buf, desc = 'ZK Preview: toggle layout' })
        vim.keymap.set('n', '<leader>zC', function()
          require('zk_follow_create').toggle_preview_center_active()
        end, { buffer = buf, desc = 'ZK Preview: center-active' })

        vim.keymap.set('n', '<leader>zB', function()
          feedkeys '<C-o>'
        end, { buffer = buf, desc = 'Back (jumplist)' })
        vim.keymap.set('n', '<leader>zFf', function()
          feedkeys '<C-i>'
        end, { buffer = buf, desc = 'Forward (jumplist)' })
      end
    end,
  })

  vim.api.nvim_create_autocmd('CursorHold', {
    group = grp,
    pattern = 'markdown',
    callback = function()
      if M.cfg.preview.auto then
        require 'zk_follow_create'
      end
      preview_for_link_under_cursor()
    end,
  })
  vim.api.nvim_create_autocmd('BufReadPost', {
    group = grp,
    pattern = '*.md',
    callback = function(args)
      if M.cfg.folds.frontmatter then
        fold_frontmatter(args.buf)
      end
      if M.cfg.virt_tags.enabled then
        show_tags_virttext(args.buf)
      end
      if M.cfg.folds.links then
        fold_links_section(args.buf)
      end
    end,
  })
  register_which_key()
end

return M
