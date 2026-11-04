#!/usr/bin/env bash
# Apply shared keys to a writable local file; never write through its symlink.
set -euo pipefail

shared_settings="$1"
local_settings="$2"

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  printf '[dry-run] Merge shared Claude settings from %s into %s\n' "$shared_settings" "$local_settings"
  exit 0
fi

existing_settings=/dev/null
if [[ -e "$local_settings" ]]; then
  [[ -f "$local_settings" ]] || { printf 'Claude settings must be a file: %s\n' "$local_settings" >&2; exit 1; }
  existing_settings="$local_settings"
fi

# Validate before creating directories, backups, or replacing the live file.
jq -e -s 'length == 1 and (.[0] | type == "object")
  and (.[0].autoMode // {} | has("environment") | not)' "$shared_settings" >/dev/null
if [[ "$existing_settings" != /dev/null ]]; then
  jq -e -s 'length == 1 and (.[0] | type == "object")' "$existing_settings" >/dev/null
fi

umask 077
mkdir -p "$(dirname "$local_settings")"
settings_tmpfile="$(mktemp "${local_settings}.tmp.XXXXXX")"
trap 'rm -f "$settings_tmpfile"' EXIT

# Objects merge recursively. Shared scalar/array values win; keys absent from
# the shared file (including app-generated environment state) stay local.
# Permission rule lists are unions, so rules Claude Code saved locally survive
# alongside shared rules.
jq -S -n --slurpfile shared "$shared_settings" --slurpfile existing "$existing_settings" '
  ($existing[0] // {}) as $local
  | ($local * $shared[0])
  | reduce ("allow", "ask", "deny") as $kind (.;
      ([$local.permissions[$kind]?, $shared[0].permissions[$kind]?]
        | map(arrays) | add) as $rules
      | if $rules == null then . else
          .permissions[$kind] = ($rules
            | reduce .[] as $rule ([]; if index([$rule]) then . else . + [$rule] end))
        end)' > "$settings_tmpfile"

if [[ ! -L "$local_settings" ]] && cmp -s "$settings_tmpfile" "$local_settings"; then
  exit 0
fi

if [[ -e "$local_settings" || -L "$local_settings" ]]; then
  backup_base="${local_settings}.bak.${TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"
  backup_path="$backup_base"
  backup_number=0
  while [[ -e "$backup_path" || -L "$backup_path" ]]; do
    backup_number=$((backup_number + 1))
    backup_path="${backup_base}.${backup_number}"
  done
  if [[ -e "$local_settings" ]]; then
    # Snapshot contents, so later source edits cannot change the backup.
    cp -L "$local_settings" "$backup_path"
    chmod 600 "$backup_path"
  else
    cp -P "$local_settings" "$backup_path"
  fi
  printf 'Backed up Claude settings to %s\n' "$backup_path" >&2
fi

mv -f "$settings_tmpfile" "$local_settings"
printf 'Applied shared Claude settings to %s\n' "$local_settings" >&2
