{
  hostName,
  isDarwin,
  lib,
  pathsFor,
  pkgs,
  repositoryEnvironment,
  repositoryPathFor,
}:
class: policy: repository:
let
  resolved = repositoryPathFor policy.repository repository;
  retentionArgs = lib.concatStringsSep " " (
    lib.filter (value: value != "") [
      (lib.optionalString (policy.retention.daily > 0) "--keep-daily ${toString policy.retention.daily}")
      (lib.optionalString (
        policy.retention.weekly > 0
      ) "--keep-weekly ${toString policy.retention.weekly}")
      (lib.optionalString (
        policy.retention.monthly > 0
      ) "--keep-monthly ${toString policy.retention.monthly}")
    ]
  );
  paths = lib.escapeShellArgs (pathsFor class);
  pathChecks = lib.concatMapStringsSep "\n" (path: ''
    if [ ! -e ${lib.escapeShellArg path} ]; then
      printf 'backup source is missing: %s\n' ${lib.escapeShellArg path} >&2
      exit 1
    fi
  '') (pathsFor class);
  initIfMissing = lib.optionalString repository.initIfMissing ''
    ensure_repository() {
      local status
      if restic cat config >/dev/null 2>&1; then
        return 0
      else
        status=$?
      fi

      if [ "$status" -ne 10 ]; then
        echo "could not check Restic repository (exit $status); refusing to initialize" >&2
        return "$status"
      fi

      if restic init; then
        return 0
      fi

      # Another scheduled/manual run may have initialized it concurrently.
      if restic cat config >/dev/null 2>&1; then
        return 0
      fi

      echo "Restic repository initialization failed" >&2
      return 1
    }
    ensure_repository
  '';
  notifyFailure =
    if isDarwin then
      ''
        if [ -x /usr/bin/osascript ]; then
          /usr/bin/osascript -e 'display notification "Backup failed; inspect the job log." with title "Nix backup"' >/dev/null 2>&1 || true
        fi
      ''
    else
      ''
        if command -v notify-send >/dev/null 2>&1; then notify-send "Nix backup" "Backup failed; inspect the user journal." || true; fi
      '';
in
pkgs.writeShellApplication {
  name = "backup-run-${class}";
  runtimeInputs = resolved.runtimeInputs ++ lib.optionals (!isDarwin) [ pkgs.libnotify ];
  text = ''
    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/storage/backup/${class}.status"
    started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    write_status() {
      local result="$1"
      local exit_code="$2"
      local finished_at="$3"
      local temp_file="''${state_file}.tmp.$$"
      mkdir -p -- "$(dirname "$state_file")"
      {
        printf 'class=%s\n' ${lib.escapeShellArg class}
        printf 'status=%s\n' "$result"
        printf 'started_at=%s\n' "$started_at"
        printf 'finished_at=%s\n' "$finished_at"
        printf 'exit_code=%s\n' "$exit_code"
      } > "$temp_file"
      mv -f -- "$temp_file" "$state_file"
    }
    finish() {
      local exit_code=$?
      trap - EXIT
      local finished_at
      finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      if [ "$exit_code" -eq 0 ]; then
        write_status success "$exit_code" "$finished_at"
      else
        write_status failure "$exit_code" "$finished_at"
        notify_failure
      fi
      exit "$exit_code"
    }
    notify_failure() {
      ${notifyFailure}
    }
    trap finish EXIT
    write_status running 0 ""
    ${repositoryEnvironment policy.repository repository}
    ${initIfMissing}
    ${pathChecks}
    restic backup --host ${lib.escapeShellArg hostName} --tag ${lib.escapeShellArg "class:${class}"} -- ${paths}
    restic forget ${retentionArgs} --prune
    restic check
  '';
}
