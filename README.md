# dotfiles

Kohei の Home Manager ベースの dotfiles です。

macOS と Linux の設定を同じ flake で管理し、エディタ、shell 周辺ツール、tmux、lazygit、Ghostty などの設定を Home Manager から適用します。

## 対応環境

| 環境 | system | Home Manager profile |
| --- | --- | --- |
| macOS Apple Silicon | `aarch64-darwin` | `kohei` / `kohei-darwin` |
| Ubuntu / Linux | `x86_64-linux` | `kohei-linux` |

## 前提

Nix の flake 機能を使います。

まだ Nix を入れていない場合は、先に Nix をインストールしてください。インストール済みかは次で確認できます。

```bash
nix --version
```

Home Manager はこの flake の input に含めているため、初回は `nix run nixpkgs#home-manager` 経由で実行できます。初回 switch 後は `home-manager` コマンドが使えるようになります。

## 初回セットアップ

このリポジトリを clone して移動します。

```bash
git clone <this-repository-url> ~/.dotfiles
cd ~/.dotfiles
```

macOS では次を実行します。

```bash
nix run nixpkgs#home-manager -- switch --flake .#kohei
```

Linux では次を実行します。

```bash
nix run nixpkgs#home-manager -- switch --flake .#kohei-linux
```

`kohei` は macOS 向けの profile です。明示したい場合は `kohei-darwin` も同じ macOS 設定を指します。

## 2 回目以降の反映

初回 switch 後は `home-manager` が有効になるので、変更を反映するときは次のように実行します。

macOS:

```bash
home-manager switch --flake .#kohei
```

Linux:

```bash
home-manager switch --flake .#kohei-linux
```

`home-manager switch --flake .` のように profile 名を省略すると、環境によって推論される名前が変わることがあります。このリポジトリでは、意図しない profile を選ばないように `.#kohei` または `.#kohei-linux` を明示する運用にしています。

## switch 前に確認する

いきなり反映せず、まず flake の出力や build 結果を確認できます。

flake の出力確認:

```bash
nix flake show --all-systems --no-write-lock-file
```

macOS の build:

```bash
home-manager build --flake .#kohei
```

Linux の build:

```bash
home-manager build --flake .#kohei-linux
```

Home Manager がまだ入っていない初回前の環境では、`home-manager build` の代わりに次のように実行できます。

macOS:

```bash
nix run nixpkgs#home-manager -- build --flake .#kohei
```

Linux:

```bash
nix run nixpkgs#home-manager -- build --flake .#kohei-linux
```

## flake.lock を更新する

Nixpkgs や Home Manager の input を更新したいときは、次を実行します。

```bash
nix flake update
```

更新後、build で確認してから switch します。

```bash
home-manager build --flake .#kohei
home-manager switch --flake .#kohei
```

Linux の場合は `.#kohei-linux` に置き換えてください。

## 主な管理対象

- `home.nix`: macOS / Linux 共通の Home Manager 設定
- `home-darwin.nix`: macOS 固有の設定
- `home-linux.nix`: Linux 固有の設定
- `config/nvim`: Neovim 設定
- `config/lazygit`: Lazygit 設定
- `config/ghostty`: Ghostty 設定
- `config/yabai`: macOS の yabai 設定
- `config/skhd`: macOS の skhd 設定
- `.tmux.conf`: tmux 設定

## よく使う流れ

設定を編集します。

```bash
nvim home.nix
```

build で確認します。

```bash
home-manager build --flake .#kohei
```

問題なければ switch します。

```bash
home-manager switch --flake .#kohei
```

Linux で作業している場合は、上の `.#kohei` を `.#kohei-linux` に置き換えます。
