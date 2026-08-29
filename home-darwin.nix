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

  home.file = {
    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/claude/settings.json";
    # herdr claude integration hook; `herdr integration install claude` rewrites it through this link
    ".claude/hooks/herdr-agent-state.sh".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/claude/hooks/herdr-agent-state.sh";
  };

  xdg.configFile = {
    "yabai".source = ./config/yabai;
    "skhd".source = ./config/skhd;
  };
}
