{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "kohei";
  home.homeDirectory = "/Users/kohei";

  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    #shell
    pkgs.zsh

    pkgs.fzf
    pkgs.ripgrep
    pkgs.neovim
    pkgs.bat
    pkgs.zoxide
    #file manager
    pkgs.yazi

    pkgs.tmux
    pkgs.ffmpeg
    #git
    pkgs.git
    pkgs.git-lfs
    pkgs.ghq
    pkgs.gh
    pkgs.lazygit
    #coding agent
    pkgs.codex
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
      ".tmux.conf".source = ./.tmux.conf;
  };

  xdg.configFile = {
      "yabai".source = ./config/yabai;
      "skhd".source = ./config/skhd;
      "lazygit".source = ./config/lazygit;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/kohei/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
