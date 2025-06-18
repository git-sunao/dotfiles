dept=$1
mkdir -p $CONDA_PREFIX/etc/conda/activate.d
mkdir -p $CONDA_PREFIX/etc/conda/deactivate.d
echo "Placing the scripts from $dept to $CONDA_PREFIX"
cp $dept/env_vars.sh $CONDA_PREFIX/etc/conda/activate.d/
cp $dept/env_vars_unset.sh $CONDA_PREFIX/etc/conda/deactivate.d/

