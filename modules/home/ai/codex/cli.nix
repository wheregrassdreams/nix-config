{
  inputs,
  pkgs,
  ...
}:
{
  programs.codex = {
    enable = true;
    package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  };
}
