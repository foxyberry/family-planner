// Kid-crayon style: bold single marker outline, crayon hatching with paper showing, fill spilling past the line,
// plain dot eyes, one-line smile. Usage: node kit.js <deps-dir> <out-dir: an .xcassets folder>
// Output names are the KitSlot raw values (ios/KitArt/KitSlot.swift).
const path = require('path');
const fs = require('fs');
const { createRequire } = require('module');
const [depsDir, outDir, shapesOut] = process.argv.slice(2);
const depRequire = createRequire(path.join(path.resolve(depsDir), 'package.json'));
const rough = depRequire('roughjs');
// points-on-path ships with roughjs and is an ES module; require() of it needs Node 22.12 or newer.
const { pointsOnPath } = depRequire('points-on-path');
const gen = rough.generator();

const INK = '#1E1B22';
const K = {
  green: '#3FAE5A', sky: '#8FD3F4', blue: '#2E8FE0', yellow: '#FFD23F', gold: '#F7B500',
  pink: '#F25FA8', orange: '#F2603C', mint: '#7FD6B5', purple: '#9B6BD3', white: '#FFFFFF',
};

const rr = (x, y, w, h, r) => `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;
const cap = (x, y, w, h) => rr(x, y, w, h, Math.min(w, h) / 2);
const circ = (cx, cy, r) => `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}Z`;
// ellipse turned by rot degrees (clockwise)
const ell = (cx, cy, rx, ry, rot = 0) => {
  const t = (rot * Math.PI) / 180;
  const ax = (cx + rx * Math.cos(t)).toFixed(1), ay = (cy + rx * Math.sin(t)).toFixed(1);
  const bx = (cx - rx * Math.cos(t)).toFixed(1), by = (cy - rx * Math.sin(t)).toFixed(1);
  return `M${ax} ${ay}A${rx} ${ry} ${rot} 1 0 ${bx} ${by}A${rx} ${ry} ${rot} 1 0 ${ax} ${ay}Z`;
};
const star = (cx, cy, R, r, rot = -90) => {
  let d = '';
  for (let i = 0; i < 10; i += 1) {
    const a = ((rot + i * 36) * Math.PI) / 180;
    const rad = i % 2 ? r : R;
    d += `${i ? 'L' : 'M'}${(cx + rad * Math.cos(a)).toFixed(1)} ${(cy + rad * Math.sin(a)).toFixed(1)}`;
  }
  return `${d}Z`;
};

// layer kinds: shape (crayon fill + marker outline), solid (marker-filled dark area), line (marker stroke only)
const S = (d, color, angle) => ({ kind: 'shape', d, color, angle });
const B = (d) => ({ kind: 'solid', d });
const Ln = (d, w = 4.5, color) => ({ kind: 'line', d, w, ...(color ? { color } : {}) });   // color: a coloured line (trim, cheeks); default is the ink
// Faces: plain marker dots for eyes, no whites, no lashes
const eye = (cx, cy, r = 13) => [B(circ(cx, cy, Math.max(4.5, r * 0.42)))];
const smile = (cx, cy, w) => Ln(`M${cx - w / 2} ${cy}Q${cx} ${cy + w * 0.5} ${cx + w / 2} ${cy}`, 4);
const wheel = (cx, cy) => [B(circ(cx, cy, 18))];

const ITEMS = {
  busMini: [
    S(rr(40, 86, 160, 98, 30), K.green, -55),
    S(rr(60, 104, 34, 32, 8), K.sky, 80), S(rr(102, 104, 34, 32, 8), K.sky, 80),
    ...eye(158, 120, 12), ...eye(184, 118, 12), smile(171, 148, 18),
    ...wheel(84, 188), ...wheel(160, 188),
  ],
  busSingle: [
    S(rr(14, 84, 212, 102, 26), K.orange, -50),
    S(rr(30, 102, 32, 34, 8), K.sky, 75), S(rr(70, 102, 32, 34, 8), K.sky, 75), S(rr(110, 102, 32, 34, 8), K.sky, 75),
    ...eye(172, 118, 12), ...eye(200, 116, 12), smile(186, 148, 18),
    ...wheel(58, 190), ...wheel(182, 190),
  ],
  busDouble: [
    S(rr(42, 26, 156, 160, 28), K.green, -60),
    S(rr(58, 44, 30, 30, 7), K.sky, 80), S(rr(96, 44, 30, 30, 7), K.sky, 80), S(rr(134, 44, 46, 30, 7), K.sky, 80),
    S(rr(58, 92, 30, 30, 7), K.sky, 80), S(rr(96, 92, 30, 30, 7), K.sky, 80),
    ...eye(146, 108, 11), ...eye(172, 106, 11), smile(159, 136, 16),
    ...wheel(82, 190), ...wheel(160, 190),
  ],
  medalGold: [
    S('M80 12H118L136 104L104 112Z', K.blue, 70),
    S('M160 12H122L104 104L136 112Z', K.pink, -70),
    S(circ(120, 156, 66), K.gold, -45),
    ...eye(98, 146, 14, [1, 2], true), ...eye(142, 146, 14, [-1, 2], true), smile(120, 178, 28),
  ],
  toothbrush: [
    S(cap(16, 142, 140, 26), K.purple, -40),
    S(rr(140, 134, 84, 34, 16), K.purple, -40),
    S(rr(150, 104, 66, 30, 6), K.white, 0),
    Ln('M162 104v30M176 104v30M190 104v30M204 104v30', 3),
    S('M146 98c8-22 24-6 36-18s28 6 36 16c-8 10-64 12-72 2z', K.mint, 30),
    ...eye(78, 154, 9, [1, 0]), ...eye(102, 154, 9, [1, 0]),
  ],
  backpack: [
    Ln('M98 58c-2-34 46-34 44 0', 6),
    S(rr(52, 52, 136, 162, 44), K.pink, -55),
    S(rr(74, 132, 92, 66, 20), K.purple, 60),
    ...eye(100, 102, 13, [1, 1], true), ...eye(140, 102, 13, [-1, 1], true), smile(120, 122, 18),
  ],
  star: [
    Ln('M38 186L104 132M24 152L92 108M62 214L118 158', 5),
    S(star(150, 96, 68, 30, -78), K.yellow, -35),
    ...eye(136, 92, 9, [1, 1]), ...eye(162, 90, 9, [1, 1]), smile(149, 110, 14),
  ],
  sun: [
    Ln('M120 14v26M120 200v26M14 120h26M200 120h26M44 44l18 18M178 178l18 18M196 44l-18 18M62 178l-18 18', 6),
    S(circ(120, 120, 62), K.yellow, -50),
    ...eye(98, 110, 12, [0, 2]), ...eye(142, 110, 12, [0, 2]), smile(120, 140, 30),
  ],
  actSleep: [
    S('M150 30A96 96 0 1 0 214 160A74 74 0 1 1 150 30Z', K.yellow, -40),
    Ln('M44 138q8 7 16 0M72 133q8 7 16 0', 4), smile(68, 156, 18),
  ],
  actBreakfast: [
    Ln('M92 70c-10-16 10-24 0-40M120 70c-10-16 10-24 0-40M148 70c-10-16 10-24 0-40', 5),
    S('M28 104h184a92 82 0 0 1-184 0z', K.orange, -50),
    S(cap(60, 92, 120, 22), K.yellow, 20),
  ],
  actSchool: [
    S('M36 108L120 44L204 108Z', K.orange, -40),
    S(rr(52, 104, 136, 104, 8), K.yellow, 60),
    S(rr(102, 146, 36, 62, 6), K.blue, 80),
    Ln('M120 44V12', 5), S('M120 12h40l-10 10 10 10h-40z', K.pink, 0),
  ],
  actCCA: [
    S(circ(120, 124, 84), K.blue, -45),
    Ln('M36 124h168M120 40c-40 40-40 128 0 168M120 40c40 40 40 128 0 168', 4.5),
  ],
  actPlay: [
    S('M120 66C90 48 52 46 24 54V196C52 188 90 190 120 208Z', K.pink, -55),
    S('M120 66C150 48 188 46 216 54V196C188 188 150 190 120 208Z', K.mint, 55),
    Ln('M44 92q30-8 56 4M44 126q30-8 56 4M140 96q26-12 56-4M140 130q26-12 56-4', 3.5),
  ],
  actDinner: [
    // dinner plate with a spoon and chopsticks (sujeo) in steel grey
    S(circ(120, 124, 76), K.white, 0),
    S(circ(120, 124, 46), K.green, -45),
    S(ell(30, 62, 15, 22), '#C9CED6', 60), S(cap(25, 80, 10, 134), '#C9CED6', 60),
    S(cap(198, 36, 12, 178), '#C9CED6', -70), S(cap(217, 36, 12, 178), '#C9CED6', -70),
  ],
  actShower: [
    // shower: a pipe up the wall, a steel shower head, blue water streaks, a rubber duck below
    Ln('M44 226V62Q44 30 76 30H112', 9),
    S('M104 28h36l28 46H76z', '#C9CED6', 30),
    Ln('M92 92l-9 34M110 94l-4 40M128 94v42M146 94l4 40M164 92l9 34', 6, K.blue),
    Ln('M100 150l-5 18M138 156v18', 6, K.blue),
    S('M128 214a34 20 0 0 1 64 -22l10 -2a6 6 0 0 1 2 12l-8 4a34 20 0 0 1 -68 8z', K.yellow, -40),
    S(circ(184, 170, 15), K.yellow, -40), S('M196 168l16 3-15 7z', K.orange, 0), B(circ(186, 166, 3)),
  ],
  feelVeryHappy: [
    S(circ(120, 122, 92), K.yellow, -45),
    B(star(92, 104, 15, 6.5)), B(star(148, 104, 15, 6.5)),
    S('M90 140h60a30 30 0 0 1-60 0z', K.pink, 0),
  ],
  feelHappy: [
    S(circ(120, 122, 92), K.gold, -45),
    ...eye(94, 106), ...eye(146, 106), smile(120, 146, 50),
  ],
  feelOK: [
    S(circ(120, 122, 92), K.mint, -45),
    ...eye(94, 108), ...eye(146, 108), Ln('M96 156h48', 4.5),
  ],
  feelSad: [
    S(circ(120, 122, 92), K.sky, -45),
    ...eye(94, 108), ...eye(146, 108), Ln('M94 166Q120 140 146 166', 4.5),
  ],
  feelVerySad: [
    S(circ(120, 122, 92), K.purple, -45),
    ...eye(94, 106), ...eye(146, 106),
    S('M88 120C84 130 80 136 80 142a8 8 0 0 0 16 0C96 136 92 130 88 120Z', K.sky, 80),
    Ln('M94 172Q108 150 120 160Q132 150 146 172', 4.5),
  ],
  energyLots: [
    Ln('M14 72l20 10M8 122h22M14 172l20-10M226 72l-20 10M232 122h-22M226 172l-20-10', 5),
    S(circ(120, 122, 84), K.orange, -45),
    B(star(96, 106, 14, 6)), ...eye(146, 106),
    S('M92 138h56a28 28 0 0 1-56 0z', K.pink, 0),
  ],
  energyGood: [
    S(circ(120, 122, 90), K.green, -45),
    ...eye(94, 106), ...eye(146, 106), smile(120, 146, 44),
  ],
  energyTired: [
    S(circ(120, 124, 88), K.sky, -45),
    Ln('M82 112h24M134 112h24', 5), Ln('M100 162Q120 150 140 162', 4.5),
    Ln('M182 34h22l-22 24h22M206 4h14l-14 16h14', 4),
  ],
  energyNone: [
    S(circ(120, 128, 86), K.purple, -45),
    Ln('M82 112q12 12 24 0M134 112q12 12 24 0', 4.5),
    S(circ(120, 164, 11), K.white, 0),
    S('M190 70C186 80 182 86 182 92a8 8 0 0 0 16 0C198 86 194 80 190 70Z', K.sky, 80),
  ],
  medalSilver: [
    S('M80 12H118L136 104L104 112Z', K.blue, 70),
    S('M160 12H122L104 104L136 112Z', K.pink, -70),
    S(circ(120, 156, 66), '#C9CDD6', -45),
    ...eye(98, 146, 14), ...eye(142, 146, 14), smile(120, 178, 28),
  ],
  medalBronze: [
    S('M80 12H118L136 104L104 112Z', K.blue, 70),
    S('M160 12H122L104 104L136 112Z', K.pink, -70),
    S(circ(120, 156, 66), '#D9925B', -45),
    ...eye(98, 146, 14), ...eye(142, 146, 14), smile(120, 178, 28),
  ],
  // Added for the app: generic, public-safe pictures for slots the canvas drew elsewhere.
  shirt: [
    S('M88 40L36 70l22 42 26-10v100h72V102l26 10 22-42-52-30a32 32 0 0 1-64 0Z', K.pink, -50),
  ],
  shoe: [
    S('M30 80v86h184v-14c0-14-10-26-24-30l-50-16-30-30-30 16-22-12Z', K.blue, -40),
    S(rr(26, 166, 192, 22, 8), K.white, 0),
    Ln('M104 100l12 12M120 90l12 12', 4),
  ],
  tv: [
    Ln('M88 24l32 34 32-34', 5),
    S(rr(28, 66, 184, 136, 18), K.purple, -45),
    S(rr(48, 84, 144, 100, 10), K.sky, 50),
    B('M108 112v44l36-22Z'),
  ],
  home: [
    S(rr(52, 110, 136, 100, 6), K.yellow, -40),
    S('M34 118L120 42L206 118Z', K.orange, 45),
    S(rr(104, 150, 32, 60, 8), K.blue, -30),
    S(rr(66, 128, 28, 26, 4), K.sky, 40), S(rr(146, 128, 28, 26, 4), K.sky, 40),
  ],
  // After-school activities (CCA). The generic actCCA stays for anything without its own picture.
  actDance: [
    // long hair first, so the arms sit in front of it
    S('M88 60C84 30 102 18 120 18C138 18 156 30 152 60C156 80 160 100 152 112C144 117 136 110 134 100L132 84H108L106 100C104 110 96 117 88 112C80 100 84 80 88 60Z', '#5B3A29', 40),
    Ln('M108 102L66 58', 7), Ln('M132 102L176 64', 7),
    Ln('M110 156L94 214', 7), Ln('M130 156L152 208', 7),
    S(rr(106, 86, 28, 52, 10), K.pink, -40),
    S('M62 160Q120 116 178 160Q120 184 62 160Z', K.pink, 40),
    S(circ(120, 58, 28), '#F6C89A', -35),
    S('M93 52C94 36 106 30 120 30C134 30 146 36 147 52C138 45 128 43 120 47C112 43 102 45 93 52Z', '#5B3A29', 40),   // fringe
    ...eye(110, 58, 12), ...eye(132, 58, 12), Ln('M110 71Q121 79 132 71', 3.5),
    B(circ(196, 118, 10)), Ln('M206 118V84L220 92', 4),
    B(circ(38, 122, 9)), Ln('M47 122V92L60 98', 4),
  ],
  actStory: [
    S('M40 44H200A20 20 0 0 1 220 64V150A20 20 0 0 1 200 170H112L76 206L86 170H40A20 20 0 0 1 20 150V64A20 20 0 0 1 40 44Z', K.sky, -40),
    S(star(80, 106, 30, 13), K.yellow, 30),
    S('M128 146V102H140V90H152V102H164V90H176V102H188V146Z', K.pink, -45),
    S(rr(150, 120, 16, 26, 7), K.white, 0),
  ],
  // Weekend: a Saturday language school (a different school with a 가 sign) and Sunday church
  actLanguageSchool: [
    S(rr(48, 100, 144, 112, 8), K.mint, -50),
    S(rr(40, 84, 160, 24, 8), K.purple, 30),
    S(rr(84, 24, 72, 54, 10), K.white, 0),
    Ln('M100 78v8M140 78v8', 4),
    Ln('M96 40H114Q116 58 104 68M130 34V70M130 52H142', 5),
    S(rr(64, 128, 36, 30, 5), K.sky, 40), S(rr(140, 128, 36, 30, 5), K.sky, 40),
    S(rr(104, 152, 32, 60, 6), K.blue, 80),
  ],
  actChurch: [
    S(rr(100, 54, 40, 58, 4), K.white, 0),
    S('M92 58L120 32L148 58Z', K.purple, -40),
    Ln('M120 32V8M110 17H130', 5),
    S(rr(54, 124, 132, 92, 6), K.white, 0),
    S('M38 130L120 78L202 130Z', K.purple, -40),
    S('M104 216V184a16 16 0 0 1 32 0V216Z', K.orange, 70),
    S(circ(120, 146, 11), K.sky, 40),
  ],
  actSwim: [
    S(circ(120, 104, 62), K.orange, 40),
    S(circ(120, 104, 26), K.white, 0),
    Ln('M70 66L84 80M170 66L156 80M70 142L84 128M170 142L156 128', 6),
    S('M14 168C34 152 56 152 76 168C96 184 118 184 138 168C158 152 180 152 200 168C210 176 218 178 226 178V222H14Z', K.sky, -30),
  ],
  actArt: [
    S('M120 40C60 40 26 82 30 132C34 182 84 206 130 198C152 194 150 172 164 164C184 154 214 160 216 122C218 74 176 40 120 40Z', '#E9C48A', -40),
    S(circ(168, 126, 12), K.white, 0),
    S(circ(80, 96, 15), K.blue, -40), S(circ(120, 74, 15), K.orange, 40), S(circ(162, 82, 14), K.yellow, -30),
    S(circ(72, 146, 15), K.green, 30), S(circ(112, 168, 14), K.pink, -45),
    S('M140 214L200 130L212 138L152 222Z', K.orange, 50),
    S('M200 130L218 104L228 116L212 138Z', K.blue, -40),
  ],
  actMusic: [
    B('M104 62L204 36L204 62L104 88Z'),
    Ln('M108 174V68', 8), Ln('M200 150V44', 8),
    S('M56 178A30 21 0 1 0 116 178A30 21 0 1 0 56 178Z', K.purple, -40),
    S('M148 154A30 21 0 1 0 208 154A30 21 0 1 0 148 154Z', K.purple, 40),
    S(star(48, 70, 18, 8), K.yellow, 30),
  ],
  actFootball: [
    S('M12 202C60 190 180 190 228 202V228H12Z', K.green, -30),
    S(circ(120, 116, 86), K.white, 0),
    // made by tools/football.py: central patch, five rim patches cut by the ball's edge, seams between them
    Ln('M120.0 86.0L120.0 66.0 M148.5 106.7L167.6 100.5 M137.6 140.3L149.4 156.5 M102.4 140.3L90.6 156.5 M91.5 106.7L72.4 100.5 M142.8 49.4L176.3 73.7 M190.4 117.1L177.6 156.5 M140.7 183.3L99.3 183.3 M62.4 156.5L49.6 117.1 M63.7 73.7L97.2 49.4', 4),
    B('M120.0 86.0L148.5 106.7L137.6 140.3L102.4 140.3L91.5 106.7Z'),
    B('M120.0 66.0L97.2 49.4L102.6 33.3L111.5 31.9L120.0 31.5L128.5 31.9L137.4 33.3L142.8 49.4Z'), B('M167.6 100.5L176.3 73.7L193.2 73.9L197.3 82.0L200.4 89.9L202.6 98.1L204.0 107.0L190.4 117.1Z'), B('M149.4 156.5L177.6 156.5L182.7 172.6L176.3 179.0L169.7 184.4L162.6 189.0L154.5 193.1L140.7 183.3Z'), B('M90.6 156.5L99.3 183.3L85.5 193.1L77.4 189.0L70.3 184.4L63.7 179.0L57.3 172.6L62.4 156.5Z'), B('M72.4 100.5L49.6 117.1L36.0 107.0L37.4 98.1L39.6 89.9L42.7 82.0L46.8 73.9L63.7 73.7Z'),
  ],
  actPiano: [
    S(rr(16, 52, 208, 44, 12), K.purple, -40),
    S(rr(16, 90, 208, 108, 10), K.white, 0),
    Ln('M45.7 94V192 M75.4 94V192 M105.1 94V192 M134.9 94V192 M164.6 94V192 M194.3 94V192', 3.5),
    B(rr(35.7, 92, 20, 58, 3)), B(rr(65.4, 92, 20, 58, 3)), B(rr(124.9, 92, 20, 58, 3)), B(rr(154.6, 92, 20, 58, 3)), B(rr(184.3, 92, 20, 58, 3)),
  ],
  // Morning routine extras
  toilet: [
    S(rr(70, 34, 100, 62, 12), K.sky, -40),
    S('M50 112H190C190 160 160 186 120 186C80 186 50 160 50 112Z', K.white, 0),
    S('M44 112A76 16 0 1 0 196 112A76 16 0 1 0 44 112Z', K.sky, 40),
    S('M96 184H144L150 212H90Z', K.white, 0),
  ],
  washFace: [
    S(circ(110, 132, 72), '#F6C89A', -35),
    Ln('M78 126Q90 136 102 126', 4.5), Ln('M120 126Q132 136 144 126', 4.5), Ln('M96 160Q112 172 128 160', 4.5),
    S('M196 46C196 46 176 74 176 88A20 20 0 0 0 216 88C216 74 196 46 196 46Z', K.sky, -30),
    S('M206 132C206 132 192 152 192 162A14 14 0 0 0 220 162C220 152 206 132 206 132Z', K.sky, 30),
    S(circ(60, 66, 14), K.white, 0), S(circ(38, 96, 9), K.white, 0),
  ],
  hairBrush: [
    S(rr(26, 92, 188, 44, 14), K.orange, -40),
    Ln('M44 136V182M64 136V182M84 136V182M104 136V182M124 136V182M144 136V182M164 136V182M184 136V182M200 136V176', 5),
  ],
  lunchBox: [
    Ln('M92 90V66H148V90', 7),
    S(rr(30, 88, 180, 116, 16), K.green, -40),
    Ln('M30 128H210', 4.5),
    S(rr(104, 116, 32, 22, 6), K.yellow, 30),
  ],
  waterBottle: [
    S(rr(92, 36, 56, 40, 10), K.blue, -40),
    S(rr(80, 70, 80, 146, 26), K.sky, 40),
    Ln('M84 124Q120 114 156 124', 4),
  ],
  // School and play
  homework: [
    S('M54 34H158L190 66V210H54Z', K.white, 0),
    Ln('M158 34V66H190', 4), Ln('M74 92H170M74 120H170M74 148H146', 3.5),
    S('M118 202L194 92L212 104L136 214Z', K.yellow, 40),
    S('M118 202L136 214L110 226Z', '#E9C48A', 0),
  ],
  blocks: [
    S(rr(36, 132, 76, 76, 8), K.blue, -40), S(rr(124, 132, 76, 76, 8), K.green, 40),
    S(rr(80, 52, 76, 76, 8), K.orange, -30),
    Ln('M60 156L88 184M88 156L60 184', 5), B(circ(162, 170, 12)), Ln('M118 74V106M102 90H134', 5),
  ],
  playground: [
    Ln('M48 82V214M80 82V214M48 112H80M48 142H80M48 172H80', 5),
    S(rr(38, 66, 56, 20, 5), K.orange, 0),
    S('M88 70C132 70 150 188 216 194L212 214C138 210 116 98 84 90Z', K.yellow, -40),
  ],
  snack: [
    Ln('M120 74C118 56 124 42 132 34', 5),
    S('M126 54C140 32 166 32 178 42C166 58 144 62 126 54Z', K.green, 30),
    S('M120 74C90 54 42 66 42 122C42 178 84 212 120 198C156 212 198 178 198 122C198 66 150 54 120 74Z', '#E5484D', -40),
  ],
  // Evening and sleep (for later)
  pyjamas: [
    // long cream-yellow pyjamas with a lilac scalloped neck and a fluffy puppy.
    // Trousers start at the top's hem (crayon shows the paper, so nothing may hide under the top).
    S('M78 122H162L170 228H128L120 162L112 228H70Z', '#FBE6A2', 50),
    S('M94 22Q120 40 146 22L178 32L208 104L184 114L162 70V122H78V70L56 114L32 104L62 32Z', '#FBE6A2', -50),
    Ln('M94.0 28.0Q97.7 34.7 101.4 32.4Q105.1 38.4 108.9 35.3Q112.6 40.6 116.3 36.8Q120.0 41.3 123.7 36.8Q127.4 40.6 131.1 35.3Q134.9 38.4 138.6 32.4Q142.3 34.7 146.0 28.0', 4, '#B993E3'),
    Ln('M180 106L203 96.5', 4), Ln('M60 106L37 96.5', 4), Ln('M74 210H113', 4), Ln('M127 210H166', 4),
    S('M71.3 57.0Q75.8 44.7 88.7 47.0Q84.2 59.3 71.3 57.0Z', K.green, 30), S('M143.1 106.2Q154.9 106.2 156.9 117.8Q145.1 117.8 143.1 106.2Z', K.orange, -30),
    S('M89.5 176.2Q100.5 180.2 98.5 191.8Q87.5 187.8 89.5 176.2Z', K.orange, 20), S('M141.6 177.7Q141.6 164.6 154.4 162.3Q154.4 175.4 141.6 177.7Z', K.green, -20),
    // puppy (shiba-like): small pointed ears, a softly fluffy round head, small white muzzle, lilac cheeks
    S('M95 82L98 58Q100 54 104 57L116 68Z', '#E9AE6E', 30), S('M145 82L142 58Q140 54 136 57L124 68Z', '#E9AE6E', -30),
    S('M120.0 61.0Q129.1 59.8 135.9 66.2Q143.9 70.6 145.7 79.7Q149.6 88.0 145.7 96.3Q143.9 105.4 135.9 109.8Q129.1 116.2 120.0 115.0Q110.9 116.2 104.1 109.8Q96.1 105.4 94.3 96.3Q90.4 88.0 94.3 79.7Q96.1 70.6 104.1 66.2Q110.9 59.8 120.0 61.0Z', '#E9AE6E', -40),
    S('M109 98A11 8 0 1 0 131 98A11 8 0 1 0 109 98Z', K.white, 0),
    B(circ(111, 84, 3.2)), B(circ(129, 84, 3.2)), B('M117 94A3 2.3 0 1 0 123 94A3 2.3 0 1 0 117 94Z'),
    Ln('M117 99.5Q120 101.5 123 99.5', 2),
    Ln('M105 93H105.1', 7, '#B993E3'), Ln('M135 93H135.1', 7, '#B993E3'),
  ],
  teddy: [
    // sitting bear: ears and arms behind, then body, legs in front, head on top
    S(circ(78, 58, 19), '#C08A5A', 30), S(circ(162, 58, 19), '#C08A5A', -30),
    S(ell(80, 172, 15, 30, 28), '#C08A5A', 60), S(ell(160, 172, 15, 30, -28), '#C08A5A', -60),
    S(ell(120, 176, 44, 42), '#C08A5A', -40),
    S(ell(120, 182, 22, 20), '#F1D3B0', 0),
    S(ell(88, 212, 23, 18, -10), '#C08A5A', 40), S(ell(152, 212, 23, 18, 10), '#C08A5A', -40),
    S(circ(84, 214, 9), '#F1D3B0', 0), S(circ(156, 214, 9), '#F1D3B0', 0),
    S(circ(120, 98, 52), '#C08A5A', -35),
    S(circ(120, 118, 21), '#F1D3B0', 0),
    ...eye(98, 92, 14), ...eye(142, 92, 14), B(circ(120, 110, 7)), Ln('M110 126Q120 134 130 126', 3.5),
  ],
  // Toddler items
  milk: [
    // a glass of milk: one outline only (two near-identical outlines drift apart and read as two cups),
    // creamy milk (pure white vanishes on the white tile), a single line for the milk's surface and a pale-blue shine on the glass
    S('M66 40H174L160 208H80Z', '#FFF0CF', -50),
    Ln('M70 64Q120 74 170 64', 3.5),
    Ln('M86 86L95 186', 6, '#BFE6F7'),
  ],
  babyBottle: [
    // milk in a baby bottle: peach teat, mint collar, creamy milk body with a surface line and measuring marks
    S('M104 60Q103 30 120 24Q137 30 136 60Z', '#F6C89A', 20),
    S(rr(86, 74, 68, 144, 24), '#FFF0CF', -50),
    S(rr(88, 52, 64, 28, 9), K.mint, -30),
    Ln('M91 104Q120 111 149 104', 3.5),
    Ln('M136 132H148 M140 152H148 M136 172H148 M140 192H148', 3),
    Ln('M101 122L101 196', 6, '#BFE6F7'),
  ],
  // One-off events
  cake: [
    S(rr(92, 62, 14, 46, 4), K.sky, 0), S(rr(136, 62, 14, 46, 4), K.yellow, 0),
    S('M99 32C99 32 90 44 90 50A9 9 0 0 0 108 50C108 44 99 32 99 32Z', K.orange, 0),
    S('M143 32C143 32 134 44 134 50A9 9 0 0 0 152 50C152 44 143 32 143 32Z', K.orange, 0),
    S(rr(42, 106, 156, 94, 12), K.pink, -40),
    S('M42 118C58 100 78 130 94 112C110 96 128 128 144 112C160 96 180 130 198 116V106H42Z', K.white, 0),
    Ln('M26 206H214', 5),
  ],
  doctor: [
    Ln('M96 82V62H144V82', 7),
    S(rr(36, 80, 168, 124, 18), K.white, 0),
    S('M104 104H136V126H158V158H136V180H104V158H82V126H104Z', '#E5484D', -40),
  ],
  // Getting to school without the bus
  car: [
    S('M22 152C22 130 34 122 54 118L80 80C86 72 94 68 104 68H150C160 68 168 72 174 80L198 116C216 120 224 130 224 152V178H22Z', K.blue, -40),
    S('M92 84H124V116H70Z', K.sky, 40), S('M134 84H154C158 84 162 86 164 90L180 116H134Z', K.sky, 40),
    S(circ(214, 142, 7), K.yellow, 0),
    B(circ(68, 180, 22)), B(circ(176, 180, 22)), S(circ(68, 180, 8), K.white, 0), S(circ(176, 180, 8), K.white, 0),
  ],
  taxi: [
    S(rr(96, 40, 52, 24, 6), K.white, 0),
    S('M22 152C22 130 34 122 54 118L80 80C86 72 94 68 104 68H150C160 68 168 72 174 80L198 116C216 120 224 130 224 152V178H22Z', K.yellow, -40),
    S('M92 84H124V116H70Z', K.sky, 40), S('M134 84H154C158 84 162 86 164 90L180 116H134Z', K.sky, 40),
    B(rr(40, 138, 16, 12, 2)), B(rr(72, 138, 16, 12, 2)), B(rr(104, 138, 16, 12, 2)), B(rr(136, 138, 16, 12, 2)), B(rr(168, 138, 16, 12, 2)),
    S(circ(214, 142, 7), K.white, 0),
    B(circ(68, 180, 22)), B(circ(176, 180, 22)), S(circ(68, 180, 8), K.white, 0), S(circ(176, 180, 8), K.white, 0),
  ],
  // Child faces for setup (S1): the parent picks one per child until the child draws their own.
  // Sky switch on the kid home screen: day, dusk (mid-animation) and night. A 5:3 pill across the 240 box,
  // so KitIcon shows it in a 160 x 96 frame with aspect fit.
  skyDay: [
    S(rr(6, 54, 228, 132, 66), K.sky, -30),
    S('M150 140a16 16 0 0 1 12-26a20 20 0 0 1 38 4a14 14 0 0 1 6 22z', K.white, 0),
    S(circ(78, 120, 44), K.yellow, -40),
    B(circ(64, 112, 4.5)), B(circ(92, 112, 4.5)), Ln('M64 132Q78 145 92 132', 4),
  ],
  skyDusk: [
    S(rr(6, 54, 228, 132, 66), '#F9A88A', 40),
    S(circ(120, 132, 40), K.yellow, -40),
    B(circ(107, 124, 4.5)), B(circ(133, 124, 4.5)), Ln('M108 141Q120 151 132 141', 4),
    Ln('M28 160H212', 12, K.purple),
  ],
  skyNight: [
    S(rr(6, 54, 228, 132, 66), '#3A3866', -30),
    S(star(50, 96, 14, 6), '#FFF3B0', 0), S(star(84, 148, 11, 5), '#FFF3B0', 0), Ln('M108 88H108.1', 7, '#FFF3B0'),
    S('M207.5 139.3L205.3 143.3L202.7 147.1L199.7 150.6L196.3 153.7L192.6 156.5L188.7 158.8L184.5 160.8L180.1 162.3L175.6 163.3L171.1 163.9L166.5 164.0L161.9 163.6L157.4 162.7L153.0 161.3L148.7 159.5L144.7 157.3L140.9 154.7L137.4 151.7L134.3 148.3L131.5 144.6L129.2 140.7L127.2 136.5L125.7 132.1L124.7 127.6L124.1 123.1L124.0 118.5L124.4 113.9L125.3 109.4L126.7 105.0L128.5 100.7L130.7 96.7L133.3 92.9L136.3 89.4L139.7 86.3L143.4 83.5L147.3 81.2L151.5 79.2L155.9 77.7L160.4 76.7L164.9 76.1L169.5 76.0L206.9 138.7L203.5 140.3L199.9 141.5L196.3 142.3L192.5 142.8L188.7 142.9L185.0 142.5L181.3 141.8L177.7 140.7L174.2 139.2L170.9 137.4L167.8 135.2L164.9 132.8L162.4 130.0L160.1 127.0L158.1 123.7L156.5 120.3L155.3 116.7L154.5 113.1L154.0 109.3L153.9 105.5L154.3 101.8L155.0 98.1L156.1 94.5L157.6 91.0L159.4 87.7L161.6 84.6L164.0 81.7L166.8 79.2L169.8 76.9Z', K.yellow, -40),
    Ln('M134 114q6 6 12 0', 3.5), Ln('M136 134q8 7 16 0', 3.5),
    Ln('M72 54H168A66 66 0 0 1 168 186H72A66 66 0 0 1 72 54Z', 5, '#F4EFFF'),
  ],
  // Developer tools: a friendly ladybug for the debug bubble. The white plate keeps it readable on a dark or orange circle.
  debugLadybug: [
    S(circ(120, 124, 108), K.white, 0),
    Ln('M106 54Q100 30 84 32q-9 2-4 11', 5), Ln('M134 54Q140 30 156 32q9 2 4 11', 5),
    S(ell(120, 148, 72, 60), '#E5484D', -40),
    Ln('M120 122V206', 5),
    B(circ(86, 146, 11)), B(circ(154, 146, 11)), B(circ(98, 182, 9)), B(circ(142, 182, 9)),
    S(ell(120, 88, 46, 36), '#3A3640', 30),
    { kind: 'eye', d: circ(102, 84, 13) }, { kind: 'eye', d: circ(138, 84, 13) },
    B(circ(104, 86, 6)), B(circ(140, 86, 6)),
    Ln('M101 81H101.1M137 81H137.1', 4, '#FFFFFF'),
    Ln('M108 104Q120 114 132 104', 4, '#FFFFFF'),
    Ln('M90 100H90.1M150 100H150.1', 9, '#F7A8CF'),
  ],
  kidGirl: [
    S(circ(42, 132, 26), '#5B3A29', 30), S(circ(198, 132, 26), '#5B3A29', -30),
    S(circ(120, 132, 80), '#F6C89A', -35),
    S('M42 124C42 70 78 46 120 46C162 46 198 70 198 124C186 104 168 96 148 98C140 84 130 80 120 80C110 80 100 84 92 98C72 96 54 104 42 124Z', '#5B3A29', 40),
    S(circ(60, 110, 11), K.pink, 0), S(circ(180, 110, 11), K.pink, 0),
    ...eye(94, 136, 20), ...eye(146, 136, 20),
    Ln('M102 170Q120 184 138 170', 5),
  ],
  kidBoy: [
    S(circ(120, 128, 82), '#F6C89A', -35),
    S('M42 116C44 66 80 44 120 44C160 44 196 66 198 116C172 94 146 88 122 100C100 88 70 92 42 116Z', '#5B3A29', 40),
    ...eye(92, 132, 20), ...eye(148, 132, 20),
    Ln('M100 168Q120 184 140 168', 5),
  ],
};

const SIZE = 240;
// Each picture gets its own seed from its slot name, so adding, removing or reordering
// pictures never changes any other picture.
let seed = 7;
const nextSeed = () => (seed += 13);
const seedFor = (name) => {
  let h = 2166136261;
  for (const ch of name) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619) >>> 0; }
  return (h % 2147483000) + 1;
};
const toSvg = (drawable, extra = '') => gen.toPaths(drawable).map((p) => {
  const fill = p.fill && p.fill !== 'none' ? p.fill : 'none';
  const stroke = p.stroke && p.stroke !== 'none' ? ` stroke="${p.stroke}" stroke-width="${p.strokeWidth}" stroke-linecap="round" stroke-linejoin="round"` : '';
  // Two decimals is far below a pixel at any size we draw, and roughly halves the file size.
  const d = p.d.replace(/-?\d*\.\d+(?:e-?\d+)?/g, (n) => String(Math.round(Number(n) * 100) / 100));
  return `<path d="${d}" fill="${fill}"${stroke}${extra}/>`;
}).join('');

// Freehand outlines: long straight runs bow a little and every edge drifts slowly, so no line is ruler-straight.
// Closed shapes bow mostly outward; an open line bows to one side. Same seed, same picture.
const MAX_BOW = 2.2;   // largest bow in viewBox units (240 per picture), whatever the edge length
const WOBBLE = { outline: { amp: 1.5, radius: 360 }, line: { amp: 1.1, radius: 300 } };
function wobble(d, s, { amp, radius }) {
  let r = s;
  const rnd = () => { r = (r * 48271) % 2147483647; return r / 2147483647; };
  const closedPath = /z\s*$/i.test(d.trim());
  const side = rnd() < 0.5 ? 1 : -1;
  return pointsOnPath(d, 0.3, 0.4).map((poly) => {
    const n = poly.length;
    let area = 0;
    for (let i = 0; i < n; i += 1) { const [x1, y1] = poly[i]; const [x2, y2] = poly[(i + 1) % n]; area += x1 * y2 - x2 * y1; }
    const outward = area > 0 ? -1 : 1;
    const pts = [];
    let len = 0;
    for (let i = 0; i < n - 1; i += 1) {
      const [ax, ay] = poly[i];
      const [bx, by] = poly[i + 1];
      const L = Math.hypot(bx - ax, by - ay);
      if (L === 0) continue;
      const k = Math.max(1, Math.ceil(L / 3));
      const nx = -(by - ay) / L;
      const ny = (bx - ax) / L;
      const dir = closedPath ? (rnd() < 0.9 ? outward : -outward) : side;
      const sag = L > 18 ? dir * Math.min((L * L) / (8 * radius), MAX_BOW) * (0.5 + rnd() * 0.9) : 0;   // long edges (buttons) bow a little, never a lot
      for (let j = 0; j < k; j += 1) {
        const u = j / k;
        const b = sag * 4 * u * (1 - u);
        pts.push([ax + (bx - ax) * u + nx * b, ay + (by - ay) * u + ny * b, len + L * u]);
      }
      len += L;
    }
    pts.push([poly[n - 1][0], poly[n - 1][1], len]);
    // On closed shapes the wavelengths divide the perimeter, so the seam meets without a step.
    const fit = (lam) => (closedPath && len > 0 ? len / Math.max(1, Math.round(len / lam)) : lam);
    const l1 = fit(48 + rnd() * 30);
    const l2 = fit(16 + rnd() * 8);
    const p1 = rnd() * 6.283;
    const p2 = rnd() * 6.283;
    const xy = pts.map((p, i) => {
      const a = pts[Math.max(0, i - 1)];
      const b = pts[Math.min(pts.length - 1, i + 1)];
      const dx = b[0] - a[0];
      const dy = b[1] - a[1];
      const m = Math.hypot(dx, dy) || 1;
      const off = amp * (0.7 * Math.sin((p[2] * 6.283) / l1 + p1) + 0.3 * Math.sin((p[2] * 6.283) / l2 + p2));
      return `${(p[0] - (dy / m) * off).toFixed(1)} ${(p[1] + (dx / m) * off).toFixed(1)}`;
    });
    return `M${xy.join('L')}${closedPath ? 'Z' : ''}`;
  }).join('');
}
const inkPath = (d, width, fill = 'none', stroke = INK) => `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"/>`;

function render(layers) {
  let out = '';
  for (const l of layers) {
    if (l.kind === 'shape') {
      if (l.color !== K.white) {
        // crayon: light wash so paper still shows, then hatching, both nudged past the outline
        out += `<g transform="translate(3 2)">`;
        out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 2.2, bowing: 2, fill: l.color, fillStyle: 'solid', stroke: 'none' }), ' opacity="0.28"');
        out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 2.4, bowing: 2, fill: l.color, fillStyle: 'hachure', hachureAngle: l.angle, hachureGap: 4.2, fillWeight: 2.8, stroke: 'none' }));
        out += `</g>`;
      }
      out += inkPath(wobble(l.d, nextSeed(), WOBBLE.outline), 5, l.color === K.white ? K.white : 'none');
    } else if (l.kind === 'eye') {
      out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 0.8, stroke: INK, strokeWidth: 3.5, disableMultiStroke: true, fill: K.white, fillStyle: 'solid' }));
    } else if (l.kind === 'solid') {
      out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 1, stroke: INK, strokeWidth: 3, disableMultiStroke: true, fill: INK, fillStyle: 'solid' }));
    } else if (l.kind === 'line') {
      out += inkPath(wobble(l.d, nextSeed(), WOBBLE.line), l.w, 'none', l.color);
    }
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}">${out}</svg>\n`;
}

// Picture rigs: tap a slot on the kid clock and its picture plays once. Rigid parts only (see "rules").
// For each rigged slot, make art writes the picture again as ordered runs of layers (one imageset per run,
// drawn with the same seeds, so stacked runs equal the normal picture) and KitRigs.dataset/rigs.json.
const RIGS = {
 "version": 1,
 "scale": 1,
 "maxSeconds": 1.2,
 "rules": "Rigid parts only (rotate or move a whole part; never bend or stretch). Faces move only with their head part; eyes may blink once. Rotations <= 15 deg, moves <= 20 units in the 240 box. One play per tap, <= 1.2 s, then still. Pivots sit where the part is attached. A picture without a rig gets 'hop'.",
 "moves": {
  "hop": "whole picture up 14 and down, a 5% squash on landing (origin: bottom centre)",
  "rock": "rotate +deg, -deg, ... 'times' swings, settling to 0",
  "bob": "move up 'px' and back, 'times' times",
  "slide": "move sideways +-'px', 'times' times (scrubbing)",
  "spin": "rotate by 'deg' once; deg is the part's symmetry angle, so it lands looking the same",
  "rise": "move up 'px' while fading out, twice (steam)",
  "fall": "move down 'px' while fading out, twice (water)",
  "press": "move down 'px' and back once, after 'delay' ms (keys)",
  "blink": "eye dot squashes to 10% height and back once",
  "flicker": "flame grows 15% taller then 10% shorter from its base",
  "twinkle": "turn 20 deg and grow 15% evenly, then back"
 },
 "default": {
  "parts": [
   {
    "name": "all",
    "layers": "all",
    "origin": [
     120,
     220
    ],
    "moves": [
     {
      "type": "hop",
      "px": 14
     }
    ]
   }
  ]
 },
 "rigs": {
  "actSleep": {
   "parts": [
    {
     "name": "moon",
     "layers": [
      0,
      1,
      2
     ],
     "origin": [
      120,
      124
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 8,
       "times": 2
      }
     ]
    }
   ]
  },
  "actBreakfast": {
   "parts": [
    {
     "name": "steam",
     "layers": [
      0
     ],
     "origin": [
      120,
      50
     ],
     "moves": [
      {
       "type": "rise",
       "px": 12
      }
     ]
    },
    {
     "name": "bowl",
     "layers": [
      1,
      2
     ],
     "origin": [
      120,
      186
     ],
     "moves": [
      {
       "type": "bob",
       "px": 4,
       "times": 1
      }
     ]
    }
   ]
  },
  "actSchool": {
   "parts": [
    {
     "name": "flag",
     "layers": [
      4
     ],
     "origin": [
      120,
      22
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 12,
       "times": 3
      }
     ]
    }
   ]
  },
  "snack": {
   "parts": [
    {
     "name": "leaf",
     "layers": [
      0,
      1
     ],
     "origin": [
      122,
      72
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 14,
       "times": 2
      }
     ]
    },
    {
     "name": "apple",
     "layers": [
      2
     ],
     "origin": [
      120,
      200
     ],
     "moves": [
      {
       "type": "bob",
       "px": 6,
       "times": 1
      }
     ]
    }
   ]
  },
  "actSwim": {
   "parts": [
    {
     "name": "ring",
     "layers": [
      0,
      1,
      2
     ],
     "origin": [
      120,
      104
     ],
     "moves": [
      {
       "type": "bob",
       "px": 8,
       "times": 2
      },
      {
       "type": "rock",
       "deg": 6,
       "times": 2
      }
     ]
    },
    {
     "name": "water",
     "layers": [
      3
     ],
     "origin": [
      120,
      200
     ],
     "moves": [
      {
       "type": "slide",
       "px": 8,
       "times": 2
      }
     ]
    }
   ]
  },
  "blocks": {
   "parts": [
    {
     "name": "top block",
     "layers": [
      2,
      5
     ],
     "origin": [
      118,
      128
     ],
     "moves": [
      {
       "type": "bob",
       "px": 18,
       "times": 1
      },
      {
       "type": "rock",
       "deg": 6,
       "times": 1
      }
     ]
    }
   ]
  },
  "actDinner": {
   "parts": [
    {
     "name": "spoon",
     "layers": [
      2,
      3
     ],
     "origin": [
      30,
      214
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 10,
       "times": 2
      }
     ]
    },
    {
     "name": "left chopstick",
     "layers": [
      4
     ],
     "origin": [
      204,
      214
     ],
     "moves": [
      {
       "type": "rock",
       "deg": -4,
       "times": 2
      }
     ]
    },
    {
     "name": "right chopstick",
     "layers": [
      5
     ],
     "origin": [
      223,
      214
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 4,
       "times": 2
      }
     ]
    }
   ]
  },
  "actShower": {
   "parts": [
    {
     "name": "water",
     "layers": [
      2,
      3
     ],
     "origin": [
      128,
      120
     ],
     "moves": [
      {
       "type": "fall",
       "px": 12
      }
     ]
    },
    {
     "name": "duck",
     "layers": [
      4,
      5,
      6,
      7
     ],
     "origin": [
      160,
      214
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 8,
       "times": 2
      }
     ]
    }
   ]
  },
  "actArt": {
   "parts": [
    {
     "name": "brush",
     "layers": [
      7,
      8
     ],
     "origin": [
      146,
      218
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 12,
       "times": 2
      }
     ]
    }
   ]
  },
  "actMusic": {
   "parts": [
    {
     "name": "notes",
     "layers": [
      0,
      1,
      2,
      3,
      4
     ],
     "origin": [
      130,
      176
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 6,
       "times": 3
      }
     ]
    },
    {
     "name": "star",
     "layers": [
      5
     ],
     "origin": [
      48,
      70
     ],
     "moves": [
      {
       "type": "twinkle"
      }
     ]
    }
   ]
  },
  "actFootball": {
   "parts": [
    {
     "name": "ball",
     "layers": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8
     ],
     "origin": [
      120,
      116
     ],
     "moves": [
      {
       "type": "bob",
       "px": 18,
       "times": 2
      },
      {
       "type": "spin",
       "deg": 72
      }
     ]
    }
   ]
  },
  "actPiano": {
   "parts": [
    {
     "name": "key 1",
     "layers": [
      3
     ],
     "origin": [
      46,
      92
     ],
     "moves": [
      {
       "type": "press",
       "px": 5,
       "delay": 0
      }
     ]
    },
    {
     "name": "key 2",
     "layers": [
      4
     ],
     "origin": [
      76,
      92
     ],
     "moves": [
      {
       "type": "press",
       "px": 5,
       "delay": 90
      }
     ]
    },
    {
     "name": "key 3",
     "layers": [
      5
     ],
     "origin": [
      135,
      92
     ],
     "moves": [
      {
       "type": "press",
       "px": 5,
       "delay": 180
      }
     ]
    },
    {
     "name": "key 4",
     "layers": [
      6
     ],
     "origin": [
      165,
      92
     ],
     "moves": [
      {
       "type": "press",
       "px": 5,
       "delay": 270
      }
     ]
    },
    {
     "name": "key 5",
     "layers": [
      7
     ],
     "origin": [
      195,
      92
     ],
     "moves": [
      {
       "type": "press",
       "px": 5,
       "delay": 360
      }
     ]
    }
   ]
  },
  "actDance": {
   "parts": [
    {
     "name": "left arm",
     "layers": [
      1
     ],
     "origin": [
      108,
      102
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 14,
       "times": 2
      }
     ]
    },
    {
     "name": "right arm",
     "layers": [
      2
     ],
     "origin": [
      132,
      102
     ],
     "moves": [
      {
       "type": "rock",
       "deg": -14,
       "times": 2
      }
     ]
    },
    {
     "name": "skirt",
     "layers": [
      6
     ],
     "origin": [
      120,
      150
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 4,
       "times": 2
      }
     ]
    },
    {
     "name": "head",
     "layers": [
      0,
      7,
      8,
      9,
      10,
      11
     ],
     "origin": [
      120,
      86
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 5,
       "times": 2
      }
     ]
    },
    {
     "name": "right note",
     "layers": [
      12,
      13
     ],
     "origin": [
      204,
      104
     ],
     "moves": [
      {
       "type": "rise",
       "px": 10
      }
     ]
    },
    {
     "name": "left note",
     "layers": [
      14,
      15
     ],
     "origin": [
      44,
      108
     ],
     "moves": [
      {
       "type": "rise",
       "px": 10
      }
     ]
    }
   ]
  },
  "cake": {
   "parts": [
    {
     "name": "left flame",
     "layers": [
      2
     ],
     "origin": [
      99,
      58
     ],
     "moves": [
      {
       "type": "flicker"
      }
     ]
    },
    {
     "name": "right flame",
     "layers": [
      3
     ],
     "origin": [
      143,
      58
     ],
     "moves": [
      {
       "type": "flicker"
      }
     ]
    }
   ]
  },
  "sun": {
   "parts": [
    {
     "name": "rays",
     "layers": [
      0
     ],
     "origin": [
      120,
      120
     ],
     "moves": [
      {
       "type": "spin",
       "deg": 45
      }
     ]
    },
    {
     "name": "left eye",
     "layers": [
      2
     ],
     "origin": [
      98,
      110
     ],
     "moves": [
      {
       "type": "blink"
      }
     ]
    },
    {
     "name": "right eye",
     "layers": [
      3
     ],
     "origin": [
      142,
      110
     ],
     "moves": [
      {
       "type": "blink"
      }
     ]
    }
   ]
  },
  "busDouble": {
   "parts": [
    {
     "name": "body",
     "layers": [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8
     ],
     "origin": [
      120,
      186
     ],
     "moves": [
      {
       "type": "bob",
       "px": 6,
       "times": 2
      }
     ]
    }
   ]
  },
  "toothbrush": {
   "parts": [
    {
     "name": "brush",
     "layers": "all",
     "origin": [
      120,
      150
     ],
     "moves": [
      {
       "type": "slide",
       "px": 10,
       "times": 3
      },
      {
       "type": "rock",
       "deg": 3,
       "times": 3
      }
     ]
    }
   ]
  },
  "actLanguageSchool": {
   "parts": [
    {
     "name": "sign",
     "layers": [
      2,
      3,
      4
     ],
     "origin": [
      120,
      86
     ],
     "moves": [
      {
       "type": "rock",
       "deg": 6,
       "times": 2
      }
     ]
    }
   ]
  }
 }
};
const CATALOG_INFO = { info: { author: 'xcode', version: 1 } };
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'Contents.json'), `${JSON.stringify(CATALOG_INFO, null, 2)}\n`);
for (const [name, layers] of Object.entries(ITEMS)) {
  seed = seedFor(name);
  const set = path.join(outDir, `${name}.imageset`);
  fs.mkdirSync(set, { recursive: true });
  fs.writeFileSync(path.join(set, `${name}.svg`), render(layers));
  const contents = {
    images: [{ filename: `${name}.svg`, idiom: 'universal' }],
    ...CATALOG_INFO,
    properties: { 'preserves-vector-representation': true },
  };
  fs.writeFileSync(path.join(set, 'Contents.json'), `${JSON.stringify(contents, null, 2)}\n`);
}
console.log('wrote', Object.keys(ITEMS).length, 'imagesets');
{
  const out = { version: RIGS.version, scale: RIGS.scale, maxSeconds: RIGS.maxSeconds, rules: RIGS.rules, moves: RIGS.moves, default: RIGS.default, rigs: {} };
  let images = 0;
  for (const [name, rig] of Object.entries(RIGS.rigs)) {
    const layers = ITEMS[name];
    if (!layers) throw new Error(`rig for unknown slot ${name}`);
    const owner = new Map();
    rig.parts.forEach((part, pi) => (part.layers === 'all' ? layers.map((_, i) => i) : part.layers).forEach((i) => owner.set(i, pi)));
    seed = seedFor(name);
    const one = layers.map((l) => render([l]).replace(/^<svg[^>]*>/, '').replace(/<\/svg>\n?$/, ''));
    const runs = [];
    for (let i = 0; i < layers.length;) {
      const pi = owner.has(i) ? owner.get(i) : -1;
      let body = '';
      while (i < layers.length && (owner.has(i) ? owner.get(i) : -1) === pi) { body += one[i]; i += 1; }
      const image = `rig-${name}-${runs.length}`;
      const set = path.join(outDir, `${image}.imageset`);
      fs.mkdirSync(set, { recursive: true });
      fs.writeFileSync(path.join(set, `${image}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}">${body}</svg>\n`);
      fs.writeFileSync(path.join(set, 'Contents.json'), `${JSON.stringify({ images: [{ filename: `${image}.svg`, idiom: 'universal' }], ...CATALOG_INFO, properties: { 'preserves-vector-representation': true } }, null, 2)}\n`);
      runs.push({ image, part: pi < 0 ? null : rig.parts[pi].name });
      images += 1;
    }
    out.rigs[name] = { runs, parts: Object.fromEntries(rig.parts.map((p) => [p.name, { origin: p.origin, moves: p.moves }])) };
  }
  const ds = path.join(outDir, 'KitRigs.dataset');
  fs.mkdirSync(ds, { recursive: true });
  fs.writeFileSync(path.join(ds, 'rigs.json'), `${JSON.stringify(out, null, 1)}\n`);
  fs.writeFileSync(path.join(ds, 'Contents.json'), `${JSON.stringify({ data: [{ filename: 'rigs.json', idiom: 'universal' }], ...CATALOG_INFO }, null, 2)}\n`);
  console.log('wrote', Object.keys(out.rigs).length, 'rigs in', images, 'run imagesets');
}

// Optional: the style-free shape definitions, so an app-side renderer can draw the same pictures
// in any style (crayon today, others later) without a separate SVG set per style.
if (shapesOut) {
  const items = {};
  for (const [name, layers] of Object.entries(ITEMS)) {
    items[name] = layers.map((l) => {
      if (l.kind === 'shape') return { kind: 'shape', d: l.d, color: l.color, hatchAngle: l.angle };
      if (l.kind === 'line') return { kind: 'line', d: l.d, width: l.w, ...(l.color ? { color: l.color } : {}) };
      if (l.kind === 'eye') return { kind: 'shape', d: l.d, color: K.white, hatchAngle: 0 };   // white eye with an ink ring
      return { kind: 'solid', d: l.d };
    });
  }
  const shapes = {
    version: 2,
    viewBox: SIZE,
    ink: INK,
    palette: K,
    seed: 'FNV-1a 32-bit of the slot name, mod 2147483000, plus 1; each layer step adds 13',
    styles: {
      crayon: {
        wash: { opacity: 0.28, roughness: 2.2, bowing: 2, offset: [3, 2] },
        hachure: { roughness: 2.4, bowing: 2, gap: 4.2, weight: 2.8, offset: [3, 2] },
        outline: { wobble: WOBBLE.outline, width: 5 },
        solid: { roughness: 1, width: 3 },
        line: { wobble: WOBBLE.line },
        wobble: 'resample every 3pt; segments over 18pt bow by sagitta min(L*L/(8*radius), 2.2) * (0.5..1.4), 90% outward on closed shapes, one side on open lines; then offset along the normal by amp * (0.7 sin(2*pi*s/l1 + p1) + 0.3 sin(2*pi*s/l2 + p2)), l1 48..78, l2 16..24, fitted to the perimeter on closed shapes',
      },
    },
    items,
  };
  fs.writeFileSync(shapesOut, `${JSON.stringify(shapes, null, 1)}\n`);
  console.log('wrote', shapesOut);
}
