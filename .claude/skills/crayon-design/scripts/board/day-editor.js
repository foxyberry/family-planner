// Grown-up day editor: a 24h pie (824 x 792) with drag knobs on every boundary, plus exact-size parts (tabs, card, time fields).
// Usage: node day-editor.js <deps-dir> <out-dir> [config.json]
// config: {out, slots:[[from,to,colour|null,angle,name,skipped?]], locked:[h], active:h|null, selected:[from,to]|null, dash:h|null, plus:[h]}
// With a config only the pie is written (to cfg.out); without one the built-in example pie plus the exact-size parts.
const path = require('path');
const fs = require('fs');
const { createRequire } = require('module');
const [depsDir, outDir, cfgPath] = process.argv.slice(2);
const CFG = cfgPath ? JSON.parse(fs.readFileSync(cfgPath, 'utf8')) : null;
const rough = createRequire(path.join(path.resolve(depsDir), 'package.json'))('roughjs');
const gen = rough.generator();
const INK = '#1E1B22';
let seed = 901;
const ns = () => (seed += 23);
const toSvg = (d, extra = '') => gen.toPaths(d).map((p) => {
  const fill = p.fill && p.fill !== 'none' ? p.fill : 'none';
  const stroke = p.stroke && p.stroke !== 'none' ? ` stroke="${p.stroke}" stroke-width="${p.strokeWidth}" stroke-linecap="round" stroke-linejoin="round"` : '';
  return `<path d="${p.d}" fill="${fill}"${stroke}${extra}/>`;
}).join('');
const crayon = (d, color, angle = -45, gap = 6.5) =>
  toSvg(gen.path(d, { seed: ns(), roughness: 2, bowing: 2, fill: color, fillStyle: 'solid', stroke: 'none' }), ' opacity="0.32"') +
  toSvg(gen.path(d, { seed: ns(), roughness: 2.2, bowing: 2, fill: color, fillStyle: 'hachure', hachureAngle: angle, hachureGap: gap, fillWeight: 2.6, stroke: 'none' }));
const marker = (d, w = 4, fill, color = INK, extra = '') => toSvg(gen.path(d, { seed: ns(), roughness: 1.1, bowing: 1.2, stroke: color, strokeWidth: w, disableMultiStroke: true, fill, fillStyle: 'solid' }), extra);
const circ = (cx, cy, r) => `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}Z`;
const rr = (x, y, w, h, r) => `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;
const doc = (w, h, inner) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${inner}</svg>\n`;
fs.mkdirSync(outDir, { recursive: true });
const W = 824, H = 792, cx = 412, cy = 396, R = 340, HUB = 130;
const pt = (h, r) => { const t = (h / 24) * 2 * Math.PI; return [+(cx + r * Math.sin(t)).toFixed(1), +(cy - r * Math.cos(t)).toFixed(1)]; };
const sector = (h1, h2) => { if (h2 < h1) h2 += 24; const [x1, y1] = pt(h1, R); const [x2, y2] = pt(h2, R); return `M${cx} ${cy}L${x1} ${y1}A${R} ${R} 0 ${h2 - h1 > 12 ? 1 : 0} 1 ${x2} ${y2}Z`; };
// example school-day template for Kid A, mid-drag: dinner's end / shower's start moved 7:15 -> 7:30 pm
const SLOTS = (CFG && CFG.slots) || [
  [20, 6.5, '#FFD23F', -40, 'sleep'], [6.5, 7.5, '#7FD6B5', 60, 'morning'], [7.5, 15, '#F7A84B', -55, 'school'],
  [15, 16, '#A8DB7A', 35, 'snack'], [16, 17, null, 0, 'free'], [17, 18.5, '#A8DB7A', -30, 'play'],
  [18.5, 19.5, '#F9A88A', 50, 'dinner'], [19.5, 20, '#B9A3F0', -60, 'shower'],
];
let pie = '';
for (const [a, b, c, ang, , skipped] of SLOTS) pie += skipped ? (marker(sector(a, b), 0.01, '#FFFFFF', '#FFFFFF') + `<g opacity="0.3">${crayon(sector(a, b), c, ang)}</g>`) : c ? crayon(sector(a, b), c, ang) : marker(sector(a, b), 0.01, '#FFFFFF', '#FFFFFF');   // skipped this day: faded
for (const [a] of SLOTS) { const [x, y] = pt(a, R); pie += marker(`M${cx} ${cy}L${x} ${y}`, 2.5); }
pie += marker(circ(cx, cy, R), 4.5);
{ const SEL = CFG ? CFG.selected : [18.5, 19.5]; if (SEL) pie += marker(sector(SEL[0], SEL[1]), 6); }   // selected slice
{ const DASH = CFG ? CFG.dash : 19.25; if (DASH != null) { const [x, y] = pt(DASH, R); pie += `<path d="M${pt(DASH, HUB)[0]} ${pt(DASH, HUB)[1]}L${x} ${y}" stroke="${INK}" stroke-width="3" stroke-dasharray="6 8" stroke-linecap="round" opacity="0.55"/>`; } } // where the edge was
for (let h = 0; h < 24; h += 1) { const [x1, y1] = pt(h, R + 4); const [x2, y2] = pt(h, R + 16); pie += marker(`M${x1} ${y1}L${x2} ${y2}`, 3); }
// free slice: a "+" to add a block there
for (const h of (CFG ? (CFG.plus || []) : [16.5])) { const [px, py] = pt(h, R * 0.64); pie += marker(circ(px, py, 28), 4, '#FFFFFF') + marker(`M${px - 13} ${py}H${px + 13}M${px} ${py - 13}V${py + 13}`, 5); }
pie += marker(circ(cx, cy, HUB), 4, '#FFFFFF');
// knobs on the rim: white = drag, grey with a lock = set elsewhere (school hours), blue = being dragged
const LOCKED = CFG ? (CFG.locked || []) : [7.5, 15], ACTIVE = CFG ? CFG.active : 19.5;
for (const [a] of SLOTS) {
  const [x, y] = pt(a, R);
  if (a === ACTIVE) { pie += crayon(circ(x, y, 24), '#2E8FE0', -40, 3.4) + marker(circ(x, y, 24), 4) + marker(circ(x, y, 34), 3, undefined, '#2E8FE0'); continue; }
  if (LOCKED.includes(a)) {
    pie += marker(circ(x, y, 20), 3.5, '#E6E1EE');
    pie += marker(rr(x - 8, y - 3, 16, 12, 3), 2.5, INK) + marker(`M${x - 5} ${y - 3}V${y - 7}a5 5 0 0 1 10 0V${y - 3}`, 2.5);
    continue;
  }
  pie += marker(circ(x, y, 18), 4, '#FFFFFF');
}
fs.writeFileSync(path.join(outDir, CFG ? CFG.out : 'pie-edit.svg'), doc(W, H, pie));
if (CFG) { console.log('ok', CFG.out); process.exit(0); }
// exact-size parts
const pill = (w, h, color) => doc(w, h, (color ? crayon(rr(6, 6, w - 12, h - 12, (h - 12) / 2), color, -40) : '') + marker(rr(6, 6, w - 12, h - 12, (h - 12) / 2), 4, color ? undefined : '#FFFFFF'));
fs.writeFileSync(path.join(outDir, 'tab150-on.svg'), pill(150, 72, '#8FD3F4'));
fs.writeFileSync(path.join(outDir, 'tab110-off.svg'), pill(110, 72, null));
fs.writeFileSync(path.join(outDir, 'tab182-off.svg'), pill(182, 72, null));
fs.writeFileSync(path.join(outDir, 'card382x440.svg'), doc(382, 440, marker(rr(5, 5, 372, 430, 24), 4, '#FFFFFF')));
fs.writeFileSync(path.join(outDir, 'field-time-170.svg'), doc(170, 80, marker(rr(5, 5, 160, 70, 18), 4, '#FFFFFF')));
fs.writeFileSync(path.join(outDir, 'field-time-170-focus.svg'), doc(170, 80, marker(rr(5, 5, 160, 70, 18), 5, '#FFFFFF', '#2E8FE0')));
console.log('ok', SLOTS.length);