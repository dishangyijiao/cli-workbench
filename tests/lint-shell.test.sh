#!/usr/bin/env bash
# scripts/lint-shell: which files it checks, that a warning fails it, and that CI cannot lose the gate silently.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
LINT=$WB_SRC/scripts/lint-shell
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT

echo "without shellcheck it skips, and --require turns that into a failure"
(cd "$T_DIR" && SHELLCHECK=no-such-shellcheck "$LINT" >/dev/null 2>&1); assert_eq "skips with exit 0" 0 $?
(cd "$T_DIR" && SHELLCHECK=no-such-shellcheck "$LINT" --require >/dev/null 2>&1); assert_eq "--require exits 2" 2 $?
(cd "$T_DIR" && "$LINT" --bogus >/dev/null 2>&1); assert_eq "an unknown option exits 2" 2 $?

if ! command -v shellcheck >/dev/null; then echo "shellcheck not installed; the rest is skipped"; t_done; exit $?; fi

R=$T_DIR/repo; mkdir -p "$R"; git -C "$R" init -q
printf '#!/usr/bin/env bash\necho ok\n' > "$R/good.sh"
printf '#!/bin/sh\necho $1\n' > "$R/note-only.sh"           # SC2086 is only a note: below the warning gate
printf '#!/usr/bin/env zsh\nprint -r -- ${(k)x}\n' > "$R/prompt.zsh"   # zsh syntax the linter cannot parse: must not be handed over
printf 'unused=1\n' > "$R/data.txt"                         # no #! line: not a script

echo "checks bash and sh scripts by their #! line, and ignores the rest"
out=$(cd "$R" && "$LINT" 2>&1); assert_eq "clean tree exits 0" 0 $?
assert_contains "two files were checked" "2 files ok" "$out"

echo "a warning fails the check and names the file"
printf '#!/bin/bash\nunused=1\n' > "$R/bad.sh"
out=$(cd "$R" && "$LINT" 2>&1); rc=$?
assert_eq "exit 1" 1 "$rc"
assert_contains "bad.sh is reported" "bad.sh" "$out"

echo "files git ignores are not checked"
rm "$R/bad.sh"; printf '#!/bin/bash\nunused=1\n' > "$R/ignored.sh"; echo ignored.sh > "$R/.gitignore"
(cd "$R" && "$LINT" >/dev/null 2>&1); assert_eq "an ignored script does not fail the check" 0 $?

echo "this repository passes"
(cd "$WB_SRC" && "$LINT" >/dev/null 2>&1); assert_eq "scripts/lint-shell is clean here" 0 $?
t_done
