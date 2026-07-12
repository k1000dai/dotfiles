# WezTerm 設定を dotfiles で管理する

Date: 2026-07-12
Status: Approved

## 目的

ghostty から WezTerm に乗り換えたため、WezTerm の設定を dotfiles (home-manager) 管理下に置く。
見た目は ghostty 時代の雰囲気 (TokyoNight Night / Fira Code 14pt / 背景透過 0.8 / ピンクカーソル) を踏襲しつつ、WezTerm でしかできない強化 (背景ブラー等) を加える。

## 前提・制約

- WezTerm 本体は Homebrew cask / 手動インストールで、nix 管理しない。dotfiles では config のみ管理する。
- tmux を併用し続けるため、WezTerm 側にペイン分割・タブ操作系のキーバインドは持たせない。tmux の prefix と衝突するバインドを作らない。
- 設定は macOS / Linux 共通で配布する (home.nix の xdg.configFile)。macOS 固有設定は Lua 側で `wezterm.target_triple` により分岐する。

## 設計

### ファイル構成

- `config/wezterm/wezterm.lua` — 単一ファイル、セクションコメントで整理 (~100 行)。
- `home.nix` の `xdg.configFile` に `"wezterm".source = ./config/wezterm;` を追加 (ghostty と同じ方式)。

### wezterm.lua の内容

**外観 (ghostty 踏襲 + 強化):**

- `color_scheme = "Tokyo Night"` (組み込みテーマ)
- フォント: `wezterm.font_with_fallback({ "Fira Code", "Hiragino Sans", "Noto Sans CJK JP" })`、14pt。ligature (calt/liga) は WezTerm デフォルトで有効。日本語フォールバックを明示して豆腐と幅ズレを防ぐ (Hiragino は macOS、Noto は Linux 用。存在しないフォントは警告のみで無視される)。
- 背景: `window_background_opacity = 0.80`、macOS では `macos_window_background_blur = 20` (すりガラス効果)
- カーソル: ブロック点滅、`cursor_bg = "#ff2c6d"` (ピンク)
- `window_decorations = "RESIZE"` (タイトルバー非表示のボーダーレス)
- ウィンドウパディング 0 (ghostty と同じ)
- `hide_tab_bar_if_only_one_tab = true` (tmux 併用のため普段はタブバー非表示)
- `front_end = "WebGpu"`、`max_fps = 120`

**挙動:**

- `use_ime = true` (日本語入力)
- `audible_bell = "Disabled"`
- `scrollback_lines = 10000`
- 終了確認なし (`window_close_confirmation` はデフォルトのまま。tmux がセッションを保持するため深追いしない)

**キーバインド (最小限):**

- `Cmd+K`: スクロールバックとビューポートをクリア
- `Cmd+Shift+B`: 背景透過の ON/OFF トグル (custom event 経由)
- それ以外はデフォルトに任せる。tmux prefix (`C-b` 等) と衝突しない。

## エラーハンドリング / テスト

- Lua 構文チェック: `wezterm` CLI が PATH にないため、`luajit`/`lua` があれば構文チェック、なければ WezTerm GUI 起動時の確認を依頼する。
- `pre-commit run --all-files` を実行する。
- `home-manager switch` (nix run 経由) は適用タイミングをユーザーに委ねる。適用前でも `~/.config/wezterm` に手動 symlink すれば動作確認できる。

## スコープ外

- ステータスバー・カスタムタブ装飾 (tmux 併用のため YAGNI)
- WezTerm 本体の nix パッケージ管理
- tmux / ghostty 設定の変更 (ghostty config は残す)
