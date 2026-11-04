#!/usr/bin/env bash
# Run Google Antigravity CLI (agy) in print mode as a subagent and print its
# final response. Runs unattended: --mode accept-edits plus
# --dangerously-skip-permissions ("auto" mode is not available on every account).
#
# Usage:
#   run.sh [-C <dir>] [-m <model>] [-M <mode>] [-t <seconds>] <task text | ->
#   echo "task" | run.sh -
#
# Options:
#   -C <dir>      working directory (default: current directory)
#   -m <model>    agy model id (default: gemini-4-argon-high; see `agy models`)
#   -M <mode>     accept-edits | auto | plan (default: accept-edits; plan is read-only)
#   -t <seconds>  print timeout passed to agy (default: 1800)
set -euo pipefail

workdir="$PWD"
model="${AGY_SUBAGENT_MODEL:-gemini-4-argon-high}"
mode="${AGY_SUBAGENT_MODE:-accept-edits}"
timeout_s="${AGY_SUBAGENT_TIMEOUT:-1800}"

while getopts ':C:m:M:t:' opt; do
  case "${opt}" in
    C) workdir="${OPTARG}" ;;
    m) model="${OPTARG}" ;;
    M) mode="${OPTARG}" ;;
    t) timeout_s="${OPTARG}" ;;
    :) printf 'missing argument for -%s\n' "${OPTARG}" >&2; exit 2 ;;
    *) printf 'unknown option -%s\n' "${OPTARG}" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  printf 'usage: %s [-C dir] [-m model] [-M mode] [-t seconds] <task | ->\n' "$0" >&2
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
  --model="${model}"
  --print-timeout="${timeout_s}s"
)
if [[ "${mode}" != "plan" ]]; then
  args+=(--dangerously-skip-permissions)
fi

raw="$(mktemp -t agy-subagent.XXXXXX)"
trap 'rm -f "${raw}"' EXIT

status=0
(cd "${workdir}" && agy "${args[@]}" --print="${task}") >"${raw}" || status=$?

if jq -e 'type == "object" and has("response")' "${raw}" >/dev/null 2>&1; then
  run_status="$(jq -r '.status // ""' "${raw}")"
  jq -r '.response' "${raw}"
  if [[ -n "${run_status}" && "${run_status}" != "SUCCESS" ]]; then
    printf '[agy subagent] status=%s\n' "${run_status}" >&2
    [[ "${status}" -eq 0 ]] && status=1
  fi
else
  # Not JSON: forward whatever agy printed (login prompts, errors).
  cat "${raw}"
  printf '[agy subagent] non-JSON output (exit %s)\n' "${status}" >&2
  [[ "${status}" -eq 0 ]] && status=1
fi

exit "${status}"
