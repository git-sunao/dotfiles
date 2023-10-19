#!/bin/bash

config_files=("$HOME/.config/bash/"*.sh)
# load the path files
for file in "${config_files[@]}"
do
  source $file
done
unset config_files
