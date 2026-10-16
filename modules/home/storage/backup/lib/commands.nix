{
  classes,
  hostName,
  lib,
  pkgs,
  repositoryEnvironment,
  repositoryPathFor,
  repositories,
}:
let
  repositoryRuntimeInputs = lib.unique (
    lib.concatLists (
      lib.mapAttrsToList (
        name: repository: (repositoryPathFor name repository).runtimeInputs
      ) repositories
    )
  );
  repositoryCases =
    command:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: repository: ''
        ${lib.escapeShellArg name})
          ${repositoryEnvironment name repository}
          ${command name}
          ;;
      '') repositories
    );
  statusCases = lib.concatStringsSep "\n" (
    map (class: ''
      ${lib.escapeShellArg class})
        status_file="''${XDG_STATE_HOME:-$HOME/.local/state}/storage/backup/${class}.status"
        if [ -f "$status_file" ]; then cat "$status_file"; else echo "no run recorded for ${class}"; fi
        ;;
    '') classes
  );
  restoreCases = lib.mapAttrsToList (name: repository: ''
    ${lib.escapeShellArg name})
      ${repositoryEnvironment name repository}
      shift
      snapshot=latest
      if [ "$#" -gt 0 ] && [ "$1" != "--target" ]; then snapshot=$1; shift; fi
      target="''${XDG_DATA_HOME:-$HOME/.local/share}/backup-restore/${name}/$(date +%Y%m%dT%H%M%S)"
      if [ "$#" -ge 2 ] && [ "$1" = "--target" ]; then target=$2; shift 2; fi
      if [ "$#" -ne 0 ]; then echo "usage: backup-restore ${name} [snapshot] [--target PATH]" >&2; exit 2; fi
      if [ -e "$target" ]; then
        if [ ! -d "$target" ]; then echo "restore target exists and is not a directory: $target" >&2; exit 2; fi
        shopt -s dotglob nullglob
        existing=("$target"/*)
        if [ "''${#existing[@]}" -gt 0 ]; then echo "restore target is not empty: $target" >&2; exit 2; fi
      fi
      mkdir -p -- "$target"
      restic restore "$snapshot" --target "$target"
      printf 'Restored into staging directory: %s\n' "$target"
      ;;
  '') repositories;
  makeRepositoryCommand =
    name: usage: command:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.restic ] ++ repositoryRuntimeInputs;
      text = ''
        repository=''${1:-}
        if [ -z "$repository" ] || [ "$#" -ne 1 ]; then echo "usage: ${usage}" >&2; exit 2; fi
        case "$repository" in
          ${repositoryCases command}
          *) echo "unknown backup repository: $repository" >&2; exit 2 ;;
        esac
      '';
    };
in
{
  inherit repositoryRuntimeInputs;
  backupCheck = makeRepositoryCommand "backup-check" "backup-check REPOSITORY" (
    _: "exec restic check"
  );
  backupInit = makeRepositoryCommand "backup-init" "backup-init REPOSITORY" (_: "exec restic init");
  backupSnapshots = makeRepositoryCommand "backup-snapshots" "backup-snapshots REPOSITORY" (
    _: "exec restic snapshots --host ${lib.escapeShellArg hostName}"
  );
  backupStatus = pkgs.writeShellApplication {
    name = "backup-status";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      class=''${1:-}
      if [ "$#" -gt 1 ]; then echo "usage: backup-status [critical|valuable|rebuildable]" >&2; exit 2; fi
      if [ -z "$class" ]; then
        for status_file in \
          "''${XDG_STATE_HOME:-$HOME/.local/state}/storage/backup/critical.status" \
          "''${XDG_STATE_HOME:-$HOME/.local/state}/storage/backup/valuable.status" \
          "''${XDG_STATE_HOME:-$HOME/.local/state}/storage/backup/rebuildable.status"; do
          if [ -f "$status_file" ]; then cat "$status_file"; printf '\n'; fi
        done
      else
        case "$class" in
          ${statusCases}
          *) echo "unknown backup class: $class" >&2; exit 2 ;;
        esac
      fi
    '';
  };
  backupRestore = pkgs.writeShellApplication {
    name = "backup-restore";
    runtimeInputs = [
      pkgs.restic
      pkgs.coreutils
    ]
    ++ repositoryRuntimeInputs;
    text = ''
      repository=''${1:-}
      if [ -z "$repository" ]; then echo "usage: backup-restore REPOSITORY [SNAPSHOT] [--target PATH]" >&2; exit 2; fi
      case "$repository" in
        ${lib.concatStringsSep "\n" restoreCases}
        *) echo "unknown backup repository: $repository" >&2; exit 2 ;;
      esac
    '';
  };
}
