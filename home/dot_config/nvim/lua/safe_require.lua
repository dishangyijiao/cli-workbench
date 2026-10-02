-- ~/.config/nvim/lua/safe_require.lua
-- require() that says what went wrong. A bare pcall(require, ...) hides every error: one bad line in lsp/init.lua, for example
-- an API that changed after :Lazy update, would silently turn off completion and every language server.
-- "module not found" is the normal state on the first start, before lazy.nvim has installed the plugins, so it is a warning.
return function(name)
  local ok, err = pcall(require, name)
  if ok then
    return true
  end
  local not_installed = tostring(err):find("module '[^']+' not found") ~= nil
  vim.notify(string.format("%s: could not load\n%s", name, tostring(err)),
             not_installed and vim.log.levels.WARN or vim.log.levels.ERROR)
  return false, err
end
