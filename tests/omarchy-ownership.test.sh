#!/usr/bin/env bash
# On Linux (Omarchy) the desktop owns the Ghostty theme and font, so the repository must not deploy a Ghostty config
# there; on macOS it still does. The rule lives in home/.chezmoiignore. It is checked for both operating systems by
# overriding chezmoi's os, and once for real by deploying into a disposable HOME on the machine running the test.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v chezmoi >/dev/null; then echo "chezmoi not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT
IGNORE=$WB_SRC/home/.chezmoiignore

ignored() { # ignored OS -> the ignore patterns chezmoi would read on that OS
  chezmoi execute-template --source "$WB_SRC" --override-data "{\"chezmoi\":{\"os\":\"$1\"}}" < "$IGNORE" 2>/dev/null
}

echo "the Ghostty config is ignored on Linux and managed on macOS"
assert "home/.chezmoiignore exists" test -f "$IGNORE"
assert_contains "linux ignores the Ghostty config" ".config/ghostty" "$(ignored linux)"
refute "darwin does not ignore the Ghostty config" sh -c "chezmoi execute-template --source '$WB_SRC' --override-data '{\"chezmoi\":{\"os\":\"darwin\"}}' < '$IGNORE' | grep -q ghostty"

echo "a real deployment follows the rule on this machine"
export HOME=$T_DIR/home; mkdir -p "$HOME"
t_render "$HOME"
case $(uname -s) in
  Darwin) assert "macOS gets the Ghostty config" test -s "$HOME/.config/ghostty/config" ;;
  *)      assert "Linux gets no Ghostty config" test ! -e "$HOME/.config/ghostty" ;;
esac
t_done
