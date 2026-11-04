# dotfiles

k1000dai の dotfiles です。

現在の主入口は `script/setup.sh` です。セットアップ方式は次の優先順で自動選択されます。

1. `nix` が入っていれば nix backend を選び、`home-manager switch --flake` で適用
2. `nix` が入っていなければ、対応環境かつ `sudo` が使える場合に `multi-user nix` を install するか確認
3. Linux で install を選ばない、または `multi-user nix` を使えない環境なら `pixi` ベースの非 sudo フローへ fallback

`script/setup.sh` は初回導入と設定の再適用に使います。既存の `flake.lock` を使い、導入済みの AI CLI や Neovim plugin を更新せず、不足分を導入します。

`script/update.sh` は依存を更新するときに使います。nix の install は提案しません。`nix` 環境では `flake update + home-manager switch --flake` を実行し、Linux で `nix` がなければ `pixi` 側の symlink 再生成と `pixi global sync` を実行します。

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

## 初回セットアップ・設定の再適用

この repo を clone して移動します。

```bash
git clone git@github.com:k1000dai/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

初回セットアップと、取得済みの設定を再適用するときは次を実行します。

```bash
./script/setup.sh
```

このスクリプトは backend に応じて次を行います。

### nix backend

- `nix` があればそれを使う
- `home-manager` CLI が必要
- `nix` がなければ、条件を満たすときだけ `multi-user nix` install を提案する
- lockfile の更新を禁止して `home-manager switch --flake ".#<target>"` で Home Manager 設定を反映
- repo 管理の npm global CLI の不足分を `~/.local` に導入する

### pixi backend

この repo では `pixi` backend は Linux 向けです。macOS では `nix` / `home-manager` を使います。

- `uv` を `~/.local/bin` に install
- `pixi` を `~/.pixi/bin` に install
- dotfiles を `~/.config` や `~/.zshrc` / `~/.bashrc` / `~/.gitconfig` へ symlink
- `~/.pixi/manifests/pixi-global.toml` を repo 内 manifest にリンク
- `pixi global sync` を実行して CLI ツール群を導入
- `nvim --headless "+Lazy! install"` を実行して不足する Neovim plugin を導入
- repo 管理の npm global CLI の不足分を `~/.local` に導入する

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

## 依存の更新

依存を更新したい端末で次を実行します。設定だけの反映には `setup.sh` を使ってください。

```bash
./script/update.sh
```

backend ごとの動作は次の通りです。

- `nix` backend: `nix flake update nixpkgs` のあと `home-manager switch --flake` で再適用
- `pixi` backend: Linux で symlink を再生成し、最新 manifest に合わせて `pixi global sync` と Neovim plugin sync

`update.sh` は `nix` 未導入時に install 確認を出しません。Linux ではそのまま `pixi` 側の更新へ進み、macOS では `nix` を用意してから再実行してください。

複数端末では、Nix の依存更新を一つの変更として検証・共有し、各端末で同じ commit を取得して `setup.sh` を実行します。pixi は manifest に環境を合わせるため、指定が変われば既存環境も変更します。npm の明示バージョン指定も適用対象です。AI CLI の初回導入や各ツール自身の自動更新は別なので、同じ dotfiles commit が全 CLI の同一バージョンを保証するわけではありません。

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

この manifest は `setup.sh` / `update.sh` から `npm install -g --prefix ~/.local ...` で適用されます。`setup.sh` はバージョン無指定の導入済みパッケージを保持し、不足分と明示したバージョン指定を適用します。`update.sh` は manifest 全体を同期します。`npm` の default prefix は使わず、`nix` / `pixi` の管理領域を汚さないように `~/.local` へ固定しています。

現在の管理対象:

- `czg`

## curl installer 管理対象 (AI CLI)

AI CLI は公式が配布する standalone installer で `~/.local/bin` に導入します。いずれも `script/lib/bootstrap-common.sh` にあり、`setup.sh` は既存の CLI を保持して不足分だけを導入し、`update.sh` は導入・更新を行います。installer は一時ファイルへのダウンロードが完了してから実行し、成功・失敗にかかわらず削除します。取得にはリトライとタイムアウトを設定しています。

| CLI | 関数 | installer | 導入先 |
| --- | --- | --- | --- |
| `claude` | `sync_claude_code` | `curl -fsSL https://claude.ai/install.sh \| bash` | `~/.local/bin/claude` |
| `codex` | `sync_codex` | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` | `~/.local/bin/codex` |
| `agy` | `sync_antigravity` | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` | `~/.local/bin/agy` |
| `herdr` | `sync_herdr` | `curl -fsSL https://herdr.dev/install.sh \| sh` | `~/.local/bin/herdr` |
| `reason` | `sync_reason_network` | `curl -fsSL https://reasonmachines.com/install.sh \| bash -s -- network join '<link>'` | `~/.local/bin/reason` |

- `@anthropic-ai/claude-code` / `@openai/codex` は npm 側では管理しません。既存の npm 版から standalone 版への移行は `update.sh` で行います。`config/npm/npm-global-packages.txt` に戻さないでください。
- `codex` / `agy` / `herdr` は nix (`pkgs.codex` / `pkgs.herdr` など) でも入れません。`home.nix` の該当行はコメントアウトしてあります。
- codex installer は `~/.local/bin` が PATH に無いと shell profile (`~/.zprofile` など) に PATH ブロックを追記するため、`sync_codex` は installer 実行前に PATH を通します。また `CODEX_NON_INTERACTIVE=1` を渡してプロンプトを抑止します。
- `update.sh` では、`claude` は `~/.local/bin/claude` があれば、そのバイナリの `update` を実行します。PATH 上の別のインストールは更新対象にしません。
- `update.sh` では、`codex` は [公式の更新手順](https://learn.chatgpt.com/docs/codex/cli) と同じく installer を再実行します。
- `update.sh` では、`agy` (Antigravity CLI) は `~/.local/bin/agy` があれば、そのバイナリの `agy update` を実行します。PATH 上の別バイナリや symlink は更新対象にせず、導入先が symlink の場合は standalone installer で置き換えます。初回は `agy` を対話実行して Google アカウントでログインしてください。
- `update.sh` では、`herdr` は導入先のバイナリで `herdr update` を実行します。[公式の注意事項](https://herdr.dev/docs/install/#update) に従い、PATH 上の別バイナリや package manager を指す symlink は更新対象にせず、導入先が symlink の場合は standalone installer で置き換えます。
- `HERDR_INSTALL_DIR` を指定した場合、インストール・更新の両方で同じディレクトリを使います。更新時も同じ値を指定してください。省略時は `~/.local/bin` です。更新に失敗した場合はエラーを返し、別チャネルへの再インストールは行いません。
- `reason` (Reason Network) の招待リンクは秘密情報で、この repo は public なのでコミットしません。未導入の場合、`setup.sh` を端末から実行すると join link の貼り付けを求めます (Enter でスキップ)。link を受け取ったときだけ installer を実行し、CLI の導入と `reason network join` を行います。`update.sh`、`DRY_RUN=1`、非対話実行では確認しません。事前に渡すこともできます。

  ```bash
  REASON_NETWORK_JOIN_URL='https://reasonmachines.com/network/join/#rn1-...' ./script/setup.sh
  ```

- `reason` 導入済みの場合、`network who --json` で team を確認し、未参加のときだけ `reason network join` を実行します。CLI は Reason Network の background process が 1 日 1 回ほど更新します。`reason update` は desktop components (macOS で約 325 MB) も導入するため使いません。
- `SKIP_TOOL_INSTALL=1` で 5 CLI のインストール・更新をスキップできます。

### Agent 設定と hooks

macOS / Linux の Home Manager と Linux pixi で同じ共通設定を適用します。

- 共通指示は `config/ai-agents/INSTRUCTIONS.md`。Claude Code と Codex の両方で repo の編集を即反映します。
- Claude Code の `settings.json` は `script/lib/sync-claude-settings.sh` で `~/.claude/settings.json` にマージします。共有ファイルに記載したキーを優先し、記載のないローカルキーは保持します。オブジェクトは再帰的にマージし、同じキーの配列は共有値に置き換えます。適用先は書き込み可能な通常ファイルなので、Claude の設定保存で repo が書き換わることはありません。
- 既存の Claude 設定リンクも通常ファイルへ移行します。変更前の内容は `settings.json.bak.<timestamp>` に保存し、同名のバックアップがあれば連番を付けます。内容が変わらない再適用ではバックアップを増やしません。JSON が不正な場合は既存ファイルを変更せず失敗します。
- `autoMode.environment` などの環境情報、project trust、認証情報、端末固有の絶対パスは共通設定に含めません。共有設定に `autoMode.environment` があれば適用を拒否します。プロジェクト固有の設定は各 repo の `.claude/settings.json`、個人的な上書きは Git 管理外の `.claude/settings.local.json` を使います。
- Claude Code の skills は `~/.claude/skills` にリンクします。アプリが生成する `skills/synced/` は Git の管理対象外です。
- 共通の `sanitize-artifacts` skill は Codex の [ユーザー用 skills ディレクトリ](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills) `~/.agents/skills/sanitize-artifacts` にも個別リンクします。既存の他の skills はそのまま使えます。
- Codex の既定設定 `config/codex/config.toml` (model `gpt-6-astra`、reasoning `xhigh`、service tier `fast`、permission は auto: `on-request` + `workspace-write` + auto-review) は、`~/.codex/config.toml` が無いときだけ setup / update がコピーします。Codex は project trust や desktop の状態を同じファイルに書き込むので、リンクはせず既存ファイルも上書きしません。
- Antigravity CLI の既定設定 `config/antigravity/settings.json` (`agentMode: accept-edits`) も同様に `~/.gemini/antigravity-cli/settings.json` が無いときだけコピーします。CLI は trusted workspace やモデル選択を同じファイルに書き込みます。

### Claude Code をベースにした subagent 構成

Claude Code をオーケストレータとし、Codex CLI と Antigravity CLI を subagent として呼びます。各 CLI は公式バイナリを非対話モードで起動するので、それぞれのサブスクリプション枠 (ChatGPT / Google AI Pro + Antigravity) を規約の範囲内で使い、Claude の枠は消費しません。

| 部品 | パス | 役割 |
| --- | --- | --- |
| skill `delegate-codex` | `config/ai-agents/skills/delegate-codex/` | `run.sh` が `codex exec -p subagent -o <file>` を実行し、最終メッセージだけを stdout に返す |
| skill `delegate-antigravity` | `config/ai-agents/skills/delegate-antigravity/` | `run.sh` が `agy --output-format=json --mode=accept-edits --dangerously-skip-permissions --print=<task>` を実行し、`.response` を stdout に返す |
| Claude subagent `codex` / `antigravity` | `config/claude/agents/*.md` → `~/.claude/agents` | `Task` ツールから並列起動できる薄いドライバ。対応する skill を preload し、`permissionMode: bypassPermissions` で `run.sh` を実行して結果を検証・報告する |
| Codex profile `subagent` | `config/codex/subagent.config.toml` → `~/.codex/subagent.config.toml` | `approval_policy = "never"`、`sandbox_mode = "danger-full-access"`、reasoning `high`。`~/.codex/config.toml` の上に layer される |

- subagent の権限は意図的に強くしています (Codex はサンドボックスなし、agy は permission prompt をスキップ)。結果の検証は呼び出し側の Claude が行います。レビューや調査だけのときは `run.sh -s read-only` (Codex) / `run.sh -M plan` (agy) を使います。
- `run.sh` は単体でも使えます。`run.sh -C /abs/path - <<'EOF' ... EOF` のように stdin でタスクを渡します。
- Claude Code の `permissions.allow` に `run.sh` と `codex exec` / `agy --print` を登録しているので、メインの Claude も subagent を介さず直接呼べます。
- skills ディレクトリは Codex 側には `sanitize-artifacts` だけをリンクしているため、Codex が自分自身や agy を再帰的に呼ぶことはありません。
- hooks は `~/.claude/hooks/` にファイル単位でリンクします。herdr の生成管理 hook と独自の `pre-commit-stop.sh` を分けています。
- Stop hook はイベントの `cwd` から Git root を解決し、`.pre-commit-config.yaml` と変更がある場合だけ検査します。サブディレクトリからの起動にも対応し、hook による継続時の再帰実行を避けます。

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
| `config/herdr/config.toml` | herdr 設定 (本体は `sync_herdr` で導入) | `~/.config/herdr/config.toml` (nix / pixi ともファイル単位リンク。`~/.config/herdr/` はランタイム状態を持つためディレクトリごとリンクしない) |
| `config/yabai` / `config/skhd` | macOS の WM / hotkey | `~/.config/yabai` / `~/.config/skhd` |
| `config/claude/settings.json` | Claude Code の共通設定 | `~/.claude/settings.json` (Home Manager activation / pixi bootstrap でマージ。ローカル状態は repo に戻さない) |
| `config/claude/hooks/` | Claude Code hooks | `~/.claude/hooks/*.sh` (ファイル単位の out-of-store link) |
| `config/claude/agents/` | Claude Code custom subagents (`codex` / `antigravity`) | `~/.claude/agents` (out-of-store link) |
| `config/antigravity/settings.json` | Antigravity CLI の既定設定 (`agentMode`) | `~/.gemini/antigravity-cli/settings.json` (存在しないときだけコピー。以後は CLI が書き換えるローカルファイル) |
| `config/ai-agents/` | AI agent 共通指示 (`INSTRUCTIONS.md`) と skills (`sanitize-artifacts`, `delegate-codex`, `delegate-antigravity`) | `~/.claude/CLAUDE.md`, `~/.claude/skills`, `~/.agents/skills/sanitize-artifacts` (out-of-store link) |
| `config/codex/AGENTS.md` | 共通指示 (`config/ai-agents/INSTRUCTIONS.md`) への symlink | `~/.codex/AGENTS.md` (out-of-store link で編集即反映) |
| `config/codex/config.toml` | Codex の既定設定 (model / reasoning / service tier / permission) | `~/.codex/config.toml` (存在しないときだけコピー。以後は Codex が書き換えるローカルファイル) |
| `config/codex/subagent.config.toml` | subagent 用 Codex profile (`codex exec -p subagent`) | `~/.codex/subagent.config.toml` (out-of-store link) |
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

### 複数 agent・端末での編集

`~/.dotfiles` は常用設定の適用元に固定し、変更はタスク別の worktree / branch で行います。

```bash
git -C ~/.dotfiles worktree add -b fix/example ../dotfiles-example
```

worktree で検証した変更を常用 checkout に取り込み、その端末の `~/.dotfiles` から `setup.sh` を実行します。各端末の clone 間では commit / PR を共有します。worktree は HOME を隔離しないため、作業用 worktree から本物の HOME に対して setup / update を実行しないでください。pixi のリンク先が作業用 worktree に切り替わり、他の agent にも影響します。テストには一時 HOME と mock、変更確認には `DRY_RUN=1` を使います。

同時実装はタスクごとに担当と branch を分け、共有ファイルを変更する担当を一人に決めます。引き継ぎには repo・branch・commit・変更範囲・検証結果・次の作業を残します。

### 検証

repo 自体のチェックは pre-commit で行います。

```bash
pre-commit run --all-files
bash script/tests/test-bootstrap.sh
bash script/tests/test-agent-hooks.sh
bash script/tests/test-claude-settings.sh
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
