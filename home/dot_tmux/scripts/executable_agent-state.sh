#!/bin/sh
# Record what the agent in this tmux pane is doing, for the overview (prefix+O, agents.sh). Claude Code hooks call it:
#   agent-state.sh working|waiting|idle|resume|end      the hook payload (JSON) may arrive on stdin
#   working  the agent is busy (UserPromptSubmit)        waiting  it needs you (permission prompt, question); rings the pane
#   idle     it is done and waits for a prompt           resume   waiting -> working once a tool has run, else nothing
#   end      the session is over: the file is removed
# One file per pane: ${XDG_STATE_HOME:-~/.local/state}/cli-workbench/sessions/<pane_id>.json, for example
#   {"state":"waiting","project":"foo","branch":"main","since":1791380000,"session_id":"3f2a..."}
# "project" is the repository's top directory name (the main one for a worktree), else the directory's name; "since" is
# when the state last changed. The file is written to a temporary name and renamed, so a reader never sees half of it.
# A hook must never be slowed or broken: outside tmux it does nothing, it prints nothing and it always exits 0.

esc() { printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'; }   # the text of a JSON string

main() {
  state=${1-}
  case $state in working|waiting|idle|resume|end) ;; *) return ;; esac
  case ${TMUX_PANE-} in %[0-9]*) ;; *) return ;; esac
  case $TMUX_PANE in *[!%0-9]*) return ;; esac
  pane=$TMUX_PANE
  dir=${XDG_STATE_HOME:-$HOME/.local/state}/cli-workbench/sessions
  file=$dir/$pane.json

  if [ "$state" = end ]; then rm -f "$file"; return; fi

  old=
  [ -f "$file" ] && old=$(head -c 4096 "$file")
  oldstate=$(printf '%s' "$old" | sed -n 's/^{"state":"\([a-z]*\)".*/\1/p')
  oldsince=$(printf '%s' "$old" | sed -n 's/.*"since":\([0-9][0-9]*\).*/\1/p')
  if [ "$state" = resume ]; then
    [ "$oldstate" = waiting ] || return
    state=working oldstate=
  fi

  payload=
  [ -t 0 ] || payload=$(head -c 65536)
  sid=
  if [ -n "$payload" ]; then
    if command -v jq >/dev/null 2>&1; then
      sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
    else
      sid=$(printf '%s' "$payload" | tr -d '\n' | sed -n 's/^ *{ *"session_id" *: *"\([A-Za-z0-9_-]*\)".*/\1/p')
    fi
    sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-')
  fi

  now=$(date +%s)
  since=$now
  [ "$state" = "$oldstate" ] && [ -n "$oldsince" ] && since=$oldsince

  here=$PWD project=$here
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && case $common in
    */.git) project=${common%/.git} ;;
    *) project=$(git rev-parse --show-toplevel 2>/dev/null) || project=$here ;;
  esac
  project=${project##*/}
  branch=$(git --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) \
    || branch=$(git --no-optional-locks rev-parse --short HEAD 2>/dev/null) || branch=

  umask 077
  mkdir -p "$dir" || return
  tmp=$dir/.$pane.$$.tmp
  if printf '{"state":"%s","project":"%s","branch":"%s","since":%s,"session_id":"%s"}\n' \
      "$state" "$(esc "$project")" "$(esc "$branch")" "$since" "$sid" > "$tmp"; then
    mv -f "$tmp" "$file" || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi

  # Waiting is the one state that rings: the same bell the Stop hook rings, so Ghostty marks the tab.
  if [ "$state" = waiting ] && [ "$oldstate" != waiting ]; then
    tty=$(tmux display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null)
    [ -n "$tty" ] && printf '\a' > "$tty"
  fi
}

main "$@" 2>/dev/null
exit 0
