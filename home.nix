{ pkgs, config, ... }:

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
    #pkgs.fd
    #pkgs.eza
    # hf CLI is installed via `uv tool install huggingface_hub` (see README)
    pkgs.tree
    pkgs.delta
    pkgs.oath-toolkit

    # file manager
    pkgs.yazi

    pkgs.tmux
    pkgs.herdr
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
    pkgs.nixfmt
    pkgs.ruff
    pkgs.shellcheck
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
    pkgs.python311

    # c/c++
    pkgs.cmake
    pkgs.ninja
    pkgs.automake
    pkgs.autoconf

    # other
    pkgs.codex
    #pkgs.claude-code
    pkgs.jq

    #net
    pkgs.nmap

    #fonts.
    pkgs.hackgen-nf-font
    pkgs.fira-code
    pkgs.nerd-fonts.hack
    pkgs.rictydiminished-with-firacode

  ];
  fonts.fontconfig.enable = true;
  home.file = {
    ".tmux.conf".source = ./.tmux.conf;
    ".codex/AGENTS.md".source = ./config/codex/AGENTS.md;
    # out-of-store: edits in the repo apply without a home-manager rebuild
    ".claude/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/claude/CLAUDE.md";
    ".claude/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/ai-agents/skills";
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
    # link the file only: ~/.config/herdr also holds runtime state (sockets, logs)
    "herdr/config.toml".source = ./config/herdr/config.toml;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    lfs.enable = true;
    # user/alias/ghq live in config/git/shared.gitconfig, shared with the
    # pixi backend (root .gitconfig includes the same file). Per-OS settings
    # like credential.helper stay in home-darwin.nix / home-linux.nix.
    includes = [
      { path = "${config.home.homeDirectory}/.dotfiles/config/git/shared.gitconfig"; }
    ];
  };

  programs.neovim = {
    enable = true;
    withRuby = true;
    withPython3 = true;
    plugins = with pkgs.vimPlugins; [
      nvim-lspconfig
      (nvim-treesitter.withPlugins (
        p: with p; [
          python
          c
          lua
          vim
          vimdoc
          query
          markdown
          markdown_inline
        ]
      ))
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
