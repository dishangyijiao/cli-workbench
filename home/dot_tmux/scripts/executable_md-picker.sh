#!/bin/sh
# Pick a Markdown file that the Claude Code conversation in this pane mentioned, and read it in Neovim (prefix+M).
#   md-picker.sh %12          the popup: fzf with a preview (a numbered menu without fzf); Enter opens `nvim -R FILE`
#   md-picker.sh --list %12   the list only, one file per line, the most recently mentioned first
# The session: agent-state.sh records the pane's session_id in
# ${XDG_STATE_HOME:-~/.local/state}/cli-workbench/sessions/<tmux server>/<pane id>.json, and the conversation is
# ${CLAUDE_CONFIG_DIR:-~/.claude}/projects/*/<session_id>.jsonl. Codex, Gemini and Grok record no session id: not covered.
# What counts as a mention: a `.md` path in the message text, the tool calls (a Write/Edit/Read file_path is taken whole,
# so it may contain spaces; other strings, such as a Bash command, are split into words) and the tool results. Thinking
# is left out. Relative paths are resolved against the record's cwd; only files that exist are listed, each once.
# Read only: nothing is written. Paths come from untrusted text, so they are only ever passed as quoted arguments, never
# as part of a command line (see branch.sh).
TAB=$(printf '\t')
unset CDPATH

pause() { printf '%s' "$1"; read -r _; }

# transcript PANE: the path of the conversation file of the Claude Code session in that pane, or nothing.
transcript() {
  server=$(tmux display-message -p '#{pid}-#{start_time}' 2>/dev/null)
  case $server in ''|*[!0-9-]*) return 0 ;; esac
  state=${XDG_STATE_HOME:-$HOME/.local/state}/cli-workbench/sessions/$server/$1.json
  [ -f "$state" ] || return 0
  sid=$(jq -r '.session_id // empty | tostring' "$state" 2>/dev/null)
  case $sid in ''|*[!A-Za-z0-9_-]*) return 0 ;; esac
  for f in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/"$sid".jsonl; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
}

# mentions FILE: "cwd<TAB>path" for every .md mention, in the order of the conversation. Lines that are not JSON are skipped.
mentions() {
  jq -rR '
    def word: "[^\\s\"'"'"'`<>()\\[\\]{}|;,:=*?]+\\.md(?![A-Za-z0-9_-])";
    def cands:
      if type == "string" then scan(word)
      elif type == "array" then .[] | cands
      elif type == "object" then
        if .type == "thinking" or .type == "redacted_thinking" then empty
        else (if (.file_path | type) == "string" and (.file_path | endswith(".md")) then .file_path else empty end),
             (del(.file_path) | .[] | cands)
        end
      else empty end;
    fromjson? | select(type == "object" and (.type == "user" or .type == "assistant"))
    | (.cwd | if type == "string" and (test("[\t\n]") | not) then . else "" end) as $cwd
    | .message.content? | cands
    | select(test("[\t\n]") | not)
    | $cwd + "\t" + .' "$1" 2>/dev/null
}

# entries PANE: "short<TAB>full" per existing file, the most recently mentioned first, each once. short has ~ for $HOME.
entries() {
  f=$(transcript "$1")
  [ -n "$f" ] || return 3
  mentions "$f" | awk -F'\t' '
    { p = $2
      if (substr(p, 1, 2) == "~/") p = ENVIRON["HOME"] substr(p, 2)
      else if (substr(p, 1, 1) != "/") { if ($1 == "") next; p = $1 "/" p }
      a[NR] = p }
    END { for (i = NR; i > 0; i--) if ((i in a) && !(a[i] in seen)) { seen[a[i]] = 1; print a[i] } }' \
  | while IFS= read -r p; do
      d=${p%/*} b=${p##*/}
      d=$(cd -- "${d:-/}" 2>/dev/null && pwd) || continue
      p=${d%/}/$b
      [ -f "$p" ] || continue
      printf '%s\n' "$p"
    done \
  | awk -v tab="$TAB" '!seen[$0]++ {
      s = $0; h = ENVIRON["HOME"]
      if (h != "" && h != "/" && index(s, h "/") == 1) s = "~" substr(s, length(h) + 1)
      print s tab $0 }'
}

# list PANE: entries, or why there are none (exit 3: no session, exit 4: no Markdown file).
list() {
  out=$(entries "$1") || return 3
  [ -n "$out" ] || return 4
  printf '%s\n' "$out"
}

open() { exec nvim -R -- "$1"; }

pick() {
  out=$(list "$1"); rc=$?
  case $rc in
    3) pause 'No Claude Code session found for this pane. Press Enter to close.'; return 0 ;;
    4) pause 'This conversation mentions no Markdown file. Press Enter to close.'; return 0 ;;
  esac
  if command -v fzf >/dev/null 2>&1; then
    # The full path is the last field: fzf shows the short one and previews the full one (it quotes {2} itself).
    sel=$(printf '%s\n' "$out" | fzf --reverse --no-sort --prompt='md> ' --delimiter="$TAB" --with-nth=1 \
      --preview='head -n 200 {2}') || return 0
    [ -n "$sel" ] && open "${sel#*"$TAB"}"
    return 0
  fi
  n=0
  while IFS= read -r line; do n=$((n + 1)); printf '%2d) %s\n' "$n" "${line%%"$TAB"*}"; done <<EOF
$out
EOF
  printf 'Number (Enter cancels): '
  read -r choice || return 0
  case $choice in ''|*[!0-9]*) return 0 ;; esac
  [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ] || return 0
  line=$(printf '%s\n' "$out" | sed -n "${choice}p")
  open "${line#*"$TAB"}"
}

mode=pick
[ "${1-}" = --list ] && { mode=list; shift; }
pane=${1-}
case $pane in %[0-9]*) ;; *) echo "usage: md-picker.sh [--list] PANE_ID" >&2; exit 2 ;; esac
case $pane in *[!%0-9]*) echo "usage: md-picker.sh [--list] PANE_ID" >&2; exit 2 ;; esac
if ! command -v jq >/dev/null 2>&1; then pause 'jq is required to read the conversation. Press Enter to close.'; exit 0; fi
case $mode in
  list)
    out=$(list "$pane"); rc=$?
    case $rc in
      0) printf '%s\n' "$out" | cut -f1 ;;
      3) echo 'No Claude Code session found for this pane.' >&2 ;;
      4) echo 'This conversation mentions no Markdown file.' >&2 ;;
    esac
    exit "$rc" ;;
  pick) pick "$pane" ;;
esac
