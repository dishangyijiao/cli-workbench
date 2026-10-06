#!/usr/bin/env bash
# workspace-switch.sh — pick a workspace with fzf and open (or switch to) its tmux session.
#   workspace-switch.sh                 fzf picker, then open the choice
#   workspace-switch.sh --list          print workspaces, one per line
#   workspace-switch.sh --open DIR      open/switch to DIR's session without fzf
#   workspace-switch.sh --info DIR      one-screen summary used as the fzf preview
# A workspace is every directory directly under a root ($WORKSPACE_ROOTS, space separated; default ~/dev/projects).
#   * a git repo or a plain directory -> one session, one window: with an AI CLI agent, the agent on top (75%) and a
#     shell under it; without one, just a shell. No editor pane: prefix+e / prefix+g open Neovim in a popup instead.
#   * a group directory (not a git repo itself, but with git repos inside, e.g. my-product/)
#     -> one session rooted at the group; one window per direct git repo, each with the same panes.
#     The repo named like the group comes first. Git worktrees (a .git *file*) get no window of their own.
# Opening an existing workspace only switches to it. Creation is atomic (tmux's new-session claims the name);
# if anything fails half-way the half-built session is removed and the error is printed.
# Why not sesh/tmuxp: their group/window layouts are static config per project; the point here is that a group
# is discovered from the directory tree, with no per-project registry to maintain.
#   WORKSPACE_SWITCH_AGENT    command started in the agent pane. Unset = the first installed of WORKSPACE_SWITCH_AGENTS,
#                             none installed = no agent pane; "none" or empty = never; anything else = that command
#                             (e.g. "claude --continue"; if its program is missing, a note is printed and there is no agent pane)
#   WORKSPACE_SWITCH_AGENTS   candidates for auto-detection, in order (default: claude codex gemini grok)
#   WORKSPACE_SWITCH_SOCKET   use `tmux -L <name>` (tests)      WORKSPACE_SWITCH_NO_ATTACH=1  do not attach/switch
#   WORKSPACE_SWITCH_TMUX     tmux binary to use (tests: fault injection)
set -u
ROOTS=${WORKSPACE_ROOTS:-$HOME/dev/projects}
AGENT_CANDIDATES=${WORKSPACE_SWITCH_AGENTS:-claude codex gemini grok}
TMUX_BIN=${WORKSPACE_SWITCH_TMUX:-tmux}
NAME=$(basename "$0")

T() { if [ -n "${WORKSPACE_SWITCH_SOCKET:-}" ]; then "$TMUX_BIN" -L "$WORKSPACE_SWITCH_SOCKET" "$@"; else "$TMUX_BIN" "$@"; fi; }
die() { echo "$NAME: $*" >&2; }

list() {
  local r d
  for r in $ROOTS; do
    [ -d "$r" ] || continue
    for d in "$r"/*/; do d=${d%/}; [ -d "$d" ] && echo "$d"; done
  done
}

group_repos() {   # direct subdirectories that are git repos (a .git DIRECTORY; worktrees are skipped); the repo named like the group first
  local s g; g=$(basename "$1")
  [ -d "$1/$g/.git" ] && echo "$1/$g"
  for s in "$1"/*/; do s=${s%/}; [ "$s" = "$1/$g" ] && continue; [ -d "$s/.git" ] && echo "$s"; done
}

have() { ( PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"; command -v "$1" >/dev/null 2>&1 ); }   # a menu-launched popup may lack these

agent_cmd() {     # the agent command to start, or nothing
  local a=${WORKSPACE_SWITCH_AGENT-auto} c
  case $a in
    ""|none) ;;
    auto) for c in $AGENT_CANDIDATES; do if have "$c"; then echo "$c"; return 0; fi; done ;;
    *) if have "${a%% *}"; then echo "$a"; else die "agent '${a%% *}' is not installed; opening without an agent pane"; fi ;;
  esac
}

is_group() { [ ! -e "$1/.git" ] && [ -n "$(group_repos "$1")" ]; }

info() {
  local d=${1/#\~/$HOME} n
  echo "$d" | sed "s#^$HOME#~#"
  if is_group "$d"; then
    n=$(group_repos "$d" | wc -l | tr -d ' ')
    echo "workspace group: $n repositories"; echo
    group_repos "$d" | while read -r r; do
      printf '  %-34s %-28s uncommitted:%s\n' "$(basename "$r")" "$(git -C "$r" branch --show-current 2>/dev/null)" "$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    done
    return
  fi
  [ -e "$d/.git" ] || { echo "(plain directory)"; ls -A "$d" 2>/dev/null | head -12; return; }
  echo "branch: $(git -C "$d" branch --show-current 2>/dev/null)   uncommitted: $(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo
  git -C "$d" log -5 --format='%h %cs %s' 2>/dev/null | cut -c1-90
}

session_dir() {   # the directory a session belongs to: our @project_dir, else the session's start directory
  local d
  d=$(T show-options -qv -t "=$1:" @project_dir)
  [ -z "$d" ] && d=$(T display-message -p -t "=$1:" '#{session_path}')
  [ -n "$d" ] && (cd "$d" 2>/dev/null && pwd -P)
}

claimed_by() {    # the directory a session belongs to, once its creator has tagged it (~1 s at most); nothing if it never does
  local d
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    d=$(T show-options -qv -t "=$1:" @project_dir 2>/dev/null)
    [ -n "$d" ] && { echo "$d"; return; }
    sleep 0.1
  done
}

pick_name() {     # a session name that is free, or already belongs to this directory
  local dir=$1 base parent h cand
  base=$(basename "$dir" | tr '.:' '__'); parent=$(basename "$(dirname "$dir")" | tr '.:' '__')
  h=$(printf '%s' "$dir" | cksum | cut -d' ' -f1)
  for cand in "$base" "${parent}_${base}" "${base}_${h}"; do
    T has-session -t "=$cand" 2>/dev/null || { echo "$cand"; return; }
    [ "$(session_dir "$cand")" = "$dir" ] && { echo "$cand"; return; }
  done
  echo "${base}_${h}"
}

set_panes() {     # $1 = window id, $2 = directory: with AGENT set, the agent on top and a shell under it; else just the shell
  local top
  [ -n "$AGENT" ] || return 0
  top=$(T display-message -p -t "$1" '#{pane_id}') || return 1
  T split-window -v -l 25% -t "$top" -c "$2" || return 1
  T send-keys -t "$top" "$AGENT" Enter || return 1
  T select-pane -t "$top"
}

create_workspace() {   # $1 = dir, $2 = session name
  local dir=$1 name=$2 gname wn r wid first="" out repos
  AGENT=$(agent_cmd)
  gname=$(basename "$dir")
  if is_group "$dir"; then repos=$(group_repos "$dir"); else repos=$dir; fi
  while read -r r; do
    if [ "$r" = "$dir" ]; then wn=main
    else wn=$(basename "$r"); [ "$wn" != "$gname" ] && wn=${wn#"$gname"-}; wn=$(echo "$wn" | tr '.:' '__'); fi
    if [ -z "$first" ]; then
      if ! out=$(T new-session -d -P -F '#{window_id}' -s "$name" -c "$r" -n "$wn" 2>&1); then
        if T has-session -t "=$name" 2>/dev/null; then            # another instance claimed the name first
          [ "$(claimed_by "$name")" = "$dir" ] && return 0        # ... for this same directory: nothing left to do
          return 3                                                # ... for another directory: the caller picks a new name
        fi
        die "cannot create session '$name': $out"; return 1
      fi
      wid=$out; first=$wid
      T set-option -t "=$name:" @project_dir "$dir" || { T kill-session -t "=$name:"; die "could not tag session '$name'; removed"; return 1; }
    else
      wid=$(T new-window -d -P -F '#{window_id}' -t "=$name:" -n "$wn" -c "$r") \
        || { T kill-session -t "=$name:" 2>/dev/null; die "could not create window '$wn' in '$name'; session removed"; return 1; }
    fi
    set_panes "$wid" "$r" || { T kill-session -t "=$name:" 2>/dev/null; die "could not set up panes for '$name' ($wn); session removed"; return 1; }
  done <<< "$repos"
  T select-window -t "$first"
}

open_dir() {
  local dir=${1/#\~/$HOME} name tries=0 rc=0
  [ -d "$dir" ] || { die "no such directory: $dir"; return 1; }
  dir=$(cd "$dir" && pwd -P)
  while :; do
    name=$(pick_name "$dir")
    if T has-session -t "=$name" 2>/dev/null; then rc=0; break; fi   # pick_name returns an existing session only when it is this directory's
    create_workspace "$dir" "$name"; rc=$?
    [ "$rc" = 3 ] || break                                           # 3 = another directory took the name meanwhile: pick again
    tries=$((tries + 1)); [ "$tries" -lt 3 ] || { die "no free session name for $dir"; return 1; }
  done
  [ "$rc" = 0 ] || return 1
  [ "${WORKSPACE_SWITCH_NO_ATTACH:-0}" = 1 ] && { echo "$name"; return 0; }
  if [ -n "${TMUX:-}" ]; then T switch-client -t "=$name"; else T attach-session -t "=$name"; fi
}

pick() {
  command -v fzf >/dev/null || { die "fzf is required"; return 1; }
  local sel
  sel=$(list | sed "s#^$HOME#~#" | fzf --prompt='workspace> ' --height=100% --reverse \
        --preview "'$0' --info {}" --preview-window=right:55%) || return 0
  [ -n "$sel" ] && open_dir "$sel"
}

case "${1:-}" in
  --list) list ;;
  --info) info "${2:?dir}" ;;
  --open) open_dir "${2:?dir}" ;;
  "") pick ;;
  *) echo "usage: $NAME [--list | --open DIR | --info DIR]" >&2; exit 2 ;;
esac
