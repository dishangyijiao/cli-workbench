#!/usr/bin/env bash
# agent-state.sh is what Claude Code hooks call: it records one JSON file per tmux pane saying whether the agent in it
# is working, waiting for you or idle. It runs against a stub of tmux, in a throwaway HOME and state directory.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
for c in git jq; do command -v "$c" >/dev/null || { echo "$c not installed; skipped"; exit 0; }; done
T_DIR=$(cd -P "$(mktemp -d "${TMPDIR:-/tmp}/wb-agent.XXXXXX")" && pwd)
trap t_cleanup EXIT
STATE=$WB_SRC/home/dot_tmux/scripts/executable_agent-state.sh
export HOME=$T_DIR/home; mkdir -p "$HOME"
export XDG_STATE_HOME=$T_DIR/state
SRV=100-1700000000
export FAKE_SERVER=$SRV
SESS=$XDG_STATE_HOME/cli-workbench/sessions/$SRV
FILE=$SESS/%7.json

# tmux stub: display-message answers "<server pid>-<start time> <pane tty>"; a plain file stands in for the terminal.
# mv stub: logs every move, then moves.
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/bin/tmux" <<'SH'
#!/bin/sh
[ "$1" = display-message ] && printf '%s %s\n' "$FAKE_SERVER" "$FAKE_TTY"
exit 0
SH
cat > "$T_DIR/bin/mv" <<'SH'
#!/bin/sh
echo "$*" >> "$MV_LOG"
exec /bin/mv "$@"
SH
chmod +x "$T_DIR/bin/tmux" "$T_DIR/bin/mv"
export FAKE_TTY=$T_DIR/tty; : > "$FAKE_TTY"
export MV_LOG=$T_DIR/mv.log; : > "$MV_LOG"
# hook DIR ACTION [JSON]: as a hook runs it in pane %7, from directory DIR. The JSON is the hook's stdin.
hook() { (cd "$1" && printf '%s' "${3-}" | TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" "$2" 2>&1); }
f() { jq -r ".$1" "$FILE" 2>/dev/null; }
g() { git -C "$1" -c user.name=t -c user.email=t@example.invalid "${@:2}" >/dev/null 2>&1; }

P=$T_DIR/proj; mkdir -p "$P/sub"; g "$P" init -q -b main; g "$P" commit -q --allow-empty -m one

echo "begin (a turn starts) writes one JSON file for the pane, under the tmux server's directory"
out=$(hook "$P/sub" begin '{"session_id":"abc-123","ts":1000}'); rc=$?
assert_eq "exit 0" 0 "$rc"; assert_eq "prints nothing" "" "$out"
assert "the file is valid JSON" jq -e . "$FILE"
assert_eq "state" working "$(f state)"
assert_eq "project is the repository's directory name" proj "$(f project)"
assert_eq "branch" main "$(f branch)"
assert_eq "session id comes from the hook payload" abc-123 "$(f session_id)"
assert "since is an epoch close to now" test "$(( $(date +%s) - $(f since) ))" -lt 10
assert_eq "no temporary file or lock is left" 1 "$(ls -A "$SESS" | wc -l | tr -d ' ')"
assert_eq "the file is private (600)" 600 "$(stat -c %a "$FILE" 2>/dev/null || stat -f %Lp "$FILE")"
assert "the final file is put in place by a rename from a temporary file in the same directory" grep -q "^$SESS/\.%7\..*\.tmp $FILE\$" <(sed 's/^-f //' "$MV_LOG")

echo "a pane id reused by a restarted tmux server does not inherit the old record"
FAKE_SERVER=200-1700009999 hook "$P" begin '{"session_id":"zzz","ts":2000}' >/dev/null
assert "the new server has its own directory" test -s "$XDG_STATE_HOME/cli-workbench/sessions/200-1700009999/%7.json"
assert_eq "the old server's record is untouched" abc-123 "$(f session_id)"
rm -rf "$XDG_STATE_HOME/cli-workbench/sessions/200-1700009999"

echo "waits are keyed: only the answer to that request ends the wait"
hook "$P" wait '{"session_id":"abc-123","ts":1100,"key":"a"}' >/dev/null
assert_eq "waiting" waiting "$(f state)"
hook "$P" wait '{"session_id":"abc-123","ts":1200,"key":"b"}' >/dev/null
hook "$P" unwait '{"session_id":"abc-123","ts":1300,"key":"zzz"}' >/dev/null
assert_eq "an unrelated answer does not end the wait" waiting "$(f state)"
hook "$P" unwait '{"session_id":"abc-123","ts":1400,"key":"a"}' >/dev/null
assert_eq "one wait answered, one left: still waiting" waiting "$(f state)"
hook "$P" unwait '{"session_id":"abc-123","ts":1500,"key":"b"}' >/dev/null
assert_eq "all answered: working again" working "$(f state)"
hook "$P" wait '{"session_id":"abc-123","ts":1600,"key":"n:x"}' >/dev/null
hook "$P" wait '{"session_id":"abc-123","ts":1700,"key":"n:y"}' >/dev/null
hook "$P" unwait-prefix '{"session_id":"abc-123","ts":1800,"key":"n:"}' >/dev/null
assert_eq "a prefix answer ends every wait that starts with it" working "$(f state)"
hook "$P" wait '{"session_id":"abc-123","ts":1900,"key":"a"}' >/dev/null
hook "$P" unwait '{"session_id":"abc-123","ts":2000}' >/dev/null
assert_eq "an answer without a key ends all waits" working "$(f state)"

echo "a turn start, a turn end and a session start end every wait"
hook "$P" wait '{"session_id":"abc-123","ts":2100,"key":"a"}' >/dev/null
hook "$P" idle '{"session_id":"abc-123","ts":2200}' >/dev/null
assert_eq "the turn ended: idle, no wait left" idle "$(f state)"
assert_eq "no waits stored" 0 "$(f 'waits|length')"
hook "$P" wait '{"session_id":"abc-123","ts":2300,"key":"a"}' >/dev/null
hook "$P" begin '{"session_id":"abc-123","ts":2400}' >/dev/null
assert_eq "a new turn: working, no wait left" working "$(f state)"
hook "$P" wait '{"session_id":"abc-123","ts":2500,"key":"a"}' >/dev/null
hook "$P" start '{"session_id":"abc-123","ts":2600}' >/dev/null
assert_eq "a session start: idle" idle "$(f state)"

echo "since moves only when the shown state changes"
jq -c '.since = 1000' "$FILE" > "$T_DIR/x" && mv "$T_DIR/x" "$FILE"
hook "$P" idle '{"session_id":"abc-123","ts":2700}' >/dev/null
assert_eq "idle again keeps since" 1000 "$(f since)"
hook "$P" begin '{"session_id":"abc-123","ts":2800}' >/dev/null
assert "working restarts the clock" test "$(f since)" -gt 1000

echo "events arrive late and out of order; the newest one wins"
hook "$P" begin '{"session_id":"abc-123","ts":5000}' >/dev/null
hook "$P" idle '{"session_id":"abc-123","ts":6000}' >/dev/null
hook "$P" wait '{"session_id":"abc-123","ts":5500,"key":"late"}' >/dev/null
assert_eq "a delayed wait does not overwrite a newer idle" idle "$(f state)"
hook "$P" end '{"session_id":"abc-123","ts":7000}' >/dev/null
assert_eq "an end leaves a tombstone, not nothing" ended "$(f state)"
hook "$P" wait '{"session_id":"abc-123","ts":6500,"key":"late"}' >/dev/null
hook "$P" begin '{"session_id":"abc-123","ts":6600}' >/dev/null
assert_eq "writes still in flight when the session ended do not bring it back" ended "$(f state)"

echo "an answer that overtakes its own request still wins; a late turn start does not clear a newer wait"
rm -f "$FILE"
hook "$P" begin '{"session_id":"s","ts":100}' >/dev/null
hook "$P" unwait '{"session_id":"s","ts":300,"key":"q"}' >/dev/null
hook "$P" wait '{"session_id":"s","ts":250,"key":"q"}' >/dev/null
assert_eq "the answer came first, so the request is not left open" working "$(f state)"
hook "$P" wait '{"session_id":"s","ts":400,"key":"r"}' >/dev/null
hook "$P" begin '{"session_id":"s","ts":350}' >/dev/null
assert_eq "a turn start older than the wait leaves the wait" waiting "$(f state)"

echo "another session in the pane: the older session's events do nothing"
hook "$P" begin '{"session_id":"new-1","ts":8000}' >/dev/null
assert_eq "the new session takes the pane" new-1 "$(f session_id)"
assert_eq "and starts its own clock" working "$(f state)"
hook "$P" end '{"session_id":"abc-123","ts":7500}' >/dev/null
assert_eq "the old session's late end does not remove the new record" new-1 "$(f session_id)"
assert_eq "and the new session is still working" working "$(f state)"
hook "$P" end '{"session_id":"abc-123","ts":9000}' >/dev/null
assert_eq "even a newer end of another session is not ours to apply" new-1 "$(f session_id)"
hook "$P" idle '{"session_id":"abc-123","ts":7600}' >/dev/null
assert_eq "an older session's turn end is ignored" working "$(f state)"
jq -c '.since = 1000' "$FILE" > "$T_DIR/x" && mv "$T_DIR/x" "$FILE"
hook "$P" begin '{"session_id":"new-2","ts":9500}' >/dev/null
assert "a newer session does not inherit the old since" test "$(f since)" -gt 1000

echo "a worktree is filed under the repository it belongs to"
rm -f "$FILE"
g "$P" worktree add -q "$T_DIR/wt/feature-x" -b feature-x
hook "$T_DIR/wt/feature-x" begin '{"ts":1}' >/dev/null
assert_eq "project" proj "$(f project)"
assert_eq "branch of the worktree" feature-x "$(f branch)"
rm -f "$FILE"; hook "$T_DIR" begin '{"ts":1}' >/dev/null
assert_eq "outside a repository: the directory name" "$(basename "$T_DIR")" "$(f project)"
assert_eq "and no branch" "" "$(f branch)"

echo "names with quotes and backslashes still give valid JSON"
rm -f "$FILE"
W=$T_DIR/'we"ird\dir'; mkdir -p "$W"; g "$W" init -q -b 'fe"at'"'"'q'; g "$W" commit -q --allow-empty -m one
hook "$W" begin '{"ts":1}' >/dev/null
assert "valid JSON" jq -e . "$FILE"
assert_eq "the name survives" 'we"ird\dir' "$(f project)"
assert_eq "so does the branch" 'fe"at'"'"'q' "$(f branch)"

echo "only a change into waiting rings the pane's terminal"
rm -f "$FILE"; : > "$FAKE_TTY"
hook "$P" begin '{"session_id":"s","ts":10}' >/dev/null; hook "$P" idle '{"session_id":"s","ts":11}' >/dev/null
assert_eq "working and idle are silent" 0 "$(wc -c < "$FAKE_TTY" | tr -d ' ')"
hook "$P" wait '{"session_id":"s","ts":12,"key":"a"}' >/dev/null
assert_eq "waiting writes one bell" "07" "$(od -An -tx1 "$FAKE_TTY" | tr -d ' \n')"
hook "$P" wait '{"session_id":"s","ts":13,"key":"b"}' >/dev/null
assert_eq "a second wait while still waiting does not ring again" "07" "$(od -An -tx1 "$FAKE_TTY" | tr -d ' \n')"

echo "many hooks at once lose no update (the read-modify-write is serialized)"
rm -f "$FILE"
hook "$P" begin '{"session_id":"s","ts":100}' >/dev/null
for i in $(seq 1 12); do hook "$P" wait "{\"session_id\":\"s\",\"ts\":$((200 + i)),\"key\":\"k$i\"}" >/dev/null & done; wait
assert_eq "every wait is recorded" 12 "$(f 'waits|length')"
for i in $(seq 1 12); do hook "$P" unwait "{\"session_id\":\"s\",\"ts\":$((300 + i)),\"key\":\"k$i\"}" >/dev/null & done; wait
assert_eq "every answer is applied" working "$(f state)"
assert_eq "no lock or temporary file is left" 1 "$(ls -A "$SESS" | wc -l | tr -d ' ')"

echo "a lock left behind by a killed hook does not stop the next one"
mkdir "$SESS/.%7.lock"; touch -t 202001010000 "$SESS/.%7.lock"
hook "$P" idle '{"session_id":"s","ts":900}' >/dev/null
assert_eq "an old lock is taken over" idle "$(f state)"
mkdir "$SESS/.%7.lock"
start=$(date +%s)
out=$(hook "$P" begin '{"session_id":"s","ts":901}'); rc=$?
assert_eq "a fresh lock held by someone else: exit 0" 0 "$rc"; assert_eq "silently" "" "$out"
assert "and within a bounded wait" test "$(( $(date +%s) - start ))" -le 3
assert_eq "the update was dropped, not forced" idle "$(f state)"
assert "the other holder's lock is left alone" test -d "$SESS/.%7.lock"
rmdir "$SESS/.%7.lock"

echo "outside tmux, or with a bad pane id, nothing happens"
rm -rf "$XDG_STATE_HOME"
out=$(cd "$P" && env -u TMUX_PANE PATH="$T_DIR/bin:$PATH" sh "$STATE" begin </dev/null 2>&1); rc=$?
assert_eq "exit 0 without TMUX_PANE" 0 "$rc"; assert_eq "silent" "" "$out"
refute "no state directory is created" test -e "$XDG_STATE_HOME"
out=$(cd "$P" && TMUX_PANE='%1/../../evil' PATH="$T_DIR/bin:$PATH" sh "$STATE" begin </dev/null 2>&1); rc=$?
assert_eq "a pane id that is not %N is ignored" 0 "$rc"
refute "and writes nothing" test -e "$XDG_STATE_HOME"

echo "it never fails and never prints"
out=$(hook "$P" nonsense); rc=$?
assert_eq "an unknown action exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
refute "and writes nothing" test -e "$FILE"
out=$(hook "$P" begin 'not json {{{'); rc=$?
assert_eq "a garbage payload exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
assert_eq "and the state is still recorded" working "$(f state)"
echo x > "$T_DIR/afile"
out=$(cd "$P" && XDG_STATE_HOME="$T_DIR/afile" TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" begin </dev/null 2>&1); rc=$?
assert_eq "an unwritable state directory exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
out=$(cd "$P" && TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" </dev/null 2>&1); rc=$?
assert_eq "no argument exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
printf '#!/bin/sh\nexit 1\n' > "$T_DIR/bin2tmux"; mkdir -p "$T_DIR/bin2"; cp "$T_DIR/bin2tmux" "$T_DIR/bin2/tmux"; chmod +x "$T_DIR/bin2/tmux"
out=$(cd "$P" && TMUX_PANE=%7 PATH="$T_DIR/bin2:$PATH" sh "$STATE" begin </dev/null 2>&1); rc=$?
assert_eq "a tmux that cannot be asked: exit 0" 0 "$rc"; assert_eq "silently" "" "$out"

echo "without XDG_STATE_HOME the state lives under ~/.local/state"
rm -rf "$XDG_STATE_HOME"
(cd "$P" && printf '' | env -u XDG_STATE_HOME TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" idle)
assert "the default directory is used" test -s "$HOME/.local/state/cli-workbench/sessions/$SRV/%7.json"
t_done
