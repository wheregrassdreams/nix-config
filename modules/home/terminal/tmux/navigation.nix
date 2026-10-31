{ lib, ... }:
let
  bindings = [
    {
      key = "h";
      command = "select-pane -L";
    }
    {
      key = "j";
      command = "select-pane -D";
    }
    {
      key = "k";
      command = "select-pane -U";
    }
    {
      key = "l";
      command = "select-pane -R";
    }
    {
      key = "|";
      command = ''split-window -h -c "#{pane_current_path}"'';
    }
    {
      key = ''\\'';
      command = ''split-window -v -c "#{pane_current_path}"'';
    }
    {
      key = "r";
      command = ''command-prompt -I "#W" "rename-window '%%'"'';
    }
    {
      key = "R";
      command = ''command-prompt -I "#S" "rename-session '%%'"'';
    }
    {
      key = "n";
      command = "new-window";
    }
    {
      key = "N";
      command = "new-session";
    }
    {
      key = "C-l";
      command = "select-layout -o";
    }
    {
      key = "=";
      command = "select-layout even-horizontal";
    }
    {
      key = "+";
      command = "select-layout even-vertical";
    }
    {
      key = "]";
      command = "select-layout tiled";
    }
    {
      key = "@";
      command = ''choose-tree "join-pane -h -s '%%'"'';
    }
    {
      key = "x";
      command = "kill-pane";
    }
    {
      key = "X";
      command = "kill-window";
    }
    {
      key = "q";
      command = "kill-pane";
    }
    {
      key = "Q";
      command = "kill-window";
    }
    {
      key = "Enter";
      command = "resize-pane -Z";
    }
    {
      key = "Up";
      command = "resize-pane -U 3";
      repeat = true;
    }
    {
      key = "Down";
      command = "resize-pane -D 3";
      repeat = true;
    }
    {
      key = "Left";
      command = "resize-pane -L 3";
      repeat = true;
    }
    {
      key = "Right";
      command = "resize-pane -R 3";
      repeat = true;
    }
  ];
  keys = map (binding: binding.key) bindings;
  render =
    binding:
    "bind -T prefix ${
      lib.optionalString (binding.repeat or false) "-r "
    }${binding.key} ${binding.command}";
in
{
  config = {
    assertions = [
      {
        assertion = builtins.length keys == builtins.length (lib.unique keys);
        message = "tmux prefix bindings contain duplicate keys";
      }
    ];

    programs.tmux.extraConfig = lib.mkAfter (lib.concatMapStringsSep "\n" render bindings);
  };
}
