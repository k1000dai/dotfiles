# Repository workflow

- Read `README.md` for setup and layout. Entrypoints are `script/setup.sh` and `script/update.sh`; shared behavior belongs in `script/lib/bootstrap-common.sh`.
- Keep these backend rules intact:
  - Prefer an existing nix installation. macOS uses nix/Home Manager; the pixi backend is Linux-only.
  - Setup may offer multi-user nix (`--daemon`) with sudo; Linux also requires systemd and disabled SELinux. Do not auto-install single-user nix.
  - Update must never prompt to install nix. It updates nixpkgs and reapplies Home Manager, or refreshes Linux pixi links and runs `pixi global sync` when nix is absent.
- Keep shared CLI tools aligned between `home*.nix` and `config/pixi/manifests/pixi-global-linux.toml` where available.
- Manage npm-only CLIs in `config/npm/npm-global-packages.txt`, installed with `--prefix "$HOME/.local"`.
- Claude Code, Codex, herdr, and Reason Network use `sync_claude_code` / `sync_codex` / `sync_herdr` / `sync_reason_network` in the shared bootstrap script. Do not add them to npm manifests or nix packages. Never commit the Reason Network join link; it is read from `REASON_NETWORK_JOIN_URL`.
- When adding or relocating dotfiles, update Home Manager declarations, `setup_links` in the shared bootstrap script, and `README.md`. Preserve `*.bak.<timestamp>` backups for link conflicts.
- Shared agent instructions live in `config/ai-agents/INSTRUCTIONS.md`; `config/claude/CLAUDE.md` and `config/codex/AGENTS.md` are symlinks to it. Keep repository-specific rules here.

# Validation

- `.pre-commit-config.yaml` defines whitespace/YAML checks, `nixfmt`, and `shellcheck`. CI builds the Darwin and Linux Home Manager configurations.
- For bootstrap changes, run shell syntax/lint checks. Validate pixi changes on Linux with `BOOTSTRAP_BACKEND=pixi DRY_RUN=1`; on macOS, use a mocked Linux environment or report the platform limitation.
- For nix installation changes, verify that setup offers multi-user nix only on eligible machines and update never prompts to install it.
