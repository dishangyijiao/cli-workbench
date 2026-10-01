#!/bin/sh
# Tests for statusline.sh (the source file under home/dot_claude).   Run:  sh tests/statusline.test.sh
#
# Fixtures are synthetic Claude Code payloads (context 48%, 5h 52%, 7d 8%, 11520000 ms, $4.2183).
# Git state comes from throwaway repositories under a temp dir.

SCRIPT="${STATUSLINE_SCRIPT:-$(cd "$(dirname "$0")/.." && pwd)/home/dot_claude/executable_statusline.sh}"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
ESC=$(printf '\033')
fail=0
count=0

strip() { sed "s/${ESC}\[[0-9;]*m//g"; }

# run <json>            -> plain text output (colors removed), cache disabled
run() { printf '%s' "$1" | STATUSLINE_CACHE_TTL=0 sh "$SCRIPT" 2>&1 | strip; }
# run_raw <json>        -> output with color codes, cache disabled
run_raw() { printf '%s' "$1" | STATUSLINE_CACHE_TTL=0 sh "$SCRIPT" 2>&1; }

check() { # check <name> <want> <got>
  count=$((count + 1))
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    fail=$((fail + 1))
    echo "FAIL $1"
    printf '  want: %s\n  got:  %s\n' "$2" "$3"
  fi
}

NL='
'

# ---- fixtures ----
make_repo() { # make_repo <name>  -> path of a repo on branch main with one commit
  d="$T/$1"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  echo base > "$d/tracked"
  git -C "$d" add tracked
  git -C "$d" -c user.email=t@t -c user.name=t commit -q -m init
  echo "$d"
}

payload() { # payload <dir> [extra jq object merged in]
  jq -n --arg d "$1" '{
    cwd: $d,
    workspace: {current_dir: $d, project_dir: $d},
    model: {display_name: "Sonnet 5.5"},
    effort: {level: "medium"},
    cost: {total_cost_usd: 4.2183, total_duration_ms: 11520000},
    context_window: {used_percentage: 48},
    rate_limits: {five_hour: {used_percentage: 52}, seven_day: {used_percentage: 8}}
  }'
}

with() { # with <json> <jq filter>
  printf '%s' "$1" | jq "$2"
}

DIRTY=$(make_repo dirty-proj)
echo changed >> "$DIRTY/tracked"
echo a > "$DIRTY/u1"
echo b > "$DIRTY/u2"
CLEAN=$(make_repo clean-proj)
PLAIN="$T/not-a-repo"
mkdir -p "$PLAIN"

# ---- layout ----
check "full payload, dirty repo: two lines" \
  "dirty-proj ⎇ main !1 ?2${NL}Sonnet 5.5 · medium · ctx 48% · 3h12m · \$4.22 · 5h 52% · 7d 8%" \
  "$(run "$(payload "$DIRTY")")"

check "clean repo: no change counters" \
  "clean-proj ⎇ main${NL}Sonnet 5.5 · medium · ctx 48% · 3h12m · \$4.22 · 5h 52% · 7d 8%" \
  "$(run "$(payload "$CLEAN")")"

check "not a repository: no branch segment" \
  "not-a-repo${NL}Sonnet 5.5 · medium · ctx 48% · 3h12m · \$4.22 · 5h 52% · 7d 8%" \
  "$(run "$(payload "$PLAIN")")"

check "minimal payload: only model on line 2" \
  "clean-proj ⎇ main${NL}Sonnet 5.5" \
  "$(run "$(jq -n --arg d "$CLEAN" '{cwd:$d, model:{display_name:"Sonnet 5.5"}}')")"

check "nothing for line 2: a single line" \
  "clean-proj ⎇ main" \
  "$(run "$(jq -n --arg d "$CLEAN" '{cwd:$d}')")"

check "project name comes from project_dir, branch from current_dir" \
  "clean-proj ⎇ main${NL}Sonnet 5.5" \
  "$(run "$(jq -n --arg p "$CLEAN" --arg c "$CLEAN" '{workspace:{project_dir:$p, current_dir:$c}, model:{display_name:"Sonnet 5.5"}}')")"

mkdir -p "$CLEAN/sub"
check "working in a subdirectory keeps the project name" \
  "clean-proj ⎇ main" \
  "$(run "$(jq -n --arg p "$CLEAN" --arg c "$CLEAN/sub" '{workspace:{project_dir:$p, current_dir:$c}}')")"

OTHER=$(make_repo other-proj)
git -C "$OTHER" checkout -q -b other-branch
check "branch comes from current_dir even if project_dir is another repo" \
  "clean-proj ⎇ other-branch" \
  "$(run "$(jq -n --arg p "$CLEAN" --arg c "$OTHER" '{workspace:{project_dir:$p, current_dir:$c}}')")"

# ---- git details ----
D2=$(make_repo detached-proj)
git -C "$D2" -c user.email=t@t -c user.name=t checkout -q --detach
SHORT=$(git -C "$D2" rev-parse --short HEAD)
check "detached HEAD shows the short hash" \
  "detached-proj ⎇ $SHORT" \
  "$(run "$(jq -n --arg d "$D2" '{cwd:$d}')")"

D3=$(make_repo staged-proj)
echo s >> "$D3/tracked"
git -C "$D3" add tracked
check "staged changes count as changed" \
  "staged-proj ⎇ main !1" \
  "$(run "$(jq -n --arg d "$D3" '{cwd:$d}')")"

D4=$(make_repo branch-proj)
git -C "$D4" checkout -q -b feature/x
check "branch names with a slash" \
  "branch-proj ⎇ feature/x" \
  "$(run "$(jq -n --arg d "$D4" '{cwd:$d}')")"

# ---- cache (5 s by default) ----
D5=$(make_repo cache-proj)
echo a > "$D5/u1"
J5=$(jq -n --arg d "$D5" '{cwd:$d}')
first=$(printf '%s' "$J5" | STATUSLINE_CACHE_DIR="$T/cache" sh "$SCRIPT" | strip)
echo b > "$D5/u2"
second=$(printf '%s' "$J5" | STATUSLINE_CACHE_DIR="$T/cache" sh "$SCRIPT" | strip)
fresh=$(printf '%s' "$J5" | STATUSLINE_CACHE_TTL=0 STATUSLINE_CACHE_DIR="$T/cache" sh "$SCRIPT" | strip)
check "counters are cached within the TTL" "cache-proj ⎇ main ?1" "$second"
check "first call sees the real state" "cache-proj ⎇ main ?1" "$first"
check "TTL 0 bypasses the cache" "cache-proj ⎇ main ?2" "$fresh"

# cache boundary: an entry exactly TTL seconds old is expired; a clearly younger one (3 s of slack, so a busy
# machine cannot age it past the TTL between touch and read) still counts. A 1 s margin made this test flaky.
ago() { date -v-"$1"S +%Y%m%d%H%M.%S 2>/dev/null || date -d "$1 seconds ago" +%Y%m%d%H%M.%S; }
D6=$(make_repo cache-edge-proj)
echo a > "$D6/u1"
J6=$(jq -n --arg d "$D6" '{cwd:$d}')
printf '%s' "$J6" | STATUSLINE_CACHE_DIR="$T/cache6" sh "$SCRIPT" >/dev/null
echo b > "$D6/u2"
touch -t "$(ago 2)" "$T"/cache6/*
check "a cache entry younger than the TTL is still used" "cache-edge-proj ⎇ main ?1" \
  "$(printf '%s' "$J6" | STATUSLINE_CACHE_DIR="$T/cache6" sh "$SCRIPT" | strip)"
touch -t "$(ago 5)" "$T"/cache6/*
check "a cache entry exactly TTL seconds old is expired" "cache-edge-proj ⎇ main ?2" \
  "$(printf '%s' "$J6" | STATUSLINE_CACHE_DIR="$T/cache6" sh "$SCRIPT" | strip)"

# ---- duration ----
dur() { # dur <ms> -> the duration text on line 2
  run "$(payload "$CLEAN" | jq --argjson ms "$1" '.cost.total_duration_ms=$ms')" | sed -n '2p' | awk -F' · ' '{print $4}'
}
check "duration: minutes only" "29m" "$(dur 1740000)"
check "duration: under a minute" "0m" "$(dur 59900)"
check "duration: exactly one hour" "1h00m" "$(dur 3600000)"
check "duration: pads minutes" "2h05m" "$(dur 7500000)"
check "duration: more than a day is still hours" "25h00m" "$(dur 90000000)"

# ---- cost ----
cost() { run "$(payload "$CLEAN" | jq --argjson c "$1" '.cost.total_cost_usd=$c')" | sed -n '2p' | awk -F' · ' '{print $5}'; }
check "cost: zero" '$0.00' "$(cost 0)"
check "cost: pads cents" '$0.50' "$(cost 0.5)"
check "cost: rounds to cents" '$229.78' "$(cost 229.784)"
check "cost: whole dollars" '$3.00' "$(cost 3)"
check "cost: rounds half a cent up" '$0.03' "$(cost 0.025)"
check "cost: rounds just below half down" '$0.02' "$(cost 0.0249)"

# ---- percentages ----
check "percentages are rounded to integers" \
  "Sonnet 5.5 · medium · ctx 48% · 3h12m · \$4.22 · 5h 53% · 7d 9%" \
  "$(run "$(payload "$CLEAN" | jq '.context_window.used_percentage=47.6 | .rate_limits.five_hour.used_percentage=52.5 | .rate_limits.seven_day.used_percentage=8.5')" | sed -n '2p')"

check "only the 5h limit present" \
  "Sonnet 5.5 · medium · ctx 48% · 3h12m · \$4.22 · 5h 52%" \
  "$(run "$(payload "$CLEAN" | jq 'del(.rate_limits.seven_day)')" | sed -n '2p')"

check "no rate limits: segment omitted" \
  "Sonnet 5.5 · medium · ctx 48% · 3h12m · \$4.22" \
  "$(run "$(payload "$CLEAN" | jq 'del(.rate_limits)')" | sed -n '2p')"

check "no context percentage yet: segment omitted" \
  "Sonnet 5.5 · medium · 3h12m · \$4.22 · 5h 52% · 7d 8%" \
  "$(run "$(payload "$CLEAN" | jq 'del(.context_window)')" | sed -n '2p')"

# ---- colors: green < 60, yellow 60..84, red >= 85 ----
color_of() { # color_of <json> <label>  -> the SGR number in front of the label
  run_raw "$1" | sed -n '2p' | sed -n "s/.*${ESC}\[\([0-9;]*\)m$2.*/\1/p"
}
ctx_json() { payload "$CLEAN" | jq --argjson v "$1" '.context_window.used_percentage=$v'; }
check "ctx 48% is green" "32" "$(color_of "$(ctx_json 48)" 'ctx 48%')"
check "ctx 59% is green" "32" "$(color_of "$(ctx_json 59)" 'ctx 59%')"
check "ctx 60% is yellow" "33" "$(color_of "$(ctx_json 60)" 'ctx 60%')"
check "ctx 84% is yellow" "33" "$(color_of "$(ctx_json 84)" 'ctx 84%')"
check "ctx 85% is red" "31" "$(color_of "$(ctx_json 85)" 'ctx 85%')"
check "ctx 100% is red" "31" "$(color_of "$(ctx_json 100)" 'ctx 100%')"
lim_json() { payload "$CLEAN" | jq --argjson v "$1" '.rate_limits.five_hour.used_percentage=$v'; }
check "5h 90% is red" "31" "$(color_of "$(lim_json 90)" '5h 90%')"
check "5h 10% is green" "32" "$(color_of "$(lim_json 10)" '5h 10%')"

# ---- robustness ----
out=$(printf 'not json {' | STATUSLINE_CACHE_TTL=0 sh "$SCRIPT" 2>&1)
printf 'not json {' | STATUSLINE_CACHE_TTL=0 sh "$SCRIPT" >/dev/null 2>&1
status=$?
check "garbage stdin exits 0" 0 "$status"
printf '%s' "$(payload "$CLEAN")" | STATUSLINE_CACHE_TTL=0 sh "$SCRIPT" >/dev/null 2>&1
check "normal payload exits 0" 0 "$?"
case "$out" in *parse*|*jq*|*error*|*Error*) leak=yes ;; *) leak=no ;; esac
check "garbage stdin leaks no error text" no "$leak"

check "empty stdin still prints something" "yes" \
  "$( [ -n "$(cd "$CLEAN" && sh "$SCRIPT" </dev/null 2>&1)" ] && echo yes || echo no )"

check "unicode and spaces in the directory name" \
  "café über" \
  "$(run "$(jq -n '{workspace:{project_dir:"/tmp/nonexistent/café über"}}')")"

check "CJK characters and a space in the directory name" \
  "我的 项目" \
  "$(run "$(jq -n '{workspace:{project_dir:"/tmp/nonexistent/我的 项目"}}')")"

echo
echo "$((count - fail))/$count passed"
[ "$fail" -eq 0 ]
