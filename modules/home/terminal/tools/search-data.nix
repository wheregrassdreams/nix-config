{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.terminal.tools;
in
{
  programs = {
    ripgrep.enable = true;
    jq.enable = true;
    fd = {
      enable = true;
      ignores = [
        ".git/"
        "node_modules/"
        "venv/"
        "site-packages/"
        ".DS_Store"
      ];
    };
  };

  home.packages = lib.optionals (!cfg.minimal) (
    with pkgs;
    [
      yq
      grex
      quicktype
      csvkit
    ]
  );
}
