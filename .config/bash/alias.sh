#############################################################
# Alias
alias gow="cd ${WORKDIR}"
alias gop="cd ${PACKDIR}"
alias ll="ls -l"
alias ls='ls -G --color=auto'

# Jupyter alias
alias jl="jupyter lab"

# PBS-related alias 
command -v qstat > /dev/null 2>&1 && alias sqstat="qstat | grep sunao"
command -v qstat > /dev/null 2>&1 && alias qstatn="qstat -n"
command -v qstat > /dev/null 2>&1 && alias sqstatn="qstat -n | grep sunao"

# VScode alias
command -v code  > /dev/null 2>&1 && alias cn="code -n"
