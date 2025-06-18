return {
  'sphamba/smear-cursor.nvim',
  config = function()
    require('smear_cursor').setup {
      cursor_color = 'none',
      stiffness = 0.5,
      trailing_stiffness = 0.1,
      distance_stop_animating = 0.5,
      time_interval = 8,
      stiffness_insert_mode = 0.2,
      trailing_stiffness_insert_mode = 0.1,
      trailing_exponent_insert_mode = 1,
      max_length = 15,
      -- transparent_bg_fallback_color = "#303030"
      hide_target_hack = true,
      lecacy_computing_symbols_support = false,
    }
  end,
}
