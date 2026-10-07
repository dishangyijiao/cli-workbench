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
SESS=$XDG_STATE_HOME/cli-workbench/sessions; mkdir -p "$SESS"
LOG=$T_DIR/log; : > "$LOG"

# tmux stub: list-panes answers with the lines of $FAKE_PANES ("%pane $session @window"); FAKE_TMUX_FAIL=1 makes it fail like
# an unreachable server; every other command is logged.
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/bin/tmux" <<'SH'
#!/bin/sh
[ "${FAKE_TMUX_FAIL:-}" = 1 ] && exit 1
if [ "$1" = list-panes ]; then cat "$FAKE_PANES"; exit 0; fi
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
assert "seconds" printf '%s\n' "$(printf '%s\n' "$out" | sed -n 2p | tr -s ' ' | grep -E '^waiting gamma fix/y 3[0-9]s$')"
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

echo "jump goes to the session, the window and the pane"
: > "$LOG"; out=$(run --jump %3); rc=$?
assert_eq "exit 0" 0 "$rc"
assert_eq "switch-client, select-window, select-pane, in that order" 'switch-client -t $2|select-window -t @3|select-pane -t %3' "$(paste -sd'|' "$LOG")"
: > "$LOG"; out=$(run --jump %77); rc=$?
assert "a pane that is gone is refused" test "$rc" -ne 0
assert_eq "and nothing is switched" "" "$(cat "$LOG")"
out=$(run --jump '%1;touch x'); rc=$?
assert "a pane id that is not %N is refused" test "$rc" -ne 0

echo "the picker with fzf: the choice is jumped to"
cat > "$T_DIR/bin/fzf" <<'SH'
#!/bin/sh
sed -n "${FAKE_PICK:-1}p"
SH
chmod +x "$T_DIR/bin/fzf"
: > "$LOG"; FAKE_PICK=2 run >/dev/null
assert_eq "the second row (gamma, pane %3) was jumped to" 'switch-client -t $2|select-window -t @3|select-pane -t %3' "$(paste -sd'|' "$LOG")"
: > "$LOG"; out=$(PATH="$T_DIR/bin:$PATH" FAKE_PICK=9 sh "$AGENTS" </dev/null 2>&1)
assert_eq "no choice (fzf closed) jumps nowhere" "" "$(cat "$LOG")"
rm "$T_DIR/bin/fzf"

echo "the picker without fzf is a numbered menu"
mkdir -p "$T_DIR/tools"
for c in sh jq sort cut sed awk tr date cat head rm ls basename mkdir grep paste printf; do
  p=$(command -v "$c") && [ -x "$p" ] && ln -sf "$p" "$T_DIR/tools/$c"
done
menu() { PATH="$T_DIR/bin:$T_DIR/tools" sh "$AGENTS" 2>&1 <<<"$1"; }
: > "$LOG"; out=$(menu 3)
assert_contains "the rows are numbered" "1) waiting" "$out"
assert_eq "choosing 3 jumps to the third row (beta, pane %2)" 'switch-client -t $1|select-window -t @2|select-pane -t %2' "$(paste -sd'|' "$LOG")"
: > "$LOG"; menu 0 >/dev/null; menu 99 >/dev/null; menu x >/dev/null; menu "" >/dev/null
assert_eq "an invalid or empty choice jumps nowhere" "" "$(cat "$LOG")"

echo "with no sessions the popup says so and waits for a key"
rm -f "$SESS"/*.json
out=$(PATH="$T_DIR/bin:$T_DIR/tools" sh "$AGENTS" 2>&1 <<<"")
assert_contains "it explains" "No agent sessions" "$out"

echo "tmux binds prefix+O to the popup, shows the waiting count in the status line, and deploys both scripts"
if command -v tmux >/dev/null && command -v chezmoi >/dev/null; then
  R=$T_DIR/render; mkdir -p "$R"; t_render "$R"
  line=$(grep -E 'bind O display-popup' "$R/.tmux.conf")
  assert_contains "prefix+O opens the overview" "tmux/scripts/agents.sh" "$line"
  refute "no directory is passed into the shell" grep -q 'pane_current_path' <<<"$line"
  assert_contains "status-right shows the count" "#(~/.tmux/scripts/agents.sh --count)" "$(grep '^set -g status-right ' "$R/.tmux.conf")"
  assert "the overview is deployed executable" test -x "$R/.tmux/scripts/agents.sh"
  assert "the state script is deployed executable" test -x "$R/.tmux/scripts/agent-state.sh"
else
  echo "  skip  tmux or chezmoi not installed"
fi
t_done
