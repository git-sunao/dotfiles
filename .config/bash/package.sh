#!/bin/bash

# get path to here
here=$(dirname "$(readlink -f ${BASH_SOURCE[0]})")

# My own scripts
export PATH="${here}/../../scripts:${PATH}"

# activate fuzzy finder
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# rbenv
command -v rbenv > /dev/null 2>&1 && eval "$(rbenv init -)"

