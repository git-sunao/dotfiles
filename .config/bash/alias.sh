#############################################################
# Alias
alias gow="cd ${WORKDIR}"
alias gop="cd ${PACKDIR}"
alias ll="ls -l"
alias ls='ls -G --color=auto'

# Jupyter alias
alias jl="jupyter lab"
alias jlp="jupyter lab --ip=localhost --no-browser --port"
alias jlab='"$(conda info --base)"/bin/jupyter-lab --no-browser --port'
alias gitslf='git status --porcelain | grep ^[AM] | sed -e "s,^\S ,,g" | xargs -r ls -hsS'

# PBS-related alias 
command -v qstat > /dev/null 2>&1 && alias sqstat="qstat | grep sunao"
command -v qstat > /dev/null 2>&1 && alias qstatn="qstat -n"
command -v qstat > /dev/null 2>&1 && alias sqstatn="qstat -n | grep sunao"

# VScode alias
command -v code  > /dev/null 2>&1 && alias cn="code -n"

# ssh alias for alacritty
if [ "$TERM" == "alacritty" ]; then
  alias ssh='TERM=xterm-256color ssh'
fi

# Local work directory alias
alias gol="cd ${LOCAL_WORKDIR}"
alias gob="cd ${LOCAL_BIGDATA}"
