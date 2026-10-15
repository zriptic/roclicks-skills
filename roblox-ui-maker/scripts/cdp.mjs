// Minimal Chrome DevTools Protocol driver (no puppeteer, no npm install): launches headless
// Google Chrome, opens pages, evaluates JS, takes clipped transparent screenshots.
// Library used by export.mjs and mockshot.mjs; not run directly.
//
//   import { launch } from './cdp.mjs';
//   const b = await launch(9333, 1920, 1080);  await b.goto(url);  await b.eval('1+1');
//   await b.shot('out.png', {x, y, width, height}, 2);  b.close();
//
// Needs Node 22+ (global fetch + WebSocket). Chrome path: env CHROME, else the macOS default.
import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

export async function launch(port = 9333, W = 1920, H = 1080) {
  if (!fs.existsSync(CHROME)) throw new Error('Chrome not found at ' + CHROME + ' (set env CHROME)');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cdp-'));
  const proc = spawn(CHROME, [
    '--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${dir}`,
    '--hide-scrollbars', `--window-size=${W},${H}`, '--disable-features=LazyImageLoading,LazyFrameLoading',
    '--force-device-scale-factor=1', 'about:blank'], { stdio: 'ignore' });
  let ws;
  for (let i = 0; i < 50; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const pg = list.find(t => t.type === 'page');
      if (pg) { ws = pg.webSocketDebuggerUrl; break; }
    } catch { }
    await sleep(200);
  }
  if (!ws) { proc.kill(); throw new Error('chrome did not start (is another one using port ' + port + '?)'); }
  const sock = new WebSocket(ws);
  await new Promise((res, rej) => { sock.onopen = res; sock.onerror = rej; });
  let id = 0; const pending = new Map(); const waiters = [];
  sock.onmessage = ev => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) {
      const { res, rej } = pending.get(m.id); pending.delete(m.id);
      m.error ? rej(new Error(m.error.message)) : res(m.result);
    } else if (m.method) {
      for (const w of [...waiters]) if (w.method === m.method) { waiters.splice(waiters.indexOf(w), 1); w.res(m.params); }
    }
  };
  const send = (method, params = {}) => new Promise((res, rej) => {
    const i = ++id; pending.set(i, { res, rej }); sock.send(JSON.stringify({ id: i, method, params }));
  });
  const once = method => new Promise(res => waiters.push({ method, res }));
  await send('Page.enable'); await send('Runtime.enable');
  const api = {
    send,
    async size(w, h) {
      await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false });
    },
    async goto(url) {
      const loaded = once('Page.loadEventFired');
      await send('Page.navigate', { url }); await loaded;
    },
    async eval(expr) {
      const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
      if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 800));
      return r.result.value;
    },
    async shot(file, clip, scale = 2, bg = { r: 0, g: 0, b: 0, a: 0 }) {
      await send('Emulation.setDefaultBackgroundColorOverride', { color: bg });
      const r = await send('Page.captureScreenshot', { format: 'png', clip: { ...clip, scale }, captureBeyondViewport: true });
      fs.writeFileSync(file, Buffer.from(r.data, 'base64'));
    },
    close() { try { sock.close(); } catch { } proc.kill(); },
  };
  await api.size(W, H);
  return api;
}

// Wait for fonts + every <img> (retrying broken ones with a cache-buster). Returns the count still broken.
export const SETTLE = `(async () => { await document.fonts.ready;
  for (let t = 0; t < 20; t++) {
    await Promise.all([...document.images].map(i => i.decode().catch(() => 0)));
    const bad = [...document.images].filter(i => !i.naturalWidth);
    if (!bad.length) break;
    bad.forEach(i => { const u = i.getAttribute('src').split('?')[0]; i.src = u + '?t=' + t; });
    await new Promise(r => setTimeout(r, 300));
  }
  const urls = new Set();
  for (const e of document.querySelectorAll('*')) {
    for (const p of [getComputedStyle(e).backgroundImage, getComputedStyle(e, '::before').backgroundImage]) {
      (p.match(/url\\("?([^")]+)"?\\)/g) || []).forEach(u => urls.add(u.replace(/url\\("?|"?\\)/g, '')));
    }
  }
  await Promise.all([...urls].map(u => new Promise(r => { const i = new Image(); i.onload = i.onerror = r; i.src = u; })));
  await new Promise(r => setTimeout(r, 400));
  return [...document.images].filter(i => !i.naturalWidth).length; })()`;
