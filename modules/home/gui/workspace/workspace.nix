{ config, lib, ... }:
{
  config = lib.mkIf config.my.gui.workspace.enable {
    my.homebrew = {
      taps = [
        {
          name = "bendews/tap";
          trusted = true;
        }
        {
          name = "shivammathur/php";
          trusted = true;
        }
      ];
      brews = [
        "mas"
        "terminal-notifier"
        "bendews/tap/apw"
        # "shivammathur/php/php@7.2"
      ];
      casks = [
        "mos"
        # "aerospace"
        "obsidian"
        "raycast"
        "dbeaver-community"
        "lookaway"
        "picgo"
        "postman"
        "the-unarchiver"
        "font-jetbrains-mono-nerd-font"
      ];
    };
  };
}
