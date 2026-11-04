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
~/.claude/skills/delegate-antigravity/run.sh [-C <dir>] [-m <model>] [-M <mode>] [-t <seconds>] <task | ->
```

- Pass long tasks over stdin with `-` (heredoc).
- `-C` sets the working directory. Use an absolute path.
- `-M accept-edits` (default) runs with `--dangerously-skip-permissions`, so edits
  and commands are auto-approved. `-M plan` is read-only: use it for reviews and
  investigations that must not change files. (`auto` mode is not available on
  every account.)
- `-m` picks the model. Default `gemini-4-argon-high`. `gemini-3.8-flash-high` is
  cheaper on quota for broad but simple scans. `agy models` lists ids.
- stdout is the final response only (parsed from `--output-format json`).
- Non-zero exit with a login message means run `agy` once interactively to sign
  in. A `status` other than `SUCCESS` is reported on stderr.

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
