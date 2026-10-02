#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"

# A throwaway git repo with the scanner and the hooks copied in. Sets R (repo) and DENY (a deny-list path that does not exist yet).
mkrepo() {
  T_DIR=$(cd -P "$(mktemp -d)" && pwd); R=$T_DIR/repo; DENY=$T_DIR/deny.txt
  mkdir -p "$R/scripts" "$R/.githooks"
  cp "$WB_SRC/scripts/privacy-scan" "$WB_SRC/scripts/lint-shell" "$R/scripts/" 2>/dev/null
  cp "$WB_SRC/.githooks/pre-commit" "$R/.githooks/" 2>/dev/null
  cp "$WB_SRC/.githooks/pre-push" "$R/.githooks/" 2>/dev/null
  git -C "$R" init -q 2>/dev/null
  git -C "$R" config user.name t; git -C "$R" config user.email t@example.com
  git -C "$R" config core.hooksPath .githooks
}
scan() { (cd "$R" && WB_DENY_FILE=$DENY scripts/privacy-scan "$@" 2>&1); }
# Test values are assembled from parts so this file never contains a real-looking secret itself.
KEY="sk-""abcdefghijklmnopqrstuvwxyz0123456789"
GH="ghp_""abcdefghijklmnopqrstuvwxyz0123456789"
AWS="AKIA""ABCDEFGHIJKLMNOP"
ANT="sk-ant-""api03-abcdefghijklmnopqrstuvwxyz0123456789"      # Claude
GOOG="AIza""SyAbcdefghijklmnopqrstuvwxyz0123456789"           # Gemini
XAI="xai-""abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123456789"     # Grok
PEM="-----BEGIN RSA PRIVATE"" KEY-----"
HOMEPATH="/Users/""alice/.local/bin"

echo "a clean repo passes in both modes"
mkrepo; printf 'export EDITOR=vim\nalias ll="ls -l"\n' > "$R/zshrc"; git -C "$R" add -A
scan --all >/dev/null; assert_eq "--all exits 0" 0 $?
scan --staged >/dev/null; assert_eq "--staged exits 0" 0 $?
t_cleanup

echo "the chezmoi source tree (home/dot_*) is not mistaken for a personal path"
mkrepo; mkdir -p "$R/home"; printf 'x\n' > "$R/home/dot_zshrc"; printf 'cp home/dot_zshrc ~/.zshrc\nsrc=$ROOT/home/dot_tmux.conf\n' > "$R/notes.sh"; git -C "$R" add -A
scan --all >/dev/null; assert_eq "home/dot_* paths pass" 0 $?
t_cleanup

echo "each kind of leak is caught, named, and never echoed"
check_rule() { # description, line-to-write, expected rule name, secret fragment that must NOT appear in the output
  mkrepo; printf '%s\n' "$2" > "$R/zshrc"; git -C "$R" add -A
  out=$(scan --staged); rc=$?
  assert_eq "$1: exit 1" 1 "$rc"
  assert_contains "$1: names the rule" "$3" "$out"
  assert_contains "$1: points at the file" "zshrc:1" "$out"
  case $out in *"$4"*) t_fail "$1: the output leaked the value";; *) t_ok "$1: the value is not printed";; esac
  t_cleanup
}
check_rule "API key"        "export OPENAI_API_KEY=$KEY"            "secret-token"  "$KEY"
check_rule "Anthropic key (Claude)" "export ANTHROPIC_API_KEY=$ANT"   "secret-token"  "$ANT"
check_rule "Google key (Gemini)"    "export GEMINI_API_KEY=$GOOG"    "secret-token"  "$GOOG"
check_rule "xAI key (Grok)"         "export XAI_API_KEY=$XAI"        "secret-token"  "$XAI"
check_rule "GitHub token"   "export GH=$GH"                          "secret-token"  "$GH"
check_rule "AWS key id"     "aws=$AWS"                               "secret-token"  "$AWS"
check_rule "private key"    "$PEM"                                   "private-key"   "PRIVATE"
check_rule "assigned secret" 'DB_PASSWORD="hunter2hunter2hunter2"'   "secret-assign" "hunter2"
check_rule "home path"      "export PATH=$HOMEPATH:\$PATH"           "home-path"     "alice"
check_rule "email address"  "contact bob@corp-internal.io"           "email"         "bob@corp"

echo "things that look similar but are fine"
mkrepo
printf '%s\n' 'export API_KEY="$(op read op://vault/item/key)"' 'export TOKEN=$MY_TOKEN' 'API_KEY=your-key-here-xxxxxxxxxxxx' \
  'git clone git@github.com:someone/repo.git' 'Author: dev <dev@users.noreply.github.com>' 'mail me@example.com' \
  "token=$KEY # wb-scan: allow" 'PATH=/home/linuxbrew/.linuxbrew/bin' > "$R/ok.sh"
git -C "$R" add -A; scan --staged >/dev/null; assert_eq "variable refs, placeholders, noreply, example.com, allow marker pass" 0 $?
t_cleanup

echo "sensitive file names are refused even when empty, but .env.example is fine"
for f in .env server.pem id_ed25519 prod.key; do
  mkrepo; : > "$R/$f"; git -C "$R" add -f "$f"; out=$(scan --staged); rc=$?
  assert_eq "$f is refused" 1 "$rc"; t_cleanup
done
mkrepo; printf 'FOO=bar\n' > "$R/.env.example"; git -C "$R" add -f .env.example; scan --staged >/dev/null; assert_eq ".env.example is allowed" 0 $?; t_cleanup

echo "--staged looks only at what is about to be committed"
mkrepo; printf 'fine\n' > "$R/a"; git -C "$R" add a; git -C "$R" commit -q --no-verify -m init
printf 'export K=%s\n' "$KEY" > "$R/b"                      # untracked and unstaged
scan --staged >/dev/null; assert_eq "an unstaged secret does not block" 0 $?
git -C "$R" add b; scan --staged >/dev/null; assert_eq "the same file once staged does" 1 $?
t_cleanup

echo "the personal deny list (kept outside the repo)"
mkrepo; printf 'built for Acme-Secret-Project\n' > "$R/notes"; git -C "$R" add -A
scan --staged >/dev/null; assert_eq "no deny file: nothing to match, passes" 0 $?
printf '# my names\n\nacme-secret-project\n' > "$DENY"
out=$(scan --staged); rc=$?
assert_eq "a denied word is caught, case-insensitively" 1 "$rc"
assert_contains "names the rule" "deny-list" "$out"
case $out in *"Acme-Secret"*) t_fail "the denied word was printed";; *) t_ok "the denied word is not printed";; esac
t_cleanup

echo "--commits scans commit metadata (author, committer, message) instead of files"
mkrepo; git -C "$R" commit -q --no-verify --allow-empty -m clean
out=$(scan --commits HEAD); rc=$?
assert_eq "clean metadata passes" 0 "$rc"
assert_contains "a missing deny list warns" "no deny list" "$out"
git -C "$R" -c user.email=alice@private.dev commit -q --no-verify --allow-empty -m "identity is the author's choice"
scan --commits HEAD >/dev/null; assert_eq "a commit's own address is not policed" 0 $?
t_cleanup

echo "private words in commit metadata come from the deny list"
mkrepo; printf 'bob@corp-internal.io\n' > "$DENY"
git -C "$R" -c user.email=bob@corp-internal.io commit -q --no-verify --allow-empty -m "using the work address"
out=$(scan --commits HEAD); rc=$?
assert_eq "a denied address in the author metadata is caught" 1 "$rc"
assert_contains "names the rule" "deny-list" "$out"
assert_contains "points at the commit" "$(git -C "$R" rev-parse --short HEAD):" "$out"
case $out in *"bob@corp"*) t_fail "the address was printed";; *) t_ok "the address is not printed";; esac
t_cleanup

echo "secrets pasted into a commit message are caught"
mkrepo
git -C "$R" commit -q --no-verify --allow-empty -m "rotate: the old key was $KEY"
out=$(scan --commits HEAD); rc=$?
assert_eq "a token in a message is caught" 1 "$rc"
assert_contains "names the rule" "secret-token" "$out"
case $out in *"$KEY"*) t_fail "the message token was printed";; *) t_ok "the message token is not printed";; esac
t_cleanup
mkrepo
git -C "$R" commit -q --no-verify --allow-empty -m "logs live in $HOMEPATH now"
scan --commits HEAD >/dev/null; assert_eq "a personal path in a message is caught" 1 $?
t_cleanup

echo "the pre-push hook blocks a push whose commit metadata leaks"
mkrepo
git -C "$R" init -q --bare "$T_DIR/remote.git"
git -C "$R" remote add origin "$T_DIR/remote.git"
printf 'bob@corp-internal.io\n' > "$DENY"
git -C "$R" -c user.email=bob@corp-internal.io commit -q --no-verify --allow-empty -m "using the work address"
out=$(cd "$R" && WB_DENY_FILE=$DENY git push origin HEAD 2>&1); rc=$?
assert_eq "the push is refused" 1 "$rc"
assert_eq "the remote received nothing" 0 "$(git -C "$T_DIR/remote.git" rev-list --all --count)"
assert_contains "says how to fix it" "privacy-scan" "$out"
git -C "$R" commit -q --no-verify --allow-empty --amend --reset-author -m clean
(cd "$R" && WB_DENY_FILE=$DENY git push -q origin HEAD >/dev/null 2>&1); assert_eq "a clean push goes through" 0 $?
t_cleanup

echo "the pre-commit hook blocks the commit"
mkrepo; printf 'export K=%s\n' "$KEY" > "$R/leak"; git -C "$R" add -A
out=$(cd "$R" && WB_DENY_FILE=$DENY git commit -m leak 2>&1); rc=$?
assert_eq "git commit fails" 1 "$rc"
assert_eq "nothing was committed" 0 "$(git -C "$R" rev-list --all --count 2>/dev/null | head -1)"
assert_contains "the message says how to fix it" "privacy-scan" "$out"
printf 'export K=1\n' > "$R/leak"; git -C "$R" add -A
(cd "$R" && WB_DENY_FILE=$DENY git commit -q -m ok >/dev/null 2>&1); assert_eq "a clean commit goes through" 0 $?
t_cleanup

echo "--all scans every tracked file"
mkrepo; printf 'x\n' > "$R/a"; printf 'p=%s\n' "$HOMEPATH" > "$R/b"; git -C "$R" add -A; git -C "$R" commit -q --no-verify -m init
scan --all >/dev/null; assert_eq "finds a leak that is already committed" 1 $?
t_cleanup
t_done
