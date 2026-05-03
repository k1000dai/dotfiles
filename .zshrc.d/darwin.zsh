export LSCOLORS='exfxcxdxbxegedabagacad'
alias ls='ls -G -F'

source_if_exists "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

prepend_path "/opt/homebrew/bin"
#prepend_path "/opt/homebrew/opt/llvm/bin"

export STM32CubeMX_PATH="$HOME/Applications/Applications.app/Contents/Resources"

if [[ -d /opt/homebrew/include ]]; then
  export CPLUS_INCLUDE_PATH="/opt/homebrew/include${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
fi


PS1='
K.S %~
%F{red}$(git_prompt_segment)%f%F{11}$(git_usr_name)%f%F{cyan}> %f'
