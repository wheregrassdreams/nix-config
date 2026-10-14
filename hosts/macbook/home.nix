{
  config,
  identity,
  lib,
  pkgs,
  ...
}:
{
  home = {
    stateVersion = "25.11";
    enableNixpkgsReleaseCheck = false;
    username = identity.username;
    sessionVariables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };
  };

  my = {
    inherit identity;
    homebrew = {
      brewPrefix = "/opt/homebrew";
      sync = {
        enable = true;
        autoUpdate = false;
        upgrade = false;
        cleanup = "none";
        strict = true;
      };
    };

    connectivity = {
      tailscale = {
        host = "homelab.tail50e8c0.ts.net";
      };
    };
    connectivity.clashVerge = {
      hostname = "cv-macbook-zane";
      tailnetDomain = "wheregrassdreams.top";
      tailnetCidr = "100.64.0.0/10";
      dnsUpstream = "100.124.158.7";
    };

    paths.personal = {
      work = "${config.home.homeDirectory}/Workspace/work";
      notes = "${config.home.homeDirectory}/Workspace/notes";
    };

    ai = {
      codex.cli.enable = true;
      opencode.cli.enable = false;
    };

    desktop = {
      browser = {
        default = "safari";
        chrome.enable = true;
        zen.enable = false;
      };
      terminal = {
        ghostty.enable = true;
        kitty.enable = true;
      };
      keymap.karabiner.enable = true;
      editor.zed.enable = true;
      menuBar.ice.enable = false;
    };

    services.defaultMode = "external";
    data.items.notes = {
      source = {
        type = "path";
        path = config.my.paths.personal.notes;
      };
      preservation = "durable";
      replication = "sync";
      restore = "copy-tree";
    };
    terminal.shell = {
      zsh.enable = true;
      prompt.enable = true;
      atuin.enable = true;
      direnv.enable = true;
      integrations = {
        macos.enable = true;
        nixIndex.enable = true;
      };
    };

    terminal.tools = {
      media.enable = true;
    };

    git = {
      lazygit.enable = true;
      github.enable = true;
      gitlab.enable = false;
      gitea.enable = true;
    };

    dev.langs = {
      lua.enable = true;
      nix.enable = true;
      go.enable = true;
      javascript.enable = true;
      rust.enable = true;
      haskell.enable = false;
      python = {
        enable = true;
        suite = "full";
      };
      clang = {
        enable = true;
        opengl.enable = true;
      };
    };
  };

  programs.git.includes = [
    {
      condition = "gitdir:${config.my.paths.personal.work}/";
      path = "${config.my.paths.personal.work}/.gitconfig";
    }
  ];
  programs.go.env.GOPRIVATE = [ "*.xiaoe-tools.com" ];
  programs.bash.initExtra = lib.optionalString pkgs.stdenv.isDarwin "ulimit -s 65500";
  programs.zsh.initContent = lib.mkAfter (lib.optionalString pkgs.stdenv.isDarwin "ulimit -s 65500");
  my.terminal.tmux.inputMethod.command =
    lib.mkIf config.my.desktop.keymap.karabiner.enable "${config.my.homebrew.brewPrefix}/bin/im-select";

  targets.darwin.defaults = {
    ".GlobalPreferences"."com.apple.mouse.scaling" = -1.0;
    "com.apple.finder" = {
      AppleShowAllFiles = true;
      CreateDesktop = false;
      FXDefaultSearchScope = "SCcf";
      FXPreferredViewStyle = "Nlsv";
      FXRemoveOldTrashItems = true;
      NewWindowTarget = "Desktop";
      ShowExternalHardDrivesOnDesktop = false;
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = false;
      ShowRemovableMediaOnDesktop = false;
    };
  }
  // lib.optionalAttrs config.my.desktop.menuBar.ice.enable {
    "com.jordanbaird.Ice" = {
      AutoRehide = true;
      CanToggleAlwaysHiddenSection = true;
      EnableAlwaysHiddenSection = true;
      IceBarLocation = 0;
      ItemSpacingOffset = 0.0;
      RehideInterval = 15;
      RehideStrategy = 0;
      ShowAllSectionsOnUserDrag = true;
      ShowIceIcon = true;
      ShowOnClick = true;
      ShowOnHover = false;
      ShowOnHoverDelay = 0.2;
      ShowOnScroll = true;
      ShowSectionDividers = false;
      TempShowInterval = 15;
      UseIceBar = true;
      SUAutomaticallyUpdate = false;
      SUEnableAutomaticallyChecks = false;
    };
  };

}
