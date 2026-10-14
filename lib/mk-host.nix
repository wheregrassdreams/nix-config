{
  nixpkgs,
  overlays ? [ ],
  inputs,
  self ? null,
  repoLib ? null,
}:
{
  system,
  userName,
  identity,
  hostName,
  dotfilesPath ? (if isDarwin then "/Users/${userName}/.dotfiles" else "/home/${userName}/.dotfiles"),
  stateVersion ? null,
  isDarwin ? false,
  isWsl ? false,
  systemModules ? [ ],
  homeModules ? [ ],
}:
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
      dotfilesPath
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
          imports = homeModules;
          home.homeDirectory = if isDarwin then "/Users/${userName}" else "/home/${userName}";
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
          dotfilesPath
          repoLib
          ;
        flake = self;
      };
    }
  ]
  ++ systemModules
  ++ nixpkgs.lib.optionals isWsl [ inputs.nixos-wsl.nixosModules.wsl ];
}
