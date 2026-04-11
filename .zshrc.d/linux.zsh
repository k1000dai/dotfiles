export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=37;41:sg=30;43:tw=30;42:ow=34;42:st=37;44'
alias ls='ls --color=auto -F'

PS1='
%F{green}%m%f %F{blue}%~%f
%F{magenta}$(git_prompt_segment)%f%F{11}$(git_usr_name)%f%F{yellow}> %f'
