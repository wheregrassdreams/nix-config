{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs ../treefmt.nix;
    in
    {
      formatter = treefmt.config.build.wrapper;
      packages.nix-fast-build = inputs.nix-fast-build.packages.${system}.default;

      # No git hooks are installed. git-hooks.nix wrote hooks whose interpreter
      # is a bare /nix/store path; those paths are not GC roots, so a garbage
      # collection left hooks that fail with "bad interpreter" and block every
      # commit and push. Run `just fmt` and `just check` explicitly instead.
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          age
          deadnix
          just
          nodejs
          nixd
          # nixfmt-rfc-style
          python3
          shellcheck
          shfmt
          sops
          statix
          inputs.nix-fast-build.packages.${system}.default
        ];
      };
    };
}
