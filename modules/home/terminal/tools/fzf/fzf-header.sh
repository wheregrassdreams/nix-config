# shellcheck shell=bash
fzf_header() {
  printf '\033[38;2;103;103;103m^/\033[0m toggle preview  \033[38;2;103;103;103m^D\033[0m/\033[38;2;103;103;103m^U\033[0m scroll preview  \033[38;2;103;103;103mTAB\033[0m select multi'
}

fzf_default_opts="${FZF_DEFAULT_OPTS-} --header \"$(fzf_header)\" --info-command='printf \$FZF_MATCH_COUNT/\$FZF_TOTAL_COUNT' "
export FZF_DEFAULT_OPTS="$fzf_default_opts"
