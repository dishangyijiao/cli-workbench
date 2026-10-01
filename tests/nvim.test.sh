#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
cd "$WB_SRC" || exit 1
NVIM_SRC=home/dot_config/nvim

echo "the nvim config ships"
assert "init.lua exists" test -f $NVIM_SRC/init.lua
assert "plugin versions are pinned by lazy-lock.json" test -f $NVIM_SRC/lazy-lock.json

echo "chezmoi deploys it to ~/.config/nvim in a clean HOME"
H=$(cd -P "$(mktemp -d)" && pwd)
t_render "$H"
assert "~/.config/nvim/init.lua is deployed" test -f "$H/.config/nvim/init.lua"
assert "the deployed copy matches the source" diff -r "$NVIM_SRC" "$H/.config/nvim" -x '.chezmoi*'
case $H in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$H";; esac

echo "every Lua file parses (needs nvim; no network, no plugins)"
if command -v nvim >/dev/null; then
  bad=$(find $NVIM_SRC -name '*.lua' | while read -r f; do nvim --headless -u NONE -l /dev/stdin "$f" >/dev/null 2>&1 <<'LUA' || echo "$f"
local f = assert(arg[1]); local ok, err = loadfile(f); if not ok then io.stderr:write(err); os.exit(1) end
LUA
  done)
  assert_eq "no Lua syntax errors" "" "$bad"
else
  echo "  skip  nvim not installed"
fi
t_done
