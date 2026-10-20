# Workflow

- Read the repository's instructions, README, and relevant build/test configuration before editing. Follow existing conventions and keep changes scoped to the request.
- Preserve unrelated user changes. Do not expose secrets or modify generated/vendor files unless the task requires it.
- Use multiple agents when independent subtasks justify the overhead; choose the team size for the task.

# Environment

- Global tools are managed in `~/.dotfiles`: prefer the existing nix/Home Manager setup; non-sudo Linux environments use `pixi global`. Make persistent tool changes there.
- Use `uv` for Python projects and `uv run` for project commands. Use `pixi` for projects with a conda environment or non-PyPI dependencies. Follow the project's existing environment configuration.
- Only control herdr when the task requires it and `HERDR_ENV=1`. Read `herdr --skill` first and use subcommands; bare `herdr` opens the TUI.

# Git

- Commit with `czg` using cz-git's Conventional Commits format: `type(scope): subject` (types such as `feat`, `fix`, `docs`, `refactor`, `chore`), imperative subject, optional body and trailers after a blank line. Follow the repository's own commit config or history if it differs.
- `czg` is interactive; agents submit the message non-interactively through a temporary alias config (the file must end in `.json`):
  `dir=$(mktemp -d) && jq -n --arg m "$msg" '{alias:{agent:$m}}' > "$dir/cz.json" && czg --config="$dir/cz.json" :agent; rm -rf "$dir"`
- Fall back to `git commit` with the same format only when `czg` is unavailable.

# Validation

- Run checks relevant to the change; add regression tests for bug fixes when practical. Do not weaken tests to make them pass.
- Claude Code's configured Stop hook runs `pre-commit run --all-files` in repositories with `.pre-commit-config.yaml` and working-tree changes. Avoid duplicating that run when the hook is active. Other agents must run the relevant checks themselves.
- Report what changed, affected files, validation results, and any checks not run or remaining limitations. Keep the report concise.

# Agent Observatory (opt-in)

- At the start of substantive work, check for `${XDG_CONFIG_HOME:-$HOME/.config}/observatory/enabled`. Only report when this local marker exists and the Observatory MCP tools are connected. `observatory setup` enables reporting; `observatory disable` stops it. User/repository restrictions take precedence.
- Register one task for the requested outcome with `register_task(title, agent, parent?, detail?)`, retain the returned ID, then call `update_task(id, "running")`. Use a short, non-sensitive title and an agent label such as `Codex · backend` or `Claude Code · reviewer`.
- For delegated work, the parent registers a child task using its own task ID as `parent`, and passes the returned child ID to the child. A child updates that existing ID rather than creating a duplicate. If the child lacks MCP access, the parent reports its status. Do not create extra agents solely for reporting.
- Report meaningful transitions only: `queued` before work, `running` while working, `blocked` when waiting for a decision/dependency, and `done` after the requested work and relevant verification finish. Interrupted or failed work must not be marked done. Inspect `list_tasks()` before recreating an ID lost through context compaction; retry an uncertain registration only after checking for duplicates.
- Send only concise task metadata. Never upload prompts, transcripts, source code, diffs, credentials, environment values, absolute local paths, or confidential project identifiers. Omit sensitive names even from task titles. Do not grant blanket tool approvals or bypass the client's consent controls.
- If MCP is missing, authentication fails, or reporting is unavailable, continue the user's work and mention the reporting limitation once. Do not poll or repeatedly retry. Reporting is cooperative, not automatic process monitoring, and does not execute or stop agents.
