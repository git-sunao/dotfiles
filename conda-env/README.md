When you want to make a new environment yml file based on (an)other yaml file(s), 
1. make a yml file in which you add all the dependencies that are not in the parent yml files,
2. use `conda-merge` command, which merges multiple yaml files into one: `conda-merge f1.yml f2.yml > fnew.yml`,
3. modify the environment name in the new yml file,
4. and finally create the environment with the conda command: `conda env create -f fnew.yml`
