# dotfiles

Kohei の dotfiles です。

現在の推奨セットアップは、`nix/home-manager` を前提にせず、`pixi global install` と shell script による symbolic link 作成で完結させる非 sudo 運用です。

`flake.nix` / `home.nix` / `home-darwin.nix` / `home-linux.nix` は引き続き repo に残していますが、日常の bootstrap と反映は `script/hpc-setup.sh` を主に使います。

## 方針

- CLI ツールの導入は `pixi global` を使う
- Python 系の bootstrap には `uv` を使う
- dotfiles の反映は symbolic link で行う
- 既存ファイルに衝突した場合は `*.bak.<timestamp>` に退避してからリンクする
- macOS / Linux で必要な差分は `pixi global` manifest を分けて吸収する

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
./script/hpc-setup.sh
```

このスクリプトは次をまとめて行います。

1. `uv` を `~/.local/bin` にインストール
2. `pixi` を `~/.pixi/bin` にインストール
3. dotfiles を `~/.config` や `~/.zshrc` / `~/.bashrc` へ symlink
4. `~/.pixi/manifests/pixi-global.toml` を repo 内 manifest にリンク
5. `pixi global sync` を実行して CLI ツール群を導入

セットアップ後は新しい shell を開くか、次を実行します。

```bash
source ~/.zshrc
```

## よく使うオプション

変更確認だけしたいとき:

```bash
DRY_RUN=1 ./script/hpc-setup.sh
```

`uv` / `pixi` 自体はすでに入っていて、再 install を避けたいとき:

```bash
SKIP_TOOL_INSTALL=1 ./script/hpc-setup.sh
```

link の再生成だけ先にやり、`pixi global sync` は後で回したいとき:

```bash
SKIP_PIXI_SYNC=1 ./script/hpc-setup.sh
```

## main 更新後の反映

`main` を pull したあとに、manifest や dotfiles の変更をローカルへ反映したいときは、まず次を実行します。

```bash
SKIP_TOOL_INSTALL=1 ./script/hpc-setup.sh
```

これで以下が揃います。

- 追加・更新された dotfiles の symlink を反映
- 最新の pixi global manifest を `~/.pixi/manifests/pixi-global.toml` に反映
- manifest に合わせて `pixi global sync` を実行

差分確認だけしたい場合は先にこちらです。

```bash
DRY_RUN=1 SKIP_TOOL_INSTALL=1 ./script/hpc-setup.sh
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

## 主な管理対象

- `script/hpc-setup.sh`: 非 sudo bootstrap と symlink 作成
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

Nix / Home Manager の設定ファイルは残しています。

- `flake.nix`
- `home.nix`
- `home-darwin.nix`
- `home-linux.nix`

ただし、今後の通常運用ではこれらを bootstrap の必須経路にはしません。必要になったときだけ参照または再利用する前提です。
