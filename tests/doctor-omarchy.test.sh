#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
doctor="$WB_SRC/scripts/doctor-omarchy"
echo "Omarchy doctor reports environment without modifying it"
out=$(bash "$doctor" --headless 2>&1)
assert_contains "headless mode is explicit" "Mode: headless" "$out"
assert_contains "headless mode reports core dependencies" "Missing required commands:" "$out"
refute "headless mode does not demand Ghostty" grep -q 'MISSING  ghostty' <<< "$out"
out=$(bash "$doctor" --desktop 2>&1)
assert_contains "desktop mode is explicit" "Mode: desktop" "$out"
assert_contains "desktop mode checks Wayland clipboard" "wl-copy" "$out"
bash "$doctor" --bad >/dev/null 2>&1
assert_eq "unknown flag exits 2" 2 "$?"
t_done
