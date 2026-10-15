{
  pkgs,
  ...
}:
{
  programs.codex = {
    enable = true;
    # nixpkgs-unstable currently provides a newer cached Codex than
    # llm-agents, whose source build is expensive on Darwin.
    package = pkgs.unstable.codex;
  };
}
