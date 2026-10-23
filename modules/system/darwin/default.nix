{ mylib, ... }:
{
  imports = [
    ../shared
  ]
  ++ mylib.importAll ./.;
}
