# This module is discovered with the rest of tmux's configuration, but remains
# inert until its generated data is consumed by a real feature.
{ pkgs, ... }:
let
  data = import ./_bindings-data.nix { };
  menu = {
    keybindings.prefix_table = "Space";
    items = map (binding: {
      key = binding.key;
      name = binding.command;
      command = binding.command;
    }) data.prefix;
  };
  yaml = (pkgs.formats.yaml { }).generate "tmux-which-key.yaml" menu;
in
{
  # Keep the generated data reachable for a future explicit opt-in without
  # loading the plugin or adding a user-facing option today.
  _module.args.tmuxWhichKeyYaml = yaml;
}
