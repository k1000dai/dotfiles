setopt correct
setopt print_eight_bit
setopt prompt_subst

autoload -Uz compinit vcs_info
typeset -U path PATH fpath

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':vcs_info:*' actionformats '[%b|%a]'

source_if_exists() {
  local file_path="$1"
  [[ -r "$file_path" ]] && source "$file_path"
}

prepend_path() {
  local dir_path="$1"
  [[ -d "$dir_path" ]] || return 0
  path=("$dir_path" $path)
}

git_prompt_segment() {
  (( $+functions[__git_ps1] )) || return 0
  __git_ps1 "(%s) "
}

case "$(uname -s)" in
  Darwin)
    ZSH_PLATFORM="darwin"
    ;;
  Linux)
    ZSH_PLATFORM="linux"
    ;;
  *)
    ZSH_PLATFORM="unknown"
    ;;
esac

export ZSH_PLATFORM

# default editor
export EDITOR=nvim

alias clang++="clang++ -std=c++17 -Wall -Wextra -Wconversion"
alias clang="clang -std=c99 -Wall -Wextra"
alias la='ls -a'
alias ll='ls -l'
alias ...='cd ../..'
alias nv='nvim'
alias vim='nvim'
alias l="ls"
alias ga="git add"
alias reboot_shell="exec $SHELL -l"
alias reload="source ~/.zshrc"
alias ga="git add"
alias gb="git branch"
alias gc="git commit -m"
alias gs="git swtich"
alias gp="git push"
alias venv="source .venv/bin/activate"
alias lg="lazygit"
alias gg="ghq get"

# yazi
alias finder="yazi"

# gitのユーザー名を変更する
function gitmain() {
   git config --global user.name "k1000dai"
   git config --global user.email "chiyodakku1000@gmail.com"
}

function gitmain_local() {
    git config --local user.name "k1000dai"
    git config --local user.email "chiyodakku1000@gmail.com"
}

# default git setting
git config --global user.name "k1000dai"
git config --global user.email "chiyodakku1000@gmail.com"
git config --global ghq.root '~/src'

# gitのユーザー名を出力する
git_usr_name () {
  local repo_info git_usr_name
  repo_info="$(git rev-parse --git-dir --is-inside-git-dir \
    --is-bare-repository --is-inside-work-tree \
    --short HEAD 2>/dev/null)"
  git_usr_name="$(git config user.name)"

  if [ -n "$repo_info" ]; then
    echo "[$git_usr_name]"
  fi
}

# zoxide
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

# Git
source_if_exists "$HOME/.zsh/git-prompt.sh"
fpath=("$HOME/.zsh" "$HOME/.zsh/completion" $fpath)
zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash
GIT_PS1_SHOWDIRTYSTATE=true
compinit -u

# docker
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

function ghq-fzf() {
  local src repo_root repo_dir
  repo_root="$(ghq root)" || return 1

  src="$(ghq list | fzf --preview "bat --color=always --style=header,grid --line-range :80 ${repo_root}/{}/README.* 2>/dev/null")" || return 0
  [[ -z "$src" ]] && return 0
  BUFFER="cd $(printf %q "${repo_root}/${src}")"
  zle accept-line
}

zle -N ghq-fzf
bindkey '^g' ghq-fzf

# env
source_if_exists "$HOME/.local/bin/env"
source_if_exists "$HOME/.env"

if (( $+commands[pixi] )); then
  eval "$(pixi completion --shell zsh)"
fi

if (( $+commands[uv] )); then
  eval "$(uv generate-shell-completion zsh)"
fi

source_if_exists "$HOME/.zsh/completion/uv"

prepend_path "$HOME/.pixi/bin"
prepend_path "$HOME/.local/bin"
prepend_path "/usr/local/smlnj/bin"

export XDG_CONFIG_HOME="${HOME}/.config"
PS1='%m %~ %# '

source_if_exists "$HOME/.zshrc.d/${ZSH_PLATFORM}.zsh"
