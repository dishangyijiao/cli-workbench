#!/usr/bin/env bash
# agents.sh is the overview popup (prefix+O): it lists the agent sessions that agent-state.sh recorded, waiting first,
# drops the records of panes that are gone, and jumps to the pane you pick. Runs against a stub of tmux, in a throwaway
# HOME and state directory.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
command -v jq >/dev/null || { echo "jq not installed; skipped"; exit 0; }
T_DIR=$(cd -P "$(mktemp -d "${TMPDIR:-/tmp}/wb-agents.XXXXXX")" && pwd)
trap t_cleanup EXIT
AGENTS=$WB_SRC/home/dot_tmux/scripts/executable_agents.sh
export HOME=$T_DIR/home; mkdir -p "$HOME"
export XDG_STATE_HOME=$T_DIR/state
SRV=100-1700000000; export FAKE_SERVER=$SRV
SESS=$XDG_STATE_HOME/cli-workbench/sessions/$SRV; mkdir -p "$SESS"
LOG=$T_DIR/log; : > "$LOG"

# tmux stub: list-panes answers with the lines of $FAKE_PANES ("%pane $session @window"); FAKE_TMUX_FAIL=1 makes it fail like
# an unreachable server; every other command is logged.
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/bin/tmux" <<'SH'
#!/bin/sh
[ "${FAKE_TMUX_FAIL:-}" = 1 ] && exit 1
if [ "$1" = display-message ]; then echo "$FAKE_SERVER"; exit 0; fi
if [ "$1" = list-panes ]; then [ "${FAKE_LIST_FAIL:-}" = 1 ] && exit 1; cat "$FAKE_PANES"; exit 0; fi
# FAKE_SELECT_FAIL=1: the window closed between the listing and the jump.
if [ "$1" = select-window ] && [ "${FAKE_SELECT_FAIL:-}" = 1 ]; then exit 1; fi
echo "$*" >> "$FAKE_LOG"
SH
chmod +x "$T_DIR/bin/tmux"
export FAKE_PANES=$T_DIR/panes FAKE_LOG=$LOG
now=$(date +%s)
rec() { printf '{"state":"%s","project":"%s","branch":"%s","since":%s,"session_id":"s"}\n' "$2" "$3" "$4" "$5" > "$SESS/$1.json"; }
run() { PATH="$T_DIR/bin:$PATH" sh "$AGENTS" "$@" 2>&1 </dev/null; }

rec %1 idle    alpha main    $((now - 7300))
rec %2 working beta  feat-x  $((now - 125))
rec %3 waiting gamma fix/y   $((now - 30))
rec %4 waiting delta main    $((now - 900))
rec %9 working gone  main    $((now - 10))
printf '%s\n' '%1 $1 @1' '%2 $1 @2' '%3 $2 @3' '%4 $3 @4' > "$FAKE_PANES"

echo "the list: waiting first (longest waiting first), then working, then idle"
out=$(run --list)
assert_eq "four rows, the dead pane is not listed" 4 "$(printf '%s\n' "$out" | grep -c .)"
assert_eq "order by state, then by how long" "delta gamma beta alpha" "$(printf '%s\n' "$out" | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//')"
assert_eq "columns: state project branch age" "waiting delta main 15m" "$(printf '%s\n' "$out" | sed -n 1p | tr -s ' ')"
assert_eq "seconds" "waiting gamma fix/y" "$(printf '%s\n' "$out" | sed -n 2p | tr -s ' ' | grep -E '^waiting gamma fix/y 3[0-9]s$' | sed 's/ [0-9]*s$//')"
assert_eq "minutes" "working beta feat-x 2m" "$(printf '%s\n' "$out" | sed -n 3p | tr -s ' ')"
assert_eq "hours" "idle alpha main 2h" "$(printf '%s\n' "$out" | sed -n 4p | tr -s ' ')"

echo "a record whose pane is gone is removed; the others stay"
refute "the dead pane's file is gone" test -e "$SESS/%9.json"
assert "a live pane's file stays" test -e "$SESS/%1.json"

echo "when tmux cannot be asked, nothing is removed and nothing is listed"
rec %9 working gone main "$now"
out=$(FAKE_TMUX_FAIL=1 run --list); assert_eq "nothing listed" "" "$out"
assert "the record is kept" test -e "$SESS/%9.json"
rm -f "$SESS/%9.json"

echo "the count of waiting sessions, for the status line"
assert_eq "two waiting" "⏳2" "$(run --count)"
rec %3 idle gamma fix/y "$now"; rec %4 working delta main "$now"
assert_eq "none waiting: nothing at all" "" "$(run --count)"
rec %3 waiting gamma fix/y $((now - 30)); rec %4 waiting delta main $((now - 900))
rec %9 waiting gone main "$now"
assert_eq "a dead pane is not counted" "⏳2" "$(run --count)"
assert "and --count removes nothing" test -e "$SESS/%9.json"
rm -f "$SESS/%9.json"
assert_eq "an unreachable tmux counts nothing" "" "$(FAKE_TMUX_FAIL=1 run --count)"

echo "the count does not slow down with the number of records"
for i in $(seq 100 199); do rec %$i waiting bulk main "$now"; printf '%%%s $1 @1\n' "$i" >> "$FAKE_PANES"; done
t0=$(date +%s%N 2>/dev/null || echo 0)
assert_eq "100 more waiting agents are counted" "⏳102" "$(run --count)"
t1=$(date +%s%N 2>/dev/null || echo 0)
if [ "$t0" != 0 ] && [ "${t0%N}" = "$t0" ]; then assert "and it takes well under half a second" test $(( (t1 - t0) / 1000000 )) -lt 500; fi
rm -f "$SESS"/%1[0-9][0-9].json; head -n 4 "$FAKE_PANES" > "$FAKE_PANES.4"; mv "$FAKE_PANES.4" "$FAKE_PANES"

echo "jump goes to the session, the window and the pane, on the client that asked"
: > "$LOG"; out=$(run --jump %3); rc=$?
assert_eq "exit 0" 0 "$rc"
assert_eq "select-window (session-qualified), select-pane, then switch-client last" 'select-window -t $2:@3|select-pane -t %3|switch-client -t $2' "$(paste -sd'|' "$LOG")"
: > "$LOG"; run --client /dev/ttys009 --jump %3 >/dev/null
assert_eq "with a client the switch names it" 'select-window -t $2:@3|select-pane -t %3|switch-client -c /dev/ttys009 -t $2' "$(paste -sd'|' "$LOG")"
: > "$LOG"; out=$(FAKE_SELECT_FAIL=1 run --client /dev/ttys009 --jump %3); rc=$?
assert "a window that closed meanwhile fails the jump" test "$rc" -ne 0
refute "and the client is not moved to another session" grep -q switch-client "$LOG"
: > "$LOG"; out=$(run --jump %77); rc=$?
assert "a pane that is gone is refused" test "$rc" -ne 0
assert_eq "and nothing is switched" "" "$(cat "$LOG")"
out=$(run --jump '%1;touch x'); rc=$?
assert "a pane id that is not %N is refused" test "$rc" -ne 0

echo "a record that was not updated for two hours is marked with a question mark"
rec %1 idle alpha main $((now - 7300))
touch -t 202001010000 "$SESS/%1.json"
out=$(run --list)
assert_eq "the stale one is marked" "idle? alpha main 2h" "$(printf '%s\n' "$out" | grep alpha | tr -s ' ')"
assert_eq "a fresh one is not" "working beta feat-x 2m" "$(printf '%s\n' "$out" | grep beta | tr -s ' ')"
rec %1 idle alpha main $((now - 7300))

echo "a stale waiting record is not counted: the status line must not claim an agent needs you when it crashed long ago"
assert_eq "two waiting before" "⏳2" "$(run --count)"
touch -t 202001010000 "$SESS/%3.json"
assert_eq "the stale one is left out" "⏳1" "$(run --count)"
rec %3 waiting gamma fix/y $((now - 30))
assert_eq "a fresh one counts again" "⏳2" "$(run --count)"

echo "a record that changed after it was read is not removed"
rec %9 working gone main "$now"
mkdir -p "$T_DIR/jqbin"; REALJQ=$(command -v jq)
cat > "$T_DIR/jqbin/jq" <<SH
#!/bin/sh
"$REALJQ" "\$@"; rc=\$?
# A hook rewrites the file of the vanished pane right after it was read.
if [ -e "$T_DIR/inject" ]; then rm -f "$T_DIR/inject"; printf '{"state":"idle","project":"back","branch":"main","since":%s,"session_id":"n"}\n' "$now" > "$SESS/%9.json"; fi
exit \$rc
SH
chmod +x "$T_DIR/jqbin/jq"
touch "$T_DIR/inject"
PATH="$T_DIR/jqbin:$T_DIR/bin:$PATH" sh "$AGENTS" --list >/dev/null 2>&1 </dev/null
assert "the changed file is kept" test -e "$SESS/%9.json"
assert_eq "with its new content" back "$(jq -r .project "$SESS/%9.json")"
run --list >/dev/null
refute "an unchanged one for a vanished pane is removed on the next look" test -e "$SESS/%9.json"

echo "only this tmux server's records are read; directories of dead servers are swept"
OTHER=$XDG_STATE_HOME/cli-workbench/sessions/200-1700000001; mkdir -p "$OTHER"
printf '{"state":"waiting","project":"old","branch":"x","since":%s}\n' "$now" > "$OTHER/%1.json"
assert_eq "a record of another server is not listed" 0 "$(run --list | grep -c old)"
assert_eq "nor counted" "⏳2" "$(run --count)"
sleep 0.1 & dead=$!; wait "$dead"
DEAD=$XDG_STATE_HOME/cli-workbench/sessions/$dead-1700000002; mkdir -p "$DEAD"
LIVEDIR=$XDG_STATE_HOME/cli-workbench/sessions/$$-1700000003; mkdir -p "$LIVEDIR"
EPERMDIR=$XDG_STATE_HOME/cli-workbench/sessions/1-1700000004; mkdir -p "$EPERMDIR"
FAKE_TMUX_FAIL=1 PATH="$T_DIR/bin:$PATH" sh "$AGENTS" >/dev/null 2>&1 </dev/null
FAKE_LIST_FAIL=1 PATH="$T_DIR/bin:$PATH" sh "$AGENTS" >/dev/null 2>&1 </dev/null
assert "nothing is swept when tmux cannot be asked" test -d "$DEAD"
FAKE_PICK=9 PATH="$T_DIR/bin:$PATH" sh "$AGENTS" >/dev/null 2>&1 </dev/null
refute "the directory of a server that is certainly gone is removed" test -e "$DEAD"
assert "a server that still runs keeps its directory" test -d "$LIVEDIR"
assert "a pid that exists but is not ours (permission denied, or ours) is never swept" test -d "$EPERMDIR"
rm -rf "$OTHER" "$LIVEDIR" "$EPERMDIR"

echo "without jq the list says so and the count stays silent"
mkdir -p "$T_DIR/tools2"
for c in sh sort cut sed awk tr date cat head rm ls basename mkdir grep paste printf cksum find; do
  p=$(command -v "$c") && [ -x "$p" ] && ln -sf "$p" "$T_DIR/tools2/$c"
done
assert_eq "--list explains" "jq is required" "$(PATH="$T_DIR/bin:$T_DIR/tools2" sh "$AGENTS" --list 2>&1 </dev/null)"
assert_eq "--count prints nothing" "" "$(PATH="$T_DIR/bin:$T_DIR/tools2" sh "$AGENTS" --count 2>&1 </dev/null)"
assert_contains "the popup explains too" "jq is required" "$(PATH="$T_DIR/bin:$T_DIR/tools2" sh "$AGENTS" 2>&1 <<<"")"

echo "the picker with fzf: the choice is jumped to"
cat > "$T_DIR/bin/fzf" <<'SH'
#!/bin/sh
sed -n "${FAKE_PICK:-1}p"
SH
chmod +x "$T_DIR/bin/fzf"
: > "$LOG"; FAKE_PICK=2 run >/dev/null
assert_eq "the second row (gamma, pane %3) was jumped to" 'select-window -t $2:@3|select-pane -t %3|switch-client -t $2' "$(paste -sd'|' "$LOG")"
: > "$LOG"; out=$(PATH="$T_DIR/bin:$PATH" FAKE_PICK=9 sh "$AGENTS" </dev/null 2>&1)
assert_eq "no choice (fzf closed) jumps nowhere" "" "$(cat "$LOG")"
rm "$T_DIR/bin/fzf"

echo "the picker without fzf is a numbered menu"
mkdir -p "$T_DIR/tools"
for c in sh jq sort cut sed awk tr date cat head rm ls basename mkdir grep paste printf cksum find; do
  p=$(command -v "$c") && [ -x "$p" ] && ln -sf "$p" "$T_DIR/tools/$c"
done
menu() { PATH="$T_DIR/bin:$T_DIR/tools" sh "$AGENTS" 2>&1 <<<"$1"; }
: > "$LOG"; out=$(menu 3)
assert_contains "the rows are numbered" "1) waiting" "$out"
assert_eq "choosing 3 jumps to the third row (beta, pane %2)" 'select-window -t $1:@2|select-pane -t %2|switch-client -t $1' "$(paste -sd'|' "$LOG")"
: > "$LOG"; menu 0 >/dev/null; menu 99 >/dev/null; menu x >/dev/null; menu "" >/dev/null
assert_eq "an invalid or empty choice jumps nowhere" "" "$(cat "$LOG")"

echo "with no sessions the popup says so and waits for a key"
rm -f "$SESS"/*.json
out=$(PATH="$T_DIR/bin:$T_DIR/tools" sh "$AGENTS" 2>&1 <<<"")
assert_contains "it explains" "No agent sessions" "$out"

echo "with a real tmux and two clients, the client that opened the popup is the one that moves"
REAL=$(command -v tmux)
if [ -n "$REAL" ] && "$REAL" -L "wbagents$$" -f /dev/null new-session -d -s one 2>/dev/null \
   && "$REAL" -L "wbagents$$" has-session -t one 2>/dev/null; then
  SOCK=wbagents$$
  trap '"$REAL" -L "$SOCK" kill-server 2>/dev/null; t_cleanup' EXIT
  mkdir -p "$T_DIR/real"
  printf '#!/bin/sh\nexec "%s" -L "%s" "$@"\n' "$REAL" "$SOCK" > "$T_DIR/real/tmux"; chmod +x "$T_DIR/real/tmux"
  "$REAL" -L "$SOCK" new-session -d -s two
  (sleep 15 | "$REAL" -L "$SOCK" -C attach -t one >/dev/null 2>&1 &)
  (sleep 15 | "$REAL" -L "$SOCK" -C attach -t one >/dev/null 2>&1 &)
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$("$REAL" -L "$SOCK" list-clients 2>/dev/null | wc -l | tr -d ' ')" = 2 ] && break; sleep 0.3; done
  A=$("$REAL" -L "$SOCK" list-clients -F '#{client_name}' | sed -n 1p); B=$("$REAL" -L "$SOCK" list-clients -F '#{client_name}' | sed -n 2p)
  target=$("$REAL" -L "$SOCK" list-panes -t two -F '#{pane_id}' | sed -n 1p)
  PATH="$T_DIR/real:$PATH" sh "$AGENTS" --client "$A" --jump "$target" >/dev/null 2>&1 </dev/null
  assert_eq "the asking client is in the target session" two "$("$REAL" -L "$SOCK" list-clients -F '#{client_name} #{session_name}' | grep "^$A " | cut -d' ' -f2)"
  assert_eq "the other client stays where it was" one "$("$REAL" -L "$SOCK" list-clients -F '#{client_name} #{session_name}' | grep "^$B " | cut -d' ' -f2)"
  PATH="$T_DIR/real:$PATH" sh "$AGENTS" --client "$B" --jump "$target" >/dev/null 2>&1 </dev/null
  assert_eq "and the other one moves when it is the one that asks" two "$("$REAL" -L "$SOCK" list-clients -F '#{client_name} #{session_name}' | grep "^$B " | cut -d' ' -f2)"
  "$REAL" -L "$SOCK" kill-server 2>/dev/null
else
  echo "  skip  tmux cannot run a throwaway server here"
fi

echo "tmux binds prefix+O to the popup, shows the waiting count in the status line, and deploys both scripts"
if command -v tmux >/dev/null && command -v chezmoi >/dev/null; then
  R=$T_DIR/render; mkdir -p "$R"; t_render "$R"
  line=$(grep -E 'bind O display-popup' "$R/.tmux.conf")
  assert_contains "prefix+O opens the overview" "tmux/scripts/agents.sh" "$line"
  assert_contains "and tells it which client opened the popup" "agents.sh --client #{client_name}" "$line"
  refute "no directory is passed into the shell" grep -q 'pane_current_path' <<<"$line"
  assert_contains "status-right shows the count" "#(~/.tmux/scripts/agents.sh --count)" "$(grep '^set -g status-right ' "$R/.tmux.conf")"
  assert "the overview is deployed executable" test -x "$R/.tmux/scripts/agents.sh"
  assert "the state script is deployed executable" test -x "$R/.tmux/scripts/agent-state.sh"
else
  echo "  skip  tmux or chezmoi not installed"
fi
t_done
