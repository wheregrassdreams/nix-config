{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.desktop.editor.zed;
  zedBin = name: "${config.home.profileDirectory}/bin/${name}";
in
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.editor.zed";
      platforms = [ "darwin" ];
      when = [
        "my"
        "desktop"
        "editor"
        "zed"
        "enable"
      ];
    })
  ];

  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "zed" ];

    xdg.configFile."zed/keymap.json".source = ./keymap.json;

    # Home Manager merges these into the existing Zed settings, preserving
    # settings maintained by Zed or configured outside this package.
    programs.zed-editor = {
      enable = true;
      package = null;
      userSettings.lsp = {
        basedpyright.binary.path = zedBin "basedpyright-langserver";
        "bash-language-server".binary.path = zedBin "bash-language-server";
        eslint.binary.path = zedBin "eslint";
        gopls.binary.path = zedBin "gopls";
        "json-language-server".binary.path = zedBin "vscode-json-language-server";
        "tailwindcss-language-server".binary.path = zedBin "tailwindcss-language-server";
        vtsls.binary.path = zedBin "vtsls";
        "vscode-css-language-server".binary.path = zedBin "vscode-css-language-server";
        "vscode-html-language-server".binary.path = zedBin "vscode-html-language-server";
        "yaml-language-server".binary.path = zedBin "yaml-language-server";
      };
    };
  };
}
