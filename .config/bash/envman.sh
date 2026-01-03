# ============================================================
# Env manager setup (priority: micromamba > conda)
# You can set these per-server:
#   export MICROMAMBA_BIN=".../micromamba"
#   export MAMBA_ROOT_PREFIX=".../micromamba-root"
#   export CONDDIR=".../miniconda3"
# ============================================================

# ---- micromamba setup (highest priority) --------------------
if [ -n "${MICROMAMBA_BIN:-}" ] && [ -x "${MICROMAMBA_BIN}" ]; then
    # micromamba 
    export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/micromamba}"

    # shell hook
    __mamba_setup="$("${MICROMAMBA_BIN}" shell hook --shell bash 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "${__mamba_setup}"
        export ENV_MANAGER="micromamba"
    else
        # if hook fails, just set PATH (activate will not work but command can)
        export PATH="$(dirname "${MICROMAMBA_BIN}"):$PATH"
        export ENV_MANAGER="micromamba-nonhook"
    fi

# ---- conda setup (fallback) ---------------------------------
elif [ -n "${CONDDIR:-}" ] && [ -x "${CONDDIR}/bin/conda" ]; then
    __conda_setup="$("${CONDDIR}/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "${__conda_setup}"
    else
        if [ -f "${CONDDIR}/etc/profile.d/conda.sh" ]; then
            . "${CONDDIR}/etc/profile.d/conda.sh"
        else
            export PATH="${CONDDIR}/bin:$PATH"
        fi
    fi
    export ENV_MANAGER="conda"

else
    export ENV_MANAGER="none"
fi

