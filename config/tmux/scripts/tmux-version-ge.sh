#!/usr/bin/env bash
# tmux-version-ge.sh MAJOR MINOR — exit 0 if the running tmux is at least MAJOR.MINOR, 1 if older, 2 on bad usage.
# Used by tmux.conf through if-shell, so this shared config still loads on an older tmux.
# A build without a version number (e.g. "tmux master") counts as new. TMUX_VERSION_CMD overrides `tmux -V` (tests).
[ $# -eq 2 ] || { echo "usage: $(basename "$0") MAJOR MINOR" >&2; exit 2; }
out=$(${TMUX_VERSION_CMD:-tmux -V} 2>/dev/null)
v=$(echo "$out" | awk '{print $NF}' | sed 's/^next-//; s/[^0-9.].*$//')
case "$v" in [0-9]*) ;; *) exit 0 ;; esac
major=${v%%.*}; rest=${v#*.}; [ "$rest" = "$v" ] && rest=0; minor=${rest%%.*}
[ "${major:-0}" -gt "$1" ] && exit 0
[ "${major:-0}" -eq "$1" ] && [ "${minor:-0}" -ge "$2" ] && exit 0
exit 1
