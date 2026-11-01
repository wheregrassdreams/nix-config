{ inputs }:
final: _prev: {
  # Keep the rolling package set available under one explicit namespace. Modules
  # opt into individual packages with `pkgs.unstable.<name>`.
  unstable = import inputs.nixpkgs-unstable {
    system = final.stdenv.hostPlatform.system;
    config.allowUnfree = true;
    overlays = [ inputs.nur.overlays.default ];
  };
}
