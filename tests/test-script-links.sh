#!/bin/bash
set -eu
repo=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/script-links.XXXXXX")
trap 'rm -rf -- "$fixture"' EXIT

for link in "$repo"/bin/*; do
    [ -L "$link" ] && [ -f "$link" ]
    case $(readlink "$link") in ../scripts/*) ;; *) exit 1 ;; esac
done
printf 'PASS: command links are relative and resolve to existing sources\n'

# Move a minimal checkout to a different location, including spaces.
checkout="$fixture/checkout with spaces"
mkdir -p "$checkout/bin" "$checkout/scripts" "$fixture/elsewhere"
cp -R "$repo/scripts/batch" "$repo/scripts/tex" "$checkout/scripts/"
ln -s ../scripts/batch/mkjob "$checkout/bin/mkjob"
ln -s ../scripts/tex/processbib "$checkout/bin/processbib"
export CHECKOUT="$checkout" PYTHONDONTWRITEBYTECODE=1
cd "$fixture/elsewhere"
"$checkout/bin/mkjob" --help > "$fixture/help"
WORK_HOST=gw python3 - <<'PY'
import os
from pathlib import Path
from runpy import run_path

root = Path(os.environ['CHECKOUT']).resolve()
module = run_path(str(root / 'bin/mkjob'))
assert module['QUEUE_FILE'] == root / 'scripts/batch/queues.csv'
job = module['BatchJob'](['hostname'], queue='mini', mpi='auto', omp='>=2,<=4')
resources = dict(cpu_limit=28, node_limit=1, properties=[], walltime='00:10:00',
                 nodes=[dict(name='node', total=56, states={'free'}, jobs='')])
assert job.plan(resources) == (1, 28, 14, 2)
assert '#PBS -l nodes=1:ppn=28' in job.render(resources)
PY
printf 'PASS: relocated mkjob loads the public queue table and adjacent template through bin\n'

# Stub only the optional dependency; this checks sibling imports, not BibTeX processing.
mkdir -p "$fixture/dependencies/bibtexparser"
printf 'def loads(*args): pass\ndef dumps(*args): pass\n' > "$fixture/dependencies/bibtexparser/__init__.py"
printf 'class BibTexWriter: pass\n' > "$fixture/dependencies/bibtexparser/bwriter.py"
PYTHONPATH="$fixture/dependencies" "$checkout/bin/processbib" --help > "$fixture/bib-help"
grep -q 'usage:' "$fixture/bib-help"
printf 'PASS: processbib imports sibling modules through its command link\n'
