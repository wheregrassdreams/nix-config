{ pkgs, ... }:
let
  brewNixReport = pkgs.writeShellScriptBin "brew-nix-report" (
    builtins.readFile ./lib/nix-report.sh
  );
in
{
  home.packages = [ brewNixReport ];
}
