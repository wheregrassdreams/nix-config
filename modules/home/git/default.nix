{ dotfilesLib, ... }:
{
  imports = [
    ./options.nix
    ../identity
  ] ++ dotfilesLib.collectPackageModules ./.;
}
