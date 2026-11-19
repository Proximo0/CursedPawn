// Boots build/web in headless Chromium and checks the game starts: the engine banner prints, no page errors or
// console errors appear, the game signals ready, and the screen is not blank. Saves build/web_smoke.png. Node + Playwright (browser automation
// has no standard-library route). Usage: node tools/web_smoke.mjs [build/web] [--chrome]  (--chrome: use the
// system Chrome, as on GitHub runners). Quiet: prints problems, then one "WEB smoke PASS|FAIL ..." line.
// SMOKE_BOT=greedy|cautious: then a second page plays a whole run with the play-bot (index.html?scripted&bot=..&seed=7,
// game/debug/bot_pilot.gd) and must finish without errors, unstuck, with a recording that replays. SMOKE_BOT_HASH: the
// final state hash the native build printed for the same run ("BOT ... hash=<n>"); the web run must match it.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const dir = resolve(process.argv.find((a, i) => i > 1 && !a.startsWith('--')) ?? 'build/web');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const tStart = Date.now();
const phase = {};  // ms since start at each step, printed so CI time can be traced
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
phase.launch = Date.now() - tStart;
const page = await browser.newPage({ viewport: { width: 640, height: 360 } });
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
// Ready = the game set window.cursedPawnReady after its first shop frame (Flags._process, whatever the main scene). Then the
// screenshot must not be blank: at the game's native 640x360 a drawn shop is 40-90 KB as PNG, a black page about 5 KB (measured).
const MIN_SHOT_BYTES = 8000;
let first = -1;
try {
  await page.waitForFunction(() => window.cursedPawnReady === true, null, { timeout: BOOT_LIMIT_MS, polling: 100 });
  first = Date.now() - t0;
} catch { /* reported below */ }
phase.ready = Date.now() - tStart;
await page.waitForTimeout(2000);  // errors that follow the first frame
phase.waited = Date.now() - tStart;
// One screenshot: on a 2-core runner with software GL each one costs seconds while the game keeps rendering.
const shot = await page.screenshot({ path: join(dir, '..', 'web_smoke.png') });
phase.shot = Date.now() - tStart;
if (first >= 0 && shot.length < MIN_SHOT_BYTES) problems.push(`screen looks blank (${shot.length} bytes)`);
if (banner < 0) problems.push('no engine banner');
if (first < 0) problems.push(`game not ready within ${BOOT_LIMIT_MS / 1000} s`);
// The play-bot run: a fresh page, so the boot check above still covers the title screen a player sees.
let bot = null;
let evPage = page;  // the page failure evidence comes from
const BOT_STYLE = process.env.SMOKE_BOT ?? '';
const BOT_STEPS = 4;  // commands a frame: software GL draws a few frames a second, and each command still runs the full screen path
if (BOT_STYLE && problems.length === 0) {
  await page.close();  // two games rendering at once on 2 CPUs halves the bot's frame rate
  const botPage = await browser.newPage({ viewport: { width: 640, height: 360 } });
  botPage.on('console', (m) => { if (m.type() === 'error') problems.push(`bot console error: ${m.text().slice(0, 200)}`); });
  botPage.on('pageerror', (e) => problems.push(`bot page error: ${String(e).slice(0, 200)}`));
  await botPage.goto(`http://localhost:${port}/index.html?scripted&bot=${BOT_STYLE}&seed=7&bot_steps=${BOT_STEPS}`);
  try {
    await botPage.waitForFunction(() => window.cursedPawnBot != null, null, { timeout: BOOT_LIMIT_MS * 2, polling: 200 });
    bot = await botPage.evaluate(() => window.cursedPawnBot);
  } catch { problems.push(`bot run did not finish within ${BOOT_LIMIT_MS * 2 / 1000} s`); }
  if (bot) {
    if (bot.stuck) problems.push(`bot stuck after ${bot.commands} commands`);
    if (bot.diverged !== -1) problems.push(`bot recording diverged at command ${bot.diverged}`);
    if (process.env.SMOKE_BOT_HASH && bot.hash !== process.env.SMOKE_BOT_HASH) problems.push(`bot hash ${bot.hash} != native ${process.env.SMOKE_BOT_HASH}`);
  }
  evPage = botPage;
  phase.bot = Date.now() - tStart;
}
// Evidence is gathered only on failure.
const failed = problems.length > 0;
const jpeg = failed && process.env.SMOKE_SHOT_B64 ? await evPage.screenshot({ type: 'jpeg', quality: 40 }) : null;
const pageText = failed ? await evPage.evaluate(() => document.body.innerText.replace(/\s+/g, ' ').slice(0, 300)).catch(() => 'n/a') : '';
const webgl2 = failed ? await evPage.evaluate(() => !!document.createElement('canvas').getContext('webgl2')).catch(() => 'n/a') : '';
phase.shots = Date.now() - tStart;
await browser.close();
server.close();
phase.closed = Date.now() - tStart;
for (const p of problems) console.log(p);
if (problems.length) {
  console.log(`webgl2=${webgl2} page text: ${pageText}`);
  if (process.env.SMOKE_SHOT_B64) {  // CI: artifacts may be unreachable; a small JPEG in 1000-character log lines
    const b64 = jpeg.toString('base64');
    for (let i = 0; i < b64.length; i += 1000) console.log(`SHOT_B64 ${b64.slice(i, i + 1000)}`);
  }
  console.log('last console lines:');
  for (const l of log.slice(-15)) console.log(`  ${l}`);
}
console.log(`WEB smoke ${problems.length ? 'FAIL' : 'PASS'} banner_ms=${banner} ready_ms=${first} shot_kb=${Math.round(shot.length / 1024)} ${bot ? `bot=${BOT_STYLE}:night${bot.night}:cmds${bot.commands}:hash${bot.hash} ` : ''}problems=${problems.length} phases_ms=${Object.entries(phase).map(([k, v]) => `${k}:${v}`).join(",")}`);
process.exit(problems.length ? 1 : 0);
