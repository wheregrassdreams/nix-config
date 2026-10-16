# shellcheck shell=bash
list_windows() {
  tmux list-windows -a -F $'#{?session_attached,1,0}#{?window_active,1,0}#{session_last_attached}\t#{window_id}\t#{session_id}:#{window_id}\t\e[38;5;245m#{session_name}\e[0m\t\e[38;2;222;222;222m#{window_name}\e[0m\t\e[38;2;103;103;103m#{?session_attached,#{?window_active,(current),},} #{?window_last_flag,,}\e[0m' |
    sort -rnk1
}

kill_windows() {
  (($# > 0)) || return 0

  declare -A selected=()
  for window_id in "$@"; do
    selected["$window_id"]=1
  done

  current_target="$(tmux display-message -p '#{session_id}:#{window_id}')"
  current_session="${current_target%%:*}"
  current_window="${current_target##*:}"

  if [[ -n ${selected[$current_window]+selected} ]]; then
    fallback_target=""
    while IFS=$'\t' read -r _ candidate_window candidate_target; do
      if [[ -z ${selected[$candidate_window]+selected} ]]; then
        fallback_target="$candidate_target"
        break
      fi
    done < <(
      tmux list-windows -a -F $'#{?session_attached,1,0}#{?window_active,1,0}#{session_last_attached}\t#{window_id}\t#{session_id}:#{window_id}' |
        sort -rnk1
    )

    if [[ -z $fallback_target ]]; then
      fallback_target="$(tmux new-window -d -P -F '#{session_id}:#{window_id}' -t "$current_session")"
    fi

    tmux switch-client -t "$fallback_target"
  fi

  for window_id in "$@"; do
    tmux kill-window -t "$window_id"
  done
}

case "${1-}" in
  --list)
    list_windows
    exit 0
    ;;
  --kill)
    shift
    kill_windows "$@"
    exit 0
    ;;
esac

fzf_header() {
  printf '\033[38;2;103;103;103menter\033[0m switch to   \033[38;2;103;103;103m^x\033[0m kill    \033[38;2;103;103;103m^/\033[0m preview    \033[38;2;103;103;103mtab\033[0m multi'
}

if selected_windows="$(
  list_windows |
    fzf --tmux --ansi \
      --delimiter=$'\t' \
      --with-nth=4,5,6 \
      --tabstop=12 \
      --prompt=' ' \
      --preview 'tmux capture-pane -ep -S -200 -E 1 -t {3}' \
      --preview-window +190 \
      --header "$(fzf_header)" \
      --bind "ctrl-x:execute-silent($0 --kill {+2})+reload($0 --list)"
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
