// End-to-end smoke test of a production web build (sh tool/build_web.sh) in
// headless browsers: what only the compiled app in a real browser shows.
//
//   1. the app opens an example and designs it in the Web Worker (not in the
//      fallback on the main thread);
//   2. the version label it prints is the build's (version.json: version,
//      build number, commit);
//   3. the service worker installs, and the app starts again offline;
//   4. the AI assistant sends a message with the user's key and shows the
//      answer, against a fake of the API (nothing leaves the machine);
//   5. a worker of another build (a cache that kept the design_worker.js of
//      the release before) is noticed by its answer and loaded again past
//      the cache: the design still runs in a worker of this build;
//   6. a share link (#p=…, the project in the address) opens its project on a
//      first visit (no landing page first), on a returning visit, pasted into
//      the address bar of the open app, and offline with the service worker
//      in control (in 3.), and the address keeps no project;
//   7. no page errors along the way.
//
// Browsers (--browser, comma-separated, default chromium):
//   chromium  an installed Chrome (--chrome <path> or CHROME_PATH; the usual
//             place of each system otherwise): nothing is downloaded;
//   webkit    the WebKit build of Playwright (the engine of Safari);
//   firefox   the Firefox build of Playwright.
// The WebKit and Firefox builds are pinned by the exact playwright-core
// version of package.json (1.64.1: WebKit 27.2, build 2370, and Firefox 157.0,
// build 1555), downloaded once with (Linux: add --with-deps):
//   npm exec --prefix tool/e2e -- playwright-core install webkit firefox
// (PLAYWRIGHT_BROWSERS_PATH chooses where they go). A check a browser build
// cannot run is reported as skipped, with the reason, never as passed.
//
// Setup, once (node_modules stays out of git):
//   npm ci --prefix tool/e2e
// Run, from the repository root:
//   node tool/e2e/smoke.mjs build/web [--browser chromium,webkit,firefox] [--chrome <path>] [--shots <dir>]
// Exit code 1 when a check fails.
import { createServer } from 'node:http';
import { gzipSync } from 'node:zlib';
import { readFile, stat, mkdir } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { platform } from 'node:os';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const playwright = require('playwright-core');

const args = process.argv.slice(2);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
};
const positional = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--')));
const root = resolve(positional[0] ?? 'build/web');
const shots = option('--shots');
const browsers = (option('--browser') ?? 'chromium')
  .split(',')
  .map((b) => b.trim())
  .filter(Boolean);
const known = ['chromium', 'webkit', 'firefox'];
for (const b of browsers) {
  if (!known.includes(b)) {
    console.error(`unknown browser ${b} (use ${known.join(', ')})`);
    process.exit(2);
  }
}
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
const skipped = [];

/** Launches [name] headless: the installed Chrome, or the Playwright build of WebKit or Firefox. */
function launch(name) {
  if (name === 'chromium') return playwright.chromium.launch({ executablePath: chrome, headless: true, args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader'] });
  // WebGL in headless Firefox (CanvasKit draws with it)
  if (name === 'firefox') return playwright.firefox.launch({ headless: true, firefoxUserPrefs: { 'webgl.force-enabled': true, 'webgl.disabled': false } });
  return playwright.webkit.launch({ headless: true });
}

const version = JSON.parse(await readFile(join(root, 'version.json'), 'utf8'));
// the project of the share links: an example of the repository, renamed for each check
const garden = JSON.parse(await readFile(new URL('../../examples/en/garden.oci.json', import.meta.url), 'utf8'));
const server = await serve(root);
const base = `http://127.0.0.1:${server.address().port}`;

/** A share link to the garden example named [name] at this server, as lib/core/io/share_link.dart writes them (gzip, base64url without padding); with its entity count. */
function shareLink(name) {
  const project = { ...garden, meta: { ...garden.meta, name } };
  delete project.results;
  const packed = gzipSync(Buffer.from(JSON.stringify(project), 'utf8')).toString('base64url').replace(/=+$/, '');
  return { url: `${base}/#p=${packed}`, name, count: project.entities.length };
}

/** Answers "Later" when the app offers to recover projects left unsaved (it asks that before it opens a link); done when [opened] shows instead. */
async function answerRecovery(page, opened, ms = 30000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()).catch(() => {});
    const later = await page
      .evaluate((opened) => {
        const nodes = [...document.querySelectorAll('flt-semantics-host *')];
        const label = (e) => `${e.getAttribute('aria-label') ?? ''} ${e.textContent ?? ''}`;
        if (nodes.some((e) => label(e).includes(opened))) return 'opened';
        if (!nodes.some((e) => label(e).includes('Recover project'))) return null;
        const b = nodes
          .filter((e) => label(e).trim() === 'Later')
          .map((e) => e.getBoundingClientRect())
          .find((r) => r.width > 0 && r.height > 0);
        return b ? [b.left + b.width / 2, b.top + b.height / 2] : null;
      }, opened)
      .catch(() => null);
    if (later === 'opened') return false;
    if (later) {
      await page.mouse.click(later[0], later[1]);
      await page.waitForTimeout(500);
      return true;
    }
    await page.waitForTimeout(250);
  }
  return false;
}

/** Whether [page] shows the project of [link] open (its name in the tab bar, its entity count in the status bar) and its address no longer carries the project. */
async function opensShared(page, link, ms = 90000) {
  const end = Date.now() + ms;
  let all = '';
  while (Date.now() < end) {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()).catch(() => {});
    all = await page
      .evaluate(() =>
        [...document.querySelectorAll('flt-semantics-host *')]
          .map((e) => `${e.getAttribute('aria-label') ?? ''} ${[...e.childNodes].filter((c) => c.nodeType === 3).map((c) => c.textContent).join('')}`)
          .join('\n'),
      )
      .catch(() => '');
    if (all.includes(link.name) && all.includes(`${link.count} ent.`)) break;
    await page.waitForTimeout(250);
  }
  const address = await page.evaluate(() => location.href).catch(() => '');
  return { open: all.includes(link.name) && all.includes(`${link.count} ent.`), clean: !address.includes('#'), address };
}
try {
  for (const name of browsers) {
    console.log(`-- ${name}`);
    let browser;
    try {
      browser = await launch(name);
    } catch (e) {
      // a browser that is not installed fails the run: CI installs all it asks for
      const what = `${name}: the browser starts`;
      console.log(`FAIL ${what} (${String(e.message).split('\n')[0]})`);
      failures.push(what);
      continue;
    }
    try {
      await smoke(name, browser);
    } finally {
      await browser.close();
    }
  }
} finally {
  server.close();
}
if (skipped.length) console.log(`${skipped.length} check(s) skipped: ${skipped.join('; ')}`);
if (failures.length) {
  console.log(`${failures.length} check(s) failed`);
  process.exit(1);
}
console.log('all checks passed');

/** The checks in one browser. */
async function smoke(name, browser) {
  const check = (what, ok, detail = '') => {
    console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}${detail ? ` (${detail})` : ''}`);
    if (!ok) failures.push(`${name}: ${what}`);
  };
  const skip = (what, why) => {
    console.log(`skip ${what} (${why})`);
    skipped.push(`${name}: ${what} (${why})`);
  };
  const logs = [];
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  await context.addInitScript(() => {
    // a returning user: no tutorial, no AI question at the start
    localStorage.setItem('opencadirrigation.tutorial_done', '1');
    localStorage.setItem('opencadirrigation.ai.askAtStart', 'off');
    // when the first frame was drawn (performance.now(), ms)
    window.addEventListener('flutter-first-frame', () => (window.__ociFirstFrame = performance.now()), { once: true });
  });
  const page = await context.newPage();
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text().slice(0, 400)}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  page.on('dialog', (d) => d.accept());
  // dedicated workers the page starts (every browser reports them)
  const workers = [];
  page.on('worker', (w) => workers.push(w.url()));
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
  const shot = async (file) => {
    if (!shots) return;
    await mkdir(shots, { recursive: true });
    await page.screenshot({ path: join(shots, `${name}-${file}.png`) });
  };

  // 1. an example, designed in the worker
  const t0 = Date.now();
  await page.goto(`${base}/?example=rowCrop&design=1&lang=en`);
  await page.waitForSelector('flutter-view', { timeout: 90000 });
  await page.waitForTimeout(2000);
  await semantics();
  const designed = await waitForText('Design finished', 180000);
  const firstFrame = await page.evaluate(() => window.__ociFirstFrame ?? null);
  check('the example opens and designs', designed, `${((Date.now() - t0) / 1000).toFixed(1)} s${firstFrame == null ? '' : `, first frame at ${(firstFrame / 1000).toFixed(1)} s`}`);
  const worker =
    workers.some((u) => new URL(u, base).pathname.endsWith('/design_worker.js')) ||
    (await page.evaluate(() => performance.getEntriesByType('resource').some((e) => new URL(e.name).pathname.endsWith('/design_worker.js'))));
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
  if (cached === 'no service worker API' && name !== 'chromium') {
    // Playwright's Firefox runs without service workers; Chrome must have them
    skip('the service worker installs and the app starts again offline', `this ${name} build has no service worker API`);
  } else {
    check('the service worker installs and keeps the app', cached === '', cached);
  }
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
    // a share link opened offline: the page and its script come from the worker, the project from the address. The
    // designed example left unsaved is offered for recovery first (in English: the language saved here); the link
    // opens once that question is answered
    await page.evaluate(() => localStorage.setItem('opencadirrigation.lang', 'en'));
    const offline = shareLink('Linked garden offline');
    await page.goto(offline.url);
    await page.waitForSelector('flutter-view', { timeout: 60000 }).catch(() => {});
    await answerRecovery(page, offline.name);
    const r = await opensShared(page, offline);
    check('a share link opens its project offline, with the service worker in control', r.open && r.clean, r.address.slice(0, 60));
    await context.setOffline(false);
  }
  await context.close();

  // 4. the AI assistant against a fake of the API, with a remembered key
  await aiAssistant(name, browser, logs, check);

  // 5. a worker of another build
  await staleWorker(name, browser, logs, check, skip);

  // 6. share links
  await shareLinks(name, browser, logs, check);

  // 7. no page errors
  // (a connection hint the test's own blocking refused is no error of the app)
  const errors = logs.filter((l) => l.startsWith('[pageerror]') || (l.startsWith('[error]') && !l.includes('ERR_INTERNET_DISCONNECTED') && !l.includes('Failed to load resource') && !l.includes('Failed to preconnect')));
  check('no page errors', errors.length === 0, errors.slice(0, 5).join(' | '));
}

/**
 * Share links (#p=…): on a first visit (nothing in this browser: the link asks for the app, no landing page first),
 * on a returning visit, and pasted into the address bar of the open app (the same page, a new entry of its history).
 * Each opens its project, and the address keeps no project.
 */
async function shareLinks(name, browser, logs, check) {
  const shot = async (page, file) => {
    if (!shots) return;
    await mkdir(shots, { recursive: true });
    await page.screenshot({ path: join(shots, `${name}-${file}.png`) });
  };
  for (const returning of [false, true]) {
    const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, serviceWorkers: 'block' });
    if (returning) {
      await context.addInitScript(() => {
        localStorage.setItem('opencadirrigation.tutorial_done', '1');
        localStorage.setItem('opencadirrigation.ai.askAtStart', 'off');
      });
    }
    const page = await context.newPage();
    page.on('console', (m) => logs.push(`[${m.type()}] ${m.text().slice(0, 400)}`));
    page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
    page.on('dialog', (d) => d.accept());
    const visit = returning ? 'a returning visit' : 'a first visit';
    try {
      const link = shareLink(returning ? 'Linked garden returning' : 'Linked garden first');
      await page.goto(link.url);
      const started = await page
        .waitForSelector('flutter-view', { timeout: 90000 })
        .then(() => true)
        .catch(() => false);
      check(`a share link starts the app on ${visit}`, started);
      if (!started) continue;
      await page.waitForTimeout(2000);
      const r = await opensShared(page, link);
      check(`a share link opens its project on ${visit}`, r.open, `${link.name}, ${link.count} ent.`);
      check(`the address keeps no project on ${visit}`, r.clean, r.address.slice(0, 60));
      await shot(page, `4-share-${returning ? 'returning' : 'first'}`);
      if (!returning) continue;
      // a second link pasted into the address bar of the open app
      const pasted = shareLink('Linked garden pasted');
      await page.evaluate((u) => {
        location.href = u;
      }, pasted.url);
      const p = await opensShared(page, pasted, 30000);
      check('a share link pasted into the address bar of the open app opens its project', p.open && p.clean, p.address.slice(0, 60));
      // Forward to the entry of the pasted link: it was emptied, the page steps back, the app stays
      await page.evaluate(() => history.forward());
      await page.waitForTimeout(1500);
      const after = await opensShared(page, pasted, 5000);
      check('Forward after a pasted link brings no project back', after.open && after.clean, after.address.slice(0, 60));
      await shot(page, '5-share-pasted');
    } finally {
      await context.close();
    }
  }
}

/**
 * Serves, at the plain address of the worker, design_worker.js as a release
 * before would have it (its build stamp changed), and the real one at the
 * address the app uses to get past the cache (design_worker.js?v=<version>).
 */
async function staleWorker(name, browser, logs, check, skip) {
  const what = 'a worker of another build is noticed and replaced';
  const full = `${version.version}+${version.build_number}`;
  const script = await readFile(join(root, 'design_worker.js'), 'utf8');
  if (!script.includes(full)) {
    skip(what, `design_worker.js carries no build stamp ${full}: rebuilt with sh tool/build_worker.sh?`);
    return;
  }
  const stale = script.split(full).join('0.0.1+1');
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, serviceWorkers: 'block' });
  await context.addInitScript(() => {
    localStorage.setItem('opencadirrigation.tutorial_done', '1');
    localStorage.setItem('opencadirrigation.ai.askAtStart', 'off');
  });
  const served = [];
  await context.route(/\/design_worker\.js(\?.*)?$/, (route) => {
    const fresh = new URL(route.request().url()).search !== '';
    served.push(fresh ? 'fresh' : 'stale');
    return fresh ? route.continue() : route.fulfill({ status: 200, headers: { 'content-type': 'text/javascript; charset=utf-8', 'cache-control': 'no-cache' }, body: stale });
  });
  const page = await context.newPage();
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text().slice(0, 400)}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  const workers = [];
  page.on('worker', (w) => workers.push(w.url()));
  try {
    await page.goto(`${base}/?example=rowCrop&design=1&lang=en`);
    await page.waitForSelector('flutter-view', { timeout: 90000 });
    await page.waitForTimeout(2000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    const end = Date.now() + 180000;
    let designed = false;
    while (!designed && Date.now() < end) {
      designed = await page.evaluate(() => [...document.querySelectorAll('flt-semantics-host *')].some((e) => `${e.getAttribute('aria-label') ?? ''} ${e.textContent ?? ''}`.includes('Design finished')));
      if (!designed) await page.waitForTimeout(250);
    }
    if (!served.includes('stale')) {
      skip(what, `this ${name} build does not let the test serve the worker script`);
      return;
    }
    check(what, designed && served.join(',') === 'stale,fresh' && workers.some((u) => u.includes('design_worker.js?v=')), `scripts served: ${served.join(', ')}`);
  } finally {
    await context.close();
  }
}

/** The stream of server-sent events of an answer of the Messages API. */
function answer(n, text) {
  const events = [
    { type: 'message_start', message: { id: `msg_e2e_${n}`, type: 'message', role: 'assistant', model: 'claude-opus-5-5', content: [], usage: { input_tokens: 1200, output_tokens: 1, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 } } },
    { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
    { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text } },
    { type: 'content_block_stop', index: 0 },
    { type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: null }, usage: { output_tokens: 20 } },
    { type: 'message_stop' },
  ];
  return events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join('');
}

/** Opens the assistant (?ai=1) with a remembered key, sends a message and reads the answer of a fake API. */
async function aiAssistant(name, browser, logs, check) {
  const key = 'sk-ant-api03-E2E-FAKE-KEY-0000';
  const reply = 'Fake answer from the end-to-end test.';
  // no service worker here: in WebKit the requests of a page it controls go
  // through it, where the routes below do not see them (a real request would leave)
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, serviceWorkers: 'block' });
  await context.addInitScript((key) => {
    localStorage.setItem('opencadirrigation.tutorial_done', '1');
    localStorage.setItem('opencadirrigation.ai.askAtStart', 'off');
    localStorage.setItem('opencadirrigation.ai.key', key);
  }, key);
  const requests = [];
  await context.route('https://api.anthropic.com/**', async (route) => {
    const r = route.request();
    const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': 'POST, OPTIONS', 'access-control-expose-headers': 'request-id' };
    if (r.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
    requests.push({ headers: r.headers(), body: r.postData() ?? '' });
    return route.fulfill({ status: 200, headers: { ...cors, 'content-type': 'text/event-stream; charset=utf-8', 'request-id': `req_e2e_${requests.length}` }, body: answer(requests.length, reply) });
  });
  // anything else beyond this machine is answered "not found" here (an aborted
  // font of the fallback chain is an unhandled error in WebKit)
  await context.route(/^https?:\/\/(?!127\.0\.0\.1|api\.anthropic\.com)/, (route) => route.fulfill({ status: 404, body: '' }));
  const page = await context.newPage();
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text().slice(0, 400)}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  page.on('dialog', (d) => d.accept());
  try {
    await page.goto(`${base}/?ai=1&lang=en`);
    await page.waitForSelector('flutter-view', { timeout: 90000 });
    await page.waitForTimeout(4000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(1500);
    // the message box: the text field of the assistant's panel
    const box = await page.evaluate(() => {
      const fields = [...document.querySelectorAll('flt-semantics-host textarea, flt-semantics-host input')].map((e) => e.getBoundingClientRect()).filter((b) => b.width > 0);
      const b = fields.sort((x, y) => y.bottom - x.bottom)[0];
      return b ? [b.left + b.width / 2, b.top + b.height / 2] : null;
    });
    check('the assistant opens with its message box', !!box);
    if (!box) return;
    // Chrome: typed into the box and sent with Enter. WebKit and Firefox take
    // keys typed by automation into Flutter's text field one at a time (it
    // moves its editing element after the first one): the first suggestion
    // fills the box there, and the Send button sends it
    let message = 'Hello from the smoke test.';
    if (name === 'chromium') {
      await page.mouse.click(box[0], box[1]);
      await page.waitForTimeout(500);
      await page.keyboard.type(message);
      await page.keyboard.press('Enter');
    } else {
      message = 'I want to design a new irrigation system.';
      const at = (text, button) =>
        page.evaluate(
          ([text, button]) => {
            const nodes = [...document.querySelectorAll('flt-semantics-host *')].filter((e) => {
              const label = `${e.getAttribute('aria-label') ?? ''} ${e.textContent ?? ''}`;
              return label.includes(text) && (!button || e.getAttribute('role') === 'button' || e.tagName === 'BUTTON');
            });
            const b = nodes.map((e) => e.getBoundingClientRect()).filter((r) => r.width > 0 && r.height > 0).sort((x, y) => x.width * x.height - y.width * y.height)[0];
            return b ? [b.left + b.width / 2, b.top + b.height / 2] : null;
          },
          [text, button],
        );
      const suggestion = await at(message, false);
      check('the first suggestion is offered', !!suggestion);
      if (!suggestion) return;
      await page.mouse.click(suggestion[0], suggestion[1]);
      await page.waitForTimeout(800);
      const send = await at('Send', true);
      check('the Send button is there', !!send);
      if (!send) return;
      await page.mouse.click(send[0], send[1]);
    }
    const end = Date.now() + 60000;
    let shown = false;
    while (!shown && Date.now() < end) {
      await page.waitForTimeout(300);
      shown = await page.evaluate((reply) => [...document.querySelectorAll('flt-semantics-host *')].some((e) => `${e.getAttribute('aria-label') ?? ''} ${e.textContent ?? ''}`.includes(reply)), reply);
    }
    const sent = requests[0];
    check("the message goes to the API with the user's key", !!sent && sent.headers['x-api-key'] === key && sent.body.includes(message));
    check('the answer shows in the panel', shown);
    if (shots) {
      await mkdir(shots, { recursive: true });
      await page.screenshot({ path: join(shots, `${name}-3-assistant.png`) });
    }
  } finally {
    await context.close();
  }
}
