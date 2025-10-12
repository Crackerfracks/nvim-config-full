return {
  'joshuadanpeterson/typewriter',
  -- dependencies = {
  --   'nvim-treesitter/nvim-treesitter',
  -- },
  config = function()
    require('typewriter').setup {
      -- start_enabled = true,
      always_center = true,
      keep_cursor_position = true,
      enable_horizontal_scroll = false,
      center_cursor_horizontally = false,
    }
  end,
}
