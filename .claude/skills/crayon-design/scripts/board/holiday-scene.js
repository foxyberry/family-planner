// Holiday mood scene behind the home clock (900 x 1032), crayon style (design mockup 2026-11-22).
const path = require('path'); const fs = require('fs'); const { createRequire } = require('module');
const [depsDir, outFile] = process.argv.slice(2);
const rough = createRequire(path.join(path.resolve(depsDir), 'package.json'))('roughjs');
const gen = rough.generator(); const INK = '#2B2833'; let seed = 7; const ns = () => (seed += 13);
const P = (d, o) => gen.toPaths(gen.path(d, { seed: ns(), ...o })).map((p) => `<path d="${p.d}" fill="${p.fill && p.fill !== 'none' ? p.fill : 'none'}"${p.stroke && p.stroke !== 'none' ? ` stroke="${p.stroke}" stroke-width="${p.strokeWidth}" stroke-linecap="round" stroke-linejoin="round"` : ''}/>`).join('');
const crayon = (d, c, ang, gap = 7, op = 0.3) => P(d, { roughness: 2, bowing: 2, fill: c, fillStyle: 'solid', stroke: 'none' }).replace(/<path /g, `<path opacity="${op}" `) + P(d, { roughness: 2.2, bowing: 2, fill: c, fillStyle: 'hachure', hachureAngle: ang, hachureGap: gap, fillWeight: 2.4, stroke: 'none' });
const line = (d, w = 3.5, c = INK) => P(d, { roughness: 1.3, bowing: 1.5, stroke: c, strokeWidth: w, disableMultiStroke: true });
const circ = (cx, cy, r) => `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}Z`;
let s = '';
s += crayon('M0 0H900V700C700 690 300 690 0 700Z', '#BFE6F7', -30, 10, 0.35);              // sky
s += crayon('M0 690C250 676 650 676 900 690V820H0Z', '#5FC0E8', 20, 7, 0.45);              // sea
s += line('M0 692C250 678 650 678 900 692', 3);
for (const [x, y] of [[120, 745], [380, 760], [700, 740], [560, 790]]) s += line(`M${x} ${y}c10 -8 20 -8 30 0s20 8 30 0`, 3, '#2E86BE');
s += crayon('M0 815C220 800 680 800 900 815V1032H0Z', '#F6D79A', 40, 8, 0.5);              // sand
s += line('M0 816C220 801 680 801 900 816', 3);
s += crayon(circ(800, 92, 54), '#FFD23F', -40, 5, 0.5) + line(circ(800, 92, 54), 3.5);     // sun
for (let a = 0; a < 360; a += 40) { const r1 = 66, r2 = 88, t = a * Math.PI / 180; s += line(`M${800 + r1 * Math.cos(t)} ${92 + r1 * Math.sin(t)}L${800 + r2 * Math.cos(t)} ${92 + r2 * Math.sin(t)}`, 4, '#F2A81D'); }
for (const [x, y, k] of [[110, 120, 1], [600, 60, 0.8]]) { const d = `M${x} ${y}c0 -30 40 -40 55 -20c10 -25 55 -20 55 8c25 -2 32 30 8 38H${x}c-25 0 -25 -26 0 -26z`; s += crayon(d, '#FFFFFF', 10, 6, 0.9) + line(d, 3); }
// beach umbrella bottom-left
s += line('M96 990L150 770', 5);
{ const d = 'M58 800C70 720 230 700 262 760C220 748 196 760 178 776C160 758 120 760 100 786C86 776 70 786 58 800Z'; s += crayon(d, '#F7A8CF', 50, 6, 0.6) + line(d, 3.5); s += line('M120 718C128 740 132 760 140 780M190 712C188 740 182 760 178 776', 3); }
// sandcastle bottom-right
{ const d = 'M700 990V900H726V880H746V900H770V860H796V840H816V860H840V900H864V880H884V990Z'; s += crayon(d, '#F2B661', -35, 6, 0.6) + line(d, 3.5); s += line('M806 840V806', 3) + crayon('M806 806L834 816L806 826Z', '#E5484D', 0, 4, 0.8) + line('M806 806L834 816L806 826', 2.5); s += line('M780 990V950C780 932 806 932 806 950V990', 3); }
// shells and a ball on the sand
s += crayon(circ(560, 980, 26), '#FFFFFF', 0, 6, 0.9) + line('M534 980C548 960 572 960 586 980', 8, '#E5484D') + line(circ(560, 980, 26), 3.5);
s += line('M300 990c6 -18 26 -18 32 0z', 3) + line('M640 1010c5 -14 20 -14 25 0z', 3);
fs.writeFileSync(outFile, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 1032" width="900" height="1032">${s}</svg>\n`);
console.log('ok');
