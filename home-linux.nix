{ config, pkgs, ... }:

{
  imports = [
    ./home.nix
  ];

  home.homeDirectory = "/home/${config.home.username}";

  programs.git.settings.credential.helper = "cache";
  home.packages = [
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.xsel
    pkgs.fira-code
  ];
}
