-- ~/.config/nvim/lua/git/init.lua
-- Git: gitsigns.nvim and Telescope git pickers

require('gitsigns').setup {
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
  },
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns

    vim.keymap.set('n', '<leader>gj', gs.next_hunk, { buffer = bufnr, desc = 'Next hunk' })
    vim.keymap.set('n', '<leader>gk', gs.prev_hunk, { buffer = bufnr, desc = 'Previous hunk' })
    vim.keymap.set('n', '<leader>gb', gs.blame_line, { buffer = bufnr, desc = 'Blame current line' })
    vim.keymap.set('n', '<leader>gp', gs.preview_hunk, { buffer = bufnr, desc = 'Preview hunk' })
    vim.keymap.set('n', '<leader>gu', gs.reset_hunk, { buffer = bufnr, desc = 'Reset hunk' })
    vim.keymap.set('n', '<leader>gs', gs.stage_hunk, { buffer = bufnr, desc = 'Stage hunk' })
    -- Open the GitLab merge request (or, failing that, the commit) that last changed the current line
    vim.keymap.set('n', '<leader>gm', function()
      local current_line = vim.fn.line('.')
      local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
      if vim.v.shell_error ~= 0 then
        vim.notify("Not in a Git repository", vim.log.levels.ERROR)
        return
      end
      local file_path_cmd = string.format("cd %s && git ls-files --full-name %s",
                                         vim.fn.shellescape(git_root),
                                         vim.fn.shellescape(vim.fn.expand('%:p')))
      local file_path = vim.fn.systemlist(file_path_cmd)[1]
      if not file_path then
        vim.notify("Cannot determine the file path in the repository", vim.log.levels.ERROR)
        return
      end
      local blame_cmd = string.format("cd %s && git blame -L %d,%d --porcelain %s | head -1 | awk '{print $1}'",
                                     vim.fn.shellescape(git_root),
                                     current_line, current_line,
                                     vim.fn.shellescape(file_path))
      local commit_hash = vim.fn.systemlist(blame_cmd)[1]
      if not commit_hash or commit_hash == "0000000000000000000000000000000000000000" then
        vim.notify("The current line is not committed yet", vim.log.levels.WARN)
        return
      end
      -- GitLab merge commits carry "See merge request group/project!123"
      local mr_command = string.format("cd %s && git show -s %s | grep -E 'See merge request [^!]+![0-9]+' | grep -oE '![0-9]+'",
                                      vim.fn.shellescape(git_root),
                                      vim.fn.shellescape(commit_hash))
      local mr_id = vim.fn.systemlist(mr_command)[1]
      local remote_url_cmd = "git config --get remote.origin.url"
      local remote_url = vim.fn.systemlist(remote_url_cmd)[1]
      if not remote_url then
        vim.notify("No remote.origin.url configured", vim.log.levels.ERROR)
        return
      end
      local gitlab_url, project_path
      if remote_url:match("^git@") then
        -- SSH: git@example.com:namespace/project.git
        local domain, path = remote_url:match("git@([^:]+):([^%.]+)")
        if domain and path then
          gitlab_url = "https://" .. domain
          project_path = path
        end
      elseif remote_url:match("^https://") then
        -- HTTPS: https://example.com/namespace/project.git
        gitlab_url, project_path = remote_url:match("(https://[^/]+)/([^%.]+)")
      end
      if not gitlab_url or not project_path then
        vim.notify("Cannot parse the GitLab URL from the remote", vim.log.levels.ERROR)
        return
      end
      project_path = project_path:gsub("%.git$", "")
      local url
      if mr_id then
        url = string.format("%s/%s/-/merge_requests/%s", gitlab_url, project_path, mr_id:sub(2))
        vim.notify("Opening MR " .. mr_id, vim.log.levels.INFO)
      else
        url = string.format("%s/%s/-/commit/%s", gitlab_url, project_path, commit_hash)
        vim.notify("No merge request found, opening the commit", vim.log.levels.INFO)
      end
      local open_cmd
      if vim.fn.has("mac") == 1 then
        open_cmd = "open"
      elseif vim.fn.has("unix") == 1 then
        open_cmd = "xdg-open"
      elseif vim.fn.has("win32") == 1 then
        open_cmd = "start"
      end
      if open_cmd then
        vim.fn.system(string.format("%s '%s'", open_cmd, url))
      else
        vim.notify("Cannot open a browser: " .. url, vim.log.levels.INFO)
      end
    end, { buffer = bufnr, desc = 'Open merge request for current line' })
  end
}

vim.keymap.set('n', '<leader>gc', '<cmd>Telescope git_commits<CR>', { noremap = true, silent = true, desc = 'Git commits' })
vim.keymap.set('n', '<leader>gt', '<cmd>Telescope git_status<CR>', { noremap = true, silent = true, desc = 'Git status' })
vim.keymap.set('n', '<leader>gB', '<cmd>Telescope git_branches<CR>', { noremap = true, silent = true, desc = 'Git branches' })
 