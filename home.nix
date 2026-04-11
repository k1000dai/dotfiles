{ pkgs, ... }:

{
  home.username = "kohei";
  home.stateVersion = "25.11";

  home.packages = [
    # shell
    pkgs.zsh
    pkgs.fzf
    pkgs.ripgrep
    pkgs.bat
    pkgs.zoxide

    # file manager
    pkgs.yazi

    pkgs.tmux
    pkgs.ffmpeg
    pkgs.wget
    pkgs.tree-sitter
    pkgs.clang-tools
    pkgs.ruff
    pkgs.ty
    pkgs.typescript
    pkgs.typescript-language-server
    pkgs.vscode-langservers-extracted
    pkgs.rust-analyzer

    # git
    pkgs.git
    pkgs.git-lfs
    pkgs.ghq
    pkgs.gh
    pkgs.lazygit

    # python
    pkgs.uv
    pkgs.pixi

    # coding agent
    pkgs.codex

    # other
    pkgs.dvc
    pkgs.cmake
  ];

  home.file = {
    ".tmux.conf".source = ./.tmux.conf;
    ".codex/AGENTS.md".source = ./config/codex/AGENTS.md;
    ".zshrc".source = ./.zshrc;
  };

  xdg.configFile = {
    "nvim".source = ./config/nvim;
    "lazygit".source = ./config/lazygit;
    "ghostty".source = ./config/ghostty;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.home-manager.enable = true;
  programs.neovim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      nvim-lspconfig
      (nvim-treesitter.withPlugins (p: with p; [
        python
        c
        lua
        vim
        vimdoc
        query
        markdown
        markdown_inline
      ]))
    ];
  };

}
