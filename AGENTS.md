## Repo Workflow
* This repository maintains dotfiles for both nix/home-manager environments and non-sudo pixi-based environments.
* The primary entrypoint is `./script/setup.sh`.
* `script/setup.sh` uses `BOOTSTRAP_BACKEND=auto` by default.
* If `nix` is already available, `script/setup.sh` should prefer the nix/home-manager path.
* If `nix` is not available, `script/setup.sh` asks whether to install nix in single-user mode. If the user declines, or nix installation cannot be completed without sudo, it must fall back to the pixi flow.
* The pixi flow installs `uv` and `pixi` if needed, creates symbolic links into `$HOME`, and runs `pixi global sync`.
* Shared bootstrap logic lives in `script/lib/bootstrap-common.sh`. If setup behavior changes, update that file in addition to any thin wrappers.
* `script/update.sh` uses the same backend resolution. On the nix path it runs `nix flake update nixpkgs` and reapplies Home Manager. On the pixi path it refreshes links and runs `pixi global sync`.
* Dotfiles are linked into `$HOME`, and conflicting files are backed up with `*.bak.<timestamp>`.
* The pixi global manifest is managed in-repo under `config/pixi/manifests/`.
* On macOS use `config/pixi/manifests/pixi-global.toml`.
* On Linux use `config/pixi/manifests/pixi-global-linux.toml`.

## What Codex Should Do After main Updates
* After updating nix dependencies, first inspect `README.md`, `script/setup.sh`, `script/update.sh`, `script/lib/bootstrap-common.sh`, and `config/pixi/manifests/`.
* Keep nix and pixi flows aligned. If a tool is added on the nix side and should also exist in the non-sudo environment, add it to the appropriate pixi global manifest too.
* If there are new dependencies, document any special installation instructions in `README.md` and, when relevant, in the bootstrap scripts.
* If there are new dotfiles or changes to existing ones, update the symbolic linking logic in `script/lib/bootstrap-common.sh` and document the change in `README.md`.
* If you touch the pixi path, prefer validating with `BOOTSTRAP_BACKEND=pixi` and `DRY_RUN=1` before making broader claims.
