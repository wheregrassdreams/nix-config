{ config, lib, ... }:
{
  home.shellAliases = lib.mkMerge [
    {
      ls = "eza";
      cat = "bat";
      grep = "rg";
      json2string = "jq tostring";
    }
    (lib.mkIf (!config.my.terminal.tools.minimal) {
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
