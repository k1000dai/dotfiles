# dotfiles

Home Manager configuration for macOS and Ubuntu.

## Supported Platforms

- macOS Apple Silicon: `aarch64-darwin`
- Ubuntu: `x86_64-linux`

## Apply

```bash
# macOS
nix run nixpkgs#home-manager -- switch --flake .#kohei

# Ubuntu
nix run nixpkgs#home-manager -- switch --flake .#kohei-linux
```

## Check Before Switching

```bash
nix flake show --all-systems --no-write-lock-file
nix run nixpkgs#home-manager -- build --flake .#kohei-linux
```
