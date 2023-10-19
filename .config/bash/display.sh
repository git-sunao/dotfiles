#!/bin/bash

if [[ $OSTYPE == "darwin"* ]]; then
    HOSTNAME_TEMP=$(scutil --get LocalHostName)
else
    HOSTNAME_TEMP=$(hostname)
fi

# BASH prompt
PS1="\[$PROMPT_COLOR\][$HOSTNAME_TEMP:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]"