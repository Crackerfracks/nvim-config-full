-- 1. Perceptually-uniform colour maths
return {
  'hsluv/hsluv-lua',
  name = 'hsluv', -- lets `require('hsluv')` trigger lazy-load
  lazy = true,
  init = function(plugin) -- ← runs *before* NumHi
    -- repo keeps `hsluv.lua` at the top level, so expose it to Lua:
    local path = plugin.dir .. '/?.lua'
    if not package.path:find(path, 1, true) then
      package.path = package.path .. ';' .. path
    end
  end,
}
