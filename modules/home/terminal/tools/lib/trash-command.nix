{ pkgs }:
let
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.send2trash ]);
in
pkgs.writeShellApplication {
  name = "trash";
  runtimeInputs = [ python ];
  text = ''
    exec send2trash "$@"
  '';
}
