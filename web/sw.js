// OpenCADIrrigation service worker: after the first visit, the installed app
// (and the site) starts without a network.
//
// - This file is a template. tool/gen_sw.dart, run by tool/build_web.sh, fills
//   in the build name and the files of the build with their SHA-256 in the
//   copy written to the build folder. Left as a template (flutter run, a plain
//   flutter build web) it only removes itself and its caches.
// - web/offline.js registers it once the app has painted its first frame and
//   the browser is idle, so the start never waits for it.
// - One cache per build ("oci-shell-<build>"), filled at install: files that
//   did not change since the previous build are copied from its cache, the
//   others are fetched past the HTTP cache and checked against their hash, so
//   a cache never mixes two builds.
// - Files most starts never need (the language packs, the PDF fonts, the
//   licence list: LAZY) are kept once a start uses them, and a new build
//   carries forward those this browser kept, fetching their new version when
//   they changed: a release does not download every language again.
// - The page learns of a newer build through offline.js, which asks it to
//   reload when the user agrees (`oci-pin-open`, then `oci-skip-waiting`).
// - A page keeps the build it started with, even when a newer one takes over
//   meanwhile; the next start (a new window, a reload) gets the newest. A
//   build's cache is deleted once it is older than the current one and no
//   open page uses it. Where the browser cannot tell which page a request
//   comes from, a new build waits until every page of the old one is closed.
// - Same-origin files are served from the cache first; the pages are
//   revalidated in the background. The fonts the engine fetches from
//   fonts.gstatic.com (Roboto and the fallback fonts of other scripts) and the
//   engine of a build that uses Google's CDN (www.gstatic.com/flutter-canvaskit)
//   are kept once fetched: their addresses never change content. Every other
//   request to another origin (map tiles, elevation, climate, analytics) goes
//   to the network untouched.
'use strict';

const BUILD = '__OCI_BUILD__';
/** [path, sha256, bytes] of the files of the build every start may need. */
const FILES = [/*__OCI_FILES__*/];
/** The same for the CanvasKit engine, by variant: only the browser's own is kept. */
const CANVASKIT = {/*__OCI_CANVASKIT__*/};
/** [path, sha256, bytes] of the files kept only once a start uses them. */
const LAZY = [/*__OCI_LAZY__*/];

const TEMPLATE = BUILD.charAt(0) === '_';
const BASE = new URL('./', self.location.href).href;
const PREFIX = 'oci-';
const SHELL_PREFIX = PREFIX + 'shell-';
const SHELL = SHELL_PREFIX + BUILD;
const RUNTIME = PREFIX + 'runtime';
const META = PREFIX + 'meta';
/** Written last into a build's cache: the build is complete (files and time). */
const MANIFEST_URL = new URL('__oci__/manifest', BASE).href;
/** Written first: when the filling started (a stale incomplete cache is dropped). */
const STARTED_URL = new URL('__oci__/started', BASE).href;
/** The build every open page started with (client id -> build), in META. */
const PINS_URL = new URL('__oci__/pins', BASE).href;
const DAY = 24 * 3600 * 1000;

/** Whether requests say which page they come from, so pages can keep their build. */
const PIN = typeof FetchEvent !== 'undefined' && 'resultingClientId' in FetchEvent.prototype;

/** CanvasKit variant the Flutter loader picks: "chromium" where V8's break iterators exist. */
const VARIANT = typeof Intl.v8BreakIterator !== 'undefined' && typeof Intl.Segmenter !== 'undefined' ? 'chromium' : 'full';

if (TEMPLATE) {
  // Not a production build: take over from any earlier worker on this
  // address, then remove the caches and the registration.
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (event) => {
    event.waitUntil((async () => {
      for (const name of await caches.keys()) {
        if (name.startsWith(PREFIX)) await caches.delete(name);
      }
      await self.registration.unregister();
    })());
  });
} else {
  self.addEventListener('install', (event) => {
    event.waitUntil(install().then(() => (PIN ? self.skipWaiting() : undefined)));
  });
  self.addEventListener('activate', (event) => event.waitUntil(activate()));
  self.addEventListener('fetch', onFetch);
  self.addEventListener('message', onMessage);
}

// ------------------------------------------------------------------ install

function shellFiles() {
  return FILES.concat(CANVASKIT[VARIANT] || []);
}

async function install() {
  const cache = await caches.open(SHELL);
  if (await cache.match(MANIFEST_URL)) return; // this build is already complete
  if (!(await cache.match(STARTED_URL))) await cache.put(STARTED_URL, new Response(String(Date.now())));
  const previous = await completeBuilds(SHELL);
  const files = shellFiles();
  for (const [path, hash] of files) {
    const url = new URL(path, BASE).href;
    if (await cache.match(url)) continue; // put by an interrupted install of this build
    let response = null;
    for (const p of previous) {
      if (p.files[path] !== hash) continue;
      response = await p.cache.match(url);
      if (response) break;
    }
    await cache.put(url, response || (await fetchChecked(url, hash)));
  }
  await carryLazy(cache, previous);
  const manifest = { build: BUILD, done: Date.now(), files: {} };
  for (const [path, hash] of files) manifest.files[path] = hash;
  await cache.put(MANIFEST_URL, new Response(JSON.stringify(manifest), { headers: { 'Content-Type': 'application/json' } }));
}

/**
 * The LAZY files an earlier build of this browser kept: copied when they did
 * not change, fetched again when they did (skipped when that fails: the
 * start that needs one fetches it then).
 */
async function carryLazy(cache, previous) {
  for (const [path, hash] of LAZY) {
    const url = new URL(path, BASE).href;
    if (await cache.match(url)) continue;
    let kept = null;
    for (const p of previous) {
      kept = await p.cache.match(url);
      if (kept) break;
    }
    if (!kept) continue;
    try {
      await cache.put(url, (await sha256(kept.clone())) === hash ? kept : await fetchChecked(url, hash));
    } catch (e) {
      // offline, or a deploy in progress
    }
  }
}

/** Fetches a file of this build from the server and checks it is that build's. */
async function fetchChecked(url, hash) {
  for (const mode of ['no-cache', 'reload']) {
    const response = await fetch(url, { cache: mode, credentials: 'same-origin' });
    if (!response.ok || response.redirected) throw new Error(url + ': HTTP ' + response.status);
    if ((await sha256(response.clone())) === hash) return response;
  }
  throw new Error(url + ' is not the file of build ' + BUILD + ' (deploy in progress?)');
}

async function sha256(response) {
  const digest = await crypto.subtle.digest('SHA-256', await response.arrayBuffer());
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

/** The complete build caches other than [except], with their manifests. */
async function completeBuilds(except) {
  const out = [];
  for (const name of await caches.keys()) {
    if (!name.startsWith(SHELL_PREFIX) || name === except) continue;
    const cache = await caches.open(name);
    const manifest = await readJson(await cache.match(MANIFEST_URL));
    if (manifest && manifest.files) out.push({ name, cache, files: manifest.files, done: manifest.done || 0 });
  }
  return out;
}

async function readJson(response) {
  if (!response) return null;
  try {
    return await response.json();
  } catch (e) {
    return null;
  }
}

// ------------------------------------------------------------------ activate

async function activate() {
  await self.clients.claim();
  // Pages open already (the first visit, or loaded past the worker with a
  // hard reload) run the files the server gave them: this build's.
  const pins = await loadPins();
  for (const client of await self.clients.matchAll({ type: 'window', includeUncontrolled: true })) {
    if (!pins.has(client.id)) pins.set(client.id, BUILD);
  }
  await savePins();
  await prune();
}

/**
 * Deletes the caches no page needs: builds older than this one that no open
 * page started with, builds whose filling stopped more than a day ago,
 * caches of an earlier format and those of Flutter's former service worker.
 * A newer complete build (waiting to take over) and one being filled stay.
 */
async function prune() {
  const pins = await loadPins();
  const live = new Set((await self.clients.matchAll({ type: 'all', includeUncontrolled: true })).map((c) => c.id));
  let changed = false;
  for (const id of Array.from(pins.keys())) {
    if (!live.has(id)) {
      pins.delete(id);
      changed = true;
    }
  }
  if (changed) await savePins();
  const used = new Set([SHELL]);
  for (const build of pins.values()) used.add(SHELL_PREFIX + build);
  const own = await readJson(await (await openCache(SHELL)).match(MANIFEST_URL));
  const ownDone = own ? own.done || 0 : 0;
  for (const name of await caches.keys()) {
    if (name.startsWith('flutter-')) {
      await deleteCache(name);
      continue;
    }
    if (!name.startsWith(PREFIX) || name === RUNTIME || name === META || used.has(name)) continue;
    if (!name.startsWith(SHELL_PREFIX)) {
      await deleteCache(name); // a format this worker does not know
      continue;
    }
    const cache = await caches.open(name);
    const manifest = await readJson(await cache.match(MANIFEST_URL));
    if (manifest) {
      if ((manifest.done || 0) < ownDone) await deleteCache(name);
      continue;
    }
    const started = await cache.match(STARTED_URL);
    const since = started ? Number(await started.text()) : 0;
    if (!(Date.now() - since < DAY)) await deleteCache(name);
  }
}

// ------------------------------------------------------------------ pins

let pinsLoaded = null;
let pinsSaved = Promise.resolve();

function loadPins() {
  if (!pinsLoaded) {
    pinsLoaded = (async () => {
      const stored = await readJson(await (await openCache(META)).match(PINS_URL));
      return new Map(stored ? Object.entries(stored) : []);
    })().catch(() => new Map());
  }
  return pinsLoaded;
}

function savePins() {
  pinsSaved = pinsSaved
    .then(async () => {
      const pins = await loadPins();
      const cache = await openCache(META);
      await cache.put(PINS_URL, new Response(JSON.stringify(Object.fromEntries(pins)), { headers: { 'Content-Type': 'application/json' } }));
    })
    .catch(() => {});
  return pinsSaved;
}

async function pin(clientId) {
  const pins = await loadPins();
  pins.set(clientId, BUILD);
  await savePins();
}

/** Caches opened by this worker, by name (one IPC round trip each, once). */
const opened = new Map();

function openCache(name) {
  let cache = opened.get(name);
  if (!cache) {
    cache = caches.open(name);
    opened.set(name, cache);
  }
  return cache;
}

async function deleteCache(name) {
  opened.delete(name);
  await caches.delete(name);
}

/** Cache of the build the page [clientId] started with (this build's by default). */
async function cacheFor(clientId) {
  if (clientId) {
    const build = (await loadPins()).get(clientId);
    if (build && build !== BUILD) {
      const name = SHELL_PREFIX + build;
      if (opened.has(name) || (await caches.has(name))) return openCache(name);
    }
  }
  return openCache(SHELL);
}

/** [url] in [cache]: the exact address first, then without its query (`?v=` of the entry page's images). */
async function lookup(cache, url) {
  const hit = await cache.match(url.href);
  if (hit || !url.search) return hit;
  return cache.match(url.href, { ignoreSearch: true });
}

// ------------------------------------------------------------------ fetch

const BASE_PATH = new URL(BASE).pathname;

/** Path of a same-origin [url] below the worker's scope, or null. */
function relative(url) {
  return url.href.startsWith(BASE) ? decodeURIComponent(url.pathname.slice(BASE_PATH.length)) : null;
}

/** Entry pages: the root and the language pages (/pt/, /de/, … and the /en/ redirect). */
function pagePath(path) {
  const m = /^(?:([a-z]{2})\/)?(?:index\.html)?$/.exec(path);
  if (!m) return null;
  return m[1] ? m[1] + '/' : './';
}

/** Same-origin files left to the network: this worker, the site's text files. */
function bypassed(path) {
  return path === 'sw.js' || path.startsWith('__oci__/') || /\.(txt|xml)$/.test(path) || path === 'version.json' || path === '404.html';
}

/** Other origins whose answers never change for an address. */
function kept(url) {
  return url.origin === 'https://fonts.gstatic.com' || (url.origin === 'https://www.gstatic.com' && url.pathname.startsWith('/flutter-canvaskit/'));
}

function onFetch(event) {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('range')) return;
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') return;
  const url = new URL(request.url);
  if (url.origin === self.location.origin) {
    const path = relative(url);
    if (path === null) return;
    if (request.mode === 'navigate') {
      const page = pagePath(path);
      if (page === null) return;
      if (event.resultingClientId) event.waitUntil(pin(event.resultingClientId).catch(() => {}));
      event.respondWith(navigate(event, page));
      return;
    }
    if (bypassed(path)) return;
    event.respondWith(serveShell(event, url));
    return;
  }
  if (kept(url)) event.respondWith(serveKept(request));
}

/**
 * An entry page from the cache, the network when it is not cached yet, and
 * offline the root page for a language page never opened before (the app
 * reads the language from the address). The cached page is revalidated
 * later, with the rest of the housekeeping (see [housekeeping]), so that
 * nothing competes with the start-up.
 */
async function navigate(event, page) {
  const key = new URL(page, BASE).href;
  const cache = await openCache(SHELL);
  const hit = await cache.match(key);
  if (hit) return hit;
  try {
    const response = await fetch(event.request);
    if (response.ok && response.type === 'basic' && !response.redirected) {
      event.waitUntil(cache.put(key, response.clone()).catch(() => {}));
    }
    return response;
  } catch (error) {
    const root = page === './' ? null : await cache.match(BASE);
    if (root) return root;
    throw error;
  }
}

/** A file of the app: the page's build cache first, then the network (kept in that cache). */
async function serveShell(event, url) {
  const cache = await cacheFor(event.clientId);
  const hit = await lookup(cache, url);
  if (hit) return hit;
  try {
    const response = await fetch(event.request);
    if (response.ok && response.type === 'basic' && !response.redirected) {
      event.waitUntil(cache.put(url.href, response.clone()).catch(() => {}));
    }
    return response;
  } catch (error) {
    const any = await caches.match(url.href, { ignoreSearch: true });
    if (any) return any;
    throw error;
  }
}

async function serveKept(request) {
  const cache = await openCache(RUNTIME);
  const hit = await cache.match(request.url, { ignoreVary: true });
  if (hit) return hit;
  const response = await fetch(request);
  if (response.ok && (response.type === 'cors' || response.type === 'basic')) {
    await cache.put(request.url, response.clone()).catch(() => {});
  }
  return response;
}

// ------------------------------------------------------------------ messages

/**
 * - `{type: 'oci-keep', urls}` from offline.js, once the app is on screen and
 *   the browser idle: the housekeeping of this start ([housekeeping]).
 * - `{type: 'oci-build'}` with a port: answers the build name and the build
 *   the asking page started with (`page`, where the browser tells pages
 *   apart): a page older than the worker has a newer build to reload into.
 * - `{type: 'oci-pin-open'}` with a port, to the active worker before a
 *   waiting build takes over: the open pages keep the build they run.
 * - `{type: 'oci-skip-waiting'}`: a waiting build takes over now.
 */
function onMessage(event) {
  const data = event.data || {};
  const port = event.ports && event.ports[0];
  if (data.type === 'oci-keep' && Array.isArray(data.urls)) {
    event.waitUntil(housekeeping(data.urls, event.source).catch(() => {}));
  } else if (data.type === 'oci-build' && port) {
    event.waitUntil(
      loadPins()
        .then((pins) => port.postMessage({ build: BUILD, pin: PIN, variant: VARIANT, page: (event.source && pins.get(event.source.id)) || null }))
        .catch(() => port.postMessage({ build: BUILD, pin: PIN, variant: VARIANT, page: null })),
    );
  } else if (data.type === 'oci-pin-open') {
    event.waitUntil(pinOpen().catch(() => {}).then(() => port && port.postMessage({ pinned: true })));
  } else if (data.type === 'oci-skip-waiting') {
    self.skipWaiting();
  }
}

/** Pins every open page that has no build yet to this one (they run it). */
async function pinOpen() {
  const pins = await loadPins();
  for (const client of await self.clients.matchAll({ type: 'window' })) {
    if (!pins.has(client.id)) pins.set(client.id, BUILD);
  }
  await savePins();
}

/**
 * After a start: keeps the files the page fetched before the worker was
 * there (the CanvasKit variant, the engine's fonts), revalidates the page it
 * was started from, and deletes the caches no open page needs any more.
 */
async function housekeeping(urls, client) {
  await keepUsed(urls, client && client.id);
  if (client && client.url) await revalidatePage(new URL(client.url));
  await prune();
}

async function revalidatePage(url) {
  const path = url.origin === self.location.origin ? relative(url) : null;
  const page = path === null ? null : pagePath(path);
  if (page === null) return;
  const key = new URL(page, BASE).href;
  const response = await fetch(key, { cache: 'no-cache', credentials: 'same-origin' }).catch(() => null);
  if (response && response.ok && response.type === 'basic' && !response.redirected) await (await openCache(SHELL)).put(key, response);
}

async function keepUsed(urls, clientId) {
  const shell = await cacheFor(clientId);
  const runtime = await openCache(RUNTIME);
  for (const href of urls) {
    let url;
    try {
      url = new URL(href);
    } catch (e) {
      continue;
    }
    if (url.origin === self.location.origin) {
      const path = relative(url);
      if (path === null || bypassed(path) || pagePath(path) !== null) continue;
      if (await lookup(shell, url)) continue;
      const response = await fetch(url.href, { cache: 'force-cache', credentials: 'same-origin' }).catch(() => null);
      if (response && response.ok && response.type === 'basic' && !response.redirected) await shell.put(url.href, response);
    } else if (kept(url)) {
      if (await runtime.match(url.href, { ignoreVary: true })) continue;
      const response = await fetch(url.href, { mode: 'cors', cache: 'force-cache', credentials: 'omit' }).catch(() => null);
      if (response && response.ok) await runtime.put(url.href, response);
    }
  }
}
