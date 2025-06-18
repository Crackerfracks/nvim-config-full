return {
  'quentingruber/pomodoro.nvim',
  lazy = false, -- needed so the pomodoro can start at launch
  opts = {
    start_at_launch = true,
    work_duration = 30,
    break_duration = 7,
    delay_duration = 3, -- The additionnal work time you get when you delay a break
    long_break_duration = 20,
    breaks_before_long = 4,
  },
}
