#!/bin/bash
# The caller loads host.sh first; this file only initializes the configured tools.

_dotfiles_init_conda() {
    local root setup
    declare -p CONDA_ROOTS >/dev/null 2>&1 || {
        printf 'envman.sh: load host.sh before initializing conda/mamba\n' >&2; return 1;
    }
    [ "${#CONDA_ROOTS[@]}" -gt 0 ] || return 0
    for root in "${CONDA_ROOTS[@]}"; do
        if [ -x "$root/bin/conda" ] || [ -x "$root/bin/mamba" ]; then
            break
        fi
        root=
    done
    [ -n "$root" ] || {
        printf 'envman.sh: no conda or mamba executable found in CONDA_ROOTS\n' >&2; return 1;
    }

    if [ -x "$root/bin/conda" ]; then
        if ! declare -F conda >/dev/null || [ "${CONDA_EXE:-}" != "$root/bin/conda" ]; then
            if setup=$("$root/bin/conda" shell.bash hook 2>/dev/null); then
                eval "$setup" || return
            elif [ -r "$root/etc/profile.d/conda.sh" ]; then
                . "$root/etc/profile.d/conda.sh" || return
            else
                case ":${PATH:-}:" in
                    *":$root/bin:"*) ;;
                    *) export PATH="$root/bin${PATH:+:$PATH}" ;;
                esac
            fi
        fi
    fi
    if [ -x "$root/bin/mamba" ]; then
        if ! declare -F mamba >/dev/null || [ "${MAMBA_EXE:-}" != "$root/bin/mamba" ] ||
            [ "${MAMBA_ROOT_PREFIX:-}" != "$root" ]; then
            export MAMBA_EXE="$root/bin/mamba" MAMBA_ROOT_PREFIX="$root"
            if setup=$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$root" 2>/dev/null); then
                eval "$setup" || return
            elif [ -r "$root/etc/profile.d/mamba.sh" ]; then
                # Older mamba uses a profile script instead of the shell subcommand.
                . "$root/etc/profile.d/mamba.sh" || return
            else
                printf 'envman.sh: mamba shell initialization failed: %s\n' "$MAMBA_EXE" >&2
                printf 'envman.sh: shell hook failed and %s/etc/profile.d/mamba.sh is unavailable\n' "$root" >&2
                return 1
            fi
        fi
    fi

    # Keep the existing startup library setting pending project-level migration.
    # This does not remove an old library path when switching conda environments.
    if [ -n "${CONDA_PREFIX:-}" ] && [ -d "$CONDA_PREFIX/lib" ]; then
        case ":${LD_LIBRARY_PATH:-}:" in
            *":$CONDA_PREFIX/lib:"*) ;;
            *) export LD_LIBRARY_PATH="$CONDA_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
        esac
    fi
}

if _dotfiles_init_conda; then
    unset -f _dotfiles_init_conda
else
    unset -f _dotfiles_init_conda
    return 1
fi
