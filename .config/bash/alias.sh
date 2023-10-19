#############################################################
# Alias
alias gow="cd ${WORKDIR}"
alias gop="cd ${PACKDIR}"
alias ll="ls -l"
alias ls='ls -G --color=auto'

# Jupyter alias
alias jl="jupyter lab"

# PBS-related alias 
command -v qstat > /dev/null 2>&1 && alias mypbsqstat="qstat"
command -v qsub  > /dev/null 2>&1 && alias mypbsqsub="qsub"

# VScode alias
command -v code  > /dev/null 2>&1 && alias cn="code -n"
