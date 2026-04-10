{
  description = "Home Manager configuration of kohei";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
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
