#!/bin/bash
set -e
source_dir=${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../config/bash" && pwd)}
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-host-test.XXXXXX")
test_root=$(cd -P -- "$test_root" && pwd)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/config" "$test_root/private settings" "$test_root/primary/bin" "$test_root/primary/lib" "$test_root/secondary/bin"
cp "$source_dir/envman.sh" "$source_dir/display.sh" "$test_root/config/"
config_dir="$test_root/config"
cat > "$test_root/private settings/test.sh" <<'HOST'
export WORK_HOST=test
export WORKDIR="$TEST_ROOT/work with spaces"
export PACKDIR="$HOME/packages"
export LOCAL_WORKDIR= LOCAL_BIGDATA=
export PROMPT_COLOR='\e[1;33m'
CONDA_ROOTS=("$TEST_ROOT/missing" "$TEST_ROOT/primary" "$TEST_ROOT/secondary")
HOST
ln -s "$test_root/private settings/test.sh" "$config_dir/host.sh"
run() {
    /usr/bin/env -i HOME="$HOME" PATH=/usr/bin:/bin TEST_ROOT="$test_root" CONFIG_DIR="$config_dir" /bin/bash --noprofile --norc -ec "$1"
}
run '
    export WORK_HOST=other HOSTNAME=hpcs000 PBS_O_HOST=other
    export LOCAL_WORKDIR=/old LOCAL_BIGDATA=/old
    set -- other
    . "$CONFIG_DIR/host.sh"
    [ "$WORK_HOST" = test ]
    [ "$WORKDIR" = "$TEST_ROOT/work with spaces" ]
    [ "$PACKDIR" = "$HOME/packages" ]
    [ -z "$LOCAL_WORKDIR$LOCAL_BIGDATA" ]
    [ "$PROMPT_COLOR" = "\e[1;33m" ]
    [ "${#CONDA_ROOTS[@]}" -eq 3 ]
    [ "${CONDA_ROOTS[1]}" = "$TEST_ROOT/primary" ]
'
printf 'PASS: linked private settings, spaces, array, and inherited values\n'
run '
    . "$CONFIG_DIR/host.sh"
    export CONDA_PROMPT_MODIFIER="(base) "
    . "$CONFIG_DIR/display.sh"
    case "$PS1" in "(base) "*) ;; *) exit 1 ;; esac
    previous=$PS1
    . "$CONFIG_DIR/display.sh"
    [ "$PS1" = "$previous" ]
    export CONDA_PROMPT_MODIFIER="(project) "
    . "$CONFIG_DIR/display.sh"
    case "$PS1" in "(project) "*) ;; *) exit 1 ;; esac
    unset CONDA_PROMPT_MODIFIER
    . "$CONFIG_DIR/display.sh"
    [ "$PS1" = "${previous#"(base) "}" ]
'
printf 'PASS: prompt preserves the active environment without duplicating or inventing it\n'
cat > "$test_root/primary/bin/conda" <<'MOCK'
#!/bin/bash
printf 'conda\n' >> "$TEST_ROOT/conda.calls"
[ "${FAIL_CONDA:-}" != 1 ] || exit 1
printf 'conda() { :; }\n'
printf 'export CONDA_EXE=%q\n' "$0"
MOCK
cat > "$test_root/primary/bin/mamba" <<'MOCK'
#!/bin/bash
printf 'mamba\n' >> "$TEST_ROOT/mamba.calls"
[ "$1 $2 $3 $4 $5 $6" = "shell hook --shell bash --root-prefix $TEST_ROOT/primary" ] || exit 1
[ "${FAIL_MAMBA:-}" != 1 ] || exit 1
printf 'mamba() { :; }\n'
MOCK
cat > "$test_root/secondary/bin/conda" <<'MOCK'
#!/bin/bash
printf 'wrong installation selected\n' >&2
exit 1
MOCK
chmod +x "$test_root/primary/bin/conda" "$test_root/primary/bin/mamba" "$test_root/secondary/bin/conda"
run '
    . "$CONFIG_DIR/host.sh"
    export CONDA_PREFIX="$TEST_ROOT/primary"
    . "$CONFIG_DIR/envman.sh"
    . "$CONFIG_DIR/envman.sh"
    [ "$(wc -l < "$TEST_ROOT/conda.calls")" -eq 1 ]
    [ "$(wc -l < "$TEST_ROOT/mamba.calls")" -eq 1 ]
    [ "$MAMBA_EXE" = "$TEST_ROOT/primary/bin/mamba" ]
    [ "$MAMBA_ROOT_PREFIX" = "$TEST_ROOT/primary" ]
    [ "$LD_LIBRARY_PATH" = "$CONDA_PREFIX/lib" ]
    ! declare -F _dotfiles_init_conda >/dev/null
'
printf 'PASS: first installed root, both hooks once, consistent mamba paths, library path\n'
run '
    . "$CONFIG_DIR/host.sh"
    CONDA_ROOTS=()
    . "$CONFIG_DIR/envman.sh"
    ! declare -F conda >/dev/null
    ! declare -F mamba >/dev/null
    [ -z "${LD_LIBRARY_PATH+x}" ]
'
printf 'PASS: empty roots skip initialization\n'
run '
    . "$CONFIG_DIR/host.sh"
    export FAIL_CONDA=1
    . "$CONFIG_DIR/envman.sh"
    [ "$PATH" = "$TEST_ROOT/primary/bin:/usr/bin:/bin" ]
    [ -z "${LD_LIBRARY_PATH+x}" ]
'
printf 'PASS: conda executable fallback and no /lib for unset prefix\n'
mkdir -p "$test_root/primary/etc/profile.d"
printf 'conda() { :; }\nexport FALLBACK=loaded\n' > "$test_root/primary/etc/profile.d/conda.sh"
run '
    . "$CONFIG_DIR/host.sh"
    export FAIL_CONDA=1
    . "$CONFIG_DIR/envman.sh"
    [ "$FALLBACK" = loaded ]
'
printf 'PASS: conda profile.d fallback\n'
run '
    . "$CONFIG_DIR/host.sh"
    export FAIL_MAMBA=1
    if . "$CONFIG_DIR/envman.sh" 2> "$TEST_ROOT/error"; then exit 1; fi
    [ -s "$TEST_ROOT/error" ]
'
printf 'PASS: mamba initialization failure is reported\n'
run '
    if . "$CONFIG_DIR/envman.sh" 2> "$TEST_ROOT/error"; then exit 1; fi
    CONDA_ROOTS=("$TEST_ROOT/missing")
    if . "$CONFIG_DIR/envman.sh" 2> "$TEST_ROOT/error"; then exit 1; fi
'
printf 'PASS: missing array and unavailable installations fail explicitly\n'

# Substitute only the installed config path to exercise .bashrc without changing HOME.
sed 's|\$HOME/.config/bash|$CONFIG_DIR|g' "$source_dir/../../rc/bashrc" > "$test_root/bashrc"
printf 'export STARTUP_PACKAGE=loaded\n' > "$config_dir/package.sh"
printf 'export STARTUP_ALIAS=loaded\n' > "$config_dir/alias.sh"
printf 'export STARTUP_TYPING=loaded\n' > "$config_dir/typing.sh"
/usr/bin/env -i HOME="$HOME" PATH=/usr/bin:/bin TERM=xterm TEST_ROOT="$test_root" CONFIG_DIR="$config_dir" /bin/bash --noprofile --norc -iec '
    export FAIL_MAMBA=1
    . "$TEST_ROOT/bashrc" 2> "$TEST_ROOT/startup.error"
    [ "$STARTUP_PACKAGE" = loaded ]
    [ "$STARTUP_ALIAS" = loaded ]
    [ "$STARTUP_TYPING" = loaded ]
    case "$PS1" in *"\\t]"*) ;; *) exit 1 ;; esac
    grep -q "mamba shell initialization failed" "$TEST_ROOT/startup.error"
    grep -q "continuing shell setup" "$TEST_ROOT/startup.error"
    declare -F conda >/dev/null
'
printf 'PASS: mamba failure is reported without suppressing aliases and prompt\n'

cat > "$test_root/primary/etc/profile.d/mamba.sh" <<'MOCK'
printf 'profile\n' >> "$TEST_ROOT/mamba-profile.calls"
declare -F conda >/dev/null || return 1
mamba() { :; }
MOCK
run '
    . "$CONFIG_DIR/host.sh"
    export FAIL_MAMBA=1 CONDA_DEFAULT_ENV=project CONDA_PROMPT_MODIFIER="(project) "
    . "$CONFIG_DIR/envman.sh"
    . "$CONFIG_DIR/envman.sh"
    declare -F conda mamba >/dev/null
    [ "$(wc -l < "$TEST_ROOT/mamba-profile.calls")" -eq 1 ]
    [ "$MAMBA_EXE" = "$TEST_ROOT/primary/bin/mamba" ]
    [ "$MAMBA_ROOT_PREFIX" = "$TEST_ROOT/primary" ]
    [ "$CONDA_DEFAULT_ENV" = project ]
    . "$CONFIG_DIR/display.sh"
    case "$PS1" in "(project) "*) ;; *) exit 1 ;; esac
'
printf 'PASS: legacy mamba profile fallback initializes once and preserves the active environment\n'
printf 'return 7\n' > "$test_root/primary/etc/profile.d/mamba.sh"
run '
    . "$CONFIG_DIR/host.sh"
    export FAIL_MAMBA=1
    if . "$CONFIG_DIR/envman.sh"; then exit 1; fi
'
printf 'PASS: a failing legacy profile still returns failure\n'
run '
    . "$CONFIG_DIR/host.sh"
    . "$CONFIG_DIR/envman.sh"
    declare -F mamba >/dev/null
'
printf 'PASS: modern hook takes precedence over the legacy profile\n'
