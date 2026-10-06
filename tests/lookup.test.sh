#!/usr/bin/env bash
# lookup.sh turns what you just selected into a translation popup. It must treat the selection as data (a book can hold
# any characters), tell one word from a sentence, and say what to do when there is nothing to look up. A stub stands in
# for translate-shell, so no test calls the network.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v tmux >/dev/null; then echo "tmux not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
export HOME=$T_DIR/home; mkdir -p "$HOME"
SOCK=wblookup$$
X() { tmux -L "$SOCK" "$@"; }
cleanup() { X kill-server 2>/dev/null; case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac; }
trap cleanup EXIT
unset TMUX
t_render "$HOME"
LOOKUP=$HOME/.tmux/scripts/lookup.sh
CONF=$HOME/.tmux.conf

# A stand-in for `trans`: it records its arguments and what arrived on standard input, then answers.
STUB=$T_DIR/stub; mkdir -p "$STUB"
cat > "$STUB/trans" <<EOF
#!/bin/sh
printf '%s\n' "\$*" > "$T_DIR/args"
cat > "$T_DIR/stdin"
printf 'STUB ANSWER\n'
EOF
chmod +x "$STUB/trans"
run() { PATH="$STUB:$PATH" sh "$LOOKUP" "$@"; }

echo "a sentence is translated briefly, on one line"
out=$(run "Always test your analogies
  to be sure.")
assert_eq "the target language is the default zh-CN, in brief mode" "-b :zh-CN -i /dev/stdin" "$(cat "$T_DIR/args")"
assert_eq "the wrapped selection reaches trans as one line" "Always test your analogies to be sure." "$(cat "$T_DIR/stdin")"
assert_contains "the original is shown above the answer" "Always test your analogies to be sure." "$out"
assert_contains "the answer is shown" "STUB ANSWER" "$out"

echo "one word gets the dictionary entry, without the punctuation around it"
run '(scrutiny),' >/dev/null
assert_eq "no brief flag for a word" ":zh-CN -i /dev/stdin" "$(cat "$T_DIR/args")"
assert_eq "only the word is looked up" "scrutiny" "$(cat "$T_DIR/stdin")"
run "don't" >/dev/null
assert_eq "an apostrophe stays inside a word" "don't" "$(cat "$T_DIR/stdin")"

echo "the target language can be changed"
LOOKUP_LANG=ja run "hello world" >/dev/null
assert_eq "LOOKUP_LANG is used" "-b :ja -i /dev/stdin" "$(cat "$T_DIR/args")"

echo "selected text is data, never part of a command line"
EVIL='-x $(cd;touch wbmarker) `touch wbmarker2` "q"'
run "$EVIL" >/dev/null
assert_eq "the text arrives on standard input unchanged" "$EVIL" "$(cat "$T_DIR/stdin")"
assert_eq "the arguments never contain it" "-b :zh-CN -i /dev/stdin" "$(cat "$T_DIR/args")"
refute "nothing in the text ran" test -e "$HOME/wbmarker" -o -e "$HOME/wbmarker2"

echo "a very long selection is cut"
long=$(printf 'a%.0s ' $(seq 1 2000))
run "$long" >/dev/null
assert "at most 1500 characters are sent" test "$(wc -c < "$T_DIR/stdin")" -le 1500

echo "with no text, or without translate-shell, it says what to do and does not fail"
out=$(run ""); rc=$?
assert_eq "an empty selection exits 0" "0" "$rc"
assert_contains "it says to select something" "nothing selected" "$out"
out=$(PATH="/usr/bin:/bin" sh "$LOOKUP" "hello"); rc=$?
assert_eq "a missing trans exits 0" "0" "$rc"
assert_contains "it names the install command" "brew install translate-shell" "$out"

echo "with no argument it reads the newest tmux buffer"
X -f /dev/null new-session -d -s t
X set-buffer -- "from the buffer"
sock=$(X display-message -p '#{socket_path}')
TMUX="$sock,0,0" PATH="$STUB:$PATH" sh "$LOOKUP" >/dev/null
assert_eq "the buffer text is what is translated" "from the buffer" "$(cat "$T_DIR/stdin")"

echo "prefix + t opens it in a popup"
X kill-server 2>/dev/null
X -f "$CONF" start-server \; new-session -d -s c
keys=$(X list-keys -T prefix | grep -E ' t +display-popup ')
assert_contains "t is bound to a popup" "lookup.sh" "$keys"
code=$(grep -v '^[[:space:]]*#' "$CONF" | grep 'lookup.sh')
assert_eq "the popup command holds no pane, window or session format" "" "$(printf '%s\n' "$code" | grep -E '#\{')"

t_done
