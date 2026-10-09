#!/bin/sh
# Claude Code Stop hook: validate the repository containing the session cwd.
set -eu

# Respect an active project environment before falling back to user CLI tools.
export PATH="${PATH}:${HOME}/.local/bin"
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' 'pre-commit Stop hook requires jq on PATH.' >&2
  exit 1
fi

# Use Claude's current cwd, including worktrees and nested directories. Ignore
# malformed input and recursive Stop events instead of checking an unrelated cwd.
hook_cwd="$(jq -er '
  select(type == "object" and .stop_hook_active != true)
  | .cwd | select(type == "string" and length > 0)
' 2>/dev/null)" || exit 0
repo_root="$(git -C "$hook_cwd" rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$repo_root" || exit 0
[ -f .pre-commit-config.yaml ] || exit 0
changes="$(git --no-optional-locks status --porcelain --untracked-files=normal 2>/dev/null)" || exit 0
[ -n "$changes" ] || exit 0

if ! command -v pre-commit >/dev/null 2>&1; then
  jq -n '{decision: "block", reason: "This repository requires pre-commit, but it is not on PATH. Use its configured environment to run pre-commit run --all-files before finishing."}'
  exit 0
fi

if output="$(pre-commit run --all-files 2>&1)"; then
  exit 0
fi

# Use stdin for large logs and limit by characters to keep UTF-8 intact.
printf '%s' "$output" | jq -Rs '{
  decision: "block",
  reason: ("pre-commit run --all-files failed. Fix the issues and re-run until it passes:\n\n" + .[-3000:])
}'
