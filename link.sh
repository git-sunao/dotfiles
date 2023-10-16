# Run commands
unlink ${HOME}/.bashrc
ln -s ${HOME}/dotfiles/rc/.bashrc ${HOME}/.bashrc
unlink ${HOME}/.latexmkrc
ln -s ${HOME}/dotfiles/rc/.latexmkrc ${HOME}/.latexmkrc
unlink ${HOME}/.gitignore_global
ln -s ${HOME}/dotfiles/rc/.gitignore_global ${HOME}/.gitignore_global
unlink ${HOME}/.inputrc
ln -s ${HOME}/dotfiles/rc/.inputrc ${HOME}/.inputrc
# config
unlink ${HOME}/.config
ln -s ${HOME}/dotfiles/.config ${HOME}/.config