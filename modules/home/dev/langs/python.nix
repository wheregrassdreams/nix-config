{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.langs;
  python = pkgs.python313;
  data = pkgs.python313.withPackages (
    ps: with ps; [
      httpx
      pdfplumber
      openpyxl
      polars
      pymysql
      pypika
    ]
  );
in
{
  config = lib.mkIf cfg.python.enable {
    programs.zsh.shellAliases = {
      py = "python3";
      python = "python3";
    };
    home.packages = with pkgs; [
      (if cfg.python.suite == "full" then data else python)
      uv
      ruff
      pyright
    ];
  };
}
