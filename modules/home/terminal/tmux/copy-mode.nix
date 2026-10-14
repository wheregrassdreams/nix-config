{
  config,
  lib,
  isDarwin,
  ...
}:
let
  data = import ./bindings-data.nix { };
  render = binding: "bind -T copy-mode-vi ${binding.key} ${binding.command}";
  copy = if isDarwin then "copy-pipe \"pbcopy\"" else "copy-selection";
in
{
  config = lib.mkIf (config.my.terminal.enable && config.my.terminal.tmux.enable) {
    programs.tmux.extraConfig = lib.mkAfter ''
      setw -g mode-keys vi
      bind -T copy-mode-vi y send -X ${copy}
      ${lib.concatMapStringsSep "\n" render data.copyMode}
    '';
  };
}
