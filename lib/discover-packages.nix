{ lib }:
root:
let
  isExcludedName = name: lib.hasPrefix "_" name || name == "lib";

  discover =
    path: segments:
    let
      entries = builtins.readDir path;
      names = builtins.attrNames entries;
      childDirectories = builtins.filter (
        name: entries.${name} == "directory" && !isExcludedName name
      ) names;
      package = lib.optionalAttrs (entries ? "default.nix") {
        ${lib.concatStringsSep "." segments} = import path;
      };
      children = lib.foldl' (
        result: name: result // discover (path + "/${name}") (segments ++ [ name ])
      ) { } childDirectories;
    in
    package // children;
in
discover root [ ]
