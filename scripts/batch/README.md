# Batch jobs

`mkjob` generates TORQUE or PBS Professional/OpenPBS scripts without submitting or overwriting files.
Requires Python 3 and `qstat`/`pbsnodes`; MPI options target Open MPI.

```bash
mkjob 'python run_mcmc.py test1.out' -q mini -n mcmc_test1 \
    -t 10:00:00 -d "$PWD" -c fastnc -s setup.sh --mpi --omp '>=2,<=4' --opt
```

- Defaults maximize ppn, then nodes. `--opt` uses currently free slots; start time is not guaranteed.
- Explicit counts stay fixed. MPI/OMP maximize used CPUs, then prefer fewer threads and nodes. OMP alone uses one node.
- [queues.csv](queues.csv): `server,queue,max_ppn,max_nodes,max_cpus`, selected by `WORK_HOST`. Caps only lower PBS limits; missing entries use PBS values. gw uses 28 slots/node; gfarm lists general-access queues; idark uses live `host_group` membership and node capacities.
- TORQUE uses `nodes/ppn`; PBS Professional/OpenPBS uses `select/ncpus/mpiprocs/ompthreads` with `place=scatter`. `--opt` reads PBS assigned CPUs, or TORQUE job slots. Multiple vnodes per host are unsupported.
- `-t` accepts `HH:MM:SS` or `D:HH:MM:SS`. TORQUE outputs days for durations ≥24h; PBS Professional/OpenPBS outputs total hours. Omitting `-t` leaves walltime to PBS.
- Jobs load `.bashrc`, enter `-d`, activate `-c`, source `-s`, then run the command. No implicit `set -e`; logs use PBS defaults.
- [Template](templates/mkjob.pbs.sh.tmpl): Python format fields; escape literal braces as `{{`/`}}`.
- Python API: load `BatchJob` with `runpy.run_path`; use `read_resources()`, `plan()`, `render()`, `write()`. Recreate objects after editing the CSV.

See `mkjob --help`. `submit-pbs` is the legacy generator with hard-coded resources and optional `--submit`.
For hand-written jobs, source `~/.bashrc` and, if conda is needed, `~/.config/bash/envman.sh` before activation.
