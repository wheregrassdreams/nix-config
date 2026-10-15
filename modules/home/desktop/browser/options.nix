{ config, lib, ... }:
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
        config.my.desktop.browser.default != "chrome" || config.my.desktop.browser.chrome.enable;
      message = "my.desktop.browser.default is chrome, but Chrome is disabled";
    }
    {
      assertion = config.my.desktop.browser.default != "zen" || config.my.desktop.browser.zen.enable;
      message = "my.desktop.browser.default is zen, but Zen is disabled";
    }
    {
      assertion = config.my.desktop.browser.default != "orion" || config.my.desktop.browser.orion.enable;
      message = "my.desktop.browser.default is orion, but Orion is disabled";
    }
  ];
}
