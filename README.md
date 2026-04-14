# dotfiles

Kohei の dotfiles です。

現在の主入口は `script/setup.sh` です。セットアップ方式は次の優先順で自動選択されます。

1. `nix` が入っていれば `home-manager` ベースで適用
2. `nix` が入っていなければ `nix` を single-user で install するか確認
3. `nix` の install を選ばない、または sudo なしで install できない場合は `pixi` ベースの非 sudo フローへ fallback

`script/update.sh` も同じ判定を使います。`nix` 環境では `flake update + home-manager`、`pixi` 環境では symlink 再生成と `pixi global sync` を実行します。

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
- `homeConfigurations.<target>.activationPackage` を build
- `result/activate` を実行して Home Manager 設定を反映

### pixi backend

- `uv` を `~/.local/bin` に install
- `pixi` を `~/.pixi/bin` に install
- dotfiles を `~/.config` や `~/.zshrc` / `~/.bashrc` へ symlink
- `~/.pixi/manifests/pixi-global.toml` を repo 内 manifest にリンク
- `pixi global sync` を実行して CLI ツール群を導入

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

- `nix` backend: `nix flake update nixpkgs` のあと Home Manager を再適用
- `pixi` backend: symlink を再生成し、最新 manifest に合わせて `pixi global sync`

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

`nix` が使える環境ではこちらが第一経路です。HPC や非 sudo 環境では `pixi` backend を明示的に使うか、`nix` install をスキップして fallback させます。
