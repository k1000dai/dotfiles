{ pkgs,config, ... }:

{
  home.username = "kohei";
  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;
  home.packages = [
    # shell
    pkgs.zsh
    pkgs.fzf
    pkgs.ripgrep
    pkgs.bat
    pkgs.zoxide
    pkgs.direnv
    pkgs.pueue
    pkgs.fd
    pkgs.eza
    pkgs.python312Packages.huggingface-hub
    pkgs.tree
    pkgs.delta

    # file manager
    pkgs.yazi

    pkgs.tmux
    pkgs.ffmpeg_7
    pkgs.wget
    pkgs.unar
    pkgs.tree-sitter
    pkgs.bash-language-server
    pkgs.clang-tools
    pkgs.dockerfile-language-server
    pkgs.go
    pkgs.gopls
    pkgs.lua-language-server
    pkgs.marksman
    pkgs.ruff
    pkgs.taplo
    pkgs.ty
    pkgs.typescript
    pkgs.typescript-language-server
    pkgs.vscode-langservers-extracted
    pkgs.yaml-language-server
    pkgs.rust-analyzer
    pkgs.nodejs

    # git
    pkgs.git
    pkgs.git-lfs
    pkgs.ghq
    pkgs.gh
    pkgs.lazygit
    pkgs.pre-commit

    # python
    pkgs.uv
    pkgs.pixi

    # c/c++
    pkgs.cmake
    pkgs.ninja
    pkgs.automake
    pkgs.autoconf

    # other
    pkgs.codex
    pkgs.jq

    #net 
    pkgs.nmap
  ];

  home.file = {
    ".tmux.conf".source = ./.tmux.conf;
    ".codex/AGENTS.md".source = ./config/codex/AGENTS.md;
    ".claude/CLAUDE.md".source = ./config/claude/CLAUDE.md;
    ".zshrc_extra".source = ./.zshrc;
    ".zshrc.d".source = ./.zshrc.d;
    ".zsh/git-prompt.sh".source = ./.zsh/git-prompt.sh;
    ".sbuildrc".source = ./sbuildrc;
  };

  xdg.configFile = {
    "nvim".source = ./config/nvim;
    "lazygit".source = ./config/lazygit;
    "ghostty".source = ./config/ghostty;
    "wezterm".source = ./config/wezterm;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "k1000dai";
      user.email = "chiyodakku1000@gmail.com";
      ghq.root = "~/codes/ghq";
      alias = {
        st = "status -s";
        l = "log --oneline --graph";
        al = "log --oneline --graph --all";
        s = "switch";
      };
    };
  };

  programs.neovim = {
    enable = true;
    withRuby = true;
    withPython3 = true;
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

  programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      historySubstringSearch.enable = true;
      syntaxHighlighting.enable = true;
      initContent = ''
        source $HOME/.zshrc_extra
      '';
  };
}
