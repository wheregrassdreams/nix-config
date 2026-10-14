{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.development.haskell.enable {
    home.packages = with pkgs; [
      ghc
      cabal-install
      stack
      haskell-language-server
    ];
  };
}
