#!/bin/bash

# get path to here
here=$(dirname "$(readlink -f ${BASH_SOURCE[0]})")

# My own scripts
export PATH="${here}/../../scripts:${PATH}"

# activate fuzzy finder
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Conda setup
if [ -n "$CONDDIR" ]; then
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
fi

# rbenv
command -v rbenv > /dev/null 2>&1 && eval "$(rbenv init -)"

