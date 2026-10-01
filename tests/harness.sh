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

# Render the chezmoi source tree into a throwaway HOME ($1), the way `chezmoi apply` would on a real machine.
t_render() { HOME="$1" chezmoi apply --source "$WB_SRC" --destination "$1" --no-tty --cache "$1/.chezmoi-cache" --persistent-state "$1/.chezmoi-state" >/dev/null 2>&1; }
t_cleanup() { case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac; }
