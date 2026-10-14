{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.keymap.karabiner;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew = lib.mkIf pkgs.stdenv.isDarwin {
      taps = [
        {
          name = "daipeihust/tap";
          trusted = true;
        }
      ];
      brews = [ "daipeihust/tap/im-select" ];
      casks = [ "karabiner-elements" ];
    };
    home.packages = [ pkgs.goku ];
    xdg.configFile."karabiner.edn" = {
      source = ./karabiner/config/karabiner.edn;
      onChange = "${pkgs.goku}/bin/goku";
    };
  };
}
