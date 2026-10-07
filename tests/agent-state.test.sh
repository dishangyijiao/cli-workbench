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
SESS=$XDG_STATE_HOME/cli-workbench/sessions

# tmux stub: display-message answers with the tty file in $FAKE_TTY (a plain file stands in for the terminal).
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/bin/tmux" <<'SH'
#!/bin/sh
[ "$1" = display-message ] && printf '%s\n' "$FAKE_TTY"
exit 0
SH
chmod +x "$T_DIR/bin/tmux"
export FAKE_TTY=$T_DIR/tty; : > "$FAKE_TTY"
# hook DIR STATE [STDIN]: as a hook would run it in pane %7, from directory DIR.
hook() { (cd "$1" && printf '%s' "${3-}" | TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" "$2" 2>&1); }
f() { jq -r ".$1" "$SESS/%7.json" 2>/dev/null; }
g() { git -C "$1" -c user.name=t -c user.email=t@example.invalid "${@:2}" >/dev/null 2>&1; }

P=$T_DIR/proj; mkdir -p "$P/sub"; g "$P" init -q -b main; g "$P" commit -q --allow-empty -m one

echo "working writes one JSON file for the pane"
out=$(hook "$P/sub" working '{"session_id":"abc-123","cwd":"/x"}'); rc=$?
assert_eq "exit 0" 0 "$rc"; assert_eq "prints nothing" "" "$out"
assert "the file is valid JSON" jq -e . "$SESS/%7.json"
assert_eq "state" working "$(f state)"
assert_eq "project is the repository's directory name" proj "$(f project)"
assert_eq "branch" main "$(f branch)"
assert_eq "session id comes from the hook payload" abc-123 "$(f session_id)"
assert "since is an epoch close to now" test "$(( $(date +%s) - $(f since) ))" -lt 10
assert_eq "no temporary file is left" 1 "$(ls -A "$SESS" | wc -l | tr -d ' ')"
assert_eq "the file is private (600)" 600 "$(stat -c %a "$SESS/%7.json" 2>/dev/null || stat -f %Lp "$SESS/%7.json")"

echo "the state follows the hooks; since moves only when the state changes"
jq -c '.since = 1000' "$SESS/%7.json" > "$T_DIR/x" && mv "$T_DIR/x" "$SESS/%7.json"
hook "$P" working '{"session_id":"abc-123"}' >/dev/null
assert_eq "same state again keeps since" 1000 "$(f since)"
hook "$P" waiting '{"session_id":"abc-123"}' >/dev/null
assert_eq "waiting" waiting "$(f state)"
assert "a new state restarts the clock" test "$(f since)" -gt 1000
hook "$P" idle >/dev/null
assert_eq "idle, with no payload at all" idle "$(f state)"
assert_eq "an empty payload leaves session_id empty" "" "$(f session_id | sed 's/^null$//')"

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
assert "valid JSON" jq -e . "$SESS/%7.json"
assert_eq "the name survives" 'we"ird\dir' "$(f project)"
assert_eq "so does the branch" 'fe"at'"'"'q' "$(f branch)"

echo "only waiting rings the pane's terminal"
: > "$FAKE_TTY"; hook "$P" working >/dev/null; hook "$P" idle >/dev/null
assert_eq "working and idle are silent" 0 "$(wc -c < "$FAKE_TTY" | tr -d ' ')"
hook "$P" waiting >/dev/null
assert_eq "waiting writes one bell" "07" "$(od -An -tx1 "$FAKE_TTY" | tr -d ' \n')"
hook "$P" waiting >/dev/null
assert_eq "a second waiting while still waiting does not ring again" "07" "$(od -An -tx1 "$FAKE_TTY" | tr -d ' \n')"

echo "resume turns waiting back into working (a tool ran, so you answered), and does nothing else"
hook "$P" waiting >/dev/null; hook "$P" resume >/dev/null
assert_eq "waiting becomes working" working "$(f state)"
hook "$P" idle >/dev/null; hook "$P" resume >/dev/null
assert_eq "idle stays idle" idle "$(f state)"
hook "$P" end >/dev/null; hook "$P" resume >/dev/null
refute "no file is created from nothing" test -e "$SESS/%7.json"

echo "end removes the file"
hook "$P" end >/dev/null
refute "the file is gone" test -e "$SESS/%7.json"
out=$(hook "$P" end); assert_eq "ending twice is fine and silent" "" "$out"

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
assert_eq "an unknown state exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
refute "and writes nothing" test -e "$SESS/%7.json"
out=$(hook "$P" working 'not json {{{'); rc=$?
assert_eq "a garbage payload exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
assert_eq "and the state is still recorded" working "$(f state)"
echo x > "$T_DIR/afile"
out=$(cd "$P" && XDG_STATE_HOME="$T_DIR/afile" TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" working </dev/null 2>&1); rc=$?
assert_eq "an unwritable state directory exits 0" 0 "$rc"; assert_eq "silently" "" "$out"
out=$(cd "$P" && TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" </dev/null 2>&1); rc=$?
assert_eq "no argument exits 0" 0 "$rc"; assert_eq "silently" "" "$out"

echo "without XDG_STATE_HOME the state lives under ~/.local/state"
rm -rf "$XDG_STATE_HOME"
(cd "$P" && printf '' | env -u XDG_STATE_HOME TMUX_PANE=%7 PATH="$T_DIR/bin:$PATH" sh "$STATE" idle)
assert "the default directory is used" test -s "$HOME/.local/state/cli-workbench/sessions/%7.json"
t_done
