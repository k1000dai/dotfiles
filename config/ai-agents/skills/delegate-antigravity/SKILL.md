---
name: delegate-antigravity
description: Delegate a self-contained task to Google Antigravity CLI (agy, Gemini 4 Argon) running unattended with full permissions. Use for repository-wide investigation, very large inputs (long logs, many files, PDFs/images), web-grounded research, or when Gemini quota should be spent instead of Claude quota.
---

# delegate-antigravity

Run `agy --print` as a subagent. agy uses the user's Google AI Pro + Antigravity
quota via the official CLI, so it does not consume Claude quota.

## When to use

- Survey or explain a large codebase or long logs that would bloat your context.
- Research that benefits from Google Search grounding.
- Multimodal inputs (screenshots, PDFs, diagrams).
- Offloading mechanical but broad work (generate tests across many files, mass
  refactors) when the task can be specified precisely.

Do not use it for small edits or for tasks that need the current conversation.

## How to run

```bash
~/.claude/skills/delegate-antigravity/run.sh [-C <dir>] [-m <model>] [-M <mode>] [-t <seconds>] [-r <conversation>] <task | ->
```

- Pass long tasks over stdin with `-` (heredoc). Tasks over 64 KiB are written to
  a temporary file that agy reads, because argv is limited (~1 MiB on macOS).
  `-M plan` rejects such tasks: put the material in files and pass paths.
- `-C` sets the working directory. Use an absolute path.
- `-M accept-edits` (default) runs with `--dangerously-skip-permissions`, so edits
  and commands are auto-approved. `-M plan` is for reviews and investigations: it
  drops `--dangerously-skip-permissions` and adds `--sandbox`, but agy does not
  enforce read-only (allow rules in `~/.gemini/antigravity-cli/settings.json` still
  apply). Also say "do not modify files" in the task. In a git repository the
  wrapper warns on stderr when the run changed the working tree. (`auto` mode is
  not available on every account.)
- `-m` picks the model. Without it agy uses the `model` in
  `~/.gemini/antigravity-cli/settings.json` (seeded as Gemini 4 Argon (High)).
  `gemini-3.8-flash-high` is cheaper on quota for broad but simple scans.
  `agy models` lists ids.
- `-r <conversation>` continues an earlier run with its context. Each run prints
  `[agy subagent] conversation=<id>` on stderr. `-r last` maps to `--continue`
  (most recent conversation), which is ambiguous in parallel, so prefer the id.
- stdout is the final response only (parsed from `--output-format json`).
- Non-zero exit with a login message means run `agy` once interactively to sign
  in. A `status` other than `SUCCESS`, or a tool permission that headless mode
  auto-denied, is reported on stderr with a non-zero exit.

## Parallel runs

Call `run.sh` directly; there is no relay subagent. For independent tasks, start
each call with the Bash tool's `run_in_background` and collect the results when
they finish. Give parallel runs separate `-C` directories or worktrees when they
edit files.

## Writing the task

agy starts with no context. Make the task self-contained:

1. Goal and definition of done.
2. Absolute paths of the files or directories to look at.
3. Constraints: read-only or allowed to edit, what not to touch, test command.
4. Required output shape, for example "answer as Markdown with headings per
   module, each with file paths and line numbers".

Example (read-only investigation):

```bash
~/.claude/skills/delegate-antigravity/run.sh -C /abs/path/repo -M plan - <<'EOF'
Map how configuration is loaded in /abs/path/repo: entry points, precedence
between env vars, files and CLI flags, and where defaults live. Do not modify
files. Answer in Markdown with file:line references.
EOF
```

## After it returns

- Verify claims against the files before relying on them.
- When agy edited files, read the diff and run the tests yourself before
  reporting to the user.
