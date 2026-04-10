{ config, ... }:

{
  imports = [
    ./home.nix
  ];

  home.homeDirectory = "/Users/${config.home.username}";

  xdg.configFile = {
    "yabai".source = ./config/yabai;
    "skhd".source = ./config/skhd;
  };
}
