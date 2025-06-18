When you want to make a new environment yml file based on (an)other yaml file(s), 
1. make a yml file in which you add all the dependencies that are not in the parent yml files,
2. use `conda-merge` command, which merges multiple yaml files into one: `conda-merge f1.yml f2.yml > fnew.yml`,
3. modify the environment name in the new yml file,
4. and finally create the environment with the conda command: `mamba env create -f fnew.yml`, 

If you want to add the environment to the ipykernels on jupyter, you can run
```bash
python -m ipykernel install --user --name=mm
```
Note that you need to install `ipykernel` package on the environment and activate the environment prior to run this command

If you have a setup script for environment variables etc for a particular conda environment, make directory for that and place them to the directory. After that, activate the conda environment and run 
```bash
. place_scripts.sh [your-script-directory]
```
