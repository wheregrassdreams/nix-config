{
  nixpkgs,
  inputs,
  self ? null,
  overlays ? [ self.overlays.default ],
  repoLib ? null,
}:
{
  system,
  identity,
  outputType,
  hostName,
  configRepoPath ? (
    if outputType == "darwin" then
      "/Users/${identity.username}/.dotfiles"
    else
      "/home/${identity.username}/.dotfiles"
  ),
  isWsl ? false,
  homeModules ? [ ],
  ...
}:
let
  isDarwin = outputType == "darwin";
  userName = identity.username;
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    inherit overlays;
  };
  extraSpecialArgs = {
    inherit
      inputs
      self
      system
      userName
      identity
      hostName
      isDarwin
      isWsl
      configRepoPath
      repoLib
      ;
    flake = self;
  };
  modules = [
    inputs.sops-nix.homeManagerModules.sops
    {
      home = {
        username = userName;
        homeDirectory = if isDarwin then "/Users/${userName}" else "/home/${userName}";
      };
    }
  ]
  ++ homeModules;
}
