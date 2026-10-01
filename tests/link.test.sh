#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
LINK() { HOME=$T_HOME "$T_REPO/scripts/link" "$@"; }
backup_dir() { ls -d "$T_HOME"/.cli-workbench-backup/*/ 2>/dev/null | head -1 | sed 's#/$##'; }

echo "dry-run is the default"
t_fixture
LINK >/dev/null
refute "creates no link" test -L "$T_HOME/.alpha"
refute "creates no backup dir" test -e "$T_HOME/.cli-workbench-backup"
t_cleanup

echo "apply creates links and is idempotent"
t_fixture
LINK --apply >/dev/null
assert_eq "alpha points at repo source" "$T_REPO/config/a/file" "$(readlink "$T_HOME/.alpha")"
assert "beta linked (parent dir created)" test -L "$T_HOME/.config/beta"
before=$(ls -l "$T_HOME/.alpha")
LINK --apply >/dev/null
assert_eq "second run changes nothing" "$before" "$(ls -l "$T_HOME/.alpha")"
refute "second run makes no backup" test -e "$T_HOME/.cli-workbench-backup"
t_cleanup

echo "regular file is backed up, then linked"
t_fixture
printf 'mine\n' > "$T_HOME/.alpha"
LINK alpha --apply >/dev/null
bk=$(backup_dir)
assert_eq "backup keeps content" "mine" "$(cat "$bk$T_HOME/.alpha")"
assert "RESTORE written" test -s "$bk/RESTORE"
assert "target is now a link" test -L "$T_HOME/.alpha"
t_cleanup

echo "real directory: STOP unless --adopt <component>"
t_fixture
mkdir -p "$T_HOME/.config/beta"; printf 'local\n' > "$T_HOME/.config/beta/only-here"
LINK beta >/dev/null; rc=$?
assert_eq "dry-run exits 1" 1 "$rc"
LINK beta --apply >/dev/null; rc=$?
assert_eq "apply without --adopt exits 1" 1 "$rc"
refute "directory not replaced" test -L "$T_HOME/.config/beta"
assert "local file still there" test -f "$T_HOME/.config/beta/only-here"
out=$(LINK beta 2>&1)
assert_contains "inventory lists files only in target" "only-here" "$out"
LINK beta --apply --adopt >/dev/null; rc=$?
assert_eq "adopt exits 0" 0 "$rc"
bk=$(backup_dir)
assert "adopted dir preserved in backup" test -f "$bk$T_HOME/.config/beta/only-here"
assert "now linked" test -L "$T_HOME/.config/beta"
t_cleanup

echo "symlink pointing elsewhere: STOP; adopt backs up the link object"
t_fixture
mkdir -p "$T_DIR/elsewhere"; ln -s "$T_DIR/elsewhere" "$T_HOME/.alpha"
LINK alpha --apply >/dev/null; rc=$?
assert_eq "STOP exits 1" 1 "$rc"
assert_eq "still points elsewhere" "$T_DIR/elsewhere" "$(readlink "$T_HOME/.alpha")"
LINK alpha --apply --adopt >/dev/null
bk=$(backup_dir)
assert "backup holds the symlink object" test -L "$bk$T_HOME/.alpha"
assert_eq "relinked to repo" "$T_REPO/config/a/file" "$(readlink "$T_HOME/.alpha")"
t_cleanup

echo "dangling symlink is treated like a foreign link (review focus 2)"
t_fixture
ln -s "$T_DIR/nowhere" "$T_HOME/.alpha"
LINK alpha --apply >/dev/null; rc=$?
assert_eq "STOP exits 1" 1 "$rc"
assert_eq "dangling link untouched" "$T_DIR/nowhere" "$(readlink "$T_HOME/.alpha")"
t_cleanup

echo "component selector"
t_fixture
LINK alpha --apply >/dev/null
assert "alpha linked" test -L "$T_HOME/.alpha"
refute "beta untouched" test -e "$T_HOME/.config/beta"
LINK nosuch >/dev/null 2>&1; rc=$?
assert_eq "unknown component exits 2" 2 "$rc"
LINK --adopt >/dev/null 2>&1; rc=$?
assert_eq "--adopt without component exits 2" 2 "$rc"
t_cleanup

echo "backup dir collisions get a suffix (review focus 5)"
t_fixture
mkdir -p "$T_HOME/.cli-workbench-backup/T1"
printf 'mine\n' > "$T_HOME/.alpha"
WB_TIMESTAMP=T1 LINK alpha --apply >/dev/null
assert "suffixed dir used" test -f "$T_HOME/.cli-workbench-backup/T1-1$T_HOME/.alpha"
assert_eq "existing dir untouched" "" "$(ls -A "$T_HOME/.cli-workbench-backup/T1")"
t_cleanup

echo "missing source is an error"
t_fixture
rm "$T_REPO/config/a/file"
LINK alpha --apply >/dev/null; rc=$?
assert_eq "exits 1" 1 "$rc"
refute "no link created" test -L "$T_HOME/.alpha"
t_cleanup

echo "malformed manifest line aborts before any change (review focus 1)"
t_fixture
printf '%s\n' 'gamma only-two-fields' >> "$T_REPO/links.txt"
LINK --apply >/dev/null 2>&1; rc=$?
assert_eq "exits 2" 2 "$rc"
refute "nothing linked" test -L "$T_HOME/.alpha"
t_cleanup

echo "target whose parent is a file fails cleanly (review focus 4)"
t_fixture
printf 'x\n' > "$T_HOME/.config"
LINK beta --apply >/dev/null 2>&1; rc=$?
assert_eq "exits 1" 1 "$rc"
assert_eq ".config file untouched" "x" "$(cat "$T_HOME/.config")"
t_cleanup

echo "any cwd; refuses without HOME (review focus 3)"
t_fixture
( cd / && HOME=$T_HOME "$T_REPO/scripts/link" alpha --apply >/dev/null )
assert "linked when run from /" test -L "$T_HOME/.alpha"
env -u HOME "$T_REPO/scripts/link" >/dev/null 2>&1; rc=$?
assert "non-zero without HOME" test "$rc" -ne 0
t_cleanup

t_done
