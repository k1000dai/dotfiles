# Neovim環境モダン化 設計書

日付: 2026-07-12
対象: `config/nvim/`

## 目的

プラグインを現行世代のLua製実装に置き換え、残存するvimscript設定(`option.vim` / `keymap.vim`)をLuaに移植する。キーマップ・オプション・見た目などの**挙動は現状維持**する。

## スコープ外

- Nix(`home.nix` の `programs.neovim.plugins`)とlazy.nvimの二重管理の解消(現状のまま)
- 新機能プラグインの追加(statusline、which-key等は追加しない)
- `lsp.lua` の変更(Neovim 0.11+ の `vim.lsp.config`/`vim.lsp.enable` 方式で既にモダン。blink.cmp向けのcapabilities差し替えのみ)

## プラグイン置き換え

| 現在 | 置き換え後 | 備考 |
|---|---|---|
| preservim/nerdtree | nvim-neo-tree/neo-tree.nvim | `<Space>e` トグル維持。自動リフレッシュ内蔵のため `normal R` のautocmdハック(BufEnter/FocusGained)は削除 |
| hrsh7th/nvim-cmp + cmp-nvim-lsp + cmp-buffer + cmp-path + L3MON4D3/LuaSnip + cmp_luasnip | saghen/blink.cmp | LSP/buffer/path/snippetsソース内蔵。キー操作を現状踏襲: `<Tab>`/`<S-Tab>` 候補移動+スニペットジャンプ、`<C-Space>` 手動補完、`<CR>` 確定、`<C-e>` 中断、`<C-b>`/`<C-f>` ドキュメントスクロール |
| github/copilot.vim | zbirenbaum/copilot.lua | ゴーストテキスト表示は現状通り。Tabの優先順: 補完メニュー選択 > Copilot受け入れ > フォールバック |
| cohama/lexima.vim | mini.pairs (echasnovski/mini.pairs) | 括弧・クォート自動補完のLua製軽量代替 |
| rust-lang/rust.vim | 削除 | 用途は `rustfmt_autosave=1` のみ。rustバッファの `BufWritePre` で `vim.lsp.buf.format`(rust_analyzer経由)に代替 |

維持: catppuccin, plenary, nvim-web-devicons, nvim-lspconfig, telescope, nvim-treesitter, gitsigns, barbar, nvim-scrollbar

## vimscript → Lua移植

- `option.vim` → `lua/config/options.lua`
  - `set ...` を `vim.opt` に変換
  - `auto-checktime` / `vimrc-auto-mkdir` のaugroupを `nvim_create_autocmd` + Lua関数に変換(auto_mkdirの `input()` 確認プロンプトの挙動も維持)
- `keymap.vim` → `lua/config/keymaps.lua`
  - `vim.keymap.set` に変換。`jj` エスケープ、`<Esc><Esc>` ハイライト消去、ウィンドウ操作系、`j`/`k` → `gj`/`gk` をすべて維持
  - `mapleader = " "` はlazy.nvimセットアップ前(init.lua冒頭のrequireより先)に設定
- `init.lua` の整理
  - `vim.cmd.runtime` による vimscript 読み込みを `require("config.options")` / `require("config.keymaps")` に置き換え
  - OSC 52クリップボード設定・lazy.nvim bootstrap・treesitter起動autocmdは維持
  - `vim.cmd.syntax("enable")` は維持、`vim.g.rustfmt_autosave` は削除(rust.vim削除に伴い)
- `option.vim` / `keymap.vim` を削除
- `plugins.lua` は1ファイル構成のまま維持

## 検証方法

1. `XDG_CONFIG_HOME=~/.dotfiles/config nvim --headless "+Lazy! sync" +qa` でプラグイン同期とエラーチェック(home-manager switch不要でリポジトリの設定を直接検証)
2. headless起動でエラーが出ないこと、`:checkhealth` で重大な問題がないこと
3. 主要動作の確認: `<Space>e` でneo-treeトグル、insertモードで補完メニュー表示、Copilotゴーストテキスト、`<Space>ff` telescope、rustファイル保存時フォーマット

## 既知の挙動差分(許容)

- neo-treeのツリー内キー操作はNERDTreeと一部異なる(基本操作 j/k/Enter/a/d は同等)
- blink.cmpの補完メニューの外観が変わる(ドキュメントは自動ポップアップ)
- mini.pairsの括弧補完ルールがleximaと細部で異なる

## リスク

- Copilotの `<Tab>` 受け入れとblink.cmpの `<Tab>` の共存はキー優先順の設定に依存するため、実装時に動作確認必須
- Nix側で `nvim-lspconfig` / `nvim-treesitter` が引き続き注入されるため、lazy.nvim側のバージョンとの混在は現状と同様に残る(今回のスコープ外)
