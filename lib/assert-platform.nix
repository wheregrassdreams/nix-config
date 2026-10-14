{
  package,
  platforms,
  when ? null,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  currentPlatform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  enabled = if when == null then true else lib.attrByPath when false config;
in
{
  assertions = [
    {
      assertion = !enabled || builtins.elem currentPlatform platforms;
      message = "Home package `${package}` supports ${builtins.concatStringsSep " or " platforms}, but the host platform is ${currentPlatform}.";
    }
  ];
}
