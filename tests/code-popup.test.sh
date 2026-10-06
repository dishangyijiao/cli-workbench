#!/usr/bin/env bash
# prefix+e and prefix+g open Neovim in a popup over the current pane: e to browse the project, g to review what the
# branch changed. The popup script runs against stubs of nvim and tmux; the review module (lua/git/changes.lua) runs in
# a headless Neovim against a real repository, with Telescope replaced by a stub. No plugin is installed.
set -u
WB_SRC=$(cd "$(dirname "$0")/.." && pwd)
. "$WB_SRC/tests/harness.sh"
if ! command -v git >/dev/null; then echo "git not installed; skipped"; exit 0; fi
T_DIR=$(cd -P "$(mktemp -d)" && pwd)
trap t_cleanup EXIT
POPUP=$WB_SRC/home/dot_tmux/scripts/executable_code-popup.sh
LUA=$WB_SRC/home/dot_config/nvim/lua

# Stubs: nvim prints where it runs and its arguments; tmux answers display-message with $STUB_DIR, the pane's directory.
mkdir -p "$T_DIR/bin"
cat > "$T_DIR/bin/nvim" <<'SH'
#!/bin/sh
printf 'cwd=%s\n' "$PWD"; for a in "$@"; do printf 'arg=%s\n' "$a"; done
SH
cat > "$T_DIR/bin/tmux" <<'SH'
#!/bin/sh
[ "$1" = display-message ] && printf '%s\n' "$STUB_DIR"
SH
chmod +x "$T_DIR/bin/nvim" "$T_DIR/bin/tmux"
popup() { STUB_DIR=$1 PATH="$T_DIR/bin:$PATH" sh "$POPUP" "$2" %7 2>&1 </dev/null; }
g() { git -C "$R" -c user.name=t -c user.email=t@example.invalid "$@" >/dev/null 2>&1; }

R=$T_DIR/repo; mkdir -p "$R"
g init -q; g symbolic-ref HEAD refs/heads/main
echo one > "$R/a.txt"; echo keep > "$R/gone.txt"; g add .; g commit -qm one
fork=$(git -C "$R" rev-parse HEAD)

echo "browse opens Neovim in the pane's directory"
out=$(popup "$R" browse)
assert_contains "nvim runs in the pane's directory" "cwd=$R" "$out"
refute "with no command of its own" grep -q '^arg=' <<<"$out"

echo "changes opens the review list"
out=$(popup "$R" changes)
assert_contains "nvim runs in the pane's directory" "cwd=$R" "$out"
assert_contains "and starts :Changes" "arg=Changes" "$out"

echo "outside a repository there is nothing to review"
mkdir -p "$T_DIR/plain"
out=$(popup "$T_DIR/plain" changes)
assert_contains "it says so" "not a git repository" "$out"
refute "and does not start nvim" grep -q '^cwd=' <<<"$out"

echo "a directory named like a command substitution is just a name"
EVIL=$T_DIR/'$(cd;touch wbmarker)'; mkdir -p "$EVIL"
out=$(HOME=$T_DIR popup "$EVIL" browse)
refute "nothing ran" test -e "$T_DIR/wbmarker"
assert_contains "nvim still opens there" "cwd=$EVIL" "$out"

echo "an unknown mode is refused"
out=$(popup "$R" nonsense); rc=$?
assert_eq "it exits with a usage error" 2 "$rc"
refute "it does not start nvim" grep -q '^cwd=' <<<"$out"

echo "tmux binds prefix+e and prefix+g to the popup, passing only the pane id"
if command -v tmux >/dev/null && command -v chezmoi >/dev/null; then
  H=$T_DIR/home; mkdir -p "$H"; t_render "$H"
  for key in e g; do
    line=$(grep -E "bind $key display-popup" "$H/.tmux.conf")
    assert_contains "prefix+$key opens a popup" "code-popup.sh" "$line"
    refute "prefix+$key passes no directory into the shell" grep -q 'pane_current_path' <<<"$line"
  done
  assert "the script is deployed executable" test -x "$H/.tmux/scripts/code-popup.sh"
else
  echo "  skip  tmux or chezmoi not installed"
fi

echo "the review list: every file the branch changed since it left the default branch"
if command -v nvim >/dev/null; then
  # The branch: a.txt changed in a commit and again uncommitted, b.txt added, gone.txt deleted, new.txt untracked.
  g checkout -qb feature; echo two >> "$R/a.txt"; echo bee > "$R/b.txt"; g add b.txt; g rm -q gone.txt; g commit -qam two
  # A remote whose main is the fork point, and a local main that moved on: the remote's is the base.
  O=$T_DIR/origin.git; git init -q --bare "$O"; g remote add origin "$O"; g push -q origin "$fork:refs/heads/main"; g fetch -q origin
  g checkout -q main; echo local >> "$R/a.txt"; g commit -qam local-only; g checkout -q feature
  echo three >> "$R/a.txt"; echo fresh > "$R/new.txt"
  cat > "$T_DIR/review.lua" <<'LUA'
package.path = arg[1] .. "/?.lua;" .. arg[1] .. "/?/init.lua;" .. package.path
-- Telescope stub: remember the picker, run <CR> on demand.
local picked
package.preload["telescope.pickers"] = function() return { new = function(_, o) return { find = function() picked = o end } end } end
package.preload["telescope.finders"] = function() return { new_table = function(t) return t end } end
package.preload["telescope.config"] = function() return { values = { generic_sorter = function() return {} end } } end
package.preload["telescope.previewers"] = function() return { new_termopen_previewer = function(o) return o end } end
local selected
package.preload["telescope.actions.state"] = function() return { get_selected_entry = function() return selected end } end
package.preload["telescope.actions"] = function()
  local select = { replace = function(self, fn) self.fn = fn end }
  return { select_default = select, close = function() end }
end
local changes = require("git.changes")
print("base " .. changes.base())
local entries = {}
for _, f in ipairs(picked == nil and changes.files(changes.base()) or {}) do
  entries[#entries + 1] = f.path .. (f.untracked and "?" or "") .. (f.deleted and "-" or "")
end
print("files " .. table.concat(entries, " "))
changes.open()
local list = {}
for _, r in ipairs(picked.finder.results) do list[#list + 1] = picked.finder.entry_maker(r).display end
print("list " .. table.concat(list, " | "))
local function preview(i) return table.concat(picked.previewer.get_command(picked.finder.entry_maker(picked.finder.results[i])), " ") end
print("preview1 " .. preview(1))
print("preview3 " .. preview(3))
print("preview4 " .. preview(4))
-- <CR> on a.txt: the file on the right, its version at the fork point on the left, both in diff mode.
local actions = require("telescope.actions")
picked.attach_mappings(0, function() end)
selected = picked.finder.entry_maker(picked.finder.results[1])
actions.select_default.fn(0)
local wins = vim.api.nvim_tabpage_list_wins(0)
local left = vim.api.nvim_win_get_buf(wins[1])
print("windows " .. #wins)
print("diff " .. tostring(vim.wo[wins[1]].diff) .. " " .. tostring(vim.wo[wins[2]].diff))
print("left " .. table.concat(vim.api.nvim_buf_get_lines(left, 0, -1, false), ","))
print("right " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(wins[2])), ":t"))
-- <CR> on the deleted gone.txt: its old content on the left, an empty side on the right.
selected = picked.finder.entry_maker(picked.finder.results[3])
actions.select_default.fn(0)
wins = vim.api.nvim_tabpage_list_wins(0)
local function lines(w) return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false), ",") end
print("deleted windows " .. #wins .. " diff " .. tostring(vim.wo[wins[1]].diff) .. " " .. tostring(vim.wo[wins[2]].diff))
print("deleted left " .. lines(wins[1]) .. " right [" .. lines(wins[2]) .. "] " .. vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(wins[2])):match("[^/]*$"))
LUA
  out=$(cd "$R" && XDG_CONFIG_HOME="$T_DIR/xdg/c" XDG_DATA_HOME="$T_DIR/xdg/d" XDG_STATE_HOME="$T_DIR/xdg/s" \
    XDG_CACHE_HOME="$T_DIR/xdg/k" nvim --headless -u NONE -l "$T_DIR/review.lua" "$LUA" 2>&1 | tr -d '\r')
  assert_contains "the base is the fork point with origin/main, not the newer local main" "base $fork" "$out"
  assert_contains "committed, uncommitted, deleted and untracked files are listed" "files a.txt b.txt gone.txt- new.txt?" "$out"
  assert_contains "deleted and untracked files are marked in the list" "list a.txt | b.txt | gone.txt (deleted) | new.txt (untracked)" "$out"
  assert_contains "the preview diffs a file against the fork point" "preview1 git --no-pager diff --color=always $fork -- a.txt" "$out"
  assert_contains "a deleted file's preview is its removal" "preview3 git --no-pager diff --color=always $fork -- gone.txt" "$out"
  assert_contains "and an untracked file shows as all new" "preview4 git --no-pager diff --color=always --no-index -- /dev/null new.txt" "$out"
  assert_contains "<CR> opens the file beside its version at the fork point" "windows 2" "$out"
  assert_contains "both sides are in diff mode" "diff true true" "$out"
  assert_contains "the left side is the fork point's content" "left one" "$out"
  assert_contains "the right side is the file itself" "right a.txt" "$out"
  assert_contains "<CR> on a deleted file opens two sides in diff mode" "deleted windows 2 diff true true" "$out"
  assert_contains "its old content on the left, nothing on the right" "deleted left keep right [] gone.txt (deleted)" "$out"
else
  echo "  skip  nvim not installed"
fi

echo "no extra plugin: the review uses Telescope and Neovim's own diff mode"
refute "diffview.nvim is not configured" grep -q 'diffview' "$WB_SRC/home/dot_config/nvim/lua/plugins/init.lua"
refute "and not pinned" grep -q 'diffview' "$WB_SRC/home/dot_config/nvim/lazy-lock.json"
assert "<leader>gv opens the review list" grep -q "'<leader>gv'" "$WB_SRC/home/dot_config/nvim/lua/git/init.lua"
t_done
