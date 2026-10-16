{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.vicinae.homeManagerModules.default ];
  disabledModules = [ "${inputs.home-manager}/modules/programs/vicinae.nix" ];

  # The upstream module emits this target even when Chrome integration is
  # disabled; Home Manager does not expose it for the proprietary Chrome cask.
  options.programs.google-chrome.nativeMessagingHosts = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
  };

  config.programs.vicinae = {
    enable = true;
    package = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
    enableChromeIntegration = lib.mkForce false;
    enableFirefoxIntegration = lib.mkForce false;
    settings = {
      "$schema" = "https://vicinae.com/schemas/config.json";
      close_on_focus_loss = true;
      consider_preedit = true;
      activate_on_single_click = true;
      language = "en";
      # Vicinae maps Qt Control to physical Command on macOS, but to Control on Linux.
      global_shortcuts.toggle = "control+SPACE";
      theme = {
        light.name = "zenwritten-light";
        dark.name = "vicinae-dark";
      };
      providers = {
        clipboard.entrypoints.history.alias = "clip";
        files.entrypoints.search.shortcut = "control+shift+SPACE";
        "raycast-compat".entrypoints.store.preferences.alwaysShowIntro = false;
      };
    };
  };
}
