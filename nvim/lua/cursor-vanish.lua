-- ~/.config/nvim/lua/cursor-vanish.lua  (replace previous file)

local shader = vim.fn.expand '~/.config/ghostty/shaders/cursor/cursor_vanish.glsl'

local function hex2vec3(hex)
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  return string.format('vec3(%.4f, %.4f, %.4f)', r, g, b)
end

local function inject_bg_define()
  local hl_norm = vim.api.nvim_get_hl(0, { name = 'Normal' })
  if not hl_norm.bg then
    return
  end

  local bg_vec = hex2vec3(string.format('%06x', hl_norm.bg))
  local define = ('#define STATIC_BACKGROUND %s'):format(bg_vec)

  local lines = vim.fn.readfile(shader)
  -- Strip any previous injected line(s)
  while #lines > 0 and lines[1]:find '#define STATIC_BACKGROUND' do
    table.remove(lines, 1)
  end
  vim.fn.writefile(vim.tbl_extend('force', { define, '' }, lines), shader)

  -- Ask Ghostty to reload (Meta-R / Win-R is mapped to SIGUSR1 in your cfg)
  vim.fn.system { 'xdotool', 'key', 'Super+R' }
end

vim.api.nvim_create_autocmd('ColorScheme', {
  pattern = '*',
  callback = inject_bg_define,
})

inject_bg_define() -- run once on startup
