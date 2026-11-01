# Batch jobs

`mkjob` generates TORQUE or PBS Professional/OpenPBS scripts without submitting or overwriting files.
Requires Python 3 and `qstat`/`pbsnodes`; select the MPI dialect matching your installation.

```bash
mkjob 'python run_mcmc.py test1.out' -q mini -n mcmc_test1 \
    -t 10:00:00 -d "$PWD" -c fastnc -s setup.sh --mpi --omp '>=2,<=4' --opt
```

- Defaults maximize ppn, then nodes. `--opt` uses currently free slots; start time is not guaranteed.
- Explicit counts stay fixed. MPI/OMP maximize used CPUs, then prefer fewer threads and nodes. OMP alone uses one node.
- [queues.csv](queues.csv): `server,queue,max_ppn,max_nodes,max_cpus`, selected by `WORK_HOST`. Caps only lower PBS limits; missing entries use PBS values. gw uses 28 slots/node; gfarm lists general-access queues; idark uses live `host_group` membership and node capacities.
- TORQUE uses `nodes/ppn`; PBS Professional/OpenPBS uses `select/ncpus/mpiprocs/ompthreads` with `place=scatter`. `--opt` reads PBS assigned CPUs, or TORQUE job slots. Multiple vnodes per host are unsupported.
- `-t` accepts `HH:MM:SS` or `D:HH:MM:SS`. TORQUE outputs days for durations ≥24h; PBS Professional/OpenPBS outputs total hours. Omitting `-t` leaves walltime to PBS.
- Jobs load `.bashrc`, enter `-d`, run `--init` once, activate `-c`, source `-s`, set the allocated OMP count, then launch the command. No implicit `set -e`; logs use PBS defaults.
- [Template](templates/mkjob.pbs.sh.tmpl): Python format fields; escape literal braces as `{{`/`}}`.
- `--mpi-flavor openmpi` (default) uses `mpirun --map-by`; `--mpi-flavor portable` uses `mpiexec -n` for MPICH or compatible installations. `--queue-file PATH` selects an alternative capacity table.
- Python API: load `BatchJob` with `runpy.run_path`; use `read_resources()`, `plan()`, `render()`, `write()`. `make_parser()` exposes the same CLI options for thin wrappers. Recreate objects after editing the CSV.

See `mkjob --help`. `submit-pbs` is the legacy generator with hard-coded resources and optional `--submit`.
For hand-written jobs, source `~/.bashrc` and, if conda is needed, `~/.config/bash/envman.sh` before activation.

## Common initialization

Use `--init "$common"` (alias `--ini`) for trusted Bash commands that should run
once before MPI launch. Quote the whole block; it is shell code, not an INI file.
Exported variables are inherited by every launched process. The block runs after
changing directory and before optional `--conda`/`--setup` and the allocated OMP
setting. Use explicit `|| exit 1` for required setup steps; no `set -e` is added.

```bash
common='
source ./setup.sh || exit 1
ulimit -s 8192 || exit 1
export PYTHONUNBUFFERED=1
'
mkjob "cosmosis-campaign campaign.yml --run run_name --mpi" \
    --init "$common" --directory "$WORKDIR" \
    --queue mini --name run_name --mpi --omp 1
```

The outer `--mpi` starts the MPI launcher; the inner option enables CosmoSIS MPI.
The default launcher is Open MPI (`mpirun --map-by`). Add `--mpi-flavor portable`
for MPICH or another installation using `mpiexec -n`.
Python callers can pass the same block as `BatchJob(..., initialization=common)`.

## Maintaining copies

The canonical source is the dotfiles `scripts/batch/` directory. When vendoring
this generator in another project, copy `mkjob`, `queues.csv`, this README and
`templates/mkjob.pbs.sh.tmpl` without local modifications. Make generic changes
here first and synchronize all four files together. Keep application-specific
setup and examples outside this directory.
