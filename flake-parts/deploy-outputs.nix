{ inputs, ... }:
let
  inherit (import ./host-context.nix { inherit inputs; }) lib hosts;
  host = hosts.macbook-remote;
  deploy = inputs.deploy-rs;
  targetSystem = host.system;
  self = inputs.self;
  pkgs = import inputs.nixpkgs { system = targetSystem; };
  deployPkgs = import inputs.nixpkgs {
    system = targetSystem;
    overlays = [
      deploy.overlays.default
      (_: previous: {
        deploy-rs = {
          inherit (pkgs) deploy-rs;
          lib = previous.deploy-rs.lib;
        };
      })
    ];
  };
in
{
  flake.deploy.nodes.macbook-remote = {
    hostname = host.hostFacts.deploy.hostname;
    sshUser = host.hostFacts.deploy.sshUser;
    interactiveSudo = false;
    profiles.system = {
      user = "root";
      remoteBuild = true;
      magicRollback = false;
      path = deployPkgs.deploy-rs.lib.activate.darwin self.darwinConfigurations.macbook-remote;
      sshOpts = host.hostFacts.deploy.sshOpts;
    };
    profiles.home = {
      user = host.identity.username;
      remoteBuild = true;
      magicRollback = false;
      path = deployPkgs.deploy-rs.lib.activate.home-manager self.homeConfigurations."zane@macbook-remote";
      sshOpts = host.hostFacts.deploy.sshOpts;
    };
  };

  perSystem =
    { system, ... }:
    let
      systemPkgs = import inputs.nixpkgs { inherit system; };
    in
    {
      apps.deploy = {
        type = "app";
        program = "${systemPkgs.deploy-rs}/bin/deploy";
      };
    }
    // lib.optionalAttrs (system == targetSystem) {
      checks = deployPkgs.deploy-rs.lib.deployChecks self.deploy;
    };
}
