-- ~/.config/nvim/lua/lsp/init.lua
-- 简化的 LSP 配置

local lspconfig = require('lspconfig')
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- 基本的 LSP 配置
local on_attach = function(client, bufnr)
    local opts = { noremap=true, silent=true, buffer=bufnr }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
end

-- 配置补全
local cmp = require('cmp')
local luasnip = require('luasnip')

cmp.setup({
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    mapping = cmp.mapping.preset.insert({
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
            else
                fallback()
            end
        end, { 'i', 's' }),
        ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end, { 'i', 's' }),
    }),
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
        { name = 'buffer' },
        { name = 'path' },
    })
})

-- 配置语言服务器
-- JavaScript/TypeScript
lspconfig.ts_ls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
})

-- HTML/CSS
lspconfig.html.setup({
    on_attach = on_attach,
    capabilities = capabilities,
})

lspconfig.cssls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
})

-- Ruby
local solargraph_available = vim.fn.executable('solargraph') == 1
if solargraph_available then
    lspconfig.solargraph.setup{
        on_attach = on_attach,
        capabilities = capabilities,
        cmd = { "solargraph", "stdio" }, -- 默认命令，如果使用 rbenv 可以改回原来的配置
        root_dir = lspconfig.util.root_pattern("Gemfile", ".git", ".ruby-version"),
        settings = {
            solargraph = {
                diagnostics = true,
                completion = true,
                definitions = true,
                references = true,
                hover = true,
                rename = true,
                symbols = true,
                flags = {
                    debounce_text_changes = 150,
                }
            }
        }
    }
end

-- Ruby LSP - 新的官方 Ruby LSP
local ruby_lsp_available = vim.fn.executable('ruby-lsp') == 1
if ruby_lsp_available then
    lspconfig.ruby_lsp.setup({
        on_attach = function(client, bufnr)
            on_attach(client, bufnr)
            -- 添加额外的 Rails 项目相关快捷键
            local opts = { noremap=true, silent=true, buffer=bufnr }
            vim.keymap.set('n', '<leader>rf', '<cmd>Telescope lsp_references<CR>', opts)
            vim.keymap.set('n', '<leader>ri', '<cmd>Telescope lsp_implementations<CR>', opts)
        end,
        capabilities = capabilities,
        -- 确保识别所有 Ruby 文件类型
        filetypes = {"ruby", "eruby", "rakefile", "rb", "rake", "gemfile"},
        -- 更智能的项目根目录判断
        root_dir = function(fname)
            return lspconfig.util.root_pattern("Gemfile", ".git", ".ruby-version", "Rakefile")(fname) or
                   lspconfig.util.find_git_ancestor(fname) or
                   vim.fn.getcwd()
        end,
        -- Rails 项目特定的设置
        settings = {
            ruby_lsp = {
                enabledFeatures = {
                    "documentHighlights",
                    "documentSymbols",
                    "foldingRanges",
                    "selectionRanges",
                    "semanticHighlighting",
                    "formatting",
                    "diagnostics",
                },
                formatter = {
                    rubocop = {
                        command = "bundle",
                        args = { "exec", "rubocop", "--autocorrect" }
                    }
                },
                diagnostics = { 
                    rubocop = {
                        command = "bundle",
                        args = { "exec", "rubocop" }
                    }
                }
            }
        }
    })
end

-- Python
local pyright_available = vim.fn.executable('pyright-langserver') == 1 or vim.fn.executable('pyright') == 1
if pyright_available then
    lspconfig.pyright.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
            python = {
                analysis = {
                    autoSearchPaths = true,
                    diagnosticMode = "workspace",
                    useLibraryCodeForTypes = true
                }
            }
        }
    })
end

-- Go
local gopls_available = vim.fn.executable('gopls') == 1
if gopls_available then
    lspconfig.gopls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
            gopls = {
                analyses = {
                    unusedparams = true,
                },
                staticcheck = true,
            },
        },
    })
end

-- C/C++ - 禁用警告提示
-- 如果您将来需要使用 C/C++ 语言服务器，请取消注释以下代码
-- 并运行 :MasonInstall clangd 安装所需服务器

-- 禁用检查和配置，不再显示提示
--[[
local clangd_available = vim.fn.executable('clangd') == 1
if clangd_available then
    lspconfig.clangd.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        cmd = {
            "clangd",
            "--background-index",
            "--suggest-missing-includes",
            "--clang-tidy",
            "--header-insertion=iwyu",
        },
    })
end
--]]

-- Rust
local rust_analyzer_available = vim.fn.executable('rust-analyzer') == 1
if rust_analyzer_available then
    lspconfig.rust_analyzer.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
            ["rust-analyzer"] = {
                assist = {
                    importGranularity = "module",
                    importPrefix = "self",
                },
                cargo = {
                    loadOutDirsFromCheck = true
                },
                procMacro = {
                    enable = true
                },
            }
        }
    })
end

-- Java
local jdtls_available = vim.fn.executable('jdtls') == 1
if jdtls_available then
    lspconfig.jdtls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
    })
end

-- Terraform
local terraformls_available = vim.fn.executable('terraform-ls') == 1
if terraformls_available then
    lspconfig.terraformls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
    })
end

-- Kubernetes/YAML
lspconfig.yamlls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
        yaml = {
            schemas = {
                ["https://raw.githubusercontent.com/instrumenta/kubernetes-json-schema/master/v1.18.0-standalone-strict/all.json"] = "/*.k8s.yaml",
                ["https://raw.githubusercontent.com/docker/compose/master/compose/config/compose_spec.json"] = "/*docker-compose*.{yml,yaml}",
                ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
            },
            format = { enabled = true },
            validate = true,
            completion = true,
        },
    },
})

-- JSON - 禁用警告提示
-- 如果您将来需要使用 JSON 语言服务器，请取消注释以下代码
-- 并运行 :MasonInstall jsonls 安装所需服务器

-- 禁用检查和配置，不再显示提示
--[[
local jsonls_available = vim.fn.executable('vscode-json-language-server') == 1
if jsonls_available then
    lspconfig.jsonls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
            json = {
                schemas = {
                    ["https://json.schemastore.org/package.json"] = "package.json",
                    ["https://json.schemastore.org/tsconfig.json"] = "tsconfig.json",
                    ["https://json.schemastore.org/eslintrc.json"] = ".eslintrc.json",
                    ["https://json.schemastore.org/prettierrc.json"] = ".prettierrc.json",
                },
                validate = { enable = true },
            },
        },
    })
end
--]]

-- Dockerfile
lspconfig.dockerls.setup({
    on_attach = on_attach,
    capabilities = capabilities,
})

-- LSP相关的快捷键配置
vim.keymap.set('n', '<leader>fs', '<cmd>Telescope lsp_document_symbols<CR>', 
  { noremap = true, silent = true, desc = "文档符号搜索" })
vim.keymap.set('n', '<leader>fr', '<cmd>Telescope lsp_references<CR>', 
  { noremap = true, silent = true, desc = "查找引用" })
vim.keymap.set('n', '<leader>fd', '<cmd>Telescope diagnostics<CR>', 
  { noremap = true, silent = true, desc = "文档诊断信息" })
vim.keymap.set('n', '<leader>gd', '<cmd>Telescope lsp_definitions<CR>',
  { noremap = true, silent = true, desc = "转到定义 (Telescope)" })
