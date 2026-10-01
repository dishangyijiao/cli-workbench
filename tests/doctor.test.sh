#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"

fixture_doctor() {
  t_fixture
  cp "$WB_SRC/scripts/doctor" "$T_REPO/scripts/" 2>/dev/null
  git -C "$T_REPO" init -q
  git -C "$T_REPO" add -A >/dev/null
  git -C "$T_REPO" -c user.name=t -c user.email=t@t commit -q -m init
}
DOCTOR() { HOME=$T_HOME "$T_REPO/scripts/doctor" --skip-check "$@"; }

echo "PATH duplicates and missing dirs are WARN"
fixture_doctor
out=$(PATH="/usr/bin:/usr/bin:/wb/does/not/exist:/bin" DOCTOR 2>&1)
assert_contains "duplicate reported" "WARN  PATH duplicate: /usr/bin" "$out"
assert_contains "missing dir reported" "WARN  PATH entry does not exist: /wb/does/not/exist" "$out"
t_cleanup

echo "dirty repo is WARN"
fixture_doctor
printf 'x\n' > "$T_REPO/untracked-file"
out=$(DOCTOR 2>&1)
assert_contains "uncommitted changes warned" "WARN  repo has uncommitted changes" "$out"
t_cleanup

echo "clean repo is PASS"
fixture_doctor
out=$(DOCTOR 2>&1)
assert_contains "clean repo passes" "PASS  repo has no uncommitted changes" "$out"
t_cleanup

echo "proxy: unset is PASS; set to a closed port is WARN, never PASS"
fixture_doctor
out=$(unset HTTP_PROXY http_proxy; DOCTOR 2>&1)
assert_contains "no proxy configured" "PASS  no proxy configured" "$out"
out=$(HTTP_PROXY=http://127.0.0.1:1 DOCTOR 2>&1)
assert_contains "closed proxy port warned" "WARN  HTTP_PROXY points at 127.0.0.1:1" "$out"
t_cleanup

echo "proxy credentials are never printed"
fixture_doctor
out=$(HTTP_PROXY=http://wbuser:wbsecret@127.0.0.1:1 DOCTOR 2>&1)
case $out in *wbsecret*|*wbuser*) t_fail "credentials leaked into doctor output";; *) t_ok "no credentials in output";; esac
assert_contains "still reports the proxy host and port" "WARN  HTTP_PROXY points at 127.0.0.1:1" "$out"
t_cleanup

echo "missing required tool is FAIL"
fixture_doctor
mkdir "$T_DIR/bin"; ln -s "$(command -v dirname)" "$T_DIR/bin/dirname"   # doctor needs only dirname to start
out=$(PATH="$T_DIR/bin" HOME=$T_HOME /bin/bash "$T_REPO/scripts/doctor" --skip-check 2>&1); rc=$?
assert_eq "exit 1" 1 "$rc"
assert_contains "git reported missing" "FAIL  git not found" "$out"
t_cleanup

echo "a copy without .git (an archive download) is not reported as a clean repository"
fixture_doctor
case $T_REPO in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_REPO/.git";; esac
out=$(DOCTOR 2>&1)
assert_contains "warns that it is not a git repository" "WARN  not a git repository" "$out"
case $out in *"PASS  repo has no uncommitted changes"*) t_fail "must not claim a clean repo without git";; *) t_ok "no false PASS";; esac
t_cleanup

echo "doctor --deep does not write into the real HOME"
fixture_doctor
mkdir -p "$T_REPO/config/zsh" "$T_REPO/config/tmux"
cp "$WB_SRC/config/zsh/zshrc" "$WB_SRC/config/zsh/path.zsh" "$T_REPO/config/zsh/"
cp "$WB_SRC/config/tmux/tmux.conf" "$T_REPO/config/tmux/"
cp "$WB_SRC/scripts/zsh-snapshot" "$T_REPO/scripts/"
( unset XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_HOME; DOCTOR --deep >/dev/null 2>&1 )
refute "no zsh cache created in HOME" test -e "$T_HOME/.cache/zsh"
refute "no nvim state created in HOME" test -e "$T_HOME/.local/state/nvim"
t_cleanup

echo "a git failure is not reported as a clean repository"
fixture_doctor
printf 'garbage' > "$T_REPO/.git/index"
out=$(DOCTOR 2>&1)
assert_contains "warns that git status failed" "WARN  git status failed" "$out"
case $out in *"PASS  repo has no uncommitted changes"*) t_fail "must not claim a clean repo when git fails";; *) t_ok "no false PASS";; esac
t_cleanup

t_done
