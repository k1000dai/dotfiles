#!/usr/bin/env bash
# Run OpenAI Codex CLI non-interactively as a subagent and print its final
# message. Uses the `subagent` profile (~/.codex/subagent.config.toml) so the
# run is unattended.
#
# Usage:
#   run.sh [-C <dir>] [-m <model>] [-s <sandbox>] [-t <seconds>] [-r <session>] <task text | ->
#   echo "task" | run.sh -
#
# Options:
#   -C <dir>      working root for Codex (default: current directory)
#   -m <model>    override model (default: profile / ~/.codex/config.toml)
#   -s <sandbox>  read-only | workspace-write | danger-full-access
#                 (default: profile value, danger-full-access)
#   -t <seconds>  kill the run after this many seconds (default: 1800)
#   -p <profile>  Codex profile name (default: subagent)
#   -r <session>  continue an earlier run: its session id, or `last` for the
#                 most recent session (ambiguous when runs are in parallel)
#
# stdout carries only Codex's final message. Progress goes to a log file that is
# kept and named on stderr when the run fails; set CODEX_SUBAGENT_VERBOSE=1 to
# also stream it to stderr. The session id is printed on stderr for -r.
set -euo pipefail

workdir="$PWD"
model=""
sandbox=""
timeout_s="${CODEX_SUBAGENT_TIMEOUT:-1800}"
profile="${CODEX_SUBAGENT_PROFILE:-subagent}"
resume=""

while getopts ':C:m:s:t:p:r:' opt; do
  case "${opt}" in
    C) workdir="${OPTARG}" ;;
    m) model="${OPTARG}" ;;
    s) sandbox="${OPTARG}" ;;
    t) timeout_s="${OPTARG}" ;;
    p) profile="${OPTARG}" ;;
    r) resume="${OPTARG}" ;;
    :) printf 'missing argument for -%s\n' "${OPTARG}" >&2; exit 2 ;;
    *) printf 'unknown option -%s\n' "${OPTARG}" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  printf 'usage: %s [-C dir] [-m model] [-s sandbox] [-t seconds] [-r session] <task | ->\n' "$0" >&2
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

if ! [[ "${timeout_s}" =~ ^[1-9][0-9]*$ ]]; then
  printf 'timeout must be a positive integer number of seconds: %s\n' "${timeout_s}" >&2
  exit 2
fi

tmp_root="${TMPDIR:-/tmp}"
tmpdir="$(mktemp -d "${tmp_root%/}/codex-subagent.XXXXXX")"
last_message="${tmpdir}/last-message.md"
log_file="${tmpdir}/progress.log"
keep_log=0
codex_pid=""
watchdog_pid=""

# shellcheck disable=SC2329 # invoked via trap
cleanup() {
  # Stop the whole Codex process group (codex spawns shells) if we exit early.
  if [[ -n "${codex_pid}" ]]; then
    kill -TERM -- "-${codex_pid}" 2>/dev/null || true
  fi
  if [[ -n "${watchdog_pid}" ]]; then
    kill "${watchdog_pid}" 2>/dev/null || true
  fi
  if [[ "${keep_log}" -eq 1 ]]; then
    rm -f "${last_message}"
  else
    rm -rf "${tmpdir}"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

args=(exec --skip-git-repo-check -C "${workdir}" -p "${profile}" -o "${last_message}")
[[ -n "${model}" ]] && args+=(-m "${model}")
[[ -n "${sandbox}" ]] && args+=(-s "${sandbox}")
# exec-level flags must precede the `resume` subcommand.
if [[ "${resume}" == "last" ]]; then
  args+=(resume --last)
elif [[ -n "${resume}" ]]; then
  args+=(resume "${resume}")
fi


# Job control gives the background job its own process group, so the watchdog
# can stop Codex and everything it spawned. No dependency on GNU timeout.
set -m
if [[ "${CODEX_SUBAGENT_VERBOSE:-0}" == "1" ]]; then
  codex "${args[@]}" - <<<"${task}" > >(tee "${log_file}" >&2) 2>&1 &
else
  codex "${args[@]}" - <<<"${task}" >"${log_file}" 2>&1 &
fi
codex_pid=$!
set +m

(
  # Sleep in the background and wait on it so the TERM trap fires immediately.
  sleep_pid=""
  trap 'kill "${sleep_pid}" 2>/dev/null; exit 0' TERM
  sleep "${timeout_s}" &
  sleep_pid=$!
  wait "${sleep_pid}"
  : >"${tmpdir}/timed-out"
  kill -TERM -- "-${codex_pid}" 2>/dev/null || exit 0
  sleep 10 &
  sleep_pid=$!
  wait "${sleep_pid}"
  kill -KILL -- "-${codex_pid}" 2>/dev/null || true
) &
watchdog_pid=$!

status=0
wait "${codex_pid}" || status=$?
codex_pid=""
kill "${watchdog_pid}" 2>/dev/null || true
wait "${watchdog_pid}" 2>/dev/null || true
watchdog_pid=""
# Let the verbose-mode tee flush the log before it is read below.
wait 2>/dev/null || true

if [[ -e "${tmpdir}/timed-out" ]]; then
  printf '[codex subagent] timed out after %ss\n' "${timeout_s}" >&2
  status=124
fi

if [[ -s "${last_message}" ]]; then
  cat "${last_message}"
  printf '\n'
else
  printf '[codex subagent] no final message (exit %s)\n' "${status}" >&2
  [[ "${status}" -eq 0 ]] && status=1
fi

session_id="$(sed -n 's/^session id: *//p' "${log_file}" | head -n 1)"
if [[ -n "${session_id}" ]]; then
  printf '[codex subagent] session=%s (continue with -r %s)\n' "${session_id}" "${session_id}" >&2
fi

if [[ "${status}" -ne 0 && "${CODEX_SUBAGENT_VERBOSE:-0}" != "1" ]]; then
  keep_log=1
  printf '[codex subagent] last progress lines (full log: %s):\n' "${log_file}" >&2
  tail -n 20 "${log_file}" >&2 || true
fi

exit "${status}"
