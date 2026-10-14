{ lib }:
packageRoot:
let
  root = toString packageRoot;
  files = lib.filesystem.listFilesRecursive packageRoot;
  isPackageEntry = path:
    let relative = lib.removePrefix "${root}/" (toString path);
    in relative == "default.nix" || relative == "options.nix";
  isImplementation = path:
    lib.hasPrefix "${root}/lib/" (toString path);
in
  builtins.filter (path: lib.hasSuffix ".nix" (toString path) && !isPackageEntry path && !isImplementation path) files
