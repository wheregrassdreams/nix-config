---@type LazySpec
return {
  {
    "williamboman/mason.nvim",
    opts = {
      -- Prefer language servers supplied by the Nix profile over Mason caches.
      PATH = "append",
    },
  },
}
