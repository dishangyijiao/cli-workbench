#!/bin/sh
# Print the git branch of a pane's directory; a short hash on a detached HEAD;
# nothing at all outside a repository.
#   branch.sh %12      a tmux pane id: the directory is looked up here, so that a directory name is never
#                      part of a shell command line (a name like $(...) would run there)
#   branch.sh DIR      a directory (by hand)
# --no-optional-locks: do not take the index lock, so this never conflicts with
# git commands that Claude Code is running.
arg="${1:-.}"
case $arg in
  %[0-9]*) dir=$(tmux display-message -p -t "$arg" '#{pane_current_path}' 2>/dev/null) || exit 0 ;;
  *) dir=$arg ;;
esac
[ -n "$dir" ] || exit 0
branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) \
  || branch=$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null) \
  || exit 0
printf '⎇ %s' "$branch"
