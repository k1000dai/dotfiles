# dotfiles

Kohei の dotfiles です。

現在の主入口は `script/setup.sh` です。セットアップ方式は次の優先順で自動選択されます。

1. `nix` が入っていれば nix backend を選び、`home-manager switch --flake` で適用
2. `nix` が入っていなければ、対応環境かつ `sudo` が使える場合に `multi-user nix` を install するか確認
3. install を選ばない、または `multi-user nix` を使えない環境なら `pixi` ベースの非 sudo フローへ fallback

`script/update.sh` は install を提案しません。`nix` 環境では `flake update + home-manager switch --flake`、`nix` がなければ `pixi` 側の symlink 再生成と `pixi global sync` を実行します。

## 方針

- `nix` が使える環境では `home-manager` を優先する
- 非 sudo 環境では `pixi global` と symlink で運用できるようにする
- 既存ファイルに衝突した場合は `*.bak.<timestamp>` に退避してからリンクする
- macOS / Linux の違いは `home-manager` または `pixi` manifest の差分で吸収する

## 対応環境

| 環境 | system | pixi manifest |
| --- | --- | --- |
| macOS Apple Silicon | `aarch64-darwin` | `config/pixi/manifests/pixi-global.toml` |
| Ubuntu / Linux | `x86_64-linux` | `config/pixi/manifests/pixi-global-linux.toml` |

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

- `uv` を `~/.local/bin` に install
- `pixi` を `~/.pixi/bin` に install
- dotfiles を `~/.config` や `~/.zshrc` / `~/.bashrc` へ symlink
- `~/.pixi/manifests/pixi-global.toml` を repo 内 manifest にリンク
- `pixi global sync` を実行して CLI ツール群を導入
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

常に `pixi` backend を使いたいとき:

```bash
BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

`nix` install を確認なしで試したいとき:

```bash
INSTALL_NIX=1 ./script/setup.sh
```

変更確認だけしたいとき:

```bash
DRY_RUN=1 BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

`uv` / `pixi` の再 install を避けたいとき:

```bash
SKIP_TOOL_INSTALL=1 BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

link の再生成だけ先にやり、`pixi global sync` は後で回したいとき:

```bash
SKIP_PIXI_SYNC=1 BOOTSTRAP_BACKEND=pixi ./script/setup.sh
```

## 更新の反映

dotfiles や依存の更新反映は次です。

```bash
./script/update.sh
```

backend ごとの動作は次の通りです。

- `nix` backend: `nix flake update nixpkgs` のあと `home-manager switch --flake` で再適用
- `pixi` backend: symlink を再生成し、最新 manifest に合わせて `pixi global sync`

`update.sh` は `nix` 未導入時に install 確認を出さず、そのまま `pixi` 側の更新へ進みます。

## Home Manager 前提

nix backend は `home-manager` CLI を前提にします。`setup.sh` 実行時に `home-manager` が見つからない場合は、Home Manager の standalone + flakes の公式手順を確認して導入してから再実行してください。

- Home Manager installation: https://github.com/nix-community/home-manager#installation

`pixi` 側で差分確認だけしたい場合:

```bash
DRY_RUN=1 BOOTSTRAP_BACKEND=pixi ./script/update.sh
```

## pixi global 管理対象

manifest は次にあります。

- `config/pixi/manifests/pixi-global.toml`
- `config/pixi/manifests/pixi-global-linux.toml`

現在は主に以下を `pixi global` で管理します。

- shell / CLI: `fzf`, `ripgrep`, `bat`, `zoxide`, `tmux`, `yazi`, `wget`
- git 周辺: `git`, `git-lfs`, `gh`, `ghq`, `lazygit`
- Python 周辺: `python`, `uv`, `ruff`
- editor / LSP 周辺: `nvim`, `node`, `typescript-language-server`, `clangd`, `vscode-langservers-extracted`

次のようなものは `pixi global` manifest にはまだ寄せていません。

- `rust-analyzer`
- `codex`
- フォントや GUI アプリ
- sudo や system package manager が必要なもの

## npm global 管理対象

`npm -g install` でしか入れられない CLI は次で管理します。

- `config/npm/npm-global-packages.txt`

この manifest は `setup.sh` / `update.sh` から `npm install -g --prefix ~/.local ...` で同期されます。`npm` の default prefix は使わず、`nix` / `pixi` の管理領域を汚さないように `~/.local` へ固定しています。

現在の管理対象:

- `happy`

## 主な管理対象

- `script/setup.sh`: `nix` 優先の統合 bootstrap
- `script/update.sh`: backend に応じた更新反映
- `config/pixi/manifests/`: `pixi global` 用 manifest
- `config/nvim`: Neovim 設定
- `config/lazygit`: Lazygit 設定
- `config/ghostty`: Ghostty 設定
- `config/yabai`: macOS の yabai 設定
- `config/skhd`: macOS の skhd 設定
- `.bashrc`: Bash 設定
- `.zshrc`, `.zshrc.d`: shell 設定
- `.tmux.conf`: tmux 設定

## Nix / Home Manager について

Nix / Home Manager の設定ファイルは引き続き repo に含めています。

- `flake.nix`
- `home.nix`
- `home-darwin.nix`
- `home-linux.nix`

`nix` が使える環境ではこちらが第一経路です。未導入時は `multi-user nix` を優先し、HPC や非 sudo 環境では `pixi` backend を明示的に使うか、`nix` install をスキップして fallback させます。
