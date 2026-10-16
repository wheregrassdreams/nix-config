{
  lib,
  isDarwin,
  repoLib,
  ...
}:
{
  imports = lib.optionals isDarwin [ ../../homebrew ] ++ repoLib.importAll ./.;
}
