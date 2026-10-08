#!/usr/bin/env bash
# One instruction text for every agent CLI: ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v chezmoi >/dev/null; then echo "chezmoi not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT
FILES=".claude/CLAUDE.md .codex/AGENTS.md .gemini/GEMINI.md"

echo "without a local file, all three agents get the same shared text"
H=$T_DIR/h1; mkdir -p "$H"; t_render "$H"
for f in $FILES; do assert "$f is deployed" test -s "$H/$f"; done
assert "Codex's file equals Claude's" cmp -s "$H/.claude/CLAUDE.md" "$H/.codex/AGENTS.md"
assert "Gemini's file equals Claude's" cmp -s "$H/.claude/CLAUDE.md" "$H/.gemini/GEMINI.md"
assert_contains "it explains the workbench" "Terminal workbench" "$(cat "$H/.claude/CLAUDE.md")"
assert_contains "it says how to work across projects" "Working across projects" "$(cat "$H/.claude/CLAUDE.md")"
last2=$(tail -c 2 "$H/.claude/CLAUDE.md" | od -An -tx1 | tr -d ' \n')
assert_eq "it ends with a newline" 0a "${last2#??}"
refute "and no blank line after it" test "$last2" = 0a0a

echo "a local file is appended to all three; nothing personal is in the repository"
H=$T_DIR/h2; mkdir -p "$H/.config/cli-workbench"
printf '# My rules\n\n- be terse\n\n\n' > "$H/.config/cli-workbench/agent-instructions.local.md"
t_render "$H"
for f in $FILES; do
  assert_contains "$f has the shared text first" "Terminal workbench" "$(head -1 "$H/$f")"
  assert_contains "$f has the local rules" "- be terse" "$(cat "$H/$f")"
done
assert_eq "trailing blank lines of the local file are trimmed" "- be terse" "$(tail -1 "$H/.claude/CLAUDE.md")"
refute "the repository itself does not contain the local text" grep -rq "be terse" "$WB_SRC/home"

echo "removing the local file removes its text on the next apply"
rm "$H/.config/cli-workbench/agent-instructions.local.md"; t_render "$H"
refute "local rules are gone" grep -q "be terse" "$H/.claude/CLAUDE.md"

echo "an existing instruction file is backed up before it is replaced"
H=$T_DIR/h3; mkdir -p "$H/.claude"; echo "# my own CLAUDE.md" > "$H/.claude/CLAUDE.md"
HOME=$H chezmoi init --source "$WB_SRC" --no-tty >/dev/null 2>&1
HOME=$H WB_BACKUP_DIR=$H/bk chezmoi apply --no-tty >/dev/null 2>&1
assert_contains "the original is in the backup" "my own CLAUDE.md" "$(cat "$H"/bk/*/.claude/CLAUDE.md 2>/dev/null)"
t_done
