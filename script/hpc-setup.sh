#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

DRY_RUN="${DRY_RUN:-0}"
SKIP_TOOL_INSTALL="${SKIP_TOOL_INSTALL:-0}"
SKIP_PIXI_SYNC="${SKIP_PIXI_SYNC:-0}"

log() {
  printf '[hpc-setup] %s\n' "$*"
}

run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

run_shell() {
  local command="$1"

  if [[ "${DRY_RUN}" == "1" ]]; then
    printf '[dry-run] %s\n' "$command"
    return 0
  fi

  bash -lc "$command"
}

ensure_path() {
  case ":${PATH}:" in
    *":$1:"*) ;;
    *)
      PATH="$1:${PATH}"
      export PATH
      ;;
  esac
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    log "uv is already installed: $(command -v uv)"
    return
  fi

  log "Installing uv into ${HOME}/.local/bin"
  run_shell 'curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" sh'
}

install_pixi() {
  if command -v pixi >/dev/null 2>&1; then
    log "pixi is already installed: $(command -v pixi)"
    return
  fi

  log "Installing pixi into ${HOME}/.pixi/bin"
  run_shell 'curl -fsSL https://pixi.sh/install.sh | env PIXI_HOME="$HOME/.pixi" PIXI_BIN_DIR="$HOME/.pixi/bin" PIXI_NO_PATH_UPDATE=1 sh'
}

backup_target() {
  local target="$1"
  local backup_path="${target}.bak.${TIMESTAMP}"

  if [[ -e "${target}" || -L "${target}" ]]; then
    log "Backing up ${target} -> ${backup_path}"
    run mv "${target}" "${backup_path}"
  fi
}

link_path() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -e "${source_path}" && ! -L "${source_path}" ]]; then
    log "Skipping missing source: ${source_path}"
    return 0
  fi

  run mkdir -p "$(dirname "${target_path}")"

  if [[ -L "${target_path}" ]]; then
    local current_source
    current_source="$(readlink "${target_path}")"
    if [[ "${current_source}" == "${source_path}" ]]; then
      log "Link already exists: ${target_path}"
      return 0
    fi
  fi

  if [[ -e "${target_path}" || -L "${target_path}" ]]; then
    backup_target "${target_path}"
  fi

  log "Linking ${target_path} -> ${source_path}"
  run ln -s "${source_path}" "${target_path}"
}

pixi_manifest_source() {
  case "$(uname -s)" in
    Darwin)
      printf '%s\n' "${REPO_ROOT}/config/pixi/manifests/pixi-global.toml"
      ;;
    Linux)
      printf '%s\n' "${REPO_ROOT}/config/pixi/manifests/pixi-global-linux.toml"
      ;;
    *)
      printf '%s\n' "${REPO_ROOT}/config/pixi/manifests/pixi-global.toml"
      ;;
  esac
}

setup_links() {
  local manifest_source
  manifest_source="$(pixi_manifest_source)"

  link_path "${REPO_ROOT}/.bashrc" "${HOME}/.bashrc"
  link_path "${REPO_ROOT}/.tmux.conf" "${HOME}/.tmux.conf"
  link_path "${REPO_ROOT}/.zshrc" "${HOME}/.zshrc"
  link_path "${REPO_ROOT}/.zshrc.d" "${HOME}/.zshrc.d"
  link_path "${REPO_ROOT}/config/codex/AGENTS.md" "${HOME}/.codex/AGENTS.md"

  link_path "${REPO_ROOT}/config/nvim" "${HOME}/.config/nvim"
  link_path "${REPO_ROOT}/config/lazygit" "${HOME}/.config/lazygit"
  link_path "${REPO_ROOT}/config/ghostty" "${HOME}/.config/ghostty"
  link_path "${manifest_source}" "${HOME}/.pixi/manifests/pixi-global.toml"

  case "$(uname -s)" in
    Darwin)
      link_path "${REPO_ROOT}/config/yabai" "${HOME}/.config/yabai"
      link_path "${REPO_ROOT}/config/skhd" "${HOME}/.config/skhd"
      ;;
    Linux)
      :
      ;;
    *)
      log "Unsupported OS for platform-specific links: $(uname -s)"
      ;;
  esac
}

sync_pixi_global() {
  if [[ "${SKIP_PIXI_SYNC}" == "1" ]]; then
    log "Skipping pixi global sync because SKIP_PIXI_SYNC=1"
    return
  fi

  log "Syncing pixi global environments from ${HOME}/.pixi/manifests/pixi-global.toml"
  run pixi global sync
  run pixi global list
}

main() {
  ensure_path "${HOME}/.local/bin"
  ensure_path "${HOME}/.pixi/bin"

  if [[ "${SKIP_TOOL_INSTALL}" == "1" ]]; then
    log "Skipping uv/pixi installation because SKIP_TOOL_INSTALL=1"
  else
    install_uv
    ensure_path "${HOME}/.local/bin"
    install_pixi
    ensure_path "${HOME}/.pixi/bin"
  fi

  if ! command -v pixi >/dev/null 2>&1; then
    log "pixi command is required but was not found on PATH"
    exit 1
  fi

  setup_links
  sync_pixi_global

  log "Setup completed. Restart the shell or run: source ~/.zshrc"
}

main "$@"
