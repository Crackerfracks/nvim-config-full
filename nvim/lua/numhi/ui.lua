--DO NOT DELETE LINE - THIS FILE LIVES @ filepath="~/.config/nvim/lua/numhi/ui.lua"
local api = vim.api
local core = require('numhi.core')
local M = {}

-- floating tooltip ------------------------------------------------------
function M.tooltip(
  pal,
  slot,
  label,
  note,
  tags
)
  if
    vim.g.numhi_tooltip
    and api.nvim_win_is_valid(vim.g.numhi_tooltip)
  then
    api.nvim_win_close(
      vim.g.numhi_tooltip,
      true
    )
  end
  local buf = api.nvim_create_buf(
    false,
    true
  )
  local first = string.format(
    "%s-%d  %s",
    pal,
    slot,
    label
    or ""
  )
  if tags
    and #tags > 0
  then
    first = first .. "  #" .. table.concat(
      tags,
      " #"
  )
  end
  local lines = {
    first
  }
  if note
    and note ~= ''
  then
    lines[#lines + 1] = "✎ " .. note:gsub(
      "\n.*",
      " …"
    )
  end
  api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    lines
  )

  -- colour first line to match highlight
  local hl = core.ensure_hl(
    pal,
    slot
  )
  api.nvim_buf_add_highlight(
    buf,
    0,
    hl,
    0,
    0,
    -1
  )

  local width = 0
  for _, l in ipairs(lines)
    do width = math.max(
      width,
      #l
    )
  end
  local win = api.nvim_open_win(
    buf,
    false,
    {
      relative = 'cursor',
      row = 1,
      col = 0,
      width = width + 2,
      height = #lines,
      style = 'minimal',
      border = 'rounded',
    }
  )
  vim.g.numhi_tooltip = win

  local aug = api.nvim_create_augroup(
    'NumHiTooltip',
    {
      clear = true
    }
  )
  api.nvim_create_autocmd(
    {
      'CursorMoved',
      'CursorMovedI',
      'BufLeave',
      'WinScrolled'
    },
    {
    group = aug,
    once = true,
    callback = function()
      if
          api.nvim_win_is_valid(win)
        then
          api.nvim_win_close(
            win,
            true
          )
        end
    end,
  })
end

return M
