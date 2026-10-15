{ config, lib, pkgs, ... }:
let
  cfg = config.my.homebrew;

  brewNixReport = pkgs.writeShellScriptBin "brew-nix-report" (
    builtins.readFile ./lib/nix-report.sh
  );

  driftCheckCommand = pkgs.writeShellScriptBin "homebrew-drift-check" ''
    exec ${brewNixReport}/bin/brew-nix-report --drift-only
  '';

  notifyOnDrift = pkgs.writeShellScriptBin "homebrew-drift-check-notify" ''
    set +e
    ${driftCheckCommand}/bin/homebrew-drift-check
    status=$?

    if [ "$status" -eq 1 ]; then
      /usr/bin/osascript \
        -e 'display notification "Review the Homebrew drift report in the LaunchAgent log." with title "Nix configuration drift"'
    fi

    exit "$status"
  '';
in
{
  config = lib.mkIf cfg.driftCheck.enable {
    launchd.agents.homebrew-drift-check = {
      enable = true;
      config = {
        Label = "org.nix-config.homebrew-drift-check";
        ProgramArguments = [ "${notifyOnDrift}/bin/homebrew-drift-check-notify" ];
        ProcessType = "Background";
        StartCalendarInterval = [
          {
            Weekday = 1;
            Hour = 9;
            Minute = 0;
          }
        ];
        EnvironmentVariables = {
          PATH = "${cfg.brewPrefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          HOMEBREW_BUNDLE_FILE = "${config.xdg.configHome}/homebrew/Brewfile";
          HOMEBREW_NO_AUTO_UPDATE = "1";
          HOMEBREW_NO_ENV_HINTS = "1";
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-config-homebrew-drift-check.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-config-homebrew-drift-check-error.log";
      };
    };
  };
}
