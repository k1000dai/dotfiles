# WezTerm Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** WezTerm の設定 (`config/wezterm/wezterm.lua`) を作成し、home-manager 経由で `~/.config/wezterm` に配布する。

**Architecture:** 単一の `wezterm.lua` に外観・挙動・キーバインドをセクション分けして記述。macOS 固有設定 (背景ブラー) は `wezterm.target_triple` で分岐。`home.nix` の `xdg.configFile` に ghostty と同じ方式でエントリを追加する。

**Tech Stack:** WezTerm (Lua 設定), Nix home-manager

## Global Constraints

- WezTerm 本体は Homebrew cask / 手動インストール。nix パッケージは追加しない。
- tmux 併用のため、ペイン分割・タブ操作系キーバインドは作らない。tmux prefix と衝突させない。
- 見た目: Tokyo Night / Fira Code 14pt / 透過 0.80 / ピンクカーソル `#ff2c6d` / パディング 0。
- 設定は macOS / Linux 共通配布 (`home.nix` に追加、darwin 専用ファイルには置かない)。
- このリポジトリに `.pre-commit-config.yaml` は無いため pre-commit は実行不可 (グローバル CLAUDE.md の指示だが対象外)。代わりに Lua 構文チェックを行う。

---

### Task 1: wezterm.lua の作成

**Files:**
- Create: `config/wezterm/wezterm.lua`

**Interfaces:**
- Consumes: なし
- Produces: `~/.config/wezterm/wezterm.lua` として WezTerm が読む設定ファイル。Task 2 が `./config/wezterm` ディレクトリを参照する。

- [ ] **Step 1: 設定ファイルを書く**

```lua
local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

local is_macos = wezterm.target_triple:find("apple-darwin", 1, true) ~= nil

-- Appearance ----------------------------------------------------------------
config.color_scheme = "Tokyo Night"
config.colors = {
  cursor_bg = "#ff2c6d",
  cursor_border = "#ff2c6d",
  cursor_fg = "#1a1b26",
}
config.default_cursor_style = "BlinkingBlock"

config.font = wezterm.font_with_fallback({
  "Fira Code",
  "Hiragino Sans",
  "Noto Sans CJK JP",
})
config.font_size = 14.0

config.window_background_opacity = 0.80
if is_macos then
  config.macos_window_background_blur = 20
end

config.window_decorations = "RESIZE"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

config.front_end = "WebGpu"
config.max_fps = 120

-- Behavior ------------------------------------------------------------------
config.use_ime = true
config.audible_bell = "Disabled"
config.scrollback_lines = 10000

-- Keys ----------------------------------------------------------------------
-- tmux を併用するため分割・タブ系のバインドは持たない
config.keys = {
  { key = "k", mods = "CMD", action = act.ClearScrollback("ScrollbackAndViewport") },
  { key = "b", mods = "CMD|SHIFT", action = act.EmitEvent("toggle-opacity") },
}

wezterm.on("toggle-opacity", function(window, _)
  local overrides = window:get_config_overrides() or {}
  if overrides.window_background_opacity then
    overrides.window_background_opacity = nil
  else
    overrides.window_background_opacity = 1.0
  end
  window:set_config_overrides(overrides)
end)

return config
```

- [ ] **Step 2: Lua 構文チェック**

Run: `nvim --headless "+lua assert(loadfile('/Users/kohei/.dotfiles/config/wezterm/wezterm.lua'))" +q`
Expected: エラー出力なしで終了 (loadfile はパースのみで実行しないので `require("wezterm")` は問題にならない)

- [ ] **Step 3: Commit**

```bash
git -C /Users/kohei/.dotfiles add config/wezterm/wezterm.lua
git -C /Users/kohei/.dotfiles commit -m "add wezterm config"
```

### Task 2: home.nix への登録

**Files:**
- Modify: `home.nix:86-90` (`xdg.configFile` ブロック)

**Interfaces:**
- Consumes: Task 1 の `./config/wezterm` ディレクトリ
- Produces: `home-manager switch` 後に `~/.config/wezterm` symlink

- [ ] **Step 1: xdg.configFile にエントリ追加**

```nix
  xdg.configFile = {
    "nvim".source = ./config/nvim;
    "lazygit".source = ./config/lazygit;
    "ghostty".source = ./config/ghostty;
    "wezterm".source = ./config/wezterm;
  };
```

- [ ] **Step 2: Nix 構文チェック**

Run: `nix-instantiate --parse /Users/kohei/.dotfiles/home.nix > /dev/null`
Expected: エラー出力なし (パースのみ。評価はしない)

- [ ] **Step 3: Commit**

```bash
git -C /Users/kohei/.dotfiles add home.nix docs/superpowers/
git -C /Users/kohei/.dotfiles commit -m "manage wezterm config with home-manager"
```

### Task 3: 動作確認

**Files:** なし (検証のみ)

**Interfaces:**
- Consumes: Task 1, 2 の成果物
- Produces: 動作確認済みの設定

- [ ] **Step 1: home-manager switch の適用**

Run: `nix run home-manager -- switch --flake /Users/kohei/.dotfiles#kohei`
Expected: `~/.config/wezterm/wezterm.lua` が nix store への symlink として存在

適用をユーザーに委ねる場合はスキップし、代わりに手動 symlink での確認を案内:
`ln -s ~/.dotfiles/config/wezterm ~/.config/wezterm`

- [ ] **Step 2: WezTerm で目視確認**

WezTerm を再起動 (または自動リロード) し、以下を確認:
- Tokyo Night 配色 + 透過とブラー
- Fira Code で ligature (`->` `=>` が合字になる)
- 日本語が豆腐にならない
- ピンクのブロックカーソルが点滅
- タブが1つのときタブバー非表示
- `Cmd+Shift+B` で透過トグル、`Cmd+K` でクリア
