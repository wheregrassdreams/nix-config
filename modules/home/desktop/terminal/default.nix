{
  lib,
  isDarwin,
  repoLib,
  ...
}:
{
  imports = [
    ./options.nix
  ]
  ++ lib.optionals isDarwin [ ../../homebrew ]
  ++ repoLib.importAll ./.;
}
