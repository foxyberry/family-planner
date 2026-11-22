# Redline boards: each screen board with its layout lines drawn on top, generated from the same layout JSON
# the app uses. Usage: python3 redlines.py [--work DIR] <layout-dir> [SHORT_IDS,comma,separated]
# Writes <work>/canvas/project/RL-<Board>.dc.html for every board in boards.json that has <layout-dir>/<id>.json.
import json, sys, os, re
sys.dont_write_bytecode = True   # no __pycache__ in the repo
from boardlib import work, boards
args = sys.argv[1:]
_pos = [a for i, a in enumerate(args) if a != '--work' and (i == 0 or args[i - 1] != '--work')]
if not _pos: sys.exit('usage: redlines.py [--work DIR] <layout-dir> [SHORT_IDS]')
L = os.path.abspath(_pos[0])   # resolved against the caller's cwd, before work() changes it
work(args)
ONLY = set(args[1].split(',')) if len(args) > 1 else None
LNAME = os.path.basename(L.rstrip('/'))
P = 'canvas/project/'
MAP = {k: n for k, (n, _) in boards().items() if not ONLY or k in ONLY}
MAG, CYAN, GREY = '#E0218A', '#0A84FF', '#8A8494'
def vline(x, label, color=MAG, dash=False, top=0, bottom=1032):
    st = 'dashed' if dash else 'solid'
    return (f'<div style="position:absolute;left:{x}px;top:{top}px;width:0;height:{bottom-top}px;border-left:2px {st} {color};opacity:.85"></div>'
            f'<span style="position:absolute;left:{x+4}px;top:{top+4}px;font:600 15px/1 Menlo,monospace;color:#fff;background:{color};padding:2px 4px;border-radius:3px;white-space:nowrap">{label}</span>')
def hline(y, label, color=MAG, dash=True, left=0, right=1376):
    st = 'dashed' if dash else 'solid'
    return (f'<div style="position:absolute;left:{left}px;top:{y}px;width:{right-left}px;height:0;border-top:2px {st} {color};opacity:.85"></div>'
            f'<span style="position:absolute;left:{right-4}px;top:{y-20}px;transform:translateX(-100%);font:600 15px/1 Menlo,monospace;color:#fff;background:{color};padding:2px 4px;border-radius:3px;white-space:nowrap">{label}</span>')
def box(x, y, w, h, label, color=CYAN):
    return (f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;outline:2px dashed {color};outline-offset:-1px;background:{color}0D"></div>'
            f'<span style="position:absolute;left:{x+4}px;top:{y+h-22}px;font:600 14px/1 Menlo,monospace;color:{color};background:#ffffffcc;padding:1px 3px;white-space:nowrap">{label}</span>')
made = []
for bid, name in MAP.items():
    jf = f'{L}/{bid}.json'
    if not os.path.exists(jf) or not os.path.exists(P + name + '.dc.html'): continue
    d = json.load(open(jf)); g = d['global']; ln = d['lines']
    o = ['<div aria-hidden="true" style="position:absolute;left:0;top:0;width:1376px;height:1032px;pointer-events:none;z-index:999">']
    o.append(f'<div style="position:absolute;left:0;top:0;width:1376px;height:24px;background:{MAG}22"></div><span style="position:absolute;left:600px;top:4px;font:600 14px/1 Menlo,monospace;color:{MAG}">status band 0–24 · keep empty</span>')
    # global lines
    M, R = g['margin'], g['right']
    o.append(vline(M, f'{M} margin')); o.append(vline(R, f'{R}', top=0))
    HT, HB, CT, BL = g['headerTop'], g['headerBottom'], g['contentTop'], g['headerBaseline']
    o.append(hline(HT, f'header {HT}')); o.append(hline(HB, f'{HB}')); o.append(hline(CT, f'content {CT}')); o.append(hline(968, 'bottom 968'))
    o.append(hline(BL, f'baseline {BL}', color=GREY, dash=True, left=M, right=R))
    # regions
    for rn, r in d['regions'].items():
        top = {'header': HT, 'strip': 176, 'kids': 536, 'missions': 548, 'bottom': 872, 'skySwitch': 36, 'clock': 0, 'panel': 96, 'main': CT, 'side': CT, 'action': 872}.get(rn, CT)
        bot = {'header': HB, 'strip': 516, 'kids': 852, 'missions': 860, 'bottom': 968, 'skySwitch': 132, 'clock': 1032, 'panel': 968, 'main': 968, 'side': 860, 'action': 968}.get(rn, 968)
        o.append(box(r['left'], top, r['right'] - r['left'], bot - top, f"{rn} · {r['anchor']}"))
    # screen lines
    fam = d['family']
    if fam == 'morning':
        for x, lab in [(172, '172 kid text'), (448, '448 missions')]: o.append(vline(x, lab, top=530))
        for y, lab in [(584, 'name baseline 584'), (612, 'circles 612'), (757, 'captions baseline 757'), (872, 'control 872')]: o.append(hline(y, lab, color=GREY, left=64, right=1312))
    if fam == 'home':
        cx, cy = ln['clockCentre']; R = ln['clockRadius']
        o.append(f'<div style="position:absolute;left:{cx-R}px;top:{cy-R}px;width:{2*R}px;height:{2*R}px;border-radius:50%;outline:2px dashed {CYAN}"></div>')
        o.append(vline(cx, f'clock centre {cx}', color=CYAN, dash=True)); o.append(hline(cy, f'clock centre {cy}', color=CYAN, left=0, right=900))
        o.append(vline(928, '928 panel', top=90)); o.append(vline(1336, '1336 panel right', top=90))
        h = ln.get('hubRadius', 104)
        o.append(f'<div style="position:absolute;left:{cx-h}px;top:{cy-h}px;width:{2*h}px;height:{2*h}px;border-radius:50%;outline:2px dashed {CYAN}"></div>')
        rows = ln.get('rows', {})
        for x, lab in [(rows.get('timeCell', [0, 1040])[1], 'time right 1040'), (rows.get('picture', [1052])[0], 'picture 1052'), (rows.get('titleLeft', 1120), 'title 1120')]: o.append(vline(x, lab, top=140, dash=True))
        chip = ln.get('kidChips', {}).get('top', 872)
        o.append(hline(chip, f'kid chips {chip}', color=GREY, left=920, right=1336))
    if fam == 'grown':
        for x, lab in [(80, '80 labels'), (208, '208 controls'), (840, '840'), (864, '864 side')]: o.append(vline(x, lab, top=CT - 6, dash=x in (80, 208)))
    if fam == 'grown64':
        for x, lab in [(104, '104 labels'), (232, '232 controls'), (882, '882'), (930, '930 side')]: o.append(vline(x, lab, top=170, dash=x in (104, 232)))
    # part boxes for parts that sit on a line (start / end / fill)
    for e in d['elements']:
        if e['kind'] in ('text', 'title', 'drawing'): continue
        if e['align'] in ('start', 'end', 'fill') and e['w'] < 1200:
            o.append(f'<div style="position:absolute;left:{e["x"]}px;top:{e["y"]}px;width:{e["w"]}px;height:{e["h"]}px;outline:1px solid {CYAN}88"></div>')
    o.append(f'<span style="position:absolute;left:{M}px;top:996px;font:600 15px/1 Menlo,monospace;color:#fff;background:{CYAN};padding:3px 6px;border-radius:3px">redlines · {bid} · from {LNAME}/{bid}.json · layout v{d.get("version","?")}</span>')
    o.append('</div>')
    s = open(P + name + '.dc.html').read()
    s = re.sub(r'<title>([^<]*)</title>', lambda m: f'<title>Redlines · {m.group(1)}</title>', s, 1)
    i = s.rindex('</div>\n</x-dc>')
    s = s[:i] + '\n'.join(o) + '\n' + s[i:]
    open(P + 'RL-' + name + '.dc.html', 'w').write(s)
    made.append((bid, 'RL-' + name + '.dc.html'))
print(made)
