# Neovim Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `config/nvim/` のプラグインをLua製の現行世代実装に置き換え、vimscript設定をLuaに移植する。挙動は現状維持。

**Architecture:** 設定は `~/.dotfiles/config/nvim/` にあり、home-managerの `xdg.configFile."nvim"` で `~/.config/nvim` にリンクされる(nix store経由なので、switchするまで本番には反映されない)。検証はすべて `XDG_CONFIG_HOME=$HOME/.dotfiles/config` を付けてリポジトリの設定を直接読み込ませて行う。プラグインマネージャはlazy.nvim。

**Tech Stack:** Neovim 0.11+, lazy.nvim, neo-tree.nvim, blink.cmp, copilot.lua, mini.pairs

**Spec:** `docs/superpowers/specs/2026-07-12-nvim-modernization-design.md`

## Global Constraints

- 挙動(オプション値・キーマップ・見た目)は現状維持。新機能は追加しない
- `lsp.lua` はcapabilities差し替え・rust format-on-save追加以外変更しない
- Nix側(`home.nix`)は変更しない
- コミットは変更したファイルのみを明示的に `git add <path>` する(`config/claude/settings.json` に未コミットの変更があり、巻き込んではいけない)
- 検証コマンドはすべて `XDG_CONFIG_HOME=$HOME/.dotfiles/config` プレフィックス付きで実行する
- コミットメッセージ末尾: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: option.vim → lua/config/options.lua

**Files:**
- Create: `config/nvim/lua/config/options.lua`
- Modify: `config/nvim/init.lua:1-9`
- Delete: `config/nvim/option.vim`

**Interfaces:**
- Produces: `require("config.options")` — 副作用のみ(オプション設定 + auto-checktime / auto-mkdir のautocmd)。戻り値なし。

- [ ] **Step 1: 現在のオプション値を記録(移植前ベースライン)**

Run:
```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(vim.o.tabstop, vim.o.shiftwidth, vim.o.inccommand, vim.o.updatetime, tostring(vim.o.relativenumber), vim.o.listchars)" +qa 2>&1
```
Expected: `4 4 split 1000 true tab:»-,trail:-,extends:»,precedes:«,nbsp:%,eol:↲`

- [ ] **Step 2: options.lua を作成**

`config/nvim/lua/config/options.lua`:
```lua
-- option.vim からのLua移植。挙動は同一
local opt = vim.opt

-- ######################## 見た目 ########################
opt.termguicolors = true -- True Color対応
opt.title = true -- ターミナルのタブ名に現在編集中のファイル名を設定
opt.number = true -- 行番号を表示する
opt.relativenumber = true -- 行番号を今いる行から相対的に表示する(13ddとかするときに便利)
opt.wrap = true -- 右端まで表示される行を折り返して表示する
opt.showmatch = true -- 括弧入力時の対応する括弧を表示
opt.list = true -- 不可視文字(改行記号など)の可視化
-- デフォルト不可視文字は美しくないのでUnicodeできれいに
opt.listchars = { tab = "»-", trail = "-", extends = "»", precedes = "«", nbsp = "%", eol = "↲" }
opt.matchtime = 3 -- 対応括弧のハイライト表示を3sにする

-- ######################## 検索・置換 ########################
opt.ignorecase = true -- 大文字小文字の区別なく検索する
opt.smartcase = true -- 検索文字列に大文字が含まれている場合は区別して検索する
opt.wrapscan = true -- 検索時に最後まで行ったら最初に戻る
opt.hlsearch = true -- 検索語をハイライト表示
opt.incsearch = true -- 検索文字列入力時に順次対象文字列にヒットさせる
opt.inccommand = "split" -- インタラクティブに変更

-- ######################## インデント ########################
opt.smartindent = true -- オートインデント
opt.expandtab = true -- タブの代わりにスペースを挿入
opt.tabstop = 4 -- スペースn個分で1つのタブとしてカウントするか
opt.softtabstop = 4 -- <tab>を押したとき、n個のスペースを挿入
opt.shiftwidth = 4 -- <Enter>や<<, >>などを押したとき、n個のスペースを挿入

-- ######################## 補完 ########################
opt.wildmode = "list:longest" -- コマンドラインの補完
opt.infercase = true -- 補完時に大文字小文字を区別しない
opt.wildmenu = true -- コマンドの補完を有効に

-- ######################## 操作 ########################
opt.clipboard:append("unnamedplus") -- クリップボードにコピーできるようにする
opt.backspace = { "indent", "eol", "start" } -- backspaceで様々な文字を消せるようにする
opt.hidden = true -- タブを切り替えるときに保存していなくてもOKにする
opt.textwidth = 0 -- 自動改行する文字数

-- ######################## ログ ########################
opt.history = 500 -- 保持するコマンド履歴の数
opt.swapfile = false -- swapファイルを保存しない
opt.undofile = false -- undoファイルを保存しない
opt.backup = false -- backupを保存しない
opt.writebackup = false -- writebackupを保存しない
opt.shada = "" -- shadaファイルに保存しない

-- ######################## 外部変更の自動検知 ########################
opt.autoread = true -- 外部でファイルが変更されたら自動で読み込む
opt.updatetime = 1000 -- CursorHoldイベントの発火を1秒後に(デフォルト4秒)

local checktime = vim.api.nvim_create_augroup("auto-checktime", { clear = true })
-- カーソル停止時・フォーカス復帰時・バッファ切替時にファイル変更をチェック
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusGained", "BufEnter" }, {
  group = checktime,
  command = "checktime",
})

-- ######################## その他 ########################
-- ファイル保存時にディレクトリがなかったら作成するか問う
local auto_mkdir = vim.api.nvim_create_augroup("vimrc-auto-mkdir", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = auto_mkdir,
  callback = function(args)
    local dir = vim.fn.fnamemodify(args.file, ":p:h")
    if vim.fn.isdirectory(dir) == 1 then
      return
    end
    local force = vim.v.cmdbang == 1
    if not force then
      local answer = vim.fn.input(string.format('"%s" does not exist. Create? [y/N]', dir)):lower()
      if answer ~= "y" and answer ~= "ye" and answer ~= "yes" then
        return
      end
    end
    vim.fn.mkdir(dir, "p")
  end,
})
```

- [ ] **Step 3: init.lua の読み込みを差し替え**

`config/nvim/init.lua` の先頭部分を変更。

変更前:
```lua
-- Main entry for Neovim config (lazy.nvim)

-- Load existing vimscript config (kept as-is for now)
vim.cmd.runtime({ args = { "option.vim" }, bang = true })
vim.cmd.runtime({ args = { "keymap.vim" }, bang = true })
```

変更後:
```lua
-- Main entry for Neovim config (lazy.nvim)

require("config.options")
vim.cmd.runtime({ args = { "keymap.vim" }, bang = true })
```

- [ ] **Step 4: option.vim を削除**

```bash
git rm config/nvim/option.vim
```

- [ ] **Step 5: 移植後の値がベースラインと一致することを確認**

Run: Step 1と同じコマンド。
Expected: Step 1と同じ値。ただし `listchars` はLuaのテーブル経由になるため項目の並び順が変わってよい(6項目 tab/trail/extends/precedes/nbsp/eol の内容が一致していること)。

さらにautocmdの存在確認:
```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(#vim.api.nvim_get_autocmds({group='auto-checktime'}), #vim.api.nvim_get_autocmds({group='vimrc-auto-mkdir'}))" +qa 2>&1
```
Expected: `1個以上のautocmd数が2つ表示される(例: 4 1)`。エラー出力がないこと。

- [ ] **Step 6: Commit**

```bash
git add config/nvim/lua/config/options.lua config/nvim/init.lua config/nvim/option.vim
git commit -m "nvim: port option.vim to lua/config/options.lua

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: keymap.vim → lua/config/keymaps.lua

**Files:**
- Create: `config/nvim/lua/config/keymaps.lua`
- Modify: `config/nvim/init.lua`(runtime keymap.vim 行を差し替え、mapleaderを冒頭に)
- Delete: `config/nvim/keymap.vim`

**Interfaces:**
- Consumes: なし(Task 1の `config.options` とは独立)
- Produces: `require("config.keymaps")` — 副作用のみ(グローバルキーマップ設定)。`vim.g.mapleader` は init.lua 冒頭で設定される(plugins.lua の `keys` が `<Leader>` を使うため、lazy.nvim setupより前である必要がある)。

- [ ] **Step 1: keymaps.lua を作成**

`config/nvim/lua/config/keymaps.lua`:
```lua
-- keymap.vim からのLua移植。挙動は同一
-- (mapleader は init.lua 冒頭で設定済み)
local map = vim.keymap.set

-- 入力モード中に素早くjjと入力した場合はESCとみなす(保存も行う)
map("i", "jj", "<Esc>:<C-u>w<CR>", { silent = true })
-- terminalモードからの離脱
map("t", "<Esc>", "<C-\\><C-n>")
map("t", "jj", "<C-\\><C-n>", { silent = true })
-- ESCを2回押すことでハイライトを消す
map("n", "<Esc><Esc>", ":nohlsearch<CR>", { silent = true })

-- ##### ウィンドウ操作系 #####
map("n", "<Leader>v", ":vs<CR>", { silent = true }) -- 縦分割
map("n", "<Leader>s", ":sp<CR>", { silent = true }) -- 横分割
map("n", "<Leader>+", ":vertical resize +5<CR>", { silent = true }) -- 拡大
map("n", "<Leader>-", ":vertical resize -5<CR>", { silent = true }) -- 縮小

-- hjklの方向にカーソルを移動させる
map("n", "<Leader>h", "<C-w>h", { silent = true })
map("n", "<Leader>j", "<C-w>j", { silent = true })
map("n", "<Leader>k", "<C-w>k", { silent = true })
map("n", "<Leader>l", "<C-w>l", { silent = true })

-- ##### 行・列関係 #####
-- 折り返し表示された行を見た目通りに上下移動する
map({ "n", "v" }, "j", "gj")
map({ "n", "v" }, "k", "gk")
```

- [ ] **Step 2: init.lua を変更(mapleader冒頭化 + require差し替え)**

変更前:
```lua
-- Main entry for Neovim config (lazy.nvim)

require("config.options")
vim.cmd.runtime({ args = { "keymap.vim" }, bang = true })
```

変更後:
```lua
-- Main entry for Neovim config (lazy.nvim)

-- leaderをスペースに変更(plugins.lua の keys 解決前に必要)
vim.g.mapleader = " "

require("config.options")
require("config.keymaps")
```

- [ ] **Step 3: keymap.vim を削除**

```bash
git rm config/nvim/keymap.vim
```

- [ ] **Step 4: キーマップの存在を確認**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(vim.g.mapleader == ' ', vim.fn.maparg('jj','i'), vim.fn.maparg(' v','n'), vim.fn.maparg('j','n'))" +qa 2>&1
```
Expected: `true <Esc>:<C-U>w<CR> :vs<CR> gj`(表記ゆれ可。空文字列が混ざっていないこと、エラーがないこと)

barbarの `<Leader><Tab>` などプラグイン側 `keys` も leader=Space で解決されていることを確認:
```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(vim.fn.maparg(' <Tab>','n') ~= '')" +qa 2>&1
```
Expected: `true`

- [ ] **Step 5: Commit**

```bash
git add config/nvim/lua/config/keymaps.lua config/nvim/init.lua config/nvim/keymap.vim
git commit -m "nvim: port keymap.vim to lua/config/keymaps.lua

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: NERDTree → neo-tree.nvim

**Files:**
- Modify: `config/nvim/lua/plugins.lua:83-100`(NERDTreeブロックを置き換え)

**Interfaces:**
- Consumes: `<Leader>e`(mapleader=Space、Task 2で設定済み)
- Produces: `:Neotree toggle` にバインドされた `<Leader>e`。NERDTree用autocmdハック(BufEnter/FocusGained での `normal R`)は削除される。

- [ ] **Step 1: plugins.lua のNERDTreeブロックを置き換え**

変更前(`-- UI / Navigation` セクション内):
```lua
    {
        "preservim/nerdtree",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        keys = {
            { "<Leader>e", ":NERDTreeToggle<CR>", silent = true },
        },
        init = function()
            vim.api.nvim_create_autocmd("BufEnter", {
                pattern = "NERD_tree_*",
                command = "normal R",
            })
            vim.api.nvim_create_autocmd("FocusGained", {
                pattern = "NERD_tree_*",
                command = "normal R",
            })
        end,
    },
```

変更後:
```lua
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
```

- [ ] **Step 2: プラグイン同期と起動確認**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(pcall(require, 'neo-tree'))" +qa 2>&1
```
Expected: syncがエラーなく完了し、2つ目のコマンドが `true` を出力。

- [ ] **Step 3: nerdtreeが完全に消えたことを確認**

```bash
grep -i nerdtree config/nvim/lua/plugins.lua config/nvim/init.lua || echo "CLEAN"
```
Expected: `CLEAN`

- [ ] **Step 4: Commit**

```bash
git add config/nvim/lua/plugins.lua
git commit -m "nvim: replace NERDTree with neo-tree.nvim

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: nvim-cmp → blink.cmp

**Files:**
- Modify: `config/nvim/lua/plugins.lua`(Completionブロック全体とLSPブロックのdependencies)
- Modify: `config/nvim/lua/lsp.lua:3-4`(capabilities差し替え)

**Interfaces:**
- Consumes: なし
- Produces: `require("blink.cmp").get_lsp_capabilities()` — lsp.lua が使用。Tab連携チェーン(Task 5でCopilot分岐が追加される)。

- [ ] **Step 1: plugins.lua のCompletionブロックを置き換え**

削除範囲: `plugins.lua` の `-- Completion` コメント直下、`{` `"hrsh7th/nvim-cmp",` で始まるプラグインスペック1個を丸ごと削除する(現在の27〜81行。`dependencies` の cmp-nvim-lsp / cmp-buffer / cmp-path / LuaSnip / cmp_luasnip、`config` 内の `cmp.setup({...})` 全体を含み、対応する閉じ `},` まで)。

その位置に以下を挿入:
```lua
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
```

- [ ] **Step 2: LSPブロックにblink.cmpをdependenciesとして追加**

lsp.lua は nvim-lspconfig の `config`(起動時)で読まれるため、blink.cmpのLuaモジュールが解決できる必要がある。

変更前:
```lua
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        config = function()
            require("lsp")
        end,
    },
```

変更後:
```lua
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        dependencies = { "saghen/blink.cmp" },
        config = function()
            require("lsp")
        end,
    },
```

- [ ] **Step 3: lsp.lua のcapabilitiesを差し替え**

変更前:
```lua
-- Capabilities for nvim-cmp
local capabilities = require("cmp_nvim_lsp").default_capabilities()
```

変更後:
```lua
-- Capabilities for blink.cmp
local capabilities = require("blink.cmp").get_lsp_capabilities()
```

- [ ] **Step 4: 同期と起動確認**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(pcall(function() return require('blink.cmp').get_lsp_capabilities() ~= nil end))" +qa 2>&1
```
Expected: syncエラーなし、`true true` が出力される。

InsertEnterイベントでのエラーがないことも確認:
```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+startinsert" "+lua vim.defer_fn(function() vim.cmd('qa!') end, 500)" 2>&1
```
Expected: エラー出力なし。

- [ ] **Step 5: cmp/LuaSnip参照が残っていないことを確認**

```bash
grep -in "cmp\|luasnip" config/nvim/lua/plugins.lua config/nvim/lua/lsp.lua config/nvim/init.lua | grep -iv "blink" || echo "CLEAN"
```
Expected: `CLEAN`

- [ ] **Step 6: Commit**

```bash
git add config/nvim/lua/plugins.lua config/nvim/lua/lsp.lua
git commit -m "nvim: replace nvim-cmp stack with blink.cmp

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: copilot.vim → copilot.lua(+ blink Tab連携)

**Files:**
- Modify: `config/nvim/lua/plugins.lua`(Copilotブロック置き換え + blink.cmpの`<Tab>`チェーン変更)

**Interfaces:**
- Consumes: Task 4のblink.cmp `<Tab>` キーマップ関数
- Produces: Tabの優先順「補完メニュー選択 > Copilot受け入れ > スニペットジャンプ > フォールバック」

- [ ] **Step 1: Copilotブロックを置き換え**

変更前:
```lua
    -- Copilot
    {
        "github/copilot.vim",
        lazy = false,
    },
```

変更後:
```lua
    -- Copilot
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        opts = {
            suggestion = {
                enabled = true,
                auto_trigger = true, -- copilot.vim同様、入力中に自動でゴーストテキスト表示
                keymap = {
                    accept = false, -- Tabでの受け入れはblink.cmp側のチェーンで処理
                    next = "<M-]>",
                    prev = "<M-[>",
                    dismiss = "<C-]>",
                },
            },
            panel = { enabled = false },
        },
    },
```

- [ ] **Step 2: blink.cmpの`<Tab>`チェーンにCopilot受け入れを追加**

Task 4で入れた `["<Tab>"]` の関数を変更。

変更前:
```lua
                ["<Tab>"] = {
                    function(cmp)
                        if cmp.is_visible() then
                            return cmp.select_next()
                        end
                    end,
                    "snippet_forward",
                    "fallback",
                },
```

変更後:
```lua
                ["<Tab>"] = {
                    function(cmp)
                        if cmp.is_visible() then
                            return cmp.select_next()
                        end
                        -- 補完メニューが出ていなければCopilotのゴーストテキストを受け入れる
                        local ok, suggestion = pcall(require, "copilot.suggestion")
                        if ok and suggestion.is_visible() then
                            suggestion.accept()
                            return true
                        end
                    end,
                    "snippet_forward",
                    "fallback",
                },
```

- [ ] **Step 3: 同期と起動確認**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(pcall(require, 'copilot'))" +qa 2>&1
```
Expected: syncエラーなし、`true` が出力される。

注意: copilot.luaの認証はcopilot.vimと共有される(`~/.config/github-copilot/`)。ただし本検証は `XDG_CONFIG_HOME` を差し替えているため、headlessでは認証状態の確認はしない(最終検証タスクで対話的に確認)。

- [ ] **Step 4: copilot.vim参照が残っていないことを確認**

```bash
grep -n "copilot.vim\|github/copilot" config/nvim/lua/plugins.lua || echo "CLEAN"
```
Expected: `CLEAN`

- [ ] **Step 5: Commit**

```bash
git add config/nvim/lua/plugins.lua
git commit -m "nvim: replace copilot.vim with copilot.lua

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: lexima.vim → mini.pairs

**Files:**
- Modify: `config/nvim/lua/plugins.lua`(Editing helpersブロック)

**Interfaces:**
- Consumes: なし
- Produces: InsertEnterで括弧・クォートの自動補完

- [ ] **Step 1: leximaブロックを置き換え**

変更前:
```lua
    -- Editing helpers
    {
        "cohama/lexima.vim",
        event = "InsertEnter",
    },
```

変更後:
```lua
    -- Editing helpers
    {
        "echasnovski/mini.pairs",
        version = "*",
        event = "InsertEnter",
        opts = {},
    },
```

- [ ] **Step 2: 同期と動作確認**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless "+Lazy! sync" +qa 2>&1 | tail -5
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua vim.api.nvim_feedkeys('i(', 'x', false); print(vim.api.nvim_get_current_line())" +qa 2>&1
```
Expected: syncエラーなし。2つ目は `()` が出力される(自動で閉じ括弧が入る)。feedkeysの挙動がheadlessで不安定な場合は `+lua print(pcall(require, 'mini.pairs'))` が `true` になることの確認で代替してよい。

- [ ] **Step 3: Commit**

```bash
git add config/nvim/lua/plugins.lua
git commit -m "nvim: replace lexima.vim with mini.pairs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: rust.vim削除 + rust format-on-save

**Files:**
- Modify: `config/nvim/lua/plugins.lua`(Languagesブロック削除)
- Modify: `config/nvim/init.lua:9`(`vim.g.rustfmt_autosave = 1` 削除)
- Modify: `config/nvim/lua/lsp.lua`(末尾にrust format-on-save autocmd追加)

**Interfaces:**
- Consumes: rust_analyzer(lsp.luaで既に有効化済み、バイナリがあれば)
- Produces: `*.rs` 保存時のLSPフォーマット(rustfmt_autosave=1 の代替)

- [ ] **Step 1: plugins.lua からrust.vimブロックを削除**

削除対象:
```lua
    -- Languages
    {
        "rust-lang/rust.vim",
        ft = { "rust" },
    },
```

- [ ] **Step 2: init.lua から rustfmt_autosave を削除**

変更前:
```lua
-- Matches previous init.vim
vim.cmd.syntax("enable")
vim.g.rustfmt_autosave = 1
```

変更後:
```lua
-- Matches previous init.vim
vim.cmd.syntax("enable")
```

- [ ] **Step 3: lsp.lua 末尾にformat-on-saveを追加**

`vim.diagnostic.config({...})` ブロックの後に追加:
```lua

-- rust.vim の rustfmt_autosave 相当: 保存時にrust_analyzer経由でフォーマット
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.rs",
  callback = function(args)
    vim.lsp.buf.format({ bufnr = args.buf, async = false })
  end,
})
```

- [ ] **Step 4: 確認**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3
grep -n "rust" config/nvim/lua/plugins.lua config/nvim/init.lua || echo "CLEAN"
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+lua print(#vim.api.nvim_get_autocmds({event='BufWritePre', pattern='*.rs'}))" +qa 2>&1
```
Expected: syncエラーなし、grepは `CLEAN`、autocmd数は `1`。

- [ ] **Step 5: Commit**

```bash
git add config/nvim/lua/plugins.lua config/nvim/init.lua config/nvim/lua/lsp.lua
git commit -m "nvim: drop rust.vim, format rust on save via LSP

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: 最終検証

**Files:**
- なし(検証のみ。問題があれば該当タスクのファイルを修正)

**Interfaces:**
- Consumes: Task 1-7のすべての成果物

- [ ] **Step 1: クリーン起動チェック**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless +qa 2>&1
```
Expected: 2つ目のコマンドは一切出力なし(エラーなし起動)。

- [ ] **Step 2: checkhealth確認**

```bash
XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim --headless \
  "+checkhealth lazy" "+w! /tmp/nvim-health.txt" +qa 2>&1; grep -i "error" /tmp/nvim-health.txt || echo "NO ERRORS"
```
Expected: `NO ERRORS`(warningは許容)

- [ ] **Step 3: 旧ファイル・旧参照の完全削除を確認**

```bash
ls config/nvim/option.vim config/nvim/keymap.vim 2>&1 | grep -c "No such" # Expected: 2
grep -rin "nerdtree\|lexima\|nvim-cmp\|luasnip\|copilot.vim\|rust.vim" config/nvim/ || echo "CLEAN"
```
Expected: `2` と `CLEAN`

- [ ] **Step 4: 対話的スモークテスト(ユーザー確認事項の提示)**

自動化できない確認項目をユーザーに提示する:
1. `XDG_CONFIG_HOME=$HOME/.dotfiles/config nvim` で起動し、`<Space>e` でneo-treeがトグルすること
2. insertモードで補完メニューが出ること、Tab/S-Tabで候補移動、Enterで確定
3. Copilotゴーストテキストが表示され、Tabで受け入れられること(要 `:Copilot auth` 済み)
4. `<Space>ff` でtelescopeが開くこと
5. 問題なければ `home-manager switch` で本番反映

- [ ] **Step 5: 設計書のステータス更新は不要(完了)**
