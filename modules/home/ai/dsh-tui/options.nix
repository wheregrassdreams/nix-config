{ lib, ... }:
{
  options.my.ai.dsh-tui = {
    enable = lib.mkEnableOption "DeepSeek Harness TUI (dsh-tui)";
  };
}
