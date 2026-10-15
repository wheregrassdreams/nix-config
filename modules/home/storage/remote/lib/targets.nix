{ lib }:
let
  backendNames = [
    "git"
    "s3"
    "webdav"
  ];
  pathSegments =
    path: lib.filter (segment: segment != "" && segment != ".") (lib.splitString "/" path);
in
{
  inherit backendNames;

  find = config: name: lib.attrByPath [ "my" "storage" "remote" "targets" name ] null config;

  backend =
    target: name: if target == null then null else lib.attrByPath [ "backend" name ] null target;

  backendCount =
    target:
    builtins.length (
      builtins.filter (name: (lib.attrByPath [ "backend" name ] null target) != null) backendNames
    );

  hasParentSegment = path: builtins.elem ".." (lib.splitString "/" path);

  joinPath = paths: lib.concatStringsSep "/" (lib.concatMap pathSegments paths);
}
