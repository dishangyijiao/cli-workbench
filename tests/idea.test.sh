#!/usr/bin/env bash
# prefix+a (and `idea` in a shell) appends one idea as one line to ~/.config/cli-workbench/inbox.md. The script runs
# against a stub of tmux, in a throwaway HOME.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v git >/dev/null; then echo "git not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT
IDEA=$WB_SRC/home/dot_tmux/scripts/executable_idea.sh
export HOME=$T_DIR/home; mkdir -p "$HOME"
INBOX=$HOME/.config/cli-workbench/inbox.md

# tmux stub: display-message answers with $STUB_DIR; STUB_FAIL=1 makes it fail like a pane that is gone.
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/bin/tmux" <<'SH'
#!/bin/sh
[ "${STUB_FAIL:-}" = 1 ] && exit 1
[ "$1" = display-message ] && printf '%s\n' "$STUB_DIR"
SH
chmod +x "$T_DIR/bin/tmux"
# popup DIR INPUT: as prefix+a would run it, typing INPUT. shell DIR ARGS...: as `idea ARGS...` in DIR.
popup() { (cd "$HOME" && printf '%s' "$2" | STUB_DIR=$1 PATH="$T_DIR/bin:$PATH" sh "$IDEA" --pane %7 2>&1); }
shell() { local d=$1; shift; (cd "$d" && PATH="$T_DIR/bin:$PATH" sh "$IDEA" -- "$@" 2>&1 </dev/null); }
last() { tail -n 1 "$INBOX" 2>/dev/null; }
lines() { if [ -f "$INBOX" ]; then wc -l < "$INBOX" | tr -d ' '; else echo 0; fi; }
g() { git -C "$1" -c user.name=t -c user.email=t@example.invalid "${@:2}" >/dev/null 2>&1; }

P=$HOME/dev/projects/proj; mkdir -p "$P/sub"; g "$P" init -q; g "$P" commit -q --allow-empty -m one
LINE='^- \[ \] [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} · '

echo "a popup capture is one line: open box, date and time, project, text"
popup "$P/sub" "first idea" >/dev/null
assert_eq "one line written" 1 "$(lines)"
assert "it has the open box and a timestamp" grep -Eq "${LINE}~/dev/projects/proj · first idea\$" "$INBOX"
assert_eq "no heading or anything else in the file" 1 "$(grep -c . "$INBOX")"

echo "the inbox is private"
assert_eq "mode 600" 600 "$(stat -c %a "$INBOX" 2>/dev/null || stat -f %Lp "$INBOX")"

echo "the text is kept exactly, and never runs"
popup "$P" "  spaced  " >/dev/null
assert "leading and trailing spaces are kept" grep -Eq " · ~/dev/projects/proj ·   spaced  \$" "$INBOX"
EVIL_TEXT='$(touch "$HOME/pwned") `touch "$HOME/pwned2"` '"'q'"' "dq" %s %% \n back\slash'
popup "$P" "$EVIL_TEXT" >/dev/null
refute "a command substitution in the text did not run" test -e "$HOME/pwned"
refute "nor a backtick" test -e "$HOME/pwned2"
assert_eq "the text is stored verbatim" "$EVIL_TEXT" "$(last | sed 's/^.* · ~\/dev\/projects\/proj · //')"

echo "nothing typed means nothing written"
n=$(lines)
popup "$P" "" >/dev/null;    assert_eq "an empty line writes nothing" "$n" "$(lines)"
popup "$P" "   " >/dev/null; assert_eq "a blank line writes nothing" "$n" "$(lines)"
out=$(cd "$HOME" && STUB_DIR=$P PATH="$T_DIR/bin:$PATH" sh "$IDEA" --pane %7 </dev/null 2>&1); rc=$?
assert_eq "end of input (Ctrl-D) cancels quietly" 0 "$rc"; assert_eq "and writes nothing" "$n" "$(lines)"

echo "the shell form takes the text as arguments and the current directory as the project"
mkdir -p "$HOME/notes"
shell "$HOME/notes" fix the "README diagram" >/dev/null
assert "arguments become the text, joined by spaces" grep -Eq "${LINE}~/notes · fix the README diagram\$" "$INBOX"
shell "$P" "two
lines" >/dev/null
assert "a newline in the text becomes a space: one idea, one line" grep -Eq " · two lines\$" "$INBOX"

echo "the project is the repository's full path, so same-named repos stay apart"
Q=$HOME/work/proj; mkdir -p "$Q"; g "$Q" init -q; g "$Q" commit -q --allow-empty -m one
popup "$Q" "other proj" >/dev/null
assert "a repo with the same name elsewhere keeps its own path" grep -Eq "· ~/work/proj · other proj\$" "$INBOX"
g "$P" worktree add -q "$HOME/wt/feature-x" -b feature-x
popup "$HOME/wt/feature-x" "from a worktree" >/dev/null
assert "a worktree is filed under the repository it belongs to" grep -Eq "· ~/dev/projects/proj · from a worktree\$" "$INBOX"
D=$T_DIR/outside; mkdir -p "$D"
popup "$D" "outside home" >/dev/null
assert "a path outside HOME is written in full" grep -Fq "· $D · outside home" "$INBOX"

echo "a directory named like a command substitution is just a name"
EVIL=$HOME/'$(cd;touch wbmarker)'; mkdir -p "$EVIL"
popup "$EVIL" "evil dir" >/dev/null
refute "nothing ran" test -e "$HOME/wbmarker"
assert "the name is recorded as it is" grep -Fq '· ~/$(cd;touch wbmarker) · evil dir' "$INBOX"

echo "a pane that is gone still keeps the idea"
out=$(cd "$HOME" && printf 'orphan idea' | STUB_FAIL=1 PATH="$T_DIR/bin:$PATH" sh "$IDEA" --pane %99 2>&1)
assert "the idea is saved with an unknown project" grep -Eq "${LINE}\? · orphan idea\$" "$INBOX"

echo "a failed write says so, shows the idea, and fails"
H2=$T_DIR/home2; mkdir -p "$H2/.config"; : > "$H2/.config/cli-workbench"     # a file where the directory should be
out=$(cd "$H2" && printf 'lost?' | HOME=$H2 STUB_DIR=$H2 PATH="$T_DIR/bin:$PATH" sh "$IDEA" --pane %7 2>&1); rc=$?
assert_eq "exit status 1" 1 "$rc"
assert_contains "the message names the inbox" "inbox.md" "$out"
assert_contains "and repeats the idea so it is not lost" "lost?" "$out"

echo "ideas appended at the same moment are all kept, whole"
n=$(lines)
for i in $(seq 1 40); do shell "$P" "parallel idea number $i with some padding text to make the line longer" >/dev/null & done; wait
assert_eq "40 more lines" $((n + 40)) "$(lines)"
assert_eq "every one intact" 40 "$(grep -Ec "${LINE}~/dev/projects/proj · parallel idea number [0-9]+ with some padding text to make the line longer\$" "$INBOX")"

echo "an unknown option is refused"
out=$(cd "$HOME" && sh "$IDEA" --bogus 2>&1 </dev/null); rc=$?
assert_eq "usage error" 2 "$rc"

echo "tmux binds prefix+a to the popup with only the pane id; the shell has an idea command"
if command -v tmux >/dev/null && command -v chezmoi >/dev/null; then
  R=$T_DIR/render; mkdir -p "$R"; t_render "$R"
  line=$(grep -E 'bind a display-popup' "$R/.tmux.conf")
  assert_contains "prefix+a opens the idea popup" "idea.sh --pane #{pane_id}" "$line"
  refute "no directory is passed into the shell" grep -q 'pane_current_path' <<<"$line"
  assert "the script is deployed executable" test -x "$R/.tmux/scripts/idea.sh"
else
  echo "  skip  tmux or chezmoi not installed"
fi
assert "zshrc defines idea without globbing" grep -Eq "^alias idea='noglob ~/.tmux/scripts/idea.sh --'" "$WB_SRC/home/dot_zshrc"
t_done
