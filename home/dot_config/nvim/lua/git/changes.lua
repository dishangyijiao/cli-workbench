-- ~/.config/nvim/lua/git/changes.lua
-- Review what the branch changed: a Telescope list of the files changed since the branch left the default branch
-- (committed, uncommitted, deleted and untracked), with a diff preview. <CR> opens a file in a new tab beside its
-- version at the fork point, in Neovim's own diff mode; a deleted file is its old version beside an empty side.
-- :Changes [base], <leader>gv, and prefix+g in tmux.
local M = {}

local function git(args)
  local out = vim.fn.systemlist(vim.list_extend({ "git" }, args))
  if vim.v.shell_error ~= 0 then return nil end
  return out
end

-- The fork point with the default branch: the remote's when there is one, since a local main may be stale or ahead.
function M.base()
  local refs = {}
  local origin_head = git({ "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD" })
  if origin_head and origin_head[1] then refs[#refs + 1] = origin_head[1] end
  vim.list_extend(refs, { "origin/main", "origin/master", "main", "master" })
  for _, ref in ipairs(refs) do
    if git({ "rev-parse", "-q", "--verify", ref .. "^{commit}" }) then
      local fork = git({ "merge-base", "HEAD", ref })
      if fork and fork[1] then return fork[1] end
    end
  end
  return "HEAD"
end

-- Paths relative to the repository root. A rename is listed as the old path deleted and the new one added.
function M.files(base, top)
  top = top or git({ "rev-parse", "--show-toplevel" })[1]
  local files, seen = {}, {}
  local function add(path, kind)
    if path and path ~= "" and not seen[path] then
      seen[path] = true
      files[#files + 1] = { path = path, deleted = kind == "D" or nil, untracked = kind == "?" or nil }
    end
  end
  for _, line in ipairs(git({ "-C", top, "diff", "--name-status", "--no-renames", base }) or {}) do
    local status, path = line:match("^(%a)%d*\t(.+)$")
    add(path, status)
  end
  for _, path in ipairs(git({ "-C", top, "ls-files", "--others", "--exclude-standard" }) or {}) do add(path, "?") end
  return files
end

-- Fill the current window with a read-only buffer that is not a file.
local function scratch(lines, name, ft)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile, vim.bo.modifiable = "nofile", "wipe", false, false
  vim.bo.filetype = ft
  vim.api.nvim_buf_set_name(0, name)
  vim.cmd("diffthis")
end

-- A new tab: on the right the file, or an empty side for a deleted one; on the left its version at the fork point.
local function show(top, file, base)
  local path = top .. "/" .. file.path
  local old = file.untracked and {} or (git({ "-C", top, "show", base .. ":" .. file.path }) or {})
  local ft = vim.filetype.match({ filename = path }) or ""
  if file.deleted then
    vim.cmd("tabnew")
    scratch({}, file.path .. " (deleted)", ft)
  else
    vim.cmd("tabedit " .. vim.fn.fnameescape(path))
    vim.cmd("diffthis")
  end
  vim.cmd("leftabove vnew")
  scratch(old, file.path .. " @ " .. base:sub(1, 7), ft)
end

function M.open(base)
  local top = git({ "rev-parse", "--show-toplevel" })
  if not top then
    vim.notify("Not a git repository", vim.log.levels.WARN)
    return
  end
  top = top[1]
  base = (base and base ~= "") and base or M.base()
  local files = M.files(base, top)
  if #files == 0 then
    vim.notify("No changes since " .. base:sub(1, 7), vim.log.levels.INFO)
    return
  end
  local actions, state = require("telescope.actions"), require("telescope.actions.state")
  require("telescope.pickers").new({}, {
    prompt_title = "Changes since " .. base:sub(1, 7),
    finder = require("telescope.finders").new_table({
      results = files,
      entry_maker = function(f)
        local mark = (f.deleted and " (deleted)") or (f.untracked and " (untracked)") or ""
        return { value = f, ordinal = f.path, display = f.path .. mark }
      end,
    }),
    sorter = require("telescope.config").values.generic_sorter({}),
    previewer = require("telescope.previewers").new_termopen_previewer({
      cwd = top,
      get_command = function(entry)
        if entry.value.untracked then
          return { "git", "--no-pager", "diff", "--color=always", "--no-index", "--", "/dev/null", entry.value.path }
        end
        return { "git", "--no-pager", "diff", "--color=always", base, "--", entry.value.path }
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then show(top, entry.value, base) end
      end)
      return true
    end,
  }):find()
end

return M
