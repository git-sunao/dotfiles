#!/bin/bash

# Setup environment variables for each host.

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
elif [[ "$HOSTNAME_TEMP" == "login*" ]]; then
    # NERSC cluster
    export WORKDIR=${PSCRATCH}
    export PACKDIR=${PSCRATCH}/package
    export CONDDIR=${PSCRATCH}/miniconda3
    PROMPT_COLOR="\e[0;31m"
else
    # Default settings
    echo "No settings for $HOSTNAME_TEMP"
fi
PS1="\[$PROMPT_COLOR\][$HOSTNAME_TEMP:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]"