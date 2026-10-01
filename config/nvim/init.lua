-- ~/.config/nvim/init.lua
-- 简化的 Neovim 配置

-- 设置 leader 键（必须在所有快捷键配置之前）
vim.g.mapleader = " "  -- 将 leader 键设置为空格键
vim.g.maplocalleader = ","  -- 将 local leader 键设置为逗号

-- 基本设置
vim.opt.termguicolors = true  -- 启用 24 位颜色
vim.opt.number = true         -- 显示行号
vim.opt.relativenumber = true -- 显示相对行号
vim.opt.expandtab = true      -- 使用空格而不是制表符
vim.opt.shiftwidth = 2        -- 缩进宽度为2
vim.opt.tabstop = 2           -- Tab宽度为2
vim.opt.smartindent = true    -- 智能缩进

-- 字符编码设置（解决中文显示问题）
vim.opt.encoding = "utf-8"     -- 内部使用的编码
vim.opt.fileencoding = "utf-8" -- 写入文件时使用的编码
vim.opt.fencs = "utf-8,ucs-bom,shift-jis,gb18030,gbk,gb2312,cp936" -- 文件编码猜测顺序

-- 安装 lazy.nvim 插件管理器
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 加载精简的插件配置
require("lazy").setup("plugins")

-- 加载核心模块
pcall(require, 'lsp')
pcall(require, 'git')
-- 不在这里加载调试模块，避免循环加载
-- pcall(require, 'dap')