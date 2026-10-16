{
  config,
  flake,
  hostName,
  identity,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    flake.homeModules.core
    flake.homeModules.terminal
    flake.homeModules."terminal.shell"
    flake.homeModules."terminal.tmux"
    flake.homeModules."terminal.tools"
    flake.homeModules."dev.kubernetes"
    flake.homeModules."dev.ci"
    flake.homeModules."dev.projects"
    flake.homeModules."dev.tools"

    flake.homeModules."dev.langs.c"
    flake.homeModules."dev.langs.css"
    flake.homeModules."dev.langs.go"
    flake.homeModules."dev.langs.html"
    flake.homeModules."dev.langs.javascript"
    flake.homeModules."dev.langs.json"
    flake.homeModules."dev.langs.lean"
    flake.homeModules."dev.langs.lua"
    flake.homeModules."dev.langs.nix"
    flake.homeModules."dev.langs.python"
    flake.homeModules."dev.langs.rust"
    flake.homeModules."dev.langs.shell"
    flake.homeModules."dev.langs.sql"
    flake.homeModules."dev.langs.typst"
    flake.homeModules."dev.langs.yaml"
    flake.homeModules."dev.langs.zig"

    flake.homeModules.git
    flake.homeModules."connectivity.ssh"

    flake.homeModules."ai.claude"
    flake.homeModules."ai.codex"
    flake.homeModules."ai.cc-switch"
    flake.homeModules."ai.opencode"
    flake.homeModules."ai.agent-resources"

    flake.homeModules."desktop.browser"
    flake.homeModules."desktop.editor"
    flake.homeModules."desktop.files"
    flake.homeModules."desktop.input"
    flake.homeModules."desktop.launcher"
    flake.homeModules."desktop.menubar"
    flake.homeModules."desktop.note"
    flake.homeModules."desktop.password"
    flake.homeModules."desktop.terminal"
    flake.homeModules."desktop.window-manager"

    flake.homeModules."connectivity.clash-verge"
    flake.homeModules."connectivity.tailscale"

    flake.homeModules.services
    flake.homeModules."storage.backup"
    flake.homeModules."storage.remote"
  ];

  home = {
    stateVersion = "25.11";
    enableNixpkgsReleaseCheck = false;
    sessionVariables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };
  };

  my = {
    inherit identity;
    homebrew = {
      brewPrefix = "/opt/homebrew";
      taps = [
        {
          name = "bendews/tap";
          trusted = true;
        }
        {
          name = "shivammathur/php";
          trusted = true;
        }
      ];
      brews = [
        # "terminal-notifier"
        "bendews/tap/apw"
        # "shivammathur/php/php@7.2"
      ];
      casks = [
        "dbeaver-community"
        "lookaway"
        "picgo"
        "postman"
        "tusk"
        "font-jetbrains-mono-nerd-font"
      ];
      sync = {
        enable = true;
        autoUpdate = false;
        upgrade = false;
        cleanup = "none";
        strict = true;
      };
      driftCheck.enable = true;
    };

    connectivity = {
      tailscale = {
        host = "homelab.tail50e8c0.ts.net";
      };
    };
    connectivity.clashVerge = {
      hostname = "mihomo-${hostName}";
      tailnetDomain = "wheregrassdreams.top";
      tailnetCidr = "100.64.0.0/10";
      dnsUpstream = "100.124.158.7";
    };

    paths.personal = {
      work = "${config.home.homeDirectory}/Workspace/work";
      projects = "${config.home.homeDirectory}/Workspace/code/projects";
      notes = "${config.home.homeDirectory}/Workspace/notes";
      downloads = "${config.home.homeDirectory}/Downloads";
    };

    ai.opencode.cli.enable = false;

    desktop = {
      browser = {
        default = "orion";
        chrome.enable = true;
        orion.enable = true;
        zen.enable = false;
      };
      terminal = {
        ghostty.enable = true;
        kitty.enable = true;
      };
      input = {
        keyboardMapping.enable = true;
        mouseScroll.enable = true;
      };
      editor.zed.enable = true;
      files.archiveExtraction.enable = true;
      launcher = {
        raycast.enable = true;
      };
    };

    services = {
      defaultMode = "external";
      mysql = {
        enable = true;
        mode = "local-manual";
      };
      postgres = {
        enable = true;
        mode = "local-manual";
      };
      redis = {
        enable = true;
        mode = "local-manual";
      };
    };
    storage.backup.datasets = {
      tmux-resurrect = {
        enable = false;
        paths = [ config.my.paths.exported."terminal.tmux.resurrect" ];
        class = "valuable";
      };
      codex-sessions = {
        enable = false;
        paths = [
          "${config.home.homeDirectory}/.codex/sessions"
          "${config.home.homeDirectory}/.codex/archived_sessions"
        ];
        class = "valuable";
      };
    };
    terminal.shell = {
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

    dev.langs.c.opengl.enable = true;
  };

  programs.git.includes = [
    {
      condition = "gitdir:${config.my.paths.personal.work}/";
      path = "${config.my.paths.personal.work}/.gitconfig";
    }
  ];
  programs.bash.initExtra = lib.optionalString pkgs.stdenv.isDarwin "ulimit -s 65500";
  programs.zsh.initContent = lib.mkAfter (lib.optionalString pkgs.stdenv.isDarwin "ulimit -s 65500");
  my.terminal.tmux.inputMethod.command =
    lib.mkIf config.my.desktop.input.keyboardMapping.enable "${config.my.homebrew.brewPrefix}/bin/im-select";

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
  };

}
