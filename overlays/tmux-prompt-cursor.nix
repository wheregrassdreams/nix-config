{ inputs, ... }:
final: prev:
let
  source = inputs.tmux-prompt-cursor;
in
{
  tmuxPlugins = prev.tmuxPlugins // {
    tmux-prompt-cursor = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "tmux-prompt-cursor";
      version = "0.1.0";
      rtpFilePath = "tmux-prompt-cursor.tmux";
      src = source;
      postInstall = ''
        mkdir -p "$out/share/zsh"
        install -m644 ${source}/shell/tmux-prompt-cursor.zsh "$out/share/zsh/tmux-prompt-cursor.zsh"
      '';
      meta = {
        description = "Move the active Zsh prompt cursor by clicking its command line";
        homepage = "https://github.com/wheregrassdreams/tmux-prompt-cursor";
        license = final.lib.licenses.mit;
        platforms = final.lib.platforms.unix;
      };
    };
  };
}
