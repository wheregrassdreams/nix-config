{ ... }:
final: prev:
let
  pythonEnv = final.python3.withPackages (pythonPackages: [ pythonPackages.libtmux ]);
in
{
  tmuxPlugins = prev.tmuxPlugins // {
    tmux-window-name = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "tmux-window-name";
      rtpFilePath = "tmux_window_name.tmux";
      version = "unstable-2026-10-17";
      src = final.fetchFromGitHub {
        owner = "ofirgall";
        repo = "tmux-window-name";
        rev = "c32497f249888c3f98cb245f78a0bcc8d05b2a46";
        hash = "sha256-gBNgLG3NGSd6zF8SuzXCNPj1AbF1S18L5cgNdxQPQhA=";
      };
      postPatch = ''
        substituteInPlace tmux_window_name.tmux \
          --replace-fail 'python -c' '${pythonEnv}/bin/python -c'
        substituteInPlace scripts/rename_session_windows.py \
          --replace-fail '#!/usr/bin/env python3' '#!${pythonEnv}/bin/python3'
      '';
      meta = {
        description = "Name tmux windows smartly based on directories and running programs";
        homepage = "https://github.com/ofirgall/tmux-window-name";
        license = final.lib.licenses.mit;
        platforms = final.lib.platforms.unix;
      };
    };
  };
}
