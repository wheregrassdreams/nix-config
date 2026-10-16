{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  raycast = import ../lib/raycast-extensions.nix {
    inherit inputs lib pkgs;
  };
  extensionSync = raycast.mkRayCastStoreExtensionSync {
    dataHome = config.xdg.dataHome;
    extensions = [
      {
        owner = "nhojb";
        name = "brew";
        commit = "645cb29302e41f7730b0e68d84777feb0ad096a9";
        sha256 = "51d535fcb5d332e4ef2d3dcb7047950cf6a155ebfbed54eecf484a40234d17a8";
      }
      {
        owner = "ike-gg";
        name = "clean-keyboard";
        commit = "06d383b2ceccaa2af12d7e9d14b3d64b992fbacd";
        sha256 = "6af55879aade86b251c2f6d261a032bd4a509436a9264418e548ab651bdea0bb";
      }
      {
        owner = "thomas";
        name = "downloads-manager";
        commit = "3c654737b0d566d3103fcdf72221a9f34664bdf2";
        sha256 = "17ba58232e8e7bf96a4bf6063b514032e9f43418567281ead394a7ebae31e0c1";
      }
      {
        owner = "vimtor";
        name = "video-downloader";
        commit = "ae5cb36200c68c045ba8fea74277fa8363bf1f63";
        sha256 = "1a53cea6fd12c33ff6784cb9e0dc920e468198aa9a6f16571db00bfdc879e229";
      }
    ];
  };
in
{
  # Release Command+Space from Spotlight so Vicinae can use it as its global shortcut.
  targets.darwin.defaults."com.apple.symbolichotkeys".AppleSymbolicHotKeys."64" = {
    enabled = false;
    value = {
      parameters = [ 65535 49 1048576 ];
      type = "standard";
    };
  };

  programs.vicinae = {
    launchd = {
      enable = true;
      autoStart = true;
    };
    settings = {
      launcher_window.material = "liquid_glass";
      providers.applications.entrypoints = {
        "com.kagi.kagimacOS".alias = "web";
        "com.mitchellh.ghostty".alias = "term";
        "com.openai.codex".alias = "codex";
      };
    };
  };

  home.activation.syncVicinaeRaycastExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${extensionSync}/bin/sync-vicinae-raycast-extensions
  '';
}
