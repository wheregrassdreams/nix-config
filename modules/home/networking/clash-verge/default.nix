{ dotfilesLib, ... }:
{
  imports = [ ./options.nix ../../homebrew/options.nix ] ++ dotfilesLib.collectPackageModules ./.;
}
