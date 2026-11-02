#!/usr/bin/env bash
# Check settings migration and local-state isolation without touching real HOME.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sync_script="$repo_root/script/lib/sync-claude-settings.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-claude-settings.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
shared="$test_root/shared.json"
settings="$test_root/local/settings.json"
export TIMESTAMP=regression
export DRY_RUN=0

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
sync_settings() { bash "$sync_script" "$shared" "$settings"; }

cp "$repo_root/config/claude/settings.json" "$shared"
sync_settings
[[ -f "$settings" && ! -L "$settings" ]] || fail 'settings were not copied to a regular file'
jq -e '.autoMode.environment == null and .model == "opus"' "$settings" >/dev/null
[[ "$(LC_ALL=C ls -l "$settings")" == -rw-------* ]] || fail 'settings permissions are not private'
sync_settings
[[ ! -e "$settings.bak.regression" ]] || fail 'unchanged settings created a backup'

# Apply new shared defaults while keeping nested app/integration-owned state.
jq '.model = "local-model" | .env.LOCAL_ONLY = "keep"
  | .permissions.allow = ["Read"]
  | .hooks.PreToolUse = [{hooks: [{type: "command", command: "local-hook"}]}]
  | .autoMode.environment = ["this device only"]' "$shared" > "$settings"
cp "$settings" "$test_root/before.json"
sync_settings
jq -e '.model == "opus" and .env.LOCAL_ONLY == "keep"
  and .permissions.defaultMode == "auto" and .permissions.allow == ["Read"]
  and .hooks.PreToolUse[0].hooks[0].command == "local-hook"
  and .autoMode.environment == ["this device only"]' "$settings" >/dev/null
cmp "$test_root/before.json" "$settings.bak.regression"
sync_settings
[[ ! -e "$settings.bak.regression.1" ]] || fail 'rerun created another backup'

# Existing direct links and Home Manager-style link chains become local files.
for link_kind in direct chained; do
  settings="$test_root/$link_kind/settings.json"
  mkdir -p "$(dirname "$settings")"
  if [[ "$link_kind" == direct ]]; then
    ln -s "$shared" "$settings"
  else
    ln -s "$shared" "$test_root/generation.json"
    ln -s "$test_root/generation.json" "$settings"
  fi
  sync_settings
  [[ ! -L "$settings" && ! -L "$settings.bak.regression" ]] || fail 'migration or backup retained a live symlink'
  cmp "$shared" "$settings.bak.regression"
  printf '{"localOnly": true}\n' > "$settings"
  cmp "$repo_root/config/claude/settings.json" "$shared"
  sync_settings
  cmp "$shared" "$settings.bak.regression"
  jq -e '.localOnly == true' "$settings.bak.regression.1" >/dev/null
done

settings="$test_root/dangling/settings.json"
mkdir -p "$(dirname "$settings")"
ln -s "$test_root/missing.json" "$settings"
sync_settings
[[ -f "$settings" && ! -L "$settings" && -L "$settings.bak.regression" ]] || fail 'dangling symlink was not preserved and replaced'

# Invalid local JSON must never be replaced; invalid shared data cannot leak.
for invalid in 'invalid json' '[]' '{} {}'; do
  printf '%s\n' "$invalid" > "$settings"
  cp "$settings" "$test_root/invalid.json"
  if sync_settings > /dev/null 2>&1; then fail 'invalid settings were accepted'; fi
  cmp "$test_root/invalid.json" "$settings"
done

settings="$test_root/invalid-shared/settings.json"
printf '{"autoMode":{"environment":["project specific"]}}\n' > "$shared"
if sync_settings > /dev/null 2>&1; then fail 'project-specific environment was accepted as shared settings'; fi
[[ ! -d "$(dirname "$settings")" ]] || fail 'validation failure changed the destination'

cp "$repo_root/config/claude/settings.json" "$shared"
settings="$test_root/dry-run/settings.json"
DRY_RUN=1 sync_settings > /dev/null
[[ ! -d "$(dirname "$settings")" ]] || fail 'dry run changed the destination'

printf '%s\n' 'PASS: Claude settings migration, shared defaults, local state, backups, and dry run'
