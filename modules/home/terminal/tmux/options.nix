{ lib, ... }:
{
  options.my.terminal.tmux = {
    inputMethod = {
      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Command used to select an input method from tmux.";
      };

      prefixKey = lib.mkOption {
        type = lib.types.str;
        default = "C-a";
        description = "Key that enters tmux's prefix table.";
      };

      events = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { ... }:
            {
              options = {
                type = lib.mkOption {
                  type = lib.types.enum [
                    "prefix"
                    "hook"
                  ];
                  description = "tmux event source consumed by the input-method executor.";
                };
                hook = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "tmux hook name when type is hook.";
                };
              };
            }
          )
        );
        default = {
          prefix.type = "prefix";
          window.type = "hook";
          window.hook = "session-window-changed";
          pane.type = "hook";
          pane.hook = "pane-focus-in";
        };
        description = "Named tmux events that should select the default input method.";
      };
    };

    smartWindowNaming.enable = lib.mkEnableOption "smart tmux window naming";
  };
}
