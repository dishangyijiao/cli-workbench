#!/usr/bin/env bash
# A directory name, a pane title or a window name is text that a repository or a program controls. The tmux config must
# never paste such text into a shell command: inside double quotes, $(...) or a backtick in the name would run.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v tmux >/dev/null; then echo "tmux not installed; skipped"; exit 0; fi
if ! command -v git >/dev/null; then echo "git not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
export HOME=$T_DIR/home; mkdir -p "$HOME"
SOCK=wbconf$$
X() { tmux -L "$SOCK" "$@"; }
cleanup() { X kill-server 2>/dev/null; case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac; }
trap cleanup EXIT
unset TMUX
t_render "$HOME"
CONF=$HOME/.tmux.conf

echo "no directory, title or name is placed inside a shell command"
# What runs in a shell: the inside of every #( ), and every run-shell, if-shell and display-popup line. None of it may
# contain these formats (##{ is an escaped literal). The same format outside a shell command, as display text, is fine.
code=$(grep -v '^[[:space:]]*#' "$CONF")
bad=$({ printf '%s\n' "$code" | grep -o '#([^)]*)'; printf '%s\n' "$code" | grep -E 'run-shell|if-shell|display-popup'; } \
  | grep -E '(^|[^#])#\{[a-z]*:?(pane_current_path|pane_title|pane_current_command|window_name|session_name)\}')
assert_eq "the config passes none of them into a shell command" "" "$bad"

echo "a directory named like a command substitution is just a name"
# If a shell ever sees the name it runs "cd; touch wbmarker": cd goes to HOME, the throwaway home, so the marker is
# $HOME/wbmarker. The name has no / and no ${ }, which tmux itself rewrites in some versions.
EVIL=$T_DIR/'$(cd;touch wbmarker)'
mkdir -p "$EVIL"; git -C "$EVIL" init -q; git -C "$EVIL" symbolic-ref HEAD refs/heads/main
X -f "$CONF" new-session -d -s t -c "$EVIL"
pane=$(X list-panes -t t -F '#{pane_id}' | head -n 1)
# A new pane only learns its directory a moment after it starts (on Linux from /proc), so ask until it answers (5 s at most).
sock=$(X display-message -p '#{socket_path}')
branch=""
for _ in $(seq 1 50); do
  branch=$(TMUX="$sock,0,0" "$HOME/.tmux/scripts/branch.sh" "$pane")
  [ -n "$branch" ] && break
  sleep 0.1
done
assert_eq "branch.sh reads the branch from a pane id" "⎇ main" "$branch"

assert "prefix+N is bound" test "$(X list-keys -T prefix | grep -cE ' N +run-shell')" -eq 1
# Run prefix+N's command as the config says it, through the same parser tmux uses to load the config. (list-keys prints
# the command with version-specific escaping, so it cannot be fed back.)
grep '^bind N run-shell ' "$CONF" | sed 's/^bind N //' > "$T_DIR/bindN.conf"
X source-file "$T_DIR/bindN.conf" >/dev/null 2>&1
# The command runs in the background of the server: wait until the session it makes exists (10 s at most), so that
# "no marker" below means the command has finished and not only that it has not started.
for _ in $(seq 1 50); do
  [ "$(X list-sessions -F '#S' | grep -cF 'touch')" -ge 1 ] && break
  sleep 0.2
done
assert "prefix+N did not run the directory name as a command" test ! -e "$HOME/wbmarker"
assert_eq "prefix+N still makes a session named after the directory" 1 "$(X list-sessions -F '#S' | grep -cF 'touch')"
if [ "$T_FAILS" -gt 0 ]; then   # what a failing run needs to be understood from a CI log alone
  echo "  --- diagnostics"
  tmux -V
  echo "  branch=[$branch] pane=[$pane] pane path=[$(X display-message -p -t "$pane" '#{pane_current_path}' 2>&1)]"
  echo "  branch.sh stderr: $(TMUX="$sock,0,0" "$HOME/.tmux/scripts/branch.sh" "$pane" 2>&1 >/dev/null)"
  echo "  keys named N: $(X list-keys -T prefix 2>&1 | grep -E ' N ' | cut -c1-200)"
  echo "  bindN.conf: $(cat "$T_DIR/bindN.conf")"
  echo "  source-file: $(X source-file "$T_DIR/bindN.conf" 2>&1)"
  echo "  sessions: $(X list-sessions -F '#S' 2>&1 | tr '\n' ' ')"
  echo "  messages: $(X show-messages 2>&1 | tail -n 5)"
fi
t_done
