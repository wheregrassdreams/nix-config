{ lib }:
packageRoot:
let
  isExcludedName = name: lib.hasPrefix "_" name || name == "lib";
  optionsFile = packageRoot + "/options.nix";

  isModuleFile =
    name:
    lib.hasSuffix ".nix" name && name != "default.nix" && name != "options.nix" && !isExcludedName name;

  collect =
    directory:
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
        isPackage = isDirectory && builtins.pathExists (path + "/default.nix");
      in
      if isExcludedName name || isPackage then
        [ ]
      else if isDirectory then
        collect path
      else if entryType == "regular" && isModuleFile name then
        [ path ]
      else
        [ ]
    ) names;
in
lib.optional (builtins.pathExists optionsFile) optionsFile ++ collect packageRoot
