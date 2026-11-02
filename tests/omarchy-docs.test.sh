#!/usr/bin/env bash
# The Omarchy guide is public. It must stay free of the author's own devices, and its incremental deployment steps must
# work as written: they are run here, with the targets taken from the guide itself.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
GUIDE=$WB_SRC/docs/omarchy.md

echo 'public documents and the acceptance script name no personal device'
# Product names of the author's machines tie a public repository to one person; say "the Omarchy host" and "the Mac".
for f in "$GUIDE" "$WB_SRC/README.md" "$WB_SRC/README.zh-CN.md" "$WB_SRC/scripts/accept-omarchy" "$WB_SRC/scripts/doctor-omarchy"; do
  refute "$(basename "$f") names no personal device" grep -Eqi 'SER9|MacBook' "$f"
done

echo 'the incremental deployment steps in the guide work as written'
if ! command -v chezmoi >/dev/null || ! command -v tmux >/dev/null; then echo 'chezmoi or tmux not installed; skipped'; t_done; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
SOCK=wbincr$$
cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null; t_cleanup; }
trap cleanup EXIT
unset TMUX
export HOME=$T_DIR/home; mkdir -p "$HOME"
step=$(grep -m1 '^chezmoi apply ~/' "$GUIDE")
assert 'the guide has an incremental chezmoi apply step' test -n "$step"
targets=${step#chezmoi apply }
# Run the targets the guide lists, as it says: relative to HOME, only those.
eval "set -- $(printf '%s' "$targets" | sed "s|~|$HOME|g")"
chezmoi apply --source "$WB_SRC" --destination "$HOME" --no-tty --cache "$HOME/.chezmoi-cache" \
  --persistent-state "$HOME/.chezmoi-state" "$@" >/dev/null 2>&1
assert_eq 'the listed targets apply' 0 "$?"
assert 'the tmux config is in place' test -s "$HOME/.tmux.conf"
assert 'the tmux scripts are in place' test -d "$HOME/.tmux/scripts"
refute 'the shell config waits (the guide says to apply it last)' test -e "$HOME/.zshrc"
cmd=$(grep -m1 '^tmux -L ' "$GUIDE")
assert 'the guide has an isolated tmux start' test -n "$cmd"
# The guide starts it in the foreground; start the same server detached to read its state.
out=$(tmux -L "$SOCK" -f "$HOME/.tmux.conf" new-session -d \; show -gv prefix 2>&1)
assert_contains 'the isolated server starts with the deployed config' 'C-' "$out"
assert_contains 'the guide names the socket option and the config file' '-f ~/.tmux.conf' "$cmd"
t_done
