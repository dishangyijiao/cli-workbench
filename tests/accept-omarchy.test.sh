#!/usr/bin/env bash
# Contract and Linux integration tests for the disposable Omarchy verifier.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
ACCEPT="$WB_SRC/scripts/accept-omarchy"

echo 'the workstation acceptance runner has a stable interface'
assert 'Bash syntax is valid' bash -n "$ACCEPT"
out=$(bash "$ACCEPT" --help 2>&1); rc=$?
assert_eq 'help succeeds' 0 "$rc"
assert_contains 'headless mode described' '--headless' "$out"
assert_contains 'desktop mode described' '--desktop' "$out"
bash "$ACCEPT" --invalid >/dev/null 2>&1
assert_eq 'unsupported flag exits 2' 2 "$?"
bash "$ACCEPT" --headless --desktop >/dev/null 2>&1
assert_eq 'multiple modes refused' 2 "$?"

if [ "$(uname -s)" = Linux ] && command -v chezmoi >/dev/null 2>&1 &&
   command -v zsh >/dev/null 2>&1 && command -v tmux >/dev/null 2>&1 &&
   command -v jq >/dev/null 2>&1 && command -v diff >/dev/null 2>&1 &&
   command -v cmp >/dev/null 2>&1; then
  echo 'headless mode exercises a fresh disposable workbench on Linux'
  out=$(bash "$ACCEPT" --headless 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" | tail -25; fi
  assert_eq 'headless acceptance passes' 0 "$rc"
  assert_contains 'chezmoi target is disposable' 'PASS  chezmoi deployment to disposable HOME' "$out"
  assert_contains 'Linux Ghostty render is validated' 'PASS  Ghostty rendered for Linux' "$out"
  assert_contains 'isolated tmux server started' 'PASS  isolated tmux server started' "$out"
  assert_contains 'tmux opener is checked' 'PASS  tmux Linux URL opener' "$out"
  assert_contains 'explicit pass summary is emitted' 'RESULT: PASS' "$out"
else
  echo 'skip Linux integration: platform or dependency unavailable'
fi
t_done
