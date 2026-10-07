#!/bin/sh
# Which agents are working, which wait for you, which are idle: a popup over every tmux session (prefix+O).
#   agents.sh              the popup: pick a row and Enter jumps to that pane (fzf; a numbered menu without it)
#   agents.sh --list       the rows as plain text: state, project, branch, how long
#   agents.sh --count      "⏳N" when N agents wait for you, nothing when none do (for the tmux status line)
#   agents.sh --jump %12   go to that pane: its session, its window, then the pane
# The rows come from the files agent-state.sh writes, one per pane, in ${XDG_STATE_HOME:-~/.local/state}/cli-workbench/sessions.
# Waiting comes first (the longest wait on top), then working, then idle. A file whose pane no longer exists is removed;
# when tmux cannot be asked, nothing is removed.
dir=${XDG_STATE_HOME:-$HOME/.local/state}/cli-workbench/sessions
TAB=$(printf '\t')

panes() { tmux list-panes -a -F '#{pane_id} #{session_id} #{window_id}' 2>/dev/null; }

age() {   # seconds -> 30s, 5m, 2h, 3d
  if [ "$1" -lt 60 ]; then echo "${1}s"
  elif [ "$1" -lt 3600 ]; then echo "$(($1 / 60))m"
  elif [ "$1" -lt 86400 ]; then echo "$(($1 / 3600))h"
  else echo "$(($1 / 86400))d"; fi
}

# rows [clean]: "pane<TAB>text" per live record, in display order; with "clean", records of vanished panes are removed.
rows() {
  live=$(panes) && [ -n "$live" ] || return 0
  now=$(date +%s)
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    pane=${f##*/}; pane=${pane%.json}
    if ! printf '%s\n' "$live" | awk -v p="$pane" '$1 == p { found = 1 } END { exit !found }'; then
      [ "${1-}" = clean ] && rm -f "$f"
      continue
    fi
    fields=$(jq -r '[.state, .project, .branch, (.since | tonumber)] | @tsv' "$f" 2>/dev/null) || continue
    state=${fields%%"$TAB"*}; rest=${fields#*"$TAB"}
    project=${rest%%"$TAB"*}; rest=${rest#*"$TAB"}
    branch=${rest%%"$TAB"*}; since=${rest#*"$TAB"}
    case $state in waiting) rank=0 ;; working) rank=1 ;; *) rank=2 ;; esac
    elapsed=$((now - since)); [ "$elapsed" -ge 0 ] || elapsed=0
    text=$(printf '%-8s %-24.24s %-24.24s %s' "$state" "$project" "$branch" "$(age "$elapsed")")
    printf '%s\t%s\t%s\t%s\n' "$rank" "$since" "$pane" "$text"
  done | sort -t "$TAB" -k1,1n -k2,2n | cut -f3-
}

jump() {
  case ${1-} in %[0-9]*) ;; *) echo "agents: not a pane id: ${1-}" >&2; return 2 ;; esac
  case $1 in *[!%0-9]*) echo "agents: not a pane id: $1" >&2; return 2 ;; esac
  target=$(panes | awk -v p="$1" '$1 == p { print $2, $3; exit }')
  [ -n "$target" ] || { echo "agents: pane $1 is gone" >&2; return 1; }
  session=${target% *} window=${target#* }
  tmux switch-client -t "$session" && tmux select-window -t "$window" && tmux select-pane -t "$1"
}

pause() { printf '%s' "$1"; read -r _; }

pick() {
  list=$(rows clean)
  if [ -z "$list" ]; then
    pause 'No agent sessions yet. Press Enter to close.'; return 0
  fi
  if command -v fzf >/dev/null 2>&1; then
    # The pane id ends each line, so the choice is found whichever form of the line fzf prints.
    sel=$(printf '%s\n' "$list" | awk -F'\t' '{ print $2 "  " $1 }' | fzf --reverse --no-sort --prompt='agent> ' \
      --header="$(printf '%-8s %-24s %-24s %-5s %s' STATE PROJECT BRANCH TIME PANE)") || return 0
    [ -n "$sel" ] && jump "${sel##* }"
    return
  fi
  n=0
  while IFS= read -r line; do n=$((n + 1)); printf '%2d) %s\n' "$n" "${line#*"$TAB"}"; done <<EOF2
$list
EOF2
  printf 'Number (Enter cancels): '
  read -r choice || return 0
  case $choice in ''|*[!0-9]*) return 0 ;; esac
  [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ] || return 0
  line=$(printf '%s\n' "$list" | sed -n "${choice}p")
  jump "${line%%"$TAB"*}"
}

case ${1-} in
  --list) rows clean | cut -f2- ;;
  --count)
    n=$(rows | grep -c "$TAB"'waiting ')
    [ "$n" -gt 0 ] && printf '⏳%s' "$n"
    exit 0 ;;
  --jump) jump "${2-}" ;;
  '') pick ;;
  *) echo "usage: agents.sh [--list | --count | --jump PANE_ID]" >&2; exit 2 ;;
esac
