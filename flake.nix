{
  description = "Home Manager configuration of kohei";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # 2026-07: unar fails to build on darwin/arm64 (cctools ld crash) on
    # current unstable; pin it to the last known-good rev until fixed upstream.
    nixpkgs-unar.url = "github:nixos/nixpkgs/331800de5053fcebacf6813adb5db9c9dca22a0c";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nixpkgs-unar, home-manager, ... }:
    let
      systems = {
        darwin = "aarch64-darwin";
        linux = "x86_64-linux";
      };

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              unar = nixpkgs-unar.legacyPackages.${system}.unar;
            })
          ];
        };

      mkHomeConfiguration =
        system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          inherit modules;
        };
    in
    {
      homeConfigurations = {
        kohei = mkHomeConfiguration systems.darwin [ ./home-darwin.nix ];
        kohei-darwin = mkHomeConfiguration systems.darwin [ ./home-darwin.nix ];
        kohei-linux = mkHomeConfiguration systems.linux [ ./home-linux.nix ];
      };
    };
}
