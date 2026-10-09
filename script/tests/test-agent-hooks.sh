#!/usr/bin/env bash
# Exercise the Stop hook in disposable repositories with a mock pre-commit.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hook="${repo_root}/config/claude/hooks/pre-commit-stop.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-agent-hooks.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
test_root="$(cd "$test_root" && pwd -P)"
test_repo="${test_root}/repo with spaces"
mkdir -p "$test_repo/nested" "$test_root/bin" "$test_root/not-a-repo"
export MOCK_LOG="${test_root}/pre-commit.log"
export MOCK_OUTPUT="${test_root}/pre-commit.out"
export MOCK_EXIT=0
cat >"$test_root/bin/pre-commit" <<'MOCK'
#!/bin/sh
printf '%s\n' "$PWD" "$*" >>"$MOCK_LOG"
cat "$MOCK_OUTPUT"
exit "$MOCK_EXIT"
MOCK
chmod +x "$test_root/bin/pre-commit"
export PATH="${test_root}/bin:${PATH}"
: >"$MOCK_OUTPUT"

git -C "$test_repo" init --quiet
printf 'repos: []\n' >"$test_repo/.pre-commit-config.yaml"
printf 'original\n' >"$test_repo/tracked.txt"
git -C "$test_repo" add .
git -C "$test_repo" -c user.name=Test -c user.email=test@example.invalid \
  -c core.hooksPath=/dev/null -c commit.gpgsign=false commit --quiet -m initial

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

run_hook() {
  local hook_input="$1"
  : >"$MOCK_LOG"
  hook_output="$(cd "$test_root/not-a-repo" && printf '%s' "$hook_input" | sh "$hook")"
}

assert_skipped() {
  [ ! -s "$MOCK_LOG" ] || fail "$1 invoked pre-commit"
  [ -z "$hook_output" ] || fail "$1 emitted a Stop decision"
}

payload="$(jq -n --arg cwd "$test_repo/nested" '{cwd: $cwd, stop_hook_active: false}')"
run_hook "$payload"
assert_skipped 'clean repository'

printf 'changed\n' >>"$test_repo/tracked.txt"
run_hook "$payload"
[ "$(sed -n '1p' "$MOCK_LOG")" = "$test_repo" ] || fail 'nested cwd did not select the repository root'
[ "$(sed -n '2p' "$MOCK_LOG")" = 'run --all-files' ] || fail 'wrong pre-commit arguments'
[ "$(wc -l <"$MOCK_LOG" | tr -d ' ')" = 2 ] || fail 'pre-commit ran more than once'
[ -z "$hook_output" ] || fail 'successful check blocked Stop'

test_worktree="$test_root/linked worktree"
git -C "$test_repo" worktree add --quiet --detach "$test_worktree" HEAD
mkdir "$test_worktree/nested"
printf 'worktree change\n' >>"$test_worktree/tracked.txt"
run_hook "$(jq -n --arg cwd "$test_worktree/nested" '{cwd: $cwd}')"
[ "$(sed -n '1p' "$MOCK_LOG")" = "$test_worktree" ] || fail 'worktree cwd did not select the worktree root'

run_hook "$(jq '.stop_hook_active = true' <<<"$payload")"
assert_skipped 'recursive Stop event'

for bad_input in 'invalid json' 'null' '[]' '{}' '{"cwd":17}'; do
  run_hook "$bad_input"
  assert_skipped 'invalid input'
done

run_hook "$(jq -n --arg cwd "$test_root/not-a-repo" '{cwd: $cwd}')"
assert_skipped 'non-Git directory'

export MOCK_EXIT=1
# A >1 MB UTF-8 log must not be passed in argv, where it can exceed ARG_MAX.
jq -nr '"前" * 400000 + "\n検査失敗"' >"$MOCK_OUTPUT"
run_hook "$payload"
jq -e '.decision == "block" and (.reason | endswith("検査失敗"))
  and (.reason | length < 3200) and (.reason | contains("�") | not)' \
  <<<"$hook_output" >/dev/null || fail 'failure feedback was not valid, bounded Unicode JSON'
export MOCK_EXIT=0
: >"$MOCK_OUTPUT"

# Mock only executable discovery so the actual user install stays untouched.
: >"$MOCK_LOG"
hook_output="$(printf '%s' "$payload" | bash -c '
  command() {
    [ "$*" != "-v pre-commit" ] || return 1
    builtin command "$@"
  }
  source "$1"
' _ "$hook")"
[ ! -s "$MOCK_LOG" ] || fail 'missing pre-commit unexpectedly invoked the executable'
jq -e '.decision == "block" and (.reason | contains("not on PATH"))' \
  <<<"$hook_output" >/dev/null || fail 'missing pre-commit did not explain the failure'

git -C "$test_repo" restore tracked.txt
git -C "$test_repo" config status.showUntrackedFiles no
printf 'new\n' >"$test_repo/new.txt"
run_hook "$payload"
[ -s "$MOCK_LOG" ] || fail 'untracked changes were ignored by Git configuration'

git -C "$test_repo" add new.txt
run_hook "$payload"
[ -s "$MOCK_LOG" ] || fail 'staged changes were ignored'

rm "$test_repo/.pre-commit-config.yaml"
run_hook "$payload"
assert_skipped 'repository without pre-commit configuration'

jq -e '.hooks.Stop[0].hooks[0].command == "sh \"$HOME/.claude/hooks/pre-commit-stop.sh\""
  and .hooks.SessionStart[0].hooks[0].command == "sh \"$HOME/.claude/hooks/herdr-agent-state.sh\" session"' \
  "$repo_root/config/claude/settings.json" >/dev/null || fail 'hook commands are not portable'

printf '%s\n' 'PASS: agent hook regression tests'
