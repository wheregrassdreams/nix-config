{
  nixpkgs,
  overlays ? [ ],
  inputs,
  self ? null,
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
  stateVersion ? null,
  isWsl ? false,
  systemModules ? [ ],
  homeModules ? [ ],
}:
let
  isDarwin = outputType == "darwin";
  userName = identity.username;
in
let
  systemFunc = if isDarwin then inputs.nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  homeManagerModule =
    if isDarwin then
      inputs.home-manager.darwinModules.home-manager
    else
      inputs.home-manager.nixosModules.home-manager;
in
systemFunc {
  inherit system;
  specialArgs = {
    inherit
      inputs
      self
      system
      hostName
      stateVersion
      isDarwin
      isWsl
      userName
      identity
      configRepoPath
      repoLib
      ;
  };
  modules = [
    { nixpkgs.overlays = overlays; }
    { nixpkgs.config.allowUnfree = true; }
    (if isDarwin then inputs.sops-nix.darwinModules.sops else inputs.sops-nix.nixosModules.sops)
    homeManagerModule
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${userName} =
        { ... }:
        {
          imports = [ ../modules/home/homebrew/options.nix ] ++ homeModules;
          home = {
            username = userName;
            homeDirectory = if isDarwin then "/Users/${userName}" else "/home/${userName}";
          };
        };
      home-manager.sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
      home-manager.extraSpecialArgs = {
        inherit
          inputs
          system
          hostName
          userName
          identity
          isDarwin
          isWsl
          configRepoPath
          repoLib
          ;
        flake = self;
      };
    }
  ]
  ++ systemModules
  ++ nixpkgs.lib.optionals isWsl [ inputs.nixos-wsl.nixosModules.wsl ];
}
