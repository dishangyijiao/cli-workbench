#!/bin/sh
# Which agents are working, which wait for you, which are idle: a popup over every tmux session (prefix+O).
#   agents.sh [--client NAME]   the popup: pick a row and Enter jumps to that pane (fzf; a numbered menu without it).
#                               NAME is the client that opened the popup (#{client_name}); that client is the one switched.
#   agents.sh --list            the rows as plain text: state, project, branch, how long
#   agents.sh --count           "⏳N" when N agents wait for you, nothing when none do (for the tmux status line)
#   agents.sh --jump %12 [--client NAME]   go to that pane: its session, its window, then the pane
# The rows come from the files agent-state.sh writes, one per pane, in
# ${XDG_STATE_HOME:-~/.local/state}/cli-workbench/sessions/<tmux server>/. Waiting comes first (the longest wait on top),
# then working, then idle. A file whose pane no longer exists is removed, and so is an "ended" record after a minute and
# the directory of a tmux server that is gone; when tmux cannot be asked, nothing is removed. Needs jq.
base=${XDG_STATE_HOME:-$HOME/.local/state}/cli-workbench/sessions
TAB=$(printf '\t')
client=

server=$(tmux display-message -p '#{pid}-#{start_time}' 2>/dev/null)
case $server in ''|*[!0-9-]*) server= ;; esac
dir=$base/$server

panes() { tmux list-panes -a -F '#{pane_id} #{session_id} #{window_id}' 2>/dev/null; }

age() {   # seconds -> 30s, 5m, 2h, 3d
  if [ "$1" -lt 60 ]; then echo "${1}s"
  elif [ "$1" -lt 3600 ]; then echo "$(($1 / 60))m"
  elif [ "$1" -lt 86400 ]; then echo "$(($1 / 3600))h"
  else echo "$(($1 / 86400))d"; fi
}

# records: "file<TAB>state<TAB>project<TAB>branch<TAB>since<TAB>ts" for every record, from one jq over all files; a file jq
# cannot read is skipped (the one-by-one pass runs only when the batch failed).
records() {
  [ -n "$server" ] || return 0
  set -- "$dir"/*.json
  [ -e "$1" ] || return 0
  prog='[input_filename, .state, .project, .branch, (.since | tostring), (.ts | tostring)] | @tsv'
  if out=$(jq -r "$prog" "$@" 2>/dev/null); then
    printf '%s\n' "$out"
  else
    for f; do jq -r "$prog" "$f" 2>/dev/null; done
  fi
}

# Remove what can never be shown again: directories of tmux servers that are gone.
sweep_servers() {
  for d in "$base"/*/; do
    d=${d%/}; n=${d##*/}
    [ "$n" = "$server" ] && continue
    pid=${n%%-*}
    case $pid in ''|*[!0-9]*) continue ;; esac
    kill -0 "$pid" 2>/dev/null || rm -rf "$d"
  done
}

# rows [clean]: "pane<TAB>text" per live record, in display order; with "clean", stale records are removed.
rows() {
  live=$(panes) && [ -n "$live" ] || return 0
  now=$(date +%s); nowms=${now}000
  records | while IFS= read -r line; do
    [ -n "$line" ] || continue
    f=${line%%"$TAB"*}; rest=${line#*"$TAB"}
    state=${rest%%"$TAB"*}; rest=${rest#*"$TAB"}
    project=${rest%%"$TAB"*}; rest=${rest#*"$TAB"}
    branch=${rest%%"$TAB"*}; rest=${rest#*"$TAB"}
    since=${rest%%"$TAB"*}; ts=${rest#*"$TAB"}
    pane=${f##*/}; pane=${pane%.json}
    if ! printf '%s\n' "$live" | awk -v p="$pane" '$1 == p { found = 1 } END { exit !found }'; then
      [ "${1-}" = clean ] && rm -f "$f"
      continue
    fi
    if [ "$state" = ended ]; then
      case $ts in ''|*[!0-9]*) ts=0 ;; esac
      [ "${1-}" = clean ] && [ $((nowms - ts)) -gt 60000 ] && rm -f "$f"
      continue
    fi
    case $since in ''|*[!0-9]*) continue ;; esac
    case $state in waiting) rank=0 ;; working) rank=1 ;; *) rank=2 ;; esac
    elapsed=$((now - since)); [ "$elapsed" -ge 0 ] || elapsed=0
    text=$(printf '%-8s %-24.24s %-24.24s %s' "$state" "$project" "$branch" "$(age "$elapsed")")
    printf '%s\t%s\t%s\t%s\n' "$rank" "$since" "$pane" "$text"
  done | sort -t "$TAB" -k1,1n -k2,2n | cut -f3-
}

# count: the number of waiting agents whose pane exists: two processes (tmux, jq) and one awk, nothing per record.
count() {
  ids=$(panes | awk '{ printf "%s ", $1 }')
  [ -n "$ids" ] || { echo 0; return; }
  records | awk -F'\t' -v ids="$ids" 'BEGIN { n = split(ids, a, " "); for (i = 1; i <= n; i++) live[a[i]] = 1 }
    $2 == "waiting" { f = $1; sub(/.*\//, "", f); sub(/\.json$/, "", f); if (f in live) c++ }
    END { print c + 0 }'
}

jump() {
  case ${1-} in %[0-9]*) ;; *) echo "agents: not a pane id: ${1-}" >&2; return 2 ;; esac
  case $1 in *[!%0-9]*) echo "agents: not a pane id: $1" >&2; return 2 ;; esac
  target=$(panes | awk -v p="$1" '$1 == p { print $2, $3; exit }')
  [ -n "$target" ] || { echo "agents: pane $1 is gone" >&2; return 1; }
  session=${target% *} window=${target#* }
  # The popup belongs to one client; with several attached, the active one may be another. -c names the right one.
  if [ -n "$client" ]; then
    tmux switch-client -c "$client" -t "$session" || return
  else
    tmux switch-client -t "$session" || return
  fi
  tmux select-window -t "$session:$window" && tmux select-pane -t "$1"
}

pause() { printf '%s' "$1"; read -r _; }

pick() {
  sweep_servers
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

mode=pick
while [ $# -gt 0 ]; do
  case $1 in
    --client) client=${2-}; shift 2 || break ;;
    --list|--count) mode=$1; shift ;;
    --jump) mode=jump; pane=${2-}; shift 2 || break ;;
    *) echo "usage: agents.sh [--client NAME] [--list | --count | --jump PANE_ID]" >&2; exit 2 ;;
  esac
done
case $mode in
  --list) rows clean | cut -f2- ;;
  --count)
    n=$(count)
    [ "${n:-0}" -gt 0 ] && printf '⏳%s' "$n"
    exit 0 ;;
  jump) jump "$pane" ;;
  pick) pick ;;
esac
