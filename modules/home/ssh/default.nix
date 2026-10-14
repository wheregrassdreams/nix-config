{ dotfilesLib, ... }:
{
  imports = [ ./options.nix ] ++ dotfilesLib.collectPackageModules ./.;
}
