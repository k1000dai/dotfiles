-- LSP Configuration (Neovim 0.11+)

-- Setup mason (LSP installer)
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    "clangd",
    "ty",
    "ruff",
    "ts_ls",
    "html",
    "cssls",
    "jsonls",
    "rust_analyzer",
  },
})

-- Capabilities for nvim-cmp
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- LSP keymaps (set when LSP attaches to buffer)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    local opts = { noremap = true, silent = true, buffer = bufnr }

    -- Hover (was <Leader>info)
    vim.keymap.set("n", "<Leader>info", vim.lsp.buf.hover, opts)

    -- Go to definition (was <Leader>df)
    vim.keymap.set("n", "<Leader>df", vim.lsp.buf.definition, opts)
    -- Go to references (was <Leader>dr)
    vim.keymap.set("n", "<Leader>dr", vim.lsp.buf.references, opts)

    -- Format (was <space>fmt)
    vim.keymap.set("n", "<Leader>fmt", function()
      vim.lsp.buf.format({ async = true })
    end, opts)

    -- Quick fix / Code action (was <space>fx)
    vim.keymap.set("n", "<Leader>fx", vim.lsp.buf.code_action, opts)

    -- Additional useful LSP keymaps
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<Leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  end,
})

-- Configure LSP servers using vim.lsp.config (Neovim 0.11+)
vim.lsp.config("clangd", {
  cmd = { "/opt/homebrew/opt/llvm/bin/clangd" },
  capabilities = capabilities,
})

vim.lsp.config("ty", {
  capabilities = capabilities,
})

vim.lsp.config("ruff", {
  capabilities = capabilities,
})

vim.lsp.config("ts_ls", {
  capabilities = capabilities,
})

vim.lsp.config("html", {
  capabilities = capabilities,
})

vim.lsp.config("cssls", {
  capabilities = capabilities,
})

vim.lsp.config("jsonls", {
  capabilities = capabilities,
})

vim.lsp.config("rust_analyzer", {
  capabilities = capabilities,
})

-- Enable all configured LSP servers
vim.lsp.enable({
  "clangd",
  "ty",
  "ruff",
  "ts_ls",
  "html",
  "cssls",
  "jsonls",
  "rust_analyzer",
})

-- Diagnostic configuration
vim.diagnostic.config({
  virtual_text = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
  update_in_insert = false,
  underline = true,
  severity_sort = true,
})
