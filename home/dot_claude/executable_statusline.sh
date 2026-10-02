#!/bin/sh
# Claude Code status line, two lines:
#
#   project ⎇ branch !changed ?untracked
#   Model · effort · ctx NN% · 3h12m · $4.22 · 5h NN% · 7d NN%
#
# Claude Code runs this on every refresh and writes the session as JSON to stdin.
# Fields used (see statusline.test.sh for the payload shape):
#   workspace.project_dir  project root of the session (the project name comes from here,
#                          so cd-ing into a subdirectory does not change it)
#   workspace.current_dir  current directory (the branch comes from here); cwd is the fallback
#   model.display_name, effort.level
#   context_window.used_percentage
#   cost.total_duration_ms, cost.total_cost_usd
#   rate_limits.five_hour / seven_day .used_percentage
#
# Rules: never print error text, always exit 0, and leave out any segment whose field is missing.
# Tests: sh ~/.claude/statusline.test.sh
#
# Environment (mainly for the tests):
#   STATUSLINE_CACHE_TTL  seconds to cache the git counters per directory (default 5, 0 = off)
#   STATUSLINE_CACHE_DIR  where the cache lives (default $TMPDIR/claude-statusline-<uid>)

# When started from a GUI or IDE, PATH may not include Homebrew.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

input=$(cat)

# One jq call for everything (this script runs on every refresh). One field per line,
# already formatted; a missing field becomes an empty line and its segment is left out below.
fields=$(printf '%s' "$input" | jq -r '
  def pct: if . == null then "" else (. + 0.5 | floor | tostring) end;
  def pad2: tostring | if length < 2 then "0" + . else . end;
  def dur: if . == null then "" else
    (. / 60000 | floor) as $m
    | if $m >= 60 then "\($m / 60 | floor)h\($m % 60 | pad2)m" else "\($m)m" end
    end;
  def usd: if . == null then "" else
    (. * 100 + 0.5 | floor) as $c | "$\($c / 100 | floor).\($c % 100 | pad2)"
    end;
  (.workspace.project_dir // .workspace.current_dir // .cwd // ""),
  (.workspace.current_dir // .cwd // .workspace.project_dir // ""),
  (.model.display_name // ""),
  (.effort.level // ""),
  (.context_window.used_percentage | pct),
  (.cost.total_duration_ms | dur),
  (.cost.total_cost_usd | usd),
  (.rate_limits.five_hour.used_percentage | pct),
  (.rate_limits.seven_day.used_percentage | pct)' 2>/dev/null)
{
  IFS= read -r project_dir
  IFS= read -r current_dir
  IFS= read -r model
  IFS= read -r effort
  IFS= read -r ctx
  IFS= read -r duration
  IFS= read -r cost
  IFS= read -r five_hour
  IFS= read -r seven_day
} <<EOF
$fields
EOF

[ -n "$current_dir" ] || current_dir=$(pwd)
[ -n "$project_dir" ] || project_dir=$current_dir
project=$(basename "$project_dir")

# Text that comes from disk or from a path (a directory name, a branch, a cache entry) is printed to the terminal, so it must not
# be able to carry escape sequences: drop every ASCII control character (octal, so it does not depend on the locale).
plain() { printf '%s' "$1" | tr -d '\000-\037\177'; }
project=$(plain "$project")

# ---- git: "<branch> <changed> <untracked>", or nothing outside a repository ----
# --no-optional-locks: do not take the index lock, so this never conflicts with git
# commands that Claude Code is running. A detached HEAD shows the short hash.
git_info() {
  b=$(git -C "$1" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) \
    || b=$(git -C "$1" --no-optional-locks rev-parse --short HEAD 2>/dev/null) \
    || return 0
  counts=$(git -C "$1" --no-optional-locks status --porcelain=v1 2>/dev/null \
    | awk '/^\?\?/ { u++; next } NF { c++ } END { print c + 0, u + 0 }')
  printf '%s %s' "$b" "${counts:-0 0}"
}

ttl=${STATUSLINE_CACHE_TTL:-5}
case $ttl in '' | *[!0-9]*) ttl=5 ;; esac

# $XDG_RUNTIME_DIR is private to the user (Linux); macOS's $TMPDIR is too. In a shared /tmp another user could have created the
# directory first, so the cache is used only when the directory is ours and not a symlink; otherwise it is left out.
cache_dir=${STATUSLINE_CACHE_DIR:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-$(id -u)}
if [ -L "$cache_dir" ] || { [ -e "$cache_dir" ] && { [ ! -d "$cache_dir" ] || [ ! -O "$cache_dir" ]; }; }; then ttl=0; fi

info=""
hit=""
if [ "$ttl" -gt 0 ]; then
  key=$(printf '%s' "$current_dir" | cksum | cut -d' ' -f1)
  cache_file="$cache_dir/$key"
  if [ -f "$cache_file" ]; then
    mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    now=$(date +%s)
    if [ -n "$mtime" ] && [ $((now - mtime)) -lt "$ttl" ]; then
      info=$(cat "$cache_file" 2>/dev/null)
      hit=1
    fi
  fi
fi
if [ -z "$hit" ]; then
  info=$(git_info "$current_dir")
  if [ "$ttl" -gt 0 ]; then
    # Check again after mkdir: another user may have created the directory between the check above and here, and a
    # directory that is not ours could hold a symlink named like the cache file.
    (umask 077 && mkdir -p "$cache_dir" && [ ! -L "$cache_dir" ] && [ -O "$cache_dir" ] && printf '%s' "$info" > "$cache_file") 2>/dev/null
  fi
fi

branch=$(plain "${info%% *}")
rest=${info#* }
changed=${rest%% *}
untracked=${rest#* }
[ -n "$info" ] || { branch=""; changed=0; untracked=0; }
# The two counters come from the same cache entry: anything that is not a plain number counts as 0.
case $changed in '' | *[!0-9]*) changed=0 ;; esac
case $untracked in '' | *[!0-9]*) untracked=0 ;; esac

# ---- colors ----
c() { printf '\033[%sm' "$1"; }
reset=$(c 0)
blue=$(c '1;34')
green=$(c 32)
yellow=$(c 33)
red=$(c 31)
dim=$(c 2)

# Usage colors: green below 60%, yellow from 60%, red from 85%.
level() {
  if [ "$1" -ge 85 ]; then printf '%s' "$red"
  elif [ "$1" -ge 60 ]; then printf '%s' "$yellow"
  else printf '%s' "$green"
  fi
}

# ---- line 1: project ⎇ branch !changed ?untracked ----
line1="${blue}${project}${reset}"
if [ -n "$branch" ]; then
  line1="${line1} ${green}⎇ ${branch}${reset}"
  [ "$changed" -gt 0 ] 2>/dev/null && line1="${line1} ${yellow}!${changed}${reset}"
  [ "$untracked" -gt 0 ] 2>/dev/null && line1="${line1} ${dim}?${untracked}${reset}"
fi

# ---- line 2: model · effort · ctx · duration · cost · 5h · 7d ----
sep="${dim} · ${reset}"
line2=""
add() { [ -n "$1" ] && { if [ -n "$line2" ]; then line2="${line2}${sep}$1"; else line2="$1"; fi; }; }

add "$model"
[ -n "$effort" ] && add "${dim}${effort}${reset}"
[ -n "$ctx" ] && add "$(level "$ctx")ctx ${ctx}%${reset}"
[ -n "$duration" ] && add "${dim}${duration}${reset}"
[ -n "$cost" ] && add "${dim}${cost}${reset}"
[ -n "$five_hour" ] && add "$(level "$five_hour")5h ${five_hour}%${reset}"
[ -n "$seven_day" ] && add "$(level "$seven_day")7d ${seven_day}%${reset}"

printf '%s' "$line1"
[ -n "$line2" ] && printf '\n%s' "$line2"
exit 0
