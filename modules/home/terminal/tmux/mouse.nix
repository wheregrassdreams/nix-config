{ ... }:
{
  config.programs.tmux.extraConfig = ''
    # Keep a mouse selection visible after releasing the button, and clear it
    # when clicking elsewhere. tmux has separate vi and non-vi copy-mode tables.
    bind -T copy-mode-vi MouseUp1Pane send -X clear-selection
    bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection-no-clear
    bind -T copy-mode MouseUp1Pane send -X clear-selection
    bind -T copy-mode MouseDragEnd1Pane send -X copy-selection-no-clear

    # tmux 3.8 keeps copy mode live as pane output changes when refresh-on is
    # enabled. Start it whenever a pane enters copy mode; tmux pauses refresh
    # while a selection is active and resumes when it is cleared.
    set-hook -g pane-mode-entered[copy-mode-refresh] 'if-shell -F "#{==:#{pane_mode},copy-mode}" { send-keys -X refresh-on }'

    # Pass right-clicks through to applications that own the mouse. Otherwise
    # open the pane menu on release and keep it open after the button is released.
    #
    # Floating-pane menu entries retained for tmux 3.8+, where move-pane gained
    # the -P placement flag. Keep these commented until intentionally enabled:
    #
    # "#{?#{#{pane_floating_flag}},Move,}" ''' { display-menu -T "#[align=centre]Move" -x L -y L Centre c { move-pane -P centre } ''' "Top Left" 1 { move-pane -P top-left } "Top Right" 2 { move-pane -P top-right } "Bottom Left" 3 { move-pane -P bottom-left } "Bottom Right" 4 { move-pane -P bottom-right } ''' Top t { move-pane -P top-centre } Bottom b { move-pane -P bottom-centre } Left l { move-pane -P centre-left } Right r { move-pane -P centre-right } }
    # "#{?#{#{pane_floating_flag}},Move & Resize,}" ''' { display-menu -T "#[align=centre]Move & Resize" -x L -y L Fill 0 { resize-pane -x "100%" -y "100%" ; move-pane -P top-left } ''' "Top Left" 1 { resize-pane -x "50%" -y "50%" ; move-pane -P top-left } "Top Right" 2 { resize-pane -x "50%" -y "50%" ; move-pane -P top-right } "Bottom Left" 3 { resize-pane -x "50%" -y "50%" ; move-pane -P bottom-left } "Bottom Right" 4 { resize-pane -x "50%" -y "50%" ; move-pane -P bottom-right } ''' Top t { resize-pane -x "100%" -y "50%" ; move-pane -P top-centre } Bottom b { resize-pane -x "100%" -y "50%" ; move-pane -P bottom-centre } Left l { resize-pane -x "50%" -y "100%" ; move-pane -P centre-left } Right r { resize-pane -x "50%" -y "100%" ; move-pane -P centre-right } }
    bind-key -T root MouseDown3Pane if-shell -F -t = "#{||:#{mouse_any_flag},#{&&:#{pane_in_mode},#{?#{m/r:(copy|view)-mode,#{pane_mode}},0,1}}}" { select-pane -t "#{mouse_pane}" ; send-keys -M -t "#{mouse_pane}" }
    bind-key -T root MouseUp3Pane if-shell -F -t = "#{||:#{mouse_any_flag},#{&&:#{pane_in_mode},#{?#{m/r:(copy|view)-mode,#{pane_mode}},0,1}}}" { send-keys -M } { display-menu -O -T "#[align=centre]#{pane_index} (#{pane_id})" -t = -x M -y M "#{?#{m/r:(copy|view)-mode,#{pane_mode}},Go To Top,}" < { send-keys -X history-top } "#{?#{m/r:(copy|view)-mode,#{pane_mode}},Go To Bottom,}" > { send-keys -X history-bottom } "#{?mouse_word,Copy #[underscore]#{=/24/…:mouse_word},}" c { copy-mode -q ; set-buffer "#{q:mouse_word}" } "Horizontal Split" h { split-window -h -c "#{pane_current_path}" } "Vertical Split" v { split-window -v -c "#{pane_current_path}" } "#{?#{>:#{window_panes},1},Swap Up,}" u { swap-pane -U } "#{?#{>:#{window_panes},1},Swap Down,}" d { swap-pane -D } "#{?#{>:#{window_panes},1},Zoom,Unzoom}" z { resize-pane -Z } Kill X { kill-pane } }
  '';
}
