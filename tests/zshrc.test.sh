#!/usr/bin/env bash
# The completion dump: reused while fresh (fast start), and checked against fpath once it is a day old, so a tool installed
# later (brew install ...) gets its completions.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v zsh >/dev/null; then echo "zsh not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT
H=$T_DIR/home; mkdir -p "$H/extra"; t_render "$H"
dump=$H/.cache/zsh/zcompdump
# A start with $H/extra on fpath, the way a newly installed tool puts a completion file on it.
start() { HOME="$H" zsh -f -c "fpath=('$H/extra' \$fpath); source '$H/.zshrc'" >/dev/null 2>&1; }

echo "the first start writes the completion dump into the XDG cache dir"
start; assert "the dump exists" test -s "$dump"
refute "and it knows no wbtest command yet" grep -q wbtest "$dump"

echo "a completion installed afterwards is not seen while the dump is fresh (that is what makes the start fast)"
printf '#compdef wbtest\n_wbtest() { :; }\n' > "$H/extra/_wbtest"
start; refute "a fresh dump is reused as it is" grep -q wbtest "$dump"

echo "once the dump is a day old it is checked again, and the new completion shows up"
touch -t 202001010000 "$dump"
start; assert "the dump now lists wbtest" grep -q wbtest "$dump"
t_done
