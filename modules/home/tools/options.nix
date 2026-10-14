{ lib, ... }:
{
  options.my.tools = {
    core = lib.mkEnableOption "core CLI tools";
    direnv = lib.mkEnableOption "project environment loading with direnv";
    query = lib.mkEnableOption "search and structured data tools";
    network = lib.mkEnableOption "network and remote access tools";
    workflow = lib.mkEnableOption "command-line workflow tools";
    interactive = lib.mkEnableOption "interactive tools, including FZF and Yazi";
    television = lib.mkEnableOption "Television interactive search";
    media = lib.mkEnableOption "media CLI tools";
  };
}
