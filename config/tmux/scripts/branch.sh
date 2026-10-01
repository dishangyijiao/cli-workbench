#!/bin/sh
# Print the git branch of the pane's directory; a short hash on a detached HEAD;
# nothing at all outside a repository.
# --no-optional-locks: do not take the index lock, so this never conflicts with
# git commands that Claude Code is running.
dir="${1:-.}"
branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) \
  || branch=$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null) \
  || exit 0
printf '⎇ %s' "$branch"
