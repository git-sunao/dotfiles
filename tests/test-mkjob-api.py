"""Test BatchJob resource allocation and its interactive API without a scheduler."""

from pathlib import Path
from itertools import product
import os
import runpy
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
mkjob = runpy.run_path(str(SCRIPTS / "mkjob"))
BatchJob = mkjob["BatchJob"]

QUEUE = """Queue: sample
    resources_max.ncpus = 16
    resources_default.walltime = 01:00:00
"""
NODES = """a
    state = free
    np = 8
    jobs = 0-3/one
b
    state = free
    np = 8
    jobs = 0-1/two
"""


class BatchJobTests(unittest.TestCase):
    def setUp(self):
        # Host-local settings must not change unrelated fixture expectations.
        env = patch.dict(os.environ)
        env.start()
        self.addCleanup(env.stop)
        os.environ["WORK_HOST"] = "fixture"
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.queue_file = Path(directory.name) / "queues.csv"
        self.set_queues("")
        config = patch.dict(BatchJob.__init__.__globals__, QUEUE_FILE=self.queue_file)
        config.start()
        self.addCleanup(config.stop)

    def set_queues(self, rows):
        self.queue_file.write_text("server,queue,max_ppn,max_nodes,max_cpus\n" + rows)

    def test_per_node_capacity_cap(self):
        resources = dict(cpu_limit=112, node_limit=4, properties=[], walltime="01:00:00",
                         nodes=[dict(name=str(i), total=total, states={"free"}, jobs="")
                                for i, total in enumerate([56, 56, 28, 28])])
        self.assertEqual(BatchJob(["true"], queue="sample", mpi="auto").plan(resources),
                         (2, 56, 112, 1))
        self.set_queues("fixture,sample,28,,\n")
        for opt in (False, True):
            job = BatchJob(["true"], queue="sample", mpi="auto", opt=opt)
            self.assertEqual(job.plan(resources), (4, 28, 112, 1))
            self.assertIn("#PBS -l nodes=4:ppn=28", job.render(resources))
            self.assertEqual(BatchJob(["true"], queue="sample", mpi="auto", omp=4,
                                     opt=opt).plan(resources), (4, 28, 28, 4))
        with self.assertRaises(ValueError):
            BatchJob(["true"], queue="sample", ppn=56)
        self.set_queues("fixture,sample,14,,\n")
        self.assertEqual(BatchJob(["true"], queue="sample", mpi="auto")
                         .plan(resources), (4, 14, 56, 1))
        resources["cpu_limit"] = 1
        self.assertEqual(job.plan(resources), (1, 1, 1, 1))

    def test_cap_subtracts_all_occupied_slots(self):
        self.set_queues("fixture,sample,28,,\n")
        job = BatchJob(["true"], queue="sample", mpi="auto", opt=True)
        node = dict(name="a", total=56, states={"free"}, jobs="28-47/job,28/job")
        resources = dict(cpu_limit=112, node_limit=4, nodes=[node])
        self.assertEqual(job.count_free_slots(node), 8)
        self.assertEqual(job.plan(resources), (1, 8, 8, 1))
        for occupied in ("0-27/job", "28-55/job", "0-55/job"):
            node["jobs"] = occupied
            self.assertEqual(job.count_free_slots(node), 0)
            with self.assertRaises(ValueError):
                job.plan(resources)
        node.update(total=8, jobs="0-2/job")
        self.assertEqual(job.plan(resources), (1, 5, 5, 1))
        node["states"] = {"job-exclusive"}
        self.assertEqual(job.count_free_slots(node), 0)

    def test_invalid_capacity_cap(self):
        for value in ("0", "-1", "abc", "2.5"):
            self.set_queues(f"fixture,sample,{value},,\n")
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    BatchJob(["true"], queue="sample")

    def test_queue_table_selection_and_live_limits(self):
        self.set_queues("other,sample,1,1,1\nfixture,other,2,1,2\nfixture,sample,4,1,6\n")
        with patch.dict(BatchJob.read_resources.__globals__, query=Mock(side_effect=[QUEUE, NODES])):
            job = BatchJob(["true"], queue="sample", mpi="auto")
            resources = job.read_resources()
        self.assertEqual(resources["cpu_limit"], 6)
        self.assertEqual(resources["node_limit"], 1)
        self.assertEqual(job.plan(resources), (1, 4, 4, 1))
        with self.assertRaises(ValueError):
            BatchJob(["true"], queue="sample", nodes=2).plan(resources)
        # Even a caller-supplied snapshot must retain the file's node/CPU caps.
        resources.update(cpu_limit=100, node_limit=100)
        self.assertEqual(job.plan(resources), (1, 4, 4, 1))
        self.set_queues("fixture,sample,100,100,100\n")
        with patch.dict(BatchJob.read_resources.__globals__, query=Mock(side_effect=[QUEUE, NODES])):
            job = BatchJob(["true"], queue="sample", mpi="auto")
            resources = job.read_resources()
        self.assertEqual(resources["cpu_limit"], 16)
        self.assertEqual(job.plan(resources), (2, 8, 16, 1))

    def test_optional_table_and_invalid_rows(self):
        self.set_queues("fixture,other,28,,\n")
        self.assertEqual(BatchJob(["true"], queue="sample").limits, {})
        self.set_queues("fixture,sample,,,\n")
        self.assertEqual(BatchJob(["true"], queue="sample").limits, {})
        os.environ.pop("WORK_HOST")
        with self.assertRaisesRegex(ValueError, "WORK_HOST"):
            BatchJob(["true"], queue="sample")
        os.environ["WORK_HOST"] = "fixture"
        for rows in ("fixture,sample,28,,\nfixture,sample,14,,\n", "fixture,sample,28\n",
                     "fixture,sample,28,,,extra\n", ",sample,28,,\n",
                     "fixture,sample,,0,\n", "fixture,sample,,,-1\n"):
            self.set_queues(rows)
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                BatchJob(["true"], queue="sample")
        self.queue_file.write_text("server,queue,ppn\n")
        with self.assertRaisesRegex(ValueError, "header"):
            BatchJob(["true"], queue="sample")
        self.queue_file.unlink()
        self.assertEqual(BatchJob(["true"], queue="sample").limits, {})
        with self.assertRaises(FileNotFoundError):
            BatchJob(["true"], queue="sample", queue_file=self.queue_file.with_name("missing.csv"))

    def test_opt_can_spread_across_more_nodes(self):
        resources = dict(cpu_limit=28, node_limit=4, properties=[], walltime="01:00:00",
                         nodes=[dict(name=str(i), total=28, states={"free"}, jobs="0-19/job")
                                for i in range(4)])
        cases = [
            (dict(mpi="auto"), (4, 7, 28, 1)),
            (dict(mpi=16), (2, 8, 16, 1)),
            (dict(mpi="auto", omp=4), (3, 8, 6, 4)),
            (dict(mpi="auto", nodes=2), (2, 8, 16, 1)),
            (dict(mpi="auto", ppn=8), (3, 8, 24, 1)),
        ]
        for options, expected in cases:
            with self.subTest(options=options):
                self.assertEqual(BatchJob(["true"], queue="sample", opt=True,
                                          **options).plan(resources), expected)
        resources["node_limit"] = 2
        self.assertEqual(BatchJob(["true"], queue="sample", mpi="auto", opt=True)
                         .plan(resources), (2, 8, 16, 1))

    def test_opt_matches_exhaustive_feasible_allocations(self):
        # Enumerate complete (nodes, ppn, ranks, threads) allocations directly;
        # this does not reuse mkjob's candidate generation or OMP parser.
        for free in ([4, 3, 2], [0, 4, 4]):
            resources = dict(node_limit=3, properties=[], walltime="01:00:00",
                             nodes=[dict(name=str(i), total=6, states={"free"},
                                         jobs=f"0-{5 - slots}/job")
                                    for i, slots in enumerate(free)])
            for limit, nodes, ppn, mpi, omp in product(
                    [4, 8, 12], [None, 1, 2, 3], [None, 2, 4],
                    [None, "auto", 2, 5], [None, "auto", "2", ">=2,<=3"]):
                if mpi == omp == "auto" or (mpi is None and omp is not None and nodes not in (None, 1)):
                    continue
                options = dict(nodes=nodes, ppn=ppn, mpi=mpi, omp=omp)
                resources["cpu_limit"] = limit
                job = BatchJob(["true"], queue="sample", opt=True, **options)
                feasible = []
                for n, p, t in product(range(1, 4), range(1, 7), range(1, 7)):
                    if n * p > limit or sum(slots >= p for slots in free) < n:
                        continue
                    if nodes is not None and n != nodes or ppn is not None and p != ppn:
                        continue
                    if mpi is None and omp is not None and n != 1:
                        continue
                    if t > p or omp is None and t != 1 or omp == "2" and t != 2:
                        continue
                    if omp == ">=2,<=3" and not 2 <= t <= 3:
                        continue
                    ranks = 1 if mpi is None else n * (p // t) if mpi == "auto" else mpi
                    if ranks > n * (p // t):
                        continue
                    used = n * p if mpi is omp is None else ranks * t
                    feasible.append(((used, -t, -n, -p), (n, p, ranks, t)))
                with self.subTest(free=free, limit=limit, **options):
                    if feasible:
                        self.assertEqual(job.plan(resources), max(feasible)[1])
                    else:
                        with self.assertRaises(ValueError):
                            job.plan(resources)

    def test_excluded_nodes_do_not_require_valid_capacity(self):
        healthy = "healthy\n    state = free\n    np = 28\n    properties = compute\n"
        for bad in ("bad\n    state = offline\n    np = 0\n",
                    "bad\n    state = down\n",
                    "bad\n    state = free\n    np = 0\n    properties = other\n"):
            with self.subTest(bad=bad):
                self.assertEqual([n["name"] for n in mkjob["read_pbs_nodes"](
                    bad + healthy, ["compute"])], ["healthy"])
        with self.assertRaises(ValueError):
            mkjob["read_pbs_nodes"](healthy.replace("np = 28", "np = 0"), ["compute"])

    def test_normal_plan_does_not_parse_running_jobs(self):
        resources = dict(cpu_limit=28, node_limit=1, nodes=[
            dict(name="a", total=28, states={"free"}, jobs="unrecognized")])
        self.assertEqual(BatchJob(["true"], queue="sample").plan(resources), (1, 28, 1, 1))
        with self.assertRaises(ValueError):
            BatchJob(["true"], queue="sample", opt=True).plan(resources)

    def test_resource_allocation(self):
        resources = dict(cpu_limit=112, node_limit=4, properties=[], walltime="01:00:00",
                         nodes=[dict(name=str(i), total=28, states={"free"},
                                     jobs=f"0-{27 - free}/job")
                                for i, free in enumerate([8, 8, 4, 0])])
        cases = [
            ({}, (4, 28, 1, 1)),
            (dict(mpi="auto"), (4, 28, 112, 1)),
            (dict(omp="auto"), (1, 28, 1, 28)),
            (dict(mpi="auto", omp=">=2,<=4"), (4, 28, 56, 2)),
            (dict(mpi="auto", opt=True), (2, 8, 16, 1)),
            (dict(mpi="auto", omp="=>3,=<4", opt=True), (2, 8, 4, 4)),
            (dict(mpi="auto", nodes=3, opt=True), (3, 4, 12, 1)),
            (dict(mpi=2, omp=4, opt=True), (1, 8, 2, 4)),
        ]
        for options, expected in cases:
            with self.subTest(options=options):
                job = BatchJob(["true"], queue="sample", **options)
                self.assertEqual(job.plan(resources), expected)
        for options in (dict(nodes=4, opt=True), dict(ppn=9, opt=True),
                        dict(mpi=8, omp=">=4", opt=True), dict(omp="bad")):
            with self.subTest(options=options), self.assertRaises(ValueError):
                BatchJob(["true"], queue="sample", **options).plan(resources)

    def test_interactive_workflow(self):
        query = Mock(side_effect=[QUEUE, NODES])
        with tempfile.TemporaryDirectory() as directory, patch.dict(
                BatchJob.read_resources.__globals__, query=query):
            job = BatchJob('printf "%s" "{queue}"', queue="sample", directory=directory,
                           mpi="auto", omp=2, opt=True)
            query.assert_not_called()
            resources = job.read_resources()
            self.assertEqual(query.call_args_list[0].args, ("qstat", "-Qf", "sample"))
            self.assertEqual(query.call_args_list[1].args, ("pbsnodes", "-a"))
            self.assertEqual([job.count_free_slots(n) for n in resources["nodes"]], [4, 6])
            allocation = job.plan(resources)
            self.assertEqual(allocation, (2, 4, 4, 2))
            script = job.render(resources)
            self.assertEqual(script, job.render(resources))
            self.assertEqual(job.command, ["/bin/bash", "-c", 'printf "%s" "{queue}"'])
            path = job.write(Path(directory) / "job.pbs", resources=resources)
            self.assertEqual(path.read_text(), script)
            with self.assertRaises(ValueError):
                job.write(path)
            self.assertEqual(path.read_text(), script)
            self.assertEqual(query.call_count, 2)

    def test_render_cannot_bypass_planning(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(
                BatchJob.read_resources.__globals__, query=Mock(side_effect=[QUEUE, NODES])):
            job = BatchJob(["true"], queue="sample", mpi="auto", omp=4)
            resources = job.read_resources()
            self.assertEqual(job.plan(resources), (2, 8, 4, 4))
            job.omp = "8"
            script = job.render(resources)
            self.assertIn("export OMP_NUM_THREADS=8", script)
            self.assertIn("mpirun -n 2 --map-by ppr:1:node:PE=8", script)
            path = Path(directory) / "invalid.pbs"
            for allocation in ((2, 28, 56, 1), (1, 4, 8, 1), (2, 8, 4, 4)):
                with self.assertRaises(TypeError):
                    job.render(resources, allocation=allocation)
                with self.assertRaises(TypeError):
                    job.write(path, resources=resources, allocation=allocation)
                self.assertFalse(path.exists())
            job.mpi = 3
            with self.assertRaises(ValueError):
                job.write(path, resources=resources)
            self.assertFalse(path.exists())

    def test_convenience_methods_refresh_defaults(self):
        later_queue = QUEUE.replace("01:00:00", "02:00:00")
        query = Mock(side_effect=[QUEUE, NODES, later_queue, NODES])
        with tempfile.TemporaryDirectory() as directory, patch.dict(
                BatchJob.read_resources.__globals__, query=query):
            job = BatchJob(["true"], queue="sample", directory=directory)
            self.assertIn("walltime=01:00:00", job.render())
            path = job.write(Path(directory) / "later.pbs")
            self.assertIn("walltime=02:00:00", path.read_text())
            self.assertIsNone(job.walltime)
            self.assertEqual(query.call_count, 4)

    def test_api_validation_and_instance_isolation(self):
        for options in (dict(nodes=0), dict(ppn=-1), dict(mpi="auto", omp="auto"),
                        dict(omp=2, nodes=2), dict(queue="bad\nqueue"), dict(directory="")):
            with self.subTest(options=options), self.assertRaises(ValueError):
                BatchJob(["true"], **dict({"queue": "sample"}, **options))
        args = ["printf", "%s", "unchanged"]
        one = BatchJob(args, queue="sample", mpi=4)
        two = BatchJob(args, queue="sample", omp=4)
        args.append("new")
        self.assertEqual(one.command, ["printf", "%s", "unchanged"])
        self.assertIsNone(one.nodes)
        self.assertEqual(two.nodes, 1)
        with self.assertRaises(TypeError):
            one.render(allocation=(1, 8, 4, 1))


if __name__ == "__main__":
    unittest.main()
