#!/usr/bin/env bash
# The package list a reader copies from docs/omarchy.md and packages/arch-packages.txt describe the same set; when one
# gains a package and the other does not, an Arch install quietly lacks a tool the doctor or a script needs.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
LIST=$WB_SRC/packages/arch-packages.txt
DOC=$WB_SRC/docs/omarchy.md

from_list() { grep -v '^#' "$LIST" | grep -v '^$' | sort; }
# The first "sudo pacman -S --needed ..." line of the guide, without the command itself.
from_doc() { grep -m1 '^sudo pacman -S --needed ' "$DOC" | sed 's/^sudo pacman -S --needed //' | tr ' ' '\n' | grep -v '^$' | sort; }

echo "the Omarchy guide and the Arch package list name the same packages"
assert "the package list is not empty" test -n "$(from_list)"
assert "the guide has an install command" test -n "$(from_doc)"
assert_eq "same packages in both" "$(from_list | tr '\n' ' ')" "$(from_doc | tr '\n' ' ')"
t_done
