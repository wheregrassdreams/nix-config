{
  config,
  inputs,
  lib,
  system,
  ...
}:
{
  config = lib.mkIf config.my.development.rust.enable {
    home.packages = [
      (inputs.fenix.packages.${system}.stable.withComponents [
        "rustc"
        "cargo"
        "clippy"
        "rust-src"
        "rustfmt"
        "rust-analyzer"
      ])
    ];
    home.sessionPath = [ "$HOME/.cargo/bin" ];
  };
}
