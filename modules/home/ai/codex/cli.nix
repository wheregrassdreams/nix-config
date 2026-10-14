{ config, lib, inputs, system, ... }:
let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in {
  config = lib.mkIf config.my.ai.codex.cli.enable {
    programs.codex = {
      enable = true;
      package = pkgs-unstable.codex;
    };
  };
}
