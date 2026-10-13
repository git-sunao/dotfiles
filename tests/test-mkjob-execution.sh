#!/bin/bash
set -eu
export WORK_HOST=fixture
repo_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkjob="$repo_dir/scripts/mkjob"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/mkjob-execution-test.XXXXXX")
test_root=$(cd -P -- "$test_root" && pwd)
trap 'rm -rf -- "$test_root"' EXIT
mkdir "$test_root/work space" "$test_root/bin"
export PBS_TEST_ROOT="$test_root" PBS_TEST_BASHRC="$test_root/bashrc"
printf 'export PBS_TEST_HOST=loaded\n' > "$PBS_TEST_BASHRC"
cat > "$test_root/setup file.sh" <<'SH'
[ "$PBS_TEST_HOST" = loaded ]
[ "$PWD" = "$PBS_TEST_ROOT/work space" ]
export PBS_TEST_SETUP=loaded
SH
cat > "$test_root/check args.sh" <<'SH'
#!/bin/bash
set -eu
[ "$PBS_TEST_HOST" = loaded ]
[ "$PBS_TEST_SETUP" = loaded ]
[ "$PWD" = "$PBS_TEST_ROOT/work space" ]
[ "$#" -eq 4 ]
[ "$1" = 'two words' ]
[ -z "$2" ]
[ "$3" = '$(touch injected)' ]
[ "$4" = "quote'and\"double" ]
printf 'ran\n' > "$PBS_TEST_ROOT/ran"
SH
for tool in qsub mpirun; do
    cat > "$test_root/bin/$tool" <<'SH'
#!/bin/bash
printf 'unexpected scheduler call\n' > "$PBS_TEST_ROOT/scheduler-called"
exit 90
SH
    chmod +x "$test_root/bin/$tool"
done
cat > "$test_root/bin/pbsnodes" <<'SH'
#!/bin/bash
[ "$#" -eq 1 ] && [ "$1" = -a ] || exit 91
for ((i=1;i<=60;i++)); do
    printf 'node%s\n     state = free\n     np = 28\n\n' "$i"
done
SH
chmod +x "$test_root/bin/pbsnodes"
cat > "$test_root/bin/qstat" <<'SH'
#!/bin/bash
[ "$#" -eq 2 ] && [ "$1" = -Qf ] || exit 91
printf '%s\n' "$2" > "$PBS_TEST_ROOT/queried-queue"
if [ -e "$PBS_TEST_ROOT/query-fails" ]; then
    printf 'qstat: queue unavailable\n' >&2
    exit 92
fi
cat "$PBS_TEST_ROOT/queue-info"
SH
chmod +x "$test_root/bin/qstat"
queue_limit() {
    cat > "$test_root/queue-info" <<QUEUE
Queue: unrelated
    resources_max.ncpus = 999999
Queue: sample
    resources_default.nodes = 1
    resources_default.walltime = 01:00:00
    resources_max.ncpus = $1
    max_user_run = 1
QUEUE
}
queue_limit 6
export PATH="$test_root/bin:$PATH"
generate() {
    "$mkjob" --queue sample --nodes 2 --ppn 3 \
        --walltime 168:00:00 --workdir "$test_root/work space" "$@"
}
reject() {
    if generate --output "$test_root/rejected.pbs" "$@" > "$test_root/error" 2>&1; then
        printf 'FAIL: accepted invalid request\n' >&2; exit 1
    fi
    [ ! -e "$test_root/rejected.pbs" ]
}
# Replace only the generated startup path, so tests never load real home settings.
run_job() {
    sed 's|"$HOME/.bashrc"|"$PBS_TEST_BASHRC"|' "$1" > "$test_root/run.pbs"
    /bin/bash --noprofile --norc "$test_root/run.pbs" > "$test_root/job-log" 2>&1
}

generate --output "$test_root/job.pbs" --name sample_job --setup "$test_root/setup file.sh" \
    -- /bin/bash "$test_root/check args.sh" 'two words' '' '$(touch injected)' "quote'and\"double"
[ ! -e "$test_root/ran" ]
[ ! -e "$test_root/scheduler-called" ]
[ "$(cat "$test_root/queried-queue")" = sample ]
/bin/bash -n "$test_root/job.pbs"
grep -qx '#PBS -q sample' "$test_root/job.pbs"
grep -qx '#PBS -l nodes=2:ppn=3' "$test_root/job.pbs"
grep -qx '#PBS -l walltime=168:00:00' "$test_root/job.pbs"
if grep -q '^#PBS -V' "$test_root/job.pbs"; then exit 1; fi
run_job "$test_root/job.pbs"
[ "$(cat "$test_root/ran")" = ran ]
[ ! -e "$test_root/work space/injected" ]
grep -q 'exit=0$' "$test_root/job-log"
printf 'PASS: generation does not execute commands; job preserves arguments, startup order and workdir\n'

for status in 7 43; do
    generate --output "$test_root/failure-$status.pbs" -- /bin/bash -c "exit $status"
    actual=0
    run_job "$test_root/failure-$status.pbs" || actual=$?
    [ "$actual" -eq "$status" ]
    grep -q "exit=$status$" "$test_root/job-log"
done
printf 'return 29\n' > "$test_root/failing-setup.sh"
generate --output "$test_root/setup-failure.pbs" --setup "$test_root/failing-setup.sh" \
    -- touch "$test_root/continued"
actual=0
run_job "$test_root/setup-failure.pbs" || actual=$?
[ "$actual" -eq 0 ]
[ -e "$test_root/continued" ]
rm "$test_root/continued"
printf 'return 31\n' > "$PBS_TEST_BASHRC"
actual=0
run_job "$test_root/setup-failure.pbs" || actual=$?
[ "$actual" -eq 0 ]
[ -e "$test_root/continued" ]
printf 'export PBS_TEST_HOST=loaded\n' > "$PBS_TEST_BASHRC"
generate 'false; printf "continued\\n"' --output "$test_root/continue-command.pbs"
run_job "$test_root/continue-command.pbs"
grep -qx continued "$test_root/job-log"
grep -q 'exit=0$' "$test_root/job-log"
printf 'PASS: final command status is preserved; initialization and intermediate failures do not force exit\n'

for literal_command in if PBS_TEST_NOT_A_COMMAND=value; do
    generate --output "$test_root/literal-$literal_command.pbs" -- "$literal_command"
    /bin/bash -n "$test_root/literal-$literal_command.pbs"
    actual=0
    run_job "$test_root/literal-$literal_command.pbs" || actual=$?
    [ "$actual" -eq 127 ]
done
printf 'PASS: command words are not interpreted as shell syntax or assignments\n'

cp "$test_root/job.pbs" "$test_root/original.pbs"
if generate --output "$test_root/job.pbs" -- true > "$test_root/error" 2>&1; then exit 1; fi
cmp "$test_root/original.pbs" "$test_root/job.pbs"
ln -s "$test_root/missing" "$test_root/link.pbs"
if generate --output "$test_root/link.pbs" -- true > "$test_root/error" 2>&1; then exit 1; fi
[ ! -e "$test_root/missing" ]
[ -L "$test_root/link.pbs" ]
if generate --output "$test_root/work space" -- true > "$test_root/error" 2>&1; then exit 1; fi
for invalid in 0 -1 01 1.5 '2:ppn=8'; do reject --nodes "$invalid" -- true; done
reject --ppn 0 -- true
reject --walltime 00:00:00 -- true
reject --walltime 01:60:00 -- true
reject --walltime 7:00:00:00 -- true
reject --queue $'sample\n#PBS -V' -- true
reject --name $'job\n#PBS -V' -- true
reject --setup "$test_root/missing" -- true
reject --workdir "$test_root/missing" -- true
reject --submit -- true
reject --
reject --ppn
printf 'PASS: existing outputs, dangling links, invalid resources and directive injection are rejected\n'

# Read the current limit on every generation; never use defaults or another queue.
queue_limit 7
generate --output "$test_root/below-limit.pbs" -- true
queue_limit 5
reject -- true
grep -q 'exceeds CPU limit 5' "$test_root/error"
queue_limit 1000
reject --nodes 36 --ppn 28 -- true
grep -q 'nodes=36 \* ppn=28 exceeds CPU limit 1000' "$test_root/error"
generate --output "$test_root/within-1000.pbs" --nodes 35 --ppn 28 -- true
reject --nodes 999999999999999999 --ppn 999999999999999999 -- true
reject --nodes 18446744073709551617 --ppn 1 -- true
for limit in '' invalid -1 '6 extra' 0 9999999999999999999; do
    queue_limit "$limit"
    reject -- true
done
printf 'Queue: sample\n    resources_default.ncpus = 6\n' > "$test_root/queue-info"
reject -- true
printf 'Queue: another\n    resources_max.ncpus = 6\n' > "$test_root/queue-info"
reject -- true
queue_limit 6
printf '    resources_max.ncpus = 7\n' >> "$test_root/queue-info"
reject -- true
queue_limit 6
touch "$test_root/query-fails"
reject -- true
grep -q 'could not read queue sample' "$test_root/error"
rm "$test_root/query-fails"
reject --queue unknown -- true
[ "$(cat "$test_root/queried-queue")" = unknown ]
# A missing executable must not accidentally fall through to the system qstat.
ln -s "$(command -v python3)" "$test_root/bin/python3"
mv "$test_root/bin/qstat" "$test_root/bin/qstat.saved"
if PATH="$test_root/bin" "$mkjob" \
    --queue sample --nodes 1 --ppn 1 --walltime 01:00:00 \
    --output "$test_root/rejected.pbs" -- true > "$test_root/error" 2>&1; then exit 1; fi
[ ! -e "$test_root/rejected.pbs" ]
grep -q 'could not read queue sample' "$test_root/error"
mv "$test_root/bin/qstat.saved" "$test_root/bin/qstat"
printf 'PASS: exact/below/above CPU limits, refreshed values, bad data, failed queries and overflow checks\n'

# Source guards must leave the caller alive and unchanged, even after failure.
/bin/bash --noprofile --norc -c '
    set +e +u
    before=$-
    . "$2"
    [ "$-" = "$before" ] || exit 1
    false
    printf "survived\n"
' bash unused "$test_root/job.pbs" > "$test_root/source-log" 2>&1
grep -q '^survived$' "$test_root/source-log"
[ ! -e "$test_root/scheduler-called" ]
printf 'PASS: neither sourcing nor generation submits jobs or changes the caller shell\n'
