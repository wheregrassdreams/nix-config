{ inputs, ... }:
let
  inherit (import ./host-context.nix { inherit inputs; }) lib hosts;
  host = hosts.macbook-remote;
  deploy = inputs.deploy-rs;
  targetSystem = host.system;
  self = inputs.self;
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
      path = deploy.lib.${targetSystem}.activate.darwin self.darwinConfigurations.macbook-remote;
      sshOpts = host.hostFacts.deploy.sshOpts;
    };
  };

  perSystem =
    { system, ... }:
    {
      apps.deploy = {
        type = "app";
        program = "${deploy.packages.${system}.deploy-rs}/bin/deploy";
      };
    }
    // lib.optionalAttrs (system == targetSystem) {
      checks = deploy.lib.${system}.deployChecks self.deploy;
    };
}
