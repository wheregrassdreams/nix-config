{ inputs, lib, pkgs, ... }:
let
  raycastRepoRev = "c4dc0113e4cb11bb2a0a8639af719aae5658d6da";
  raycastExtension = { name, sha256 }:
    inputs.vicinae.lib.${pkgs.stdenv.hostPlatform.system}.mkRayCastExtension {
      inherit name;
      hash = sha256;
      rev = raycastRepoRev;
    };
  settings = {
    "$schema" = "https://vicinae.com/schemas/config.json";
    close_on_focus_loss = true;
    consider_preedit = true;
    activate_on_single_click = true;
    language = "en";
    global_shortcuts.toggle = "control+SPACE";
    theme = {
      light.name = "zenwritten-light";
      dark.name = "vicinae-dark";
    };
    launcher_window.material = "liquid_glass";
    providers = {
      applications.entrypoints = {
        "com.kagi.kagimacOS".alias = "web";
        "com.mitchellh.ghostty".alias = "term";
        "com.openai.codex".alias = "codex";
      };
      clipboard.entrypoints.history.alias = "clip";
      files.entrypoints.search.shortcut = "control+shift+SPACE";
      "raycast-compat".entrypoints.store.preferences.alwaysShowIntro = false;
    };
  };
in
{
  imports = [ inputs.vicinae.homeManagerModules.default ];
  disabledModules = [ "${inputs.home-manager}/modules/programs/vicinae.nix" ];

  # The upstream module emits this target even when Chrome integration is
  # disabled; Home Manager does not expose it for the proprietary Chrome cask.
  options.programs.google-chrome.nativeMessagingHosts = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
  };

  config = {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "desktop.launcher requires macOS for Vicinae";
      }
    ];

    programs.vicinae = {
      enable = true;
      package = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
      enableChromeIntegration = lib.mkForce false;
      enableFirefoxIntegration = lib.mkForce false;
      launchd = {
        enable = true;
        autoStart = true;
      };
      settings = settings;
      extensions = [
        (raycastExtension {
          name = "brew";
          sha256 = "sha256-6iinDCYna7wcI9TOF4E0PXvTlyP5lJyHzi3fusS3EUA=";
        })
        (raycastExtension {
          name = "clean-keyboard";
          sha256 = "sha256-MU1fgIDB+Z30rfqI4SaxXZwqPnKnsn8o1AUMg8EN5WA=";
        })
        (raycastExtension {
          name = "downloads-manager";
          sha256 = "sha256-Xx2GmWDfmqgz2vkp3OMImuf2pQ3Jpns38MZ2OP7DvEo=";
        })
        (raycastExtension {
          name = "video-downloader";
          sha256 = "sha256-jE/PFZiaRWpOETE6k6foPWPpMfjAeotqGzuqFDCsh5A=";
        })
      ];
    };
  };
}
