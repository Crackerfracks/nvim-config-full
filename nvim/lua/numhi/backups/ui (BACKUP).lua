--DO NOT DELETE LINE - THIS FILE LIVES @ filepath="~/.config/nvim/lua/numhi/ui.lua"
local api = vim.api
local M   = {}

-- floating tooltip ------------------------------------------------------
function M.tooltip(pal, slot, label, note, tags)
  if vim.g.numhi_tooltip and api.nvim_win_is_valid(vim.g.numhi_tooltip) then
    api.nvim_win_close(vim.g.numhi_tooltip, true)
  end
  local buf   = api.nvim_create_buf(false, true)
  local tag_str = tags and #tags > 0 and ("#" .. table.concat(tags, " #")) or ""
  local first  = string.format("%s-%d  %s", pal, slot, label or "")
  local second = (note and "✎" or "") .. (tag_str ~= "" and (" " .. tag_str) or "")
  local lines  = { first, second }
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_add_highlight(buf, -1, string.format("NumHi_%s_%d", pal, slot), 0, 0, -1)
  local win = api.nvim_open_win(buf, false, {
    relative = "cursor",
    row      = 1,
    col      = 0,
    width    = math.max(14, math.max(#first, #second)),
    height   = 2,
    style    = "minimal",
    border   = "rounded",
  })
  vim.g.numhi_tooltip = win
  api.nvim_create_autocmd({"CursorMoved", "InsertEnter", "BufLeave"}, {
    once = true,
    callback = function()
      if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    end,
  })
end

return M

