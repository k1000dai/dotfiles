{pkgs, config, ... }:

{
  imports = [
    ./home.nix
  ];

  home.packages = [
      pkgs.gnused
      pkgs.gawk
      pkgs.typst
      #pkgs.openmpi
  ];

  home.homeDirectory = "/Users/${config.home.username}";

  home.file = {
      ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/claude/settings.json";
  };

  xdg.configFile = {
    "yabai".source = ./config/yabai;
    "skhd".source = ./config/skhd;
  };
}
