setopt correct
setopt print_eight_bit
autoload -U compinit 
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
autoload -Uz vcs_info
zstyle ':vcs_info:*' actionformats '[%b|%a]'

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# default editor
export EDITOR=nvim

alias clang++="clang++ -std=c++17 -Wall -Wextra -Wconversion"
alias clang="clang -std=c99 -Wall -Wextra"
alias ls='ls -GF'
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
#activate virtualenv in uv 
alias venv="source .venv/bin/activate"
alias lg="lazygit"
alias gg="ghq get"

# yazi
alias finder="yazi"

#gitのユーザー名を変更する
function gitmain() {
   git config --global user.name "k1000dai"
   git config --global user.email "chiyodakku1000@gmail.com"
}

function gitmain_local() {
    git config --local user.name "k1000dai"
    git config --local user.email "chiyodakku1000@gmail.com"
}

#default git setting 
git config --global user.name "k1000dai"
git config --global user.email "chiyodakku1000@gmail.com"
git config --global ghq.root '~/src'

# gitのユーザー名を出力する
git_usr_name () {
	local repo_info git_usr_name
	repo_info="$(git rev-parse --git-dir --is-inside-git-dir \
		--is-bare-repository --is-inside-work-tree \
		--short HEAD 2>/dev/null)"
	git_usr_name=`git config user.name`

	if [ -n "$repo_info" ]; then
		# gitディレクトリが存在する時
		echo "[$git_usr_name]"
	fi
}

#precmd () { vcs_info }
#PROMPT="%n@%m %~ $vcs_info_msg_0_%% "

# zoxide
eval "$(zoxide init zsh)"
alias cd="z"

# Git
source ~/.zsh/git-prompt.sh
fpath=(~/.zsh $fpath)
zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash
autoload -Uz compinit && compinit -u
GIT_PS1_SHOWDIRTYSTATE=true
setopt PROMPT_SUBST
PS1='
K.S %~
%F{red}$(__git_ps1 "(%s) ")%f%F{11}$(git_usr_name)%f%F{cyan}> %f'

fpath=(~/.zsh/completion $fpath)

#docker
fpath=(~/.zsh/completion $fpath)
# dockerコマンドの補完の制御処理
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes
# 保管機能を有効にして、実行する
autoload -Uz compinit && compinit


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
#env
. "$HOME/.local/bin/env"
. "$HOME/.env"
eval "$(pixi completion --shell zsh)"
eval "$(uv generate-shell-completion zsh)"
source ~/.zsh/completion/uv
export PATH="/Users/kohei/.pixi/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export PATH="/usr/local/smlnj/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export XDG_CONFIG_HOME=${HOME}/.config
export STM32CubeMX_PATH=/Users/kohei/Applications/Applications.app/Contents/Resources
export CPLUS_INCLUDE_PATH=/opt/homebrew/include:$CPLUS_INCLUDE_PATH
export CPPYGEN_LIBCLANG_PATH=/opt/homebrew/opt/llvm/lib/libclang.dylib
export CC=/opt/homebrew/opt/llvm/bin/clang
export CXX=/opt/homebrew/opt/llvm/bin/clang++

