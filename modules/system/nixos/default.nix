{ dotfilesLib, ... }:
{
  imports = [
    ../lib/nix.nix
    ../lib/base-tools.nix
    ../services/nixos.nix
    ../../home/ssh/options.nix
  ] ++ dotfilesLib.collectPackageModules ./.;
}
