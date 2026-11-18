// Boots build/web in headless Chromium and checks the game starts: the engine banner prints, no page errors or
// console errors appear, and a full screen draws. Saves build/web_smoke.png. Node + Playwright (browser automation
// has no standard-library route). Usage: node tools/web_smoke.mjs [build/web] [--chrome]  (--chrome: use the
// system Chrome, as on GitHub runners). Quiet: prints problems, then one "WEB smoke PASS|FAIL ..." line.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const dir = resolve(process.argv.find((a, i) => i > 1 && !a.startsWith('--')) ?? 'build/web');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const BOOT_LIMIT_MS = 30000;
const server = createServer(async (req, res) => {
  try {
    const path = join(dir, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    const body = await readFile(path);
    res.writeHead(200, { 'Content-Type': TYPES[extname(path)] ?? 'application/octet-stream' });
    res.end(body);
  } catch { res.writeHead(404); res.end(); }
}).listen(0);
const port = server.address().port;
const browser = await chromium.launch({
  channel: process.argv.includes('--chrome') ? 'chrome' : undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const t0 = Date.now();
let banner = -1;
const problems = [];
page.on('console', (m) => {
  if (banner < 0 && m.text().startsWith('Godot Engine')) banner = Date.now() - t0;
  if (m.type() === 'error') problems.push(`console error: ${m.text().slice(0, 200)}`);
});
page.on('pageerror', (e) => problems.push(`page error: ${String(e).slice(0, 200)}`));
await page.goto(`http://localhost:${port}/index.html`);
// "Full screen drawn" = a 1280x720 screenshot over FULL_BYTES: Godot's loading page compresses to a few tens of KB,
// the shop frame to about 245 KB. Each software-GL screenshot takes about 0.9 s, so times are to about 1 s.
const FULL_BYTES = 100000;
let first = -1;
while (Date.now() - t0 < BOOT_LIMIT_MS) {
  const n = (await page.screenshot()).length;
  if (n > FULL_BYTES) { first = Date.now() - t0; break; }
  await page.waitForTimeout(100);
}
await page.waitForTimeout(2000);  // errors that follow the first frame
await page.screenshot({ path: join(dir, '..', 'web_smoke.png') });
await browser.close();
server.close();
if (banner < 0) problems.push('no engine banner');
if (first < 0) problems.push(`no full screen within ${BOOT_LIMIT_MS / 1000} s`);
for (const p of problems) console.log(p);
console.log(`WEB smoke ${problems.length ? 'FAIL' : 'PASS'} banner_ms=${banner} first_screen_ms=${first} problems=${problems.length}`);
process.exit(problems.length ? 1 : 0);
