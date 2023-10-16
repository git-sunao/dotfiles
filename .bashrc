#!/bin/bash

#############################################################
# Settings for each host

# Get HOSTNAME
if [[ $OSTYPE == "darwin"* ]]; then
    HOSTNAME_TEMP=$(scutil --get LocalHostName)
else
    HOSTNAME_TEMP=$(hostname)
fi
# Setup for each host
if [ "$HOSTNAME_TEMP" = "sunaomac" ]; then
    # Local computer macbook air
    export WORKDIR="${HOME}/documents/projects"
    export PACKDIR="${HOME}/documents/packages"
    export CONDDIR="${HOME}/miniconda3"
    PROMPT_COLOR="\e[1;33m"
    eval "$(rbenv init -)"
    export PATH="/opt/cisco/anyconnect/bin:${PATH}"
    export LDFLAGS="-L/usr/local/opt/llvm/lib"
    export CPPFLAGS="-I/usr/local/opt/llvm/include"
elif [ "$HOSTNAME_TEMP" = "idark" ] || [[ "$HOSTNAME_TEMP" == *ansys* ]]; then
    # IPMU cluster idark
    [ -f /etc/bashrc ] && . /etc/bashrc
    export WORKDIR="/lustre/work/sunao.sugiyama/"
    export PACKDIR="/lustre/work/sunao.sugiyama/package"
    export CONDDIR="/home/anaconda3"
    PROMPT_COLOR="\e[1;35m"
elif [ "$HOSTNAME_TEMP" = "gw1.local" ] || [[ "$HOSTNAME_TEMP" == *hpcs* ]]; then
    # IPMU cluster gw
    [ -f /etc/bashrc ] && . /etc/bashrc
    export WORKDIR="/work/sunao.sugiyama/"
    export PACKDIR="/work/sunao.sugiyama/package"
    export CONDDIR="/home/anaconda3"
    PROMPT_COLOR="\e[0;32m"
elif [ "$HOSTNAME_TEMP" = "fe" ] || [[ "$HOSTNAME_TEMP" == *ansys* ]]; then
    # IPMU cluster gfarm
    [ -f /etc/bashrc ] && . /etc/bashrc
    export WORKDIR="/gpfs02/work/sunao.sugiyama/"
    export PACKDIR="/gpfs02/work/sunao.sugiyama/package"
    export CONDDIR="/home/anaconda3"
    PROMPT_COLOR="\e[0;31m"
elif [[ "$HOSTNAME" == "login*" ]]; then
    # NERSC cluster
    export WORKDIR=${PSCRATCH}
    export PACKDIR=${PSCRATCH}/package
    export CONDDIR=${PSCRATCH}/miniconda3
else
    # Default settings
    echo "No settings for $HOSTNAME_TEMP"
fi
PS1="\[$PROMPT_COLOR\][$HOSTNAME_TEMP:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]"

#############################################################
# Common settings

# Neovim
export PATH=${HOME}/.nvim/:$PATH

# colorized ls
if [[ "$OSTYPE" == "darwin"* ]]; then
    export LSCOLORS=exfxcxdxbxegedabagacad
else
    export LS_COLORS="di=34:ln=36:so=32:pi=33:ex=31:bd=34;46:cd=37;44:*.mp3=35"
fi

# Ignore duplicate commands in the history
export HISTCONTROL=ignoreboth

# activate fuzzy finder
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# auto complete, ignoring large/small characters (for macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -r "/usr/local/etc/profile.d/bash_completion.sh" ]; then
        . "/usr/local/etc/profile.d/bash_completion.sh"
    fi
fi

# Conda setup
__conda_setup="$(${CONDDIR}/bin/conda 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "${CONDDIR}/etc/profile.d/conda.sh" ]; then
        . "${CONDDIR}/etc/profile.d/conda.sh"
    else
        export PATH="${CONDDIR}/bin:$PATH"
    fi
fi

# My own scripts
export PATH="${HOME}/.scripts/scripts:${PATH}"

#############################################################
# Alias
alias gow="cd ${WORKDIR}"
alias gop="cd ${PACKDIR}"
alias ls='ls -G --color=auto'

# Jupyter alias
alias jl="jupyter lab"

# PBS-related alias 
command -v qstat > /dev/null 2>&1 && alias mypbsqstat="qstat"
command -v qsub  > /dev/null 2>&1 && alias mypbsqsub="qsub"

# VScode alias
command -v code  > /dev/null 2>&1 && alias cn="code -n"
