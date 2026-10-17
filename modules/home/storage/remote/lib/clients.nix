{ lib, pkgs }:
let
  targets = import ./targets.nix { inherit lib; };

  restic =
    {
      targetId,
      target,
      hostName,
      repositoryName,
      repositoryPath ? null,
      passwordFile,
      environmentFile ? null,
      rcloneConfigFile ? null,
    }:
    let
      s3 = targets.backend target "s3";
      webdav = targets.backend target "webdav";
      suffix =
        if repositoryPath != null then
          targets.joinPath [ repositoryPath ]
        else
          targets.joinPath [
            hostName
            repositoryName
          ];
      repository =
        if s3 != null then
          "s3:${lib.removeSuffix "/" s3.endpoint}/${
            targets.joinPath [
              s3.bucket
              s3.prefix
              suffix
            ]
          }"
        else if webdav != null then
          "rclone:${targetId}:${
            targets.joinPath [
              webdav.root
              suffix
            ]
          }"
        else
          null;
      environment =
        if repository == null then
          ""
        else
          ''
            export RESTIC_REPOSITORY=${lib.escapeShellArg repository}
            export RESTIC_PASSWORD_FILE=${lib.escapeShellArg passwordFile}
            ${lib.optionalString (environmentFile != null) ''
              set -a
              # shellcheck disable=SC1091 # SOPS provides this runtime-only file.
              . ${lib.escapeShellArg environmentFile}
              set +a
            ''}
            ${lib.optionalString (rcloneConfigFile != null) ''
              export RCLONE_CONFIG=${lib.escapeShellArg rcloneConfigFile}
            ''}
          '';
    in
    {
      inherit environment repository;
      runtimeInputs = [ pkgs.restic ] ++ lib.optionals (webdav != null) [ pkgs.rclone ];
    };

  git =
    target:
    let
      backend = targets.backend target "git";
    in
    {
      inherit target;
      runtimeInputs = [
        pkgs.git
        pkgs.openssh
      ];
      sshHost = if backend == null then null else backend.sshHost;
      root = if backend == null then null else backend.root;
    };
in
{
  inherit git restic;
}
