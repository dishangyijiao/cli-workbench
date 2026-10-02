-- ~/.config/nvim/lua/git/gitlab.lua
-- Helpers for the <leader>gm mapping in git/init.lua: a remote URL becomes a GitLab project, and a project becomes a page URL.
-- Every part of the result is checked against what GitLab itself allows. A remote URL, a commit message or a merge request
-- number comes from the repository, so none of them may carry quotes or shell syntax into a URL that is then opened.
local M = {}

-- A GitLab project path: letters, digits, . _ - and / between groups; no "..", no trailing slash, no ".git" suffix.
local function clean_path(path)
  path = path:gsub("/+$", ""):gsub("%.git$", "")
  if path ~= "" and path:match("^[%w._/-]+$") and not path:find("..", 1, true) then
    return path
  end
end

-- "git@host:group/project.git" or "https://[user[:token]@]host[:port]/group/project.git"
-- -> "https://host[:port]", "group/project"; nil when the remote is not one of these or holds anything unexpected.
-- Credentials in the URL are dropped: they must not end up in a browser.
function M.parse_remote(remote_url)
  if type(remote_url) ~= "string" then
    return nil
  end
  local base, path
  local host, ssh_path = remote_url:match("^git@([%w._-]+):(.+)$")
  if host then
    base, path = "https://" .. host, ssh_path
  else
    local rest = remote_url:match("^https://(.+)$")
    if rest then
      rest = rest:gsub("^[^/@]*@", "")
      local authority, https_path = rest:match("^([%w._-]+:?%d*)/(.+)$")
      if authority then
        base, path = "https://" .. authority, https_path
      end
    end
  end
  if not base then
    return nil
  end
  path = clean_path(path)
  if not path then
    return nil
  end
  return base, path
end

-- The merge request page when mr_id ("!123" or "123") is given, else the commit page; nil when a value is not what it
-- should be (a commit is hexadecimal, a merge request number is digits).
function M.page_url(base, path, mr_id, commit)
  if mr_id then
    local number = tostring(mr_id):match("^!?(%d+)$")
    if not number then
      return nil
    end
    return string.format("%s/%s/-/merge_requests/%s", base, path, number)
  end
  if type(commit) == "string" and commit:match("^%x+$") then
    return string.format("%s/%s/-/commit/%s", base, path, commit)
  end
  return nil
end

return M
