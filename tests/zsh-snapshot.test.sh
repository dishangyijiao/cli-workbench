#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v zsh >/dev/null; then echo "zsh not installed; skipped"; exit 0; fi
SNAP="$WB_SRC/scripts/zsh-snapshot"
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
H=$T_DIR/home; mkdir -p "$H"
RC=$T_DIR/zshrc
snap() { HOME=$H "$SNAP" "$@"; }
section() { awk -v s="== $1" '$0==s{f=1;next} /^== /{f=0} f' ; }   # print one section from stdin

echo "captures aliases, functions, PATH, env"
cat > "$RC" <<'EOF'
alias wbfoo='echo bar'
wbfunc() { :; }
export WB_TEST_VAR=hello
path=(/wb/test/dir $path)
EOF
out=$(snap "$RC" 2>&1); rc=$?
assert_eq "exit 0" 0 "$rc"
assert_contains "alias present" "wbfoo" "$out"
assert_contains "function present" "wbfunc" "$out"
assert_contains "env var present" "WB_TEST_VAR=hello" "$out"
assert_contains "path entry present" "/wb/test/dir" "$out"

echo "canonical start: the caller's PATH never leaks in"
printf 'true\n' > "$RC"
out=$(PATH="/wb/caller/bin:$PATH" snap "$RC" 2>&1)
case $out in *"/wb/caller/bin"*) t_fail "caller PATH leaked into the snapshot";; *) t_ok "caller PATH did not leak";; esac
assert_contains "system PATH present" "/usr/bin" "$(printf '%s\n' "$out" | section path)"

echo "login files: the real ~/.zshenv and ~/.zprofile are read"
printf 'export WB_ZSHENV=1\n' > "$H/.zshenv"
printf 'export WB_ZPROFILE=1\n' > "$H/.zprofile"
out=$(snap "$RC" 2>&1)
assert_contains ".zshenv read" "WB_ZSHENV=1" "$out"
assert_contains ".zprofile read" "WB_ZPROFILE=1" "$out"
rm -f "$H/.zshenv" "$H/.zprofile"

echo "compdump files are seeded into the private ZDOTDIR (warm compinit)"
: > "$H/.zcompdump-wbtest"
printf 'ls -A "$ZDOTDIR"\n' > "$RC"
out=$(snap "$RC" 2>&1)
assert_contains "dump copied" ".zcompdump-wbtest" "$out"
rm -f "$H/.zcompdump-wbtest"

echo "a compinit lock DIRECTORY among the compdump files does not break the snapshot"
mkdir "$H/.zcompdump-wbtest.lock"
out=$(snap "$RC" 2>&1); rc=$?
assert_eq "exit 0" 0 "$rc"
assert_contains "snapshot still produced" "== path" "$out"
rmdir "$H/.zcompdump-wbtest.lock"

echo "alias -g / -s definitions are captured in full"
cat > "$RC" <<'EOF'
alias -g WBG='| cat'
alias -s wbx=cat
EOF
out=$(snap "$RC" 2>&1)
assert_contains "global alias" "alias -g WBG=" "$out"
assert_contains "suffix alias" "alias -s wbx=" "$out"

echo "function bodies are hashed, so a body change is visible"
printf 'wbfunc() { echo one; }\n' > "$RC"; a=$(snap "$RC" 2>&1 | grep '^wbfunc ')
printf 'wbfunc() { echo two; }\n' > "$RC"; b=$(snap "$RC" 2>&1 | grep '^wbfunc ')
assert "hash lines exist" test -n "$a"
assert "hashes differ when the body differs" test "$a" != "$b"

echo "completions show key AND value"
cat > "$RC" <<'EOF'
autoload -Uz compinit
compinit -u -d "$ZDOTDIR/wbdump"
compdef _files wbcmd
EOF
out=$(snap "$RC" 2>&1)
assert_contains "comp key and function" "wbcmd _files" "$out"

echo "setopt, bindkey and zstyle are captured"
cat > "$RC" <<'EOF'
setopt rmstarsilent
bindkey '^X^W' backward-kill-word
zstyle ':wb:test' key val
EOF
out=$(snap "$RC" 2>&1)
assert_contains "setopt" "rmstarsilent" "$out"
assert_contains "bindkey" "^X^W" "$out"
assert_contains "zstyle" ":wb:test" "$out"

echo "resolution: names from PATH dirs, extra names, and UNRESOLVED"
mkdir -p "$T_DIR/bin"; printf '#!/bin/sh\n' > "$T_DIR/bin/wbtool"; chmod +x "$T_DIR/bin/wbtool"
printf 'path=(%s $path)\n' "$T_DIR/bin" > "$RC"
printf 'wb-nonexistent\n' > "$T_DIR/names"
out=$(snap "$RC" --names "$T_DIR/names" 2>&1)
res=$(printf '%s\n' "$out" | section resolution)
assert_contains "own PATH executable resolved" "$(printf 'wbtool\t%s/bin/wbtool' "$T_DIR")" "$res"
assert_contains "extra name is UNRESOLVED" "$(printf 'wb-nonexistent\tUNRESOLVED')" "$res"

echo "isolation: git config --global and ssh-agent cannot touch real state"
cat > "$RC" <<'EOF'
git config --global wbsnapshot.probe yes
[ -z "$SSH_AUTH_SOCK" ] && echo AGENT_WOULD_START
EOF
out=$(snap "$RC" 2>&1)
refute "real ~/.gitconfig not created" test -e "$H/.gitconfig"
case $out in *AGENT_WOULD_START*) t_fail "SSH_AUTH_SOCK must be preset";; *) t_ok "SSH_AUTH_SOCK preset";; esac

echo "non-zero exit is propagated"
printf 'exit 3\n' > "$RC"
snap "$RC" >/dev/null 2>&1; rc=$?
assert "non-zero" test "$rc" -ne 0

echo "volatile values do not make snapshots differ (starship key, proxy variables)"
cat > "$RC" <<'EOF'
export STARSHIP_SESSION_KEY=$RANDOM$RANDOM
export HTTP_PROXY=http://127.0.0.1:$RANDOM
EOF
a=$(snap "$RC" 2>&1); b=$(snap "$RC" 2>&1)
assert_eq "identical across runs" "$a" "$b"

echo "same input -> identical output"
printf 'alias a=b\n' > "$RC"
a=$(snap "$RC" 2>&1); b=$(snap "$RC" 2>&1)
assert_eq "deterministic" "$a" "$b"

echo "--time and --zprof"
out=$(snap "$RC" --time 3 2>&1)
assert_contains "median printed" "median_ms" "$out"
assert_contains "three samples" "samples 3" "$out"
out=$(snap "$RC" --zprof 2>&1)
assert_contains "zprof report" "calls" "$out"

echo "--pty (skipped where a pty cannot be allocated)"
out=$(snap "$RC" --pty 2>&1); rc=$?
if [ "$rc" = 3 ] || case $out in *PTY_UNAVAILABLE*) true;; *) false;; esac; then
  t_ok "pty unavailable here (skipped)"
else
  assert_contains "pty lane produced sections" "== resolution" "$out"
fi

case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac
t_done
