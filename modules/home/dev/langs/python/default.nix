{
  pkgs,
  ...
}:
let
  python = pkgs.python314;
  # Keep optional convenience libraries project-scoped through uv.lock rather
  # than adding their full transitive closures to every Home Manager generation.
  # Restore selectively if a host later has a concrete global use case:
  # data = pkgs.python314.withPackages (
  #   ps: with ps; [
  #     httpx
  #     pdfplumber
  #     openpyxl
  #     polars
  #     pymysql
  #     pypika
  #   ]
  # );
in
{
  programs.zsh.shellAliases = {
    py = "python3";
    python = "python3";
  };
  home.packages = with pkgs; [
    python
    uv
    ruff
    unstable.basedpyright
  ];
}
