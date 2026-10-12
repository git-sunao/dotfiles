#!/bin/bash

if [[ $OSTYPE == "darwin"* ]] && command -v scutil >/dev/null 2>&1; then
    HOSTNAME_TEMP=$(scutil --get LocalHostName 2>/dev/null) || HOSTNAME_TEMP=$(hostname)
else
    HOSTNAME_TEMP=$(hostname)
fi

# BASH prompt
# Keep the active environment prefix when rebuilding the prompt after tool setup.
PS1="${CONDA_PROMPT_MODIFIER:-}\[${PROMPT_COLOR:-}\][$HOSTNAME_TEMP:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]"
unset HOSTNAME_TEMP
