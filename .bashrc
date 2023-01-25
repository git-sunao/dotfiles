[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# prompto
PS1='\[\e[1;33m\]sunao:\[\e[m\]\[\e[1;36m\]\t \w \$ \[\e[m\]'

# bash command history is saved, but identical ones are ignored
HISTCONTROL=erasedups

# auto complete, ignoring large/small characters
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

# cntr+w up to previous slash
#stty werase undef
#bind '"\C-w": unix-filename-rubout'

# alias
alias gow="cd ${HOME}/Documents/projects"
alias cn="code -n $argv"
alias jl="jupyter lab"
alias bundlejkl="bundle exec jekyll serve --trace"
alias clamscanall="clamscan ~/ --recursive --infected"

# colorized ls
export LSCOLORS=exfxcxdxbxegedabagacad
alias ls='ls -G'
alias ll='ls -l'

# pyenv
## set PYENV_ROOT /usr/local/Cellar/pyenv/1.2.18/bin/pyenv $PYENV_ROOT
export PYENV_ROOT=$HOME/.pyenv:$PYENV_ROOT
export PATH=$PYENV_ROOT/bin:$PATH
eval "$(pyenv init -)"

# conda initialize
## !! Contents within this block are managed by 'conda init' !!
eval "$(${HOME}/.pyenv/versions/anaconda3-5.3.1/bin/conda shell.bash hook)"

# path
export PATH="/opt/cisco/anyconnect/bin:${PATH}"
export PATH="${HOME}/.cmds:${PATH}"

export LDFLAGS="-L/usr/local/opt/llvm/lib"
export CPPFLAGS="-I/usr/local/opt/llvm/include"

# Share bash history between sessions
function share_history {
    history -a
    history -c
    history -r
}

PROMPT_COMMAND='share_history'
shopt -u histappend
export HISTSIZE=2000

# 
export PATH="$HOME/.rbenv/bin:$PATH"
if which rbenv > /dev/null; then 
	eval "$(rbenv init -)"; 
fi

# python packages
PKGPATH=${HOME}/Documents/python_package
#export $HOME/Documents/python_package/HSCWLsimulations/dark_emulator:$PYTHONPATH
#export $HOME/Documents/python_package/pyhalofit:$PYTHONPATH
#export $HOME/Documents/python_package/CLASS-PT:$PYTHONPATH
#export $HOME/Documents/python_package/FAST-PT:$PYTHONPATH
#export $HOME/Documents/python_package:$PYTHONPATH
#export $HOME/Documents/python_package/dark_emulator_public/:$PYTHONPATH
#export $HOME/Documents/python_package/CAMB-1.0.2:$PYTHONPATH
#export $HOME/Documents/python_package/colossus:$PYTHONPATH
# needed for PolyChord compilation
#export /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include:$CPATH
#export $(xcrun --sdk macosx --show-sdk-path):$SDKROOT
export PYTHONPATH=${PKGPATH}/PyMultiNest:$PYTHONPATH
#export PYTHONPATH=${PKGPATH}/tkhtmlview:$PYTHONPATH
export PYTHONPATH=${PKGPATH}/tk_html_widgets:$PYTHONPATH
