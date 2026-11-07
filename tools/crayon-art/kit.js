// Kid-crayon style: bold single marker outline, crayon hatching with paper showing, fill spilling past the line,
// plain dot eyes, one-line smile. Usage: node kit.js <deps-dir> <out-dir: an .xcassets folder>
// Output names are the KitSlot raw values (ios/KitArt/KitSlot.swift).
const path = require('path');
const fs = require('fs');
const { createRequire } = require('module');
const [depsDir, outDir, shapesOut] = process.argv.slice(2);
const rough = createRequire(path.join(path.resolve(depsDir), 'package.json'))('roughjs');
const gen = rough.generator();

const INK = '#1E1B22';
const K = {
  green: '#3FAE5A', sky: '#8FD3F4', blue: '#2E8FE0', yellow: '#FFD23F', gold: '#F7B500',
  pink: '#F25FA8', orange: '#F2603C', mint: '#7FD6B5', purple: '#9B6BD3', white: '#FFFFFF',
};

const rr = (x, y, w, h, r) => `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;
const cap = (x, y, w, h) => rr(x, y, w, h, Math.min(w, h) / 2);
const circ = (cx, cy, r) => `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}Z`;
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
const Ln = (d, w = 4.5) => ({ kind: 'line', d, w });
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
    S(circ(120, 124, 76), K.white, 0),
    S(circ(120, 124, 46), K.green, -45),
    Ln('M24 52v60M14 52v28q10 14 20 0V52M24 112v100', 5),
    S(cap(206, 52, 22, 64), K.orange, 80), Ln('M217 116v96', 5),
  ],
  actShower: [
    S('M120 24C96 66 70 92 70 128a50 50 0 0 0 100 0C170 92 144 66 120 24Z', K.sky, -60),
    S('M56 150C46 166 38 176 38 190a18 18 0 0 0 36 0C74 176 66 166 56 150Z', K.blue, 70),
    S('M186 146C176 162 168 172 168 186a18 18 0 0 0 36 0C204 172 196 162 186 146Z', K.blue, 70),
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
    Ln('M108 102L66 58', 7), Ln('M132 102L176 64', 7),
    Ln('M110 156L94 214', 7), Ln('M130 156L152 208', 7),
    S(rr(106, 86, 28, 52, 10), K.pink, -40),
    S('M62 160Q120 116 178 160Q120 184 62 160Z', K.pink, 40),
    S(circ(120, 58, 28), '#F6C89A', -35),
    ...eye(110, 56, 12), ...eye(132, 56, 12), Ln('M110 70Q121 78 132 70', 3.5),
    B(circ(196, 118, 10)), Ln('M206 118V84L220 92', 4),
    B(circ(38, 122, 9)), Ln('M47 122V92L60 98', 4),
  ],
  actStory: [
    S('M40 44H200A20 20 0 0 1 220 64V150A20 20 0 0 1 200 170H112L76 206L86 170H40A20 20 0 0 1 20 150V64A20 20 0 0 1 40 44Z', K.sky, -40),
    S(star(80, 106, 30, 13), K.yellow, 30),
    S('M128 146V102H140V90H152V102H164V90H176V102H188V146Z', K.pink, -45),
    S(rr(150, 120, 16, 26, 7), K.white, 0),
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
    Ln('M120.0 88.0L120.0 51.6 M146.6 107.3L181.2 96.1 M136.5 138.7L157.9 168.1 M103.5 138.7L82.1 168.1 M93.4 107.3L58.8 96.1', 4),
    B('M120.0 88.0L146.6 107.3L136.5 138.7L103.5 138.7L93.4 107.3Z'),
    B('M120.0 55.6L107.6 46.7L112.4 32.1L127.6 32.1L132.4 46.7Z'), B('M177.4 97.3L182.1 82.8L197.4 82.8L202.1 97.3L189.8 106.3Z'), B('M155.5 164.8L170.8 164.8L175.5 179.4L163.1 188.3L150.8 179.4Z'), B('M84.5 164.8L89.2 179.4L76.9 188.3L64.5 179.4L69.2 164.8Z'), B('M62.6 97.3L50.2 106.3L37.9 97.3L42.6 82.8L57.9 82.8Z'),
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
    S('M88 40L36 70l22 42 26-10v100h72V102l26 10 22-42-52-30a32 32 0 0 1-64 0Z', K.purple, -50),
    S(star(98, 140, 14, 6), K.yellow, 30), S(star(144, 174, 12, 5), K.yellow, -30),
    S('M150 120A16 16 0 1 0 150 150A12 12 0 1 1 150 120Z', K.yellow, 0),
  ],
  teddy: [
    S(circ(120, 182, 46), '#C08A5A', -40),
    S(circ(76, 60, 20), '#C08A5A', 30), S(circ(164, 60, 20), '#C08A5A', -30),
    S(circ(120, 100, 54), '#C08A5A', -35),
    S(circ(120, 120, 22), '#F1D3B0', 0),
    ...eye(98, 94, 14), ...eye(142, 94, 14), B(circ(120, 112, 7)), Ln('M110 128Q120 136 130 128', 3.5),
  ],
  // Toddler items
  milk: [
    S('M66 40H174L160 208H80Z', K.white, 0),
    S('M72 96H168L159 208H81Z', K.sky, -50),
    Ln('M70 96H170', 4),
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
      out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 1.3, bowing: 1.6, stroke: INK, strokeWidth: 5, disableMultiStroke: true, fill: l.color === K.white ? K.white : undefined, fillStyle: 'solid' }));
    } else if (l.kind === 'eye') {
      out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 0.8, stroke: INK, strokeWidth: 3.5, disableMultiStroke: true, fill: K.white, fillStyle: 'solid' }));
    } else if (l.kind === 'solid') {
      out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 1, stroke: INK, strokeWidth: 3, disableMultiStroke: true, fill: INK, fillStyle: 'solid' }));
    } else if (l.kind === 'line') {
      out += toSvg(gen.path(l.d, { seed: nextSeed(), roughness: 1.2, bowing: 1.5, stroke: INK, strokeWidth: l.w, disableMultiStroke: true }));
    }
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}">${out}</svg>\n`;
}

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

// Optional: the style-free shape definitions, so an app-side renderer can draw the same pictures
// in any style (crayon today, others later) without a separate SVG set per style.
if (shapesOut) {
  const items = {};
  for (const [name, layers] of Object.entries(ITEMS)) {
    items[name] = layers.map((l) => {
      if (l.kind === 'shape') return { kind: 'shape', d: l.d, color: l.color, hatchAngle: l.angle };
      if (l.kind === 'line') return { kind: 'line', d: l.d, width: l.w };
      return { kind: 'solid', d: l.d };                 // 'solid' and 'eye' both render as filled marker shapes
    });
  }
  const shapes = {
    version: 1,
    viewBox: SIZE,
    ink: INK,
    palette: K,
    seed: 'FNV-1a 32-bit of the slot name, mod 2147483000, plus 1; each layer step adds 13',
    styles: {
      crayon: {
        wash: { opacity: 0.28, roughness: 2.2, bowing: 2, offset: [3, 2] },
        hachure: { roughness: 2.4, bowing: 2, gap: 4.2, weight: 2.8, offset: [3, 2] },
        outline: { roughness: 1.3, bowing: 1.6, width: 5 },
        solid: { roughness: 1, width: 3 },
        line: { roughness: 1.2, bowing: 1.5 },
      },
    },
    items,
  };
  fs.writeFileSync(shapesOut, `${JSON.stringify(shapes, null, 1)}\n`);
  console.log('wrote', shapesOut);
}
