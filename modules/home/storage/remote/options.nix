{ config, lib, ... }:
let
  targets = import ./lib/targets.nix { inherit lib; };
  gitBackend = lib.types.submodule {
    options = {
      sshHost = lib.mkOption {
        type = lib.types.str;
        description = "SSH config alias used by Git clients and provisioning.";
      };
      root = lib.mkOption {
        type = lib.types.str;
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
      provisioner.kind = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "sshBare" ]);
        default = null;
        description = "Remote repository creation strategy, when supported.";
      };
    };
  };
  targetAssertions = lib.concatMap (
    name:
    let
      target = config.my.storage.remote.targets.${name};
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
          || (target.backend.git.sshHost != "" && lib.hasPrefix "/" target.backend.git.root);
        message = "my.storage.remote.targets.${name}.backend.git needs an SSH alias and absolute root path.";
      }
      {
        assertion =
          target.backend.s3 == null || (target.backend.s3.endpoint != "" && target.backend.s3.bucket != "");
        message = "my.storage.remote.targets.${name}.backend.s3 needs endpoint and bucket.";
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
  ) (builtins.attrNames config.my.storage.remote.targets);
in
{
  options.my.storage.remote.targets = lib.mkOption {
    type = lib.types.attrsOf targetType;
    default = { };
    description = "Shared remote endpoints; backup and snapshot products own their policies.";
  };

  config.assertions = targetAssertions;
}
