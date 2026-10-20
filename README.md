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
- agent hooks: `jq`, `pre-commit` (各 repo の lint / test コマンドは別途その環境で用意)
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

AI CLI は公式が配布する standalone installer で `~/.local/bin` に導入します。いずれも `script/lib/bootstrap-common.sh` にあり、`setup.sh` / `update.sh` の両方から自動で同期されます。installer は一時ファイルへのダウンロードが完了してから実行し、成功・失敗にかかわらず削除します。取得にはリトライとタイムアウトを設定しています。

| CLI | 関数 | installer | 導入先 |
| --- | --- | --- | --- |
| `claude` | `sync_claude_code` | `curl -fsSL https://claude.ai/install.sh \| bash` | `~/.local/bin/claude` |
| `codex` | `sync_codex` | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` | `~/.local/bin/codex` |
| `herdr` | `sync_herdr` | `curl -fsSL https://herdr.dev/install.sh \| sh` | `~/.local/bin/herdr` |

- `@anthropic-ai/claude-code` / `@openai/codex` は npm 側では管理しません (npm 版が残っている場合は各関数が uninstall します)。`config/npm/npm-global-packages.txt` に戻さないでください。
- `codex` / `herdr` は nix (`pkgs.codex` / `pkgs.herdr`) でも入れません。`home.nix` の該当行はコメントアウトしてあります。
- codex installer は `~/.local/bin` が PATH に無いと shell profile (`~/.zprofile` など) に PATH ブロックを追記するため、`sync_codex` は installer 実行前に PATH を通します。また `CODEX_NON_INTERACTIVE=1` を渡してプロンプトを抑止します。
- `claude` は `~/.local/bin/claude` があれば、そのバイナリの `update` を実行します。PATH 上の別のインストールは更新対象にしません。
- `codex` は [公式の更新手順](https://learn.chatgpt.com/docs/codex/cli) と同じく installer を再実行します。
- `herdr` は 2 回目以降、導入先のバイナリで `herdr update` を実行します。[公式の注意事項](https://herdr.dev/docs/install/#update) に従い、PATH 上の別バイナリや package manager を指す symlink は更新対象にせず、導入先が symlink の場合は standalone installer で置き換えます。
- `HERDR_INSTALL_DIR` を指定した場合、インストール・更新の両方で同じディレクトリを使います。更新時も同じ値を指定してください。省略時は `~/.local/bin` です。更新に失敗した場合はエラーを返し、別チャネルへの再インストールは行いません。
- `SKIP_TOOL_INSTALL=1` で 3 CLI のインストール・更新をスキップできます。

### Agent 設定と hooks

macOS / Linux の Home Manager と Linux pixi で同じ設定をリンクします。

- 共通指示は `config/ai-agents/INSTRUCTIONS.md`。Claude Code と Codex の両方で repo の編集を即反映します。
- Claude Code の skills は `~/.claude/skills` にリンクします。アプリが生成する `skills/synced/` は Git の管理対象外です。
- 共通の `sanitize-artifacts` skill は Codex の [ユーザー用 skills ディレクトリ](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills) `~/.agents/skills/sanitize-artifacts` にも個別リンクします。既存の他の skills はそのまま使えます。
- hooks は `~/.claude/hooks/` にファイル単位でリンクします。herdr の生成管理 hook と独自の `pre-commit-stop.sh` を分けています。
- Stop hook はイベントの `cwd` から Git root を解決し、`.pre-commit-config.yaml` と変更がある場合だけ検査します。サブディレクトリからの起動にも対応し、hook による継続時の再帰実行を避けます。

### Agent Observatory: Claude Code / Codex の一元管理

ダッシュボード: <https://agent-observatory-hub.peachy-pony-3346.chatgpt.site>

`script/observatory.py` を Home Manager / Linux pixi の両方で `~/.local/bin/observatory` にリンクします。Python 3.11 以上を使い、追加パッケージは不要です。通常の setup/update はリンクを作るだけで、MCP 登録やログイン、データ送信は行いません。

```bash
# この変更を取り込んで、通常の dotfiles 更新でリンクを反映
./script/update.sh
# 手元にインストールされている両 CLI を登録（片方だけなら setup codex / setup claude）
observatory setup
observatory status
# Codex: ブラウザでサイト所有者のアカウントにログイン
observatory login codex
# Claude Code: 起動後に /mcp → observatory → Authenticate
claude
```

リンク反映前でも `python3 ~/.dotfiles/script/observatory.py setup` で実行できます。CLI が未導入なら通常の setup/update を先に実行してください。

- Codex: `${CODEX_HOME:-~/.codex}/config.toml` に下記の専用テーブルだけを追記します。既存設定は保持し、ファイルは atomic に更新して mode 600 にします。既存の同名接続は検査し、異なる URL / OAuth resource / stdio 設定は上書きしません。symlink や安全に追記できない inline table は手動設定に切り替えます。
- Claude Code: 公式の `claude mcp add --transport http --scope user observatory <URL>` を実行し、全プロジェクトで利用できる user scope に登録します。`~/.claude.json`（`CLAUDE_CONFIG_DIR` 指定時はそのディレクトリ内）の既存接続を保持します。プロジェクト側の同名定義が優先される場合は `/mcp` で実際の接続先を確認してください。
- `observatory status` はローカル設定の確認です。ログイン成功やネットワーク疎通は保証しません。各 CLI を再起動し、「Observatory の list_tasks を呼んで」と依頼して接続を確認してください。認証・CLI バージョン・サイトの利用制限によって接続できない場合があります。Claude Code からの実ログインは未検証です。
- OAuth は各 CLI が管理します。トークン、Cookie、service bypass token、認証済みヘッダーを dotfiles に追加しないでください。サイトは所有者限定のまま使い、接続のために公開しないでください。

Codex の手動設定例（既存の同名テーブルがあればその中に統合し、二重定義しないこと）:

```toml
[mcp_servers.observatory]
url = "https://agent-observatory-hub.peachy-pony-3346.chatgpt.site/mcp"
oauth_resource = "https://agent-observatory-hub.peachy-pony-3346.chatgpt.site/mcp"
enabled_tools = ["register_task", "update_task", "list_tasks"]
```

#### 作業の報告ルール

`observatory setup` は `${XDG_CONFIG_HOME:-~/.config}/observatory/enabled` を作成します。共通指示はこのファイルと接続済み MCP を確認してから、作業を登録・更新します。手動設定した場合は `observatory setup codex` / `observatory setup claude` を実行すると接続を検査して報告を有効化できます。

| タイミング | MCP 操作 |
| --- | --- |
| 新しい作業 | `register_task(title, agent, parent?, detail?)` → 戻り値の ID を保持 |
| 作業開始 | `update_task(id, "running")` |
| 依存関係・判断待ち | `update_task(id, "blocked")` |
| 作業と必要な確認が完了 | `update_task(id, "done")` |
| 子エージェントへ委譲 | 親が `parent=<親ID>` で子タスクを登録し、子にその ID を渡す |

例: 「Observatory に『認証APIの実装』を登録してから作業し、子タスクも親IDで紐づけて。進捗と完了を更新して」。`queued` は登録直後・開始前の状態です。agent 名に `Codex · backend` などの役割を含めると見分けやすくなります。

報告はエージェントが指示に従って MCP を呼ぶ方式です。CLI の全プロセス・全 tool call・クラッシュを自動検出する hooks や、実行停止・コマンド配信は実装していません。既存の herdr / pre-commit hooks は変更しません。切断・認証切れ・中断時は表示が古いまま残る可能性があります。

送信対象は機密性を確認した短いタスク情報のみです。プロンプト全文、会話ログ、コード、diff、環境変数、絶対パス、秘密情報は送信しません。ユーザーや各リポジトリの制約を優先します。MCP が使えない場合は報告の失敗を一度伝えて本来の作業を継続します。

```bash
# 共通指示による報告を停止。再開は observatory setup
observatory disable
# MCP 自体も外す場合（CLI が管理する認証情報の整理は各公式手順に従う）
codex mcp remove observatory
claude mcp remove --scope user observatory
```

`disable` は報告用マーカーだけを削除し、接続設定・ログイン情報は残します。指示を再読込するためエージェントの新しいセッションで反映してください。

公式仕様: [Codex MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)、[Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)、[Claude Code MCP](https://code.claude.com/docs/en/mcp)。

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
| `script/observatory.py` | Observatory の MCP 登録・ログイン補助・報告の有効化 | `~/.local/bin/observatory` (nix / pixi) |
| `script/setup.sh` / `script/update.sh` | 統合 bootstrap / 更新反映 | - |
| `flake.nix`, `home*.nix` | Nix / Home Manager 設定 | `home-manager switch --flake` |
| `config/nvim` | Neovim 設定 | `~/.config/nvim` |
| `config/lazygit` | Lazygit 設定 | `~/.config/lazygit` |
| `config/ghostty` | Ghostty 設定 | `~/.config/ghostty` |
| `config/wezterm` | WezTerm 設定 | `~/.config/wezterm` (nix のみ) |
| `config/herdr/config.toml` | herdr 設定 (本体は `sync_herdr` で導入) | `~/.config/herdr/config.toml` (nix / pixi ともファイル単位リンク。`~/.config/herdr/` はランタイム状態を持つためディレクトリごとリンクしない) |
| `config/yabai` / `config/skhd` | macOS の WM / hotkey | `~/.config/yabai` / `~/.config/skhd` |
| `config/claude/` | Claude Code 設定と hooks | `~/.claude/settings.json`, `~/.claude/hooks/*.sh` (ファイル単位の out-of-store link) |
| `config/ai-agents/` | AI agent 共通指示 (`INSTRUCTIONS.md`) と skills | `~/.claude/CLAUDE.md`, `~/.claude/skills`, `~/.agents/skills/sanitize-artifacts` (out-of-store link) |
| `config/codex/AGENTS.md` | 共通指示 (`config/ai-agents/INSTRUCTIONS.md`) への symlink | `~/.codex/AGENTS.md` (out-of-store link で編集即反映) |
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
bash script/tests/test-bootstrap.sh
bash script/tests/test-agent-hooks.sh
python3 script/tests/test-observatory.py
```

- `nixfmt` (nix ファイル)、`shellcheck` (shell script)、標準 hooks (行末空白・EOF 改行など)
- `nixfmt` / `shellcheck` は nix backend では `home.nix` で導入されます
- Claude Code では、設定ファイルと作業ツリーの変更がある場合に Stop hook が pre-commit を実行します。Codex などではこの hook は動かないため、必要なチェックを別途実行します。
- shell 回帰テストは一時 HOME と mock を使い、installer の失敗・更新先の選択・Linux のリンクと dry-run・Stop hook を検証します。実際のインストールやネットワークアクセスは行いません。

CI (GitHub Actions, `.github/workflows/build.yml`) は push / PR ごとに darwin / linux の `homeConfigurations` をビルドし、依存の破損を早期検知します。

## Nix / Home Manager について

Nix / Home Manager の設定ファイルは引き続き repo に含めています。

- `flake.nix`
- `home.nix`
- `home-darwin.nix`
- `home-linux.nix`

`nix` が使える環境ではこちらが第一経路です。macOS は `multi-user nix` を優先し、Linux の HPC や非 sudo 環境では `pixi` backend を明示的に使うか、`nix` install をスキップして fallback させます。
