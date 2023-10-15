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
    export WORKDIR="${HOME}/documents/projects"
    export PACKDIR="${HOME}/documents/packages"
    export CONDDIR="${HOME}/miniconda3"
    eval "$(rbenv init -)"
    export PATH="/opt/cisco/anyconnect/bin:${PATH}"
    export LDFLAGS="-L/usr/local/opt/llvm/lib"
    export CPPFLAGS="-I/usr/local/opt/llvm/include"
    alias clamscanall="clamscan ~/ --recursiv"
    alias cn="code -n"
elif [ "$HOSTNAME_TEMP" = "idark"]; then
    export WORKDIR="/lustre/work/sunao.sugiyama/"
    export PACKDIR="/lustre/work/sunao.sugiyama/package"
    export CONDDIR="/home/anaconda3"
    #export PATH=${HOME}/.nvim/:$PATH
    alias sqstat="qstat | grep sunao"
    alias sqstatn="qstat -n | grep sunao"
else
    # Default settings
    echo "No settings for $HOSTNAME_TEMP"
fi
PS1="\[\e[1;33m\][$HOSTNAME_TEMP:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]"
unset HOSTNAME_TEMP

#############################################################
# Common settings

# colorized ls (for macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Set LSCOLORS for macOS
    export LSCOLORS=exfxcxdxbxegedabagacad
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

# Alias
alias jl="jupyter lab"
alias gow="cd ${WORKDIR}"
alias gop="cd ${PACKDIR}"
alias ls='ls -G'
