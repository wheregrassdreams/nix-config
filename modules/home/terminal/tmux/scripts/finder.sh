# shellcheck shell=bash
SOURCE_CMD="$(
  cat <<'EOF'
tmux list-windows -a -F $'#{?session_attached,1,0}#{?window_active,1,0}#{session_last_attached}\t#{session_name}\t#{session_name}:#{window_index}\t\e[38;5;245m#{session_name}\e[0m\t\e[38;2;222;222;222m#{window_name}\e[0m\t\e[38;2;103;103;103m#{?session_attached,#{?window_active,(current),},} #{?window_last_flag,,}\e[0m' |
sort -rnk1
EOF
)"

fzf_header() {
  printf '\033[38;2;103;103;103menter\033[0m switch to   \033[38;2;103;103;103m^x\033[0m kill    \033[38;2;103;103;103m^/\033[0m preview    \033[38;2;103;103;103mtab\033[0m multi'
}

if selected_windows="$(
  sh -c "$SOURCE_CMD" |
    fzf --tmux --ansi \
    --delimiter=$'\t' \
    --with-nth=4,5,6 \
    --tabstop=12 \
    --prompt=' ' \
    --preview 'tmux capture-pane -ep -S -200 -E 1 -t {3}' \
    --preview-window +190 \
    --header "$(fzf_header)" \
    --bind 'ctrl-x:execute-silent(printf "%s\n" {+3} | xargs -r -n1 tmux kill-window -t)+reload:'"$SOURCE_CMD"
)"; then
  :
else
  fzf_status=$?
  case "$fzf_status" in
    1 | 130) exit 0 ;;
    *) exit "$fzf_status" ;;
  esac
fi

[[ -n $selected_windows ]] || exit 0

targets="$(cut -f 3 <<< "$selected_windows")"
while IFS= read -r target; do
  [[ -n $target ]] && tmux switch-client -t "$target"
done <<< "$targets"
