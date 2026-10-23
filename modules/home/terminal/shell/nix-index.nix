{ config, lib, ... }:
let
  cfg = config.my.terminal.shell;
in
{
  config = lib.mkIf cfg.integrations.nixIndex.enable {
    # The Zsh package owns the command-not-found UX. Keep nix-index itself as
    # the package database and query tool instead of sourcing its generic
    # handler, whose output is noisy when a lookup returns no usable candidates.
    programs.nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
    programs.nix-index-database.comma.enable = true;
  };
}
