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
      {
        owner = "koinzhang";
        name = "browser-tabs";
        commit = "676b573f9e383ffd4d2623605238ffa234f64a3b";
        sha256 = "7d248a12177897a3eed3f751502aa04be0ab206b4104fd92a87c82e2bdc3ff39";
      }
    ];
  };
  aliasApplications = [
    {
      alias = "web";
      application = config.my.desktop.browser.default;
    }
  ]
  ++ lib.optionals (config.my.desktop.terminal.default != null) [
    {
      alias = "term";
      application = config.my.desktop.terminal.default;
    }
  ]
  ++ lib.optionals (config.my.desktop.agent.default != null) [
    {
      alias = "agent";
      application = config.my.desktop.agent.default;
    }
  ];
  appIdentity = import ../../apps/lib/package.nix { inherit pkgs; };
  cacheFile = "${config.xdg.cacheHome}/nix-config/app-identities.json";
  aliasArgs = lib.concatMapStringsSep " " (
    item: "--alias ${lib.escapeShellArg item.alias}=${lib.escapeShellArg item.application}"
  ) aliasApplications;
  favoriteArgs = lib.concatMapStringsSep " " (favorite: "--favorite ${lib.escapeShellArg favorite}") [
    "files:search"
    "@koinzhang/store.raycast.browser-tabs:index"
  ];
  dynamicSettings = "${config.xdg.configHome}/vicinae/generated-settings.json";
  accessibilityReminder = "${config.xdg.stateHome}/nix-config/vicinae-accessibility-reminder-shown";
  ensureVicinaeImports = pkgs.writeText "ensure-vicinae-imports.py" ''
    import os
    import re
    import sys
    import tempfile
    from pathlib import Path

    path = Path(sys.argv[1])
    required = ["home-manager.json", "generated-settings.json"]
    path.parent.mkdir(parents=True, exist_ok=True)
    text = path.read_text() if path.exists() else "{}\n"

    imports = re.search(r'(?m)^[ \t]*"imports"[ \t]*:', text)
    if imports:
        array = re.search(r'(?s)"imports"[ \t]*:[ \t]*\[(.*?)\]', text[imports.start():])
        if not array:
            raise SystemExit(f"Cannot safely update imports in {path}")
        existing = re.findall(r'"((?:\\.|[^"\\])*)"', array.group(1))
        missing = [item for item in required if item not in existing]
        if missing:
            raise SystemExit(f"Add these Vicinae imports to {path}: {', '.join(missing)}")
        raise SystemExit(0)

    opening = re.search(r'(?m)^[ \t]*\{', text)
    if not opening:
        raise SystemExit(f"Cannot find the JSON object in {path}")
    index = text.index("{", opening.start()) + 1
    block = '\n  "imports": ["home-manager.json", "generated-settings.json"],'
    updated = text[:index] + block + text[index:]

    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(updated)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
  '';
in
{
  # Release Command+Space from Spotlight so Vicinae can use it as its global shortcut.
  targets.darwin.defaults."com.apple.symbolichotkeys".AppleSymbolicHotKeys."64" = {
    enabled = false;
    value = {
      parameters = [
        65535
        49
        1048576
      ];
      type = "standard";
    };
  };

  programs.vicinae = {
    launchd = {
      enable = true;
      autoStart = true;
    };
  };

  home.activation.prepareVicinaeApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${appIdentity}/bin/app-identity settings \
      --cache ${lib.escapeShellArg cacheFile} \
      --output ${lib.escapeShellArg dynamicSettings} \
      --allow-missing \
      ${aliasArgs} \
      ${favoriteArgs}
  '';
  home.activation.ensureVicinaeConfigImports =
    lib.hm.dag.entryAfter [ "prepareVicinaeApplications" ]
      ''
        $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${ensureVicinaeImports} \
          ${lib.escapeShellArg "${config.xdg.configHome}/vicinae/settings.json"}
      '';
  home.activation.setupLaunchAgents = lib.hm.dag.entryAfter [ "prepareVicinaeApplications" ] (
    lib.mkDefault ""
  );
  home.activation.configureVicinaeApplications =
    lib.hm.dag.entryAfter
      [
        "refreshAppIdentities"
        "ensureVicinaeConfigImports"
        "setupLaunchAgents"
      ]
      ''
        changed="$(${appIdentity}/bin/app-identity settings \
          --cache ${lib.escapeShellArg cacheFile} \
          --output ${lib.escapeShellArg dynamicSettings} \
          ${aliasArgs} \
          ${favoriteArgs})"
        if [ "$changed" = changed ]; then
          $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$UID/org.nix-community.home.vicinae"
        fi
      '';
  home.activation.syncVicinaeRaycastExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${extensionSync}/bin/sync-vicinae-raycast-extensions
  '';

  home.activation.remindVicinaeAccessibility =
    lib.hm.dag.entryAfter [ "configureVicinaeApplications" ]
      ''
        if [ ! -e ${lib.escapeShellArg accessibilityReminder} ]; then
          printf '\nVicinae clipboard paste needs macOS Accessibility permission.\n'
          printf 'Open System Settings > Privacy & Security > Accessibility. If Vicinae is not listed, click + and add:\n'
          printf '  %s\n\n' "$HOME/Applications/Home Manager Apps/Vicinae.app"
          $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg (builtins.dirOf accessibilityReminder)}
          $DRY_RUN_CMD touch ${lib.escapeShellArg accessibilityReminder}
        fi
      '';
}
