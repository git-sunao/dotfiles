#!/bin/sh
# This init script is written by Sunao Sugiyama
# and based on script /opt/local/hscPipe8/loadLSST.bash on idark


export PROJDIR=${WORKDIR}/HSCM31microlensingImaging
alias gop="cd ${PROJDIR}"
alias goa="cd ${PROJDIR}/analysis"

# update PYTHONPATH
export CONDA_PYTHONPATH_BACKUP=${PYTHONPATH}
export CONDA_PATH_BACKUP=${PATH}
export PYTHONPATH=${PROJDIR}/analysis/python:${PYTHONPATH}
export PATH=${PROJDIR}/analysis/python:${PATH}

# Bootstrap EUPS
LSST_HOME=/opt/local/hscPipe8
EUPS_DIR="${LSST_HOME}/eups/2.1.5"
source "${EUPS_DIR}/bin/setups.sh"
export -f setup
export -f unsetup

setup hscPipe 8.5.3
