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
export WORKSPACE_ROOTS="$ROOT $ROOT2" WORKSPACE_SWITCH_EDITOR="" WORKSPACE_SWITCH_AGENT="" WORKSPACE_SWITCH_NO_ATTACH=1
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

echo "two simultaneous opens of different directories with the same name each get their own session"
# tmux-slownew delays new-session, so both instances see the name as free before either one creates it.
cat > "$T_DIR/bin/tmux-slownew" <<'SH'
#!/usr/bin/env bash
for a in "$@"; do if [ "$a" = new-session ]; then sleep 0.4; break; fi; done
exec tmux "$@"
SH
chmod +x "$T_DIR/bin/tmux-slownew"
mkdir -p "$T_DIR/p1/dup/.git" "$T_DIR/p2/dup/.git"
WORKSPACE_SWITCH_TMUX="$T_DIR/bin/tmux-slownew" "$PS" --open "$T_DIR/p1/dup" > "$T_DIR/res1" 2>/dev/null &
WORKSPACE_SWITCH_TMUX="$T_DIR/bin/tmux-slownew" "$PS" --open "$T_DIR/p2/dup" > "$T_DIR/res2" 2>/dev/null &
wait
res1=$(cat "$T_DIR/res1"); res2=$(cat "$T_DIR/res2")
assert "the two get different session names" test -n "$res1" -a -n "$res2" -a "$res1" != "$res2"
assert_eq "the first directory owns its session" "$T_DIR/p1/dup" "$(X show-options -qv -t "=$res1:" @project_dir)"
assert_eq "the second directory owns its session" "$T_DIR/p2/dup" "$(X show-options -qv -t "=$res2:" @project_dir)"

echo "a session made by hand (e.g. with prefix+N, no @project_dir tag) for the same directory is reused"
mkdir -p "$ROOT/byhand/.git"
X new-session -d -s byhand -c "$ROOT/byhand"
assert_eq "reuses it" "byhand" "$("$PS" --open "$ROOT/byhand")"
assert_eq "no duplicate session" 1 "$(X list-sessions -F '#S' | grep -c 'byhand')"

echo "bad input is refused"
"$PS" --open "$ROOT/nope" >/dev/null 2>&1; assert_eq "missing dir -> exit 1" 1 $?
"$PS" --bogus >/dev/null 2>&1; assert_eq "unknown option -> exit 2" 2 $?

echo "an AI CLI agent gets its own pane: editor | agent over shell"
FAKE=$T_DIR/fakebin; mkdir -p "$FAKE"
for a in fakeclaude fakecodex; do printf '#!/bin/sh\necho "AGENT-STARTED %s in $(pwd -P | sed "s#.*/##")"\nexec sleep 300\n' "$a" > "$FAKE/$a"; chmod +x "$FAKE/$a"; done
export PATH="$FAKE:$PATH"
mkdir -p "$ROOT/ag1/.git" "$ROOT/ag2/.git" "$ROOT/ag3/.git" "$ROOT/ag4/.git" "$ROOT/ag5/.git"
agent_text() { local i t; for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do t=$(X capture-pane -p -t "$1" 2>/dev/null); case $t in *AGENT-STARTED*) break;; esac; sleep 0.1; done; echo "$t"; }
WORKSPACE_SWITCH_AGENT=fakeclaude "$PS" --open "$ROOT/ag1" >/dev/null
assert_eq "three panes" 3 "$(panes '=ag1:main')"
assert_contains "the agent is started in the project directory" "AGENT-STARTED fakeclaude in ag1" "$(agent_text "$(X list-panes -t '=ag1:main' -F '#{pane_id}' | sed -n 2p)")"
assert_eq "the shell pane under it started nothing" "" "$(X capture-pane -p -t "$(X list-panes -t '=ag1:main' -F '#{pane_id}' | sed -n 3p)" | grep AGENT-STARTED)"
geo=$(X list-panes -t '=ag1:main' -F '#{pane_left} #{pane_top}' | tr '\n' ';')
assert_eq "editor left; agent and shell stacked on the right" 1 "$(echo "$geo" | awk -F';' '{split($1,e," "); split($2,a," "); split($3,s," "); print (e[1]==0 && a[1]>0 && a[1]==s[1] && s[2]>a[2]) ? 1 : 0}')"

echo "auto-detect takes the first installed candidate, in the given order"
WORKSPACE_SWITCH_AGENT=auto WORKSPACE_SWITCH_AGENTS="not-installed-x fakecodex fakeclaude" "$PS" --open "$ROOT/ag2" >/dev/null
assert_contains "second candidate chosen" "AGENT-STARTED fakecodex" "$(agent_text "$(X list-panes -t '=ag2:main' -F '#{pane_id}' | sed -n 2p)")"

echo "no candidate installed: the usual two panes"
WORKSPACE_SWITCH_AGENT=auto WORKSPACE_SWITCH_AGENTS="not-installed-x not-installed-y" "$PS" --open "$ROOT/ag3" >/dev/null
assert_eq "two panes" 2 "$(panes '=ag3:main')"

echo "an explicitly named agent that is missing is reported, not fatal"
err=$(WORKSPACE_SWITCH_AGENT="not-installed-x --flag" "$PS" --open "$ROOT/ag4" 2>&1 >/dev/null)
assert_contains "says so" "agent 'not-installed-x' is not installed" "$err"
assert_eq "two panes" 2 "$(panes '=ag4:main')"

echo "the agent can be switched off, and takes arguments"
WORKSPACE_SWITCH_AGENT=none WORKSPACE_SWITCH_AGENTS="fakeclaude" "$PS" --open "$ROOT/ag5" >/dev/null
assert_eq "none: two panes although an agent is installed" 2 "$(panes '=ag5:main')"
mkdir -p "$ROOT/ag6/.git"
WORKSPACE_SWITCH_AGENT="fakeclaude --continue" "$PS" --open "$ROOT/ag6" >/dev/null
assert_eq "a command with arguments is accepted" 3 "$(panes '=ag6:main')"

echo "a group gets an agent in every repo window"
mkdir -p "$ROOT/team/t-one/.git" "$ROOT/team/t-two/.git"
WORKSPACE_SWITCH_AGENT=fakeclaude "$PS" --open "$ROOT/team" >/dev/null
assert_eq "t-one has three panes" 3 "$(panes '=team:t-one')"
assert_eq "t-two has three panes" 3 "$(panes '=team:t-two')"

t_done
