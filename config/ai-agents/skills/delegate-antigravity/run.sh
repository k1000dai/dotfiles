#!/usr/bin/env bash
# Run Google Antigravity CLI (agy) in print mode as a subagent and print its
# final response. Runs unattended: --mode accept-edits plus
# --dangerously-skip-permissions ("auto" mode is not available on every account).
#
# Usage:
#   run.sh [-C <dir>] [-m <model>] [-M <mode>] [-t <seconds>] [-r <conversation>] <task text | ->
#   echo "task" | run.sh -
#
# Options:
#   -C <dir>      working directory (default: current directory)
#   -m <model>    agy model id (default: the `model` in agy's settings.json;
#                 see `agy models`)
#   -M <mode>     accept-edits | auto | plan (default: accept-edits). plan skips
#                 --dangerously-skip-permissions and adds --sandbox, but agy does
#                 not enforce read-only: settings.json allow rules still apply.
#                 In a git repo the wrapper reports any files changed by the run.
#   -t <seconds>  print timeout passed to agy (default: 1800)
#   -r <conversation>  continue an earlier run: its conversation id, or `last`
#                 for the most recent conversation (ambiguous in parallel)
#
# The conversation id is printed on stderr for -r.
set -euo pipefail

workdir="$PWD"
model="${AGY_SUBAGENT_MODEL:-}"
mode="${AGY_SUBAGENT_MODE:-accept-edits}"
timeout_s="${AGY_SUBAGENT_TIMEOUT:-1800}"
resume=""

while getopts ':C:m:M:t:r:' opt; do
  case "${opt}" in
    C) workdir="${OPTARG}" ;;
    m) model="${OPTARG}" ;;
    M) mode="${OPTARG}" ;;
    t) timeout_s="${OPTARG}" ;;
    r) resume="${OPTARG}" ;;
    :) printf 'missing argument for -%s\n' "${OPTARG}" >&2; exit 2 ;;
    *) printf 'unknown option -%s\n' "${OPTARG}" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  printf 'usage: %s [-C dir] [-m model] [-M mode] [-t seconds] [-r conversation] <task | ->\n' "$0" >&2
  exit 2
fi

if ! command -v agy >/dev/null 2>&1; then
  printf 'agy CLI not found. Install it with ~/.dotfiles/script/setup.sh (sync_antigravity).\n' >&2
  exit 127
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required to parse agy JSON output.\n' >&2
  exit 127
fi

task="$*"
if [[ "${task}" == "-" ]]; then
  task="$(cat)"
fi

# `--print` takes the prompt as its own value; keep every other flag as
# `--flag=value` so agy cannot mistake a flag for the prompt. Slash command
# expansion stays enabled because `--mode plan` is ignored without it.
args=(
  --output-format=json
  --mode="${mode}"
  --print-timeout="${timeout_s}s"
)
[[ -n "${model}" ]] && args+=(--model="${model}")
if [[ "${resume}" == "last" ]]; then
  args+=(--continue)
elif [[ -n "${resume}" ]]; then
  args+=(--conversation="${resume}")
fi
if [[ "${mode}" == "plan" ]]; then
  args+=(--sandbox)
else
  args+=(--dangerously-skip-permissions)
fi

tmp_root="${TMPDIR:-/tmp}"
tmpdir="$(mktemp -d "${tmp_root%/}/agy-subagent.XXXXXX")"
trap 'rm -rf "${tmpdir}"' EXIT
raw="${tmpdir}/response.json"

# argv is capped (ARG_MAX, ~1 MiB on macOS), so large tasks go through a file
# that agy reads from an added workspace directory.
prompt="${task}"
if (( ${#task} > 64 * 1024 )); then
  if [[ "${mode}" == "plan" ]]; then
    # Headless plan mode auto-denies the tool agy uses to read the task file.
    printf 'task is %s bytes; plan mode only accepts up to 64 KiB inline.\n' "${#task}" >&2
    printf 'Put large material in files under %s and reference their paths instead.\n' "${workdir}" >&2
    exit 2
  fi
  printf '%s\n' "${task}" >"${tmpdir}/task.md"
  args+=(--add-dir="${tmpdir}")
  prompt="Your full task is in ${tmpdir}/task.md. Read that whole file first and follow it exactly as if it were this prompt."
fi

git_state() {
  git -C "${workdir}" status --porcelain=v1 --untracked-files=all 2>/dev/null
  git -C "${workdir}" diff --no-ext-diff 2>/dev/null | cksum
}
in_git=0
if [[ "${mode}" == "plan" ]] && git -C "${workdir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=1
  before="$(git_state)"
fi

status=0
(cd "${workdir}" && agy "${args[@]}" --print="${prompt}") >"${raw}" 2>"${tmpdir}/stderr" || status=$?
cat "${tmpdir}/stderr" >&2

if [[ "${in_git}" -eq 1 && "$(git_state)" != "${before}" ]]; then
  printf '[agy subagent] WARNING: plan mode changed the working tree in %s; review git status.\n' "${workdir}" >&2
fi

if jq -e 'type == "object" and has("response")' "${raw}" >/dev/null 2>&1; then
  run_status="$(jq -r '.status // ""' "${raw}")"
  conversation_id="$(jq -r 'first(.. | objects | to_entries[] | select(.key | test("^conversation_?id$"; "i")) | .value | strings) // ""' "${raw}")"
  if [[ -n "${conversation_id}" ]]; then
    printf '[agy subagent] conversation=%s (continue with -r %s)\n' "${conversation_id}" "${conversation_id}" >&2
  fi
  jq -r '.response' "${raw}"
  if [[ -n "${run_status}" && "${run_status}" != "SUCCESS" ]]; then
    printf '[agy subagent] status=%s\n' "${run_status}" >&2
    [[ "${status}" -eq 0 ]] && status=1
  fi
  # A permission auto-deny exits 0 with an empty response; the reason is on stderr.
  if ! jq -e '.response | strings | test("\\S")' "${raw}" >/dev/null 2>&1; then
    if grep -q 'auto-denied' "${tmpdir}/stderr"; then
      printf '[agy subagent] no output: a tool permission was auto-denied\n' >&2
    else
      printf '[agy subagent] empty response\n' >&2
    fi
    [[ "${status}" -eq 0 ]] && status=1
  fi
else
  # Not JSON: forward whatever agy printed (login prompts, errors).
  cat "${raw}"
  printf '[agy subagent] non-JSON output (exit %s)\n' "${status}" >&2
  [[ "${status}" -eq 0 ]] && status=1
fi

exit "${status}"
