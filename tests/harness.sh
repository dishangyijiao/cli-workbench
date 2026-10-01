#!/usr/bin/env bash
# Minimal test helpers. Source from *.test.sh after setting WB_SRC (repo root).
T_FAILS=0; T_RUNS=0
t_ok()   { T_RUNS=$((T_RUNS+1)); printf '  ok   %s\n' "$1"; }
t_fail() { T_RUNS=$((T_RUNS+1)); T_FAILS=$((T_FAILS+1)); printf '  FAIL %s\n' "$1"; }
assert() { local d=$1; shift; if "$@" >/dev/null 2>&1; then t_ok "$d"; else t_fail "$d"; fi; }
refute() { local d=$1; shift; if "$@" >/dev/null 2>&1; then t_fail "$d"; else t_ok "$d"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then t_ok "$1"; else t_fail "$1 (expected '$2', got '$3')"; fi; }
assert_contains() { case $3 in *"$2"*) t_ok "$1";; *) t_fail "$1 (missing '$2')";; esac; }
t_done() { printf '%s: %d run, %d failed\n' "$(basename "$0")" "$T_RUNS" "$T_FAILS"; [ "$T_FAILS" -eq 0 ]; }

# Fresh fixture repo and HOME under a temp dir (physical paths). Sets T_DIR, T_REPO, T_HOME.
t_fixture() {
  T_DIR=$(cd -P "$(mktemp -d)" && pwd)
  T_REPO=$T_DIR/repo; T_HOME=$T_DIR/home
  mkdir -p "$T_REPO/scripts" "$T_REPO/config/a" "$T_REPO/config/dir" "$T_HOME"
  cp "$WB_SRC/scripts/lib.sh" "$T_REPO/scripts/" 2>/dev/null
  [ -f "$WB_SRC/scripts/link" ] && cp "$WB_SRC/scripts/link" "$T_REPO/scripts/"
  printf 'from-repo\n' > "$T_REPO/config/a/file"
  printf 'from-repo\n' > "$T_REPO/config/dir/x"
  printf '%s\n' '# comment' 'alpha config/a/file ~/.alpha' 'beta config/dir ~/.config/beta' > "$T_REPO/links.txt"
}
t_cleanup() { case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac; }
