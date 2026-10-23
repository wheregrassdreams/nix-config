# shellcheck disable=SC2148,SC2076,SC2154,SC1090
install-completion() {
  emulate -L zsh

  if (( $# < 2 )); then
    print -u2 'usage: install-completion GENERATOR [ARG ...]'
    return 2
  fi

  local generator="$1"
  shift
  if [[ ! -x "$generator" ]]; then
    print -u2 "install-completion: not executable: $generator"
    return 1
  fi

  local completion_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/completions"
  command mkdir -p "$completion_dir" || return

  local temporary_file
  temporary_file="$(command mktemp "$completion_dir/.completion.XXXXXXXX")" || return
  if ! "$generator" "$@" >| "$temporary_file"; then
    command rm -f -- "$temporary_file"
    print -u2 "install-completion: generator failed: $generator"
    return 1
  fi

  local header completion_name destination changed
  header="$(command head -n 1 "$temporary_file")"
  if [[ "$header" != '#compdef '* ]]; then
    command rm -f -- "$temporary_file"
    print -u2 'install-completion: output is not a zsh completion (#compdef header missing)'
    return 1
  fi

  completion_name="${header#\#compdef }"
  completion_name="${completion_name%% *}"
  if [[ ! "$completion_name" =~ '^[A-Za-z0-9_.+-]+$' ]]; then
    command rm -f -- "$temporary_file"
    print -u2 "install-completion: invalid command name in completion header: $completion_name"
    return 1
  fi
  if ! zsh -n "$temporary_file"; then
    command rm -f -- "$temporary_file"
    print -u2 'install-completion: generated file has invalid zsh syntax'
    return 1
  fi

  destination="$completion_dir/_$completion_name"
  if [[ -f "$destination" ]] && command cmp -s "$temporary_file" "$destination"; then
    command rm -f -- "$temporary_file"
    changed=false
  else
    command chmod 0644 "$temporary_file" || {
      command rm -f -- "$temporary_file"
      return 1
    }
    command mv -f -- "$temporary_file" "$destination" || {
      command rm -f -- "$temporary_file"
      return 1
    }
    changed=true
  fi

  if (( $+functions[compdef] )); then
    source "$destination" || return
  else
    autoload -Uz compinit
    compinit
  fi

  if [[ $changed == true ]]; then
    print "installed zsh completion for $completion_name: $destination"
  else
    print "completion already current: $destination"
  fi
}
