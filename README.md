# dotfiles

k1000dai の dotfiles です。

現在の主入口は `script/setup.sh` です。セットアップ方式は次の優先順で自動選択されます。

1. `nix` が入っていれば nix backend を選び、`home-manager switch --flake` で適用
2. `nix` が入っていなければ、対応環境かつ `sudo` が使える場合に `multi-user nix` を install するか確認
3. Linux で install を選ばない、または `multi-user nix` を使えない環境なら `pixi` ベースの非 sudo フローへ fallback

`script/update.sh` は install を提案しません。`nix` 環境では `flake update + home-manager switch --flake` を実行し、Linux で `nix` がなければ `pixi` 側の symlink 再生成と `pixi global sync` を実行します。

## 方針

- `nix` が使える環境では `home-manager` を優先する
- 非 sudo 環境では `pixi global` と symlink で運用できるようにする
- 既存ファイルに衝突した場合は `*.bak.<timestamp>` に退避してからリンクする
- macOS は `nix` / `home-manager` を基本経路にする
- Linux の非 sudo 環境は `pixi global` と symlink で運用できるようにする

## 対応環境

| 環境 | system | backend |
| --- | --- | --- |
| macOS Apple Silicon | `aarch64-darwin` | `nix` / `home-manager` |
| Ubuntu / Linux | `x86_64-linux` | `nix` または `pixi` (`config/pixi/manifests/pixi-global-linux.toml`) |

## 初回セットアップ

この repo を clone して移動します。

```bash
git clone git@github.com:k1000dai/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

初回セットアップは次を実行します。

```bash
./script/setup.sh
```

このスクリプトは backend に応じて次を行います。

### nix backend

- `nix` があればそれを使う
- `home-manager` CLI が必要
- `nix` がなければ、条件を満たすときだけ `multi-user nix` install を提案する
- `home-manager switch --flake ".#<target>"` で Home Manager 設定を反映
- repo 管理の npm global CLI を `~/.local` に同期する

### pixi backend

この repo では `pixi` backend は Linux 向けです。macOS では `nix` / `home-manager` を使います。

- `uv` を `~/.local/bin` に install
- `pixi` を `~/.pixi/bin` に install
- dotfiles を `~/.config` や `~/.zshrc` / `~/.bashrc` / `~/.gitconfig` へ symlink
- `~/.pixi/manifests/pixi-global.toml` を repo 内 manifest にリンク
- `pixi global sync` を実行して CLI ツール群を導入
- `nvim --headless "+Lazy! sync"` を実行して Neovim plugin を同期
- repo 管理の npm global CLI を `~/.local` に同期する

セットアップ後は新しい shell を開くか、必要なら次を実行します。

```bash
source ~/.zshrc
```

## よく使うオプション

`nix` が未導入のとき、確認を出さずに `pixi` へ寄せたいとき:

```bash
INSTALL_NIX=0 ./script/setup.sh
```

Linux で常に `pixi` backend を使いたいとき:

```bash
BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

`nix` install を確認なしで試したいとき:

```bash
INSTALL_NIX=1 ./script/setup.sh
```

Linux の `pixi` フローで変更確認だけしたいとき:

```bash
DRY_RUN=1 BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

Linux の `pixi` フローで `uv` / `pixi` の再 install を避けたいとき:

```bash
SKIP_TOOL_INSTALL=1 BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

Linux の `pixi` フローで link の再生成だけ先にやり、`pixi global sync` は後で回したいとき:

```bash
SKIP_PIXI_SYNC=1 BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

`SKIP_PIXI_SYNC=1` のときは Neovim plugin の headless sync もスキップされます。

## 更新の反映

dotfiles や依存の更新反映は次です。

```bash
./script/update.sh
```

backend ごとの動作は次の通りです。

- `nix` backend: `nix flake update nixpkgs` のあと `home-manager switch --flake` で再適用
- `pixi` backend: Linux で symlink を再生成し、最新 manifest に合わせて `pixi global sync` と Neovim plugin sync

`update.sh` は `nix` 未導入時に install 確認を出しません。Linux ではそのまま `pixi` 側の更新へ進み、macOS では `nix` を用意してから再実行してください。

## Home Manager 前提

nix backend は `home-manager` CLI を前提にします。`setup.sh` 実行時に `home-manager` が見つからない場合は、Home Manager の standalone + flakes の公式手順を確認して導入してから再実行してください。

- Home Manager installation: https://github.com/nix-community/home-manager#installation

`pixi` 側で差分確認だけしたい場合:

```bash
DRY_RUN=1 BOOTSTRAP_BACKEND=pixi ./script/update.sh
```

## pixi global 管理対象

manifest は次にあります。

- `config/pixi/manifests/pixi-global-linux.toml`

現在は主に以下を `pixi global` で管理します。

- shell / CLI: `zsh`, `fzf`, `ripgrep`, `bat`, `zoxide`, `tmux`, `yazi`, `wget`, `pueue`, `fd-find`
- git 周辺: `git`, `git-lfs`, `gh`, `ghq`, `lazygit`
- Python 周辺: `python`, `uv`, `ruff`
- editor / LSP 周辺: `nvim`, `node`, `bash-language-server`, `dockerfile-language-server`, `go`, `gopls`, `lua-language-server`, `marksman`, `taplo`, `ty`, `typescript-language-server`, `clangd`, `vscode-langservers-extracted`, `yaml-language-server`

次のようなものは `pixi global` manifest にはまだ寄せていません。

- `unar` (`conda-forge` に同名 package がないため。必要なら nix 側か system package、または `p7zip` / `libarchive` 系の代替 CLI を使う)
- `rust-analyzer`
- フォントや GUI アプリ
- sudo や system package manager が必要なもの

## npm global 管理対象

`npm -g install` で管理したい CLI は次で管理します。

- `config/npm/npm-global-packages.txt`

この manifest は `setup.sh` / `update.sh` から `npm install -g --prefix ~/.local ...` で同期されます。`npm` の default prefix は使わず、`nix` / `pixi` の管理領域を汚さないように `~/.local` へ固定しています。

現在の管理対象:

- `czg`

## curl installer 管理対象 (AI CLI)

AI CLI は公式が配布する standalone installer で `~/.local/bin` に導入します。どちらも `script/lib/bootstrap-common.sh` にあり、`setup.sh` / `update.sh` の両方から自動で同期されます (installer 自体が最新版の解決と更新を兼ねます)。

| CLI | 関数 | installer | 導入先 |
| --- | --- | --- | --- |
| `claude` | `sync_claude_code` | `curl -fsSL https://claude.ai/install.sh \| bash` | `~/.local/bin/claude` |
| `codex` | `sync_codex` | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` | `~/.local/bin/codex` |

- `@anthropic-ai/claude-code` / `@openai/codex` は npm 側では管理しません (npm 版が残っている場合は各関数が uninstall します)。`config/npm/npm-global-packages.txt` に戻さないでください。
- `codex` は nix (`pkgs.codex`) でも入れません。`home.nix` の該当行はコメントアウトしてあります。
- codex installer は `~/.local/bin` が PATH に無いと shell profile (`~/.zprofile` など) に PATH ブロックを追記するため、`sync_codex` は installer 実行前に PATH を通します。また `CODEX_NON_INTERACTIVE=1` を渡してプロンプトを抑止します。

### Codex pet

Codex desktop の custom pet「ヤチヨ」も `config/codex/pets/` で管理しています (`~/.codex/pets` へ out-of-store link)。

<img src="docs/assets/codex-pet-yachiyo.gif" alt="Codex pet ヤチヨ" width="120">

## uv tool 管理対象

Python 系の standalone CLI は `uv tool` で `~/.local/bin` に導入します。

```bash
uv tool install huggingface_hub
```

- `huggingface_hub` (`hf` コマンド)

## リポジトリ構成

| パス | 内容 | リンク先 / 反映方法 |
| --- | --- | --- |
| `script/setup.sh` / `script/update.sh` | 統合 bootstrap / 更新反映 | - |
| `flake.nix`, `home*.nix` | Nix / Home Manager 設定 | `home-manager switch --flake` |
| `config/nvim` | Neovim 設定 | `~/.config/nvim` |
| `config/lazygit` | Lazygit 設定 | `~/.config/lazygit` |
| `config/ghostty` | Ghostty 設定 | `~/.config/ghostty` |
| `config/wezterm` | WezTerm 設定 | `~/.config/wezterm` (nix のみ) |
| `config/herdr/config.toml` | herdr 設定 | `~/.config/herdr/config.toml` (ファイル単位リンク。`~/.config/herdr/` はランタイム状態を持つためディレクトリごとリンクしない) |
| `config/yabai` / `config/skhd` | macOS の WM / hotkey | `~/.config/yabai` / `~/.config/skhd` |
| `config/claude/` | Claude Code 設定 | `~/.claude/settings.json` は out-of-store link で編集即反映 |
| `config/ai-agents/` | AI agent 共通指示 (`INSTRUCTIONS.md`) と skills | `~/.claude/CLAUDE.md`, `~/.claude/skills` (out-of-store link) |
| `config/codex/AGENTS.md` | 共通指示 (`config/ai-agents/INSTRUCTIONS.md`) への symlink | `~/.codex/AGENTS.md` (nix では Home Manager 再適用で反映) |
| `config/codex/pets/` | Codex desktop の custom pet (`<id>/pet.json` + `spritesheet.webp`) | `~/.codex/pets` (out-of-store link。Codex で作成/再生成した pet はそのまま repo に入る。どの pet を使うかは `~/.codex/config.toml` の `[desktop] selected-avatar-id = "custom:<id>"` で、こちらは未管理) |
| `config/git/shared.gitconfig` | Git 共通設定 (user / alias / ghq / lfs) | nix: `programs.git.includes` / pixi: root `.gitconfig` から include |
| `.gitconfig` | pixi backend 用エントリ (共通設定を include + credential) | `~/.gitconfig` (pixi のみ) |
| `config/pixi/manifests/` | Linux 用 `pixi global` manifest | `~/.pixi/manifests/pixi-global.toml` |
| `config/npm/npm-global-packages.txt` | npm global CLI manifest | `npm install -g --prefix ~/.local` |
| `.zshrc`, `.zshrc.d`, `.bashrc` | shell 設定 | nix: zsh は `.zshrc_extra` 経由 / pixi: 直接リンク |
| `.tmux.conf` | tmux 設定 | `~/.tmux.conf` |
| `keyboard/` | Vial キーボード設定 (cornix) のエクスポート | Vial から手動で読み込み |

## 開発 (lint / CI)

エージェント共通の指示は `config/ai-agents/INSTRUCTIONS.md`、この repo 固有のルールはルートの `AGENTS.md` に記載します。`config/claude/CLAUDE.md` と `config/codex/AGENTS.md` は共通指示への symlink なので、本文は共通ファイルを編集してください。

repo 自体のチェックは pre-commit で行います。

```bash
pre-commit run --all-files
```

- `nixfmt` (nix ファイル)、`shellcheck` (shell script)、標準 hooks (行末空白・EOF 改行など)
- `nixfmt` / `shellcheck` は nix backend では `home.nix` で導入されます
- Claude Code では、設定ファイルと作業ツリーの変更がある場合に Stop hook が pre-commit を実行します。Codex などではこの hook は動かないため、必要なチェックを別途実行します。

CI (GitHub Actions, `.github/workflows/build.yml`) は push / PR ごとに darwin / linux の `homeConfigurations` をビルドし、依存の破損を早期検知します。

## Nix / Home Manager について

Nix / Home Manager の設定ファイルは引き続き repo に含めています。

- `flake.nix`
- `home.nix`
- `home-darwin.nix`
- `home-linux.nix`

`nix` が使える環境ではこちらが第一経路です。macOS は `multi-user nix` を優先し、Linux の HPC や非 sudo 環境では `pixi` backend を明示的に使うか、`nix` install をスキップして fallback させます。
