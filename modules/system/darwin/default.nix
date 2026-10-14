{ dotfilesLib, ... }: {
  imports = [
    ../lib/nix.nix
    ../lib/base-tools.nix
    ./options.nix
    ./lib/dock.nix
  ] ++ dotfilesLib.collectPackageModules ./.;
}
