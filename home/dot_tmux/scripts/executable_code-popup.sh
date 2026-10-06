#!/bin/sh
# Open Neovim in a tmux popup over the current pane, in that pane's directory (prefix+e, prefix+g).
#   code-popup.sh browse  %12    the project: file tree, search, go to definition
#   code-popup.sh changes %12    :Changes, the files this branch changed with a diff preview (lua/git/changes.lua)
# The pane id is resolved here, so a directory name never becomes part of a shell command line (see branch.sh).
mode=$1 pane=$2
case $mode in browse|changes) ;; *) echo "usage: code-popup.sh browse|changes PANE_ID" >&2; exit 2 ;; esac
dir=$(tmux display-message -p -t "$pane" '#{pane_current_path}') || exit 1
cd "$dir" || exit 1
[ "$mode" = browse ] && exec nvim

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf 'Nothing to review: %s is not a git repository. Press Enter.' "$dir"; read -r _; exit 0
fi
exec nvim -c Changes
