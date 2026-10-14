{ self }:
{
  macbook = import ./macbook { inherit self; };
  wsl = import ./wsl { inherit self; };
}
