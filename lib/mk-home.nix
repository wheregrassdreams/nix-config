{
  nixpkgs,
  inputs,
  self ? null,
  overlays ? [
    inputs.nur.overlays.default
    inputs.llm-agents.overlays.default
  ],
  repoLib ? null,
}:
{
  system,
  userName,
  identity,
  hostName,
  configRepoPath ? (
    if isDarwin then "/Users/${userName}/.dotfiles" else "/home/${userName}/.dotfiles"
  ),
  isDarwin ? false,
  isWsl ? false,
  homeModules ? [ ],
  ...
}:
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
    { home.homeDirectory = if isDarwin then "/Users/${userName}" else "/home/${userName}"; }
  ]
  ++ homeModules;
}
