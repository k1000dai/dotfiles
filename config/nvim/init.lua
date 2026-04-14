-- Main entry for Neovim config (lazy.nvim)

-- Load existing vimscript config (kept as-is for now)
vim.cmd.runtime({ args = { "option.vim" }, bang = true })
vim.cmd.runtime({ args = { "keymap.vim" }, bang = true })

-- Matches previous init.vim
vim.cmd.syntax("enable")
vim.g.rustfmt_autosave = 1

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
