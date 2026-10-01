-- ~/.config/nvim/lua/git/init.lua
-- 简化的 Git 配置

-- 配置 gitsigns.nvim
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

    -- 核心 Git 快捷键
    vim.keymap.set('n', '<leader>gj', gs.next_hunk, { buffer = bufnr, desc = '下一个更改块' })
    vim.keymap.set('n', '<leader>gk', gs.prev_hunk, { buffer = bufnr, desc = '上一个更改块' })
    vim.keymap.set('n', '<leader>gb', gs.blame_line, { buffer = bufnr, desc = '当前行 blame' })
    vim.keymap.set('n', '<leader>gp', gs.preview_hunk, { buffer = bufnr, desc = '预览更改块' })
    vim.keymap.set('n', '<leader>gu', gs.reset_hunk, { buffer = bufnr, desc = '撤销更改块' })
    vim.keymap.set('n', '<leader>gs', gs.stage_hunk, { buffer = bufnr, desc = '暂存更改块' })
    -- 添加跳转到 GitLab MR 的功能
    vim.keymap.set('n', '<leader>gm', function()
      -- 获取当前行的 blame 信息
      -- 使用 blame_line 代替 get_current_line_blame_info
      local current_line = vim.fn.line('.')
      -- 获取 Git 仓库根目录
      local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
      if vim.v.shell_error ~= 0 then
        vim.notify("不在 Git 仓库中", vim.log.levels.ERROR)
        return
      end
      -- 获取当前文件相对于 Git 仓库的路径
      local file_path_cmd = string.format("cd %s && git ls-files --full-name %s",
                                         vim.fn.shellescape(git_root),
                                         vim.fn.shellescape(vim.fn.expand('%:p')))
      local file_path = vim.fn.systemlist(file_path_cmd)[1]
      if not file_path then
        vim.notify("无法获取文件路径", vim.log.levels.ERROR)
        return
      end
      -- 使用 git blame 获取提交哈希
      local blame_cmd = string.format("cd %s && git blame -L %d,%d --porcelain %s | head -1 | awk '{print $1}'",
                                     vim.fn.shellescape(git_root),
                                     current_line, current_line,
                                     vim.fn.shellescape(file_path))
      local commit_hash = vim.fn.systemlist(blame_cmd)[1]
      if not commit_hash or commit_hash == "0000000000000000000000000000000000000000" then
        vim.notify("当前行没有提交记录", vim.log.levels.WARN)
        return
      end
      -- 查找 MR ID (尝试从提交信息中提取)
      local mr_command = string.format("cd %s && git show -s %s | grep -E 'See merge request [^!]+![0-9]+' | grep -oE '![0-9]+'",
                                      vim.fn.shellescape(git_root),
                                      vim.fn.shellescape(commit_hash))
      local mr_id = vim.fn.systemlist(mr_command)[1]
      -- 获取远程仓库 URL
      local remote_url_cmd = "git config --get remote.origin.url"
      local remote_url = vim.fn.systemlist(remote_url_cmd)[1]
      if not remote_url then
        vim.notify("无法获取远程仓库地址", vim.log.levels.ERROR)
        return
      end
      -- 解析仓库信息
      local gitlab_url, project_path
      -- 支持 SSH 和 HTTPS 形式的 GitLab URL
      if remote_url:match("^git@") then
        -- SSH 形式: git@example.com:namespace/project.git
        local domain, path = remote_url:match("git@([^:]+):([^%.]+)")
        if domain and path then
          gitlab_url = "https://" .. domain
          project_path = path
        end
      elseif remote_url:match("^https://") then
        -- HTTPS 形式: https://example.com/namespace/project.git
        gitlab_url, project_path = remote_url:match("(https://[^/]+)/([^%.]+)")
      end
      if not gitlab_url or not project_path then
        vim.notify("无法解析 GitLab 地址", vim.log.levels.ERROR)
        return
      end
      -- 移除尾部的 .git
      project_path = project_path:gsub("%.git$", "")
      local url
      if mr_id then
        -- 如果找到 MR ID，打开 MR 页面
        url = string.format("%s/%s/-/merge_requests/%s", gitlab_url, project_path, mr_id:sub(2))
        vim.notify("打开 MR: " .. mr_id, vim.log.levels.INFO)
      else
        -- 如果没找到 MR ID，打开提交页面
        url = string.format("%s/%s/-/commit/%s", gitlab_url, project_path, commit_hash)
        vim.notify("无法找到相关 MR，打开提交详情", vim.log.levels.INFO)
      end
      -- 打开浏览器
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
        vim.notify("无法打开浏览器: " .. url, vim.log.levels.INFO)
      end
    end, { buffer = bufnr, desc = '打开当前行对应的 MR' })
  end
}

-- Telescope Git 集成
vim.keymap.set('n', '<leader>gc', '<cmd>Telescope git_commits<CR>', { noremap = true, silent = true, desc = 'Git 提交历史' })
vim.keymap.set('n', '<leader>gt', '<cmd>Telescope git_status<CR>', { noremap = true, silent = true, desc = 'Git 文件状态' })
vim.keymap.set('n', '<leader>gB', '<cmd>Telescope git_branches<CR>', { noremap = true, silent = true, desc = 'Git 分支' })
 