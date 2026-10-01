-- ~/.config/nvim/lua/plugins/init.lua
-- Plugin specs for lazy.nvim

vim.keymap.set('n', '<leader>rc', function()
  for name, _ in pairs(package.loaded) do
    if name:match('^lsp') or name:match('^plugins') or name:match('^ui') then
      package.loaded[name] = nil
    end
  end

  dofile(vim.fn.stdpath('config') .. '/init.lua')

  vim.notify('Neovim config reloaded', vim.log.levels.INFO)
end, { desc = 'Reload Neovim config' })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.rb", "*.rake", "Rakefile", "Gemfile", "*.gemspec", "*.ru" },
  callback = function()
    vim.bo.filetype = "ruby"
  end,
})

vim.keymap.set('n', '<leader>lr', function()
  vim.cmd("LspRestart")
  vim.notify('LSP servers restarted', vim.log.levels.INFO)
end, { desc = 'Restart LSP servers' })

return {
  { "folke/lazy.nvim", tag = "stable" },

  -- tmux integration
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    priority = 500,
    config = function()
      -- C-l is taken by pane navigation, so clearing the screen moves to <leader>l
      vim.keymap.set('n', '<leader>l', ':nohlsearch<CR><C-L>', { silent = true, desc = 'Clear search highlight and redraw' })
    end,
  },

  -- Syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          -- Neovim itself
          "lua", "vim", "vimdoc", "query",
          -- Backend
          "c", "cpp", "python", "go", "java", "ruby", "rust",
          -- Frontend
          "javascript", "typescript", "html", "css", "scss", "tsx", "json", "yaml",
          -- DevOps
          "dockerfile", "terraform", "hcl", "yaml", "bash", "json", "jsonnet",
          -- Build tools
          "cmake", "make"
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
        incremental_selection = { enable = true },
      })
    end,
  },

  -- LSP
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

  -- Debugging
  { "mfussenegger/nvim-dap" },
  { "rcarriga/nvim-dap-ui" },
  { "theHamsta/nvim-dap-virtual-text" },

  -- LSP and DAP package manager
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
        -- Nothing is installed automatically (automatic npm installs are unreliable).
        -- Install servers by hand once npm and the network work, for example:
        -- :MasonInstall html-lsp css-lsp bash-language-server
        -- :MasonInstall jsonls clangd gopls pyright rust-analyzer
        ensure_installed = { },
        automatic_installation = false,
      })
    end,
  },
  -- mason-nvim-dap is disabled for now because it raised errors
  -- {
  --   "jay-babu/mason-nvim-dap.nvim",
  --   dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
  --   config = function()
  --   end,
  -- },

  -- File tree
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

          local function opts(desc)
            return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
          end

          vim.keymap.set('n', '<CR>', api.node.open.edit, opts('Open'))
          vim.keymap.set('n', 'o', api.node.open.edit, opts('Open'))
          vim.keymap.set('n', '<2-LeftMouse>', api.node.open.edit, opts('Open'))

          vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Close Directory'))
          vim.keymap.set('n', 'l', api.node.open.edit, opts('Open'))

          -- J: open a closed directory, or make an open one the tree root
          vim.keymap.set('n', 'J', function()
            local node = api.tree.get_node_under_cursor()
            if node.type == "directory" then
              api.node.open.edit(node)
              if node.open then
                api.tree.change_root_to_node(node)
              end
            end
          end, opts('Enter directory'))

          vim.keymap.set('n', 'K', function()
            api.tree.change_root_to_parent()
          end, opts('Go to parent directory'))

          vim.keymap.set('n', 'H', api.tree.change_root_to_parent, opts('Up'))
          vim.keymap.set('n', 'L', api.tree.change_root_to_node, opts('CD'))

          vim.keymap.set('n', 'R', api.tree.reload, opts('Refresh'))
          vim.keymap.set('n', 'a', api.fs.create, opts('Create'))
          vim.keymap.set('n', 'd', api.fs.remove, opts('Delete'))
          vim.keymap.set('n', 'r', api.fs.rename, opts('Rename'))
          vim.keymap.set('n', 'c', api.fs.copy.node, opts('Copy'))
          vim.keymap.set('n', 'p', api.fs.paste, opts('Paste'))
          vim.keymap.set('n', 'y', api.fs.copy.filename, opts('Copy file name'))
          vim.keymap.set('n', 'Y', api.fs.copy.relative_path, opts('Copy relative path'))
          vim.keymap.set('n', '?', api.tree.toggle_help, opts('Help'))
        end,
      })

      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = 'Toggle file tree', noremap = true, silent = true })
      vim.keymap.set('n', '<leader>fe', ':NvimTreeFindFile<CR>', { desc = 'Reveal current file in file tree', noremap = true, silent = true })
    end,
  },

  -- Status line
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

  -- Git
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  -- Fuzzy finding
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local telescope = require("telescope")
      local keymap = vim.keymap.set

      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            width = 0.9,
            height = 0.8,
          },
        },
        extensions = {
        },
      })

      keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
      keymap("n", "<leader>fp", "<cmd>Telescope find_files<CR>", { desc = "Find files (Ctrl+P)" })
      keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Search in project" })
      keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })

      -- Text searches that work without an LSP server
      keymap("n", "<leader>fw", function()
        local word = vim.fn.expand("<cword>")
        require('telescope.builtin').grep_string({ search = word })
      end, { desc = "Search word under cursor" })

      keymap("n", "<leader>fm", function()
        local word = vim.fn.expand("<cword>")
        require('telescope.builtin').grep_string({
          search = "def\\s+" .. word,
          use_regex = true
        })
      end, { desc = "Find Ruby method definition" })

      keymap("n", "<leader>fu", function()
        local word = vim.fn.expand("<cword>")
        require('telescope.builtin').grep_string({
          search = word,
          grep_open_files = false,
          path_display = { "smart" },
        })
      end, { desc = "Find Ruby method usages" })

      keymap("v", "<leader>fs", function()
        vim.cmd('noau normal! "vy"')
        local text = vim.fn.getreg('v')
        text = string.gsub(text, "\n", "")

        require('telescope.builtin').grep_string({
          search = text,
          word_match = "-w",
          only_sort_text = true,
          grep_open_files = false,
          path_display = { "smart" },
        })

        vim.fn.setreg('v', {})
      end, { desc = "Search selected text in project" })

      keymap("n", "<leader>fh", function()
        vim.ui.input(
          { prompt = "Search project: " },
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
      end, { desc = "Search project for typed text" })

      keymap("n", "<leader>fr", "<cmd>Telescope lsp_references<CR>", { desc = "Find references" })
      keymap("n", "<leader>fd", "<cmd>Telescope lsp_definitions<CR>", { desc = "Find definitions" })
      keymap("n", "<leader>fi", "<cmd>Telescope lsp_implementations<CR>", { desc = "Find implementations" })
      keymap("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Find document symbols" })
      keymap("n", "<leader>ft", "<cmd>Telescope lsp_type_definitions<CR>", { desc = "Find type definitions" })
    end,
  },

  -- VS Code Dark color scheme, loaded first so other plugins see it
  {
    "tomasiser/vim-code-dark",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.codedark_conservative = false
      vim.g.codedark_italics = true
      vim.g.codedark_transparent = false

      vim.cmd([[colorscheme codedark]])

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

  -- Avante.nvim: AI assistant
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    opts = {
      provider = "claude",
      claude = {
        model = "claude-3-5-sonnet-20240620",
        -- No api_key here: Avante asks for it
        temperature = 0,
        max_tokens = 4096,
      },
      behaviour = {
        enable_claude_text_editor_tool_mode = true,
      },
      secrets = {
        -- The API key is stored in a plain-text file in Neovim's data directory
        backend = "file",
        encryption_method = "plain",
      },
    },
    build = "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- Optional dependencies below
      "echasnovski/mini.pick",
      "nvim-telescope/telescope.nvim",
      "hrsh7th/nvim-cmp",
      "ibhagwan/fzf-lua",
      "nvim-tree/nvim-web-devicons",
      {
        -- Image pasting
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
      require("avante").setup(opts)

      vim.keymap.set("n", "<leader>aa", function()
        vim.cmd("AvanteToggle")
      end, { desc = "Toggle Avante" })

      vim.keymap.set("n", "<leader>ac", function()
        vim.cmd("AvanteChat")
      end, { desc = "Open Avante chat" })

      vim.keymap.set("v", "<leader>a", function()
        vim.cmd("AvanteSelection")
      end, { desc = "Send selection to Avante" })
    end,
  },
}
