{
  config,
  pkgs,
  lib,
  isDarwin,
  ...
}:
{
  config = lib.mkIf config.my.development.enable {
    programs.k9s.enable = true;
    home = {
      packages = with pkgs; [
        neovim
        sqlite
        sbcl
        uv
      ];
      sessionVariables = lib.optionalAttrs isDarwin {
        LIBRARY_PATH = "${pkgs.libiconv}/lib:$LIBRARY_PATH";
      };
    };
  };
}
