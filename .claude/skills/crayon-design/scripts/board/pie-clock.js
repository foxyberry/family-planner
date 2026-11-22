// Crayon 24h pie clock (home screen, 900 x 1032) + small UI pieces (dots, ink button, circles, milk cup).
// Usage: [PIE_ONLY=1] node pie-clock.js <deps-dir> <out-dir> [config.json]
// config: {out, secs:[[from,to,colour|null,hatchAngle]], now:h, current:[from,to]|null, night:bool, hub:radius (default 104), rim:colour (the picked kid's)}  (hours 0-24, decimals)
// Without a config it draws the built-in school-day example to pie-crayon.svg. PIE_ONLY=1 skips the UI pieces.
const path = require('path');
const fs = require('fs');
const { createRequire } = require('module');
const [depsDir, outDir, cfgPath] = process.argv.slice(2);
const CFG = cfgPath ? JSON.parse(fs.readFileSync(cfgPath, 'utf8')) : null;
const rough = createRequire(path.join(path.resolve(depsDir), 'package.json'))('roughjs');
const gen = rough.generator();
const INK = '#1E1B22';

let seed = 101;
const ns = () => (seed += 17);
const toSvg = (drawable, extra = '') => gen.toPaths(drawable).map((p) => {
  const fill = p.fill && p.fill !== 'none' ? p.fill : 'none';
  const stroke = p.stroke && p.stroke !== 'none' ? ` stroke="${p.stroke}" stroke-width="${p.strokeWidth}" stroke-linecap="round" stroke-linejoin="round"` : '';
  return `<path d="${p.d}" fill="${fill}"${stroke}${extra}/>`;
}).join('');
const crayon = (d, color, angle, gap = 6) =>
  toSvg(gen.path(d, { seed: ns(), roughness: 2, bowing: 2, fill: color, fillStyle: 'solid', stroke: 'none' }), ' opacity="0.32"') +
  toSvg(gen.path(d, { seed: ns(), roughness: 2.2, bowing: 2, fill: color, fillStyle: 'hachure', hachureAngle: angle, hachureGap: gap, fillWeight: 2.6, stroke: 'none' }));
const marker = (d, w = 4, fill) => toSvg(gen.path(d, { seed: ns(), roughness: 1.2, bowing: 1.4, stroke: INK, strokeWidth: w, disableMultiStroke: true, fill, fillStyle: 'solid' }));
const circ = (cx, cy, r) => `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}Z`;
const rr = (x, y, w, h, r) => `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;
const doc = (w, h, inner) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${inner}</svg>\n`;

// --- pie ---
const cx = 448; const cy = 528; const R = 372;
const pt = (h, r) => { const t = (h / 24) * 2 * Math.PI; return [+(cx + r * Math.sin(t)).toFixed(1), +(cy - r * Math.cos(t)).toFixed(1)]; };
const sector = (h1, h2) => {
  if (h2 < h1) h2 += 24;
  const [x1, y1] = pt(h1, R); const [x2, y2] = pt(h2, R);
  return `M${cx} ${cy}L${x1} ${y1}A${R} ${R} 0 ${h2 - h1 > 12 ? 1 : 0} 1 ${x2} ${y2}Z`;
};
// Example school day. A slot with colour null is free time: plain paper.
const SECS = (CFG && CFG.secs) || [
  [20, 6.5, '#FFD23F', -40], [6.5, 7.5, '#7FD6B5', 60], [7.5, 15, '#F7A84B', -55], [15, 15.5, '#A8DB7A', 35],
  [15.5, 16.5, '#8FD3F4', 40], [16.5, 17, null, 0], [17, 18.5, '#A8DB7A', -30], [18.5, 19.25, '#F9A88A', 50], [19.25, 20, '#B9A3F0', -60],
];
const NOW = CFG ? CFG.now : 6 + 52 / 60;
const TICK = CFG && CFG.night ? '#F4EFFF' : INK;   // at night the ticks outside the disc are chalk
let pie = CFG && CFG.night ? `<path d="${circ(cx, cy, R)}" fill="#EFE8D8"/>` : '';   // night: a lit paper face under the slots
for (const [a, b, c, ang] of SECS) if (c) pie += crayon(sector(a, b), c, ang, 6.5);
for (const [a] of SECS) { const [x, y] = pt(a, R); pie += marker(`M${cx} ${cy}L${x} ${y}`, 2.5); }
pie += marker(circ(cx, cy, R), 4.5);
{ const CUR = CFG ? CFG.current : [6.5, 7.5]; if (CUR) pie += marker(sector(CUR[0], CUR[1]), 6); }   // current slot outlined
for (let h = 0; h < 24; h += 1) { const [x1, y1] = pt(h, R + 6); const [x2, y2] = pt(h, R + 20); pie += toSvg(gen.path(`M${x1} ${y1}L${x2} ${y2}`, { seed: ns(), roughness: 1.2, bowing: 1.4, stroke: TICK, strokeWidth: 3, disableMultiStroke: true })); }
const HUB = (CFG && CFG.hub) || 104;   // home v75: the hub holds only the face, weekday and time
if (CFG && CFG.rim) pie += toSvg(gen.path(circ(cx, cy, R), { seed: ns(), roughness: 1.4, bowing: 1.4, stroke: CFG.rim, strokeWidth: 12, disableMultiStroke: true })) + marker(circ(cx, cy, R + 7), 2.5);
pie += marker(circ(cx, cy, HUB), 4, CFG && CFG.night ? '#D8D2E8' : '#FFFFFF');
{ // lollipop "now" hand: long red line from the hub to a red disc near the rim
  const RED = '#E5484D';
  const [x1, y1] = pt(NOW, HUB + 2); const [x2, y2] = pt(NOW, 312); const [cx2, cy2] = pt(NOW, 336);
  pie += toSvg(gen.path(`M${x1} ${y1}L${x2} ${y2}`, { seed: ns(), roughness: 1.1, bowing: 1.2, stroke: RED, strokeWidth: 9, disableMultiStroke: true }));
  pie += crayon(circ(cx2, cy2, 24), RED, -45, 3.2) + marker(circ(cx2, cy2, 24), 4);
}
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, CFG ? CFG.out : 'pie-crayon.svg'), doc(900, 1032, pie));
if (process.env.PIE_ONLY) process.exit(0);

// --- UI pieces ---
fs.writeFileSync(path.join(outDir, 'dot-blue.svg'), doc(64, 64, crayon(circ(32, 32, 24), '#2E8FE0', -40, 3.5) + marker(circ(32, 32, 24), 3)));
fs.writeFileSync(path.join(outDir, 'dot-orange.svg'), doc(64, 64, crayon(circ(32, 32, 24), '#F28C28', 40, 3.5) + marker(circ(32, 32, 24), 3)));
fs.writeFileSync(path.join(outDir, 'dot-green.svg'), doc(48, 48, crayon(circ(24, 24, 16), '#3FAE5A', -40, 3) + marker(circ(24, 24, 16), 2.5)));
fs.writeFileSync(path.join(outDir, 'btn-ink.svg'), doc(400, 112, marker(rr(6, 6, 388, 100, 26), 4, INK)));
fs.writeFileSync(path.join(outDir, 'circle-orange.svg'), doc(240, 240, crayon(circ(120, 120, 108), '#FBC97A', -45, 6) + marker(circ(120, 120, 108), 4.5)));
fs.writeFileSync(path.join(outDir, 'circle-white.svg'), doc(240, 240, marker(circ(120, 120, 108), 4.5, '#FFFFFF')));
fs.writeFileSync(path.join(outDir, 'act-milk.svg'), doc(240, 240,
  crayon('M66 40h108l-14 168H80Z', '#FFFFFF', 0) + crayon('M72 96h96l-9 112H81Z', '#8FD3F4', -50) + marker('M66 40h108l-14 168H80Z', 5) + marker('M70 96h100', 4)));
console.log('ok');
