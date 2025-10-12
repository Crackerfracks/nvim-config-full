-- ~/.config/nvim/lua/plugins/blink-zk-wikilink.lua
return {
  'saghen/blink.cmp',
  optional = true,
  dependencies = { 'zk-org/zk-nvim' },
  opts = function(_, opts)
    opts.sources = opts.sources or {}
    opts.sources.providers = opts.sources.providers or {}
    opts.sources.per_filetype = opts.sources.per_filetype or {}

    -- Register our provider (module is exposed by zk_follow_create.lua)
    opts.sources.providers.zk_wikilink = {
      name = 'ZK Wikilink',
      module = 'zk_follow_create.completion',
      score_offset = 80,
    }

    local current = opts.sources.per_filetype.markdown or { 'lsp', 'path', 'snippets', 'buffer' }
    local new = { 'zk_wikilink' }
    local seen = { zk_wikilink = true }
    for _, s in ipairs(current) do
      if not seen[s] then
        new[#new + 1] = s
        seen[s] = true
      end
    end
    opts.sources.per_filetype.markdown = new
  end,
}
