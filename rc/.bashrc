#!/bin/bash

. "$HOME/.config/bash/host.sh" || return

# Resolve the repository through the installed config directory, including symlinks.
_dotfiles_scripts=$(cd -P -- "$HOME/.config/bash/../.." && pwd)/scripts || return
if [ -d "$_dotfiles_scripts" ]; then
    case ":${PATH:-}:" in
        *":$_dotfiles_scripts:"*) ;;
        *) export PATH="$_dotfiles_scripts${PATH:+:$PATH}" ;;
    esac
fi
unset _dotfiles_scripts

# SSH commands may read .bashrc, but must not initialize interactive tools.
case $- in
    *i*) ;;
    *) return 0 ;;
esac

# Dependencies first, followed by interactive preferences.
for _dotfiles_config in envman package alias display typing; do
    . "$HOME/.config/bash/$_dotfiles_config.sh" || return
done
unset _dotfiles_config

if [ -r "$HOME/.config/bash/interactive.local.sh" ]; then
    . "$HOME/.config/bash/interactive.local.sh"
fi
return 0
