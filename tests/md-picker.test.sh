#!/usr/bin/env bash
# prefix+M lists the Markdown files that the Claude Code conversation in the current pane mentioned, and opens the one
# you pick in Neovim, read-only. The script runs against a made-up state file and transcript, with stand-ins for tmux,
# fzf and nvim, in a throwaway HOME.
# shellcheck disable=SC2088  # the expected lists hold a literal "~", as the picker shows it
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
command -v jq >/dev/null || { echo "jq not installed; skipped"; exit 0; }
T_DIR=$(cd -P "$(mktemp -d "${TMPDIR:-/tmp}/wb-md.XXXXXX")" && pwd)
trap t_cleanup EXIT
PICK=$WB_SRC/home/dot_tmux/scripts/executable_md-picker.sh
export HOME=$T_DIR/home XDG_STATE_HOME=$T_DIR/state
unset CLAUDE_CONFIG_DIR
SRV=100-1700000000
STATEF=$XDG_STATE_HOME/cli-workbench/sessions/$SRV/%7.json
SID=abc-123
TR=$HOME/.claude/projects/-some-project/$SID.jsonl
P=$HOME/proj
mkdir -p "$(dirname "$STATEF")" "$(dirname "$TR")" "$P/docs" "$P/notes" "$P/sub" "$P/dir.md" "$HOME/reports"

# Stand-ins: tmux answers display-message with the server; fzf logs its arguments and picks the first line; nvim logs its
# arguments.
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/bin/tmux" <<'SH'
#!/bin/sh
[ "$1" = display-message ] && printf '%s\n' "$FAKE_SERVER"
exit 0
SH
cat > "$T_DIR/bin/fzf" <<'SH'
#!/bin/sh
for a in "$@"; do printf '%s\n' "$a"; done > "$FZF_LOG"
head -n 1
SH
cat > "$T_DIR/bin/nvim" <<'SH'
#!/bin/sh
for a in "$@"; do printf 'arg=%s\n' "$a"; done
SH
chmod +x "$T_DIR/bin/tmux" "$T_DIR/bin/fzf" "$T_DIR/bin/nvim"
export FAKE_SERVER=$SRV FZF_LOG=$T_DIR/fzf.log

list() { (cd "$T_DIR" && PATH="$T_DIR/bin:$PATH" sh "$PICK" --list %7 2>&1); }
pick() { (cd "$T_DIR" && printf '%s\n' "${1-}" | PATH="${2:-$T_DIR/bin:$PATH}" sh "$PICK" %7 2>&1); }

# Records: rec TYPE CWD CONTENT_JSON
rec() { jq -nc --arg t "$1" --arg cwd "$2" --argjson c "$3" '{type: $t, cwd: $cwd, message: {role: $t, content: $c}}'; }
tool() { jq -nc --arg n "$1" --argjson i "$2" '[{type: "tool_use", id: "x", name: $n, input: $i}]'; }

for f in docs/plan.md notes/report.md arr.md top.md 'my notes.md' '$(touch pwned).md' thought.md docs/plan.mdx; do
  echo "# $f" > "$P/$f"
done
echo "# weekly" > "$HOME/reports/weekly.md"

{
  rec assistant "$P" "$(tool Write "{\"file_path\":\"$P/docs/plan.md\",\"content\":\"x\"}")"
  rec user "$P" '[{"type":"tool_result","tool_use_id":"x","content":"wrote notes/report.md and /nonexistent/gone.md"}]'
  rec assistant "$P" '[{"type":"text","text":"See `~/reports/weekly.md`, and docs/plan.mdx."}]'
  rec user "$P" "[{\"type\":\"tool_result\",\"tool_use_id\":\"x\",\"content\":[{\"type\":\"text\",\"text\":\"($P/arr.md)\"}]}]"
  rec assistant "$P" "[{\"type\":\"thinking\",\"thinking\":\"maybe $P/thought.md\"}]"
  echo 'not json {{{'
  jq -nc --arg c "$P/sub" --arg p "$P" '{type: "assistant", cwd: $c, message: {content: [
      {type: "tool_use", name: "Bash", input: {command: "cat ../top.md | head; ls dir.md ../dir.md"}},
      {type: "tool_use", name: "Read", input: {file_path: ($p + "/my notes.md")}},
      {type: "tool_use", name: "Edit", input: {file_path: ($p + "/$(touch pwned).md")}}]}}'
  rec assistant "$P" "$(tool Read '{"file_path":"./notes/report.md"}')"
  jq -nc --arg p "$P" '{type: "summary", summary: ($p + "/docs/plan.mdx " + $p + "/arr.md")}'
} > "$TR"
jq -nc --arg s "$SID" '{state: "idle", project: "proj", branch: "main", since: 1, session_id: $s}' > "$STATEF"

echo "the list: the Markdown files the conversation mentioned, most recent first, each once"
out=$(list)
expected='~/proj/notes/report.md
~/proj/$(touch pwned).md
~/proj/my notes.md
~/proj/top.md
~/proj/arr.md
~/reports/weekly.md
~/proj/docs/plan.md'
assert_eq "order, de-duplication, ~ and relative paths, missing files left out" "$expected" "$out"
refute "a name is never run as a command" test -e "$T_DIR/pwned"
refute "nor in the project" test -e "$P/pwned"

echo "the script reads only: the transcript and the state file are unchanged"
before=$(cksum "$TR" "$STATEF")
list >/dev/null
assert_eq "unchanged" "$before" "$(cksum "$TR" "$STATEF")"

echo "fzf: Enter opens the first file in Neovim, read-only"
out=$(pick)
assert_contains "nvim -R" "arg=-R" "$out"
assert_contains "with the full path" "arg=$P/notes/report.md" "$out"
assert "fzf previews the file" grep -q -- '--preview' "$FZF_LOG"
assert "fzf shows the short form" grep -q -- '--with-nth' "$FZF_LOG"

echo "Esc in fzf opens nothing"
mkdir -p "$T_DIR/esc"; printf '#!/bin/sh\ncat >/dev/null; exit 130\n' > "$T_DIR/esc/fzf"
chmod +x "$T_DIR/esc/fzf"
out=$(pick '' "$T_DIR/esc:$T_DIR/bin:$PATH"); rc=$?
assert_eq "exit 0" 0 "$rc"
refute "no nvim" grep -q '^arg=' <<<"$out"

echo "without fzf: a numbered menu"
mkdir -p "$T_DIR/nofzf"
for c in sh jq awk sed head cat tr nvim tmux; do p=$(PATH="$T_DIR/bin:$PATH" command -v "$c") && ln -sf "$p" "$T_DIR/nofzf/$c"; done
out=$(pick 3 "$T_DIR/nofzf")
assert_contains "numbered rows" " 3) ~/proj/my notes.md" "$out"
assert_contains "the chosen file opens read-only" "arg=$P/my notes.md" "$out"
out=$(pick '' "$T_DIR/nofzf")
refute "Enter cancels" grep -q '^arg=' <<<"$out"
out=$(pick 99 "$T_DIR/nofzf")
refute "a number out of range opens nothing" grep -q '^arg=' <<<"$out"

echo "the two empty cases say which one it is"
jq -nc '{state: "idle", session_id: "other-session"}' > "$STATEF"
out=$(pick)
assert_contains "no conversation for the session" "No Claude Code session" "$out"
refute "and no nvim" grep -q '^arg=' <<<"$out"
rm -f "$STATEF"
out=$(pick)
assert_contains "no state file for the pane" "No Claude Code session" "$out"
assert_eq "one line" 1 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
jq -nc --arg s "$SID" '{state: "idle", session_id: $s}' > "$STATEF"
rec user "$P" '"hello, nothing to read here"' > "$TR"
out=$(pick)
assert_contains "a conversation without Markdown files" "mentions no Markdown file" "$out"
assert_eq "one line" 1 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
assert_eq "--list prints nothing then" "" "$(list 2>/dev/null | grep -v 'mentions no Markdown')"

echo "a session id is used as a file name only when it is plain"
jq -nc '{state: "idle", session_id: "../../x"}' > "$STATEF"
rec user "$P" "\"$P/arr.md\"" > "$HOME/.claude/x.jsonl"
out=$(pick)
assert_contains "treated as no session" "No Claude Code session" "$out"

echo "CLAUDE_CONFIG_DIR moves the transcripts"
jq -nc --arg s "$SID" '{state: "idle", session_id: $s}' > "$STATEF"
mkdir -p "$T_DIR/cfg/projects/p"; rec user "$P" "\"$P/arr.md\"" > "$T_DIR/cfg/projects/p/$SID.jsonl"
out=$(CLAUDE_CONFIG_DIR=$T_DIR/cfg list)
assert_eq "read from there" '~/proj/arr.md' "$out"

echo "outside tmux, or with a bad pane id, it says so"
out=$(cd "$T_DIR" && PATH="$T_DIR/bin:$PATH" sh "$PICK" 'nope' 2>&1 </dev/null); rc=$?
assert_eq "a pane id that is not %N: exit 2" 2 "$rc"
t_done
