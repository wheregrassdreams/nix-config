{ ... }:
{
  targets.darwin.defaults = {
    # Use Caps Lock to switch between Latin and non-Latin input sources.
    NSGlobalDomain.TISRomanSwitchState = 1;

    # Disable macOS's input-source shortcuts; the input package owns these mappings.
    "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
      "60" = {
        enabled = false;
        value = {
          parameters = [ 65535 49 262144 ];
          type = "standard";
        };
      };
      "61" = {
        enabled = false;
        value = {
          parameters = [ 65535 49 786432 ];
          type = "standard";
        };
      };
    };
  };
}
