# Terminal tab startup: pick a tmux session, or create one. Opt-in: set WB_TMUX_AUTOSTART=1 in ~/.config/zsh/local.zsh.
#   - No sessions yet        -> create one right away.
#   - Existing sessions      -> show a chooser (existing sessions + "new session"); Esc / q gives a plain shell.
# Escape hatch: run `TMUX_NO_AUTOSTART=1 zsh` to get a shell that stays outside tmux.

zmodload zsh/datetime 2>/dev/null

_TMUX_NEW=__new__

# Prints "<name>\t<display>" per session, most recently active first.
_tmux_session_entries() {
  local tmux_bin=$1 name attached windows activity dir
  "$tmux_bin" list-sessions -F $'#{session_activity}\t#{session_name}\t#{session_attached}\t#{session_windows}\t#{pane_current_path}' 2>/dev/null \
    | sort -t$'\t' -k1,1nr \
    | while IFS=$'\t' read -r activity name attached windows dir; do
        printf '%s\t%s\n' "$name" \
          "${(r:16:)name} ${(l:2:)windows} win  $( (( attached )) && print -n 'attached' || print -n 'detached' )  $(strftime '%m-%d %H:%M' "$activity")  ${dir/#$HOME/~}"
      done
}

# Prints the chosen session name, $_TMUX_NEW for a new session, or nothing for "plain shell".
_tmux_choose() {
  local tmux_bin=$1; shift
  local -a entries=("$@")
  local fzf_bin=${commands[fzf]:-} reply i=1 e

  [[ -x $fzf_bin ]] || fzf_bin=$(command -v fzf)
  if [[ -n $fzf_bin ]]; then
    { printf '%s\n' "${entries[@]}"; printf '%s\t%s\n' $_TMUX_NEW '+ new session'; } \
      | "$fzf_bin" --delimiter=$'\t' --with-nth=2 --height=~50% --reverse --no-sort \
          --prompt='tmux> ' --header='Enter: attach   Esc: plain shell' \
          --preview="$tmux_bin capture-pane -ep -t \"=\"{1}\":\" 2>/dev/null" --preview-window=right:50% \
      | cut -f1
    return 0
  fi

  for e in "${entries[@]}"; do
    print -u2 -r -- "  $i) ${e#*$'\t'}"
    (( i++ ))
  done
  print -u2 "  n) new session"
  print -u2 "  q) plain shell"
  read -r "reply?Select [1]: " || return 0
  reply=${reply:-1}
  case $reply in
    n|N) print -r -- $_TMUX_NEW ;;
    q|Q) ;;
    <->) (( reply >= 1 && reply <= $#entries )) && print -r -- "${${entries[reply]}%%$'\t'*}" ;;
  esac
}

_tmux_autostart() {
  local tmux_bin=${commands[tmux]:-} choice sname
  local -a entries
  [[ -x $tmux_bin ]] || return 0

  entries=("${(@f)$(_tmux_session_entries "$tmux_bin")}")
  entries=("${(@)entries:#}")

  # No exec and no unconditional exit: if tmux fails, the shell survives so the error stays visible.
  # The tab closes only when tmux exits cleanly (detach or last session gone, exit status 0).
  if (( $#entries == 0 )); then
    "$tmux_bin" new-session && exit
    return 0
  fi

  choice=$(_tmux_choose "$tmux_bin" "${entries[@]}")
  [[ -z $choice ]] && return 0

  if [[ $choice == $_TMUX_NEW ]]; then
    read -r "sname?New session name (empty = auto): "
    if [[ -n $sname ]]; then
      "$tmux_bin" new-session -A -s "$sname" && exit
    else
      "$tmux_bin" new-session && exit
    fi
  else
    "$tmux_bin" attach-session -t "=$choice" && exit
  fi
}

_tmux_autostart
