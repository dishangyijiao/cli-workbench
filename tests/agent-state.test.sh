#!/usr/bin/env bash
# agent-state.sh is what Claude Code hooks call: it records one JSON file per tmux pane saying whether the agent in it
# is working, waiting for you or idle. The last event wins; the overview heals itself. It runs against a stub of tmux,
# in a throwaway HOME and state directory.
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

echo "working writes one JSON file for the pane, under the tmux server's directory"
out=$(hook "$P/sub" working '{"session_id":"abc-123"}'); rc=$?
assert_eq "exit 0" 0 "$rc"; assert_eq "prints nothing" "" "$out"
assert "the file is valid JSON" jq -e . "$FILE"
assert_eq "state" working "$(f state)"
assert_eq "project is the repository's directory name" proj "$(f project)"
assert_eq "branch" main "$(f branch)"
assert_eq "session id comes from the hook payload" abc-123 "$(f session_id)"
assert "since is an epoch close to now" test "$(( $(date +%s) - $(f since) ))" -lt 10
assert_eq "exactly the five fields" "branch project session_id since state" "$(jq -r 'keys | join(" ")' "$FILE")"
assert_eq "no temporary file is left" 1 "$(ls -A "$SESS" | wc -l | tr -d ' ')"
assert_eq "the file is private (600)" 600 "$(stat -c %a "$FILE" 2>/dev/null || stat -f %Lp "$FILE")"

echo "the file is replaced atomically: written beside the final name, then renamed over it"
assert "the rename comes from a temporary file in the same directory" grep -q "^$SESS/\.%7\..*\.tmp $FILE\$" <(sed 's/^-f //' "$MV_LOG")
# A reader that polls while a writer runs 40 times must never see an empty or half-written file.
bad=0
( for _ in $(seq 1 40); do hook "$P" working '{"session_id":"abc-123"}' >/dev/null; hook "$P" idle '{"session_id":"abc-123"}' >/dev/null; done; touch "$T_DIR/writer-done" ) &
while [ ! -e "$T_DIR/writer-done" ]; do
  if [ -e "$FILE" ]; then jq -e '.state' "$FILE" >/dev/null 2>&1 || bad=$((bad + 1)); fi
done
wait
assert_eq "a reader never saw an invalid file" 0 "$bad"

echo "a pane id reused by a restarted tmux server does not inherit the old record"
hook "$P" working '{"session_id":"abc-123"}' >/dev/null
FAKE_SERVER=200-1700009999 hook "$P" idle '{"session_id":"zzz"}' >/dev/null
assert "the new server has its own directory" test -s "$XDG_STATE_HOME/cli-workbench/sessions/200-1700009999/%7.json"
assert_eq "the old server's record is untouched" abc-123 "$(f session_id)"
rm -rf "$XDG_STATE_HOME/cli-workbench/sessions/200-1700009999"

echo "the last event wins"
hook "$P" working '{"session_id":"s"}' >/dev/null; assert_eq "working" working "$(f state)"
hook "$P" waiting '{"session_id":"s"}' >/dev/null; assert_eq "waiting" waiting "$(f state)"
hook "$P" idle '{"session_id":"s"}' >/dev/null;    assert_eq "idle" idle "$(f state)"
hook "$P" working '{"session_id":"t"}' >/dev/null; assert_eq "a new session in the pane simply replaces the record" t "$(f session_id)"

echo "since moves only when the state changes"
jq -c '.since = 1000' "$FILE" > "$T_DIR/x" && mv "$T_DIR/x" "$FILE"
hook "$P" working '{"session_id":"t"}' >/dev/null
assert_eq "the same state again keeps since" 1000 "$(f since)"
hook "$P" waiting '{"session_id":"t"}' >/dev/null
assert "a new state restarts the clock" test "$(f since)" -gt 1000

echo "heal turns waiting into working, and does nothing else"
hook "$P" waiting >/dev/null; hook "$P" heal >/dev/null
assert_eq "waiting becomes working" working "$(f state)"
hook "$P" idle >/dev/null; hook "$P" heal >/dev/null
assert_eq "idle stays idle" idle "$(f state)"
hook "$P" working >/dev/null; hook "$P" heal >/dev/null
assert_eq "working stays working" working "$(f state)"
hook "$P" end >/dev/null; hook "$P" heal >/dev/null
refute "no file is created from nothing" test -e "$FILE"

echo "end removes the file"
hook "$P" working >/dev/null; hook "$P" end >/dev/null
refute "the file is gone" test -e "$FILE"
out=$(hook "$P" end); assert_eq "ending twice is fine and silent" "" "$out"

echo "a worktree is filed under the repository it belongs to"
g "$P" worktree add -q "$T_DIR/wt/feature-x" -b feature-x
hook "$T_DIR/wt/feature-x" working >/dev/null
assert_eq "project" proj "$(f project)"
assert_eq "branch of the worktree" feature-x "$(f branch)"
hook "$T_DIR" working >/dev/null
assert_eq "outside a repository: the directory name" "$(basename "$T_DIR")" "$(f project)"
assert_eq "and no branch" "" "$(f branch)"

echo "names with quotes and backslashes still give valid JSON"
W=$T_DIR/'we"ird\dir'; mkdir -p "$W"; g "$W" init -q -b 'fe"at'"'"'q'; g "$W" commit -q --allow-empty -m one
hook "$W" working >/dev/null
assert "valid JSON" jq -e . "$FILE"
assert_eq "the name survives" 'we"ird\dir' "$(f project)"
assert_eq "so does the branch" 'fe"at'"'"'q' "$(f branch)"

echo "only entering waiting rings the pane's terminal"
rm -f "$FILE"; : > "$FAKE_TTY"
hook "$P" working >/dev/null; hook "$P" idle >/dev/null
assert_eq "working and idle are silent" 0 "$(wc -c < "$FAKE_TTY" | tr -d ' ')"
hook "$P" waiting >/dev/null
assert_eq "waiting writes one bell" "07" "$(od -An -tx1 "$FAKE_TTY" | tr -d ' \n')"
hook "$P" waiting >/dev/null
assert_eq "a second waiting while still waiting does not ring again" "07" "$(od -An -tx1 "$FAKE_TTY" | tr -d ' \n')"
hook "$P" heal >/dev/null; hook "$P" waiting >/dev/null
assert_eq "waiting again after it was answered rings again" "0707" "$(od -An -tx1 "$FAKE_TTY" | tr -d ' \n')"

echo "outside tmux, or with a bad pane id, nothing happens"
rm -rf "$XDG_STATE_HOME"
out=$(cd "$P" && env -u TMUX_PANE PATH="$T_DIR/bin:$PATH" sh "$STATE" working </dev/null 2>&1); rc=$?
assert_eq "exit 0 without TMUX_PANE" 0 "$rc"; assert_eq "silent" "" "$out"
refute "no state directory is created" test -e "$XDG_STATE_HOME"
out=$(cd "$P" && TMUX_PANE='%1/../../evil' PATH="$T_DIR/bin:$PATH" sh "$STATE" working </dev/null 2>&1); rc=$?
assert_eq "a pane id that is not %N is ignored" 0 "$rc"
refute "and writes nothing" test -e "$XDG_STATE_HOME"

echo "it never fails and never prints"
out=$(hook "$P" nonsense); rc=$?
assert_eq "an unknown action exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
refute "and writes nothing" test -e "$FILE"
out=$(hook "$P" working 'not json {{{'); rc=$?
assert_eq "a garbage payload exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
assert_eq "and the state is still recorded" working "$(f state)"
echo x > "$T_DIR/afile"
out=$(cd "$P" && XDG_STATE_HOME="$T_DIR/afile" TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" working </dev/null 2>&1); rc=$?
assert_eq "an unwritable state directory exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
out=$(cd "$P" && TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" </dev/null 2>&1); rc=$?
assert_eq "no argument exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
mkdir -p "$T_DIR/bin2"; printf '#!/bin/sh\nexit 1\n' > "$T_DIR/bin2/tmux"; chmod +x "$T_DIR/bin2/tmux"
rm -f "$FILE"
out=$(cd "$P" && TMUX_PANE=%7 PATH="$T_DIR/bin2:$PATH" sh "$STATE" working </dev/null 2>&1); rc=$?
assert_eq "a tmux that cannot be asked: exit 0" 0 "$rc"; assert_eq "silently" "" "$out"
refute "and nothing is written" test -e "$FILE"

echo "without jq the hook stays silent and writes nothing"
mkdir -p "$T_DIR/nojq"
for c in sh tmux mv date head git cat sed tr rm mkdir dirname basename; do p=$(PATH="$T_DIR/bin:$PATH" command -v "$c") && ln -sf "$p" "$T_DIR/nojq/$c"; done
out=$(cd "$P" && printf '' | TMUX_PANE=%7 PATH="$T_DIR/nojq" sh "$STATE" working 2>&1); rc=$?
assert_eq "exit 0" 0 "$rc"; assert_eq "silently" "" "$out"
refute "and writes nothing" test -e "$FILE"

echo "without XDG_STATE_HOME the state lives under ~/.local/state"
rm -rf "$XDG_STATE_HOME"
(cd "$P" && printf '' | env -u XDG_STATE_HOME TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" idle)
assert "the default directory is used" test -s "$HOME/.local/state/cli-workbench/sessions/$SRV/%7.json"
t_done
