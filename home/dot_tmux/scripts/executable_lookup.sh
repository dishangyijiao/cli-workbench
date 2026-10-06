#!/bin/sh
# Translate or look up the text you just selected, in a popup, so the pane you are reading stays put.
#   lookup.sh          the newest tmux paste buffer: a mouse selection and `y` in copy mode both put the selection there
#   lookup.sh TEXT...  the given text (by hand)
# One English word gives a dictionary entry (meanings and translations); anything longer gives its translation.
# Needs translate-shell:  brew install translate-shell
# The text is sent to the translation service (translate-shell uses Google by default), so do not use this on text
# you may not send out. Selected text is data: it goes in on standard input and is never part of a command line.
#   LOOKUP_LANG   target language (default zh-CN)
lang=${LOOKUP_LANG:-zh-CN}

if [ $# -gt 0 ]; then text=$*; else text=$(tmux show-buffer 2>/dev/null); fi
# A selection wraps across lines; squeeze it to one line and cap its length.
text=$(printf '%s' "$text" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//' | cut -c1-1500)

show() {
  if [ -t 1 ]; then less -R; else cat; fi
}

if [ -z "$text" ]; then
  printf 'nothing selected: select some text first (drag with the mouse, or v ... y in copy mode)\n' | show
  exit 0
fi
if ! command -v trans >/dev/null 2>&1; then
  printf 'translate-shell is not installed: brew install translate-shell\n' | show
  exit 0
fi

# One word, with the punctuation around it ("analogy," or "(scrutiny)") taken off, gets the dictionary entry.
word=$(printf '%s' "$text" | sed 's/^[^A-Za-z]*//; s/[^A-Za-z]*$//')
case $word in
  '' | *[!A-Za-z\'-]*) brief=-b; query=$text ;;
  *) brief=''; query=$word ;;
esac

{
  printf '%s\n\n' "$text"
  # shellcheck disable=SC2086  # $brief is empty or the single flag -b
  printf '%s' "$query" | trans $brief ":$lang" -i /dev/stdin 2>&1
} | show
