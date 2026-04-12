{pkgs, config, ... }:

{
  imports = [
    ./home.nix
  ];
  home.packages = [
      pkgs.gnused
      pkgs.gawk
      pkgs.typst
      pkgs.openmpi
  ];

  home.homeDirectory = "/Users/${config.home.username}";

  xdg.configFile = {
    "yabai".source = ./config/yabai;
    "skhd".source = ./config/skhd;
  };
}
