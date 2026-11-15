# Shared helpers for the board scripts: work folder, Chrome, board registry.
# The work folder holds canvas/project (boards + canvas.json), blob (assets by id), deps (roughjs), preview (output).
import json, os, sys, subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHROME = os.environ.get('CHROME', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
W, H = 1376, 1032


def work(args):
    """Pop '--work DIR' from args, else use $DESIGN_WORK. chdir into it and return its Path."""
    w = None
    if '--work' in args:
        i = args.index('--work'); w = args[i + 1]; del args[i:i + 2]
    w = w or os.environ.get('DESIGN_WORK')
    if not w: sys.exit('set DESIGN_WORK=<work folder> or pass --work DIR')
    p = Path(w).expanduser().resolve()
    if not (p / 'canvas' / 'project').is_dir(): sys.exit(f'{p}/canvas/project not found (see README: setup)')
    os.chdir(p); (p / 'preview').mkdir(exist_ok=True)
    return p


def registry():
    return json.load(open(HERE / 'boards.json'))


def boards():
    """short id -> (board name, family)"""
    return {k: tuple(v) for k, v in registry()['boards'].items()}


def shot(html, png, scale=2):
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', f'--force-device-scale-factor={scale}',
                    f'--window-size={W},{H}', f'--screenshot={Path(png).resolve()}', Path(html).resolve().as_uri()],
                   capture_output=True, check=True)
