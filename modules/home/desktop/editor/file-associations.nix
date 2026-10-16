{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.editor;
  appIdentity = import ../apps/lib/package.nix { inherit pkgs; };
  cacheFile = "${config.xdg.cacheHome}/nix-config/app-identities.json";
  extensions = [
    "nix"
    "json"
    "jsonc"
    "json5"
    "yaml"
    "yml"
    "toml"
    "conf"
    "ini"
    "properties"
    "js"
    "jsx"
    "mjs"
    "cjs"
    "ts"
    "tsx"
    "go"
    "py"
    "sh"
    "bash"
    "zsh"
    "css"
    "scss"
    "xml"
    "sql"
    "rs"
    "java"
  ];
in
{
  config = lib.mkIf (pkgs.stdenv.isDarwin && cfg.default != null) {
    home.packages = [ pkgs.duti ];

    home.activation.setDefaultEditorForSourceFiles = lib.hm.dag.entryAfter [ "refreshAppIdentities" ] ''
      bundle_id="$(${appIdentity}/bin/app-identity lookup --cache ${lib.escapeShellArg cacheFile} ${lib.escapeShellArg cfg.default})"
      ${lib.concatMapStringsSep "\n" (extension: ''
        handler_info="$(${pkgs.duti}/bin/duti -x ${lib.escapeShellArg extension} 2>/dev/null || true)"
        current_bundle_id="$(printf '%s\n' "$handler_info" | /usr/bin/tail -n 1)"
        if [ "$current_bundle_id" != "$bundle_id" ]; then
          ${pkgs.duti}/bin/duti -s "$bundle_id" ${lib.escapeShellArg ".${extension}"} editor >/dev/null 2>&1 || true
        fi
      '') extensions}
    '';
  };
}
