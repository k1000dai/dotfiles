#!/usr/bin/env bash

set -euo pipefail

case "$(uname -s)" in
  Darwin)
    flake_target="kohei"
    ;;
  Linux)
    flake_target="kohei-linux"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

# Update the flake input.
nix flake update nixpkgs

# Apply the matching Home Manager profile explicitly.
home-manager switch --flake ".#${flake_target}"
