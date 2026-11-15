// Injected by relations.py into a locally rendered board (preview/r-<Board>.html). Collects every part box
// with what is needed to tell its kind (classes, role, art id, size) and, where the art is local, the box the
// crayon ink actually covers (alpha bbox of the background / 9-slice art drawn at the element's size).
// Writes JSON to body[data-rel]. Board units = CSS px at 1376 x 1032.
window.addEventListener('load', () => setTimeout(async () => { try {
  const root = document.querySelector('x-dc > div') || document.querySelector('body > div');
  const R = e => { const r = e.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; };
  const glyph = e => { const g = document.createRange(); g.selectNodeContents(e); const r = g.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; };
  const vis = e => { const r = e.getBoundingClientRect(); if (r.width < 8 || r.height < 8) return false; const cs = getComputedStyle(e); return cs.visibility !== 'hidden' && cs.display !== 'none' && +cs.opacity > 0.05; };
  const clipped = e => { let p = e.parentElement; const b = e.getBoundingClientRect(); while (p && p !== root) { const cs = getComputedStyle(p); if (cs.overflow === 'hidden') { const a = p.getBoundingClientRect(); if (b.bottom <= a.top || b.top >= a.bottom || b.right <= a.left || b.left >= a.right) return true; } p = p.parentElement; } return false; };
  const urlOf = s => { const m = /url\("?([^")]+)"?\)/.exec(s || ''); return m ? m[1] : null; };
  const own = e => [...e.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent).join(' ').replace(/\s+/g, ' ').trim();
  const out = [], seen = new Set();
  function rec(e, cat, extra) {
    const cs = getComputedStyle(e);
    const o = { cat, tag: e.tagName.toLowerCase(), cls: (e.className && e.className.baseVal === undefined ? e.className : '') + '',
      role: e.getAttribute('role') || '', aria: e.getAttribute('aria-label') || '', pressed: e.getAttribute('aria-pressed') || e.getAttribute('aria-checked') || '',
      text: (e.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 40), ...R(e), font: parseFloat(cs.fontSize),
      bg: urlOf(cs.backgroundImage), bi: urlOf(cs.borderImageSource), biSlice: cs.borderImageSlice, biWidth: cs.borderImageWidth,
      bw: [cs.borderTopWidth, cs.borderRightWidth, cs.borderBottomWidth, cs.borderLeftWidth].map(parseFloat),
      parentRole: (e.parentElement && e.parentElement.getAttribute('role')) || '', parentAria: (e.parentElement && e.parentElement.getAttribute('aria-label')) || '',
      inHeader: !!e.closest('[data-rel-header]'), idx: all.indexOf(e),
      pad: [cs.paddingTop, cs.paddingRight, cs.paddingBottom, cs.paddingLeft].map(parseFloat),
      anc: +((e.parentElement && e.parentElement.closest('[data-rel-card]') || { getAttribute: () => 0 }).getAttribute('data-rel-card')) || 0, ...extra };
    // a ring: an absolutely placed child picture bigger than the part (the S1 / C3 "picked" ring)
    const ring = [...e.querySelectorAll(':scope > img')].find(i => { const a = i.getBoundingClientRect(), b = e.getBoundingClientRect(); return a.width > b.width + 2 && getComputedStyle(i).position === 'absolute'; });
    if (ring) o.ring = { ...R(ring), src: ring.getAttribute('src') };
    o.imgs = [...e.querySelectorAll('img')].filter(i => i !== ring && !i.closest('[role=img]')).map(i => { const r = i.getBoundingClientRect(); return [r.width, r.height]; }).filter(([w]) => w >= 16);
    o.faces = [...e.querySelectorAll('[role=img]')].map(i => { const r = i.getBoundingClientRect(); return [r.width, r.height]; });
    out.push(o); return o;
  }
  const take = (e, cat, extra, keepKids) => { if (seen.has(e) || !vis(e) || clipped(e)) return null; seen.add(e); const o = rec(e, cat, extra); if (!keepKids) e.querySelectorAll('*').forEach(c => seen.add(c)); return o; };
  // the header row: the first flex row at the top (y 44..124 on grown-up boards)
  [...root.children].forEach(c => { const r = c.getBoundingClientRect(); if (r.top < 60 && r.bottom <= 140 && r.width > 600) c.setAttribute('data-rel-header', '1'); });
  const all = [...root.querySelectorAll('*')]; let cardNo = 0;
  const hasArt = e => { const cs = getComputedStyle(e); return !!(urlOf(cs.backgroundImage) || urlOf(cs.borderImageSource)); };
  // 1. cards (containers; their contents stay)
  all.forEach(e => { if (!hasArt(e)) return; const r = e.getBoundingClientRect(); const cls = (e.className || '') + '';
    const card = /card/.test(cls) || (urlOf(getComputedStyle(e).borderImageSource) && r.width >= 300 && r.height >= 150) || (r.width >= 400 && r.height >= 200);
    if (card) { const o = take(e, 'card', { kids: e.children.length }, true); if (o) { o.cardNo = ++cardNo; e.setAttribute('data-rel-card', cardNo); } } });
  // 2. switches, then every other part with art, and links / buttons / radios without art
  root.querySelectorAll('[role=switch]').forEach(e => take(e, 'part', {}));
  all.forEach(e => { if (!seen.has(e) && hasArt(e)) { const r = e.getBoundingClientRect(); if (r.width >= 20 && r.height >= 20) take(e, 'part', {}); } });
  root.querySelectorAll('a, button, [role=radio], [role=tab], [role=checkbox]').forEach(e => take(e, 'part', {}));
  // 3. labels, title, pictures, leaf text
  root.querySelectorAll('.lbl').forEach(e => take(e, 'label', { glyph: glyph(e) }));
  root.querySelectorAll('h1').forEach(e => take(e, 'title', { glyph: glyph(e) }));
  root.querySelectorAll('img, [role=img]').forEach(e => { const r = e.getBoundingClientRect(); if (r.width >= 28 && r.width < 400) take(e, 'picture', {}); });
  root.querySelectorAll('span, p, div').forEach(e => { if (own(e)) take(e, 'text', { glyph: glyph(e), own: own(e).slice(0, 40) }, true); });
  // 4. ink boxes of the art, drawn as the browser draws it (stretch, or 9-slice)
  const cache = {};
  const load = src => cache[src] || (cache[src] = new Promise(res => { const i = new Image(); i.onload = () => res(i); i.onerror = () => res(null); i.src = src; }));
  const K = 2;
  async function ink(o) {
    const src = o.bi || o.bg; if (!src || src.includes('missing')) return null;
    const img = await load(src); if (!img || !img.naturalWidth) return null;
    const W = Math.round(o.w * K), H = Math.round(o.h * K); if (W < 2 || H < 2) return null;
    const c = document.createElement('canvas'); c.width = W; c.height = H; const g = c.getContext('2d');
    const iw = img.naturalWidth, ih = img.naturalHeight;
    if (o.bi) {
      const sl = o.biSlice.replace('fill', '').trim().split(/\s+/).map(parseFloat); const [st, sr, sb, sL] = [sl[0], sl[1] ?? sl[0], sl[2] ?? sl[0], sl[3] ?? sl[1] ?? sl[0]];
      const wd = o.biWidth.split(/\s+/).map(v => v.endsWith('px') ? parseFloat(v) : null);
      const [wt, wr, wb, wl] = [wd[0], wd[1] ?? wd[0], wd[2] ?? wd[0], wd[3] ?? wd[1] ?? wd[0]].map((v, i) => (v ?? o.bw[i]) * K);
      const sx = [0, sL, iw - sr, iw], sy = [0, st, ih - sb, ih], dx = [0, wl, W - wr, W], dy = [0, wt, H - wb, H];
      for (let a = 0; a < 3; a++) for (let b = 0; b < 3; b++) { const w0 = sx[a + 1] - sx[a], h0 = sy[b + 1] - sy[b], w1 = dx[a + 1] - dx[a], h1 = dy[b + 1] - dy[b]; if (w0 > 0 && h0 > 0 && w1 > 0 && h1 > 0) g.drawImage(img, sx[a], sy[b], w0, h0, dx[a], dy[b], w1, h1); }
    } else g.drawImage(img, 0, 0, W, H);
    let d; try { d = g.getImageData(0, 0, W, H).data; } catch (err) { return { err: 'tainted' }; }
    const A = 96, col = new Array(W).fill(0), row = new Array(H).fill(0);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (d[(y * W + x) * 4 + 3] > A) { col[x]++; row[y]++; }
    const need = 2; let l = col.findIndex(v => v >= need), r = W - 1 - [...col].reverse().findIndex(v => v >= need), t = row.findIndex(v => v >= need), b = H - 1 - [...row].reverse().findIndex(v => v >= need);
    if (l < 0 || t < 0) return null;
    return { l: l / K, t: t / K, r: (W - 1 - r) / K, b: (H - 1 - b) / K };
  }
  for (const o of out) if (o.cat === 'part' || o.cat === 'card') o.ink = await ink(o);
  document.body.setAttribute('data-rel', JSON.stringify(out));
} catch (err) { document.body.setAttribute('data-rel', JSON.stringify([{ cat: 'ERR', text: String(err) + ' ' + err.stack }])); } }, 1500));
