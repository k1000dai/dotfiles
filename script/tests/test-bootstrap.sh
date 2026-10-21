#!/usr/bin/env bash
# Isolated regression tests: no network, installers, or changes to the real HOME.
# Mocks and configuration variables are consumed by the sourced library.
# shellcheck disable=SC2034,SC2329
set -euo pipefail

if [[ "${1:-}" != --isolated ]]; then
  test_root="$(mktemp -d)"
  trap 'rm -rf "$test_root"' EXIT
  mkdir -p "$test_root/home" "$test_root/tmp"
  env -i HOME="$test_root/home" TMPDIR="$test_root/tmp" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    /bin/bash "$0" --isolated "$test_root"
  exit
fi

TEST_ROOT="$2"
BOOTSTRAP_LIB="$(cd -- "$(dirname -- "$0")/../lib" && pwd)/bootstrap-common.sh"
export TEST_ROOT BOOTSTRAP_LIB
# shellcheck source=/dev/null
source "$BOOTSTRAP_LIB"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
assert_calls() {
  [[ "$(cat "$TEST_ROOT/calls")" == "$1" ]] || fail "unexpected command: $(cat "$TEST_ROOT/calls")"
}
stub_binary() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<STUB
#!/bin/bash
printf '%s:%s\n' '$2' "\$*" >> "\${TEST_ROOT}/calls"
exit ${3:-0}
STUB
  chmod +x "$1"
}

# Exercise the actual download wrapper, including a failing installer under -e.
curl() {
  while [[ "$1" != -o ]]; do shift; done
  printf '%s\n' "$2" > "$TEST_ROOT/download-path"
  printf 'exit %s\n' "${INSTALLER_STATUS:-0}" > "$2"
  return "${DOWNLOAD_STATUS:-0}"
}
export -f curl
for outcome in success download-failure installer-failure; do
  download_status=0 installer_status=0 expected_status=0
  case "$outcome" in
    download-failure) download_status=22 expected_status=1 ;;
    installer-failure) installer_status=17 expected_status=17 ;;
  esac
  status=0
  # The child shell evaluates these variable references.
  # shellcheck disable=SC2016
  env DOWNLOAD_STATUS="$download_status" INSTALLER_STATUS="$installer_status" \
    /bin/bash -ec '
      source "$BOOTSTRAP_LIB"
      trap '\''printf "caller-exit\n" >> "$TEST_ROOT/traps"'\'' EXIT
      trap '\''printf "caller-return\n" >> "$TEST_ROOT/traps"'\'' RETURN
      before=$(trap -p EXIT RETURN)
      safe_curl_run https://example.invalid/installer test
      [[ "$(trap -p EXIT RETURN)" == "$before" ]]
    ' || status=$?
  [[ "$status" == "$expected_status" ]] || fail "$outcome returned $status"
  [[ ! -e "$(cat "$TEST_ROOT/download-path")" ]] || fail "$outcome left installer behind"
  [[ "$(tail -n 1 "$TEST_ROOT/traps")" == caller-exit ]] || fail "caller EXIT trap lost"
  pass "download cleanup and trap isolation: $outcome"
done

# Keep PATH shadows executable so accidentally dispatching to them is observable.
stub_binary "$TEST_ROOT/shadow/herdr" shadow-herdr
stub_binary "$TEST_ROOT/shadow/claude" shadow-claude
PATH="$TEST_ROOT/shadow:$PATH"
export PATH
(
  safe_curl_run() {
    printf 'installer:%s:%s\n' "$2" "$HERDR_INSTALL_DIR" >> "$TEST_ROOT/calls"
    [[ ":$PATH:" == *":$HERDR_INSTALL_DIR:"* ]] || fail "installer directory missing from PATH"
  }
  : > "$TEST_ROOT/calls"
  sync_herdr
  assert_calls "installer:herdr:$HOME/.local/bin"
  pass 'herdr installs at managed path despite PATH shadow'

  HERDR_INSTALL_DIR="$TEST_ROOT/custom tools"
  : > "$TEST_ROOT/calls"
  sync_herdr
  assert_calls "installer:herdr:$HERDR_INSTALL_DIR"
  stub_binary "$HERDR_INSTALL_DIR/herdr" managed-herdr
  : > "$TEST_ROOT/calls"
  sync_herdr
  assert_calls 'managed-herdr:update'
  pass 'herdr honors custom install directory for install and update'

  rm "$HERDR_INSTALL_DIR/herdr"
  ln -s "$TEST_ROOT/shadow/herdr" "$HERDR_INSTALL_DIR/herdr"
  : > "$TEST_ROOT/calls"
  sync_herdr
  assert_calls "installer:herdr:$HERDR_INSTALL_DIR"
  pass 'herdr never self-updates a package-manager symlink'

  : > "$TEST_ROOT/calls"
  SKIP_TOOL_INSTALL=1 sync_herdr
  assert_calls ''
  # Restore the real wrapper to verify DRY_RUN suppresses downloads as well.
  # shellcheck source=/dev/null
  source "$BOOTSTRAP_LIB"
  curl() { fail 'dry run downloaded an installer'; }
  DRY_RUN=1 sync_herdr > "$TEST_ROOT/dry-install"
  [[ ! -s "$TEST_ROOT/calls" ]] || fail 'dry run executed herdr'
  rm "$HERDR_INSTALL_DIR/herdr"
  stub_binary "$HERDR_INSTALL_DIR/herdr" managed-herdr
  DRY_RUN=1 sync_herdr > "$TEST_ROOT/dry-update"
  [[ ! -s "$TEST_ROOT/calls" ]] || fail 'dry run updated herdr'
  pass 'herdr skip and dry-run suppress execution'

  stub_binary "$HERDR_INSTALL_DIR/herdr" failed-herdr 23
  safe_curl_run() { fail 'failed update fell back to installer'; }
  status=0
  sync_herdr || status=$?
  [[ "$status" == 23 ]] || fail "herdr update failure was masked: $status"
  assert_calls 'failed-herdr:update'
  pass 'herdr update failure propagates without reinstalling'
)

(
  safe_curl_run() { printf 'installer:%s\n' "$2" >> "$TEST_ROOT/calls"; }
  : > "$TEST_ROOT/calls"
  sync_claude_code
  assert_calls 'installer:claude-code'
  stub_binary "$HOME/.local/bin/claude" managed-claude
  : > "$TEST_ROOT/calls"
  sync_claude_code
  assert_calls 'managed-claude:update'
  stub_binary "$HOME/.local/bin/claude" failed-claude 19
  : > "$TEST_ROOT/calls"
  status=0
  sync_claude_code || status=$?
  [[ "$status" == 19 ]] || fail "Claude update failure was masked: $status"
  assert_calls 'failed-claude:update'
  pass 'Claude uses managed path and propagates update failures'
)

(
  current_os() { printf 'Linux\n'; }
  TIMESTAMP=regression
  mkdir -p "$HOME/.claude/hooks" "$HOME/.agents/skills/keep-me" "$HOME/.config/herdr"
  printf 'old instructions\n' > "$HOME/.codex-old"
  mkdir -p "$HOME/.codex"
  cp "$HOME/.codex-old" "$HOME/.codex/AGENTS.md"
  printf 'runtime state\n' > "$HOME/.config/herdr/runtime"
  setup_links > /dev/null 2>&1
  for mapping in \
    '.local/bin/observatory:script/observatory.py' \
    '.codex/AGENTS.md:config/codex/AGENTS.md' \
    '.claude/CLAUDE.md:config/claude/CLAUDE.md' \
    '.claude/settings.json:config/claude/settings.json' \
    '.claude/skills:config/ai-agents/skills' \
    '.agents/skills/sanitize-artifacts:config/ai-agents/skills/sanitize-artifacts' \
    '.claude/hooks/herdr-agent-state.sh:config/claude/hooks/herdr-agent-state.sh' \
    '.claude/hooks/pre-commit-stop.sh:config/claude/hooks/pre-commit-stop.sh'; do
    [[ "$(readlink "$HOME/${mapping%%:*}")" == "$REPO_ROOT/${mapping#*:}" ]] || fail "wrong link: $mapping"
  done
  cmp "$HOME/.codex-old" "$HOME/.codex/AGENTS.md.bak.regression"
  [[ -d "$HOME/.agents/skills/keep-me" ]] || fail 'unmanaged skill lost'
  [[ ! -L "$HOME/.config/herdr" && -f "$HOME/.config/herdr/runtime" ]] || fail 'herdr state replaced'
  setup_links > /dev/null 2>&1
  cmp "$HOME/.codex-old" "$HOME/.codex/AGENTS.md.bak.regression"
  pass 'Linux links preserve backups, runtime state, and unmanaged skills on rerun'
)

(
  node() { printf 'node:%s\n' "$2" >> "$TEST_ROOT/calls"; return "${CHECK_STATUS:-1}"; }
  python3() {
    [[ "$1" != -c ]] || return 0
    printf 'python3:%s\n' "$2" >> "$TEST_ROOT/calls"
    [[ "$2" != connect ]] || return "${CONNECT_STATUS:-0}"
  }
  has_interactive_stdin() { return "${TTY_STATUS:-0}"; }
  : > "$TEST_ROOT/calls"
  CHECK_STATUS=0 sync_observatory 2> /dev/null
  assert_calls 'node:check'
  pass 'Observatory skips pairing when already connected'

  : > "$TEST_ROOT/calls"
  sync_observatory 2> /dev/null
  assert_calls $'node:check\npython3:connect\npython3:setup'
  pass 'Observatory pairs and registers agents when not connected'

  : > "$TEST_ROOT/calls"
  CONNECT_STATUS=130 sync_observatory 2> /dev/null
  assert_calls $'node:check\npython3:connect'
  pass 'Observatory pairing failure does not abort bootstrap'

  : > "$TEST_ROOT/calls"
  TTY_STATUS=1 sync_observatory 2> /dev/null
  assert_calls 'node:check'
  : > "$TEST_ROOT/calls"
  SKIP_OBSERVATORY=1 sync_observatory 2> /dev/null
  assert_calls ''
  : > "$TEST_ROOT/calls"
  DRY_RUN=1 TTY_STATUS=1 sync_observatory > "$TEST_ROOT/dry-observatory" 2> /dev/null
  assert_calls 'node:check'
  grep -q 'observatory.py connect' "$TEST_ROOT/dry-observatory" || fail 'dry run omitted Observatory pairing'
  pass 'Observatory honors no terminal, SKIP_OBSERVATORY, and DRY_RUN'
)

# Worker synchronization is skipped without a connection, respects opt-out,
# and routes through run() so dry-run never starts a daemon.
(
  node() { printf 'node:%s\n' "$2" >> "$TEST_ROOT/calls"; return "${CHECK_STATUS:-0}"; }
  : > "$TEST_ROOT/calls"
  SKIP_OBSERVATORY_WORKER=1 sync_observatory_worker
  assert_calls ''
  : > "$TEST_ROOT/calls"
  CHECK_STATUS=1 sync_observatory_worker
  assert_calls 'node:check'
  : > "$TEST_ROOT/calls"
  sync_observatory_worker
  assert_calls $'node:check\nnode:sync'
  : > "$TEST_ROOT/calls"
  DRY_RUN=1 sync_observatory_worker > "$TEST_ROOT/dry-worker"
  assert_calls 'node:check'
  # printf %q in bash 3.2 (macOS /bin/bash) escapes commas.
  grep -qE 'observatory-worker\.mjs sync --default-agents=codex\\?,claude --default-owners=k1000dai\\?,airoa-org' "$TEST_ROOT/dry-worker" \
    || fail 'worker defaults missing from dry run'
  OBSERVATORY_WORKER_OWNERS='' DRY_RUN=1 sync_observatory_worker > "$TEST_ROOT/dry-worker"
  grep -q -- '--default-owners=$' "$TEST_ROOT/dry-worker" || fail 'empty owners did not opt out'
  pass 'worker sync honors authentication, opt-out, dry-run, and defaults'
)

# Run both public entrypoints with a mocked Linux platform and inert tool stubs.
# DRY_RUN must prevent all commands below from actually running.
uname() { printf 'Linux\n'; }
# Avoid sourcing the host's /nix profile while running the real entrypoints.
nix() { fail 'nix executed during pixi dry run'; }
pixi() { fail 'pixi executed during dry run'; }
uv() { fail 'uv executed during dry run'; }
npm() { fail 'npm executed during dry run'; }
nvim() { fail 'nvim executed during dry run'; }
curl() { fail 'network accessed during dry run'; }
export -f uname nix pixi uv npm nvim curl fail
mkdir -p "$TEST_ROOT/dry-home"
for entrypoint in setup update; do
  env HOME="$TEST_ROOT/dry-home" BOOTSTRAP_BACKEND=pixi DRY_RUN=1 \
    /bin/bash "$REPO_ROOT/script/$entrypoint.sh" > "$TEST_ROOT/$entrypoint.log" 2>&1
  [[ -z "$(ls -A "$TEST_ROOT/dry-home")" ]] || fail "$entrypoint dry run changed HOME"
  grep -q 'pixi global sync' "$TEST_ROOT/$entrypoint.log" || fail "$entrypoint missed pixi sync"
  grep -q 'herdr.dev/install.sh' "$TEST_ROOT/$entrypoint.log" || fail "$entrypoint missed herdr"
  pass "$entrypoint pixi dry run on mocked Linux"
done

# Auto update must never ask to install nix, even when install is opted in.
(
  source_nix_profile() { :; }
  ensure_nix_command() { return 1; }
  confirm_install_nix() { fail 'update prompted to install nix'; }
  current_os() { printf 'Linux\n'; }
  BOOTSTRAP_BACKEND=auto INSTALL_NIX=1
  [[ "$(resolve_backend update)" == pixi ]] || fail 'update did not choose pixi'
  pass 'update never prompts to install nix'
)
