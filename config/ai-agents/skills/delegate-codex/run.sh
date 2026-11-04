#!/usr/bin/env bash
# Run OpenAI Codex CLI non-interactively as a subagent and print its final
# message. Uses the `subagent` profile (~/.codex/subagent.config.toml) so the
# run is unattended with full workspace access.
#
# Usage:
#   run.sh [-C <dir>] [-m <model>] [-s <sandbox>] [-t <seconds>] <task text | ->
#   echo "task" | run.sh -
#
# Options:
#   -C <dir>      working root for Codex (default: current directory)
#   -m <model>    override model (default: profile / ~/.codex/config.toml)
#   -s <sandbox>  read-only | workspace-write | danger-full-access
#                 (default: profile value, danger-full-access)
#   -t <seconds>  kill the run after this many seconds (default: 1800)
#   -p <profile>  Codex profile name (default: subagent)
set -euo pipefail

workdir="$PWD"
model=""
sandbox=""
timeout_s="${CODEX_SUBAGENT_TIMEOUT:-1800}"
profile="${CODEX_SUBAGENT_PROFILE:-subagent}"

while getopts ':C:m:s:t:p:' opt; do
  case "${opt}" in
    C) workdir="${OPTARG}" ;;
    m) model="${OPTARG}" ;;
    s) sandbox="${OPTARG}" ;;
    t) timeout_s="${OPTARG}" ;;
    p) profile="${OPTARG}" ;;
    :) printf 'missing argument for -%s\n' "${OPTARG}" >&2; exit 2 ;;
    *) printf 'unknown option -%s\n' "${OPTARG}" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  printf 'usage: %s [-C dir] [-m model] [-s sandbox] [-t seconds] <task | ->\n' "$0" >&2
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  printf 'codex CLI not found. Install it with ~/.dotfiles/script/setup.sh (sync_codex).\n' >&2
  exit 127
fi

task="$*"
if [[ "${task}" == "-" ]]; then
  task="$(cat)"
fi

last_message="$(mktemp -t codex-subagent.XXXXXX)"
trap 'rm -f "${last_message}"' EXIT

args=(exec --skip-git-repo-check -C "${workdir}" -p "${profile}" -o "${last_message}")
[[ -n "${model}" ]] && args+=(-m "${model}")
[[ -n "${sandbox}" ]] && args+=(-s "${sandbox}")

# Progress goes to stderr so stdout only carries the final answer.
status=0
if command -v timeout >/dev/null 2>&1; then
  timeout --foreground "${timeout_s}" codex "${args[@]}" - <<<"${task}" >&2 || status=$?
elif command -v gtimeout >/dev/null 2>&1; then
  gtimeout --foreground "${timeout_s}" codex "${args[@]}" - <<<"${task}" >&2 || status=$?
else
  codex "${args[@]}" - <<<"${task}" >&2 || status=$?
fi

if [[ "${status}" -eq 124 ]]; then
  printf '[codex subagent] timed out after %ss\n' "${timeout_s}" >&2
fi

if [[ -s "${last_message}" ]]; then
  cat "${last_message}"
  printf '\n'
else
  printf '[codex subagent] no final message (exit %s)\n' "${status}" >&2
fi

exit "${status}"
