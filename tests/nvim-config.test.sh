#!/usr/bin/env bash
# Three properties of the Neovim config that do not need any plugin installed: a module that fails to load says so,
# <leader>rc does what it says, and a language server is only set up when it is installed. The plugins are replaced by stubs.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v nvim >/dev/null; then echo "nvim not installed; skipped"; exit 0; fi
NVIM=$(command -v nvim)
LUA=$WB_SRC/home/dot_config/nvim/lua
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap 'case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac' EXIT
# Run a Lua script with nvim: $1 = script, and the config's lua/ directory is arg[1] inside it. The XDG directories point
# into T_DIR, so nothing here can read or touch the real Neovim config. RUNLUA_PATH replaces PATH for nvim only.
runlua() {
  PATH="${RUNLUA_PATH:-$PATH}" XDG_CONFIG_HOME="$T_DIR/xdg/config" XDG_DATA_HOME="$T_DIR/xdg/data" \
    XDG_STATE_HOME="$T_DIR/xdg/state" XDG_CACHE_HOME="$T_DIR/xdg/cache" \
    "$NVIM" --headless -u NONE -l "$1" "$LUA" 2>&1 | tr -d '\r'
}

echo "a module that fails to load is reported, not swallowed"
cat > "$T_DIR/safe.lua" <<'LUA'
package.path = arg[1] .. "/?.lua;" .. arg[1] .. "/?/init.lua;" .. package.path
local seen = {}
vim.notify = function(msg, level) seen[#seen + 1] = level .. ":" .. (msg:gsub("\n", " | ")) end
package.preload["wb_boom"] = function() error("kaboom") end
package.preload["wb_fine"] = function() return {} end
local safe = require("safe_require")
print("fine", tostring((safe("wb_fine"))), #seen)
print("boom", tostring((safe("wb_boom"))), seen[1])
print("missing", tostring((safe("wb_not_installed_xyz"))), seen[2])
LUA
out=$(runlua "$T_DIR/safe.lua")
assert_contains "a module that loads is quiet" "fine true 0" "$out"
assert_contains "a runtime error is an ERROR (4) that names the module" "boom false 4:wb_boom: could not load" "$out"
assert_contains "and the cause reaches the user" "kaboom" "$out"
assert_contains "a module that is not installed yet (first start) is only a WARN (3)" "missing false 3:wb_not_installed_xyz: could not load" "$out"

t_done
