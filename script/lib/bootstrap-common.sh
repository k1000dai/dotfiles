#!/usr/bin/env bash

# shellcheck shell=bash

SCRIPT_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd -- "${SCRIPT_LIB_DIR}/.." && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

TIMESTAMP="${TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"
DRY_RUN="${DRY_RUN:-0}"
SKIP_TOOL_INSTALL="${SKIP_TOOL_INSTALL:-0}"
SKIP_PIXI_SYNC="${SKIP_PIXI_SYNC:-0}"
BOOTSTRAP_BACKEND="${BOOTSTRAP_BACKEND:-auto}"
INSTALL_NIX="${INSTALL_NIX:-ask}"
NPM_GLOBAL_MANIFEST="${REPO_ROOT}/config/npm/npm-global-packages.txt"
NPM_GLOBAL_PREFIX="${HOME}/.local"

log() {
  printf '[%s] %s\n' "${SCRIPT_NAME:-bootstrap}" "$*" >&2
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

current_os() {
  uname -s
}

flake_target() {
  case "$(current_os)" in
    Darwin)
      printf '%s\n' "kohei"
      ;;
    Linux)
      printf '%s\n' "kohei-linux"
      ;;
    *)
      log "Unsupported OS: $(current_os)"
      return 1
      ;;
  esac
}

pixi_manifest_source() {
  case "$(current_os)" in
    Linux)
      printf '%s\n' "${REPO_ROOT}/config/pixi/manifests/pixi-global-linux.toml"
      ;;
    *)
      log "Unsupported OS for pixi manifest: $(current_os)"
      return 1
      ;;
  esac
}

pixi_backend_supported() {
  case "$(current_os)" in
    Linux)
      return 0
      ;;
    Darwin)
      log "pixi backend is not supported on macOS in this repository; use nix/home-manager instead"
      return 1
      ;;
    *)
      log "Unsupported OS for pixi backend: $(current_os)"
      return 1
      ;;
  esac
}

npm_global_prefix() {
  printf '%s\n' "${NPM_GLOBAL_PREFIX}"
}

source_nix_profile() {
  local profile_script

  if command -v nix >/dev/null 2>&1; then
    return 0
  fi

  for profile_script in \
    "${HOME}/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  do
    if [[ -r "${profile_script}" ]]; then
      # shellcheck disable=SC1090
      . "${profile_script}"
      break
    fi
  done
}

ensure_nix_command() {
  source_nix_profile
  command -v nix >/dev/null 2>&1
}

ensure_home_manager_command() {
  source_nix_profile
  command -v home-manager >/dev/null 2>&1
}

nix_cmd() {
  run nix --extra-experimental-features "nix-command flakes" "$@"
}

home_manager_cmd() {
  run home-manager --extra-experimental-features "nix-command flakes" "$@"
}

has_sudo() {
  command -v sudo >/dev/null 2>&1
}

can_use_sudo_non_interactively() {
  has_sudo && sudo -n true >/dev/null 2>&1
}

has_interactive_tty() {
  [[ -t 0 && -t 1 ]]
}

linux_has_systemd() {
  [[ -d /run/systemd/system ]] || command -v systemctl >/dev/null 2>&1
}

linux_selinux_disabled() {
  local selinux_state=""

  if [[ ! -e /sys/fs/selinux/enforce ]] \
    && ! command -v getenforce >/dev/null 2>&1 \
    && ! command -v sestatus >/dev/null 2>&1
  then
    return 0
  fi

  if command -v getenforce >/dev/null 2>&1; then
    selinux_state="$(getenforce 2>/dev/null || true)"
  elif command -v sestatus >/dev/null 2>&1; then
    selinux_state="$(sestatus 2>/dev/null | awk -F': *' '/SELinux status:/ { print $2; exit }')"
  elif [[ -r /sys/fs/selinux/enforce ]]; then
    case "$(cat /sys/fs/selinux/enforce 2>/dev/null || true)" in
      0)
        selinux_state="disabled"
        ;;
      1)
        selinux_state="enabled"
        ;;
    esac
  fi

  case "${selinux_state}" in
    Disabled|disabled)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

can_install_nix_multi_user() {
  case "$(current_os)" in
    Darwin)
      if ! has_sudo; then
        log "sudo is required for multi-user nix on macOS; falling back to pixi"
        return 1
      fi
      ;;
    Linux)
      if ! has_sudo; then
        log "sudo is required for multi-user nix on Linux; falling back to pixi"
        return 1
      fi

      if ! linux_has_systemd; then
        log "multi-user nix requires systemd on Linux; falling back to pixi"
        return 1
      fi

      if ! linux_selinux_disabled; then
        log "multi-user nix requires SELinux to be disabled on Linux; falling back to pixi"
        return 1
      fi
      ;;
    *)
      log "Unsupported OS for nix installation: $(current_os)"
      return 1
      ;;
  esac

  if has_interactive_tty; then
    return 0
  fi

  if can_use_sudo_non_interactively; then
    return 0
  fi

  log "multi-user nix needs interactive sudo or passwordless sudo; falling back to pixi"
  return 1
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    log "uv is already installed: $(command -v uv)"
    return 0
  fi

  log "Installing uv into ${HOME}/.local/bin"
  run_shell 'curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" sh'
  ensure_path "${HOME}/.local/bin"
}

install_pixi() {
  if command -v pixi >/dev/null 2>&1; then
    log "pixi is already installed: $(command -v pixi)"
    return 0
  fi

  log "Installing pixi into ${HOME}/.pixi/bin"
  run_shell 'curl -fsSL https://pixi.sh/install.sh | env PIXI_HOME="$HOME/.pixi" PIXI_BIN_DIR="$HOME/.pixi/bin" PIXI_NO_PATH_UPDATE=1 sh'
  ensure_path "${HOME}/.pixi/bin"
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

setup_links() {
  local manifest_source
  manifest_source="$(pixi_manifest_source)"

  link_path "${REPO_ROOT}/.bashrc" "${HOME}/.bashrc"
  link_path "${REPO_ROOT}/.gitconfig" "${HOME}/.gitconfig"
  link_path "${REPO_ROOT}/.tmux.conf" "${HOME}/.tmux.conf"
  link_path "${REPO_ROOT}/.zshrc" "${HOME}/.zshrc"
  link_path "${REPO_ROOT}/.zshrc.d" "${HOME}/.zshrc.d"
  link_path "${REPO_ROOT}/config/codex/AGENTS.md" "${HOME}/.codex/AGENTS.md"
  link_path "${REPO_ROOT}/config/claude/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
  link_path "${REPO_ROOT}/config/claude/settings.json" "${HOME}/.claude/settings.json"

  link_path "${REPO_ROOT}/config/nvim" "${HOME}/.config/nvim"
  link_path "${REPO_ROOT}/config/lazygit" "${HOME}/.config/lazygit"
  link_path "${REPO_ROOT}/config/ghostty" "${HOME}/.config/ghostty"
  link_path "${manifest_source}" "${HOME}/.pixi/manifests/pixi-global.toml"

  case "$(current_os)" in
    Darwin)
      link_path "${REPO_ROOT}/config/yabai" "${HOME}/.config/yabai"
      link_path "${REPO_ROOT}/config/skhd" "${HOME}/.config/skhd"
      ;;
    Linux)
      :
      ;;
    *)
      log "Unsupported OS for platform-specific links: $(current_os)"
      ;;
  esac
}

sync_pixi_global() {
  if [[ "${SKIP_PIXI_SYNC}" == "1" ]]; then
    log "Skipping pixi global sync because SKIP_PIXI_SYNC=1"
    return 0
  fi

  log "Syncing pixi global environments from ${HOME}/.pixi/manifests/pixi-global.toml"
  run pixi global sync
  run pixi global list
}

sync_neovim_plugins() {
  if [[ "${SKIP_PIXI_SYNC}" == "1" ]]; then
    log "Skipping Neovim plugin sync because SKIP_PIXI_SYNC=1"
    return 0
  fi

  if ! command -v nvim >/dev/null 2>&1; then
    log "Skipping Neovim plugin sync because nvim is not available on PATH"
    return 0
  fi

  log "Syncing Neovim plugins with lazy.nvim"
  if ! run nvim --headless "+Lazy! sync" +qa; then
    log "Neovim plugin sync failed; continuing without blocking setup"
  fi
}

sync_npm_global_packages() {
  local prefix
  local package_spec
  local packages=()

  if [[ ! -r "${NPM_GLOBAL_MANIFEST}" ]]; then
    log "npm global manifest not found: ${NPM_GLOBAL_MANIFEST}; skipping"
    return 0
  fi

  while IFS= read -r package_spec || [[ -n "${package_spec}" ]]; do
    if [[ "${package_spec}" =~ ^[[:space:]]*($|#) ]]; then
      continue
    fi

    packages+=("${package_spec}")
  done < "${NPM_GLOBAL_MANIFEST}"

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log "npm global packages are not configured; skipping"
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log "npm is required to install npm global packages from ${NPM_GLOBAL_MANIFEST}"
    return 1
  fi

  prefix="$(npm_global_prefix)"
  run mkdir -p "${prefix}/bin"
  log "Syncing npm global packages into ${prefix}: ${packages[*]}"
  run npm install -g --prefix "${prefix}" "${packages[@]}"
}

confirm_install_nix() {
  local answer

  case "${INSTALL_NIX}" in
    1|true|TRUE|yes|YES|y|Y)
      return 0
      ;;
    0|false|FALSE|no|NO|n|N)
      return 1
      ;;
    ask)
      if [[ ! -t 0 ]]; then
        log "nix is not installed and no interactive prompt is available; falling back to pixi"
        return 1
      fi

      while true; do
        printf 'nix is not installed. Install multi-user nix and use Home Manager? [Y/n]: ' >&2
        read -r answer || return 1
        case "${answer}" in
          ""|y|Y|yes|YES)
            return 0
            ;;
          n|N|no|NO)
            return 1
            ;;
          *)
            printf 'Please answer y or n.\n' >&2
            ;;
        esac
      done
      ;;
    *)
      log "Unsupported INSTALL_NIX value: ${INSTALL_NIX}"
      return 1
      ;;
  esac
}

install_nix_multi_user() {
  log "Installing nix in multi-user mode"
  if ! run_shell 'curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon'; then
    log "multi-user nix installation failed. Falling back to pixi is available."
    return 1
  fi

  source_nix_profile
  if ! command -v nix >/dev/null 2>&1; then
    log "nix installer completed but nix is not available in the current shell"
    return 1
  fi

  log "nix is now available: $(command -v nix)"
}

resolve_backend() {
  local command_name="${1:-setup}"

  source_nix_profile

  case "${BOOTSTRAP_BACKEND}" in
    auto)
      if ensure_nix_command; then
        printf '%s\n' "nix"
        return 0
      fi

      if [[ "${command_name}" == "update" ]]; then
        if pixi_backend_supported; then
          log "nix is not installed; using pixi refresh path"
          printf '%s\n' "pixi"
          return 0
        fi

        log "nix is not installed and no supported fallback backend is available"
        return 1
      fi

      if [[ "${SKIP_TOOL_INSTALL}" != "1" ]] \
        && confirm_install_nix \
        && can_install_nix_multi_user \
        && install_nix_multi_user
      then
        printf '%s\n' "nix"
        return 0
      fi

      if pixi_backend_supported; then
        printf '%s\n' "pixi"
        return 0
      fi

      log "nix is not installed and pixi fallback is unavailable on this platform"
      return 1
      ;;
    nix)
      if ensure_nix_command; then
        printf '%s\n' "nix"
        return 0
      fi

      if [[ "${SKIP_TOOL_INSTALL}" == "1" ]]; then
        log "BOOTSTRAP_BACKEND=nix but nix is not installed and SKIP_TOOL_INSTALL=1"
        return 1
      fi

      if [[ "${command_name}" == "update" ]]; then
        log "BOOTSTRAP_BACKEND=nix but nix is not installed"
        return 1
      fi

      if confirm_install_nix && can_install_nix_multi_user && install_nix_multi_user; then
        printf '%s\n' "nix"
        return 0
      fi

      log "BOOTSTRAP_BACKEND=nix was requested but nix could not be prepared"
      return 1
      ;;
    pixi)
      if ! pixi_backend_supported; then
        log "BOOTSTRAP_BACKEND=pixi was requested on an unsupported platform"
        return 1
      fi

      printf '%s\n' "pixi"
      ;;
    *)
      log "Unsupported BOOTSTRAP_BACKEND value: ${BOOTSTRAP_BACKEND}"
      return 1
      ;;
  esac
}

setup_with_pixi() {
  if ! pixi_backend_supported; then
    return 1
  fi

  ensure_path "${HOME}/.local/bin"
  ensure_path "${HOME}/.pixi/bin"

  if [[ "${SKIP_TOOL_INSTALL}" == "1" ]]; then
    log "Skipping uv/pixi installation because SKIP_TOOL_INSTALL=1"
  else
    install_uv
    install_pixi
  fi

  if ! command -v pixi >/dev/null 2>&1; then
    log "pixi command is required but was not found on PATH"
    return 1
  fi

  setup_links
  sync_pixi_global
  sync_neovim_plugins
  sync_npm_global_packages
  log "Pixi-based setup completed. Restart the shell or run: source ~/.zshrc"
}

setup_with_nix() {
  local target

  if ! ensure_nix_command; then
    log "nix is required for nix-based setup but was not found"
    return 1
  fi

  target="$(flake_target)"
  log "Applying Home Manager profile ${target}"
  if ! ensure_home_manager_command; then
    log "home-manager is required for nix-based setup but was not found"
    log "Install Home Manager standalone with flakes, then rerun ./script/setup.sh"
    log "Docs: https://github.com/nix-community/home-manager#installation"
    return 1
  fi

  home_manager_cmd switch --flake "${REPO_ROOT}#${target}"
  sync_npm_global_packages
  log "Nix-based setup completed."
}

update_with_pixi() {
  setup_with_pixi
}

update_with_nix() {
  if ! ensure_home_manager_command; then
    log "home-manager is required for nix-based update but was not found"
    return 1
  fi

  log "Updating flake input nixpkgs"
  nix_cmd flake update nixpkgs --flake "${REPO_ROOT}"
  setup_with_nix
}
