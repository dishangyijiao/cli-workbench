#!/usr/bin/env bash
# Markdown files are shown rendered, in the same Neovim window: headings, lists, tables and code blocks drawn as styled text
# (render-markdown.nvim), with one key to switch the rendering off and on. This test checks what the config decides, with
# no plugin installed and no network: that the plugin is in the spec for Markdown files only, that the parsers it needs are
# requested, that the toggle key is a buffer-local mapping for Markdown, and that the plugin version is pinned. That the
# plugin then draws well is the plugin's job; docs/keybindings.md says what to look for.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v nvim >/dev/null; then echo "nvim not installed; skipped"; exit 0; fi
NVIM=$(command -v nvim)
NVIM_SRC=$WB_SRC/home/dot_config/nvim
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap 'case $T_DIR in /tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$T_DIR";; esac' EXIT
runlua() {
  XDG_CONFIG_HOME="$T_DIR/xdg/config" XDG_DATA_HOME="$T_DIR/xdg/data" XDG_STATE_HOME="$T_DIR/xdg/state" \
    XDG_CACHE_HOME="$T_DIR/xdg/cache" "$NVIM" --headless -u NONE -l "$1" "$NVIM_SRC/lua" 2>&1 | tr -d '\r'
}

cat > "$T_DIR/spec.lua" <<'LUA'
package.path = arg[1] .. "/?.lua;" .. arg[1] .. "/?/init.lua;" .. package.path
local specs = dofile(arg[1] .. "/plugins/init.lua")
local function find(name)
  for _, s in ipairs(specs) do if s[1] == name then return s end end
end

local r = find("MeanderingProgrammer/render-markdown.nvim")
print("present", tostring(r ~= nil))
if r then
  local ft = r.ft
  if type(ft) == "string" then ft = { ft } end
  print("only-markdown", tostring(ft ~= nil and #ft == 1 and ft[1] == "markdown"))
  local deps = {}
  for _, d in ipairs(r.dependencies or {}) do deps[d] = true end
  print("needs-treesitter", tostring(deps["nvim-treesitter/nvim-treesitter"] == true))
  print("needs-icons", tostring(deps["nvim-tree/nvim-web-devicons"] == true))
  local o = r.opts or {}
  local h = o.heading or {}
  print("heading-block", tostring(h.width == "block"))
  print("heading-no-sign", tostring(h.sign == false))
  print("heading-h1-only-bar", tostring(h.backgrounds ~= nil and h.backgrounds[1] ~= "" and h.backgrounds[2] == "" and h.backgrounds[6] == ""))
  print("code-block", tostring(o.code ~= nil and o.code.width == "block" and o.code.border == "thin"))
  local key
  for _, k in ipairs(r.keys or {}) do if k[1] == "<leader>mp" then key = k end end
  print("toggle-key", tostring(key ~= nil))
  if key then
    print("toggle-runs", tostring(type(key[2]) == "string" and key[2]:find("RenderMarkdown toggle", 1, true) ~= nil))
    print("toggle-scope", tostring(key.ft == "markdown" and key.mode == nil))
    print("toggle-desc", tostring(type(key.desc) == "string" and #key.desc > 0))
  end
end

-- the parsers the plugin needs are requested by the treesitter spec
local ts = find("nvim-treesitter/nvim-treesitter")
local asked
package.loaded["nvim-treesitter.configs"] = { setup = function(opts) asked = opts end }
ts.config()
local have = {}
for _, p in ipairs(asked and asked.ensure_installed or {}) do have[p] = true end
print("parser-markdown", tostring(have["markdown"] == true))
print("parser-markdown_inline", tostring(have["markdown_inline"] == true))
LUA
out=$(runlua "$T_DIR/spec.lua")
assert_contains "the plugin is in the spec" "present true" "$out"
assert_contains "it loads for Markdown files only, so nothing else starts it" "only-markdown true" "$out"
assert_contains "it declares treesitter, which it draws from" "needs-treesitter true" "$out"
assert_contains "it declares the icon plugin the config already uses" "needs-icons true" "$out"
assert_contains "headings are as wide as the text, not the window" "heading-block true" "$out"
assert_contains "headings leave the sign column empty" "heading-no-sign true" "$out"
assert_contains "only the top heading has a coloured bar; lower levels differ by colour and weight" "heading-h1-only-bar true" "$out"
assert_contains "code blocks are as wide as their text, with a thin border" "code-block true" "$out"
assert_contains "<leader>mp is defined with the plugin" "toggle-key true" "$out"
assert_contains "it runs the plugin's toggle" "toggle-runs true" "$out"
assert_contains "it exists only in Markdown buffers, in normal mode" "toggle-scope true" "$out"
assert_contains "it has a description for the key list" "toggle-desc true" "$out"
assert_contains "the markdown parser is requested" "parser-markdown true" "$out"
assert_contains "and the inline parser, which headings and emphasis need" "parser-markdown_inline true" "$out"

echo "the plugin version is pinned, like every other plugin"
lock=$NVIM_SRC/lazy-lock.json
assert_eq "render-markdown.nvim has a pinned commit" "yes" \
  "$(jq -r 'if (.["render-markdown.nvim"].commit // "" | test("^[0-9a-f]{40}$")) then "yes" else "no" end' "$lock" 2>/dev/null)"
assert_eq "the lock file is still valid JSON" "0" "$(jq empty "$lock" >/dev/null 2>&1; echo $?)"

echo "the key is written down in both languages"
assert "English key list names <leader>mp" grep -q '`<leader>mp`' "$WB_SRC/docs/keybindings.md"
assert "Chinese key list names <leader>mp" grep -q '`<leader>mp`' "$WB_SRC/docs/keybindings.zh-CN.md"
t_done
