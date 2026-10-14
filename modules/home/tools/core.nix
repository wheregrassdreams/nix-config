{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.tools.core) {
    home.packages = with pkgs; [
      gnumake
      just
      curl
      wget
      p7zip
      unrar
      unzip
      rsync
      lsof
    ];
  };
}
