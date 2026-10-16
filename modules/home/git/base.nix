{
  config,
  pkgs,
  ...
}:
let
  cfg = config.my.identity;
in
{
  config = {
    programs.git = {
      enable = true;
      ignores = [
        # macOS metadata
        ".DS_Store"
        ".AppleDouble"
        ".LSOverride"
        "._*"
        ".Spotlight-V100/"
        ".Trashes/"
        ".fseventsd/"

        # Windows metadata
        "Thumbs.db"
        "ehthumbs.db"
        "Desktop.ini"

        # Editor and temporary files
        "*~"
        "*.swp"
        "*.swo"
        "*.swn"
        ".#*"
        "\\#*#"

        # Local environment files
        ".env"
        ".env.local"
        ".env.*.local"

        # Local-only Claude settings
        "**/.claude/settings.local.json"
      ];
      settings = {
        user = {
          name = cfg.fullname;
          email = cfg.email;
        };
        core.pager = "delta";
        core.excludesFile = "${config.xdg.configHome}/git/ignore";
        interactive.diffFilter = "delta --color-only --features=interactive";

        delta = {
          features = "decorations";
          syntax-theme = "OneHalfDark";
          line-numbers = true;
          side-by-side = false;
          navigate = true;
        };
        "delta \"interactive\"".keep-plus-minus-markers = false;
        "delta \"decorations\"" = {
          commit-decoration-style = "blue ol";
          commit-style = "raw";
          file-style = "omit";
          hunk-header-decoration-style = "blue box";
          hunk-header-file-style = "red";
          hunk-header-line-number-style = "#067a00";
          hunk-header-style = "file line-number syntax";
        };

        diff = {
          tool = "nvimdiff";
          colorMoved = "default";
        };

        lfs = {
          enable = true;
        };

        branch.sort = "-committerdate";
        fetch.prune = true;
        merge.conflictstyle = "diff3";
        push = {
          autoSetupRemote = true;
          followTags = true;
        };
        rebase = {
          autoStash = true;
          updateRefs = true;
        };
        rerere.enabled = true;
      };
    };

    home.packages = with pkgs; [
      # git
      delta
      git-filter-repo
      # git-lfs
    ];
  };
}
