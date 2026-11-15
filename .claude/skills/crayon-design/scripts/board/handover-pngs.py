# Handover board PNGs (@2x) for the boards listed under "handover" in boards.json (or only the names given).
# Usage: python3 handover-pngs.py [--work DIR] <boards-out-dir> [PNG_NAME...]   -> <dir>/<PNG_NAME>@2x.png
import subprocess, sys, os
sys.dont_write_bytecode = True   # no __pycache__ in the repo
from boardlib import work, registry, shot, HERE
args = sys.argv[1:]
_pos = [a for i, a in enumerate(args) if a != '--work' and (i == 0 or args[i - 1] != '--work')]
if not _pos: sys.exit('usage: handover-pngs.py [--work DIR] <boards-out-dir> [PNG_NAME...]')
HB = os.path.abspath(_pos[0])   # resolved against the caller's cwd, before work() changes it
WORK = work(args)
M = registry()['handover']
if len(args) > 1:
    bad = [k for k in args[1:] if k not in M]
    if bad: sys.exit(f'not in boards.json "handover": {bad}')
    M = {k: M[k] for k in args[1:]}
os.makedirs(HB, exist_ok=True)
subprocess.run([sys.executable, str(HERE / 'local-render.py'), '--work', str(WORK)] + sorted(set(M.values())), check=True)
for k, v in M.items(): shot(f'preview/r-{v}.html', f'{HB}/{k}@2x.png')
print('pngs', len(M), HB)
