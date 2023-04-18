## Apperence
#prompto
PS1='\[\e[1;33m\]sunao:\[\e[m\]\[\e[1;36m\]\t \W \$ \[\e[m\]'

# colorized ls
export LSCOLORS=exfxcxdxbxegedabagacad
alias ls='ls -G'
alias ll='ls -l'

## History
#Share bash history between sessions
# function share_history {
#     history -a
#     history -c
#     history -r
# }
# PROMPT_COMMAND='share_history'
# shopt -u histappend
# shopt -s histverify
# export HISTSIZE=2000

# bash command history is saved, but identical ones are ignored
#HISTIGNORE=
#HISTCONTROL=ignorespace:ignoredups



## Utility
# activate fuzzy finder
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# auto complete, ignoring large/small characters
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

# cntr+w up to previous slash
#stty werase undef
#bind '"\C-w": unix-filename-rubout'



## Alias
alias gow="cd ${HOME}/Documents/projects"
alias cn="code -n $argv"
alias jl="jupyter lab"
alias clamscanall="clamscan ~/ --recursive --infected"



## Environments
# pyenv
## set PYENV_ROOT /usr/local/Cellar/pyenv/1.2.18/bin/pyenv $PYENV_ROOT
export PYENV_ROOT=$HOME/.pyenv:$PYENV_ROOT
export PATH=$PYENV_ROOT/bin:$PATH
eval "$(pyenv init -)"

# conda initialize
## !! Contents within this block are managed by 'conda init' !!
eval "$(${HOME}/.pyenv/versions/anaconda3-5.3.1/bin/conda shell.bash hook)"

# rbenv
eval "$(rbenv init -)"



## Path
export PATH="/opt/cisco/anyconnect/bin:${PATH}"
export PATH="${HOME}/.scripts/scripts:${PATH}"

export LDFLAGS="-L/usr/local/opt/llvm/lib"
export CPPFLAGS="-I/usr/local/opt/llvm/include"




## PATH to Packages
PKGPATH=${HOME}/Documents/packages
## pythonpath
#export PYTHONPATH=$PKGPATH:$PYTHONPATH
#export PYTHONPATH=$PKGPATH/HSCWLsimulations/dark_emulator:$PYTHONPATH
#export PYTHONPATH=$PKGPATH/pyhalofit:$PYTHONPATH
#export PYTHONPATH=$PKGPATH/CLASS-PT:$PYTHONPATH
#export PYTHONPATH=$PKGPATH/FAST-PT:$PYTHONPATH
#export PYTHONPATH=$PKGPATH/dark_emulator_public/:$PYTHONPATH
#export PYTHONPATH=$PKGPATH/CAMB-1.0.2:$PYTHONPATH
#export PYTHONPATH=$PKGPATH/colossus:$PYTHONPATH
#export PYTHONPATH=${PKGPATH}/tkhtmlview:$PYTHONPATH
export PYTHONPATH=${PKGPATH}/PyMultiNest:$PYTHONPATH
export PYTHONPATH=${PKGPATH}/tk_html_widgets:$PYTHONPATH
## others
#export /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include:$CPATH
#export $(xcrun --sdk macosx --show-sdk-path):$SDKROOT
