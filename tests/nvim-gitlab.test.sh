#!/usr/bin/env bash
# lua/git/gitlab.lua: what the <leader>gm mapping turns a remote URL, a merge request number and a commit into.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v nvim >/dev/null; then echo "nvim not installed; skipped"; exit 0; fi
MOD=$WB_SRC/home/dot_config/nvim/lua/git/gitlab.lua

echo "remote URLs become a base URL and a project path"
out=$(nvim --headless -u NONE -l /dev/stdin "$MOD" 2>&1 <<'LUA' | tr -d '\r'
local gl = dofile(arg[1])
local function p(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  print(table.concat(t, "|"))
end
p(gl.parse_remote("git@gitlab.com:group/my.project.git"))
p(gl.parse_remote("https://gitlab.example.com/a/b/c.git"))
p(gl.parse_remote("https://oauth2:secrettoken@gitlab.com:8443/g/p.git")) -- wb-scan: allow (a credential-shaped fixture)
p(gl.parse_remote("https://gitlab.com/g/p/"))
p(gl.parse_remote("git@git_server.corp:g/p.git"))
p(gl.parse_remote("https://git_server.corp:8443/g/p"))
LUA
)
expected=$(printf '%s\n' 'https://gitlab.com|group/my.project' 'https://gitlab.example.com|a/b/c' \
  'https://gitlab.com:8443|g/p' 'https://gitlab.com|g/p' 'https://git_server.corp|g/p' 'https://git_server.corp:8443|g/p')
assert_eq "dots in a project name survive; credentials are dropped; a trailing slash and an underscore in the host are fine" "$expected" "$out"

echo "anything unexpected is refused instead of being put into a URL"
out=$(nvim --headless -u NONE -l /dev/stdin "$MOD" 2>&1 <<'LUA' | tr -d '\r'
local gl = dofile(arg[1])
local function p(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  print(table.concat(t, "|"))
end
p(gl.parse_remote("git@gitlab.com:g/p'; touch x; '.git"))
p(gl.parse_remote("https://gitlab.com/'$(touch x)'"))
p(gl.parse_remote("https://ho'st.com/g/p"))
p(gl.parse_remote("https://gitlab.com/g/../etc"))
p(gl.parse_remote("ftp://gitlab.com/g/p"))
p(gl.parse_remote(nil))
LUA
)
expected=$(printf '%s\n' nil nil nil nil nil nil)
assert_eq "quotes, \$( ), .., other schemes and nil all give nil" "$expected" "$out"

echo "page URLs"
out=$(nvim --headless -u NONE -l /dev/stdin "$MOD" 2>&1 <<'LUA' | tr -d '\r'
local gl = dofile(arg[1])
print(tostring(gl.page_url("https://h", "g/p", "!123", "abc")))
print(tostring(gl.page_url("https://h", "g/p", nil, "abc123")))
print(tostring(gl.page_url("https://h", "g/p", "!1;x", "abc")))
print(tostring(gl.page_url("https://h", "g/p", nil, "x'; rm -rf ~; '")))
print(tostring(gl.page_url("https://h", "g/p", nil, nil)))
LUA
)
expected=$(printf '%s\n' 'https://h/g/p/-/merge_requests/123' 'https://h/g/p/-/commit/abc123' nil nil nil)
assert_eq "a merge request or a commit page; non-numeric and non-hex values give nil" "$expected" "$out"
t_done
