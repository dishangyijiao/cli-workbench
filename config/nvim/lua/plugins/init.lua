-- ~/.config/nvim/lua/plugins/init.lua
-- 简化的插件配置 (使用 Lazy.nvim)

-- 添加重新加载配置的快捷键
vim.keymap.set('n', '<leader>rc', function()
  -- 清除并重新加载所有配置
  for name, _ in pairs(package.loaded) do
    if name:match('^lsp') or name:match('^plugins') or name:match('^ui') then
      package.loaded[name] = nil
    end
  end
  
  -- 重新加载 init.lua
  dofile(vim.fn.stdpath('config') .. '/init.lua')
  
  -- 通知用户
  vim.notify('Neovim 配置已重新加载', vim.log.levels.INFO)
end, { desc = '重新加载 Neovim 配置' })

-- 确保 Ruby 文件类型被正确识别
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.rb", "*.rake", "Rakefile", "Gemfile", "*.gemspec", "*.ru" },
  callback = function()
    vim.bo.filetype = "ruby"
  end,
})

-- 添加手动触发 LSP 重新加载的快捷键
vim.keymap.set('n', '<leader>lr', function()
  vim.cmd("LspRestart")
  vim.notify('LSP 服务已重新启动', vim.log.levels.INFO)
end, { desc = '重启 LSP 服务器' })

return {
  -- 核心插件
  { "folke/lazy.nvim", tag = "stable" },
  
  -- tmux 整合插件
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    priority = 500,
    config = function()
      -- 重新绑定清屏快捷键，因为C-l被导航占用
      vim.keymap.set('n', '<leader>l', ':nohlsearch<CR><C-L>', { silent = true, desc = '清除搜索高亮并刷新屏幕' })
    end,
  },
  
  -- 语法高亮
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { 
          -- 配置文件
          "lua", "vim", "vimdoc", "query", 
          -- 后端语言
          "c", "cpp", "python", "go", "java", "ruby", "rust",
          -- 前端语言
          "javascript", "typescript", "html", "css", "scss", "tsx", "json", "yaml",
          -- DevOps 工具
          "dockerfile", "terraform", "hcl", "yaml", "bash", "json", "jsonnet",
          -- 构建工具
          "cmake", "make"
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
        incremental_selection = { enable = true },
      })
    end,
  },
  
  -- LSP支持
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
  },
  
  -- 调试支持
  { "mfussenegger/nvim-dap" },
  { "rcarriga/nvim-dap-ui" },
  { "theHamsta/nvim-dap-virtual-text" },
  
  -- LSP 和 DAP 包管理
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "▲",
            package_uninstalled = "✗"
          }
        }
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        -- 禁用自动安装，根据日志显示 npm 安装失败
        ensure_installed = { },
        -- 注意: 所有服务器均需手动安装
        -- 检查 npm 安装和网络连接后，可以通过以下命令安装：
        -- :MasonInstall html-lsp css-lsp bash-language-server
        -- :MasonInstall jsonls clangd gopls pyright rust-analyzer
        automatic_installation = false, -- 禁用自动安装
      })
    end,
  },
  -- 暂时禁用 mason-nvim-dap 以避免错误
  -- { 
  --   "jay-babu/mason-nvim-dap.nvim",
  --   dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
  --   config = function()
  --     -- 空配置
  --   end,
  -- },
  
  -- 文件树
  {
    "kyazdani42/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        sort_by = "case_sensitive",
        view = { width = 30 },
        renderer = { group_empty = true },
        filters = { dotfiles = false },
        on_attach = function(bufnr)
          local api = require('nvim-tree.api')
          
          -- 自定义按键映射
          local function opts(desc)
            return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
          end
          
          -- 修复Enter键映射，确保它打开文件或目录
          vim.keymap.set('n', '<CR>', api.node.open.edit, opts('Open'))
          vim.keymap.set('n', 'o', api.node.open.edit, opts('Open'))
          vim.keymap.set('n', '<2-LeftMouse>', api.node.open.edit, opts('Open'))
          
          -- 其他有用的键映射
          vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Close Directory'))
          vim.keymap.set('n', 'l', api.node.open.edit, opts('Open'))
          
          -- 添加上下级目录导航快捷键
          -- 进入子目录 (J键)
          vim.keymap.set('n', 'J', function()
            local node = api.tree.get_node_under_cursor()
            if node.type == "directory" then
              -- 直接进入子目录
              api.node.open.edit(node)
              -- 如果是关闭的目录，这会打开它
              -- 如果已经打开，这会进入该目录
              if node.open then
                api.tree.change_root_to_node(node)
              end
            end
          end, opts('进入子目录'))
          
          -- 返回父目录 (K键)
          vim.keymap.set('n', 'K', function()
            -- 切换到父目录
            api.tree.change_root_to_parent()
          end, opts('返回父目录'))
          
          -- 更多快捷导航
          vim.keymap.set('n', 'H', api.tree.change_root_to_parent, opts('Up'))
          vim.keymap.set('n', 'L', api.tree.change_root_to_node, opts('CD'))
          
          -- 其他实用快捷键
          vim.keymap.set('n', 'R', api.tree.reload, opts('刷新'))
          vim.keymap.set('n', 'a', api.fs.create, opts('创建'))
          vim.keymap.set('n', 'd', api.fs.remove, opts('删除'))
          vim.keymap.set('n', 'r', api.fs.rename, opts('重命名'))
          vim.keymap.set('n', 'c', api.fs.copy.node, opts('复制'))
          vim.keymap.set('n', 'p', api.fs.paste, opts('粘贴'))
          vim.keymap.set('n', 'y', api.fs.copy.filename, opts('复制文件名'))
          vim.keymap.set('n', 'Y', api.fs.copy.relative_path, opts('复制相对路径'))
          vim.keymap.set('n', '?', api.tree.toggle_help, opts('帮助'))
        end,
      })
      
      -- 添加打开文件树的快捷键
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = '切换文件树', noremap = true, silent = true })
      vim.keymap.set('n', '<leader>fe', ':NvimTreeFindFile<CR>', { desc = '在文件树中定位当前文件', noremap = true, silent = true })
    end,
  },
  
  -- 状态栏
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "codedark",
          component_separators = { left = "", right = ""},
          section_separators = { left = "", right = ""},
        }
      })
    end,
  },
  
  -- Git支持
  { 
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },
  
  -- 文件查找
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local telescope = require("telescope")
      local keymap = vim.keymap.set
      
      -- 加载扩展
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            width = 0.9,
            height = 0.8,
          },
        },
        extensions = {
          -- 扩展配置
        },
      })
      
      -- 基础文件搜索
      keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "查找文件" })
      keymap("n", "<leader>fp", "<cmd>Telescope find_files<CR>", { desc = "查找文件 (Ctrl+P)" })
      keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "全局搜索" })
      keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "查找缓冲区" })
      
      -- 添加文件内容搜索快捷键（不依赖 LSP）
      keymap("n", "<leader>fw", function()
        -- 获取光标下的单词
        local word = vim.fn.expand("<cword>")
        -- 使用 Telescope grep_string 进行搜索
        require('telescope.builtin').grep_string({ search = word })
      end, { desc = "搜索光标下的单词" })
      
      -- 添加 Ruby 特定的方法搜索
      keymap("n", "<leader>fm", function()
        -- 获取光标下的单词
        local word = vim.fn.expand("<cword>")
        -- 针对 Ruby 方法定义模式进行搜索
        require('telescope.builtin').grep_string({ 
          search = "def\\s+" .. word, 
          use_regex = true 
        })
      end, { desc = "查找 Ruby 方法定义" })
      
      keymap("n", "<leader>fu", function()
        -- 获取光标下的单词
        local word = vim.fn.expand("<cword>")
        -- 搜索方法调用（不带 def 关键字的使用）
        require('telescope.builtin').grep_string({ 
          search = word, 
          grep_open_files = false,
          path_display = { "smart" },
        })
      end, { desc = "查找 Ruby 方法使用" })
      
      -- 添加可视模式下的全局搜索
      keymap("v", "<leader>fs", function()
        -- 获取可视模式下选中的文本
        vim.cmd('noau normal! "vy"')
        local text = vim.fn.getreg('v')
        -- 清理文本
        text = string.gsub(text, "\n", "")
        
        -- 搜索选中的文本
        require('telescope.builtin').grep_string({ 
          search = text,
          word_match = "-w",
          only_sort_text = true,
          grep_open_files = false,
          path_display = { "smart" },
        })
        
        -- 重置寄存器
        vim.fn.setreg('v', {})
      end, { desc = "全局搜索选中文本" })
      
      -- 添加手动输入搜索
      keymap("n", "<leader>fh", function()
        vim.ui.input(
          { prompt = "搜索整个项目: " },
          function(input)
            if input then
              require('telescope.builtin').grep_string({ 
                search = input,
                only_sort_text = true,
                grep_open_files = false,
                path_display = { "smart" },
              })
            end
          end
        )
      end, { desc = "手动输入搜索文本" })
      
      -- 添加符号搜索快捷键
      keymap("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>", { desc = "查找引用" })
      keymap("n", "<leader>fd", "<cmd>Telescope lsp_definitions<CR>", { desc = "查找定义" })
      keymap("n", "<leader>fi", "<cmd>Telescope lsp_implementations<CR>", { desc = "查找实现" })
      keymap("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "查找文档符号" })
      keymap("n", "<leader>ft", "<cmd>Telescope lsp_type_definitions<CR>", { desc = "查找类型定义" })
    end,
  },
  
  -- VSCode Dark主题（C/C++配置）- 高优先级加载
  {
    "tomasiser/vim-code-dark",
    lazy = false,
    priority = 1000,
    config = function()
      -- 配置主题选项
      vim.g.codedark_conservative = false  -- 保持代码高亮的鲜艳色彩
      vim.g.codedark_italics = true        -- 启用斜体
      vim.g.codedark_transparent = false   -- 禁用透明背景
      
      -- 应用主题
      vim.cmd([[colorscheme codedark]])
      
      -- 为C/C++设置特定的高亮
      vim.cmd([[
        augroup cpp_highlights
        autocmd!
        autocmd FileType c,cpp highlight cppSTLtype guifg=#569CD6
        autocmd FileType c,cpp highlight cppSTLnamespace guifg=#4EC9B0
        autocmd FileType c,cpp highlight cppSTLconstant guifg=#4FC1FF
        augroup END
      ]])
    end,
  },
  
  -- Avante.nvim - AI助手
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    opts = {
      provider = "claude",  -- 使用Claude作为提供者
      claude = {
        model = "claude-3-5-sonnet-20240620",  -- 使用支持的Claude模型
        -- 不设置api_key，让用户手动输入
        temperature = 0,
        max_tokens = 4096,
      },
      behaviour = {
        enable_claude_text_editor_tool_mode = true,  -- 启用Claude文本编辑工具模式
      },
      secrets = {
        -- 使用secrets管理API密钥
        backend = "file",  -- 使用文件存储API密钥
        encryption_method = "plain",  -- 简单文本存储
      },
    },
    build = "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- 以下依赖是可选的
      "echasnovski/mini.pick",
      "nvim-telescope/telescope.nvim",
      "hrsh7th/nvim-cmp",
      "ibhagwan/fzf-lua",
      "nvim-tree/nvim-web-devicons",
      {
        -- 支持图片粘贴
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            use_absolute_path = true,
          },
        },
      },
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
    config = function(_, opts)
      -- 设置插件
      require("avante").setup(opts)
      
      -- 添加快捷键
      vim.keymap.set("n", "<leader>aa", function()
        vim.cmd("AvanteToggle")
      end, { desc = "打开 Avante" })
      
      vim.keymap.set("n", "<leader>ac", function()
        vim.cmd("AvanteChat")
      end, { desc = "打开 Avante 聊天" })
      
      vim.keymap.set("v", "<leader>a", function()
        vim.cmd("AvanteSelection")
      end, { desc = "将选中文本发送到 Avante" })
    end,
  },
}
