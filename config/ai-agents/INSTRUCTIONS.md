# Repository discovery
If you are in a new git repository, start by understanding the project structure, dependencies, and conventions. This will help you make informed decisions about where to make changes and how to maintain consistency with the existing codebase. If not a git repository, ignore this section.
Before editing, look for:

- `README.md`
- package/build configuration files
- test configuration
- lint/format/typecheck configuration
- CI configuration
- existing examples of similar code
- Do `pre-commit run --all-files` after making changes to check for formatting, linting, and type errors.

# Tool
## Tool for Python Engineering
* uv: please use uv to create and manage virtual environments for Python projects.
If you are not in a virtual environment, activate "source .venv/bin/activate" first.

* pixi : a tool for managing Python packages and dependencies like anaconda. It provides a simple interface for installing, updating, and removing packages, as well as managing virtual environments. If repository is conda environment or including not pip packages, please use pixi to manage dependencies.

## Tool for global environment.
All tools assume installed via .dotfiles which is at ~/.dotfiles. 
If user have sudo permission, environment are managed by nix and home-manager. If user don't have sudo permission, environment are managed by pixi global sync.

## herdr (terminal workspace manager)
Terminal sessions are managed by herdr, a tmux-like workspace manager for coding agents (config: ~/.dotfiles/config/herdr/config.toml, tmux-compatible keybindings, prefix ctrl+b).

- If `HERDR_ENV=1`, you are running inside a herdr pane and can use the `herdr` CLI to inspect/control panes, tabs, workspaces, and other agents. Run `herdr --skill` first for usage.
- Never run bare `herdr` (it launches/attaches the TUI). Use subcommands: `herdr pane`, `herdr tab`, `herdr agent`, `herdr workspace`, `herdr worktree`.
- Only control herdr when the task calls for it (user asks, or coordinating parallel agents/panes). Check `HERDR_ENV` before any herdr command.
- Git worktrees created via herdr live under the ghq root: ~/codes/ghq/worktrees/<repo>/<branch>.

# Code style

- Match the style of the existing codebase.
- Prefer simple, readable code.
- Use descriptive names.
- Avoid clever abstractions unless they clearly reduce complexity.
- Keep functions and modules focused.
- Avoid large refactors unless explicitly requested.
- Do not reformat unrelated files.

# Testing

- Run targeted tests for the changed area when possible.
- Run broader tests when changing shared logic, public APIs, configuration, or core behavior.
- Add regression tests for bug fixes when practical.
- Do not delete, skip, or weaken tests just to make the suite pass.
- If tests cannot be run, explain why and describe the remaining risk.

# Security

- Never commit secrets, API keys, tokens, passwords, private certificates, or credentials.
- Do not expose secrets in logs, tests, errors, screenshots, or documentation.
- Be especially careful with authentication, authorization, payment, cryptography, migrations, and destructive operations.
- Do not change production infrastructure, deployment, or environment configuration unless explicitly requested.
- Treat generated files, vendor files, and build artifacts as read-only unless the task requires changing them.

# Communication

In final responses, include:

- What changed
- Files changed
- Tests/checks run
- Anything not run and why
- Any remaining risks or follow-up work

# Team AGENT
- use AGENT TEAMS. default team number is 4. but you can change the number based on the project size and complexity.
