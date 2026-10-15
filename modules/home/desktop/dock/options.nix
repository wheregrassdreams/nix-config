{ lib, ... }:
{
  options.my.desktop.dock.entries = lib.mkOption {
    type =
      with lib.types;
      listOf (submodule {
        options = {
          path = lib.mkOption { type = str; };
          section = lib.mkOption {
            type = enum [
              "apps"
              "others"
            ];
            default = "apps";
          };
          options = lib.mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional dockutil arguments for this entry.";
          };
        };
      });
    default = [ ];
    description = "Ordered user Dock entries; an empty list leaves the Dock unmanaged.";
  };
}
