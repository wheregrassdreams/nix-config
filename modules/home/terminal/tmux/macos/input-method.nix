{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.terminal.tmux.inputMethod;
  hasPrefixEvent = lib.any (event: event.type == "prefix") (lib.attrValues cfg.events);
  hooks = lib.unique (
    lib.filter (hook: hook != null) (
      map (event: event.hook) (lib.filter (event: event.type == "hook") (lib.attrValues cfg.events))
    )
  );
  selectEnglish = pkgs.writeShellScript "tmux-select-english" ''
    exec ${
      lib.escapeShellArgs [
        cfg.command
        "com.apple.keylayout.ABC"
      ]
    }
  '';
  runSelectEnglish = "run-shell -b ${lib.escapeShellArg "${selectEnglish}"}";
  prefixBinding = lib.optionalString hasPrefixEvent ''
    bind-key -T root ${cfg.prefixKey} ${runSelectEnglish} \; switch-client -T prefix
    bind-key -T prefix ${cfg.prefixKey} send-keys ${cfg.prefixKey}
  '';
  hookBindings = lib.concatMapStringsSep "\n" (hook: ''
    set-hook -g ${lib.escapeShellArg hook} ${runSelectEnglish}
  '') hooks;
in
{
  config = lib.mkIf (cfg.command != null) {
    assertions = [
      {
        assertion = lib.all (event: event.type != "hook" || event.hook != null) (lib.attrValues cfg.events);
        message = "tmux inputMethod hook events must set a hook name";
      }
      {
        assertion =
          builtins.length (lib.filter (event: event.type == "prefix") (lib.attrValues cfg.events)) <= 1;
        message = "tmux inputMethod.events may define at most one prefix event";
      }
    ];

    programs.tmux.extraConfig = lib.mkAfter ''
      ${prefixBinding}
      ${hookBindings}
    '';
  };
}
