#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v zsh >/dev/null; then echo "zsh not installed; skipped"; exit 0; fi
H=$(cd -P "$(mktemp -d)" && pwd)
show() { HOME="$H" zsh -f -c "source '$WB_SRC/config/zsh/zshrc' >/dev/null 2>&1; alias $1" 2>/dev/null; }

echo "ls and grep are colored out of the box"
case $(show ls) in *"--color=auto"*|*"-G"*) t_ok "ls alias picks a color flag this platform accepts";; *) t_fail "ls has no color flag: $(show ls)";; esac
assert_contains "grep colors matches" "--color=auto" "$(show grep)"
assert "the ls alias runs on this platform" env HOME="$H" zsh -f -c "source '$WB_SRC/config/zsh/zshrc' >/dev/null 2>&1; eval 'ls /' >/dev/null"

case $H in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$H";; esac
t_done
