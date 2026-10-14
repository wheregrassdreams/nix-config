{ lib }:
packageRoot:
let
  isExcludedName = name: lib.hasPrefix "_" name || name == "lib";

  isModuleFile = name: lib.hasSuffix ".nix" name && name != "default.nix" && !isExcludedName name;

  collect =
    directory: isRoot:
    let
      entries = builtins.readDir directory;
      names = builtins.attrNames entries;
    in
    lib.concatMap (
      name:
      let
        path = directory + "/${name}";
        entryType = entries.${name};
        isDirectory = entryType == "directory";
        isPackage = !isRoot && isDirectory && builtins.pathExists (path + "/default.nix");
      in
      if isExcludedName name || isPackage then
        [ ]
      else if isDirectory then
        collect path false
      else if isModuleFile name then
        [ path ]
      else
        [ ]
    ) names;
in
collect packageRoot true
