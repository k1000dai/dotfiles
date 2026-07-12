-- Main entry for Neovim config (lazy.nvim)

-- leaderをスペースに変更(plugins.lua の keys 解決前に必要)
vim.g.mapleader = " "

require("config.options")
require("config.keymaps")

-- Matches previous init.vim
vim.cmd.syntax("enable")

-- SSH接続時はOSC 52でyankをローカルのクリップボードに転送する
-- (リモートにはローカルのpbcopy/xclip等が無いため、エスケープシーケンス経由で送る)
if vim.env.SSH_TTY then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
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
require("lazy").setup(require("plugins"), {
  checker = { enabled = true },
  change_detection = { notify = false },
  lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
  performance = {
    rtp = {
      reset = false,
    },
  },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "python",
    "c",
    "lua",
    "vim",
    "vimdoc",
    "query",
    "markdown",
  },
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})
