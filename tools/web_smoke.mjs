// Boots build/web in headless Chromium and checks the game starts: the engine banner prints, no page errors or
// console errors appear, the game signals ready, and the screen is not blank. Saves build/web_smoke.png. Node + Playwright (browser automation
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
const BOOT_LIMIT_MS = Number(process.env.SMOKE_TIMEOUT_MS ?? 30000);
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
const log = [];
page.on('console', (m) => {
  log.push(`${Date.now() - t0} ${m.type()} ${m.text().slice(0, 160)}`);
  if (banner < 0 && m.text().startsWith('Godot Engine')) banner = Date.now() - t0;
  if (m.type() === 'error') problems.push(`console error: ${m.text().slice(0, 200)}`);
});
page.on('pageerror', (e) => problems.push(`page error: ${String(e).slice(0, 200)}`));
await page.goto(`http://localhost:${port}/index.html`);
// Ready = the game set window.cursedPawnReady after its first shop frame (ShopDebug._signal_web_ready). Then the
// screenshot must not be blank: a drawn shop is about 245 KB as PNG, an empty canvas a few KB.
const MIN_SHOT_BYTES = 20000;
let first = -1;
try {
  await page.waitForFunction(() => window.cursedPawnReady === true, null, { timeout: BOOT_LIMIT_MS, polling: 100 });
  first = Date.now() - t0;
} catch { /* reported below */ }
await page.waitForTimeout(2000);  // errors that follow the first frame
const pageText = await page.evaluate(() => document.body.innerText.replace(/\s+/g, ' ').slice(0, 300)).catch(() => 'n/a');
const webgl2 = await page.evaluate(() => !!document.createElement('canvas').getContext('webgl2')).catch(() => 'n/a');
const shot = await page.screenshot({ path: join(dir, '..', 'web_smoke.png') });
if (first >= 0 && shot.length < MIN_SHOT_BYTES) problems.push(`screen looks blank (${shot.length} bytes)`);
await browser.close();
server.close();
if (banner < 0) problems.push('no engine banner');
if (first < 0) problems.push(`game not ready within ${BOOT_LIMIT_MS / 1000} s`);
for (const p of problems) console.log(p);
if (problems.length) {
  console.log(`webgl2=${webgl2} page text: ${pageText}`);
  console.log('last console lines:');
  for (const l of log.slice(-15)) console.log(`  ${l}`);
}
console.log(`WEB smoke ${problems.length ? 'FAIL' : 'PASS'} banner_ms=${banner} ready_ms=${first} shot_kb=${Math.round(shot.length / 1024)} problems=${problems.length}`);
process.exit(problems.length ? 1 : 0);
