{ mylib, ... }:
{
  imports = [
    ../core
  ]
  ++ mylib.importAll ./.;
}
