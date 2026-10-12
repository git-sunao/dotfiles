#!/bin/bash

# Script PATH is set by .bashrc, including in non-interactive shells.

# activate fuzzy finder
if [ -z "${_dotfiles_fzf_loaded:-}" ] && [ -r "$HOME/.fzf.bash" ]; then
    . "$HOME/.fzf.bash"
    _dotfiles_fzf_loaded=1
fi

# rbenv
if command -v rbenv >/dev/null 2>&1 && ! declare -F rbenv >/dev/null; then
    eval "$(rbenv init -)"
fi

# NVM may be installed directly or via Homebrew; neither is required.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if ! declare -F nvm >/dev/null; then
    _dotfiles_nvm_root=$NVM_DIR
    if [ ! -s "$_dotfiles_nvm_root/nvm.sh" ] && command -v brew >/dev/null 2>&1; then
        _dotfiles_nvm_root=$(brew --prefix nvm 2>/dev/null) || _dotfiles_nvm_root=
    fi
    if [ -n "$_dotfiles_nvm_root" ] && [ -s "$_dotfiles_nvm_root/nvm.sh" ]; then
        . "$_dotfiles_nvm_root/nvm.sh"
        if [ -r "$_dotfiles_nvm_root/bash_completion" ]; then
            . "$_dotfiles_nvm_root/bash_completion"
        elif [ -r "$_dotfiles_nvm_root/etc/bash_completion.d/nvm" ]; then
            . "$_dotfiles_nvm_root/etc/bash_completion.d/nvm"
        fi
    fi
    unset _dotfiles_nvm_root
fi
return 0
