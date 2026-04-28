{ config, pkgs, ... }:

{
  imports = [
    ./home.nix
  ];

  home.homeDirectory = "/home/${config.home.username}";
  home.file = {
      ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/claude/settings.json";
  };


  home.packages = [
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.xsel
    pkgs.fira-code
  ];
}
