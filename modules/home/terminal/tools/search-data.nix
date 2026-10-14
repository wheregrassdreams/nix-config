{
  config,
  lib,
  pkgs,
  ...
}:
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

  home.packages = lib.optionals (!config.my.terminal.tools.minimal) (
    with pkgs;
    [
      yq
      grex
      quicktype
      csvkit
    ]
  );
}
