{ config, lib, ... }:
let
  cfg = config.my.storage.remote;
  targets = import ./lib/targets.nix { inherit lib; };
  gitBackend = lib.types.submodule {
    options = {
      sshHost = lib.mkOption {
        type = lib.types.str;
        description = "SSH config alias used by Git clients and provisioning.";
      };
      root = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Absolute directory under which remote bare repositories are created.";
      };
    };
  };
  s3Backend = lib.types.submodule {
    options = {
      endpoint = lib.mkOption { type = lib.types.str; };
      bucket = lib.mkOption { type = lib.types.str; };
      prefix = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };
  webdavBackend = lib.types.submodule {
    options = {
      endpoint = lib.mkOption { type = lib.types.str; };
      root = lib.mkOption { type = lib.types.str; };
    };
  };
  targetType = lib.types.submodule {
    options = {
      backend = {
        git = lib.mkOption {
          type = lib.types.nullOr gitBackend;
          default = null;
        };
        s3 = lib.mkOption {
          type = lib.types.nullOr s3Backend;
          default = null;
        };
        webdav = lib.mkOption {
          type = lib.types.nullOr webdavBackend;
          default = null;
        };
      };
      provisioner = {
        kind = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "sshBare" "gitea" "giteaPreprovisioned" ]);
          default = null;
          description = "Remote repository provisioning strategy.";
        };
        gitea = {
          apiUrl = lib.mkOption { type = lib.types.str; default = ""; };
          organization = lib.mkOption { type = lib.types.str; default = ""; };
          tokenFile = lib.mkOption { type = lib.types.str; default = ""; };
          repository = lib.mkOption { type = lib.types.str; default = ""; };
        };
      };
    };
  };
  targetAssertions = lib.concatMap (
    name:
    let
      target = cfg.targets.${name};
    in
    [
      {
        assertion = targets.backendCount target == 1;
        message = "my.storage.remote.targets.${name}: select exactly one backend.";
      }
      {
        assertion = target.provisioner.kind == null || target.backend.git != null;
        message = "my.storage.remote.targets.${name}: provisioner is supported only for Git targets.";
      }
      {
        assertion =
          target.backend.git == null
          || (
            target.backend.git.sshHost != ""
            && (
              (builtins.elem target.provisioner.kind [ "gitea" "giteaPreprovisioned" ] && target.backend.git.root == null)
              || (target.provisioner.kind != "gitea" && target.backend.git.root != null && lib.hasPrefix "/" target.backend.git.root && target.backend.git.root != "/")
            )
          );
        message = "my.storage.remote.targets.${name}.backend.git needs an SSH alias and a compatible root.";
      }
      {
        assertion = target.provisioner.kind != "gitea" || (
          target.backend.git != null
          && target.backend.git.root == null
          && builtins.match "https://[^/?#@]+(/[^?#]*)?" target.provisioner.gitea.apiUrl != null
          && !(lib.hasInfix "\n" target.provisioner.gitea.apiUrl)
          && builtins.match "[A-Za-z0-9][A-Za-z0-9_.-]*" target.provisioner.gitea.organization != null
          && target.provisioner.gitea.organization != "."
          && target.provisioner.gitea.organization != ".."
          && target.provisioner.gitea.tokenFile != ""
          && lib.hasPrefix "/" target.provisioner.gitea.tokenFile
        );
        message = "my.storage.remote.targets.${name}.provisioner.gitea needs a valid Git SSH target, HTTPS API base URL, organization path segment, and absolute external token file.";
      }
      {
        assertion = target.provisioner.kind != "giteaPreprovisioned" || (
          target.backend.git != null
          && target.backend.git.root == null
          && builtins.match "[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*" target.provisioner.gitea.repository != null
        );
        message = "my.storage.remote.targets.${name}.provisioner.gitea.repository must be owner/repository for a pre-provisioned repository target.";
      }
      {
        assertion =
          target.backend.s3 == null
          || (
            builtins.match "https?://[^/?#@]+(/[^?#]*)?" target.backend.s3.endpoint != null
            && target.backend.s3.bucket != ""
            && !(lib.hasInfix "\n" target.backend.s3.endpoint)
          );
        message = "my.storage.remote.targets.${name}.backend.s3 needs an HTTP(S) endpoint without credentials, query, or fragment, and a bucket.";
      }
      {
        assertion =
          target.backend.s3 == null
          || (
            !(lib.hasPrefix "/" target.backend.s3.prefix)
            && !(targets.hasParentSegment target.backend.s3.prefix)
          );
        message = "my.storage.remote.targets.${name}.backend.s3.prefix must stay within its bucket.";
      }
      {
        assertion =
          target.backend.webdav == null
          || (target.backend.webdav.endpoint != "" && target.backend.webdav.root != "");
        message = "my.storage.remote.targets.${name}.backend.webdav needs endpoint and root.";
      }
      {
        assertion = target.backend.webdav == null || !(targets.hasParentSegment target.backend.webdav.root);
        message = "my.storage.remote.targets.${name}.backend.webdav.root cannot contain parent-directory segments.";
      }
    ]
  ) (builtins.attrNames cfg.targets);
in
{
  options.my.storage.remote.targets = lib.mkOption {
    type = lib.types.attrsOf targetType;
    default = { };
    description = "Shared remote endpoints; backup and snapshot products own their policies.";
  };

  config.assertions = targetAssertions;
}
