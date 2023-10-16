#!/bin/bash

# load the path files
for file in envs.sh package.sh typing.sh alias.sh editor.sh;
do
  source $HOME/.config/bash/$file
done
unset config_files
