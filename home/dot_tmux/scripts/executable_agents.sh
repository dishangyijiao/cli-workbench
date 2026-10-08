#!/bin/sh
# Which agents are working, which wait for you, which are idle: a popup over every tmux session (prefix+O).
#   agents.sh [--client NAME]   the popup: pick a row and Enter jumps to that pane (fzf; a numbered menu without it).
#                               NAME is the client that opened the popup (#{client_name}); that client is the one switched.
#   agents.sh --list            the rows as plain text: state, project, branch, how long
#   agents.sh --count           "⏳N" when N agents wait for you, nothing when none do (for the tmux status line)
#   agents.sh --jump %12 [--client NAME]   go to that pane: its session, its window, then the pane
# The rows come from the files agent-state.sh writes, one per pane, in
# ${XDG_STATE_HOME:-~/.local/state}/cli-workbench/sessions/<tmux server>/. Waiting comes first (the longest wait on top),
# then working, then idle. The overview is a hint, so it heals instead of insisting:
#   - a record whose pane no longer exists is removed, but only when the file still holds what was read a moment ago;
#   - a record that was not updated for two hours is shown with a "?" (a crash or a missed hook left it behind);
#   - the directory of a tmux server whose process is gone (kill -0 says "No such process", not "not permitted") is removed.
# When tmux cannot be asked, nothing is removed. Needs jq: without it the list says so, and the count stays silent.
base=${XDG_STATE_HOME:-$HOME/.local/state}/cli-workbench/sessions
TAB=$(printf '\t')
client=

have_jq=1; command -v jq >/dev/null 2>&1 || have_jq=
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

# records: "file<TAB>state<TAB>project<TAB>branch<TAB>since" for every record, from one jq over all files; a file jq cannot
# read is skipped (the one-by-one pass runs only when the batch failed).
records() {
  [ -n "$server" ] && [ -n "$have_jq" ] || return 0
  set -- "$dir"/*.json
  [ -e "$1" ] || return 0
  prog='[input_filename, .state, .project, .branch, (.since | tostring)] | @tsv'
  if out=$(jq -r "$prog" "$@" 2>/dev/null); then
    printf '%s\n' "$out"
  else
    for f; do jq -r "$prog" "$f" 2>/dev/null; done
  fi
}

# Remove the directories of tmux servers that are gone. Only a pid that is certainly dead counts: "No such process".
# Permission denied means it exists (another user's), and any other doubt means do nothing.
sweep_servers() {
  for d in "$base"/*/; do
    d=${d%/}; n=${d##*/}
    [ "$n" = "$server" ] && continue
    pid=${n%%-*}
    case $pid in ''|*[!0-9]*) continue ;; esac
    err=$(LC_ALL=C kill -0 "$pid" 2>&1) && continue
    case $err in *"No such process"*) rm -rf "$d" ;; esac
  done
}

# rows [clean]: "pane<TAB>text" per live record, in display order; with "clean", records of vanished panes are removed.
rows() {
  live=$(panes) && [ -n "$live" ] || return 0
  now=$(date +%s)
  # What the files held just before they were read; a removal below happens only if the file still holds the same.
  sigs=$(cksum "$dir"/*.json 2>/dev/null)
  old=$(find "$dir" -name '*.json' -mmin +120 2>/dev/null)
  records | while IFS= read -r line; do
    [ -n "$line" ] || continue
    f=${line%%"$TAB"*}; rest=${line#*"$TAB"}
    state=${rest%%"$TAB"*}; rest=${rest#*"$TAB"}
    project=${rest%%"$TAB"*}; rest=${rest#*"$TAB"}
    branch=${rest%%"$TAB"*}; since=${rest#*"$TAB"}
    pane=${f##*/}; pane=${pane%.json}
    if ! printf '%s\n' "$live" | awk -v p="$pane" '$1 == p { found = 1 } END { exit !found }'; then
      if [ "${1-}" = clean ]; then
        want=$(printf '%s\n' "$sigs" | awk -v f="$f" '{ n = $0; sub(/^[0-9]+ [0-9]+ /, "", n); if (n == f) { print $1, $2; exit } }')
        [ -n "$want" ] && [ "$(cksum < "$f" 2>/dev/null | awk '{ print $1, $2 }')" = "$want" ] && rm -f "$f"
      fi
      continue
    fi
    case $since in ''|*[!0-9]*) continue ;; esac
    case $state in waiting) rank=0 ;; working) rank=1 ;; *) rank=2 ;; esac
    mark=
    case "
$old
" in *"
$f
"*) mark='?' ;; esac
    elapsed=$((now - since)); [ "$elapsed" -ge 0 ] || elapsed=0
    text=$(printf '%-9s %-24.24s %-24.24s %s' "$state$mark" "$project" "$branch" "$(age "$elapsed")")
    printf '%s\t%s\t%s\t%s\n' "$rank" "$since" "$pane" "$text"
  done | sort -t "$TAB" -k1,1n -k2,2n | cut -f3-
}

# count: the number of waiting agents whose pane exists. Three commands in all (tmux, jq, awk), whatever the number of records.
count() {
  ids=$(panes | awk '{ printf "%s ", $1 }')
  [ -n "$ids" ] || { echo 0; return; }
  # A record not updated for two hours is stale (the list marks it "?"): an agent that crashed while waiting must not keep
  # the status line saying someone needs you.
  old=$(find "$dir" -name '*.json' -mmin +120 2>/dev/null)
  records | awk -F'\t' -v ids="$ids" -v old="$old" 'BEGIN { n = split(ids, a, " "); for (i = 1; i <= n; i++) live[a[i]] = 1
      n = split(old, b, "\n"); for (i = 1; i <= n; i++) if (b[i] != "") stale[b[i]] = 1 }
    $2 == "waiting" && !($1 in stale) { f = $1; sub(/.*\//, "", f); sub(/\.json$/, "", f); if (f in live) c++ }
    END { print c + 0 }'
}

jump() {
  case ${1-} in %[0-9]*) ;; *) echo "agents: not a pane id: ${1-}" >&2; return 2 ;; esac
  case $1 in *[!%0-9]*) echo "agents: not a pane id: $1" >&2; return 2 ;; esac
  target=$(panes | awk -v p="$1" '$1 == p { print $2, $3; exit }')
  [ -n "$target" ] || { echo "agents: pane $1 is gone" >&2; return 1; }
  session=${target% *} window=${target#* }
  # Select the window and the pane first: if the window closed since the listing, the client stays where it is. Only then
  # move the client. It belongs to the popup; with several attached, the active one may be another, so -c names the right one.
  tmux select-window -t "$session:$window" && tmux select-pane -t "$1" || return
  if [ -n "$client" ]; then
    tmux switch-client -c "$client" -t "$session"
  else
    tmux switch-client -t "$session"
  fi
}

pause() { printf '%s' "$1"; read -r _; }

pick() {
  if [ -z "$have_jq" ]; then pause 'jq is required for the agent overview. Press Enter to close.'; return 0; fi
  panes >/dev/null && [ -n "$server" ] && sweep_servers
  list=$(rows clean)
  if [ -z "$list" ]; then
    pause 'No agent sessions yet. Press Enter to close.'; return 0
  fi
  if command -v fzf >/dev/null 2>&1; then
    # The pane id ends each line, so the choice is found whichever form of the line fzf prints.
    sel=$(printf '%s\n' "$list" | awk -F'\t' '{ print $2 "  " $1 }' | fzf --reverse --no-sort --prompt='agent> ' \
      --header="$(printf '%-9s %-24s %-24s %-5s %s' STATE PROJECT BRANCH TIME PANE)") || return 0
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
  --list)
    if [ -z "$have_jq" ]; then echo "jq is required"; exit 0; fi
    rows clean | cut -f2- ;;
  --count)
    n=$(count)
    [ "${n:-0}" -gt 0 ] && printf '⏳%s' "$n"
    exit 0 ;;
  jump) jump "$pane" ;;
  pick) pick ;;
esac
