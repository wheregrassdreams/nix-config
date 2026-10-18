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

    programs.zed-editor = {
      enable = true;
      package = null;
      userSettings.lsp = {
        basedpyright.binary = {
          path = zedBin "basedpyright-langserver";
          arguments = [ "--stdio" ];
        };
        "bash-language-server".binary = {
          path = zedBin "bash-language-server";
          arguments = [ "start" ];
        };
        eslint.binary = {
          path = zedBin "vscode-eslint-language-server";
          arguments = [ "--stdio" ];
        };
        gopls.binary.path = zedBin "gopls";
        "json-language-server".binary = {
          path = zedBin "vscode-json-language-server";
          arguments = [ "--stdio" ];
        };
        "tailwindcss-language-server".binary = {
          path = zedBin "tailwindcss-language-server";
          arguments = [ "--stdio" ];
        };
        vtsls.binary = {
          path = zedBin "vtsls";
          arguments = [ "--stdio" ];
        };
        "vscode-css-language-server".binary = {
          path = zedBin "vscode-css-language-server";
          arguments = [ "--stdio" ];
        };
        "vscode-html-language-server".binary = {
          path = zedBin "vscode-html-language-server";
          arguments = [ "--stdio" ];
        };
        "yaml-language-server".binary = {
          path = zedBin "yaml-language-server";
          arguments = [ "--stdio" ];
        };
      };
    };
  };
}
