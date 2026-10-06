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
      local gitlab = require('git.gitlab')
      local current_line = vim.fn.line('.')
      -- The repository that holds this file, not the one Neovim happened to be started in
      local git_root = vim.fn.systemlist(string.format("git -C %s rev-parse --show-toplevel",
                                                       vim.fn.shellescape(vim.fn.expand('%:p:h'))))[1]
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
      -- The remote of the repository that holds this file, not of whatever directory Neovim was started in
      local remote_url = vim.fn.systemlist(string.format("git -C %s config --get remote.origin.url",
                                                         vim.fn.shellescape(git_root)))[1]
      if not remote_url then
        vim.notify("No remote.origin.url configured", vim.log.levels.ERROR)
        return
      end
      local gitlab_url, project_path = gitlab.parse_remote(remote_url)
      if not gitlab_url or not project_path then
        vim.notify("Cannot parse the GitLab URL from the remote", vim.log.levels.ERROR)
        return
      end
      local url = gitlab.page_url(gitlab_url, project_path, mr_id, commit_hash)
      if not url then
        vim.notify("Unexpected value in the merge request number or commit; not opening a browser", vim.log.levels.ERROR)
        return
      end
      if mr_id then
        vim.notify("Opening MR " .. mr_id, vim.log.levels.INFO)
      else
        vim.notify("No merge request found, opening the commit", vim.log.levels.INFO)
      end
      -- No shell is involved: the URL is one argument. vim.ui.open exists from Neovim 0.10; before that, run the opener directly.
      if vim.ui.open then
        local _, err = vim.ui.open(url)
        if err then
          vim.notify("Cannot open a browser: " .. err .. "\n" .. url, vim.log.levels.ERROR)
        end
      else
        local opener
        if vim.fn.has("mac") == 1 then
          opener = { "open", url }
        elseif vim.fn.has("unix") == 1 then
          opener = { "xdg-open", url }
        elseif vim.fn.has("win32") == 1 then
          opener = { "cmd", "/c", "start", "", url }
        end
        if opener then
          vim.fn.jobstart(opener, { detach = true })
        else
          vim.notify("Cannot open a browser: " .. url, vim.log.levels.INFO)
        end
      end
    end, { buffer = bufnr, desc = 'Open merge request for current line' })
  end
}

vim.keymap.set('n', '<leader>gc', '<cmd>Telescope git_commits<CR>', { noremap = true, silent = true, desc = 'Git commits' })
vim.keymap.set('n', '<leader>gt', '<cmd>Telescope git_status<CR>', { noremap = true, silent = true, desc = 'Git status' })
vim.keymap.set('n', '<leader>gB', '<cmd>Telescope git_branches<CR>', { noremap = true, silent = true, desc = 'Git branches' })

-- What the branch changed since it left the default branch, with a diff preview (lua/git/changes.lua; prefix+g in tmux)
vim.api.nvim_create_user_command('Changes', function(o) require('git.changes').open(o.args) end,
  { nargs = '?', desc = 'Files changed since the fork point, with a diff preview' })
vim.keymap.set('n', '<leader>gv', '<cmd>Changes<CR>', { noremap = true, silent = true, desc = 'Review branch changes' })
