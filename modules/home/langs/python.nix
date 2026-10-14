{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.development;
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
  config = lib.mkIf (cfg.enable && cfg.python.enable) {
    home.packages = with pkgs; [
      (if cfg.python.suite == "full" then data else python)
      uv
      ruff
      pyright
    ];
  };
}
