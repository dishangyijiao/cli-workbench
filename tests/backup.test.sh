#!/usr/bin/env bash
# chezmoi keeps no backup of files it replaces; scripts/backup-before-apply (a hook written by `chezmoi init`) does.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v chezmoi >/dev/null; then echo "chezmoi not installed; skipped"; exit 0; fi

T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT
unset TMUX ZDOTDIR XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME
# A fresh HOME already initialised from this clone, the way the README quick start does it.
newhome() { export HOME=$T_DIR/h$1; export WB_BACKUP_DIR=$HOME/.cli-workbench-backup; mkdir -p "$HOME"; chezmoi init --source "$WB_SRC" --no-tty >/dev/null 2>&1; }
backups() { find "$WB_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort; }
latest() { backups | tail -1; }

echo "init writes the config: this clone as the source, plus the backup hook"
newhome 1
assert "sourceDir points at the clone" grep -qF "sourceDir = \"$WB_SRC\"" "$HOME/.config/chezmoi/chezmoi.toml"
assert "the apply.pre hook is configured" grep -q 'backup-before-apply' "$HOME/.config/chezmoi/chezmoi.toml"
assert "the hook script is executable" test -x "$WB_SRC/scripts/backup-before-apply"

echo "a fresh machine has nothing to back up and gets no backup directory"
chezmoi apply --no-tty >/dev/null 2>&1; assert_eq "apply exits 0" 0 $?
assert_eq "no backup directory" "" "$(backups)"
chezmoi apply --no-tty >/dev/null 2>&1
assert_eq "applying again (nothing changes) still creates none" "" "$(backups)"

echo "replaced files are backed up first, with their paths, modes and a RESTORE note"
newhome 2
echo '# my old zshrc' > "$HOME/.zshrc"; chmod 600 "$HOME/.zshrc"
mkdir -p "$HOME/.config/ghostty"; echo 'font-size = 14' > "$HOME/.config/ghostty/config"
err=$(chezmoi apply --no-tty 2>&1 >/dev/null); assert_eq "apply exits 0" 0 $?
B=$(latest)
assert_contains "it says where the backup is" "backed up 2 file(s)" "$err"
assert_eq "one backup directory" 1 "$(backups | wc -l | tr -d ' ')"
assert_eq ".zshrc backed up" "# my old zshrc" "$(cat "$B/.zshrc" 2>/dev/null)"
assert_eq "ghostty config backed up under its own path" "font-size = 14" "$(cat "$B/.config/ghostty/config" 2>/dev/null)"
assert_eq "file mode kept" 600 "$(stat -c %a "$B/.zshrc" 2>/dev/null || stat -f %Lp "$B/.zshrc")"
assert_eq "backup directory is private (700)" 700 "$(stat -c %a "$B" 2>/dev/null || stat -f %Lp "$B")"
assert "RESTORE note exists" test -s "$B/RESTORE"
assert "the new .zshrc is the repository's" grep -q 'cli-workbench zshrc' "$HOME/.zshrc"

echo "the RESTORE command really restores"
bash -c "$(grep -F "$HOME/.zshrc" "$B/RESTORE")" >/dev/null 2>&1
assert_eq ".zshrc is back" "# my old zshrc" "$(cat "$HOME/.zshrc")"

echo "a file you edited after chezmoi wrote it is backed up too"
chezmoi apply --force --no-tty >/dev/null 2>&1
echo '# local tweak' >> "$HOME/.tmux.conf"
chezmoi apply --force --no-tty >/dev/null 2>&1
assert_contains "the edit is in the newest backup" "local tweak" "$(cat "$(latest)/.tmux.conf" 2>/dev/null)"

echo "applying ONE file backs that file up (the quick start applies one first)"
newhome 3
echo '# mine' > "$HOME/.tmux.conf"
chezmoi apply --no-tty "$HOME/.tmux.conf" >/dev/null 2>&1; assert_eq "exit 0" 0 $?
assert_eq "tmux.conf backed up" "# mine" "$(cat "$(latest)/.tmux.conf" 2>/dev/null)"

echo "a symlink in the way is kept as a symlink"
newhome 4
ln -s /nonexistent/target "$HOME/.zshrc"
chezmoi apply --no-tty >/dev/null 2>&1; assert_eq "exit 0" 0 $?
assert "the backup holds a symlink" test -L "$(latest)/.zshrc"
assert_eq "pointing where it did" /nonexistent/target "$(readlink "$(latest)/.zshrc")"

echo "a directory replaced by a file is kept whole; a directory that stays a directory is not noise"
newhome 5
mkdir -p "$HOME/.zshrc"; echo inner > "$HOME/.zshrc/file"
mkdir -p "$HOME/.config/zsh"; chmod 755 "$HOME/.config/zsh"      # only its mode differs from the source (700)
chezmoi apply --force --no-tty >/dev/null 2>&1
assert_eq "directory content backed up" inner "$(cat "$(latest)/.zshrc/file" 2>/dev/null)"
assert "the mode-only directory is not copied" test ! -e "$(latest)/.config/zsh"

echo "--dry-run has no side effects"
newhome 6
echo '# mine' > "$HOME/.zshrc"
chezmoi apply --dry-run --no-tty >/dev/null 2>&1; assert_eq "exit 0" 0 $?
assert_eq "no backup directory" "" "$(backups)"
assert_eq ".zshrc untouched" "# mine" "$(cat "$HOME/.zshrc")"

echo "no backup, no overwrite: if the backup cannot be made the apply is refused"
newhome 7
echo '# mine' > "$HOME/.zshrc"
echo 'a file, not a directory' > "$T_DIR/blocker"
WB_BACKUP_DIR=$T_DIR/blocker/sub chezmoi apply --no-tty >/dev/null 2>"$T_DIR/err"; rc=$?
assert "apply fails" test "$rc" -ne 0
assert_eq ".zshrc untouched" "# mine" "$(cat "$HOME/.zshrc")"
assert_contains "it says why" "refusing to apply without a backup" "$(cat "$T_DIR/err")"

t_done
