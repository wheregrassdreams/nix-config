{ ... }:
{
  programs.vicinae.systemd = {
    enable = true;
    autoStart = true;
  };
}
