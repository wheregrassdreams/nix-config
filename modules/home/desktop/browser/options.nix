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
        "orion"
        "zen"
      ];
      default = "safari";
      description = "macOS default browser";
    };
  };

  config.assertions = [
    {
      assertion =
        cfg.default != "chrome" || cfg.chrome.enable;
      message = "my.desktop.browser.default is chrome, but Chrome is disabled";
    }
    {
      assertion = cfg.default != "zen" || cfg.zen.enable;
      message = "my.desktop.browser.default is zen, but Zen is disabled";
    }
    {
      assertion = cfg.default != "orion" || cfg.orion.enable;
      message = "my.desktop.browser.default is orion, but Orion is disabled";
    }
  ];
}
