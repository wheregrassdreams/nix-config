{ inputs, ... }:
let
  inherit (import ./host-context.nix { inherit inputs; }) lib mylib hosts;

  hostHomeConfigurations = lib.mapAttrs' (
    name: host: lib.nameValuePair "${host.identity.username}@${name}" (mylib.mkHome host)
  ) hosts;
  homeConfigurations = hostHomeConfigurations;
  stagingReprise = import ../integrations/staging/reprise-bridge.nix { inherit inputs lib; };
in
{
  flake = {
    homeModules = mylib.discoverPackages ../modules/home // {
      "staging.reprise" = stagingReprise;
      "staging.tmux-config" = inputs.staging-tmux-config.homeManagerModules.default;
    };
    homeConfigurations = homeConfigurations;
    darwinModules.platform = import ../modules/system/darwin;
    nixosModules.platform = import ../modules/system/nixos;
    lib = lib.extend (_: _: { nixConfig = lib.removeAttrs mylib [ "mkHost" ]; });
  };
}
