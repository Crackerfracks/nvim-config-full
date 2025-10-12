-- ~/.config/nvim/lua/custom/plugins/shader-ls.lua

return {
  'neovim/nvim-lspconfig',
  opts = {
    servers = {
      shader_ls = {},
    },
    setup = {
      shader_ls = function(_, opts)
        local lspconfig = require 'lspconfig'

        -- Register the custom config if it doesn't already exist
        if not lspconfig.configs.shader_ls then
          lspconfig.configs.shader_ls = {
            default_config = {
              cmd = { 'shader-ls', '--stdio' },
              filetypes = { 'glsl', 'hlsl', 'wgsl', 'shaderlab', 'frag' },
              root_dir = lspconfig.util.root_pattern('.git', '.'),
              single_file_support = true,
            },
          }
        end

        lspconfig.shader_ls.setup(opts)
        return true
      end,
    },
  },
}
