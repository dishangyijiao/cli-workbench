#!/usr/bin/env bash
# scripts/tdd-gate: a feat/fix/refactor/perf commit that changes product code must add or change a test in the same commit.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
GATE=$WB_SRC/scripts/tdd-gate
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT

R=$T_DIR/repo; mkdir -p "$R"; git -C "$R" init -q -b main
git -C "$R" config user.email t@example.invalid; git -C "$R" config user.name t
msg() { printf '%s\n' "$@" > "$T_DIR/msg"; }
gate() { (cd "$R" && "$GATE" "$T_DIR/msg" >/dev/null 2>&1); }
stage() { git -C "$R" reset -q; for f in "$@"; do mkdir -p "$R/$(dirname "$f")"; echo "$RANDOM" >> "$R/$f"; git -C "$R" add "$f"; done; }
base() { git -C "$R" add -A; git -C "$R" commit -q --no-verify -m "chore: base"; }
stage home/dot_zshrc tests/zshrc.test.sh scripts/privacy-scan docs/architecture.md; base

echo "product code without a test is refused for feat, fix, refactor and perf"
stage home/dot_zshrc
for type in feat fix refactor perf; do msg "$type(zsh): change"; gate; assert_eq "$type is refused" 1 $?; done
for type in feat fix refactor perf; do msg "$type!: change"; gate; assert_eq "$type!: (no scope, breaking) is refused" 1 $?; done
msg "fix(zsh)!: breaking"; gate; assert_eq "scope plus breaking marker is refused" 1 $?
msg "Fix(zsh): capitalised"; gate; assert_eq "a capitalised type is still checked" 1 $?
stage scripts/privacy-scan; msg "fix: scripts count as product code"; gate; assert_eq "scripts/ is refused" 1 $?
stage .githooks/pre-commit; msg "fix: hooks count as product code"; gate; assert_eq ".githooks/ is refused" 1 $?
stage "home/dot_café/f"; msg "fix: unicode path"; gate; assert_eq "a non-ASCII path is still seen" 1 $?
git -C "$R" reset -q --hard; git -C "$R" clean -fdq; git -C "$R" rm -q home/dot_zshrc
assert_eq "setup: the only staged change is the deletion" "D	home/dot_zshrc" "$(git -C "$R" diff --cached --name-status)"
msg "refactor: delete code"; gate; assert_eq "deleting product code is refused" 1 $?
git -C "$R" reset -q --hard

echo "a test in the same commit lets it through"
stage home/dot_zshrc tests/zshrc.test.sh; msg "fix(zsh): change"; gate; assert_eq "code plus an edited test passes" 0 $?
stage home/dot_zshrc tests/new.test.sh; msg "feat: change"; gate; assert_eq "code plus a new test passes" 0 $?

echo "a test that is only deleted or is not a test does not count"
git -C "$R" reset -q --hard; git -C "$R" clean -fdq; stage home/dot_zshrc; git -C "$R" rm -qf tests/zshrc.test.sh
assert_eq "setup: staged are the code change and the test deletion" "D	tests/zshrc.test.sh M	home/dot_zshrc" "$(git -C "$R" diff --cached --name-status | sort | tr '\n' ' ' | sed 's/ $//')"
msg "fix: change"; gate; assert_eq "deleting a test is refused" 1 $?
git -C "$R" reset -q --hard
stage home/dot_zshrc tests/notes.txt tests/harness.sh; msg "fix: change"; gate; assert_eq "a non-test file under tests/ is refused" 1 $?
git -C "$R" reset -q --hard

echo "commits that need no test"
stage home/dot_zshrc
for type in docs chore test ci style build; do msg "$type: change"; gate; assert_eq "$type passes" 0 $?; done
msg "fixture: not a fix type"; gate; assert_eq "a look-alike type passes" 0 $?
msg 'Revert "fix: x"'; gate; assert_eq "a revert passes" 0 $?
stage docs/architecture.md; msg "fix: typo in docs"; gate; assert_eq "fix without product code passes" 0 $?

echo "a merge in progress passes"
stage home/dot_zshrc; msg "fix: merge side branch"
git -C "$R" rev-parse HEAD > "$R/.git/MERGE_HEAD"; gate; assert_eq "MERGE_HEAD present" 0 $?
rm -f "$R/.git/MERGE_HEAD"

echo "amending judges the amended commit, not only the new delta"
git -C "$R" reset -q --hard; stage home/dot_zshrc tests/zshrc.test.sh; git -C "$R" commit -q --no-verify -m "fix: with a test"
stage home/dot_zshrc; msg "fix: with a test"
gate; assert_eq "without the amend flag a code-only delta is refused" 1 $?
(cd "$R" && TDD_GATE_AMEND=1 "$GATE" "$T_DIR/msg" >/dev/null 2>&1); assert_eq "amend of a commit that has a test passes" 0 $?
git -C "$R" reset -q --hard; stage home/dot_zshrc; git -C "$R" commit -q --no-verify -m "fix: no test"
stage home/dot_zshrc; msg "fix: no test"
(cd "$R" && TDD_GATE_AMEND=1 "$GATE" "$T_DIR/msg" >/dev/null 2>&1); assert_eq "amend of a commit that has none is refused" 1 $?
git -C "$R" reset -q --hard

echo "the explicit escape hatch needs a reason"
stage home/dot_zshrc
msg "fix(zsh): comment only" "" "tdd: skip - comment-only change, no behaviour"; gate; assert_eq "skip with a reason passes" 0 $?
msg "fix(zsh): comment only" "" "tdd: skip"; gate; assert_eq "skip without a reason is refused" 1 $?
msg "fix(zsh): comment only" "" "# tdd: skip - in a comment line"; gate; assert_eq "skip inside a comment line is refused" 1 $?

echo "the refusal says what to do"
stage home/dot_zshrc; msg "feat: x"
out=$(cd "$R" && "$GATE" "$T_DIR/msg" 2>&1)
assert_contains "mentions tests/" "tests/*.test.sh" "$out"
assert_contains "mentions the escape hatch" "tdd: skip" "$out"

echo "--range checks every commit of a pull request, so --no-verify cannot skip the gate"
rangegate() { (cd "$R" && "$GATE" --range "$1" >"$T_DIR/range.out" 2>&1); }
git -C "$R" reset -q --hard; git -C "$R" tag start
stage home/dot_zshrc tests/zshrc.test.sh; git -C "$R" commit -q --no-verify -m "fix: with a test"
stage docs/architecture.md;               git -C "$R" commit -q --no-verify -m "docs: words"
rangegate start..HEAD; assert_eq "a good range passes" 0 $?
stage home/dot_zshrc;                      git -C "$R" commit -q --no-verify -m "feat: no test here"
bad=$(git -C "$R" rev-parse --short HEAD)
rangegate start..HEAD; assert_eq "a range with one bad commit fails" 1 $?
assert_contains "the bad commit is named" "$bad" "$(cat "$T_DIR/range.out")"
stage home/dot_zshrc;                      git -C "$R" commit -q --no-verify -m "fix: skipped" -m "tdd: skip - comment only"
git -C "$R" tag skipped; git -C "$R" reset -q --hard "$bad"; git -C "$R" tag -f bad >/dev/null
rangegate start..bad; assert_eq "still failing" 1 $?
rangegate bad..HEAD 2>/dev/null; assert_eq "a skip with a reason in range mode passes" 0 $?
rangegate start..start; assert_eq "an empty range passes" 0 $?
git -C "$R" commit -q --allow-empty --no-verify -m "feat: empty"
rangegate bad..HEAD; assert_eq "a commit that changes nothing passes" 0 $?
(cd "$R" && "$GATE" --range >/dev/null 2>&1); assert_eq "--range without a range exits 2" 2 $?

echo "only the first line decides the commit type, and only a tests/*.test.sh is a test"
git -C "$R" reset -q --hard; git -C "$R" clean -fdq
stage home/dot_zshrc; msg "docs: words" "" "fix: this line is in the body"; gate; assert_eq "a body line that looks like a type is ignored" 0 $?
stage home/dot_zshrc home/other.test.sh; msg "fix: x"; gate; assert_eq "a *.test.sh outside tests/ is not a test" 1 $?
stage home/dot_zshrc tests/sub/deep.test.sh; msg "fix: x"; gate; assert_eq "a test in a subdirectory of tests/ counts" 0 $?
stage home/dot_zshrc "tests/café.test.sh"; msg "fix: x"; gate; assert_eq "a test with a non-ASCII name counts" 0 $?
stage home/dot_zshrc; msg "fix: x" "" "tdd: skip -  "; gate; assert_eq "a whitespace-only skip reason is refused" 1 $?
msg "fix: x" "" "tdd: skip - "; gate; assert_eq "an empty skip reason after the dash is refused" 1 $?
msg "fix: x" "" "tdd: skip -x"; gate; assert_eq "a skip without the separating space is refused" 1 $?

echo "amending a root commit"
A=$T_DIR/root; mkdir -p "$A/scripts"; git -C "$A" init -q -b main; git -C "$A" config user.email t@example.invalid; git -C "$A" config user.name t
amend() { (cd "$A" && TDD_GATE_AMEND=1 "$GATE" "$T_DIR/msg" >/dev/null 2>&1); }
P=home; mkdir -p "$A/$P" "$A/tests"; echo 1 > "$A/$P/a"; echo 1 > "$A/tests/a.test.sh"; git -C "$A" add -A; git -C "$A" commit -q --no-verify -m "feat: first"
echo 2 >> "$A/$P/a"; git -C "$A" add -A; msg "feat: first"; amend; assert_eq "root commit that has a test: amend passes" 0 $?
git -C "$A" reset -q --hard; git -C "$A" rm -q tests/a.test.sh; git -C "$A" commit -q --amend --no-verify -m "feat: first"; echo 3 >> "$A/$P/a"; git -C "$A" add -A
amend; assert_eq "root commit with no test: amend is refused" 1 $?

echo "--range in detail (its own code path, so it needs its own cases)"
P=home; Q=$T_DIR/q; mkdir -p "$Q"; git -C "$Q" init -q -b main; git -C "$Q" config user.email t@example.invalid; git -C "$Q" config user.name t
qc() { local m=$1 b=$2; shift 2; for f in "$@"; do mkdir -p "$Q/$(dirname "$f")"; echo "$RANDOM" >> "$Q/$f"; done; git -C "$Q" add -A
  if [ -n "$b" ]; then git -C "$Q" commit -q --no-verify -m "$m" -m "$b"; else git -C "$Q" commit -q --no-verify -m "$m"; fi; }
qrange() { (cd "$Q" && "$GATE" --range "$1" >"$T_DIR/q.out" 2>&1); }
qreset() { git -C "$Q" reset -q --hard cur; }
qc "feat: first, no test" "" home/a
qrange HEAD; assert_eq "a root commit is checked" 1 $?
qc "chore: tests" "" tests/t.test.sh; git -C "$Q" tag cur
qc "fix: unicode" "" "home/dot_café/f";           qrange cur..HEAD; assert_eq "a non-ASCII product path is seen" 1 $?; qreset
qc "fix: code with test" "" home/b tests/t.test.sh; qrange cur..HEAD; assert_eq "code plus an edited test passes" 0 $?; qreset
qc "fix: non-ASCII test name" "" home/b "tests/café.test.sh"; qrange cur..HEAD; assert_eq "a test with a non-ASCII name counts" 0 $?; qreset
git -C "$Q" rm -q home/a; git -C "$Q" commit -q --no-verify -m "refactor: delete product code"
qrange cur..HEAD; assert_eq "deleting product code needs a test" 1 $?; qreset
echo 1 >> "$Q/$P/b"; git -C "$Q" rm -q tests/t.test.sh; git -C "$Q" add -A; git -C "$Q" commit -q --no-verify -m "fix: deletes the test"
qrange cur..HEAD; assert_eq "deleting a test does not count" 1 $?; qreset
qc "fix: x" "" home/b home/b.test.sh;              qrange cur..HEAD; assert_eq "a *.test.sh outside tests/ does not count" 1 $?; qreset
qc "feat!: breaking" "" home/b;                    qrange cur..HEAD; assert_eq "feat!: is checked" 1 $?; qreset
qc "docs: has code" "" home/b;                     qrange cur..HEAD; assert_eq "docs: needs no test" 0 $?; qreset
qc "fixture: look-alike" "" home/b;                qrange cur..HEAD; assert_eq "a look-alike type needs no test" 0 $?; qreset
qc "fix: c" "tdd: skip - comment only" home/b;     qrange cur..HEAD; assert_eq "a skip with a reason passes" 0 $?
assert_contains "and the skip is printed for reviewers" "skipped" "$(cat "$T_DIR/q.out")"; qreset
qc "fix: c" "tdd: skip" home/b;                    qrange cur..HEAD; assert_eq "a skip without a reason fails" 1 $?; qreset
qc "fix: c" "tdd: skip -  " home/b;                qrange cur..HEAD; assert_eq "a whitespace-only reason fails" 1 $?; qreset
qc "fix: first bad" "" home/b; qc "fix: second bad" "" home/c; qrange cur..HEAD
out=$(cat "$T_DIR/q.out"); assert_contains "both bad commits are listed" "second bad" "$out"
case ${out%%second bad*} in *"first bad"*) t_ok "oldest first";; *) t_fail "oldest first";; esac; qreset
git -C "$Q" checkout -q -b side; qc "chore: side" "" home/s; git -C "$Q" checkout -q main; qc "chore: m" "" home/m
git -C "$Q" merge --no-ff -q side -m "fix: merge side"; qrange cur..HEAD; assert_eq "a merge commit is not judged" 0 $?; qreset

echo "the amend marker (hook scripts called directly)"
H=$T_DIR/hooked; mkdir -p "$H/scripts" "$H/.githooks"; git -C "$H" init -q -b main
cp "$GATE" "$H/scripts/tdd-gate"; cp "$WB_SRC/.githooks/commit-msg" "$WB_SRC/.githooks/prepare-commit-msg" "$H/.githooks/"
git -C "$H" config user.email t@example.invalid; git -C "$H" config user.name t
echo 1 > "$H/f"; git -C "$H" add -A; git -C "$H" commit -q --no-verify -m "chore: one"; echo 2 > "$H/f"; git -C "$H" add -A; git -C "$H" commit -q --no-verify -m "chore: two"
MK=$H/$(git -C "$H" rev-parse --git-path tdd-gate-amend); printf 'chore: x\n' > "$T_DIR/m"
prep() { rm -f "$MK"; (cd "$H" && .githooks/prepare-commit-msg "$T_DIR/m" "$@"); }
prep commit HEAD;                             assert "source commit + HEAD marks an amend" test -e "$MK"
prep commit "$(git -C "$H" rev-parse HEAD)";  assert "source commit + HEAD's sha marks an amend" test -e "$MK"
prep commit "$(git -C "$H" rev-parse HEAD~1)"; refute "source commit + another commit (-C <other>) does not" test -e "$MK"
prep message HEAD;                            refute "another source does not" test -e "$MK"
prep;                                         refute "no source (plain commit) does not" test -e "$MK"
: > "$MK"; (cd "$H" && .githooks/prepare-commit-msg "$T_DIR/m" message); refute "a stale marker is cleared by the next commit" test -e "$MK"
: > "$MK"; (cd "$H" && .githooks/commit-msg "$T_DIR/m"); refute "commit-msg consumes the marker" test -e "$MK"

echo "the commit-msg hook is wired to the gate, for real commits"
H=$T_DIR/hooked; mkdir -p "$H/scripts" "$H/.githooks"; git -C "$H" init -q -b main
cp "$GATE" "$H/scripts/tdd-gate"; cp "$WB_SRC/.githooks/commit-msg" "$WB_SRC/.githooks/prepare-commit-msg" "$H/.githooks/"
git -C "$H" config core.hooksPath .githooks; git -C "$H" config user.email t@example.invalid; git -C "$H" config user.name t
P=home; mkdir -p "$H/$P" "$H/tests"; echo 0 > "$H/$P/a"; echo 0 > "$H/tests/a.test.sh"; git -C "$H" add -A; git -C "$H" commit -q -m "chore: init"
echo 1 >> "$H/$P/a"; git -C "$H" add $P/a
refute "a real feat! commit without a test is blocked" git -C "$H" commit -q -m "feat!: x"
refute "a real commit -a without a test is blocked" git -C "$H" commit -q -a -m "fix: x"
assert "--no-verify still skips the hook (CI is the backstop)" git -C "$H" commit -q --no-verify -m "fix: x"
echo 2 >> "$H/$P/a"; echo 2 >> "$H/tests/a.test.sh"; git -C "$H" add -A; git -C "$H" commit -q -m "fix: y"
echo 3 >> "$H/$P/a"; git -C "$H" add $P/a
assert "a real --amend that adds code to a commit with a test passes" git -C "$H" commit -q --amend --no-edit
echo 4 >> "$H/$P/a"; git -C "$H" add $P/a; git -C "$H" commit -q --no-verify -m "chore: unrelated"
echo 5 >> "$H/$P/a"; git -C "$H" add $P/a
assert "an --amend of a non-test commit retitled chore: passes" git -C "$H" commit -q --amend -m "chore: still chore"
git -C "$H" commit -q --amend --no-verify -m "fix: now a fix, no test in it"
echo 6 >> "$H/$P/a"; git -C "$H" add $P/a
refute "a real --amend of a fix that has no test is blocked" git -C "$H" commit -q --amend --no-edit
echo 7 >> "$H/$P/a"; git -C "$H" add $P/a
refute "after the amend, the next ordinary commit is judged on its own delta" git -C "$H" commit -q -m "fix: plain"
git -C "$H" reset -q --hard
git -C "$H" checkout -q -b side; echo 4 > "$H/$P/b"; git -C "$H" add -A; git -C "$H" commit -q --no-verify -m "chore: side"
git -C "$H" checkout -q main; echo 5 > "$H/$P/c"; git -C "$H" add -A; git -C "$H" commit -q --no-verify -m "chore: main"
assert "a real merge titled fix: passes" git -C "$H" merge --no-ff -q side -m "fix: merge side"

echo "CI runs the gate over the pull request's commits"
assert "the workflow calls scripts/tdd-gate --range" grep -q 'scripts/tdd-gate --range' "$WB_SRC/.github/workflows/tests.yml"
t_done
