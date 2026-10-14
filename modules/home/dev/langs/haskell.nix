{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.dev.langs.haskell.enable {
    home.packages = with pkgs; [
      ghc
      cabal-install
      stack
      haskell-language-server
    ];
  };
}
