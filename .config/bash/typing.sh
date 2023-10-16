#!/bin/bash

# colorized ls
if [[ "$OSTYPE" == "darwin"* ]]; then
    export LSCOLORS=exfxcxdxbxegedabagacad
else
    export LS_COLORS="di=34:ln=36:so=32:pi=33:ex=31:bd=34;46:cd=37;44:*.mp3=35"
fi

# Ignore duplicate commands in the history
export HISTCONTROL=ignoreboth

# auto complete, ignoring large/small characters (for macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -r "/usr/local/etc/profile.d/bash_completion.sh" ]; then
        . "/usr/local/etc/profile.d/bash_completion.sh"
    fi
fi
