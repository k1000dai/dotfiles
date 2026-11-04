---
name: delegate-codex
description: Delegate a self-contained task to OpenAI Codex CLI (GPT) running unattended with full workspace access. Use for deep reasoning, design trade-offs, rigorous code review, second opinions, or long autonomous implementation that benefits from a different model family.
---

# delegate-codex

Run `codex exec` as a subagent. Codex uses the user's ChatGPT subscription via the
official CLI, so it does not consume Claude quota.

## When to use

- The task needs a second, independent opinion (design review, security review,
  "find what I missed").
- A long, well-specified implementation that can run unattended.
- Comparing approaches where a different model family adds signal.

Do not use it for trivial edits, for questions you can answer from context, or
when the task depends on conversation history Codex cannot see.

## How to run

```bash
~/.claude/skills/delegate-codex/run.sh [-C <dir>] [-m <model>] [-s <sandbox>] [-t <seconds>] [-r <session>] <task | ->
```

- Pass long tasks over stdin with `-` (heredoc) to avoid quoting problems.
- `-C` sets the working root. Default is the current directory. Use an absolute path.
- Default permissions come from the `subagent` profile
  (`~/.codex/subagent.config.toml`): `approval_policy = "never"`,
  `sandbox_mode = "danger-full-access"`. Pass `-s read-only` for review-only runs.
- `-m` overrides the model; omit it to use the profile default.
- `-r <session>` continues an earlier run with its context (for example "now fix
  findings 1 and 3"). Each run prints `[codex subagent] session=<id>` on stderr.
  `-r last` picks the most recent session, which is ambiguous when runs are in
  parallel, so prefer the id. Pass `-C`/`-s` again; they are not inherited.
- `-t` kills the whole Codex process group after that many seconds (default 1800)
  and exits 124. It needs no GNU `timeout`.
- stdout is the final answer only. Progress goes to a log file, so the Bash tool
  output stays small; on failure the last 20 lines and the log path are printed
  on stderr. Set `CODEX_SUBAGENT_VERBOSE=1` to stream progress to stderr instead.
- Non-zero exit with no answer usually means Codex is not logged in (`codex login`),
  the quota is exhausted, or the run timed out (exit 124).

## Parallel runs

Call `run.sh` directly; there is no relay subagent. For independent tasks, start
each call with the Bash tool's `run_in_background` and collect the results when
they finish. Give parallel runs separate `-C` directories or worktrees when they
edit files.

## Writing the task

Codex starts with no context. The task text must stand alone:

1. Goal and definition of done.
2. Absolute paths of the relevant files or directories.
3. Constraints: what not to touch, style/lint rules, test command to run.
4. Required output shape, for example "end with a bullet list of changed files and
   remaining risks" or "answer with a Markdown review: findings, severity, fix".

Example:

```bash
~/.claude/skills/delegate-codex/run.sh -C /abs/path/repo -s read-only - <<'EOF'
Review the change in /abs/path/repo (git diff main...HEAD) for correctness and
concurrency bugs. Do not modify files. Reply in Markdown: findings grouped by
severity, each with file:line and a concrete fix.
EOF
```

## After it returns

- Treat the result as input, not truth. Read the files Codex changed and run the
  tests yourself before reporting to the user.
- When Codex edited files, summarize what changed and why in your own reply.
