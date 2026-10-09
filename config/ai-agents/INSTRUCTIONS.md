# Workflow

- Read the repository's instructions, README, and relevant build/test configuration before editing. Follow existing conventions and keep changes scoped to the request.
- Preserve unrelated user changes. Do not expose secrets or modify generated/vendor files unless the task requires it.
- Use multiple agents when independent subtasks justify the overhead; choose the team size for the task.

# Environment

- Global tools are managed in `~/.dotfiles`: prefer the existing nix/Home Manager setup; non-sudo Linux environments use `pixi global`. Make persistent tool changes there.
- Use `uv` for Python projects and `uv run` for project commands. Use `pixi` for projects with a conda environment or non-PyPI dependencies. Follow the project's existing environment configuration.
- Only control herdr when the task requires it and `HERDR_ENV=1`. Read `herdr --skill` first and use subcommands; bare `herdr` opens the TUI.

# Validation

- Run checks relevant to the change; add regression tests for bug fixes when practical. Do not weaken tests to make them pass.
- Claude Code's configured Stop hook runs `pre-commit run --all-files` in repositories with `.pre-commit-config.yaml` and working-tree changes. Avoid duplicating that run when the hook is active. Other agents must run the relevant checks themselves.
- Report what changed, affected files, validation results, and any checks not run or remaining limitations. Keep the report concise.
