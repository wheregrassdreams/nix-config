{ lib, ... }:
{
  config.programs.tmux.extraConfig = lib.mkBefore ''
    # Match the shared tmux-config palette. Status-line and prompt rendering
    # remain owned by tmux-statusbar, whose color options are mapped to these.
    set-option -g @palette-bg '#111111'
    set-option -g @palette-surface '#1B1B1B'
    set-option -g @float-bg '#1B1B1B'
    set-option -g @palette-border '#303030'
    set-option -g @palette-border-active '#686868'
    set-option -g @palette-text '#D8D8D8'
    set-option -g @palette-text-dim '#A0A0A0'
    set-option -g @palette-muted '#696969'
    set-option -g @palette-muted-strong '#777777'
    set-option -g @palette-accent '#CBA6F7'
    set-option -g @palette-selection-bg '#555555'
    set-option -g @palette-selection-fg '#E0E0E0'
    set-option -g @palette-picker-selection-bg '#262626'
    set-option -g @palette-hint-key '#777777'
    set-option -g @palette-hint-label '#4D4D4D'
    set-option -g @palette-attention '#FF1744'

    # Map the standalone status bar's public color options to this palette.
    set-option -gF @tmux-statusbar-bg-session '#{@palette-surface}'
    set-option -gF @tmux-statusbar-fg '#{@palette-muted}'
    set-option -gF @tmux-statusbar-fg-current '#{@palette-text}'
    set-option -gF @tmux-statusbar-fg-session '#{@palette-muted}'
    set-option -gF @tmux-statusbar-fg-prefix '#{@palette-bg}'
    set-option -gF @tmux-statusbar-bg-prefix '#{@palette-accent}'
    set-option -gF @tmux-statusbar-fg-accent '#{@palette-accent}'
    set-option -gF @tmux-statusbar-fg-message '#{@palette-text}'
    set-option -gF @tmux-statusbar-bg-message '#{@palette-surface}'
    set-option -gF @tmux-statusbar-bg-command '#{@palette-surface}'

    set-option -g mode-style 'noattr,bg=#{@palette-accent},fg=#{@palette-bg}'
    set-window-option -g copy-mode-position-format '#[align=right]#{?selection_present,#[fg=#{@palette-accent}]#{?rectangle_toggle,BLOCK,#{selection_mode}} #[fg=#{@palette-muted}]L#{e|+|:#{selection_start_y},1}:C#{e|+|:#{selection_start_x},1}–L#{e|+|:#{selection_end_y},1}:C#{e|+|:#{selection_end_x},1},#[fg=#{@palette-muted}]#{?#{==:#{copy_position},0},BOTTOM,↑ #{copy_position}}}'
    set-window-option -gF copy-mode-position-style 'noattr,fg=#{@palette-muted},bg=default'
    set-window-option -g copy-mode-selection-style 'fg=#{@palette-selection-fg},bg=#{@palette-selection-bg}'
    set-option -gF menu-style 'fg=#{@palette-text},bg=#{@palette-surface}'
    set-option -gF menu-border-style 'fg=#{@palette-border},bg=#{@palette-surface}'
    set-option -gF menu-selected-style 'fg=#{@palette-bg},bg=#{@palette-accent}'
    set-option -g pane-border-style 'fg=#{@palette-border},bg=default'
    set-option -g pane-active-border-style 'fg=#{@palette-border-active},bg=default'
    # Floating panes use the same surface as popup panes while tiled panes keep
    # their terminal-default background.
    set-window-option -g window-style 'bg=#{?pane_floating_flag,#{@float-bg},default}'
    set-window-option -g window-active-style 'bg=#{?pane_floating_flag,#{@float-bg},default}'
    set-option -gF popup-style 'bg=#{@float-bg}'
    set-option -gF popup-border-style 'fg=#{@palette-border},bg=#{@float-bg}'
  '';
}
