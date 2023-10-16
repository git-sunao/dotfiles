#!/bin/bash

# Neovim
export PATH=${HOME}/.nvim/:$PATH

# My own scripts
export PATH="${HOME}/.scripts/scripts:${PATH}"

# activate fuzzy finder
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

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