###############################################
# Global setups shared among various servers
###############################################

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

# Macbook air
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
  # rbenv
  eval "$(rbenv init -)"
  # Path 
  export PATH="/opt/cisco/anyconnect/bin:${PATH}"
  export LDFLAGS="-L/usr/local/opt/llvm/lib"
  export CPPFLAGS="-I/usr/local/opt/llvm/include"
  # Alias
  alias gow="cd ${HOME}/Documents/projects"
  alias clamscanall="clamscan ~/ --recursiv"
  # Prompto
  PS1='\[\e[1;33m\][sunao:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]'
  # pyenv
  ## set PYENV_ROOT /usr/local/Cellar/pyenv/1.2.18/bin/pyenv $PYENV_ROOT
  # export PYENV_ROOT=$HOME/.pyenv:$PYENV_ROOT
  # export PATH=$PYENV_ROOT/bin:$PATH
  # eval "$(pyenv init -)"
}

# iMac provided by ipmu
function ipmuimac (){
  # conda initialize
  # !! Contents within this block are managed by 'conda init' !!
  __conda_setup="$('/Users/sunao-mac/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__conda_setup"
  else
      if [ -f "/Users/sunao-mac/miniconda3/etc/profile.d/conda.sh" ]; then
          . "/Users/sunao-mac/miniconda3/etc/profile.d/conda.sh"
      else
          export PATH="/Users/sunao-mac/miniconda3/bin:$PATH"
      fi
  fi
  unset __conda_setup
  # Prompto
  PS1='\[\e[1;33m\][sunao:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]'
  # Alias
  alias gow="cd ${HOME}/Documents/projects"
}

# idark server at ipmu
function idark () {
  # Source global bash
  [ -f /etc/bashrc ] && . /etc/bashrc
  # Script direstry
  SCRIPTDIR=/home/.common
  # Compiler: options are
  # - COMPILER=INTEL19.0
  # - COMPILER=INTEL18.0
  # - COMPILER=INTEL17.0
  # - COMPILER=INTEL15.0
  # - COMPILER=PGI17
  # - COMPILER=PGI16
  # - COMPILER=PGI15
  COMPILER=INTEL19.0
  # MPI: options are 
  # - MPI=IntelMPI
  # - MPI=OpenMPI
  # - MPI=MPICH
  # - MPI=MPICH2
  MPI=INTEL19.0
  # Run script to setup compiler and mpi
  for script in $SCRIPTDIR/$COMPILER/*.sh $SCRIPTDIR/$COMPILER/$MPI/*.sh $SCRIPTDIR/*.sh
  do
      if [ -r $script ]; then
      . $script
    fi
  done
  # Set env viriable
  export OMP_NUM_THREADS=1
  export MKL_NUM_THREADS=1
  # Alias
  alias gow="cd /lustre/work/sunao.sugiyama"
  alias sqstat="qstat | grep sunao"
  alias sqstatn="qstat -n | grep sunao"
  # neovim
  export PATH=${HOME}/.nvim/:$PATH
  # Prompto
  PS1='($CONDA_DEFAULT_ENV) \[\e[1;35m\][idark:\[\e[m\]\[\e[1;36m\]\t] \$ \[\e[m\]'
}

case "$HOSTNAME" in
  "idark"         ) idark;;
  "gw1.local"     ) gw1;;
  "fe"            ) gfarm;;
  "sunaoair.local") sunaoair;;
  "ipmuimac.local") ipmuimac;;
  *) echo "We do not support the server: $HOSTNAME";;
esac

