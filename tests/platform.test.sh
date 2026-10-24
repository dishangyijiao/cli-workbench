#!/usr/bin/env bash
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
template="$root/home/dot_config/ghostty/config.tmpl"
tmux_config="$root/home/dot_tmux.conf"
grep -q 'eq .chezmoi.os "darwin"' "$template"
grep -q 'macos-titlebar-style = tabs' "$template"
grep -q 'window-save-state = always' "$template"
grep -q "xdg-open" "$tmux_config"
grep -q "set -g prefix C-a" "$tmux_config"
if command -v chezmoi >/dev/null 2>&1; then
  rendered=$(chezmoi --source "$root" execute-template < "$template")
  printf '%s\n' "$rendered" | grep -q 'theme = Catppuccin Mocha'
  printf '%s\n' "$rendered" | grep -q 'font-family = SauceCodePro Nerd Font Mono'
  case $(uname -s) in
    Darwin)
      printf '%s\n' "$rendered" | grep -q 'macos-titlebar-style = tabs'
      printf '%s\n' "$rendered" | grep -q 'window-save-state = always'
      ;;
    Linux)
      if printf '%s\n' "$rendered" | grep -Eq '^(macos-titlebar-style|window-save-state)'; then
        echo "macOS-only Ghostty options leaked into Linux configuration" >&2
        exit 1
      fi
      ;;
  esac
fi
echo "platform config checks passed"
