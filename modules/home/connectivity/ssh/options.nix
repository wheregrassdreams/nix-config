{ lib, ... }:
{
  options.my.connectivity.ssh.trzsz.enable =
    lib.mkEnableOption "trzsz-ssh as the default ssh command";
}
