#!/usr/bin/env bash
# Shared helpers for cli-workbench scripts. Source it; do not execute it.

WB_ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WB_MANIFEST=${WB_MANIFEST:-$WB_ROOT/links.txt}
WB_FAILS=0

# The manifest is passed between scripts as tab-separated lines, so a tab or newline in these paths cannot be represented.
case $WB_ROOT${HOME:-} in
  *$'\t'*|*$'\n'*) echo "cli-workbench: the repository path or HOME contains a tab or newline character, which is not supported" >&2; exit 2 ;;
esac

wb_pass() { printf 'PASS  %s\n' "$1"; }
wb_warn() { printf 'WARN  %s\n' "$1"; }
wb_fail() { printf 'FAIL  %s\n' "$1"; WB_FAILS=$((WB_FAILS+1)); }

# ~ and ~/x -> $HOME-based path; anything else unchanged.
wb_expand() {
  case $1 in
    "~")   printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${1#\~/}" ;;
    *)     printf '%s\n' "$1" ;;
  esac
}

# Physical absolute path with every symlink resolved; status 1 (no output) if it does not exist.
wb_resolve() {
  local p=$1 n=0 l dir base
  while [ -L "$p" ]; do
    n=$((n+1)); [ "$n" -gt 40 ] && return 1
    l=$(readlink "$p")
    case $l in /*) p=$l ;; *) p=$(dirname "$p")/$l ;; esac
  done
  [ -e "$p" ] || return 1
  dir=$(cd -P "$(dirname "$p")" 2>/dev/null && pwd) || return 1
  base=$(basename "$p")
  if [ "$dir" = / ]; then printf '/%s\n' "$base"; else printf '%s/%s\n' "$dir" "$base"; fi
}

# Status 2 and a message on stderr if any non-comment line does not have exactly three fields.
wb_manifest_check() {
  local n=0 c s t extra rc=0
  while read -r c s t extra; do
    n=$((n+1))
    case $c in ''|'#'*) continue ;; esac
    if [ -z "$s" ] || [ -z "$t" ] || [ -n "$extra" ]; then
      echo "links.txt:$n: expected 'component source target' (three fields, no spaces)" >&2
      rc=2
    fi
  done < "$WB_MANIFEST"
  return $rc
}

# One line per entry, tab-separated (paths may contain spaces): component, absolute repo source, absolute target.
# Read it with:  while IFS=$'\t' read -r comp src tgt; do ...; done < <(wb_manifest)
wb_manifest() {
  local c s t
  while read -r c s t; do
    case $c in ''|'#'*) continue ;; esac
    printf '%s\t%s\t%s\n' "$c" "$WB_ROOT/$s" "$(wb_expand "$t")"
  done < "$WB_MANIFEST"
}

# Physical path of the directory that holds $1, even if $1 does not exist yet (the nearest existing ancestor).
wb_parent_real() {
  local d; d=$(dirname "$1")
  while [ ! -d "$d" ] && [ "$d" != / ] && [ "$d" != . ]; do d=$(dirname "$d"); done
  ( cd -P "$d" 2>/dev/null && pwd )
}

# Classify a target: ok | missing | file | dir | foreign-link | broken-link | inside-source | contains-source
# inside-source: the target physically lives inside the repository (so it IS part of the repo, for example when
# ~/.config is a symlink to the repo's config/), or would be created there. contains-source: the target is a
# directory that holds the repository source. Moving or creating such a target would modify the repo itself, so
# link refuses both, even with --adopt. Equality of two paths uses file identity (-ef), not spelling, so a
# differently cased path on a case-insensitive filesystem cannot slip through.
wb_state() {
  local src=$1 tgt=$2 a b p root inside=0
  root=$(cd -P "$WB_ROOT" && pwd); p=$(wb_parent_real "$tgt")
  case $p/ in "$root"/*) inside=1 ;; esac
  if [ -L "$tgt" ]; then
    a=$(wb_resolve "$tgt") || { if [ $inside = 1 ]; then echo inside-source; else echo broken-link; fi; return; }
    b=$(wb_resolve "$src") || { echo foreign-link; return; }
    if [ "$a" = "$b" ] || [ "$a" -ef "$b" ]; then echo ok
    elif [ $inside = 1 ]; then echo inside-source
    else echo foreign-link; fi
  elif [ -e "$tgt" ] && [ "$tgt" -ef "$src" ]; then echo ok            # the same file, reached through a symlinked parent
  elif [ $inside = 1 ]; then echo inside-source
  elif [ -e "$tgt" ]; then
    a=$(wb_resolve "$tgt"); b=$(wb_resolve "$src")
    case $b in "$a"/*) echo contains-source; return ;; esac
    if [ -d "$tgt" ]; then echo dir; else echo file; fi
  else echo missing
  fi
}

# Create and print a fresh backup dir; never reuse an existing one (suffix -1, -2, ...).
wb_new_backup_root() {
  local ts=${WB_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)} base cand n=0
  base=$HOME/.cli-workbench-backup/$ts
  mkdir -p "$HOME/.cli-workbench-backup" || return 1
  cand=$base
  until mkdir "$cand" 2>/dev/null; do
    n=$((n+1))
    if [ "$n" -gt 100 ]; then echo "cannot create a backup dir under $HOME/.cli-workbench-backup" >&2; return 1; fi
    cand=$base-$n
  done
  printf '%s\n' "$cand"
}
