#!/usr/bin/env bash
# End-to-end test: what a first-time user does, in a throwaway HOME. Follows the README quick start.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v zsh >/dev/null; then echo "zsh not installed; skipped"; exit 0; fi

T_DIR=$(cd -P "$(mktemp -d)" && pwd)
export HOME=$T_DIR/home; mkdir -p "$HOME"
unset TMUX ZDOTDIR XDG_CONFIG_HOME XDG_CACHE_HOME
SOCK=smoke$$
cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null; case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac; }
trap cleanup EXIT

# the user's own files, which must survive
echo '# my old zshrc' > "$HOME/.zshrc"
mkdir -p "$HOME/.config/ghostty"; echo 'font-size = 14' > "$HOME/.config/ghostty/config"
# a clone: the working tree without .git
mkdir "$T_DIR/wb"; (cd "$WB_SRC" && tar --exclude=.git -cf - .) | (cd "$T_DIR/wb" && tar xf -)
cd "$T_DIR/wb" || exit 1
git init -q && git add -A && git -c user.name=smoke -c user.email=smoke@example.invalid commit -q -m "clone"
links() { find "$HOME" -type l 2>/dev/null | wc -l | tr -d ' '; }
components=$(awk '!/^#/ && NF {print $1}' links.txt)

echo "bootstrap and the link dry-run are read-only"
out=$(scripts/bootstrap 2>&1); assert_eq "bootstrap exits 0" 0 $?
assert_contains "bootstrap explains that FAIL lines are expected on a first run" "only mean nothing is linked yet" "$out"
scripts/link >/dev/null 2>&1;      assert_eq "link dry-run exits 0" 0 $?
assert_eq "no links created" 0 "$(links)"
assert_eq "existing .zshrc untouched" "# my old zshrc" "$(cat "$HOME/.zshrc")"

echo "the README quick start: apply ONE component, then check just that one"
scripts/link tmux --apply >/dev/null 2>&1; assert_eq "apply tmux" 0 $?
out=$(scripts/check tmux 2>&1); assert_eq "check tmux passes although the other components are not linked yet" 0 $?
assert_contains "it reports the tmux link" "PASS  link tmux" "$out"

echo "every component applies"
for c in $components; do scripts/link "$c" --apply >/dev/null 2>&1; assert_eq "apply $c" 0 $?; done
for c in $components; do
  tgt=$(awk -v c="$c" '$1==c {print $3}' links.txt); tgt=${tgt/#\~/$HOME}
  [ -L "$tgt" ] && [ -e "$tgt" ]; assert_eq "$c is a working symlink" 0 $?
done

echo "the user's own files were backed up, not lost"
assert "old .zshrc is in a backup" test -n "$(grep -rl 'my old zshrc' "$HOME/.cli-workbench-backup" 2>/dev/null | head -1)"
assert "old ghostty config is in a backup" test -n "$(grep -rl 'font-size = 14' "$HOME/.cli-workbench-backup" 2>/dev/null | head -1)"
assert "a RESTORE note exists" test -n "$(find "$HOME/.cli-workbench-backup" -name RESTORE | head -1)"

echo "applying again is a no-op"
out=$(scripts/link zsh --apply 2>&1); assert_eq "exit 0" 0 $?
assert_contains "reports ok" "[ok]" "$out"

echo "check and doctor pass"
scripts/check >/dev/null 2>&1;  assert_eq "check exits 0" 0 $?
out=$(scripts/doctor 2>&1); assert_eq "doctor exits 0 (no FAIL)" 0 $?
assert_contains "doctor sees a clean git clone" "PASS  repo has no uncommitted changes" "$out"

echo "a fresh interactive zsh starts cleanly"
zsh -i -c 'echo shell-ok' >"$T_DIR/zsh.out" 2>"$T_DIR/zsh.err" </dev/null
assert_eq "it runs" "shell-ok" "$(cat "$T_DIR/zsh.out")"
zsh_errs=$(grep -v -E "can.t change option: zle" "$T_DIR/zsh.err")
assert_eq "nothing on stderr" "" "$zsh_errs"   # shows the text if it fails
if [ -n "$zsh_errs" ]; then   # what compinit's security audit objects to, to make the CI log self-explanatory
  echo "  diag: compaudit:"; zsh -i -c 'compaudit' </dev/null 2>&1 | head -6 | sed 's/^/    /'
  echo "  diag: fpath: $(zsh -i -c 'print -r -- $fpath' </dev/null 2>&1 | head -2)"
fi
assert "completion cache is in the XDG cache dir" test -f "$HOME/.cache/zsh/zcompdump"
assert_eq "no duplicate PATH entries" 0 "$(zsh -i -c 'print -l $path | sort | uniq -d | wc -l' 2>/dev/null </dev/null | tr -d ' ')"

if command -v tmux >/dev/null; then
  echo "the tmux config loads without errors, even without tpm"
  tmux -L "$SOCK" -f "$HOME/.tmux.conf" new-session -d -s t 2>"$T_DIR/tmux.err"; assert_eq "tmux starts" 0 $?
  assert_eq "no config errors" 0 "$(tmux -L "$SOCK" show-messages 2>&1 | grep -c -i -E 'error|unknown|invalid')"
  assert_eq "prefix is C-a" "C-a" "$(tmux -L "$SOCK" show-options -gv prefix)"
else echo "tmux not installed; tmux part skipped"; fi

t_done
