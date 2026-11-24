---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      -- AstroCommunity packs append tools to ensure_installed. Keep those
      -- tools available for explicit Mason commands, but do not install them
      -- every time Neovim starts; system packages are managed by Nix.
      opts.run_on_start = false
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = {
      -- Prefer language servers supplied by the Nix profile over Mason caches.
      PATH = "append",
    },
  },
}
