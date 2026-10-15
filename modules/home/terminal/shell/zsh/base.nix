{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.my.terminal.shell;
in
{
  config = {
    home.file = {
      ".config/zsh/scripts/edit-command-line.zsh".source = ./scripts/edit-command-line.zsh;
      ".config/zsh/scripts/keybinds.zsh".source = ./scripts/keybinds.zsh;
    };

    programs = {
      zsh = {
        enable = true;
        dotDir = "${config.xdg.configHome}/zsh";
        enableCompletion = true; # 开启补全
        autosuggestion.enable = true; # 提示历史命令
        syntaxHighlighting.enable = true; # 语法高亮
        autocd = true; # 不需要输入`cd`直接跳转目录

        initContent = lib.mkMerge [
          (lib.mkOrder 550 ''
            mkdir -p ${config.xdg.configHome}/zsh/completions
            fpath+=(${config.xdg.configHome}/zsh/completions)
          '')
          (lib.mkIf cfg.zsh.clipboard.enable ''
            # The plugin reports an error when sourced without a supported
            # clipboard manager. Keep headless shells quiet while allowing hosts
            # to provide their appropriate backend.
            if (( $+commands[pbcopy] || $+commands[wl-copy] || $+commands[xclip] || $+commands[xsel] )); then
              source ${pkgs.zsh-system-clipboard}/share/zsh/zsh-system-clipboard/zsh-system-clipboard.zsh
            fi
          '')
          ''
            source ${config.xdg.configHome}/zsh/scripts/keybinds.zsh
            source ${config.xdg.configHome}/zsh/scripts/edit-command-line.zsh

            if [[ -o interactive && -o zle && -t 0 ]]; then
              eval "$(${pkgs.fzf}/bin/fzf --zsh)"
            fi

            # 对命令名启用模糊
            zstyle ':completion:*:commands' matcher-list \
              'm:{a-z}={A-Za-z}' \
              'r:|[._-]=** r:|=**'

            # 对选项/参数启用模糊
            zstyle ':completion:*:options' matcher-list \
              'm:{a-z}={A-Za-z}' \
              'r:|[._-]=** r:|=**'

            # 对参数/变量（包括环境变量）启用模糊
            zstyle ':completion:*:parameters' matcher-list \
              'm:{a-z}={A-Za-z}' \
              'r:|[._-]=** r:|=**'

            # zstyle ':completion:*' insert-unambiguous false
            zstyle ':completion:*:paths' matcher-list ""
            zstyle ':completion:*:files' matcher-list ""
            zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
            zstyle ':completion:*' menu no
            zstyle ':fzf-tab:*' use-fzf-default-opts yes
            zstyle ':fzf-tab:*' fzf-flags --no-sort --ansi --header '< > switch group' --min-height=6
            zstyle ':fzf-tab:*' switch-group '<' '>'
            zstyle ':completion:*:descriptions' format '• %d'
            zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
            zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

          ''
        ];
        envExtra = ''
          # Custom ~/.zshenv goes here
        '';
        profileExtra = ''
          # Let GUI-launched editors resolve Home Manager tools and language servers first.
          typeset -U path PATH
          path=("${config.home.profileDirectory}/bin" $path)
        '';
        loginExtra = ''
          # Custom ~/.zlogin goes here
        '';
        logoutExtra = ''
          # Custom ~/.zlogout goes here
        '';

        # dirHashes = {
        #   docs  = "${config.home.homeDirectory}/Documents";
        #   dl    = "${config.home.homeDirectory}/Downloads";
        # };

        history = {
          size = 50000;
          save = 50000;
          path = "${config.xdg.dataHome}/zsh/zsh_history";
          ignoreSpace = true;
          ignoreDups = true;
          share = true;
          extended = true;
        };

        plugins = [
          {
            name = "zsh-fzf-tab";
            src = pkgs.zsh-fzf-tab;
            file = "share/fzf-tab/fzf-tab.plugin.zsh";
          }
          {
            name = "zsh-completions";
            src = pkgs.zsh-completions;
          }
        ];

        siteFunctions = {
          mkcd = ''mkdir --parents "$1" && cd "$1" '';
          uuid = ''uuidgen | tr -d '\n' '';
          to-timestamp = ''if [ "$#" -gt 0 ]; then date '+%s' --date "$*"; else date '+%s'; fi'';
          from-timestamp = ''date '+%Y-%m-%d %H:%M:%S' --date=@"''${1:0:10}" '';
          timestamp = "date '+%s' ";
          random = "cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1";
        };
      };

      zoxide = {
        enable = true;
        enableZshIntegration = true;
        options = [ "--cmd cd" ];
      };

      carapace = {
        enable = true;
        enableZshIntegration = true;
      };

      # Prompt configuration lives in ../prompt.nix.
      /*
        starship = {
          enable = true;
          enableZshIntegration = true;
          settings = {
            format = ''
              $directory''${custom.git_branch_tail}
              $character
            '';

            directory = {
              style = "white";
              truncation_length = 3;
              format = "[$path]($style) ";
            };

            custom.git_branch_tail = {
              command = "git rev-parse --abbrev-ref HEAD | awk -F/ '{print $NF}'";

              when = "git rev-parse --is-inside-work-tree 2>/dev/null";

              symbol = " ";
              format = "[$symbol$output](dimmed) ";
            };

            character = {
              success_symbol = "[➜](green)";
              error_symbol = "[➜](red)";
              vicmd_symbol = "[➜](yellow)";
            };

            python = {
              symbol = " ";
              style = "yellow";
              version_format = "v\${raw}";
              format = "[$symbol]($style)[$version](dimmed) ";
            };

            golang = {
              symbol = " ";
              style = "cyan";
              format = "[$symbol$version](dimmed) ";
            };

            nodejs = {
              symbol = " ";
              style = "green";
              format = "[$symbol]($style)[$version](dimmed) ";
            };

            rust = {
              symbol = " ";
              style = "red";
              format = "[$symbol$version](dimmed) ";
            };
          };
        };
      */
    };

    home.sessionVariables.EDITOR = "nvim";

    home.shellAliases = {
      reload = "exec $SHELL --login";
      e = "$EDITOR";
      server = "python3 -m http.server";
      noansi = ''sed -r "s/\x1B\[[0-9;]*[mK]//g"'';
      today = "date +%Y-%m-%d";
      ".." = "cd ..";
      "..." = "cd ../..";
      "-" = "cd -";
    };
  };
}
