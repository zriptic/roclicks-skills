// Layout dump, injected into a kit page by export.mjs (not run directly).
//
// Walks every top-level `.grp` wrapper (see PIPELINE.md "Export markers") and returns a JSON
// tree of Roblox-ready nodes in absolute stage px. Kinds:
//   group  {n, a(anchor), ch}          from grp(name, html, anchor)
//   sub    {n, btn, ch}                from sub(name, html, btn)   (invisible named frame = union of kids)
//   text   outlined (.ot) or plain text
//   icon   <img> (icons/<slug>.png); filters other than brightness turn it into a raster
//   frame  a div with native-drawable looks (bg colour, linear gradient, border, radius, box-shadow)
//   raster anything Roblox cannot draw natively: stud plates (.plate / overlay-blend stud child),
//          clip-path shapes, url() backgrounds, SVG shapes (clustered). export.mjs screenshots each
//          one ALONE (data-rid) at 2x with a transparent background.
//   line   SVG <line> (drawn as a rotated Frame)
// Attributes picked up: data-n (instance name), data-btn (TextButton + Button attribute),
// data-opens (attribute Opens = screen it toggles), data-col (tint for white-exported art),
// class "hid" or opacity:0 (exported but Visible = false).
(() => {
  let RID = 0;
  const num = s => parseFloat(s) || 0;
  const R = el => { const r = el.getBoundingClientRect(); return [r.left, r.top, r.width, r.height]; };
  const rgba = s => {
    const m = s && s.match(/rgba?\(([^)]+)\)/); if (!m) return null;
    const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
    return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
  };
  function splitTop(s) { // split on commas not inside parentheses
    const out = []; let d = 0, cur = '';
    for (const ch of s) {
      if (ch === '(') d++; if (ch === ')') d--;
      if (ch === ',' && d === 0) { out.push(cur.trim()); cur = ''; } else cur += ch;
    }
    if (cur.trim()) out.push(cur.trim()); return out;
  }
  function gradient(bg, w, h) {
    if (!bg || bg === 'none' || splitTop(bg).length > 1) return null; // layered backgrounds -> not native
    const m = bg.match(/^(linear|radial|conic)-gradient\((.*)\)$/); if (!m) return null;
    const type = m[1]; const parts = splitTop(m[2]);
    let angle = 180, first = parts[0];
    if (!/^rgb/.test(first)) {
      parts.shift();
      if (type === 'linear') {
        const a = first.match(/(-?[\d.]+)deg/); if (a) angle = +a[1];
        else if (/to bottom/.test(first)) angle = 180; else if (/to right/.test(first)) angle = 90;
        else if (/to top/.test(first)) angle = 0; else if (/to left/.test(first)) angle = 270;
      }
    }
    const len = type === 'linear' ? Math.abs(w * Math.sin(angle * Math.PI / 180)) + Math.abs(h * Math.cos(angle * Math.PI / 180)) : h;
    const stops = [];
    for (const p of parts) {
      const c = rgba(p); if (!c) continue;
      const rest = p.replace(/rgba?\([^)]*\)/, '').trim().split(/\s+/).filter(Boolean);
      const pos = rest.map(x => x.endsWith('%') ? num(x) / 100 : x.endsWith('deg') ? num(x) / 360 : num(x) / len);
      if (!pos.length) stops.push([null, c]); else for (const q of pos) stops.push([q, c]);
    }
    if (!stops.length) return null;
    // CSS rules: missing first/last -> 0/1; stops never go backwards; gaps interpolate.
    if (stops[0][0] === null) stops[0][0] = 0;
    if (stops[stops.length - 1][0] === null) stops[stops.length - 1][0] = 1;
    let mx = 0; for (const s of stops) if (s[0] !== null) { if (s[0] < mx) s[0] = mx; mx = s[0]; }
    for (let i = 0; i < stops.length; i++) if (stops[i][0] === null) {
      let j = i; while (stops[j][0] === null) j++;
      const a = stops[i - 1][0], b = stops[j][0];
      for (let k = i; k < j; k++) stops[k][0] = a + (b - a) * (k - i + 1) / (j - i + 1);
    }
    return { type, angle, stops };
  }
  function shadows(s) {
    if (!s || s === 'none') return [];
    return splitTop(s).map(p => {
      const c = rgba(p); const inset = /inset/.test(p);
      const n = p.replace(/rgba?\([^)]*\)/, '').replace('inset', '').trim().split(/\s+/).map(num);
      return { inset, x: n[0] || 0, y: n[1] || 0, blur: n[2] || 0, spread: n[3] || 0, c };
    });
  }
  function dropShadow(f) {
    const m = f && f.match(/drop-shadow\((rgba?\([^)]*\))\s*(-?[\d.]+)px\s+(-?[\d.]+)px\s+(-?[\d.]+)px\)/);
    return m ? { c: rgba(m[1]), x: +m[2], y: +m[3], blur: +m[4] } : null;
  }
  function ancestorDim(el) { // brightness/saturate filters on ancestors (locked plates) tint text
    let b = 1, sat = 1;
    for (let a = el.parentElement; a; a = a.parentElement) {
      const f = getComputedStyle(a).filter; if (!f || f === 'none') continue;
      const mb = f.match(/brightness\(([\d.]+)\)/); if (mb) b *= +mb[1];
      const ms = f.match(/saturate\(([\d.]+)\)/); if (ms) sat *= +ms[1];
    }
    return (b !== 1 || sat !== 1) ? [b, sat] : null;
  }
  function rotation(cs) {
    const t = cs.transform; if (!t || t === 'none') return 0;
    const m = t.match(/matrix\(([^)]+)\)/); if (!m) return 0;
    const [a, b, c, d] = m[1].split(',').map(Number);
    if (Math.abs(a - d) > 1e-3 || Math.abs(b + c) > 1e-3) return 0; // not a pure rotation
    return Math.atan2(b, a) * 180 / Math.PI;
  }
  function align(el) {
    for (let p = el.parentElement; p; p = p.parentElement) {
      const cs = getComputedStyle(p);
      if (cs.display.includes('flex')) return cs.justifyContent === 'center' ? 'C' : cs.justifyContent === 'flex-end' ? 'R' : 'L';
      if (cs.textAlign === 'center') return 'C'; if (cs.textAlign === 'right') return 'R';
      if (cs.position === 'absolute') return cs.textAlign === 'center' ? 'C' : cs.textAlign === 'right' ? 'R' : 'L';
    }
    return 'L';
  }
  function scaleOf(el) { // cumulative CSS scale (x, y) from el's own and ancestors' transforms
    let kx = 1, ky = 1;
    for (let a = el; a && a.nodeType === 1; a = a.parentElement) {
      const t = getComputedStyle(a).transform; if (!t || t === 'none') continue;
      const m = t.match(/matrix\(([^)]+)\)/); if (!m) continue;
      const [A, B, C, D] = m[1].split(',').map(Number);
      if (Math.abs(B) > 1e-3 || Math.abs(C) > 1e-3) continue; // rotations handled separately
      kx *= Math.abs(A); ky *= Math.abs(D);
    }
    return [kx, ky];
  }
  // y offset of the first hard text-shadow ("rgb(..) 0px 3px 0px") = the drop under outlined text
  const textDrop = cs => { const m = (cs.textShadow || '').match(/\)\s*(-?[\d.]+)px\s+(-?[\d.]+)px\s+(-?[\d.]+)px/); return m && +m[3] === 0 ? +m[2] : 0; };
  const hidden = (el, cs) => el.classList.contains('hid') || +cs.opacity === 0;
  const fam = cs => cs.fontFamily.split(',')[0].replace(/["']/g, '').trim();
  const iconName = src => { const m = src.match(/icons\/([\w-]+)\.png/); return m ? m[1] : null; };
  const markRaster = (...els) => { const id = 'r' + (++RID); for (const e of els) e.setAttribute('data-rid', id); return id; };
  const attrsOf = el => { const a = {}; if (el.dataset.opens) a.Opens = el.dataset.opens; return Object.keys(a).length ? a : undefined; };

  function textNode(el) {
    const cs = getComputedStyle(el);
    const [x, y, w, h] = R(el);
    const [kx, ky] = scaleOf(el);
    const after = getComputedStyle(el, '::after');
    const g = gradient(after.backgroundImage, el.offsetWidth, el.offsetHeight);
    const fs = num(cs.fontSize);
    const solid = rgba(after.color);
    return {
      k: 'text', n: el.dataset.n, t: el.dataset.t, r: [x, y, w, h], fs: fs * ky, sq: kx / ky,
      ff: fam(cs), wt: +cs.fontWeight,
      sw: num(cs.webkitTextStrokeWidth) * ky, dy: textDrop(cs) * ky,
      oc: rgba(cs.webkitTextStrokeColor), fill: g ? g.stops : null,
      color: (solid && solid[3] > 0) ? solid : [255, 255, 255, 1],
      lh: num(cs.lineHeight) || fs * 1.05, al: align(el), dim: ancestorDim(el), op: hidden(el, cs) ? 0 : 1,
    };
  }
  function plainText(tn, el) {
    const s = tn.textContent.trim(); if (!s) return null;
    const rg = document.createRange(); rg.selectNodeContents(tn);
    const r = rg.getBoundingClientRect(); if (!r.width) return null;
    const cs = getComputedStyle(el);
    return {
      k: 'text', t: s, r: [r.left, r.top, r.width, r.height], fs: num(cs.fontSize), sq: 1,
      ff: fam(cs), wt: +cs.fontWeight, sw: 0, dy: 0, oc: null,
      fill: null, color: rgba(cs.color), lh: r.height, al: 'L', dim: ancestorDim(el), op: hidden(el, cs) ? 0 : 1,
    };
  }
  function icon(el) {
    const cs = getComputedStyle(el);
    const f = cs.filter;
    const node = { k: 'icon', n: el.dataset.n, icon: iconName(el.src), r: R(el), op: hidden(el, cs) ? 0 : 1 };
    if (!node.icon) { // not a pack icon: rasterise it as art
      return { k: 'raster', rid: markRaster(el), n: el.dataset.n, r: R(el), m: [0, 0, 0, 0], why: 'img', op: node.op, ch: [] };
    }
    if (ancestorDim(el)) { // inside a desaturated (.off) plate: the icon must look desaturated too -> bake it
      return { k: 'raster', rid: markRaster(el), n: el.dataset.n, r: R(el), why: 'filtered-icon', op: node.op, m: [2, 2, 2, 5], ch: [], adim: true };
    }
    const bOnly = f && /brightness\(([\d.]+)\)/.exec(f);
    if (bOnly && !/grayscale|saturate/.test(f)) { node.tint = +bOnly[1]; node.sh = dropShadow(f); return node; }
    if (f && /grayscale|brightness|saturate/.test(f)) {
      const ds = dropShadow(f);
      return { k: 'raster', rid: markRaster(el), n: el.dataset.n, r: R(el), why: 'filtered-icon', op: node.op,
               m: [2, 2, 2, ds ? Math.max(2, ds.y + 2) : 2], ch: [] };
    }
    node.sh = dropShadow(f);
    return node;
  }

  function svgNodes(svg) {
    const out = []; const sr = svg.getBoundingClientRect();
    const shapes = [];
    for (const e of svg.querySelectorAll('line,polygon,polyline,rect,path,circle,ellipse')) {
      if (e.closest('defs,pattern,mask,clipPath')) continue;
      const cs = getComputedStyle(e);
      if (e.tagName === 'line') {
        const a = n => num(e.getAttribute(n));
        out.push({ k: 'line', n: e.dataset.n, p: [sr.left + a('x1'), sr.top + a('y1'), sr.left + a('x2'), sr.top + a('y2')], c: rgba(cs.stroke), sw: num(cs.strokeWidth), cap: cs.strokeLinecap });
      } else shapes.push(e);
    }
    // every other shape: cluster by centre (6px grid) and rasterise each cluster as one image
    const clusters = new Map();
    for (const e of shapes) {
      const r = e.getBoundingClientRect(); const key = Math.round((r.left + r.width / 2) / 6) + ',' + Math.round((r.top + r.height / 2) / 6);
      if (!clusters.has(key)) clusters.set(key, []);
      clusters.get(key).push(e);
    }
    for (const els of clusters.values()) {
      let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, sw = 0;
      for (const e of els) { const r = e.getBoundingClientRect(); x0 = Math.min(x0, r.left); y0 = Math.min(y0, r.top); x1 = Math.max(x1, r.right); y1 = Math.max(y1, r.bottom); sw = Math.max(sw, num(getComputedStyle(e).strokeWidth)); }
      const pad = Math.ceil(sw / 2 + 2);
      const named = els.find(e => e.dataset && e.dataset.n);
      const tint = els.find(e => e.dataset && e.dataset.col);
      out.push({ k: 'raster', rid: markRaster(...els), n: named ? named.dataset.n : undefined, tint: tint ? tint.dataset.col : undefined,
                 r: [x0, y0, x1 - x0, y1 - y0], m: [pad, pad, pad, pad], why: 'svg', ch: [] });
    }
    return out;
  }

  function hasVisual(cs, el) {
    return (rgba(cs.backgroundColor) || [0, 0, 0, 0])[3] > 0 || cs.backgroundImage !== 'none' ||
      num(cs.borderTopWidth) > 0 || (cs.boxShadow && cs.boxShadow !== 'none') ||
      (cs.outlineStyle !== 'none' && num(cs.outlineWidth) > 0);
  }

  function walk(el) {
    if (el.nodeType !== 1) return [];
    if (el.matches('.rbx,.world,.cap,script,style')) return [];   // placeholders / stand-in world / captions are not UI
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden') return [];
    if (el.tagName === 'svg') return svgNodes(el);
    if (el.tagName === 'IMG') return [icon(el)];
    if (el.classList.contains('ot')) return [textNode(el)];
    const kids = () => {
      const out = [];
      for (const c of el.childNodes) {
        if (c.nodeType === 3) { const t = plainText(c, el); if (t) out.push(t); }
        else out.push(...walk(c));
      }
      return out;
    };
    if (el.classList.contains('grp')) return [{ k: 'group', n: el.dataset.g, a: el.dataset.a, ch: kids() }];
    if (el.classList.contains('sub')) return [{ k: 'sub', n: el.dataset.n, btn: !!el.dataset.btn, attrs: attrsOf(el), op: hidden(el, cs) ? 0 : 1, ch: kids() }];

    const [x, y, w, h] = R(el);
    const rot = rotation(cs);
    const ow = el.offsetWidth, oh = el.offsetHeight;
    const k = rot ? 1 : scaleOf(el)[1];
    const box = rot ? [x + w / 2 - ow / 2, y + h / 2 - oh / 2, ow, oh] : [x, y, w, h];
    const sh = shadows(cs.boxShadow);
    // ---- raster?
    const studKid = [...el.children].find(c => /url\(/.test(getComputedStyle(c).backgroundImage) && getComputedStyle(c).mixBlendMode === 'overlay');
    const isPlate = el.classList.contains('plate');
    const clipPath = cs.clipPath && cs.clipPath !== 'none';
    const layered = cs.backgroundImage !== 'none' && splitTop(cs.backgroundImage).length > 1;
    if (isPlate || studKid || clipPath || layered || /url\(/.test(cs.backgroundImage) || (cs.filter && cs.filter !== 'none' && hasVisual(cs, el))) {
      const els = studKid ? [el, studKid] : [el];
      const id = markRaster(...els);
      let m = [0, 0, 0, 0];
      for (const s of sh) if (!s.inset) {
        const b = s.blur + s.spread;
        m = [Math.max(m[0], b - s.x), Math.max(m[1], b - s.y), Math.max(m[2], b + s.x), Math.max(m[3], b + s.y)];
      }
      m = m.map(v => Math.ceil(Math.max(0, v)));
      let stud = null;
      if (isPlate) {
        const b = getComputedStyle(el, '::before');
        const P = num(b.backgroundSize) * k; const bw = num(cs.borderLeftWidth) * k;
        if (P > 0) stud = { P, x0: bw + num(b.backgroundPositionX) * k };
      } else if (studKid) {
        const b = getComputedStyle(studKid); const P = num(b.backgroundSize) * k;
        if (P > 0) stud = { P, x0: studKid.getBoundingClientRect().left - x + num(b.backgroundPositionX) * k };
      }
      const node = { k: 'raster', rid: id, n: el.dataset.n, r: box, m, stud, plate: isPlate, head: el.classList.contains('head'),
        close: el.classList.contains('closeb'), btn: !!el.dataset.btn, attrs: attrsOf(el), why: isPlate ? 'plate' : 'art',
        op: hidden(el, cs) ? 0 : 1, ch: [] };
      for (const c of el.childNodes) {
        if (c === studKid) continue;
        if (c.nodeType === 3) { const t = plainText(c, el); if (t) node.ch.push(t); } else node.ch.push(...walk(c));
      }
      return [node];
    }
    const children = kids();
    const named = el.dataset.n;
    if (!hasVisual(cs, el) && !named && !rot && !el.dataset.btn && !hidden(el, cs)) return children; // hoist invisible wrappers
    const node = { k: 'frame', n: named, r: box, rot, ch: children, op: hidden(el, cs) ? 0 : 1 };
    node.cls = typeof el.className === 'string' ? el.className : '';
    const bg = rgba(cs.backgroundColor); if (bg && bg[3] > 0) node.bg = bg;
    if (cs.backgroundImage !== 'none') node.grad = gradient(cs.backgroundImage, ow, oh);
    const bw = num(cs.borderTopWidth); if (bw > 0) { node.bw = bw * k; node.bc = rgba(cs.borderTopColor); node.bs = cs.borderTopStyle; }
    const rad = cs.borderTopLeftRadius;
    node.rad = rad.endsWith('%') ? { s: num(rad) / 100 } : { o: num(rad) * k };
    if (sh.length) node.sh = sh.map(s => ({ ...s, x: s.x * k, y: s.y * k, spread: s.spread * k, blur: s.blur * k }));
    if (cs.overflow === 'hidden') node.clip = true;
    if (cs.outlineStyle !== 'none' && num(cs.outlineWidth) > 0) node.outline = { w: num(cs.outlineWidth), off: num(cs.outlineOffset), c: rgba(cs.outlineColor) };
    if (el.dataset.btn) node.btn = true;
    node.attrs = attrsOf(el);
    return [node];
  }

  const groups = [];
  for (const g of document.querySelectorAll('.grp')) {
    if (g.parentElement.closest('.grp')) continue;
    groups.push(...walk(g));
  }
  return groups;
})()
