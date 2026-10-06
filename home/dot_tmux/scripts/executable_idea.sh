#!/bin/sh
# Write an idea down without leaving the terminal: one line appended to ~/.config/cli-workbench/inbox.md.
#   idea.sh --pane %12      prefix+a popup: asks for one line; the project is that pane's directory (looked up here,
#                           so a directory name never becomes part of a shell command line; see branch.sh)
#   idea.sh -- TEXT...      `idea TEXT...` in a shell: the arguments are the text, the current directory the project
#   idea.sh --              `idea` alone: asks for one line
# A line is "- [ ] 2026-10-06 17:42 · ~/dev/projects/foo · text". The project is the repository's top directory
# (the main one for a worktree), else the directory; "?" when the pane is gone. There is no heading, so the file
# needs no set-up: every idea is a single append of a single line. Newlines become spaces; the text is only data.
inbox=$HOME/.config/cli-workbench/inbox.md
popup=
case ${1-} in
  --pane) popup=1; dir=$(tmux display-message -p -t "${2-}" '#{pane_current_path}' 2>/dev/null) || dir=; shift 2 ;;
  --) shift; dir=$PWD ;;
  *) echo "usage: idea.sh --pane PANE_ID | idea.sh -- [TEXT...]" >&2; exit 2 ;;
esac

fail() {
  printf 'idea: %s\n' "$1" >&2
  if [ -n "$popup" ]; then printf 'Press Enter to close.' >&2; read -r _; fi
  exit 1
}

if [ $# -gt 0 ]; then
  text=$*
else
  printf 'idea> '
  IFS= read -r text || [ -n "$text" ] || exit 0          # Ctrl-D on an empty line: cancel
fi
text=$(printf '%s' "$text" | tr '\n\r' '  ')
case $text in *[![:space:]]*) ;; *) exit 0 ;; esac      # nothing typed: write nothing

project='?'
if [ -n "$dir" ] && [ -d "$dir" ]; then
  project=$dir
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && case $common in
    */.git) project=${common%/.git} ;;
    *) project=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || project=$dir ;;
  esac
  case $project in "$HOME"/*) project="~${project#"$HOME"}" ;; esac
fi

mkdir -p "${inbox%/*}" 2>/dev/null || fail "cannot create ${inbox%/*} for $inbox; your idea was: $text"
line=$(printf -- '- [ ] %s · %s · %s' "$(date '+%Y-%m-%d %H:%M')" "$project" "$text")
(umask 077; printf '%s\n' "$line" >> "$inbox") 2>/dev/null || fail "could not write $inbox; your idea was: $text"
