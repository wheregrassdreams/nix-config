{ lib }:
root:
let
  ignoredDirectoryNames = [ "lib" "module" ];

  discover = path: segments:
    let
      entries = builtins.readDir path;
      names = builtins.attrNames entries;
      isDirectory = name: entries.${name} == "directory";
      childDirectories = builtins.filter
        (name: isDirectory name && !(builtins.elem name ignoredDirectoryNames))
        names;
    in
    if entries ? "default.nix" then
      [ (lib.nameValuePair (lib.concatStringsSep "." segments) (import path)) ]
    else
      lib.concatMap
        (name: discover (path + "/" + name) (segments ++ [ name ]))
        childDirectories;
in
lib.listToAttrs (discover root [])
