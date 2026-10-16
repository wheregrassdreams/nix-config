{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.editor.vscode;
in
{
  config = lib.mkIf (pkgs.stdenv.isDarwin && cfg.enable) {
    my.homebrew.casks = [ "visual-studio-code" ];
  };
}
