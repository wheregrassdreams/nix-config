{
  config,
  repoLib,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  cfg = config.my.services;
  homebrew = config.my.homebrew;
  components = [
    {
      name = "mysql";
      formula = "mysql";
      package = pkgs.mysql84;
      settings = cfg.mysql;
    }
    {
      name = "postgres";
      formula = "postgresql@17";
      package = pkgs.postgresql;
      settings = cfg.postgres;
    }
    {
      name = "redis";
      formula = "redis";
      package = pkgs.redis;
      settings = cfg.redis;
    }
  ];
  modeOf =
    component: if component.settings.mode != null then component.settings.mode else cfg.defaultMode;
  enabledComponents = builtins.filter (component: component.settings.enable) components;
  manualComponents = builtins.filter (
    component: modeOf component == "local-manual"
  ) enabledComponents;
  daemonComponents = builtins.filter (
    component: modeOf component == "local-daemon"
  ) enabledComponents;
  enabledClient = component: component.enable && component.client.enable;
in
{
  imports = lib.optionals isDarwin [ ../homebrew ] ++ repoLib.importAll ./.;

  config = lib.mkMerge [
    {
      assertions = map (component: {
        assertion = component.settings.enable || component.settings.mode == null;
        message = "my.services.${component.name}.mode requires my.services.${component.name}.enable";
      }) components;

      home.packages =
        map (component: component.package) manualComponents
        ++ lib.optionals (enabledClient cfg.mysql) [
          pkgs.mycli
          pkgs.mysql-shell
        ]
        ++ lib.optionals (enabledClient cfg.postgres) [
          pkgs.pgcli
          pkgs.postgresql
        ]
        ++ lib.optionals (enabledClient cfg.redis) [ pkgs.iredis ];
    }
    (lib.mkIf pkgs.stdenv.isDarwin {
      my.homebrew.brews = map (component: component.formula) daemonComponents;
    })
    (lib.mkIf (pkgs.stdenv.isDarwin && daemonComponents != [ ]) {
      home.activation.manageHomebrewServices = lib.hm.dag.entryAfter [ "brewBundle" ] ''
        brew=${lib.escapeShellArg "${homebrew.brewPrefix}/bin/brew"}
        if [ -x "$brew" ]; then
          ${lib.concatMapStrings (component: ''
            "$brew" services start ${lib.escapeShellArg component.formula}
          '') daemonComponents}
        fi
      '';
    })
  ];
}
