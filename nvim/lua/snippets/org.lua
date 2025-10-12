local ls = require 'luasnip'
local s = ls.snippet
local i = ls.insert_node
local fmt = require('luasnip.extras.fmt').fmt

return {
  -- trigger word: "cb" -> expands to the four-line block
  s(
    'cb',
    fmt(
      [[#+NAME: {}
#+BEGIN_SRC {}{}{}

#+END_SRC]],
      {
        -- 1st empty `{}`
        i(1, 'TEXT_BLOCK'),

        -- 2nd empty `{}`
        i(2, 'markdown '),

        -- 3rd empty `{}`
        i(3, ' '),

        -- 4th empty `{}`
        i(4),
      }
    )
  ),
}
