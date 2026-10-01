#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v tmux >/dev/null; then echo "tmux not installed; skipped"; exit 0; fi
PS="$WB_SRC/home/dot_tmux/scripts/executable_workspace-switch.sh"

T_DIR=$(cd -P "$(mktemp -d)" && pwd)
export HOME=$T_DIR/home; mkdir -p "$HOME"                      # no ~/.tmux.conf, no real projects
ROOT=$T_DIR/projects; ROOT2=$T_DIR/other
mkdir -p "$ROOT/alpha/.git" "$ROOT/dotted.name/.git" "$ROOT/plain" "$ROOT2/alpha/.git"
mkdir -p "$ROOT/group/beta/.git" "$ROOT/group/group-api/.git" "$ROOT/group/notes"
mkdir -p "$ROOT/group/wt"; echo "gitdir: /elsewhere" > "$ROOT/group/wt/.git"      # a worktree: .git is a file
mkdir -p "$ROOT/mono/mono-a/.git" "$ROOT/mono/mono/.git"                                  # main repo is named like the group
export WORKSPACE_ROOTS="$ROOT $ROOT2" WORKSPACE_SWITCH_EDITOR="" WORKSPACE_SWITCH_NO_ATTACH=1
export WORKSPACE_SWITCH_SOCKET=wbtest$$
unset TMUX
cleanup() { tmux -L "$WORKSPACE_SWITCH_SOCKET" kill-server 2>/dev/null; case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac; }
trap cleanup EXIT
X() { tmux -L "$WORKSPACE_SWITCH_SOCKET" "$@"; }
panes()    { X list-panes -t "$1" 2>/dev/null | wc -l | tr -d ' '; }
windows()  { X list-windows -t "=$1" -F '#{window_name}' 2>/dev/null | tr '\n' ' '; }
sessions() { X list-sessions -F '#S' 2>/dev/null | sort | tr '\n' ' '; }
panepath() { local i p; for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do p=$(X list-panes -t "$1" -F '#{pane_current_path}' | head -1); [ -n "$p" ] && [ "$p" != "$HOME" ] && break; sleep 0.1; done; echo "$p"; }

echo "every directory directly under a root is a workspace; nothing deeper is listed"
out=$("$PS" --list | sed "s#^$T_DIR/##" | sort | tr '\n' ' ')
assert_eq "list" "other/alpha projects/alpha projects/dotted.name projects/group projects/mono projects/plain " "$out"

echo "a repo: one session, one window, two panes"
name=$("$PS" --open "$ROOT/alpha")
assert_eq "session name" "alpha" "$name"
assert_eq "one window" "main " "$(windows alpha)"
assert_eq "two panes" 2 "$(panes '=alpha:main')"

echo "opening it again changes nothing"
"$PS" --open "$ROOT/alpha" >/dev/null
assert_eq "still one session" "alpha " "$(sessions)"
assert_eq "still two panes" 2 "$(panes '=alpha:main')"

echo "a dot in the name is mapped to an underscore"
assert_eq "session name" "dotted_name" "$("$PS" --open "$ROOT/dotted.name")"

echo "a plain directory is a workspace too"
assert_eq "session name" "plain" "$("$PS" --open "$ROOT/plain")"
assert_eq "one window" "main " "$(windows plain)"

echo "two workspaces with the same basename get different sessions"
assert_eq "second alpha is prefixed by its parent dir" "other_alpha" "$("$PS" --open "$ROOT2/alpha")"
assert_eq "first alpha untouched" 2 "$(panes '=alpha:main')"

echo "a group directory is ONE workspace: a window per repo, worktrees and non-repos skipped"
assert_eq "session name" "group" "$("$PS" --open "$ROOT/group")"
assert_eq "windows" "beta api " "$(windows group)"
assert_eq "beta has two panes" 2 "$(panes '=group:beta')"
assert_eq "api has two panes" 2 "$(panes '=group:api')"
assert_eq "api window starts in its own repo" "$ROOT/group/group-api" "$(panepath '=group:api')"
assert_eq "opening the group again adds nothing" "beta api " "$( "$PS" --open "$ROOT/group" >/dev/null; windows group)"

echo "in a group, the repo named like the group comes first"
assert_eq "session name" "mono" "$("$PS" --open "$ROOT/mono")"
assert_eq "main repo window first" "mono a " "$(windows mono)"

echo "a failure half-way rolls the session back (no half-built session is left behind)"
mkdir -p "$ROOT/rb/.git" "$T_DIR/bin"
cat > "$T_DIR/bin/tmux-failsplit" <<'SH'
#!/usr/bin/env bash
for a in "$@"; do [ "$a" = split-window ] && exit 1; done
exec tmux "$@"
SH
chmod +x "$T_DIR/bin/tmux-failsplit"
err=$(WORKSPACE_SWITCH_TMUX="$T_DIR/bin/tmux-failsplit" "$PS" --open "$ROOT/rb" 2>&1 >/dev/null); rc=$?
assert_eq "exit 1" 1 "$rc"
assert_contains "says what failed" "rb" "$err"
assert_eq "no session left" "" "$(X has-session -t '=rb:' 2>/dev/null && echo yes)"
assert_eq "a later open works" 2 "$("$PS" --open "$ROOT/rb" >/dev/null; panes '=rb:main')"

echo "names that collide on the same basename AND the same parent still get distinct sessions"
mkdir -p "$T_DIR/x/other/alpha/.git"
name3=$("$PS" --open "$T_DIR/x/other/alpha")
assert_contains "third alpha gets a hash suffix" "alpha_" "$name3"
[ "$name3" != "alpha" ] && [ "$name3" != "other_alpha" ]; assert_eq "distinct from the first two" 0 $?

echo "a.b and a_b are different workspaces"
mkdir -p "$ROOT/ab.c/.git" "$ROOT/ab_c/.git"
n1=$("$PS" --open "$ROOT/ab.c"); n2=$("$PS" --open "$ROOT/ab_c")
[ "$n1" != "$n2" ]; assert_eq "different sessions" 0 $?

echo "two simultaneous opens of the same new workspace create it once"
mkdir -p "$ROOT/conc/.git"
"$PS" --open "$ROOT/conc" >/dev/null 2>&1 & "$PS" --open "$ROOT/conc" >/dev/null 2>&1 & wait
assert_eq "one window" "main " "$(windows conc)"
assert_eq "two panes" 2 "$(panes '=conc:main')"

echo "a session made by hand (e.g. with prefix+N, no @project_dir tag) for the same directory is reused"
mkdir -p "$ROOT/byhand/.git"
X new-session -d -s byhand -c "$ROOT/byhand"
assert_eq "reuses it" "byhand" "$("$PS" --open "$ROOT/byhand")"
assert_eq "no duplicate session" 1 "$(X list-sessions -F '#S' | grep -c 'byhand')"

echo "bad input is refused"
"$PS" --open "$ROOT/nope" >/dev/null 2>&1; assert_eq "missing dir -> exit 1" 1 $?
"$PS" --bogus >/dev/null 2>&1; assert_eq "unknown option -> exit 2" 2 $?

t_done
