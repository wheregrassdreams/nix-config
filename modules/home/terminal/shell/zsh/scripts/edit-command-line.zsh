# shellcheck disable=SC2148,SC2034
# ============================================================================
# Functions
# ============================================================================


autoload -U edit-command-line
zle -N edit-command-line

function custom_edit_command_line() {
  if [[ -n "$TMUX" ]]; then
    tmux_edit_command_line
  else
    zle edit-command-line
  fi
  echo -ne '\e[5 q'
}

function tmux_edit_command_line() {
  _tmux_float_edit_buffer
}

function _tmux_float_edit_buffer() {
  local float_root tmpfile editor_status
  float_root=${TMUX_FLOAT_LAB_ROOT:-$(tmux show-option -gqv @float-lab-root 2>/dev/null)}
  [[ -n "$float_root" && -x "$float_root/bin/float-edit-file" ]] || return 1

  tmpfile=$(mktemp "${TMPDIR:-/tmp}/tmux-float-edit.XXXXXX") || return
  print -r -- "$BUFFER" > "$tmpfile"
  VISUAL=${VISUAL-} EDITOR=${EDITOR-} \
    "$float_root/bin/float-edit-file" --output none --title 'Edit prompt' "$tmpfile"
  editor_status=$?
  (( editor_status == 130 )) && editor_status=0
  [[ -f "$tmpfile" ]] && BUFFER=$(<"$tmpfile")
  command rm -f -- "$tmpfile"
  CURSOR=${#BUFFER}
  zle reset-prompt
  zle redisplay
  zle end-of-line
  return $editor_status
}

function _tmux_float_editor_bridge_widget() {
  local request
  IFS= read -r -u "$1" request || return 0
  [[ "$request" == edit ]] || return 0

  tmux set-option -pu -t "$TMUX_PANE" @float-editor-ready 2>/dev/null || true
  _tmux_float_edit_buffer
  tmux set-option -p -t "$TMUX_PANE" @float-editor-ready on 2>/dev/null || true
  zle -R
}

function _tmux_float_editor_bridge_init() {
  [[ -n ${TMUX-} && -n ${TMUX_PANE-} ]] || return 0
  local float_root
  float_root=${TMUX_FLOAT_LAB_ROOT:-$(tmux show-option -gqv @float-lab-root 2>/dev/null)}
  [[ -n "$float_root" && -x "$float_root/bin/float-edit-file" ]] || return 0

  if [[ -z ${_TMUX_FLOAT_EDITOR_FIFO-} ]]; then
    _TMUX_FLOAT_EDITOR_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tmux-float-bridge.XXXXXX") || return 0
    _TMUX_FLOAT_EDITOR_FIFO="$_TMUX_FLOAT_EDITOR_DIR/request"
    command mkfifo "$_TMUX_FLOAT_EDITOR_FIFO" || return 0
    exec {_TMUX_FLOAT_EDITOR_FD}<>"$_TMUX_FLOAT_EDITOR_FIFO"
    zle -F -w "$_TMUX_FLOAT_EDITOR_FD" _tmux_float_editor_bridge_widget
    tmux set-option -p -t "$TMUX_PANE" @float-editor-bridge "$_TMUX_FLOAT_EDITOR_FIFO" 2>/dev/null || true
    tmux set-option -p -t "$TMUX_PANE" @float-editor-bridge-pid "$$" 2>/dev/null || true
  fi
  tmux set-option -p -t "$TMUX_PANE" @float-editor-ready on 2>/dev/null || true
}

function _tmux_float_editor_bridge_finish() {
  [[ -n ${TMUX-} && -n ${TMUX_PANE-} ]] || return 0
  tmux set-option -pu -t "$TMUX_PANE" @float-editor-ready 2>/dev/null || true
}

function _tmux_float_editor_bridge_cleanup() {
  [[ -z ${TMUX_PANE-} ]] || {
    tmux set-option -pu -t "$TMUX_PANE" @float-editor-ready 2>/dev/null || true
    tmux set-option -pu -t "$TMUX_PANE" @float-editor-bridge 2>/dev/null || true
    tmux set-option -pu -t "$TMUX_PANE" @float-editor-bridge-pid 2>/dev/null || true
  }
  [[ -z ${_TMUX_FLOAT_EDITOR_DIR-} ]] || command rm -rf -- "$_TMUX_FLOAT_EDITOR_DIR"
}

zle -N custom_edit_command_line
bindkey '^o' custom_edit_command_line
zle -N _tmux_float_editor_bridge_widget
autoload -Uz add-zsh-hook
add-zsh-hook zle-line-init _tmux_float_editor_bridge_init
add-zsh-hook zle-line-finish _tmux_float_editor_bridge_finish
add-zsh-hook zshexit _tmux_float_editor_bridge_cleanup
