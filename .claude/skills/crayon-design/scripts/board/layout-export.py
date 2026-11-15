# Export board geometry as layout JSON (board coordinates 1376 x 1032), the app's layout source.
# Usage: python3 layout-export.py [--work DIR] <out-dir> <version> [SHORT_IDS,comma,separated]
#   e.g. DESIGN_WORK=~/design-work python3 layout-export.py docs/superpowers/layout 50 G4,G1
# Renders each board (local-render.py), loads it in headless Chrome with extract.js, writes <out-dir>/<id>.json.
# Board ids, names and families come from boards.json. Text is kept only for plain labels: anything with a digit,
# longer than 32 characters, or matching a private word is dropped.
# Private words (real names, places) are read from $PRIVATE_TERMS or <work>/private-terms.txt, one per line,
# never from the repo. Without either file the export stops; PRIVATE_TERMS=none skips the word check on purpose.
import json, re, subprocess, sys, os, html, shutil
from pathlib import Path
sys.dont_write_bytecode = True   # no __pycache__ in the repo
from boardlib import work, boards, CHROME, HERE
_re = re
args = sys.argv[1:]
_pos = [a for i, a in enumerate(args) if a != '--work' and (i == 0 or args[i - 1] != '--work')]
OUT = os.path.abspath(_pos[0]) if _pos else None   # resolved against the caller's cwd, before work() changes it
WORK = work(args)
if len(args) < 2: sys.exit('usage: layout-export.py [--work DIR] <out-dir> <version> [SHORT_IDS]')
VERSION = args[1]
_tp = os.environ.get('PRIVATE_TERMS') or str(WORK / 'private-terms.txt')
if _tp == 'none': _terms = []
elif os.path.exists(_tp): _terms = [l.strip() for l in open(_tp, encoding='utf-8') if l.strip() and not l.startswith('#')]
else: sys.exit(f'layout-export: no private-terms file at {_tp} (set PRIVATE_TERMS=<file> or PRIVATE_TERMS=none)')
PRIVATE = re.compile('|'.join(re.escape(t) for t in _terms), re.I) if _terms else None
BOARDS = [(k, n, f) for k, (n, f) in boards().items()]
GLOBAL = {'width': 1376, 'height': 1032, 'statusBand': [0, 24], 'margin': 64, 'right': 1312, 'gutter': 24, 'column': 82,
          'columnLefts': [64 + 106 * n for n in range(12)], 'headerTop': 48, 'headerBottom': 128, 'headerBaseline': 107,
          'contentTop': 176, 'contentBottom': 968}
REGIONS = {
 'morning': {'header': (64, 1312, 'stretch'), 'strip': (64, 1312, 'stretch'), 'kids': (64, 418, 'left'), 'missions': (448, 1312, 'stretch'), 'bottom': (448, 1312, 'stretch')},
 'home': {'skySwitch': (40, 200, 'left'), 'clock': (0, 900, 'left'), 'panel': (928, 1336, 'stretch')},
 'grown': {'header': (40, 1336, 'stretch'), 'main': (40, 840, 'left'), 'side': (864, 1336, 'right'), 'action': (864, 1336, 'right')},
 'grown64': {'header': (64, 1312, 'stretch'), 'main': (64, 882, 'left'), 'side': (930, 1312, 'right'), 'action': (930, 1312, 'right')},
}
LINES = {
 'morning': {'kidsLeft': 64, 'kidTextLeft': 172, 'missionsLeft': 448, 'right': 1312, 'stripTop': 176, 'stripBottom': 516, 'kidsTop': 536, 'missionsTop': 548,
             'circleTop': 612, 'captionTop': 732, 'bottomControlTop': 872, 'baselines': {'header': 107, 'missionsName': 584, 'captions': 757}},
 'home': {'clockCentre': [448, 528], 'clockRadius': 372, 'clockArea': [0, 900], 'panelLeft': 928, 'panelTop': 96, 'right': 1336, 'mainButtonWidth': 408, 'mainButtonBottom': 968,
          'baselines': {'weekday': 132, 'kidAName': 187, 'kidALabel': 265, 'timeLeft72': 337, 'status': 374, 'nextLabel': 259, 'nextTitle': 300, 'nextAt': 338},
          'kidARow': {'pictureLeft': 928, 'picture': 96, 'pictureTop': 241, 'nextPicture': 104, 'nextPictureTop': 238, 'textLeft': 1040, 'nextTextLeft': 1048, 'gap': 16},
          'kidBRule': {'gapBelowKidA': 40, 'lowestNameBaseline': 584, 'note': 'Kid B block (name, now/next circles, captions) moves as one; its name box top = Kid A block last box bottom + 40, never lower than baseline 584'}},
 'grown': {'margin': 40, 'formLeft': 40, 'formRight': 840, 'labelLeft': 78, 'controlLeft': 192, 'rightEdge': 808, 'sideLeft': 864, 'sideWidth': 472, 'right': 1336, 'headerTop': 44, 'headerBottom': 124, 'formTop': 148, 'formBottom': 968},
 'grown64': {'note': 'superseded board (C1 -> G6, C6 -> G1), kept on the old 64 grid', 'formLeft': 64, 'formRight': 882, 'labelLeft': 104, 'controlLeft': 232, 'sideLeft': 930, 'right': 1312, 'formTop': 176, 'formBottom': 968},
}
def region(fam, e):
    x, y, w, h = e['x'], e['y'], e['w'], e['h']
    if fam == 'home':
        if x < 220 and y < 150 and e['w'] < 400 and e['kind'] != 'drawing': return 'skySwitch'
        return 'panel' if x >= 900 else 'clock'
    if y + h <= (136 if fam == 'grown' else 140): return 'header'
    if fam == 'morning':
        if 170 <= y and y + h <= 520: return 'strip'
        if y >= 860: return 'bottom'
        return 'kids' if x < 430 else 'missions'
    sx = 852 if fam == 'grown' else 900
    if y >= 860 and x >= sx: return 'action'
    return 'side' if x >= sx else 'main'
def align(fam, reg, e):
    lo, hi, anc = REGIONS[fam][reg]
    l, r = e['x'], e['x'] + e['w']
    if abs(l - lo) <= 2 and abs(r - hi) <= 2: a = 'fill'
    elif abs(l - lo) <= 2: a = 'start'
    elif abs(r - hi) <= 2: a = 'end'
    else: a = 'inside'
    return anc, a
UNIQUE = {'doneMedal','doneTitle','doneSubtitle','doneLabel','knob','knobCheck','back','title','leaveLabel','minutes','status','statusDot','ground','home','destination','homeLabel','destinationLabel','card','legend','name','leaveAt','slide','pill','skySwitch','clock','weekday','button','primary','time','kidALabel','kidAWay','kidAStatus'}
def slug(t): return _re.sub(r'[^a-z0-9]+', '-', (t or '').lower()).strip('-')[:24] or 'part'
def name_of(fam, reg, e, els):
    k, t, x, y, w, h = e['kind'], (e.get('text') or ''), e['x'], e['y'], e['w'], e['h']
    if k == 'back': return 'back'
    if k == 'title': return 'title'
    if fam in ('morning', 'home') and reg == 'header' or (fam == 'morning' and reg == 'header'):
        if t.startswith('Leave in') or t in ('Leave in',): return 'leaveLabel'
        if _re.fullmatch(r'\d+ ?min', t): return 'minutes'
        if k == 'text': return 'status'
        if k == 'picture': return 'statusDot'
    if fam == 'morning':
        if reg == 'strip':
            if k == 'picture' and w >= 1200: return 'ground'
            if k == 'picture' and w == 150: return 'home'
            if k == 'picture' and w == 120: return 'destination'
            if k == 'text' and t in ('Our stop', 'Home'): return 'homeLabel'
            if k == 'text' and y >= 440: return 'destinationLabel'
            if k in ('mover', 'bubble', 'card'): return k
            if k == 'text' and t == 'my bus' and y < 230: return 'legend'
            return k
        if reg == 'kids':
            if k == 'picture' and w == 354: return 'band'
            return {'row': 'row', 'ring': 'ring', 'text': 'rowText'}.get(k, k)
        if reg == 'missions':
            if k == 'picture' and w >= 180: return 'doneMedal'
            if k == 'text' and e.get('font') == 96: return 'doneTitle'
            if k == 'text' and e.get('font') == 30 and y > 600: return 'doneSubtitle'
            if k == 'circle': return 'circle'
            if k == 'text' and y >= 725: return 'caption'
            if k == 'text' and e.get('font') == 36: return 'name'
            if k == 'text': return 'leaveAt'
            return k
        if reg == 'bottom':
            if k == 'text': return 'doneLabel'
            if k == 'mover' or (k == 'picture' and w >= 56): return 'knob'
            if k == 'picture': return 'knobCheck'
            return k
    if fam == 'home':
        if reg == 'skySwitch': return 'skySwitch'
        if reg == 'clock':
            if k == 'drawing': return 'clock'
            if k == 'picture' and w >= 800: return 'clockArt'
            return 'slotPicture' if k == 'picture' else k
        if reg == 'panel':
            if k == 'primary': return 'button'
            if k == 'text':
                f = e.get('font')
                if f == 96: return 'time'
                if t in ('now', 'next'): return t + 'Caption'
                if t in ('Leave in', 'Bed in', 'Next', 'in') or t.endswith(' in'): return 'kidALabel'
                if t in ('On time',) or 'Holiday' in t: return 'kidAStatus'
                if f == 36 and y < 140: return 'weekday'
                if f == 36: return 'kidName'
                return 'text'
            if k == 'picture':
                if w == 48: return 'kidRing'
                if w in (40, 41): return 'kidFace'
                if w == 80: return 'kidAWay'
                if w == 160: return 'nowCircle'
                return 'picture'
    if fam in ('grown', 'grown64'):
        if reg == 'header' and k == 'text': return 'note'
        if reg == 'main' and k == 'label': return 'label.' + slug(t)
        if reg == 'main':
            for l in els:
                if l['kind'] == 'label' and l['y'] <= y < l['y'] + max(l['h'], 72) and l is not e:
                    return 'row.' + slug(l.get('text')) + '.' + k
            return k
        if reg == 'side': return {'text': 'line', 'picture': 'picture'}.get(k, k)
        if reg == 'action': return 'primary' if k == 'primary' else k
    return k
os.makedirs(OUT, exist_ok=True)
ONLY = set(args[2].split(',')) if len(args) > 2 else None
if ONLY:
    unknown = ONLY - {b[0] for b in BOARDS}
    if unknown: sys.exit(f'unknown short ids {sorted(unknown)} (add them to boards.json)')
    BOARDS = [b for b in BOARDS if b[0] in ONLY]
subprocess.run([sys.executable, str(HERE / 'local-render.py'), '--work', str(WORK)] + [b for _, b, _ in BOARDS], check=True)
shutil.copy(HERE / 'extract.js', 'preview/extract.js')
summary = []
for bid, name, fam in BOARDS:
    src = open(f'preview/r-{name}.html').read().replace('</body>', '<script src="extract.js"></script></body>')
    open(f'preview/x-{name}.html', 'w').write(src)
    dom = subprocess.run([CHROME, '--headless', '--disable-gpu', '--window-size=1376,1032', '--virtual-time-budget=6000', '--dump-dom', Path(f'preview/x-{name}.html').resolve().as_uri()], capture_output=True, text=True).stdout
    m = re.search(r'data-x="([^"]*)"', dom)
    if not m: sys.exit(f'{bid}: no data-x in the dumped DOM (is $CHROME right? does the board load?)')
    els = json.loads(html.unescape(m.group(1)))
    els.sort(key=lambda e: (e['y'], e['x']))
    names = [(e, region(fam, e)) for e in els]
    keys = [f"{reg}.{name_of(fam, reg, e, els)}" for e, reg in names]
    total = {k: keys.count(k) for k in keys}
    counts, items = {}, []
    for (e, reg), k in zip(names, keys):
        counts[k] = counts.get(k, 0) + 1
        anc, al = align(fam, reg, e)
        it = {'id': k if total[k] == 1 else f"{k}.{counts[k]}", 'kind': e['kind'], 'x': e['x'], 'y': e['y'], 'w': e['w'], 'h': e['h'], 'region': reg, 'anchor': anc, 'align': al}
        if 'base' in e: it['baseline'] = e['base']; it['font'] = e['font']
        if e.get('text'): it['text'] = e['text']
        if reg == 'strip': it['stripLocal'] = {'x': e['x'] - 64, 'y': e['y'] - 176}
        items.append(it)
    doc = {'version': VERSION, 'board': bid, 'family': fam, 'unit': 'pt at 1376 x 1032 (board = full screen; y 0 = top of the glass)',
           'global': (dict(GLOBAL, margin=40, right=1336, columnLefts=[40 + 112 * n for n in range(12)], column=88, headerTop=44, headerBottom=124, headerBaseline=103, contentTop=148) if fam == 'grown' else dict(GLOBAL, margin=40, right=1336, columnLefts=[40 + 112 * n for n in range(12)], column=88) if fam == 'home' else GLOBAL), 'lines': LINES[fam], 'regions': {k: {'left': v[0], 'right': v[1], 'anchor': v[2]} for k, v in REGIONS[fam].items()},
           'elements': items}
    if fam == 'home':
        import copy
        doc['lines'] = copy.deepcopy(doc['lines'])
        kb = [it for it in items if it['region'] == 'panel' and it['kind'] == 'text' and it.get('font') == 36 and it['y'] > 300 and it['x'] == 928]
        nc = [it for it in items if it['id'].startswith('panel.nowCircle')]
        cap = [it for it in items if it['id'].startswith('panel.nowCaption')]
        if kb: doc['lines']['baselines']['kidBName'] = kb[0]['baseline']
        if nc: doc['lines']['nowNextBottom'] = nc[0]['y'] + nc[0]['h']
        if cap: doc['lines']['baselines']['nowNextCaptions'] = cap[0]['baseline']
    if fam in ('grown', 'grown64'):
        cards = list(re.finditer(r'<div class="(?:bg-cardform|card-form|bg-card[ab])"[^>]*left:\s*(\d+)px;\s*top:\s*(\d+)px;\s*width:\s*(\d+)px;\s*height:\s*(\d+)px', src))
        if not cards: cards = list(re.finditer(r'<div style="position: ?absolute; ?left: ?(\d+)px; ?top: ?(\d+)px; ?width: ?(8\d\d)px; ?height: ?(\d+)px; ?background: ?url\([^)]*card-8\d\dx', src))
        for n, cm in enumerate(cards, 1):
            x, y, w, h = map(int, cm.groups())
            doc['elements'].insert(0, {'id': 'main.card' if n == 1 else f'main.card.{n}', 'kind': 'card', 'part': 'PaperCard', 'x': x, 'y': y, 'w': w, 'h': h, 'region': 'main', 'anchor': 'left', 'align': 'inside'})
    if bid in ('G1', 'G1c', 'G1d', 'G1e', 'G1f', 'G1g'):
        doc['lines'] = dict(doc['lines'], clockCentre=[410, 549], clockLabelsLeft=30, note='v32: the clock (moved 66 left in v31, hour labels from x 30 like home) moved up 23 to sit centred in 148-968')
    for it in doc['elements']:
        if bid == 'S1' and it['kind'] == 'back' and it['region'] == 'main':
            it['id'] = 'main.removeKid.' + str(sum(1 for o in doc['elements'] if o['id'].startswith('main.removeKid')) + 1); it['kind'] = 'button'
        if bid == 'C4' and it['kind'] == 'back' and it['region'] == 'main':
            it['id'] = 'main.pageEarlier' if it['x'] < 208 else 'main.pageLater'; it['kind'] = 'button'
        t = it.get('text')
        if t is not None and (_re.search(r'\d', t) or (PRIVATE and PRIVATE.search(t)) or len(t) > 32): it.pop('text')
    open(f'{OUT}/{bid}.json', 'w').write(json.dumps(doc, indent=1, ensure_ascii=False))
    summary.append((bid, len(items)))
print(summary)
