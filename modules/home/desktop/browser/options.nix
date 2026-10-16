{ config, lib, ... }:
let
  cfg = config.my.desktop.browser;
in
{
  options.my.desktop.browser = {
    chrome.enable = lib.mkEnableOption "Google Chrome";
    orion.enable = lib.mkEnableOption "Orion Browser";
    zen.enable = lib.mkEnableOption "Zen Browser";
    default = lib.mkOption {
      type = lib.types.enum [
        "safari"
        "chrome"
        "kagimacos"
        "zen"
      ];
      default = "safari";
      description = "Application key for the macOS default browser";
    };
  };

  config.assertions = [
    {
      assertion = cfg.default != "chrome" || cfg.chrome.enable;
      message = "my.desktop.browser.default is chrome, but Chrome is disabled";
    }
    {
      assertion = cfg.default != "zen" || cfg.zen.enable;
      message = "my.desktop.browser.default is zen, but Zen is disabled";
    }
    {
      assertion = cfg.default != "kagimacos" || cfg.orion.enable;
      message = "my.desktop.browser.default is kagimacos, but Orion is disabled";
    }
  ];
}
