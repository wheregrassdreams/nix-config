{ pkgs, ... }:
{
  # Commands expected from a Unix-like distribution, including repository
  # bootstrap commands, independent of the per-user Home Manager profile.
  environment.systemPackages = with pkgs; [
    coreutils
    gnugrep
    gnused
    gnutar
    findutils
    file
    just
    tree
  ];
}
