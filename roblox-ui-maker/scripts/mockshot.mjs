// Render each screen three ways for the offline mock check (run mock.py first):
//   ref_<Screen>.png   the HTML page with only that screen's groups (+ its Dim) visible
//   bg_<Screen>.png    the same page with every group hidden (just the stand-in world)
//   mock_<Screen>.png  rbx/out/mock/<Screen>.html (Roblox semantics) on a transparent background
// then runs mockdiff.py, which composites mock over bg and scores it against ref.
// Usage (from the project's UI folder, preview server running):
//     node $SK/scripts/mockshot.mjs [Screen ...]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { launch, SETTLE } from './cdp.mjs';

const HERE = path.dirname(new URL(import.meta.url).pathname);
const CFG = JSON.parse(fs.readFileSync('rbx.json', 'utf8'));
const [W, H] = CFG.design || [1920, 1080];
const OUT = path.resolve('rbx', 'out', 'mock');
const want = process.argv.slice(2);
const screens = CFG.screens.filter(s => !want.length || want.includes(s.name));
const base = `http://127.0.0.1:${CFG.port}`;
const b = await launch(9334, W, H);
const full = { x: 0, y: 0, width: W, height: H };
try {
  for (const s of screens) {
    const keep = JSON.stringify([...s.groups.filter(g => typeof g === 'string'), 'Dim']);
    await b.goto(`${base}/${s.page}.html?raw`); await b.eval(SETTLE);
    await b.eval(`(() => { const k = ${keep}; document.querySelectorAll('.grp').forEach(g => { if (!k.includes(g.dataset.g)) g.style.display = 'none'; }); return 1; })()`);
    await b.shot(path.join(OUT, `ref_${s.name}.png`), full, 1, { r: 0, g: 0, b: 0, a: 1 });
    await b.eval(`(() => { document.querySelectorAll('.grp').forEach(g => g.style.display = 'none'); return 1; })()`);
    await b.shot(path.join(OUT, `bg_${s.name}.png`), full, 1, { r: 0, g: 0, b: 0, a: 1 });
    await b.goto(`${base}/rbx/out/mock/${s.name}.html`); await b.eval(SETTLE);
    await b.shot(path.join(OUT, `mock_${s.name}.png`), full, 1);
    console.log('rendered', s.name);
  }
} finally { b.close(); }
execFileSync('python3', [path.join(HERE, 'mockdiff.py'), ...screens.map(s => s.name)], { stdio: 'inherit' });
