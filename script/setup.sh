#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="setup.sh"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=script/lib/bootstrap-common.sh
source "${SCRIPT_DIR}/lib/bootstrap-common.sh"

main() {
  local backend

  backend="$(resolve_setup_backend)"
  log "Selected bootstrap backend: ${backend}"

  case "${backend}" in
    nix)
      setup_with_nix
      ;;
    pixi)
      setup_with_pixi
      ;;
  esac
}

main "$@"
