


# exec zsh if possible
if [ -t 1 ] && [ -x "$(command -v zsh)" ] && [ -z "$ZSH_VERSION" ]; then
    export SHELL="$(command -v zsh)"
    exec zsh
else
    source_if_exists() {
      local file_path="$1"
      [[ -r "$file_path" ]] && source "$file_path"
    }
    
    prepend_path() {
      local dir_path="$1"
    
      [[ -d "$dir_path" ]] || return 0
    
      case ":$PATH:" in
        *":$dir_path:"*) ;;
        *) PATH="$dir_path${PATH:+:$PATH}" ;;
      esac
    }
    
    git_prompt_segment() {
      declare -F __git_ps1 >/dev/null || return 0
      __git_ps1 '(%s) '
    }
    
    case "$(uname -s)" in
      Darwin)
        BASH_PLATFORM="darwin"
        ;;
      Linux)
        BASH_PLATFORM="linux"
        ;;
      *)
        BASH_PLATFORM="unknown"
        ;;
    esac
    
    export BASH_PLATFORM
    
    # default editor
    export EDITOR="nvim"
    
    alias clang++="clang++ -std=c++17 -Wall -Wextra -Wconversion"
    alias clang="clang -std=c99 -Wall -Wextra"
    alias la="ls -a"
    alias ll="ls -l"
    alias ...="cd ../.."
    alias nv="nvim"
    alias vim="nvim"
    alias l="ls"
    alias ga="git add"
    alias reboot_shell='exec "$SHELL" -l'
    alias reload="source ~/.bashrc"
    alias gb="git branch"
    alias gc="git commit -m"
    alias gs="git switch"
    alias gp="git push"
    alias venv="source .venv/bin/activate"
    alias lg="lazygit"
    alias gg="ghq get"
    
    # yazi
    alias finder="yazi"
    
    gitmain() {
      git config --global user.name "k1000dai"
      git config --global user.email "chiyodakku1000@gmail.com"
    }
    
    gitmain_local() {
      git config --local user.name "k1000dai"
      git config --local user.email "chiyodakku1000@gmail.com"
    }
    
    # git user name
    git_usr_name() {
      local repo_info git_usr_name_value
    
      repo_info="$(git rev-parse --git-dir --is-inside-git-dir \
        --is-bare-repository --is-inside-work-tree \
        --short HEAD 2>/dev/null)"
      git_usr_name_value="$(git config user.name)"
    
      if [[ -n "$repo_info" ]]; then
        echo "[$git_usr_name_value]"
      fi
    }
    
    # zoxide
    if command -v zoxide >/dev/null 2>&1; then
      eval "$(zoxide init bash)"
      alias cd="z"
    fi
    
    # Git
    source_if_exists "$HOME/.zsh/git-prompt.sh"
    source_if_exists "$HOME/.zsh/git-completion.bash"
    GIT_PS1_SHOWDIRTYSTATE=true
    
    # bash-completion
    source_if_exists "/opt/homebrew/etc/profile.d/bash_completion.sh"
    source_if_exists "/usr/local/etc/profile.d/bash_completion.sh"
    source_if_exists "/usr/share/bash-completion/bash_completion"
    
    ghq_fzf() {
      local src repo_root
    
      repo_root="$(ghq root)" || return 1
      src="$(ghq list | fzf --preview "bat --color=always --style=header,grid --line-range :80 ${repo_root}/{}/README.* 2>/dev/null")" || return 0
      [[ -z "$src" ]] && return 0
      printf '%s' "$(printf 'cd %q' "${repo_root}/${src}")"
    }
    
    ghq_fzf_bind() {
      local cmd
    
      cmd="$(ghq_fzf)" || return 0
      [[ -z "$cmd" ]] && return 0
      READLINE_LINE="$cmd"
      READLINE_POINT=${#READLINE_LINE}
    }
    
    if [[ $- == *i* ]]; then
      bind -x '"\C-g":ghq_fzf_bind'
    fi
    
    # env
    source_if_exists "$HOME/.local/bin/env"
    source_if_exists "$HOME/.env"
    
    if command -v pixi >/dev/null 2>&1; then
      eval "$(pixi completion --shell bash)"
    fi
    
    if command -v uv >/dev/null 2>&1; then
      eval "$(uv generate-shell-completion bash)"
    fi
    
    prepend_path "$HOME/.pixi/bin"
    prepend_path "$HOME/.local/bin"
    prepend_path "/usr/local/smlnj/bin"
    
    export PATH
    export XDG_CONFIG_HOME="${HOME}/.config"
    
    case "$BASH_PLATFORM" in
      darwin)
        export LSCOLORS="exfxcxdxbxegedabagacad"
        alias ls="ls -G -F"
    
        prepend_path "/opt/homebrew/bin"
        prepend_path "/opt/homebrew/opt/llvm/bin"
    
        export STM32CubeMX_PATH="$HOME/Applications/Applications.app/Contents/Resources"
    
        if [[ -d /opt/homebrew/include ]]; then
          export CPLUS_INCLUDE_PATH="/opt/homebrew/include${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
        fi
    
        export CPPYGEN_LIBCLANG_PATH="/opt/homebrew/opt/llvm/lib/libclang.dylib"
        export CC="/opt/homebrew/opt/llvm/bin/clang"
        export CXX="/opt/homebrew/opt/llvm/bin/clang++"
    
        PS1='\h \w\n\[\e[31m\]$(git_prompt_segment)\[\e[0m\]\[\e[1;33m\]$(git_usr_name)\[\e[0m\]\[\e[36m\]\$ \[\e[0m\]'
        ;;
      linux)
        export LS_COLORS="di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=37;41:sg=30;43:tw=30;42:ow=34;42:st=37;44"
        alias ls="ls --color=auto -F"
    
        PS1='\[\e[32m\]\h\[\e[0m\] \[\e[34m\]\w\[\e[0m\]\n\[\e[35m\]$(git_prompt_segment)\[\e[0m\]\[\e[1;33m\]$(git_usr_name)\[\e[0m\]\[\e[33m\]\$ \[\e[0m\]'
        ;;
      *)
        PS1='\h \w \$ '
        ;;
    esac
fi
