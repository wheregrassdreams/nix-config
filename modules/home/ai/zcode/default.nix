{
  isDarwin,
  lib,
  repoLib,
  ...
}:
{
  imports = [
    (repoLib.assertPlatform {
      package = "ai.zcode";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals isDarwin [ ../../homebrew ];

  config = lib.mkIf isDarwin {
    my.homebrew.casks = [ "zcode" ];
  };
}
