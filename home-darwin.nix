{ pkgs, config, ... }:

{
  imports = [
    ./home.nix
  ];

  home.packages = [
    pkgs.gnused
    pkgs.gawk
    pkgs.typst
    pkgs.texliveSmall
  ];

  home.homeDirectory = "/Users/${config.home.username}";

  programs.git.settings.credential.helper = "osxkeychain";

  xdg.configFile = {
    "yabai".source = ./config/yabai;
    "skhd".source = ./config/skhd;
  };
}
