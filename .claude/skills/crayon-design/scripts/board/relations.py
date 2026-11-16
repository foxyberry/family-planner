# Relations check: alignment between parts on the grown-up boards (no spec rule covers these yet).
# Usage: python3 relations.py [--work DIR] [--cached] [--line box|drawn] [--quiet] [--sizes] [SHORT_IDS,comma,separated]
#   e.g. DESIGN_WORK=~/design-work python3 relations.py S1,C3      (no ids = every grown-up board)
# Renders each board (local-render.py), loads it in headless Chrome with relations.js, and measures every part
# box, its kind, the ink box of its art, then checks, in board units at 13":
#   (rules: spec "Layout model", "Layout balance" and "Grown-up form layout")
#   1 line    each row's first control: its frame (box x) on the line (--line drawn: box x + the app's inset);
#             named exceptions (F4 indent, F1/F2/F4 caption columns) are listed, not failed
#   2 col2    second column: one label line and one control line per card, its controls end on 808,
#             label line = control line - (longest second-column label + 10)
#   3 height  one height per row for controls of the same kind; other kinds centred on the row; header tabs 72
#   4 right   stretching controls (fields, search, value areas, side rows, main button) end drawn on 802 / 1330 /
#             the small card's content edge; choices next to a label may end short and are not checked
#   5 label   each label's glyph centred on its control's drawn box
#   6 balance card padding by kind, card gap 40, row gap (spec "Layout balance")
# Rulings (2026-11-15): frames sit on the lines; every part draws its outline 6 inside its frame; extra touch area
# is outside the frame and invisible; pick rings are an outward overlay. So the default is --line box (frames);
# --line drawn checks the drawn outlines instead. --sizes prints an inventory of every control / picture size instead
# of the checks. Exits 1 when any checked delta is over 1 pt (2 when a board cannot be measured). Text from the boards is masked with the private-terms file.
import json, re, subprocess, sys, os, html, shutil
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
sys.dont_write_bytecode = True
from boardlib import work, boards, CHROME, HERE

args = sys.argv[1:]
WORK = work(args)
CACHED = '--cached' in args
QUIET = '--quiet' in args
LINE_MODE = 'box'
SIZES = '--sizes' in args
if '--line' in args: i = args.index('--line'); LINE_MODE = args[i + 1]; del args[i:i + 2]
args = [a for a in args if a not in ('--cached', '--quiet', '--sizes')]
if LINE_MODE not in ('box', 'drawn'): sys.exit('--line box|drawn')
ONLY = set(args[0].split(',')) if args else None
TOL = 1.0

# Boards: every grown / grown64 row of boards.json (C3k included), plus the F1-F4 ConfirmCard boards, which are
# not exported as layout JSON. Kept here so layout-export does not pick them up.
EXTRA = {'F1': ('CardF1', 'grown'), 'F2': ('CardF2', 'grown'),
         'F3': ('CardF3', 'grown'), 'F4': ('CardF4', 'grown')}
BOARDS = {k: v for k, v in boards().items() if v[1] in ('grown', 'grown64')}
BOARDS.update(EXTRA)
if ONLY:
    bad = ONLY - set(BOARDS)
    if bad: sys.exit(f'unknown short ids {sorted(bad)}')
    BOARDS = {k: v for k, v in BOARDS.items() if k in ONLY}

_tp = os.environ.get('PRIVATE_TERMS') or next((str(p) for p in (WORK / 'private-terms.txt', WORK / 'tools' / 'private-terms.txt') if p.exists()), '')
TERMS = [l.strip() for l in open(_tp, encoding='utf-8') if l.strip() and not l.startswith('#')] if _tp and _tp != 'none' and os.path.exists(_tp) else []
_PRIV = re.compile('|'.join(re.escape(t) for t in TERMS), re.I) if TERMS else None
def mask(t):
    t = (t or '').strip()
    if _PRIV: t = _PRIV.sub(lambda m: 'Kid', t)
    return t[:22]

# ---- kinds -------------------------------------------------------------------------------------------------
# From the markup classes the tools use (extract.js: btn-round, btn-ink, field, tab-, day-, slot) and, for parts
# drawn with inline art and no class, the art's blob id (first 6 hex). Ids marked # guessed were mapped by their
# art size and where they sit, not by a class.
ART = {'55a93d': 'round', '4df81f': 'ink', '550529': 'ink', '871a26': 'field', '486ce5': 'field', 'eed9b4': 'field',
       'b9aa6f': 'field', '124b73': 'field', '04613c': 'field', '6b8910': 'field', '82e01f': 'time',
       '7df5f3': 'time', '33ffe5': 'time',                      # 9-slice time fields, G1 slice card  # guessed
       '0f21df': 'tab', 'c1a235': 'tab', '5e7f79': 'tab', 'c2ecdc': 'tab', '5d3932': 'tab', '6a4bd6': 'tab',  # List / Settings 9-slice art # guessed
       '87be14': 'daychip', 'b84cc7': 'daychip', '350d83': 'datechip', '70068d': 'datechip', '5b6129': 'picture',
       'ea501b': 'field',                                          # C2 / C2c / S3 stop search field 400 x 80 # guessed
       '542e7d': 'tab', 'fe94b4': 'tab', '7df88b': 'tab', 'c47ce0': 'tab', 'd08366': 'tab',   # G6-G8 header tabs # guessed
       '0dc75e': 'tab', 'a79b64': 'tab', 'a3a130': 'tab', '919a3d': 'tab',   # G5 / G7 "from when" choices # guessed
       'ef6dd3': 'field',                                          # G1f slice card Name 424 x 72 # guessed
       '9f9a2e': 'row', 'a9dd04': 'row', 'a22580': 'row', 'ec1a02': 'row', '719d40': 'daybutton'}  # guessed: 719d40
CLASS = [(r'btn-round|bg-btnround', 'round'), (r'btn-ink|bg-btnink', 'ink'), (r'field-time|bg-ftime', 'time'),
         (r'\bfield\b|bg-field|bg-f\d+|bg-foc|bg-ffocus', 'field'), (r'tab-on|tab-off|bg-tab', 'tab'),
         (r'day-on|day-off|bg-day', 'daychip'), (r'date-on|date-off', 'datechip'), (r'\bslot\b|bg-slot', 'picture'),
         (r'rowsel|row-today|bg-today|bg-rowsel', 'row'), (r'pill', 'tab')]
# Drawn inset (left, top, right, bottom) of each kind relative to its board box, as the app draws it
# (ios/DesignSystem): partBackground / CrayonField / ListRow pad CrayonStyle.artInset = 6 on every side.
#   swatch: ColourSwatch draws the 56 circle at its full size (inset 0) inside a 72 frame (touch padding 8);
#   face:   SetupView draws the 64 disc at full size (inset 0), no touch padding;
#   tile:   IconPicker tiles draw at full size (0);
#   switch: CrayonSwitch track 92 x 28 in 96 x 52, offset 2 (2, 12, 2, 12);
#   link / text: what is drawn is the glyph (0 from the box; the glyph box is reported separately).
SIX = (6, 6, 6, 6)
INSET = {'field': SIX, 'time': SIX, 'tab': SIX, 'daychip': SIX, 'datechip': SIX, 'round': SIX, 'ink': SIX,
         'picture': SIX, 'row': SIX, 'daybutton': SIX, 'card': SIX, 'swatch': (0, 0, 0, 0), 'face': (0, 0, 0, 0),
         'tile': (0, 0, 0, 0), 'switch': (2, 12, 2, 12), 'link': (0, 0, 0, 0), 'dot': (0, 0, 0, 0), 'part': SIX,
         'title': (0, 0, 0, 0), 'label': (0, 0, 0, 0)}
# Part floors (spec "Sizing formulas"): scaled drawn-box height of a control whose board height is h.
def scaled_h(kind, h, s):
    f = {'field': 64, 'time': 64, 'tab': 56, 'daychip': 56, 'daybutton': 56, 'round': 56, 'swatch': 48, 'face': 56,
         'picture': 72, 'tile': 72, 'switch': 48, 'datechip': 72}.get(kind)
    if kind == 'ink': f = {96: 72, 80: 64, 72: 56}.get(round(h), 56)
    if kind == 'row': return h                         # two-line rows 72 fixed, one-line 48 fixed
    if kind == 'datechip': return h * max(96 * s, 72) / 96 if h > 90 else h   # compact G1c chips: fixed (app)
    if kind == 'link' or f is None: return h * s
    return max(h * s, f)

def scaled_drawn(e, s):
    """Drawn height at scale s: the floor applies to the frame (board box), the outline sits inside it."""
    H = scaled_h(e['kind'], e['h'], s)
    if e.get('reg') == 'header' and e['kind'] == 'tab': H = e['h']   # spec 2026-11-15: header text controls 72 fixed
    if e['kind'] == 'switch': return H * 28 / 52
    _, t, _, b = INSET.get(e['kind'], SIX)
    return H - t - b

def kind_of(o):
    cls, role, w, h = o['cls'], o['role'], o['w'], o['h']
    if o['cat'] == 'card': return 'card'
    if role == 'switch': return 'switch'
    art = (o.get('bi') or o.get('bg') or '')
    aid = re.search(r'([0-9a-f]{32})', art); aid = aid.group(1)[:6] if aid else ''
    k = next((k for rx, k in CLASS if re.search(rx, cls)), None) or ART.get(aid)
    if k == 'daychip' and w < 40: return 'dot'
    if k == 'tab' and abs(w - 96) < 2 and abs(h - 52) < 2: return 'switch'   # G4: a switch drawn with tab art
    if not k and art and (aid == '' or 'missing' in art):              # art not local (C6): guess by size
        if 70 <= h <= 74: return 'tab'
        if 78 <= h <= 82 and w >= 300: return 'field'                       # step dots in the S-step headers
    if not k and o['tag'] == 'span' and 'colour' in (o['parentAria'] or '').lower(): return 'swatch'
    if not k and o['tag'] == 'span' and o['parentRole'] == 'radiogroup' and abs(w - 56) < 1: return 'swatch'
    if k == 'picture' and 'face' in (o['parentAria'] or '').lower(): return 'face'
    if not k and not art: return 'link'
    return k or 'part'

def dump(bid, name):
    cache = Path(f'preview/rel-{name}.json')
    if CACHED and cache.exists(): return json.loads(cache.read_text())
    src = open(f'preview/r-{name}.html').read().replace('</body>', '<script src="relations.js"></script></body>')
    Path(f'preview/q-{name}.html').write_text(src)
    dom = subprocess.run([CHROME, '--headless', '--disable-gpu', '--allow-file-access-from-files', '--window-size=1376,1032',
                          '--virtual-time-budget=8000', '--dump-dom', Path(f'preview/q-{name}.html').resolve().as_uri()],
                         capture_output=True, text=True).stdout
    m = re.search(r'data-rel="([^"]*)"', dom)
    if not m: return None
    els = json.loads(html.unescape(m.group(1)))
    cache.write_text(json.dumps(els))
    return els

# ---- geometry helpers --------------------------------------------------------------------------------------
def drawn(e):
    l, t, r, b = INSET.get(e['kind'], SIX)
    return e['x'] + l, e['y'] + t, e['x'] + e['w'] - r, e['y'] + e['h'] - b
# Board box -> frame. Most board parts are drawn as their frame (art inside the box). The S1 swatch is drawn as
# the 56 circle itself, so its frame is that box grown by the one part inset (6) on every side (spec Layout model).
FRAME_OUT = {'swatch': 6}
def frame(e):
    o = FRAME_OUT.get(e['kind'], 0)
    return e['x'] - o, e['y'] - o, e['x'] + e['w'] + o, e['y'] + e['h'] + o
def art(e):
    i = e.get('ink')
    if not i or 'err' in i: return None
    return e['x'] + i['l'], e['y'] + i['t'], e['x'] + e['w'] - i['r'], e['y'] + e['h'] - i['b']
def f(v): return ('%+.1f' % v).replace('.0', '') if isinstance(v, float) and v != int(v) else '%+d' % round(v)
def n(v): return ('%.1f' % v).rstrip('0').rstrip('.')

def region_of(e, cards):
    if e.get('anc'):
        return next(c for c in cards if c['cardNo'] == e['anc'])
    cx, cy = e['x'] + e['w'] / 2, e['y'] + e['h'] / 2
    if e['inHeader'] or e['y'] + e['h'] <= 136: return 'header'
    inside = [c for c in cards if not c['kids'] and c['idx'] < e['idx'] and c['x'] <= cx <= c['x'] + c['w'] and c['y'] <= cy <= c['y'] + c['h']]
    if inside: return max(inside, key=lambda c: c['idx'])            # the last card drawn before it
    return 'side' if e['x'] >= 852 else 'main'

def bands(items):
    """Group items into row bands: y ranges that overlap by at least half the smaller height."""
    items = sorted(items, key=lambda e: e['y'])
    out = []
    for e in items:
        for b in out:
            if any(min(e['y'] + e['h'], o['y'] + o['h']) - max(e['y'], o['y']) >= 0.5 * min(e['h'], o['h']) for o in b):
                b.append(e); break
        else: out.append([e])
    return out

def lines_for(reg, fam, bid):
    """(label line, control line, inner right) for a region."""
    if reg == 'header': return (None, 40, 1336) if fam == 'grown' else (None, 64, 1312)
    if reg == 'side': return (None, 864, 1336) if fam == 'grown' else (None, 930, 1312)
    if reg == 'main': return (78, 192, 808) if fam == 'grown' else (104, 232, 860)
    c = reg
    if c['w'] >= 700:                                                 # form card
        return c['x'] + 38, c['x'] + 152, c['x'] + c['w'] - 32     # spec: label 78, control 192, right edge 808
    pl = c['bw'][3] + c['pad'][3]; pr = c['bw'][1] + c['pad'][1]
    if not c['kids']: pl = pr = 24
    return c['x'] + pl, c['x'] + pl, c['x'] + c['w'] - pr          # small card: its content edge

# Deliberate exceptions to the control line, named in the output so they do not fail.
#   indent:  F4 "At a set time" sub-options sit under their radio choice, 56 in (radio 40 + gap 16).
#   caption: F1 / F2 / F4 picture choices are 88 circles centred in a 96 caption column (4 in).
def exception(bid, reg, e, delta):
    if isinstance(reg, str) or reg['w'] >= 700: return None
    if bid == 'F4' and round(delta) in (56, 60): return 'indented sub-option' + (' + caption column' if round(delta) == 60 else '')
    if bid in ('F1', 'F2', 'F4') and e['kind'] == 'picture' and round(delta) == 4: return 'picture centred in its caption column'
    return None

def rname(reg):
    if isinstance(reg, str): return reg
    return ('card' if reg['w'] >= 700 else 'small card') + f" @{n(reg['x'])},{n(reg['y'])} {n(reg['w'])}x{n(reg['h'])}"

CONTROLS = {'field', 'time', 'tab', 'daychip', 'datechip', 'round', 'ink', 'picture', 'row', 'daybutton', 'swatch', 'face', 'tile', 'switch', 'part'}

def check(bid, name, fam, els):
    rows, flags = [], []
    def out(chk, where, what, val, delta=None, fail=True):
        bad = delta is not None and abs(delta) > TOL and fail
        rows.append((chk, where, what, val, '' if delta is None else f(delta), '!!' if bad else ''))
        if bad: flags.append(chk)
    for e in els: e['kind'] = kind_of(e) if e['cat'] in ('part', 'card') else e['cat']
    cards = [e for e in els if e['cat'] == 'card']
    parts = [e for e in els if e['cat'] in ('part', 'label', 'title')]
    for e in parts: e['reg'] = region_of(e, cards)
    for e in parts:   # a round button sitting on a card's corner (S1 remove-kid): a badge, not a row control
        if e['kind'] == 'round' and any(e['x'] < c['x'] + c['w'] < e['x'] + e['w'] and e['y'] < c['y'] + 40 and e['y'] + e['h'] > c['y'] for c in cards):
            e['kind'] = 'badge'
            out('0 badge', rname(e['reg']), 'round ' + mask(e.get('aria')), f"box {n(e['x'])},{n(e['y'])} {n(e['w'])} centre {n(e['x'] + e['w'] / 2)},{n(e['y'] + e['h'] / 2)}")
        if e.get('ring'):
            r = e['ring']
            out('0 ring', rname(e['reg']), f"{e['kind']} {mask(e.get('aria') or e.get('text'))}", f"part {n(e['w'])}x{n(e['h'])} ring {n(r['w'])} at {f(r['x'] - e['x'])},{f(r['y'] - e['y'])} (outset {n((r['w'] - e['w']) / 2)})")
    texts = [e for e in els if e['cat'] in ('text', 'picture')]
    for e in texts:
        e['reg'] = region_of(e, cards)
        if e.get('glyph') and e['glyph']['w'] > 0: e['gx'], e['gy'], e['gh'] = e['glyph']['x'], e['glyph']['y'], e['glyph']['h']
        else: e['gx'], e['gy'], e['gh'] = e['x'], e['y'], e['h']
    def after_text(c):
        return next((t for t in texts if t['reg'] is c['reg'] and t['gx'] + 4 < c['x'] and
                     min(t['gy'] + t['gh'], c['y'] + c['h']) - max(t['gy'], c['y']) >= 0.5 * min(t['gh'], c['h'])), None)
    regs = []
    for e in parts:
        if not any(e['reg'] is r for r in regs): regs.append(e['reg'])
    for reg in regs:
        mem = [e for e in parts if e['reg'] is reg and (e['kind'] in CONTROLS or e['kind'] in ('label', 'title', 'link'))]
        if not mem: continue
        L, C, RIGHT = lines_for(reg, fam, bid)
        where = rname(reg)
        col2 = []
        for b in bands(mem):
            b.sort(key=lambda e: e['x'])
            ctr = [e for e in b if e['kind'] in CONTROLS]
            labels = [e for e in b if e['kind'] == 'label']
            y0 = min(e['y'] for e in b)
            tag = f"{where} y{n(y0)}"
            first = ctr[0] if ctr else None
            col2_row = any(lb['x'] > C + 1 for lb in labels)
            ex = lambda e: drawn(e) if LINE_MODE == 'drawn' else frame(e)
            # 1. control line: the row's first control's frame (or drawn edge) on the line
            free_main = reg == 'main' and not any(c['w'] >= 700 for c in cards)   # G1-style boards: main is the clock
            lead = after_text(first) if first is not None and not labels else None
            if lead is not None and reg != 'header':
                out('1 line', tag, f"{first['kind']} {mask(first.get('text') or first.get('aria'))}", f"box {n(first['x'])} after {lead['cat']} '{mask(lead.get('own') or lead.get('text'))}' at {n(lead['gx'])} (not on a line, not checked)")
            elif first is not None and not free_main:
                line = C if (reg == 'header' or L is None or first['x'] >= (L + C) / 2) else L
                d = ex(first)[0] - line; a = art(first)
                why = exception(bid, reg, first, frame(first)[0] - line)
                out('1 line', tag, f"{first['kind']} {mask(first.get('text') or first.get('aria'))}",
                    (f"frame {n(frame(first)[0])} " if frame(first)[0] != first['x'] else '') + f"box {n(first['x'])} drawn {n(drawn(first)[0])}" + (f" art {n(a[0])}" if a else '') + f" line {n(line)}" + (f" (exception: {why})" if why else ''), d, fail=not why)
            # 2. second columns: labels right of the control line and the controls after them (checked per card below)
            if col2_row:
                for lb in labels:
                    if lb['x'] > C + 1:
                        nxt = [e for e in ctr if e['x'] >= lb['x']]
                        col2.append((lb, nxt[0] if nxt else None, max(nxt, key=lambda e: e['x'] + e['w']) if nxt else None, y0))
            # 3. one height per row for the same kind; other kinds centred on the row; header text controls 72
            if ctr:
                desc = ' '.join(f"{e['kind']}{'(' + mask(e.get('text') or e.get('aria'))[:10] + ')' if reg == 'header' else ''}:{n(e['h'])}@{n(e['y'])}" for e in ctr)
                bykind = {}
                for e in ctr: bykind.setdefault(e['kind'], []).append(e)
                for k, es in bykind.items():
                    hs = sorted({round(e['h'], 1) for e in es})
                    if len(hs) > 1: out('3 height', tag, f'{k}: one height', desc, hs[-1] - hs[0])
                if len(bykind) > 1:
                    cs = sorted({round(e['y'] + e['h'] / 2, 1) for e in ctr})
                    out('3 centred', tag, 'kinds centred on the row', desc + f" centres {'/'.join(n(c) for c in cs)}", cs[-1] - cs[0])
                if reg == 'header':
                    for e in ctr:
                        if e['kind'] == 'tab': out('3 header', tag, f"tab {mask(e.get('text'))[:12]} 72 fixed", f"h {n(e['h'])}", e['h'] - 72)
                    if not QUIET: out('3 header', tag, 'header row', desc + ''.join(' | title box %s font %s' % (n(t['h']), n(t['font'])) for t in b if t['kind'] == 'title'))
            # 4. right edge: stretching controls (fields, search, value areas, side rows, main button) end on the right line
            if ctr and not free_main and reg != 'header':
                last = max(ctr, key=lambda e: e['x'] + e['w'])
                stretch = last['kind'] in ('field', 'row', 'daybutton') or (last['kind'] == 'ink' and last['w'] >= 300) or col2_row
                if stretch:
                    a = art(last)
                    out('4 right', tag, f"{last['kind']} {mask(last.get('text') or last.get('aria'))}",
                        f"box {n(last['x'] + last['w'])} drawn {n(drawn(last)[2])}" + (f" art {n(a[2])}" if a else '') + f" right line {n(RIGHT if LINE_MODE == 'box' else RIGHT - 6)}",
                        drawn(last)[2] - (RIGHT - 6))                  # drawn edges line up (parts without the inset too)
            # 5. label centred on its control's drawn box
            for lb in labels:
                nxt = [e for e in ctr if e['x'] > lb['x']]
                if not nxt: continue
                c = nxt[0]; d = drawn(c); g = lb.get('glyph') or lb
                gc = g['y'] + g['h'] / 2; cc = (d[1] + d[3]) / 2
                out('5 label', tag, f"{mask(lb.get('text'))} -> {c['kind']}", f"glyph centre {n(gc)} control drawn centre {n(cc)}", gc - cc)
        if col2:
            lx = sorted({round(lb['x']) for lb, _, _, _ in col2}); cx = sorted({round(drawn(c)[0]) for _, c, _, _ in col2 if c})        # drawn edges (parts without the inset too)
            desc = '; '.join(f"y{n(y)} {mask(lb.get('text'))}@{n(lb['x'])} -> {c['kind'] + '@' + n(c['x']) + '..' + n(z['x'] + z['w']) if c else '-'}" for lb, c, z, y in col2)
            out('2 col2', where, 'one label line', desc, lx[-1] - lx[0])
            if cx: out('2 col2', where, 'one control line', 'controls drawn x ' + '/'.join(map(str, cx)), cx[-1] - cx[0])
            for lb, c, z, y in col2:
                if z: out('2 col2', where, f"y{n(y)} ends on {n(RIGHT)} (drawn {n(RIGHT - 6)})", f"{z['kind']} drawn right {n(drawn(z)[2])}", drawn(z)[2] - (RIGHT - 6))
            if cx:
                longest = max((lb.get('glyph') or lb)['w'] for lb, _, _, _ in col2)
                want = cx[0] - (longest + 16)
                # the label width is measured from Chrome's text metrics; a board that rounds it up to the 4 grid
                # (54.7 -> 56) is on the rule, so allow up to 4 short of the exact value, never longer
                dd = lx[0] - want; ok = -4 <= dd <= TOL
                out('2 col2', where, 'label line = control line - (longest + 10)', f"control drawn {cx[0]} longest label {n(longest)} -> {n(want)}; labels at {'/'.join(map(str, lx))}" + (' (label width rounded up)' if ok and abs(dd) > TOL else ''), dd, fail=not ok)
    balance(cards, els, out)
    return rows, flags

# 6 balance (spec "Layout balance"), every gap between drawn edges: card padding by card kind (main form card and
# overlay cards 32, nested cards 24; a fixed main card's bottom is spare, at least 32), card -> card 40, and
# row -> row at least 24 inside a main / overlay card (16 inside a nested card). A caption or body line within 12 under
# the row above belongs to that row.
def ink(e):
    if e['cat'] in ('text', 'label', 'title') and e.get('glyph') and e['glyph']['w'] > 0:
        g = e['glyph']; return g['x'], g['y'], g['x'] + g['w'], g['y'] + g['h']
    if e['cat'] in ('part', 'card'): return drawn(e)
    return e['x'], e['y'], e['x'] + e['w'], e['y'] + e['h']

def card_kind(c, cards):
    inside = any(o is not c and o['x'] <= c['x'] and o['y'] <= c['y'] and c['x'] + c['w'] <= o['x'] + o['w'] + 0.5
                 and c['y'] + c['h'] <= o['y'] + o['h'] + 0.5 for o in cards)
    return 'nested' if inside or c['x'] >= 860 else ('main' if c['w'] >= 700 else 'overlay')

def balance(cards, els, out):
    for c in cards:
        k = card_kind(c, cards); want = 24 if k == 'nested' else 32
        inner = [o for o in cards if o is not c and card_kind(o, cards) == 'nested' and o['reg'] is c] if 'reg' in c else []
        mem = [e for e in els if e.get('reg') is c and e['cat'] in ('part', 'label', 'text', 'picture', 'title') and e.get('kind') != 'badge']
        if not mem: continue
        d = drawn(c); I = [ink(e) for e in mem]
        pads = (min(i[0] for i in I) - d[0], min(i[1] for i in I) - d[1], d[2] - max(i[2] for i in I), d[3] - max(i[3] for i in I))
        tag = f"{k} card @{n(c['x'])},{n(c['y'])} {n(c['w'])}x{n(c['h'])}"
        fixed = k == 'main' and c['h'] >= 800
        for side, v in zip('LTRB', pads):
            if side == 'R': out('6 pad', tag, f'R >= {want}', f'ink {n(v)}', min(0, v - want)); continue   # rows may end short (check 4 covers stretching ones)
            if side == 'B' and fixed: out('6 pad', tag, f'{side} spare >= {want}', f'ink {n(v)}', min(0, v - want)); continue
            out('6 pad', tag, f'{side} {want}', f'ink {n(v)}', v - want)
        # rows inside the card
        rowsep = 16 if k == 'nested' else 24
        bs = sorted(bands([e for e in mem if e['cat'] in ('part', 'text', 'label', 'picture')]), key=lambda b: min(ink(e)[1] for e in b))
        prev = None
        for b in bs:
            top = min(ink(e)[1] for e in b); bot = max(ink(e)[3] for e in b)
            small = all(e['cat'] == 'text' and e.get('font', 30) <= 30 for e in b)
            if prev is not None:
                gap = top - prev
                if small and gap <= 12.5: prev = max(prev, bot); continue       # caption / body under its row
                out('6 row', tag, f'row gap >= {rowsep}', f'ink {n(gap)} at y{n(top)}', min(0, gap - rowsep))
            prev = bot if prev is None else max(prev, bot)
    cs = sorted([c for c in cards if card_kind(c, cards) != 'nested'], key=lambda c: c['y'])
    for a, b in zip(cs, cs[1:]):
        if abs(a['x'] - b['x']) < 5 and b['y'] > a['y'] + a['h'] - 1:
            out('6 cards', f"card @{n(a['x'])},{n(a['y'])}", 'card gap 40', f'ink {n(drawn(b)[1] - drawn(a)[3])}', drawn(b)[1] - drawn(a)[3] - 40)

# ---- --sizes: inventory of part sizes ------------------------------------------------------------------------
def group_of(e):
    k = e['kind']
    if k == 'ink': return 'main button' if e['w'] >= 300 else 'card button'
    return {'field': 'field', 'time': 'time field', 'tab': 'tab / pill', 'daybutton': 'tab / pill', 'daychip': 'chip',
            'datechip': 'chip', 'round': 'round button', 'badge': 'round button', 'switch': 'switch', 'swatch': 'swatch',
            'face': 'face', 'picture': 'picture circle', 'row': 'list row', 'card': 'card', 'dot': 'step dot'}.get(k)
STRETCH = {'field', 'tab / pill', 'list row', 'card'}       # height only; widths listed when they recur

def sizes(res):
    inv = {}                                                   # (group, size) -> {board: count}
    def add(g, size, bid): inv.setdefault((g, size), {}).setdefault(bid, 0); inv[(g, size)][bid] += 1
    for bid, els in res.items():
        if not els or els[0].get('cat') == 'ERR': continue
        cards = [e for e in els if e['cat'] == 'card']
        for e in els:
            if e['cat'] in ('part', 'card'):
                e['kind'] = kind_of(e)
                if e['kind'] == 'round' and any(e['x'] < c['x'] + c['w'] < e['x'] + e['w'] and e['y'] < c['y'] + 40 and e['y'] + e['h'] > c['y'] for c in cards): e['kind'] = 'badge'
                g = group_of(e)
                for w, h in e.get('imgs', []): add('icon / picture in parts', f'{n(w)}x{n(h)}', bid)
                for w, h in e.get('faces', []): add('kid face', f'{n(w)}x{n(h)}', bid)
                if e.get('ring'): add('pick ring', f"{n(e['ring']['w'])} over {n(e['w'])}", bid)
                if not g: continue
                if g in STRETCH:
                    add(g, f"h {n(e['h'])}", bid); add(g + ' widths', f"w {n(e['w'])}", bid)
                else: add(g, f"{n(e['w'])}x{n(e['h'])}", bid)
            elif e['cat'] == 'picture':
                add('icon / picture in rows' if e['tag'] == 'img' else 'kid face', f"{n(e['w'])}x{n(e['h'])}", bid)
    groups = ['field', 'time field', 'tab / pill', 'chip', 'round button', 'switch', 'swatch', 'face', 'picture circle',
              'pick ring', 'kid face', 'icon / picture in rows', 'icon / picture in parts', 'list row', 'card', 'card button', 'main button', 'step dot']
    oneoff = []
    num = lambda t: [float(v) for v in re.findall(r'[\d.]+', t)]
    for g in groups + [x + ' widths' for x in STRETCH]:
        items = sorted(((sz, b) for (gg, sz), b in inv.items() if gg == g), key=lambda t: num(t[0]))
        if not items: continue
        widths = g.endswith(' widths')
        shared = [(sz, b) for sz, b in items if len(b) > 1]
        one = [(sz, b) for sz, b in items if len(b) == 1]
        if widths:                                             # stretching parts: only widths that recur
            if shared: print(f"{g} (recurring): " + ', '.join(f"{sz[2:]} ×{sum(b.values())}/{len(b)}b" for sz, b in shared))
            continue
        print(f"\n{g}")
        for sz, b in shared:
            print(f"  {sz:<14} ×{sum(b.values()):<4} {len(b)} boards: {','.join(sorted(b))}")
        oneoff += [(g, sz, b) for sz, b in one]
        # near-duplicates: sizes in this group whose numbers all differ by 1..4 pt
        vals = [(sz, num(sz)) for sz, _ in items]
        near = [f"{a} ~ {c}" for i, (a, va) in enumerate(vals) for c, vc in vals[i + 1:]
                if len(va) == len(vc) and all(abs(x - y) <= 4 for x, y in zip(va, vc)) and va != vc]
        if near: print('  near-duplicates: ' + '; '.join(near))
    print('\none-off sizes (one board only):')
    for g, sz, b in oneoff: print(f"  {g:<24} {sz:<14} ×{sum(b.values())} {next(iter(b))}")
    sys.exit(0)

def main():
    need = [name for _, (name, _) in BOARDS.items() if not (CACHED and Path(WORK / f'preview/rel-{name}.json').exists())]
    if need:
        subprocess.run([sys.executable, str(HERE / 'local-render.py'), '--work', str(WORK), '--allow-missing'] + need, check=True, capture_output=QUIET)
    shutil.copy(HERE / 'relations.js', 'preview/relations.js')
    with ThreadPoolExecutor(4) as ex:
        res = dict(zip(BOARDS, ex.map(lambda kv: dump(kv[0], kv[1][0]), BOARDS.items())))
    if SIZES: return sizes(res)
    total, broken = {}, []
    for bid, (name, fam) in BOARDS.items():
        els = res[bid]
        if not els or els[0].get('cat') == 'ERR': broken.append(bid); print(f'\n## {bid} ({name}): could not measure', els and els[0].get('text')); continue
        rows, flags = check(bid, name, fam, els)
        total[bid] = len(flags)
        print(f'\n## {bid} ({name}, {fam})  flags: {len(flags)}')
        w = [max(len(str(r[i])) for r in rows) if rows else 0 for i in range(6)]
        groups = {}
        for r in rows:
            if r[5]: groups.setdefault((r[0], r[4]), []).append(r[2].split(' ')[0])
        if groups:
            print('  flagged, grouped: ' + '; '.join(f"{c} {d} x{len(v)} ({', '.join(sorted(set(v)))})" for (c, d), v in sorted(groups.items())))
        for r in rows:
            if QUIET and not r[5]: continue
            print('  ' + '  '.join(str(r[i]).ljust(min(w[i], (10, 34, 26, 120, 6, 2)[i])) for i in range(6)).rstrip())
    print('\nsummary (checked deltas over 1 pt): ' + ', '.join(f'{k} {v}' for k, v in total.items()))
    if broken: print('not measured:', broken); sys.exit(2)
    sys.exit(1 if any(total.values()) else 0)

main()
