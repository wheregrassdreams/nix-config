{
  lib,
  isDarwin,
  mylib,
  ...
}:
{
  imports = lib.optionals isDarwin [ ../../homebrew ] ++ mylib.importAll ./.;
}
