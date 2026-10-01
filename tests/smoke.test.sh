#!/usr/bin/env bash
# End-to-end test: what a first-time user does, in a throwaway HOME. Follows the README quick start.
if ! command -v chezmoi >/dev/null; then echo "chezmoi not installed; skipped"; exit 0; fi
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

# the user's own files, which chezmoi must not silently lose
echo '# my old zshrc' > "$HOME/.zshrc"
mkdir -p "$HOME/.config/ghostty"; echo 'font-size = 14' > "$HOME/.config/ghostty/config"
export WB_BACKUP_DIR=$HOME/.cli-workbench-backup
CZ=(chezmoi --no-tty)

echo "the README quick start: init points chezmoi at this clone"
chezmoi init --source "$WB_SRC" --no-tty >/dev/null 2>&1; assert_eq "chezmoi init exits 0" 0 $?

echo "look first (diff), then apply"
out=$("${CZ[@]}" diff 2>&1); assert_eq "chezmoi diff exits 0" 0 $?
assert_eq "diff changed nothing" "# my old zshrc" "$(cat "$HOME/.zshrc")"
"${CZ[@]}" apply --dry-run >/dev/null 2>&1; assert_eq "apply --dry-run exits 0" 0 $?
assert_eq "dry-run changed nothing" "# my old zshrc" "$(cat "$HOME/.zshrc")"

echo "apply deploys every file"
"${CZ[@]}" apply >/dev/null 2>&1; assert_eq "apply exits 0" 0 $?
for f in .zshrc .tmux.conf .config/zsh/path.zsh .config/zsh/tmux-autostart.zsh .config/ghostty/config .config/git/config .config/nvim/init.lua .claude/statusline.sh .claude/CLAUDE.md .codex/AGENTS.md .gemini/GEMINI.md .tmux/scripts/workspace-switch.sh; do
  assert "$f is deployed" test -f "$HOME/$f"
done
for f in .claude/statusline.sh .tmux/scripts/workspace-switch.sh .tmux/scripts/tmux-version-ge.sh .tmux/scripts/branch.sh; do
  assert "$f is executable" test -x "$HOME/$f"
done

echo "the user's own files were backed up, not lost"
assert "old .zshrc is in a backup" test -n "$(grep -rl 'my old zshrc' "$WB_BACKUP_DIR" 2>/dev/null | head -1)"
assert "old ghostty config is in a backup" test -n "$(grep -rl 'font-size = 14' "$WB_BACKUP_DIR" 2>/dev/null | head -1)"
assert "a RESTORE note exists" test -n "$(find "$WB_BACKUP_DIR" -name RESTORE | head -1)"

echo "applying again is a no-op"
"${CZ[@]}" apply >/dev/null 2>&1; assert_eq "exit 0" 0 $?
assert_eq "nothing left to change" "" "$("${CZ[@]}" status 2>&1)"
"${CZ[@]}" verify >/dev/null 2>&1; assert_eq "chezmoi verify passes" 0 $?

echo "a fresh interactive zsh starts cleanly"
# Debian/Ubuntu's /etc/zsh/zshrc runs its own compinit first; on CI images /usr/share/zsh is too permissive and it complains.
# That is the system's doing, not this config's, so skip it here (the zshrc runs its own compinit).
export skip_global_compinit=1
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
