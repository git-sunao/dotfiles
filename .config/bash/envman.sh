# ============================================================
# Conda-family setup
# Priority: Miniforge > Conda (Miniconda / system conda)
# ============================================================

export ENV_MANAGER="none"

# ---- Miniforge (highest priority) ---------------------------
if [ -n "${MINIFORGEDIR:-}" ] && [ -x "${MINIFORGEDIR}/bin/conda" ]; then
    __conda_setup="$("${MINIFORGEDIR}/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "${__conda_setup}"
    else
        if [ -f "${MINIFORGEDIR}/etc/profile.d/conda.sh" ]; then
            . "${MINIFORGEDIR}/etc/profile.d/conda.sh"
        else
            export PATH="${MINIFORGEDIR}/bin:$PATH"
        fi
    fi
    export ENV_MANAGER="miniforge"

# ---- Fallback: traditional conda ----------------------------
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
fi

# ============================================================
