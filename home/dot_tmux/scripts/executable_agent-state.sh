#!/bin/sh
# Record what the agent in this tmux pane is doing, for the overview (prefix+O, agents.sh). Claude Code hooks call it:
#   agent-state.sh ACTION      the hook's JSON arrives on stdin: session_id, and optionally ts (event time, ms) and key
#   begin    a turn starts: working, no wait left        idle   a turn ended (answered, interrupted or failed): idle
#   start    a session starts or resumes: idle           end    the session is over (a tombstone, see below)
#   wait     the agent needs you; "key" names the request (a tool call, a dialog), several can be open
#   unwait   the request named by "key" was answered, denied or failed (no key: all of them); unwait-prefix: every
#            request whose key starts with "key"
# One file per pane and tmux server: ${XDG_STATE_HOME:-~/.local/state}/cli-workbench/sessions/<server>/<pane id>.json
# <server> is the tmux server's pid and start time, so a pane id that a restarted tmux hands out again never meets an
# old record. The file says {"state","base","waits","project","branch","since","ts","session_id"}; "state" is what the
# overview shows: waiting while "waits" is not empty, else "base" (working or idle), or ended.
# Ordering: every event carries its time. An event older than the record, or from an older session than the record's,
# changes nothing, so a hook process that was slow cannot undo a newer state or bring back a session that ended. The
# read-modify-write runs under a lock (mkdir; a lock older than 5 s is taken over; if it stays busy the event is dropped).
# The file is written to a temporary name and renamed, so a reader never sees half of it. "ended" records stay for a
# minute so that late events find them, then the overview removes them.
# A hook must never be slowed or broken: outside tmux it does nothing, it prints nothing and it always exits 0.
# Needs jq (a requirement of the workbench); without it nothing is recorded.

main() {
  action=${1-}
  case $action in begin|idle|start|end|wait|unwait|unwait-prefix) ;; *) return ;; esac
  case ${TMUX_PANE-} in %[0-9]*) ;; *) return ;; esac
  case $TMUX_PANE in *[!%0-9]*) return ;; esac
  command -v jq >/dev/null 2>&1 || return
  pane=$TMUX_PANE

  info=$(tmux display-message -p -t "$pane" '#{pid}-#{start_time} #{pane_tty}' 2>/dev/null) || return
  server=${info%% *} tty=${info#* }
  case $server in ''|*[!0-9-]*) return ;; esac
  dir=${XDG_STATE_HOME:-$HOME/.local/state}/cli-workbench/sessions/$server
  file=$dir/$pane.json

  payload=
  [ -t 0 ] || payload=$(head -c 65536)

  nowsec=$(date +%s)
  now=${nowsec}000

  umask 077
  mkdir -p "$dir" || return
  lock=$dir/.$pane.lock
  tries=0
  until mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 12 ]; then
      # Busy for half a second: a live hook is finishing, or a killed one left its lock. Take over only an old lock.
      mtime=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null) || return
      [ $((nowsec - mtime)) -gt 5 ] || return
      rmdir "$lock" 2>/dev/null
      mkdir "$lock" 2>/dev/null || return
      break
    fi
    sleep 0.05
  done
  trap 'rmdir "$lock" 2>/dev/null' EXIT
  trap 'exit 0' INT TERM HUP

  oldfile=/dev/null
  [ -f "$file" ] && oldfile=$file

  # Where the agent is, looked up only when the record needs it: a wait or an answer on an existing record keeps its own.
  project='' branch=''
  case $action in wait|unwait|unwait-prefix) [ -s "$oldfile" ] && have=1 ;; esac
  if [ -z "${have-}" ]; then
    here=$PWD project=$PWD
    common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && case $common in
      */.git) project=${common%/.git} ;;
      *) project=$(git rev-parse --show-toplevel 2>/dev/null) || project=$here ;;
    esac
    project=${project##*/}
    branch=$(git --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) \
      || branch=$(git --no-optional-locks rev-parse --short HEAD 2>/dev/null) || branch=
  fi

  # One jq decides everything: line 1 is "reject" or "ok <old state> <new state>", line 2 the record to write.
  res=$(jq -nr --rawfile oldraw "$oldfile" --arg praw "$payload" --arg action "$action" --argjson now "$now" \
    --argjson nowsec "$nowsec" --arg project "$project" --arg branch "$branch" '
    (try ($oldraw | fromjson) catch null | if type == "object" then . else null end) as $old
    | (try ($praw | fromjson) catch {} | if type == "object" then . else {} end) as $p
    | ($p.session_id // "" | tostring | gsub("[^A-Za-z0-9_-]"; "")) as $sid
    | (($p.ts // $now) | tonumber? // $now) as $ts
    | ($p.key // "" | tostring) as $key
    | (if $old == null then "new"
       elif $sid != "" and ($old.session_id // "") != "" and $sid != $old.session_id then
         (if $action == "end" or $ts <= ($old.ts // 0) then "reject" else "new" end)
       else "same" end) as $mode
    | if $mode == "reject" or ($mode == "new" and ($action | startswith("unwait"))) then "reject"
      else
        (if $mode == "same" then $old
         else {base: (if $action == "wait" then "working" else "idle" end), base_ts: 0, floor: 0, waits: {}, done: [],
               project: $project, branch: $branch} end) as $cur
        | ($action == "begin" or $action == "idle" or $action == "start" or $action == "end") as $reset
        | (if $reset and $ts >= ($cur.base_ts // 0) then
             {base: (if $action == "end" then "ended" elif $action == "begin" then "working" else "idle" end), base_ts: $ts}
           else {base: $cur.base, base_ts: ($cur.base_ts // 0)} end) as $b
        | ((if $reset then ([($cur.floor // 0), $ts] | max) else ($cur.floor // 0) end)) as $floor
        | ($cur.done // []) as $done
        | def hit($d; $k): if $d.exact then $d.k == $k else ($k | startswith($d.k)) end;
          (if $action == "wait" then
             (if $ts <= $floor or ($done | any(hit(.; $key) and .ts >= $ts)) then null
              else (($cur.waits // {}) | .[$key] = ([(.[$key] // 0), $ts] | max)) end)
           elif $action == "unwait" or $action == "unwait-prefix" then
             ({k: $key, exact: ($action == "unwait" and $key != "")}) as $d
             | (($cur.waits // {}) | with_entries(. as $w | select((hit($d; $w.key) | not) or ($w.value > $ts))))
           else ($cur.waits // {}) end) as $waits0
        | if $waits0 == null then "reject"
          else
            ($waits0 | with_entries(select(.value > $floor))) as $waits
            | ((if $action == "unwait" or $action == "unwait-prefix"
                then $done + [{k: $key, exact: ($action == "unwait" and $key != ""), ts: $ts}] else $done end)
               | map(select(.ts > $floor)) | .[-50:]) as $done2
            | (if $b.base == "ended" then "ended" elif ($waits | length) > 0 then "waiting" else $b.base end) as $state
            | "ok \($old.state // "-") \($state)",
              ({state: $state, base: $b.base, base_ts: $b.base_ts, floor: $floor, waits: $waits, done: $done2,
                project: (if $project != "" then $project else $cur.project // "" end),
                branch: (if $project != "" then $branch else $cur.branch // "" end),
                since: (if $mode == "same" and $cur.state == $state then $cur.since else $nowsec end),
                ts: ([($cur.ts // 0), $ts] | max),
                session_id: (if $sid != "" then $sid else $cur.session_id // "" end)} | tojson)
          end
      end' 2>/dev/null) || return
  verdict=$(printf '%s\n' "$res" | sed -n 1p)
  case $verdict in "ok "*) ;; *) return ;; esac
  new=$(printf '%s\n' "$res" | sed -n 2p)
  [ -n "$new" ] || return

  tmp=$dir/.$pane.$$.tmp
  if printf '%s\n' "$new" > "$tmp"; then
    mv -f "$tmp" "$file" || { rm -f "$tmp"; return; }
  else
    rm -f "$tmp"; return
  fi

  # Waiting is the one state that rings: the same bell the Stop hook rings, so Ghostty marks the tab.
  set -- $verdict
  oldstate=$2 newstate=$3
  if [ "$newstate" = waiting ] && [ "$oldstate" != waiting ] && [ -n "$tty" ]; then printf '\a' >> "$tty"; fi
}

main "$@" 2>/dev/null
exit 0
