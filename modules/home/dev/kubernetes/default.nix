{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.kubernetes;
in
{
  options.my.dev.kubernetes.minimal = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Install only kubectl and k9s instead of the full Kubernetes CLI toolkit.";
  };

  config = {
    home.packages = with pkgs;
      [
        kubectl
        k9s
      ]

      ++ lib.optionals (!cfg.minimal)
      [
        kubernetes-helm
        kustomize
        kubectx
        stern
        fluxcd
      ];

  };
}
