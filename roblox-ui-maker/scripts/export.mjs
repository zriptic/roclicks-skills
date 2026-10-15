// HTML -> Roblox, step 1 of 4: dump each page's layout tree and screenshot every raster piece
// (art only, transparent background, 2x) in isolation.
//
// Usage (run from the project's UI folder, i.e. the folder holding rbx.json, with its preview
// server running on rbx.json's "port"):
//     node $SK/scripts/export.mjs            # every page in rbx.json
//     node $SK/scripts/export.mjs shop hud   # just these pages
//
// Reads  rbx.json  (see PIPELINE.md): {"port", "design":[W,H], "screens":[{"page":...}], "templates":[...]}
// Writes rbx/out/<page>.json   layout tree (from dump.js)
//        rbx/out/raw/<page>_<rid>.png   one transparent 2x PNG per raster node
// Pages are loaded as http://127.0.0.1:<port>/<page>.html?raw  (?raw = 1:1, no preview zoom).
// Page height: a page may set <div id="stage" style="height:NNNpx">; it is read automatically.
import fs from 'node:fs';
import path from 'node:path';
import { launch, SETTLE } from './cdp.mjs';

const HERE = path.dirname(new URL(import.meta.url).pathname);
const CFG = JSON.parse(fs.readFileSync('rbx.json', 'utf8'));
const [W, H] = CFG.design || [1920, 1080];
const OUT = path.resolve('rbx', 'out'); fs.mkdirSync(path.join(OUT, 'raw'), { recursive: true });
const all = [...new Set([...(CFG.screens || []).map(s => s.page), ...(CFG.screens || []).flatMap(s => (s.groups || []).filter(g => typeof g === 'object').map(g => g.page)), ...(CFG.templates || [])])];
const PAGES = process.argv.slice(2).length ? process.argv.slice(2) : all;
const DUMP = fs.readFileSync(path.join(HERE, 'dump.js'), 'utf8');
// isolation mode: hide everything except the raster element itself (its text/icon children stay
// hidden: they are exported as live nodes) (and SVG pattern/defs content,
// or pattern fills vanish); "hid" elements are forced visible so hidden states still get art.
const ISO = `(() => { const s = document.createElement('style'); s.id='isocss'; s.textContent =
  'html.iso,html.iso body,html.iso #stage{background:transparent!important} html.iso body *{visibility:hidden!important;animation:none!important;transition:none!important}' +
  ' html.iso body .iso-on,html.iso body pattern *,html.iso body defs *{visibility:visible!important}' +
  ' html.iso .hid{opacity:1!important}';
  document.head.appendChild(s); return 1; })()`;

const b = await launch(9333, W, H);
let total = 0;
try {
  for (const pg of PAGES) {
    await b.size(W, H);
    await b.goto(`http://127.0.0.1:${CFG.port}/${pg}.html?raw`);
    const st = await b.eval(`(() => { const s = document.getElementById('stage'); return s ? s.offsetHeight : ${H}; })()`);
    if (st !== H) { await b.size(W, st); await b.goto(`http://127.0.0.1:${CFG.port}/${pg}.html?raw`); }
    const broken = await b.eval(SETTLE);
    if (broken) console.warn(`WARN ${pg}: ${broken} broken image(s) - check the paths (icons/<slug>.png) before trusting this export`);
    await b.eval(ISO);
    const tree = await b.eval(DUMP);
    // art that is tinted at runtime (ImageColor3) is captured white: pages can read --tint-capture
    await b.eval(`(() => { document.documentElement.classList.add('capture'); return 1; })()`);
    fs.writeFileSync(path.join(OUT, pg + '.json'), JSON.stringify(tree));
    const rasters = [];
    const visit = n => { if (n.k === 'raster') rasters.push(n); (n.ch || []).forEach(visit); };
    tree.forEach(visit);
    for (const r of rasters) {
      const m = r.m || [0, 0, 0, 0];
      const clip = { x: r.r[0] - m[0], y: r.r[1] - m[1], width: r.r[2] + m[0] + m[2], height: r.r[3] + m[1] + m[3] };
      await b.eval(`(() => { document.documentElement.classList.add('iso');
        document.querySelectorAll('[data-rid="${r.rid}"]').forEach(e => e.classList.add('iso-on')); return 1; })()`);
      await b.shot(path.join(OUT, 'raw', `${pg}_${r.rid}.png`), clip, 2);
      await b.eval(`(() => { document.documentElement.classList.remove('iso');
        document.querySelectorAll('.iso-on').forEach(e => e.classList.remove('iso-on')); return 1; })()`);
    }
    total += rasters.length;
    console.log(pg, 'groups', tree.length, 'rasters', rasters.length);
  }
} finally { b.close(); }
console.log('done:', PAGES.length, 'page(s),', total, 'raster(s) -> rbx/out/. Next: python3 .../scripts/gen.py');
