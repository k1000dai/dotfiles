-- LSP Configuration (Neovim 0.11+)

-- Capabilities for nvim-cmp
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local servers = {
  { name = "bashls", executable = "bash-language-server" },
  { name = "clangd", executable = "clangd" },
  { name = "dockerls", executable = "docker-langserver" },
  { name = "gopls", executable = "gopls" },
  { name = "lua_ls", executable = "lua-language-server" },
  { name = "marksman", executable = "marksman" },
  { name = "ty", executable = "ty" },
  { name = "ruff", executable = "ruff" },
  { name = "taplo", executable = "taplo" },
  { name = "ts_ls", executable = "typescript-language-server" },
  { name = "html", executable = "vscode-html-language-server" },
  { name = "cssls", executable = "vscode-css-language-server" },
  { name = "jsonls", executable = "vscode-json-language-server" },
  { name = "yamlls", executable = "yaml-language-server" },
  { name = "rust_analyzer", executable = "rust-analyzer" },
}

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

-- Configure LSP servers using vim.lsp.config (Neovim 0.11+).
-- Server binaries are installed by Nix/Home Manager or pixi.
for _, server in ipairs(servers) do
  vim.lsp.config(server.name, {
    capabilities = capabilities,
  })
end

local enabled_servers = {}

for _, server in ipairs(servers) do
  if vim.fn.executable(server.executable) == 1 then
    table.insert(enabled_servers, server.name)
  end
end

if #enabled_servers > 0 then
  vim.lsp.enable(enabled_servers)
end

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
