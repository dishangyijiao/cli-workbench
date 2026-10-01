#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v zsh >/dev/null; then echo "zsh not installed; skipped"; exit 0; fi
SNAP="$WB_SRC/scripts/zsh-snapshot"
T_DIR=$(cd -P "$(mktemp -d)" && pwd)

echo "siblings are found when zshrc is reached through a symlink"
mkdir -p "$T_DIR/repo/config/zsh"
cp "$WB_SRC/config/zsh/zshrc" "$WB_SRC/config/zsh/path.zsh" "$T_DIR/repo/config/zsh/"
ln -s "$T_DIR/repo/config/zsh/zshrc" "$T_DIR/zshrc-link"
out=$("$SNAP" "$T_DIR/zshrc-link" 2>&1)
case $out in *"FAILED to load"*) t_fail "siblings not found through the symlink";; *) t_ok "siblings found through the symlink";; esac

echo "a copied lone zshrc (no siblings) fails loudly"
mkdir -p "$T_DIR/lone"; cp "$WB_SRC/config/zsh/zshrc" "$T_DIR/lone/zshrc"
out=$("$SNAP" "$T_DIR/lone/zshrc" 2>&1)
assert_contains "loud message for path.zsh" "FAILED to load" "$out"

case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac
t_done
