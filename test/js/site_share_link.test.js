// The share links of site.js (tool/site.dart, renderSiteScript), with a fake browser: a project shared by a link
// (#p=…) is taken out of the address before the statistics and the app's engine load, kept for the app
// (window.ociLinks), and starts the app on a first visit; a link pasted later into the address bar is taken the same
// way, its history entry emptied and left, so that the engine (which would read #p=… as a page of the app) and the
// statistics never see it and neither Back nor Forward brings it back.
// Run by test/web_js_test.dart: node test/js/site_share_link.test.js <site.js rendered by renderSiteScript>
'use strict';
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const src = fs.readFileSync(process.argv[2], 'utf8');
const tick = (ms = 0) => new Promise((r) => setTimeout(r, ms));

/** A page at [address] with a fake history, events in the browser's order and what the page loads. */
function browser(address, { landing = true, stored = {} } = {}) {
  const entries = [{ url: address, state: null }];
  let index = 0;
  const listeners = {};
  const appended = [];
  const replaced = [];
  const storage = new Map(Object.entries(stored));
  const at = () => new URL(entries[index].url);
  const location = {
    get href() { return at().href; },
    get origin() { return at().origin; },
    get hostname() { return at().hostname; },
    get pathname() { return at().pathname; },
    get search() { return at().search; },
    get hash() { return at().hash; },
    replace(u) { replaced.push(u); },
  };
  function dispatch(type, init) {
    let stopped = false;
    const e = { type, ...init, stopImmediatePropagation() { stopped = true; }, preventDefault() {} };
    // at the target, the capture listeners first, each group in the order they were added
    const all = listeners[type] || [];
    for (const l of [...all.filter((l) => l.capture), ...all.filter((l) => !l.capture)]) {
      if (stopped) break;
      l.fn(e);
    }
  }
  function moveTo(i) {
    const from = entries[index].url;
    index = i;
    dispatch('popstate', { state: entries[index].state });
    if (new URL(from).hash !== at().hash) dispatch('hashchange', { oldURL: from, newURL: at().href });
  }
  const history = {
    get state() { return entries[index].state; },
    get length() { return entries.length; },
    replaceState(state, _title, url) { entries[index] = { url: new URL(url ?? entries[index].url, at()).href, state }; },
    pushState(state, _title, url) {
      entries.splice(index + 1);
      entries.push({ url: new URL(url ?? entries[index].url, at()).href, state });
      index = entries.length - 1;
    },
    back() { if (index > 0) setTimeout(() => moveTo(index - 1), 5); },
    forward() { if (index < entries.length - 1) setTimeout(() => moveTo(index + 1), 5); },
  };
  const element = (id) => ({ id, className: '', textContent: '', hidden: true, attrs: {}, getAttribute(n) { return this.attrs[n] ?? null; }, setAttribute(n, v) { this.attrs[n] = v; }, hasAttribute(n) { return n in this.attrs; } });
  const nodes = landing ? { 'oci-landing': element('oci-landing'), 'oci-status': element('oci-status'), 'oci-consent': element('oci-consent') } : {};
  const loaded = () => appended.filter((n) => n.tag === 'script').map((n) => n.src);
  const win = {
    addEventListener(type, fn, options) {
      (listeners[type] = listeners[type] || []).push({ fn, capture: options === true || !!(options && options.capture) });
    },
    matchMedia: () => ({ matches: false }),
    scrollTo() {},
  };
  const document = {
    currentScript: { getAttribute: (n) => (n === 'data-ga' ? 'G-TEST' : null) },
    getElementById: (id) => nodes[id] || null,
    addEventListener() {},
    createElement: (tag) => ({ tag }),
    head: { appendChild: (n) => appended.push({ ...n, hashThen: location.hash }) },
    body: { appendChild: (n) => appended.push({ ...n, hashThen: location.hash }) },
    cookie: '',
  };
  const localStorage = {
    get length() { return storage.size; },
    key: (i) => [...storage.keys()][i] ?? null,
    getItem: (k) => (storage.has(k) ? storage.get(k) : null),
    setItem: (k, v) => storage.set(k, String(v)),
  };
  const ctx = { window: win, document, location, history, localStorage, matchMedia: win.matchMedia, setTimeout, Date, JSON, String, URL, encodeURIComponent };
  win.window = win;
  vm.createContext(ctx);
  vm.runInContext(src, ctx);
  // what loads after site.js listens after it: the app's engine and the statistics
  const engine = [];
  const statistics = [];
  win.addEventListener('popstate', (e) => engine.push(e.state));
  win.addEventListener('popstate', () => statistics.push('popstate'));
  win.addEventListener('hashchange', (e) => statistics.push(`hashchange ${e.newURL}`));
  return {
    win, location, history, entries, engine, statistics, loaded, appended, replaced,
    gtagConfig: () => (win.dataLayer || []).map((a) => [...a]).find((a) => a[0] === 'config'),
    /** Typing [url] into the address bar of this page: a new entry of the history, at once (same document). */
    paste(url) {
      entries.splice(index + 1);
      entries.push({ url, state: null });
      const from = entries[index].url;
      index = entries.length - 1;
      dispatch('popstate', { state: null });
      dispatch('hashchange', { oldURL: from, newURL: url });
    },
    index: () => index,
  };
}

(async () => {
  const site = 'https://opencadirrigation.com/';
  const link = '#p=H4sIAAAAAAAAE6tWKkktLlGyUlAqS8wpTVWqBQBKpT5mFAAAAA';
  const later = '#p=H4sIAAAAAAAAE6tWKkktLlGyUlAqKc1LUaoFAH0AIxQTAAAA';

  // 1. a first visit opened by a link: the link leaves the address before anything loads, the app starts by itself
  {
    const b = browser(`${site}${link}`);
    assert.strictEqual(b.location.href, site, 'the address keeps no project');
    assert.strictEqual(b.history.length, 1, 'the link was replaced, not followed by another entry');
    assert.ok(b.loaded().includes('flutter_bootstrap.js'), 'a link asks for the app: no landing page first');
    // the statistics were loaded with an address that never had the project
    const gtag = b.appended.find((n) => String(n.src).includes('googletagmanager.com'));
    assert.ok(gtag, 'statistics on the published site');
    assert.strictEqual(gtag.hashThen, '', 'loaded after the link left the address');
    assert.strictEqual(b.gtagConfig()[2].page_location, site);
    // the app takes it once, first thing
    const got = [];
    b.win.ociLinks((l) => got.push(l));
    assert.deepStrictEqual(got, [link]);
    const again = [];
    b.win.ociLinks((l) => again.push(l));
    assert.deepStrictEqual(again, [], 'taken once');
  }

  // 2. a returning visitor (the app has run here): the same
  {
    const b = browser(`${site}?lang=pt${link}`, { stored: { 'opencadirrigation.tutorial_done': '1' } });
    assert.strictEqual(b.location.href, `${site}?lang=pt`, 'the query stays, the fragment goes');
    assert.ok(b.loaded().includes('flutter_bootstrap.js'));
    const got = [];
    b.win.ociLinks((l) => got.push(l));
    assert.deepStrictEqual(got, [link]);
  }

  // 3. no link, a first visit: the landing page alone, nothing for the app
  {
    const b = browser(`${site}#install`);
    assert.strictEqual(b.location.href, `${site}#install`, 'another fragment is left alone');
    assert.ok(!b.loaded().includes('flutter_bootstrap.js'), 'a first visit gets the landing page');
    const got = [];
    b.win.ociLinks((l) => got.push(l));
    assert.deepStrictEqual(got, []);
  }

  // 4. a link pasted into the address bar of the open app
  {
    const b = browser(site, { stored: { 'opencadirrigation.tutorial_done': '1' } });
    assert.ok(b.loaded().includes('flutter_bootstrap.js'));
    // the engine's single-entry history: an origin entry and its own one on top
    b.history.replaceState({ origin: true, state: null }, '', '/');
    b.history.pushState({ flutter: true }, '', '/');
    const got = [];
    b.win.ociLinks((l) => got.push(l));
    b.paste(`${site}${later}`);
    assert.strictEqual(b.location.href, site, 'the address loses the project at once');
    assert.deepStrictEqual(got, [], 'handed over once the page is back on its entry');
    await tick(30);
    assert.deepStrictEqual(got, [later]);
    assert.strictEqual(b.index(), 1, 'back on the entry of the engine');
    assert.deepStrictEqual(b.history.state, { flutter: true });
    assert.deepStrictEqual(b.engine, [], 'the engine never saw the link nor the step back');
    assert.deepStrictEqual(b.statistics, [], 'nor did the statistics');
    assert.ok(b.entries.every((e) => !e.url.includes('#p=')), 'no entry of the history keeps the project');
    // Forward to the emptied entry: the page steps back again, unseen
    b.history.forward();
    await tick(30);
    assert.strictEqual(b.index(), 1);
    assert.deepStrictEqual(b.engine, []);
    assert.deepStrictEqual(got, [later], 'nothing more arrives');
    // an ordinary step of the history still reaches the engine
    b.history.back();
    await tick(30);
    assert.deepStrictEqual(b.engine, [{ origin: true, state: null }]);
  }

  // 5. a link pasted on the landing page of a first visit: the app starts and gets it
  {
    const b = browser(site);
    assert.ok(!b.loaded().includes('flutter_bootstrap.js'));
    b.paste(`${site}${later}`);
    await tick(30);
    assert.ok(b.loaded().includes('flutter_bootstrap.js'), 'the app starts for the link');
    assert.strictEqual(b.location.href, site);
    const got = [];
    b.win.ociLinks((l) => got.push(l));
    assert.deepStrictEqual(got, [later]);
  }

  // 6. pages without the app (privacy, terms) leave the address as it is
  {
    const b = browser(`${site}privacy/${link}`, { landing: false });
    assert.strictEqual(b.location.href, `${site}privacy/${link}`);
  }

  // 7. a new visitor at a default address of the hosting is sent to the site with the link
  {
    const b = browser(`https://opencadirrigation.web.app/${link}`);
    assert.deepStrictEqual(b.replaced, [`https://opencadirrigation.com/${link}`]);
  }

  console.log('site share links ok');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
