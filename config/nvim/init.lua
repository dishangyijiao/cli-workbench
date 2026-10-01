-- ~/.config/nvim/init.lua

-- Leader keys must be set before any mapping is defined
vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true

-- Encodings tried in order when reading a file, so CJK files in legacy encodings display correctly
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.fencs = "utf-8,ucs-bom,shift-jis,gb18030,gbk,gb2312,cp936"

-- Bootstrap lazy.nvim
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

require("lazy").setup("plugins")

pcall(require, 'lsp')
pcall(require, 'git')
-- Not loaded here, to avoid a circular require
-- pcall(require, 'dap')
