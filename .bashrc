## Apperence
#prompto
PS1='\[\e[1;33m\][sunao:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]'

# colorized ls
export LSCOLORS=exfxcxdxbxegedabagacad
alias ls='ls -G'
alias ll='ls -l'


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

# Alias
alias jl="jupyter lab"

# scripts
export PATH="${HOME}/.scripts/scripts:${PATH}"




##################################
# Environmental dependent setups
##################################
function sunaoair (){
  # conda initialize
  # !! Contents within this block are managed by 'conda init' !!
  __conda_setup="$('/Users/sugiyamasunao/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__conda_setup"
  else
      if [ -f "/Users/sugiyamasunao/miniconda3/etc/profile.d/conda.sh" ]; then
          . "/Users/sugiyamasunao/miniconda3/etc/profile.d/conda.sh"
      else
          export PATH="/Users/sugiyamasunao/miniconda3/bin:$PATH"
      fi
  fi
  unset __conda_setup
  # Path 
  export PATH="/opt/cisco/anyconnect/bin:${PATH}"
  export LDFLAGS="-L/usr/local/opt/llvm/lib"
  export CPPFLAGS="-I/usr/local/opt/llvm/include"
  # Alias
  alias gow="cd ${HOME}/Documents/projects"
  alias clamscanall="clamscan ~/ --recursive --infected"
}

function idark () {
  echo hello
}
#
#
#
#
#
#
echo "Running on $HOSTNAME"
case "$HOSTNAME" in
  "idark"         ) idark;;
  "gw1.local"     ) gw1;;
  "fe"            ) gfarm;;
  "sunaoair.local") sunaoair;;
  *) echo "We do not support the server: $HOSTNAME";;
esac


# pyenv
## set PYENV_ROOT /usr/local/Cellar/pyenv/1.2.18/bin/pyenv $PYENV_ROOT
# export PYENV_ROOT=$HOME/.pyenv:$PYENV_ROOT
# export PATH=$PYENV_ROOT/bin:$PATH
# eval "$(pyenv init -)"

# rbenv
eval "$(rbenv init -)"

