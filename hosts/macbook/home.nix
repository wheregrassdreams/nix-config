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
    flake.homeModules."desktop.agent"
    flake.homeModules."desktop.apps"
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

  sops.secrets = lib.mkIf (builtins.pathExists ../../secrets/users/remote-backups.yaml) {
    "backup/gitea-ssh-private-key" = {
      sopsFile = ../../secrets/users/remote-backups.yaml;
      key = "backup/gitea-ssh-private-key";
      path = "${config.home.homeDirectory}/.config/nix-config/secrets/backup-gitea-ssh-key";
      mode = "0400";
    };
    "backup/restic-valuable" = {
      sopsFile = ../../secrets/users/remote-backups.yaml;
      key = "backup/restic-valuable";
      path = "${config.home.homeDirectory}/.config/nix-config/secrets/backup-restic-valuable";
      mode = "0400";
    };
    "backup/s3-environment" = {
      sopsFile = ../../secrets/users/remote-backups.yaml;
      key = "backup/s3-environment";
      path = "${config.home.homeDirectory}/.config/nix-config/secrets/backup-s3-environment";
      mode = "0400";
    };
  };

  my = {
    inherit identity;
    # desktop.files.disktree.enable = true;
    homebrew = {
      brewPrefix = "/opt/homebrew";
      taps = [
        # { name = "bendews/tap"; trusted = true; }
        # { name = "shivammathur/php"; trusted = true; }
      ];
      brews = [
        # "terminal-notifier"        # ghostty/kitty已经有这个功能了
        # "bendews/tap/apw"          # 暂时没有使用场景
        # "shivammathur/php/php@7.2" # 以前工作用到，现在不需要了
      ];
      casks = [
        "dbeaver-community"
        "lookaway"
        "picgo"
        "postman"
        "tusk"
        # "kicad"
        # "neteasemusic" # Homebrew Cask.
        # "wechat" # Homebrew Cask.
        # "ticktick" # Homebrew Cask.
        # "orbstack" # Homebrew Cask.
        # "affinity" # Homebrew Cask (current unified Affinity app).
        # "figma" # Homebrew Cask.
        # "localsend" # Homebrew Cask.
        # "syncthing-app" # Homebrew Cask GUI.
        # "xnip" # Homebrew Cask.
      ];
      # MAS fallback only where no Homebrew Cask is available:
      # Gifski is the app; RunCat Neo is the available alternative to RunCat.
      # masApps = {
      #   "Gifski" = 1351639930;
      #   "RunCat Neo" = 6757801838;
      # };
      # DiskTree has a local Nix package. Z-Library currently only has a manually downloaded,
      # dynamically linked DMG via Z-Access; keep it unmanaged until the artifact is verifiable.
      # RunCat has no Cask; RunCat Neo is the available MAS alternative.
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
      ssh.trzsz.enable = true;
      tailscale = {
        # TODO: 换成主domain会更实用，当前看不出意图
        host = "homelab.tail50e8c0.ts.net";
      };
      clashVerge = {
        # TODO: 优化命名，当前命名看不出意图，至少要表明是和tailscale的集成
        hostname = "mihomo-${hostName}";
        tailnetDomain = "wheregrassdreams.top";
        tailnetCidr = "100.64.0.0/10";
        dnsUpstream = "100.124.158.7";
      };
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
        default = "kagimacos";
        chrome.enable = true;
        orion.enable = true;
        zen.enable = false;
      };

      terminal = {
        default = "ghostty";
        ghostty.enable = true;
        kitty.enable = true;
      };
      agent.default = "codex";

      input = {
        keyboardMapping.enable = true;
        mouseScroll.enable = true;
      };

      editor = {
        zed.enable = true;
        default = "zed";
      };

    };

    storage.backup = {
      repositories.valuable = {
        target = "homelab-s3";
        initIfMissing = false;
        passwordFile = "${config.home.homeDirectory}/.config/nix-config/secrets/backup-restic-valuable";
        environmentFile = "${config.home.homeDirectory}/.config/nix-config/secrets/backup-s3-environment";
      };
      policies.valuable.repository = "valuable";
      datasets = {
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
    };

    terminal.shell = {
      # TODO: 有些改成默认的
      prompt.enable = true;
      atuin.enable = true;
      direnv.enable = true;
      integrations = {
        macos.enable = true;
        nixIndex.enable = true;
      };
    };

    storage.remote.targets = {
      homelab-s3 = {
        backend.s3 = {
          endpoint = "http://192.168.3.250:8333";
          bucket = "home-backups";
          prefix = "nix-config";
        };
      };
      homelab-gitea-backups = {
        backend.git = {
          sshHost = "gitea-backups";
        };
        provisioner = {
          kind = "giteaPreprovisioned";
          gitea = {
            repository = "homelab-backups/nix-config-snapshots";
          };
        };
      };
    };

    dev.projects.snapshots.remote.target = "homelab-gitea-backups";

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
  };

}
