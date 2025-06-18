return {
  'OXY2DEV/markview.nvim',
  lazy = false,
  config = function()
    require('markview.extras.checkboxes').setup {
      --- Default checkbox state(used when adding checkboxes).
      ---@type string
      default = 'X',

      --- Changes how checkboxes are removed.
      ---@type
      ---| "disable" Disables the checkbox.
      ---| "checkbox" Removes the checkbox.
      ---| "list_item" Removes the list item markers too.
      remove_style = 'disable',

      --- Various checkbox states.
      ---
      --- States are in sets to quickly change between them
      --- when there are a lot of states.
      ---@type string[][]
      states = {
        {
          ' ',
          '/',
          'X',
        },
        {
          '<',
          '>',
        },
        {
          '?',
          '!',
          '*',
        },
        {
          '"',
        },
        {
          'l',
          'b',
          'i',
        },
        {
          'S',
          'I',
        },
        {
          'p',
          'c',
        },
        { 'f', 'k', 'w' },
        {
          'u',
          'd',
        },
      },
    }
  end,
  -- For blink.cmp's completion
  -- source
  dependencies = {
    'saghen/blink.cmp',
  },
}
