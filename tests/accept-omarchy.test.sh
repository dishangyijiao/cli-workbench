#!/usr/bin/env bash
# Contract and Linux integration tests for the disposable Omarchy verifier.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
ACCEPT="$WB_SRC/scripts/accept-omarchy"

echo 'the workstation acceptance runner has a stable interface'
assert 'Bash syntax is valid' bash -n "$ACCEPT"
out=$(bash "$ACCEPT" --help 2>&1); rc=$?
assert_eq 'help succeeds' 0 "$rc"
assert_contains 'headless mode described' '--headless' "$out"
assert_contains 'desktop mode described' '--desktop' "$out"
bash "$ACCEPT" --invalid >/dev/null 2>&1
assert_eq 'unsupported flag exits 2' 2 "$?"
bash "$ACCEPT" --headless --desktop >/dev/null 2>&1
assert_eq 'multiple modes refused' 2 "$?"

echo 'the runner does not require the font macOS uses (Omarchy ships its own)'
refute 'no SauceCodePro requirement' grep -Fq 'SauceCodePro' "$ACCEPT"

if [ "$(uname -s)" = Linux ] && command -v chezmoi >/dev/null 2>&1 &&
   command -v zsh >/dev/null 2>&1 && command -v tmux >/dev/null 2>&1 &&
   command -v jq >/dev/null 2>&1 && command -v diff >/dev/null 2>&1 &&
   command -v cmp >/dev/null 2>&1; then
  echo 'headless mode exercises a fresh disposable workbench on Linux'
  out=$(bash "$ACCEPT" --headless 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" | tail -25; fi
  assert_eq 'headless acceptance passes' 0 "$rc"
  assert_contains 'chezmoi target is disposable' 'PASS  chezmoi deployment to disposable HOME' "$out"
  assert_contains 'Linux leaves Ghostty to the desktop' 'PASS  Ghostty config not deployed on Linux' "$out"
  assert_contains 'isolated tmux server started' 'PASS  isolated tmux server started' "$out"
  assert_contains 'tmux opener is checked' 'PASS  tmux Linux URL opener' "$out"
  assert_contains 'explicit pass summary is emitted' 'RESULT: PASS' "$out"

  echo 'desktop mode keeps the Ghostty parser check and does not require the macOS font'
  # Stubs stand in for the desktop: the host has a Nerd Font that is not the one macOS uses, and a Ghostty that records
  # how it was asked to validate.
  T_DIR=$(cd -P "$(mktemp -d)" && pwd); trap t_cleanup EXIT
  mkdir -p "$T_DIR/bin"
  # The stub also keeps the config file it was given, so the test can tell which rendering of the template was checked.
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/ghostty.args"\nfor a in "$@"; do case $a in --config-file=*) cat "${a#--config-file=}" > "%s/ghostty.config";; esac; done\n' "$T_DIR" "$T_DIR" > "$T_DIR/bin/ghostty"
  printf '#!/bin/sh\necho "[{}]"\n' > "$T_DIR/bin/hyprctl"
  printf '#!/bin/sh\nprintf "JetBrainsMono Nerd Font\\nNoto Sans\\n"\n' > "$T_DIR/bin/fc-list"
  printf '#!/bin/sh\nexit 0\n' > "$T_DIR/bin/wl-copy"; cp "$T_DIR/bin/wl-copy" "$T_DIR/bin/wl-paste"
  chmod +x "$T_DIR"/bin/*
  out=$(PATH="$T_DIR/bin:$PATH" XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=stub \
        bash "$ACCEPT" --desktop 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" | tail -25; fi
  assert_eq 'desktop acceptance passes with Omarchy fonts' 0 "$rc"
  assert_contains 'Ghostty parser check ran' 'PASS  Ghostty accepts the rendered template' "$out"
  assert_contains 'Ghostty was asked to validate a config' '+validate-config' "$(cat "$T_DIR/ghostty.args" 2>/dev/null)"
  # Linux does not deploy the template, so the check renders the macOS variant; the guide has to say that and not claim a Linux config.
  assert_contains 'the config Ghostty checked is the macOS rendering' 'macos-titlebar-style' "$(cat "$T_DIR/ghostty.config" 2>/dev/null)"
  assert_contains 'the guide says which rendering is validated' 'validate the template rendered for macOS' "$(tr '\n' ' ' < "$WB_SRC/docs/omarchy.md" | tr -s ' ')"
  refute 'the guide does not call it a Linux config' grep -Fq 'validate the rendered Linux config' "$WB_SRC/docs/omarchy.md"
  assert_contains 'any Nerd Font satisfies the font check' 'PASS  a Nerd Font is installed' "$out"
else
  echo 'skip Linux integration: platform or dependency unavailable'
fi
t_done
