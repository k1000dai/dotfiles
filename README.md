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

```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

このリポジトリを clone して移動します。

```bash
git clone  ~git@github.com:k1000dai/dotfiles.git /.dotfiles
cd ~/.dotfiles
```

セットアップは次を実行します。

```bash
./script/setup.sh
```

`script/setup.sh` は `uname` で OS を判定し、macOS では `.#kohei`、Ubuntu / Linux では `.#kohei-linux` を自動で選びます。

直接 `home-manager` を実行したい場合は、次の profile を使ってください。

```bash
home-manager switch --flake .#kohei
home-manager switch --flake .#kohei-linux
```

`kohei` は macOS 向けの profile です。明示したい場合は `kohei-darwin` も同じ macOS 設定を指します。


`home-manager switch --flake .` のように profile 名を省略すると、環境によって推論される名前が変わることがあります。このリポジトリでは、意図しない profile を選ばないように `.#kohei` または `.#kohei-linux` を明示する運用にしています。


## flake.lock を更新する

`nixpkgs` input を更新して、そのまま Home Manager を適用したいときは、次を実行します。

```bash
./script/update.sh
```

`script/update.sh` も OS を判定して、対応する Home Manager profile を自動で apply します。

同じ処理を手動で行う場合は、次のように実行できます。

```bash
nix flake update nixpkgs
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

設定をそのまま適用するときは、次を実行します。

```bash
./script/setup.sh
```

`nixpkgs` を更新してから適用したいときは次を使います。

```bash
./script/update.sh
```

手動で build / switch する場合は、macOS では `.#kohei`、Linux では `.#kohei-linux` を指定します。
