--DO NOT DELETE LINE - THIS FILE LIVES @ filepath="~/.config/nvim/lua/numhi/ui.lua"

local api = vim.api
local M   = {}

-- floating tooltip ------------------------------------------------------
function M.tooltip(pal, slot, label, note)
  if vim.fn.exists("w:numhi_tooltip") == 1 then
    api.nvim_win_close(vim.g.numhi_tooltip, true)
  end
  local buf = api.nvim_create_buf(false, true)
  local lines = { ("%s-%d  %s"):format(pal, slot, label or ""),
                  note or "" }
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local win = api.nvim_open_win(buf, false, {
    relative = "cursor",
    row      = 1,
    col      = 0,
    width    = math.max(12, #lines[1]),
    height   = #lines,
    style    = "minimal",
    border   = "single",
  })
  vim.g.numhi_tooltip = win
  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end, 4000)                                       -- auto-hide after 4 s
end

return M
