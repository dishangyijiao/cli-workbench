#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
V="$WB_SRC/config/tmux/scripts/tmux-version-ge.sh"
ge() { TMUX_VERSION_CMD="echo tmux $1" "$V" "$2" "$3" >/dev/null 2>&1; echo $?; }

echo "tmux-version-ge.sh MAJOR MINOR: exit 0 when the running tmux is at least that version"
assert_eq "3.5a >= 3.2"      0 "$(ge 3.5a 3 2)"
assert_eq "3.2 >= 3.2"       0 "$(ge 3.2 3 2)"
assert_eq "3.1c < 3.2"       1 "$(ge 3.1c 3 2)"
assert_eq "2.9a < 3.2"       1 "$(ge 2.9a 3 2)"
assert_eq "4.0 >= 3.2"       0 "$(ge 4.0 3 2)"
assert_eq "3.10 >= 3.2 (numeric, not decimal)" 0 "$(ge 3.10 3 2)"
assert_eq "next-3.6 >= 3.2"  0 "$(ge next-3.6 3 2)"
assert_eq "next-3.1 < 3.2"   1 "$(ge next-3.1 3 2)"
assert_eq "a build from master (no number) is treated as new" 0 "$(ge master 3 2)"
"$V" >/dev/null 2>&1; assert_eq "missing arguments -> exit 2" 2 $?
t_done
