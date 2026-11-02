// End-to-end smoke test of a production web build (sh tool/build_web.sh) in
// headless Chrome: what only the compiled app in a real browser shows.
//
//   1. the app opens an example and designs it in the Web Worker (not in the
//      fallback on the main thread);
//   2. the version label it prints is the build's (version.json: version,
//      build number, commit);
//   3. the service worker installs, and the app starts again offline;
//   4. no page errors along the way.
//
// Setup, once (playwright-core only drives an installed Chrome; nothing is
// downloaded besides the package, and node_modules stays out of git):
//   npm ci --prefix tool/e2e
// Run, from the repository root:
//   node tool/e2e/smoke.mjs build/web [--chrome <path>] [--shots <dir>]
// CHROME_PATH also gives the browser. Exit code 1 when a check fails.
import { createServer } from 'node:http';
import { readFile, stat, mkdir } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { platform } from 'node:os';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright-core');

const args = process.argv.slice(2);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
};
const positional = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--')));
const root = resolve(positional[0] ?? 'build/web');
const shots = option('--shots');
const chrome =
  option('--chrome') ??
  process.env.CHROME_PATH ??
  (platform() === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : platform() === 'win32' ? 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe' : '/usr/bin/google-chrome');

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml',
  '.cat': 'application/json',
  '.md': 'text/markdown; charset=utf-8',
};

// A static server like the site's hosting: folders serve their index.html,
// unknown paths the 404 page with status 404, no caching.
async function serve(dir) {
  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      let path = normalize(join(dir, decodeURIComponent(url.pathname)));
      if (path !== dir && !path.startsWith(dir + sep)) throw new Error('outside');
      let info = await stat(path).catch(() => null);
      if (info?.isDirectory()) {
        path = join(path, 'index.html');
        info = await stat(path).catch(() => null);
      }
      const status = info ? 200 : 404;
      if (!info) path = join(dir, '404.html');
      const body = await readFile(path);
      res.writeHead(status, { 'content-type': types[extname(path)] ?? 'application/octet-stream', 'cache-control': 'no-cache' });
      res.end(body);
    } catch {
      res.writeHead(404, { 'content-type': 'text/plain' });
      res.end('not found');
    }
  });
  await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
  return server;
}

const failures = [];
const check = (what, ok, detail = '') => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}${detail ? ` (${detail})` : ''}`);
  if (!ok) failures.push(what);
};

const version = JSON.parse(await readFile(join(root, 'version.json'), 'utf8'));
const server = await serve(root);
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ executablePath: chrome, headless: true, args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader'] });
try {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  await context.addInitScript(() => {
    // a returning user: no tutorial, no AI question at the start
    localStorage.setItem('opencadirrigation.tutorial_done', '1');
    localStorage.setItem('opencadirrigation.ai.askAtStart', 'off');
  });
  const page = await context.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text().slice(0, 400)}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  page.on('dialog', (d) => d.accept());
  const texts = () =>
    page.evaluate(() =>
      [...document.querySelectorAll('flt-semantics-host *')]
        .map((e) => `${e.getAttribute('aria-label') ?? ''} ${[...e.childNodes].filter((c) => c.nodeType === 3).map((c) => c.textContent).join('')}`)
        .join('\n'),
    );
  const semantics = () => page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  const waitForText = async (needle, ms) => {
    const end = Date.now() + ms;
    while (Date.now() < end) {
      if ((await texts()).includes(needle)) return true;
      await page.waitForTimeout(250);
    }
    return false;
  };
  const shot = async (name) => {
    if (!shots) return;
    await mkdir(shots, { recursive: true });
    await page.screenshot({ path: join(shots, `${name}.png`) });
  };

  // 1. an example, designed in the worker
  const t0 = Date.now();
  await page.goto(`${base}/?example=rowCrop&design=1&lang=en`);
  await page.waitForSelector('flutter-view', { timeout: 90000 });
  await page.waitForTimeout(2000);
  await semantics();
  const designed = await waitForText('Design finished', 120000);
  check('the example opens and designs', designed, `${((Date.now() - t0) / 1000).toFixed(1)} s`);
  const worker = await page.evaluate(() => performance.getEntriesByType('resource').some((e) => new URL(e.name).pathname.endsWith('/design_worker.js')));
  check('the design ran in the Web Worker', worker);
  await shot('1-design');

  // 2. the version label
  const label = logs.find((l) => l.includes(`OpenCADIrrigation ${version.version} (build ${version.build_number})`));
  check('the version label is the build of version.json', !!label && (!version.commit || label.includes(`git ${version.commit}`)), label ?? 'no label in the console');

  // 3. offline start through the service worker
  const cached = await page.evaluate(async () => {
    if (!navigator.serviceWorker) return 'no service worker API';
    const end = Date.now() + 120000;
    while (Date.now() < end) {
      if (navigator.serviceWorker.controller) {
        const names = await caches.keys();
        for (const n of names.filter((n) => n.startsWith('oci-shell-'))) {
          const c = await caches.open(n);
          if (await c.match(new URL('main.dart.js', location.href).href)) return '';
        }
      }
      await new Promise((r) => setTimeout(r, 500));
    }
    return 'the shell cache never held main.dart.js';
  });
  check('the service worker installs and keeps the app', cached === '', cached);
  if (cached === '') {
    await context.setOffline(true);
    await page.reload();
    const started = await page
      .waitForSelector('flutter-view', { timeout: 60000 })
      .then(() => true)
      .catch(() => false);
    await page.waitForTimeout(2000);
    check('the app starts again offline', started);
    await shot('2-offline');
    await context.setOffline(false);
  }

  // 4. no page errors
  const errors = logs.filter((l) => l.startsWith('[pageerror]') || (l.startsWith('[error]') && !l.includes('ERR_INTERNET_DISCONNECTED') && !l.includes('Failed to load resource')));
  check('no page errors', errors.length === 0, errors.slice(0, 5).join(' | '));
} finally {
  await browser.close();
  server.close();
}
if (failures.length) {
  console.log(`${failures.length} check(s) failed`);
  process.exit(1);
}
console.log('all checks passed');
