{ inputs, lib, ... }:
let
  overlayFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) (builtins.readDir ../overlays);

  localOverlays = lib.mapAttrs' (
    name: _:
    lib.nameValuePair (lib.removeSuffix ".nix" name) (
      import (../overlays + "/${name}") { inherit inputs; }
    )
  ) overlayFiles;
in
{
  flake.overlays = localOverlays // {
    default = lib.composeManyExtensions (
      [
        inputs.nur.overlays.default
      ]
      ++ builtins.attrValues localOverlays
    );
  };
}
