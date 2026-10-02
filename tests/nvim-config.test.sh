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

echo "<leader>rc reloads the LSP config, and only that"
cat > "$T_DIR/rc.lua" <<'LUA'
package.path = arg[1] .. "/?.lua;" .. arg[1] .. "/?/init.lua;" .. package.path
vim.g.mapleader = " "
local msgs, loads = {}, 0
vim.notify = function(msg) msgs[#msgs + 1] = msg end
package.preload["lsp"] = function() loads = loads + 1; return true end
require("plugins")
require("lsp")                                           -- loaded once, as at start-up
package.loaded["lspconfig"] = "plugin-internal-state"      -- a plugin's own module must survive the reload
vim.fn.maparg("<leader>rc", "n", false, true).callback()
print("lspconfig_kept", tostring(package.loaded["lspconfig"] == "plugin-internal-state"))
print("lsp_loaded_again", tostring(loads == 2))
print("says_restart", tostring((msgs[#msgs] or ""):lower():find("restart", 1, true) ~= nil))
LUA
out=$(runlua "$T_DIR/rc.lua")
assert_contains "lspconfig's own modules are not thrown away" "lspconfig_kept true" "$out"
assert_contains "lsp/ is loaded again" "lsp_loaded_again true" "$out"
assert_contains "the message says that plugin changes need a restart" "says_restart true" "$out"

echo "a language server is only set up when its executable is installed"
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/lsp.lua" <<'LUA'
package.path = arg[1] .. "/?.lua;" .. arg[1] .. "/?/init.lua;" .. package.path
local calls = {}
local function any() local t; t = setmetatable({}, { __index = function() return t end, __call = function() return t end }); return t end
package.preload["lspconfig"] = function()
  return setmetatable({ util = { root_pattern = function() end, find_git_ancestor = function() end } },
    { __index = function(_, name) return { setup = function() calls[#calls + 1] = name end } end })
end
package.preload["cmp_nvim_lsp"] = function() return { default_capabilities = function() return {} end } end
package.preload["cmp"] = any
package.preload["luasnip"] = any
require("lsp")
print("set up: " .. table.concat(calls, " "))
LUA
out=$(RUNLUA_PATH="$T_DIR/bin" runlua "$T_DIR/lsp.lua")
assert_eq "with no server installed, none is set up" "set up: " "$out"
for exe in yaml-language-server docker-langserver; do printf '#!/bin/sh\n' > "$T_DIR/bin/$exe"; chmod +x "$T_DIR/bin/$exe"; done
out=$(RUNLUA_PATH="$T_DIR/bin" runlua "$T_DIR/lsp.lua")
assert_eq "only the installed ones are set up" "set up: yamlls dockerls" "$out"
for exe in typescript-language-server vscode-html-language-server vscode-css-language-server; do
  printf '#!/bin/sh\n' > "$T_DIR/bin/$exe"; chmod +x "$T_DIR/bin/$exe"
done
out=$(RUNLUA_PATH="$T_DIR/bin" runlua "$T_DIR/lsp.lua")
assert_eq "with all five installed, all five are set up" "set up: ts_ls html cssls yamlls dockerls" "$out"
t_done
