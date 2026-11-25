{
  config,
  isDarwin,
  lib,
  mylib,
  ...
}:
{
  imports = [
    (mylib.assertPlatform {
      package = "ai.magpie";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals isDarwin [ ../../homebrew ];

  config = lib.mkIf isDarwin {
    my.homebrew.casks = [ "magpie" ];

    # magpie has no separate CLI package: the app binary is the CLI. Link it
    # into ~/.local/bin, which is already on PATH, rather than letting the app
    # write to a shell profile. zsh here reads its startup files from ZDOTDIR
    # (~/.config/zsh, home-manager generated), so an entry added to ~/.zshrc or
    # ~/.zprofile would never be read and would not survive a rebuild.
    # mkOutOfStoreSymlink keeps the ~100 MB binary out of the nix store and
    # stays valid when the app updates itself in place.
    home.file.".local/bin/magpie".source =
      config.lib.file.mkOutOfStoreSymlink "/Applications/magpie.app/Contents/MacOS/magpie";
  };
}
