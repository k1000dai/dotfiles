{ config, pkgs, ... }:

{
  imports = [
    ./home.nix
  ];

  home.homeDirectory = "/home/${config.home.username}";

  home.packages = [
    pkgs.gcc
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.xsel
    pkgs.fira-code
  ];
}
