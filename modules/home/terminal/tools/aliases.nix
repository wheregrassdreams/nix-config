{ config, lib, ... }:
let
  cfg = config.my.terminal.tools;
in
{
  home.shellAliases = lib.mkMerge [
    {
      ls = "eza";
      cat = "bat";
      grep = "rg";
      json2string = "jq tostring";
    }
    (lib.mkIf (!cfg.minimal) {
      top = "btop";
      neofetch = "fastfetch";
      ps = "procs";
      du = "dust";
      csv = "csvlens";
      http = "xh";
      https = "xh --https";
      man = "tldr";
      del = "trash";
      cb = "NO_COLOR=1 CLIPBOARD_SLIENT=1 cb ";
      cbcopy = "cb copy";
      cbpaste = "cb paste";
    })
  ];
}
