#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"

fixture_check() {
  t_fixture
  cp "$WB_SRC/scripts/check" "$T_REPO/scripts/" 2>/dev/null
  mkdir -p "$T_REPO/config/zsh" "$T_REPO/config/tmux/scripts" "$T_REPO/config/claude" "$T_REPO/config/nvim"
  printf 'alias x=y\n' > "$T_REPO/config/zsh/zshrc"
  printf 'true\n' > "$T_REPO/config/zsh/tmux-autostart.zsh"
  printf 'true\n' > "$T_REPO/config/zsh/path.zsh"
  printf 'true\n' > "$T_REPO/config/zsh/proxy.zsh"
  printf '#!/bin/sh\ntrue\n' > "$T_REPO/config/tmux/scripts/branch.sh"
  printf '#!/bin/sh\nexit 0\n' > "$T_REPO/config/claude/statusline.test.sh"
  printf -- '-- init\n' > "$T_REPO/config/nvim/init.lua"
}
CHECK() { HOME=$T_HOME "$T_REPO/scripts/check"; }
LINK()  { HOME=$T_HOME "$T_REPO/scripts/link" "$@"; }

echo "all links correct -> exit 0"
fixture_check
LINK --apply >/dev/null
out=$(CHECK 2>&1); rc=$?
assert_eq "exit 0" 0 "$rc"
assert_contains "reports a PASS for alpha" "PASS  link alpha" "$out"
t_cleanup

echo "unlinked target -> FAIL, exit 1"
fixture_check
out=$(CHECK 2>&1); rc=$?
assert_eq "exit 1" 1 "$rc"
assert_contains "FAIL names the component" "FAIL  link alpha" "$out"
t_cleanup

echo "link into the repo but to the wrong file -> FAIL (exact source, not 'anywhere in repo')"
fixture_check
LINK --apply >/dev/null
rm "$T_HOME/.alpha"; ln -s "$T_REPO/config/dir/x" "$T_HOME/.alpha"
out=$(CHECK 2>&1); rc=$?
assert_eq "exit 1" 1 "$rc"
assert_contains "FAIL for alpha" "FAIL  link alpha" "$out"
t_cleanup

echo "zsh syntax error -> FAIL"
if command -v zsh >/dev/null; then
  fixture_check
  LINK --apply >/dev/null
  printf 'if then\n' > "$T_REPO/config/zsh/zshrc"
  out=$(CHECK 2>&1); rc=$?
  assert_eq "exit 1" 1 "$rc"
  assert_contains "FAIL mentions zshrc" "zshrc" "$(printf '%s\n' "$out" | grep '^FAIL')"
  t_cleanup
else t_ok "zsh not installed; skipped"; fi

echo "zsh syntax error in a sibling (path.zsh) -> FAIL"
if command -v zsh >/dev/null; then
  fixture_check
  LINK --apply >/dev/null
  printf 'if then\n' > "$T_REPO/config/zsh/path.zsh"
  out=$(CHECK 2>&1); rc=$?
  assert_eq "exit 1" 1 "$rc"
  assert_contains "FAIL mentions path.zsh" "path.zsh" "$(printf '%s\n' "$out" | grep '^FAIL')"
  t_cleanup
else t_ok "zsh not installed; skipped"; fi

echo "nvim lua syntax error -> FAIL"
if command -v nvim >/dev/null; then
  fixture_check
  LINK --apply >/dev/null
  printf 'local = =\n' > "$T_REPO/config/nvim/init.lua"
  out=$(CHECK 2>&1); rc=$?
  assert_eq "exit 1" 1 "$rc"
  assert_contains "FAIL mentions nvim" "nvim" "$(printf '%s\n' "$out" | grep '^FAIL')"
  t_cleanup
else t_ok "nvim not installed; skipped"; fi

# Content-aware hash of a directory tree: names, file contents and link targets. cksum is POSIX, so this
# works on macOS and Linux (the earlier version used md5, which Linux lacks, and hashed names only).
tree_hash() {
  ( cd "$1" && {
      find . | LC_ALL=C sort
      find . -type f -exec cksum {} + | LC_ALL=C sort
      find . -type l -exec sh -c 'for l; do printf "%s -> %s\n" "$l" "$(readlink "$l")"; done' sh {} + | LC_ALL=C sort
    } | cksum )
}
EMPTY_HASH="4294967295 0"

echo "the HOME hash notices a content change, not only a renamed file"
t_fixture
printf 'a\n' > "$T_HOME/f"; h1=$(tree_hash "$T_HOME")
printf 'b\n' > "$T_HOME/f"; h2=$(tree_hash "$T_HOME")
[ "$h1" != "$h2" ]; assert_eq "hash changed" 0 $?
[ "$h1" != "$EMPTY_HASH" ]; assert_eq "hash is not the empty-input hash" 0 $?
t_cleanup

echo "check does not write to HOME"
fixture_check
LINK --apply >/dev/null
before=$(tree_hash "$T_HOME")
CHECK >/dev/null 2>&1
after=$(tree_hash "$T_HOME")
[ "$before" != "$EMPTY_HASH" ]; assert_eq "the hash tool really ran" 0 $?
assert_eq "HOME unchanged (names, contents, links)" "$before" "$after"
t_cleanup

echo "a clone whose path contains spaces is checked correctly"
fixture_check
mv "$T_REPO" "$T_DIR/my repo"; T_REPO="$T_DIR/my repo"
LINK --apply >/dev/null 2>&1
out=$(CHECK 2>&1); rc=$?
assert_eq "exit 0" 0 "$rc"
assert_contains "alpha passes" "PASS  link alpha" "$out"
t_cleanup

t_done
