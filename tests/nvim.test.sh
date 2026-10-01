#!/usr/bin/env bash
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
cd "$WB_SRC" || exit 1

echo "the nvim component ships and is enabled"
assert "links.txt has an active nvim component" grep -qE '^nvim[[:space:]]+config/nvim[[:space:]]+~/\.config/nvim$' links.txt
assert "init.lua exists" test -f config/nvim/init.lua
assert "plugin versions are pinned by lazy-lock.json" test -f config/nvim/lazy-lock.json

echo "linking it from a clean HOME"
H=$(cd -P "$(mktemp -d)" && pwd)
out=$(HOME=$H scripts/link nvim --apply 2>&1); assert_eq "link nvim --apply exits 0" 0 $?
assert "~/.config/nvim resolves to the repo copy" test "$(cd -P "$H/.config/nvim" && pwd)" = "$WB_SRC/config/nvim"
out=$(HOME=$H scripts/check nvim 2>&1); assert_eq "check nvim exits 0" 0 $?
case $H in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$H";; esac

echo "every Lua file parses (needs nvim; no network, no plugins)"
if command -v nvim >/dev/null; then
  bad=$(find config/nvim -name '*.lua' | while read -r f; do nvim --headless -u NONE -l /dev/stdin "$f" >/dev/null 2>&1 <<'LUA' || echo "$f"
local f = assert(arg[1]); local ok, err = loadfile(f); if not ok then io.stderr:write(err); os.exit(1) end
LUA
  done)
  assert_eq "no Lua syntax errors" "" "$bad"
else
  echo "  skip  nvim not installed"
fi
t_done
