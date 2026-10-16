{ lib, ... }:
{
  options.my.desktop.agent = {
    default = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Application key used for the agent alias";
    };
  };
}
