## Repo Workflow
* This repository maintains dotfiles for both nix/home-manager environments and non-sudo pixi-based environments.
* The primary entrypoint is `./script/setup.sh`.
* `script/setup.sh` uses `BOOTSTRAP_BACKEND=auto` by default.
* If `nix` is already available, `script/setup.sh` should prefer the nix/home-manager path.
* If `nix` is not available and the machine is eligible, `script/setup.sh` asks whether to install multi-user nix. Prefer the official `--daemon` install path when the machine is eligible.
* On macOS, multi-user nix requires `sudo`.
* On Linux, only attempt multi-user nix when `sudo` is available, `systemd` is present, and SELinux is disabled. Otherwise fall back to pixi.
* Do not auto-install single-user nix in the default flow.
* The pixi flow installs `uv` and `pixi` if needed, creates symbolic links into `$HOME`, and runs `pixi global sync`.
* Shared bootstrap logic lives in `script/lib/bootstrap-common.sh`. If setup behavior changes, update that file in addition to any thin wrappers.
* `script/update.sh` uses the same backend resolution, but must not prompt to install nix. On the nix path it runs `nix flake update nixpkgs` and reapplies Home Manager. If nix is absent, it should refresh links and run `pixi global sync`.
* npm-only CLI tools are managed separately in `config/npm/npm-global-packages.txt`.
* For npm-only packages, do not use npm's default global prefix. Sync them with `npm install -g --prefix "$HOME/.local"` so pixi or nix managed Node environments are not mutated.
* `happy` is currently managed through that npm global manifest.
* Dotfiles are linked into `$HOME`, and conflicting files are backed up with `*.bak.<timestamp>`.
* The pixi global manifest is managed in-repo under `config/pixi/manifests/`.
* This repository's pixi backend is Linux-only; macOS should use nix/home-manager.
* On Linux use `config/pixi/manifests/pixi-global-linux.toml`.

## What Codex Should Do After main Updates
* After updating nix dependencies, first inspect `README.md`, `script/setup.sh`, `script/update.sh`, `script/lib/bootstrap-common.sh`, and `config/pixi/manifests/`.
* Keep nix and pixi flows aligned. If a tool is added on the nix side and should also exist in the non-sudo environment, add it to the appropriate pixi global manifest too.
* If a CLI can only be installed via `npm -g`, add it to `config/npm/npm-global-packages.txt` instead of relying on manual install.
* If there are new dependencies, document any special installation instructions in `README.md` and, when relevant, in the bootstrap scripts.
* If there are new dotfiles or changes to existing ones, update the symbolic linking logic in `script/lib/bootstrap-common.sh` and document the change in `README.md`.
* If you touch the pixi path, prefer validating with `BOOTSTRAP_BACKEND=pixi` and `DRY_RUN=1` before making broader claims.
* If you touch the nix install path, validate that `setup.sh` prompts for multi-user nix and that `update.sh` does not prompt for installation.
