#!/bin/sh
# Record what the agent in this tmux pane is doing, for the overview (prefix+O, agents.sh). Claude Code hooks call it:
#   agent-state.sh ACTION      the hook's JSON may arrive on stdin; only session_id is read from it
#   working   a turn starts          waiting  the agent needs you (rings the pane once)       idle  a turn ended
#   heal      waiting -> working, anything else stays (something ran, so you must have answered)
#   end       the session is over: the file is removed
# One small file per pane: ${XDG_STATE_HOME:-~/.local/state}/cli-workbench/sessions/<server>/<pane id>.json
#   {"state":"waiting","project":"foo","branch":"main","since":1791380000,"session_id":"3f2a..."}
# <server> is the tmux server's pid and start time, so a pane id that a restarted tmux hands out again never meets an old
# record. "project" is the repository's top directory name (the main one for a worktree), else the directory's name;
# "since" is when the state last changed (wall clock, for display).
# The overview is a hint for one person, not a state machine: the last event wins, and the file is replaced atomically
# (written to a temporary name in the same directory, then renamed), so a reader never sees half of it. Two events in the
# same instant may land in either order; the reader marks records that were not updated for hours.
# A hook must never be slowed or broken: outside tmux, or without jq, it does nothing; it prints nothing and exits 0.

main() {
  action=${1-}
  case $action in working|waiting|idle|heal|end) ;; *) return ;; esac
  case ${TMUX_PANE-} in %[0-9]*) ;; *) return ;; esac
  case $TMUX_PANE in *[!%0-9]*) return ;; esac
  command -v jq >/dev/null 2>&1 || return
  pane=$TMUX_PANE

  info=$(tmux display-message -p -t "$pane" '#{pid}-#{start_time} #{pane_tty}' 2>/dev/null) || return
  server=${info%% *} tty=${info#* }
  case $server in ''|*[!0-9-]*) return ;; esac
  dir=${XDG_STATE_HOME:-$HOME/.local/state}/cli-workbench/sessions/$server
  file=$dir/$pane.json

  if [ "$action" = end ]; then rm -f "$file"; return; fi

  oldstate='' oldsince=''
  if [ -f "$file" ]; then
    old=$(jq -r '[.state // "", (.since // "" | tostring)] | join(" ")' "$file" 2>/dev/null) && {
      oldstate=${old% *} oldsince=${old#* }
    }
  fi
  if [ "$action" = heal ]; then
    [ "$oldstate" = waiting ] || return
    action=working
  fi
  state=$action

  payload=
  [ -t 0 ] || payload=$(head -c 65536)
  sid=$(printf '%s' "$payload" | jq -r '.session_id // empty | tostring' 2>/dev/null | tr -cd 'A-Za-z0-9_-')

  now=$(date +%s)
  since=$now
  case $oldsince in ''|*[!0-9]*) ;; *) [ "$state" = "$oldstate" ] && since=$oldsince ;; esac

  here=$PWD project=$PWD
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
  if jq -nc --arg state "$state" --arg project "$project" --arg branch "$branch" --argjson since "$since" --arg sid "$sid" \
      '{state: $state, project: $project, branch: $branch, since: $since, session_id: $sid}' > "$tmp"; then
    mv -f "$tmp" "$file" || { rm -f "$tmp"; return; }
  else
    rm -f "$tmp"; return
  fi

  # Entering waiting rings once, like the Stop hook does, so Ghostty marks the tab.
  if [ "$state" = waiting ] && [ "$oldstate" != waiting ] && [ -n "$tty" ]; then printf '\a' >> "$tty"; fi
}

main "$@" 2>/dev/null
exit 0
