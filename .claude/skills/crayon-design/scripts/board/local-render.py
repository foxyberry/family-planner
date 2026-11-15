# Render boards locally: every /_blob/<id> in a board becomes a copy of <work>/blob/<id>.<ext>.
# Usage: python3 local-render.py [--work DIR] BOARD...   -> <work>/preview/r-<BOARD>.html
# Exits 1 and lists the ids when an asset is missing from blob/ (fetch them, then run again),
# unless --allow-missing is given (missing assets show as missing.svg).
import re, sys, os, shutil
sys.dont_write_bytecode = True   # no __pycache__ in the repo
from boardlib import work

args = sys.argv[1:]
allow = '--allow-missing' in args
if allow: args.remove('--allow-missing')
work(args)
if not args: sys.exit(__doc__ or 'usage: local-render.py [--work DIR] BOARD...')
absent = [f for f in args if not os.path.exists(f'canvas/project/{f}.dc.html')]
if absent: sys.exit(f'not in canvas/project (pull them from the artifact, or pass short ids): {absent}')
os.makedirs('preview/loc', exist_ok=True)
miss = set()


def find(i):
    for ext in ('svg', 'png', 'jpg', 'jpeg', 'webp'):
        if os.path.exists(f'blob/{i}.{ext}'): return f'blob/{i}.{ext}'
    return None


for f in args:
    s = open(f'canvas/project/{f}.dc.html').read()

    def sub(mm):
        i = mm.group(1); src = find(i)
        if not src: miss.add(i); return 'missing.svg'
        dst = 'loc/' + i + os.path.splitext(src)[1]
        if not os.path.exists('preview/' + dst): shutil.copy(src, 'preview/' + dst)
        return dst
    s = re.sub(r'/_blob/([0-9a-f]{32})', sub, s)
    for t in ['<script src="./support.js"></script>', '<x-dc>', '</x-dc>', '<helmet>', '</helmet>']: s = s.replace(t, '')
    open(f'preview/r-{f}.html', 'w').write(s)
print('ok', len(args), 'missing', sorted(miss))
if miss and not allow: sys.exit(1)
