# shellcheck disable=SC2148,SC2154,SC2296
if (( $+commands[nix-locate] )); then
  function command_not_found_handler() {
    local command_name=$1 candidate
    local -a candidates packages

    candidates=("${(@f)$(command nix-locate \
      --minimal --no-group --type x --type s --whole-name --at-root \
      "/bin/$command_name" 2>/dev/null)}")

    for candidate in "${candidates[@]}"; do
      [[ -n "$candidate" ]] && packages+=("$candidate")
    done
    typeset -U packages

    case ${#packages} in
      0)
        print -u2 -- "$command_name: command not found"
        ;;
      1)
        print -u2 -- "$command_name isn't installed."
        print -u2 -- "Install: nix profile install nixpkgs#${packages[1]}"
        print -u2 -- "Run once: , $command_name ..."
        ;;
      *)
        print -u2 -- "$command_name isn't installed. It is available from:"
        for candidate in "${packages[@]}"; do
          print -u2 -- "  nixpkgs#$candidate"
        done
        print -u2 -- "Install one with: nix profile install nixpkgs#<package>"
        print -u2 -- "Run once with: , $command_name ..."
        ;;
    esac

    return 127
  }
fi
