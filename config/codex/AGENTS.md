# Python Engineering Agents
## Tool 
* uv: please use uv to create and manage virtual environments for Python projects.
If you are not in a virtual environment, activate "source .venv/bin/activate" first.

* pixi : a tool for managing Python packages and dependencies like anaconda. It provides a simple interface for installing, updating, and removing packages, as well as managing virtual environments. If repository is conda environment or including not pip packages, please use pixi to manage dependencies.

## Repo Workflow
* This repository currently prefers a non-sudo bootstrap flow over nix/home-manager for day-to-day setup.
* The primary entrypoint is `./script/hpc-setup.sh`.
* `script/hpc-setup.sh` installs `uv` and `pixi` first, then creates symbolic links, then runs `pixi global sync`.
* Dotfiles are linked into `$HOME`, and conflicting files are backed up with `*.bak.<timestamp>`.
* The pixi global manifest is managed in-repo under `config/pixi/manifests/`.
* On macOS use `config/pixi/manifests/pixi-global.toml`.
* On Linux use `config/pixi/manifests/pixi-global-linux.toml`.

## What Codex Should Do After main Updates
* After pulling or merging updates from `main`, first inspect `README.md`, `script/hpc-setup.sh`, and `config/pixi/manifests/`.
* The default resync command is `SKIP_TOOL_INSTALL=1 ./script/hpc-setup.sh`.
* If only validation is needed, use `DRY_RUN=1 SKIP_TOOL_INSTALL=1 ./script/hpc-setup.sh`.
* If only links should be refreshed and package sync should be deferred, use `SKIP_PIXI_SYNC=1 ./script/hpc-setup.sh`.
* When changing CLI packages, prefer editing the pixi manifest instead of ad-hoc local installs.
* When adding new dotfiles, prefer adding them to the repo and extending `script/hpc-setup.sh` link generation instead of documenting manual copy steps.

## Maintenance Notes
* Treat nix/home-manager files as retained configuration assets, not the default bootstrap path.
* Prefer `pixi global sync` for reproducible CLI updates.
* If a requested package cannot be solved on conda-forge, document that limitation and keep it outside the pixi global manifest unless the user asks for a different distribution path.

