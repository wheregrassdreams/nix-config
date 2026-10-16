{ pkgs }:
(pkgs.buildGoModule.override {
  go = pkgs.unstable.go_1_27;
})
  {
    pname = "app-identity";
    version = "0.1.0";
    src = ./app-identity;
    vendorHash = null;
    subPackages = [ "." ];
    doCheck = false;
    postInstall = ''
      mv $out/bin/app-identity-cli $out/bin/app-identity
    '';
  }
