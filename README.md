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
~/.config/nix/nix.confに

`experimental-features = nix-command flakes`
を追加して、flake を有効にしてください。


## セットアップ
### Home Manager をインストールする

```
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

このリポジトリを clone して移動します。

```bash
git clone  ~git@github.com:k1000dai/dotfiles.git /.dotfiles
cd ~/.dotfiles
```

macOS では次を実行します。

```bash
home-manager switch --flake .#kohei
```

Linux では次を実行します。

```bash
home-manager switch --flake .#kohei-linux
```

`kohei` は macOS 向けの profile です。明示したい場合は `kohei-darwin` も同じ macOS 設定を指します。


`home-manager switch --flake .` のように profile 名を省略すると、環境によって推論される名前が変わることがあります。このリポジトリでは、意図しない profile を選ばないように `.#kohei` または `.#kohei-linux` を明示する運用にしています。


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
