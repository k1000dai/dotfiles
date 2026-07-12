return {
    -- Colorscheme
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- Core dependencies
    { "nvim-lua/plenary.nvim" },
    { "nvim-tree/nvim-web-devicons" },

    -- LSP
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        dependencies = { "saghen/blink.cmp" },
        config = function()
            require("lsp")
        end,
    },

    -- Completion
    {
        "saghen/blink.cmp",
        version = "1.*",
        event = "InsertEnter",
        opts = {
            keymap = {
                -- nvim-cmp時代の操作感を再現
                preset = "none",
                ["<C-Space>"] = { "show", "fallback" },
                ["<CR>"] = { "accept", "fallback" },
                ["<C-e>"] = { "hide", "fallback" },
                ["<C-b>"] = { "scroll_documentation_up", "fallback" },
                ["<C-f>"] = { "scroll_documentation_down", "fallback" },
                ["<Tab>"] = {
                    function(cmp)
                        if cmp.is_visible() then
                            return cmp.select_next()
                        end
                    end,
                    "snippet_forward",
                    "fallback",
                },
                ["<S-Tab>"] = {
                    function(cmp)
                        if cmp.is_visible() then
                            return cmp.select_prev()
                        end
                    end,
                    "snippet_backward",
                    "fallback",
                },
            },
            completion = {
                documentation = { auto_show = true },
            },
            sources = {
                default = { "lsp", "snippets", "buffer", "path" },
            },
        },
    },

    -- UI / Navigation
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        keys = {
            { "<Leader>e", "<cmd>Neotree toggle<CR>", silent = true },
        },
        opts = {
            filesystem = {
                -- 開いているファイルにツリーを追従させる
                follow_current_file = { enabled = true },
                -- ファイルシステム変更を監視して自動リフレッシュ(NERDTreeのnormal Rハックの代替)
                use_libuv_file_watcher = true,
            },
        },
    },
    {
        "petertriho/nvim-scrollbar",
        config = function()
            require("scrollbar").setup()
        end,
    },

    -- Editing helpers
    {
        "cohama/lexima.vim",
        event = "InsertEnter",
    },

    -- Languages
    {
        "rust-lang/rust.vim",
        ft = { "rust" },
    },

    -- Copilot
    {
        "github/copilot.vim",
        lazy = false,
    },

    -- Telescope
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<Leader>ff", "<cmd>Telescope find_files<CR>", silent = true },
            { "<Leader>fg", "<cmd>Telescope live_grep<CR>",  silent = true },
            { "<Leader>fb", "<cmd>Telescope buffers<CR>",    silent = true },
            { "<Leader>fh", "<cmd>Telescope help_tags<CR>",  silent = true },
        },
    },

    -- Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
    },

    -- Git
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup({
                signs = {
                    add = { text = "┃" },
                    change = { text = "┃" },
                    delete = { text = "_" },
                    topdelete = { text = "‾" },
                    changedelete = { text = "~" },
                    untracked = { text = "┆" },
                },
                signs_staged = {
                    add = { text = "┃" },
                    change = { text = "┃" },
                    delete = { text = "_" },
                    topdelete = { text = "‾" },
                    changedelete = { text = "~" },
                    untracked = { text = "┆" },
                },
                signs_staged_enable = true,
                signcolumn = true,
                numhl = false,
                linehl = false,
                word_diff = false,
                watch_gitdir = { follow_files = true },
                auto_attach = true,
                attach_to_untracked = false,
                current_line_blame = false,
                current_line_blame_opts = {
                    virt_text = true,
                    virt_text_pos = "eol",
                    delay = 1000,
                    ignore_whitespace = false,
                    virt_text_priority = 100,
                    use_focus = true,
                },
                current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
                sign_priority = 6,
                update_debounce = 100,
                status_formatter = nil,
                max_file_length = 40000,
                preview_config = {
                    style = "minimal",
                    relative = "cursor",
                    row = 0,
                    col = 1,
                },
            })
        end,
    },

    -- Buffer/tab line
    {
        "romgrk/barbar.nvim",
        lazy = false,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        keys = {
            { "<Leader><S-Tab>", ":BufferPrevious<CR>", silent = true },
            { "<Leader><Tab>",   ":BufferNext<CR>",     silent = true },
            { "<Leader>q",       ":BufferClose<CR>",    silent = true },
        },
    },
}
