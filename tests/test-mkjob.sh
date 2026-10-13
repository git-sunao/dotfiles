#!/bin/bash
set -eu
export WORK_HOST=fixture
repo=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkjob="$repo/bin/mkjob"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/mkjob-test.XXXXXX")
fixture=$(cd -P -- "$fixture" && pwd)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/work space"
export PBS_FIXTURE=$fixture PATH="$fixture/bin:$PATH"
cat > "$fixture/bin/qstat" <<'SH'
#!/bin/bash
[ "$#" = 2 ] && [ "$1" = -Qf ] && [ "$2" = sample ] || exit 91
printf 'qstat\n' >> "$PBS_FIXTURE/queries"
[ ! -e "$PBS_FIXTURE/qstat-fails" ] || exit 92
cat "$PBS_FIXTURE/queue"
SH
cat > "$fixture/bin/pbsnodes" <<'SH'
#!/bin/bash
[ "$#" = 1 ] && [ "$1" = -a ] || exit 91
printf 'pbsnodes\n' >> "$PBS_FIXTURE/queries"
[ ! -e "$PBS_FIXTURE/nodes-fail" ] || exit 92
cat "$PBS_FIXTURE/nodes"
SH
for tool in qsub mpirun conda; do
    cat > "$fixture/bin/$tool" <<'SH'
#!/bin/bash
touch "$PBS_FIXTURE/unexpected-execution"
exit 93
SH
done
chmod +x "$fixture/bin/"*
queue() {
    printf 'Queue: unrelated\n    resources_max.ncpus = 999999\nQueue: sample\n    resources_max.ncpus = %s\n    resources_default.nodes = 1\n    resources_default.walltime = 01:00:00\n    enabled = True\n    started = True\n' "$1" > "$fixture/queue"
}
node() {
    printf '%s\n    state = %s\n    np = %s\n    properties = %s\n    jobs = %s\n\n' \
        "$1" "$2" "$3" "${5:-compute}" "${4:-}" >> "$fixture/nodes"
}
generate() {
    rm -f "$fixture/job.pbs"
    : > "$fixture/queries"
    "$mkjob" -q sample -d "$fixture/work space" \
        -o "$fixture/job.pbs" "$@" > "$fixture/result"
    /bin/bash -n "$fixture/job.pbs"
    [ "$(cat "$fixture/queries")" = $'qstat\npbsnodes' ]
}
allocation() { grep -qx "#PBS -l nodes=$1:ppn=$2" "$fixture/job.pbs"; }
parallelism() {
    grep -qx "export OMP_NUM_THREADS=$2" "$fixture/job.pbs"
    grep -q "mpirun -n $1 --map-by ppr:$3:node:PE=$2 " "$fixture/job.pbs"
}
reject() {
    rm -f "$fixture/job.pbs"
    if "$mkjob" -q sample -o "$fixture/job.pbs" "$@" > "$fixture/error" 2>&1; then
        printf 'Unexpected acceptance: %s\n' "$*" >&2; exit 1
    fi
    [ ! -e "$fixture/job.pbs" ]
}

queue 112
: > "$fixture/nodes"
for n in a b c d; do node "$n" free 28; done
generate 'python run_mcmc.py test1.out' -n mcmc_test1 -t 10:00:00 -c fastnc
allocation 4 28
grep -qx 'conda activate fastnc' "$fixture/job.pbs"
grep -qx '#PBS -l walltime=10:00:00' "$fixture/job.pbs"
generate true --nodes 2
allocation 2 28
generate true --ppn 7
allocation 4 7
queue 28
generate true --nodes 2
allocation 2 14
reject true --nodes 2 --ppn 28
generate true --mpi
allocation 1 28; parallelism 28 1 28
generate true --omp
allocation 1 28
grep -qx 'export OMP_NUM_THREADS=28' "$fixture/job.pbs"
reject true --omp --nodes 2
reject true --mpi --omp
generate true --mpi --omp '>=4'
parallelism 7 4 7
generate true --mpi --omp '>=2,<5'
parallelism 14 2 14
generate true --mpi --omp '=>2,=<4'
parallelism 14 2 14
generate true --mpi --omp '>3,<5'
parallelism 7 4 7
generate true --mpi --omp ' <5 , =>2 '
parallelism 14 2 14
generate true --mpi 4 --omp '>=2,<=8'
parallelism 4 7 4
generate true --omp '<5'
grep -qx 'export OMP_NUM_THREADS=4' "$fixture/job.pbs"
generate true --mpi 7 --omp 4
parallelism 7 4 7
reject true --mpi 8 --omp 4
generate true --nodes 2 --ppn 14 --mpi 5 --omp 4
parallelism 5 4 3
reject true --nodes 2 --ppn 14 --mpi 7 --omp 4
queue 30
: > "$fixture/nodes"; node a free 30
generate true --mpi --omp '>=4'
parallelism 6 5 6
for range in '' ' ' 0 -1 01 '>=4,<=2' '<1' '>=31' '>999999999' '>=' \
    '>=02' '2<=4' '=4' '>=2,,<5' '>=2,' ',<5' '>=2,<5,<=4' '>=2&<5' \
    '$(touch bad)' $'>=2\n#PBS -V'; do
    reject true --omp "$range"
done
reject true --mpi 0
reject true -s
for option in --directory --conda --setup --output; do reject true "$option" ''; done
reject 'echo ('
reject true --submit
printf 'PASS: CLI, maximum resources, fixed MPI/OMP, bounds/aliases and per-node fit\n'

# Reducing ppn may allow more nodes than the normal maximum-ppn allocation.
queue 28
: > "$fixture/nodes"
for n in a b c d; do node "$n" free 28 '0-19/1.server'; done
generate true --mpi --opt
allocation 4 7; parallelism 28 1 7
generate true --mpi 16 --opt
allocation 2 8; parallelism 16 1 8
generate true --mpi --omp 4 --opt
allocation 3 8; parallelism 6 4 2
generate true --mpi --nodes 2 --opt
allocation 2 8
generate true --mpi --ppn 8 --opt
allocation 3 8
reject true --mpi 16 --omp 2 --opt
printf '    resources_max.nodect = 2\n' >> "$fixture/queue"
generate true --mpi --opt
allocation 2 8

# Free slots 8,8,4,0. The third node includes ranges split before a job ID;
# a duplicate slot must not be counted twice. Busy/offline capacity cannot win.
queue 112
: > "$fixture/nodes"
node a free 28 '0-19/10.server'
node b free 28 '0-19/11.server'
node c free 28 '0-8,12-26/12.server,0/12.server'
node d job-exclusive 28
node login offline 256
generate true --mpi --opt
allocation 2 8; parallelism 16 1 8
generate true --mpi --omp 4 --opt
allocation 2 8; parallelism 4 4 2
generate true --mpi --omp '=>3,=<4' --opt
allocation 2 8; parallelism 4 4 2
generate true --nodes 3 --mpi --opt
allocation 3 4; parallelism 12 1 4
generate true --ppn 8 --mpi --opt
allocation 2 8
generate true --mpi 2 --omp 4 --opt
allocation 1 8; parallelism 2 4 2
generate true --mpi 1 --omp 4 --opt
allocation 1 4; parallelism 1 4 1
reject true --nodes 4 --opt
reject true --ppn 9 --opt
reject true --mpi 8 --omp '>=4' --opt
: > "$fixture/nodes"; node a free 28 '0-27/1.server'
reject true --opt
generate true --mpi
allocation 1 28
: > "$fixture/nodes"; node a free 28 '0-29/1.server'
reject true --opt
: > "$fixture/nodes"; node a free 28 'broken'
generate true
reject true --opt
# qstat/pbsnodes can wrap long values onto indented continuation lines.
printf 'a\n    state = free\n    np = 28\n    jobs = 0-8,\n        12-26/12.server\n' > "$fixture/nodes"
generate true --mpi --opt
allocation 1 4; parallelism 4 1 4
printf 'PASS: optimization, slot ranges, duplicate slots, unavailable nodes and fixed constraints\n'

queue 112
: > "$fixture/nodes"; node a free 56; node b free 28
generate true --mpi
allocation 1 56
generate true --nodes 2 --mpi
allocation 2 28
printf '    resources_max.nodect = 1\n' >> "$fixture/queue"
reject true --nodes 2
generate true --mpi
allocation 1 56
queue 112
printf '    resources_default.neednodes = compute\n' >> "$fixture/queue"
: > "$fixture/nodes"; node a free 28 '' compute; node b free 56 '' other
node bad offline 0
node unrelated free 0 '' other
generate true --mpi
grep -qx '#PBS -l nodes=1:compute:ppn=28' "$fixture/job.pbs"
queue 112
printf '    resources_default.neednodes = 1:compute+1:other\n' >> "$fixture/queue"
reject true
queue 112
touch "$fixture/nodes-fail"; reject true; rm "$fixture/nodes-fail"
touch "$fixture/qstat-fails"; reject true; rm "$fixture/qstat-fails"
: > "$fixture/nodes"; reject true
printf 'node\n    state = free\n' > "$fixture/nodes"; reject true
: > "$fixture/nodes"; node a free 28
printf '    started = False\n' >> "$fixture/queue"; reject true
printf 'PASS: mixed capacities, node limits, property selectors and failed scheduler queries\n'

# Execute only fixture jobs; substitute startup paths without changing HOME.
queue 28
cat > "$fixture/bashrc" <<'SH'
export PBS_TEST_HOST=loaded
SH
cat > "$fixture/envman" <<'SH'
[ "$PBS_TEST_HOST" = loaded ]
[ "$PWD" = "$PBS_FIXTURE/work space" ]
conda() { [ "$1" = activate ] && [ "$2" = fastnc ]; export PBS_TEST_ENV=$2; }
SH
cat > "$fixture/setup file.sh" <<'SH'
[ "$PBS_TEST_ENV" = fastnc ]
export PBS_TEST_SETUP=loaded
SH
generate '[ "$PBS_TEST_SETUP" = loaded ]; printf "%s\n" "two words" > result.txt' \
    -c fastnc -s "$fixture/setup file.sh" --omp 4
[ ! -e "$fixture/work space/result.txt" ]
sed -e 's|"$HOME/.bashrc"|"$PBS_FIXTURE/bashrc"|' \
    -e 's|"$HOME/.config/bash/envman.sh"|"$PBS_FIXTURE/envman"|' \
    "$fixture/job.pbs" > "$fixture/run.pbs"
/bin/bash "$fixture/run.pbs" > "$fixture/job-log"
[ "$(cat "$fixture/work space/result.txt")" = 'two words' ]
grep -q 'exit=0$' "$fixture/job-log"
printf 'return 29\n' > "$fixture/setup file.sh"
status=0
/bin/bash "$fixture/run.pbs" > "$fixture/job-log" || status=$?
[ "$status" -eq 0 ]
grep -q 'exit=0$' "$fixture/job-log"
[ ! -e "$fixture/unexpected-execution" ]
cat > "$fixture/bin/mpirun" <<'SH'
#!/bin/bash
set -eu
[ "$1" = -n ] && [ "$2" = 7 ]
[ "$3" = --map-by ] && [ "$4" = ppr:7:node:PE=4 ]
[ "$OMP_NUM_THREADS" = 4 ]
shift 4
"$@"
SH
generate 'printf "%s\n" "$OMP_NUM_THREADS" > mpi-result.txt' --mpi --omp 4
sed 's|"$HOME/.bashrc"|"$PBS_FIXTURE/bashrc"|' "$fixture/job.pbs" > "$fixture/run.pbs"
/bin/bash "$fixture/run.pbs" > "$fixture/job-log"
[ "$(cat "$fixture/work space/mpi-result.txt")" = 4 ]
generate 'python3 -c '\''import os; print(os.environ["OMP_NUM_THREADS"])'\'' > python-result.txt' --mpi --omp 4
sed 's|"$HOME/.bashrc"|"$PBS_FIXTURE/bashrc"|' "$fixture/job.pbs" > "$fixture/run.pbs"
/bin/bash "$fixture/run.pbs" > "$fixture/job-log"
[ "$(cat "$fixture/work space/python-result.txt")" = 4 ]
generate 'exit 43' --mpi --omp 4
sed 's|"$HOME/.bashrc"|"$PBS_FIXTURE/bashrc"|' "$fixture/job.pbs" > "$fixture/run.pbs"
status=0
/bin/bash "$fixture/run.pbs" > "$fixture/job-log" || status=$?
[ "$status" -eq 43 ]
grep -q 'exit=43$' "$fixture/job-log"
( cd "$fixture/work space"; "$mkjob" true -q sample -n default_output > "$fixture/result" )
[ -f "$fixture/work space/default_output.pbs" ]
/bin/bash --noprofile --norc -c '
    set +e +u; before=$-
    . "$1"
    [ "$-" = "$before" ] || exit 1
    false
    printf "survived\n"
' bash "$fixture/job.pbs" > "$fixture/source-log" 2>&1
grep -qx survived "$fixture/source-log"
printf 'PASS: deferred command/conda/setup, Open MPI arguments, runtime failures, output and source guard\n'

# Resolve the template relative to the executable, even through a symlink and
# outside the repository. A missing template must not leave a partial output.
mkdir -p "$fixture/installed/templates"
cp "$mkjob" "$fixture/installed/mkjob"
cp "$repo/scripts/batch/templates/mkjob.pbs.sh.tmpl" "$fixture/installed/templates/"
printf '# external template marker\n' >> "$fixture/installed/templates/mkjob.pbs.sh.tmpl"
ln -s "$fixture/installed/mkjob" "$fixture/bin/mkjob"
( cd "$fixture/work space"; mkjob 'printf "%s" "{queue}"' -q sample -n external_template > "$fixture/result" )
grep -qx '# external template marker' "$fixture/work space/external_template.pbs"
grep -q '{queue}' "$fixture/work space/external_template.pbs"
/bin/bash -n "$fixture/work space/external_template.pbs"
rm "$fixture/installed/templates/mkjob.pbs.sh.tmpl"
if "$fixture/bin/mkjob" true -q sample -o "$fixture/missing-template.pbs" > "$fixture/error" 2>&1; then
    exit 1
fi
[ ! -e "$fixture/missing-template.pbs" ]
grep -q 'mkjob.pbs.sh.tmpl' "$fixture/error"
[ ! -e "$fixture/unexpected-execution" ]
printf 'PASS: external template, symlink/cwd independence, literal braces and missing-template protection\n'

queue 112
: > "$fixture/nodes"
node a free 56; node b free 56; node c free 28; node d free 28
cp "$repo/scripts/batch/templates/mkjob.pbs.sh.tmpl" "$fixture/installed/templates/"
mkjob="$fixture/installed/mkjob"
printf 'server,queue,max_ppn,max_nodes,max_cpus\nfixture,sample,28,,\n' > "$fixture/installed/queues.csv"
generate true --mpi
allocation 4 28; parallelism 112 1 28
generate true --mpi --omp 4 --opt
allocation 4 28; parallelism 28 4 7
reject true --ppn 56
: > "$fixture/nodes"; node a free 56 '28-47/1.server,28/1.server'
generate true --mpi --opt
allocation 1 8
: > "$fixture/nodes"; node a free 56 '0-27/1.server'
reject true --mpi --opt
printf 'server,queue,max_ppn,max_nodes,max_cpus\n' > "$fixture/installed/queues.csv"
generate true --mpi --opt
allocation 1 28
printf 'PASS: host capacity cap, hybrid allocation, occupied high slots and uncapped fallback\n'
