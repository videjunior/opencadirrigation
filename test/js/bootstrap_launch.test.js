// The page side of web/flutter_bootstrap.js, with a fake browser: the files the installed app is asked to open
// (the launch queue of its file handlers and of a window already open) and those shared with it (kept by web/sw.js),
// queued until the app asks for them, and the address of the hosted fonts handed to the engine.
// Run by test/web_js_test.dart: node test/js/bootstrap_launch.test.js web/flutter_bootstrap.js [fonts address]
'use strict';
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const template = fs.readFileSync(process.argv[2], 'utf8').replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
// as tool/site_fonts.dart fills it in, or left as the placeholder (flutter run)
const src = process.argv[3] ? template.replace('__OCI_FONTS__', process.argv[3]) : template;
const store = new Map();
const cache = {
  match: async (u) => (store.has(u) ? store.get(u).clone() : undefined),
  put: async (u, r) => { store.set(u, r); },
  delete: async (u) => store.delete(u),
};
let consumer = null;
let loaded = null;
const listeners = {};
const win = {
  launchQueue: { setConsumer: (f) => { consumer = f; } },
  caches: { open: async (name) => { assert.strictEqual(name, 'oci-share'); return cache; } },
  addEventListener: (t, f) => { listeners[t] = f; },
};
const ctx = {
  window: win,
  location: { href: 'https://opencadirrigation.com/?source=pwa' },
  document: { baseURI: 'https://opencadirrigation.com/', createElement: () => ({}), body: { appendChild() {} } },
  caches: win.caches,
  _flutter: { loader: { load: (o) => { loaded = o; } } },
  URL, File, Blob, Response, Promise, console, setTimeout,
};
ctx.window.window = win;
vm.createContext(ctx);
vm.runInContext(src, ctx);
// window.ociLaunches / ociShared live on the window object of the page
const ociLaunches = win.ociLaunches;
const ociShared = win.ociShared;

(async () => {
  // the fonts
  if (process.argv[3]) assert.deepStrictEqual(JSON.parse(JSON.stringify(loaded)), { config: { fontFallbackBaseUrl: process.argv[3] } });
  else assert.deepStrictEqual(JSON.parse(JSON.stringify(loaded)), {});
  // a launch before the app listens: queued; the first launch keeps its files only
  const f1 = new File(['{"format":"opencadirrigation"}'], 'a.oci.json', { type: 'application/json' });
  consumer({ targetURL: 'https://opencadirrigation.com/?source=pwa', files: [{ getFile: async () => f1 }] });
  await new Promise((r) => setTimeout(r, 10));
  const got = [];
  ociLaunches((item) => got.push(item));
  assert.strictEqual(got.length, 1);
  assert.strictEqual(got[0].url, '');
  assert.strictEqual(got[0].files.length, 1);
  assert.strictEqual(got[0].files[0].name, 'a.oci.json');
  // a later launch into this window: its address counts
  consumer({ targetURL: 'https://opencadirrigation.com/?ai=1', files: [] });
  await new Promise((r) => setTimeout(r, 10));
  assert.strictEqual(got.length, 2);
  assert.strictEqual(got[1].url, 'https://opencadirrigation.com/?ai=1');
  // a handle that cannot be read: the launch still arrives, without files
  consumer({ targetURL: 'https://opencadirrigation.com/?source=file', files: [{ getFile: async () => { throw new Error('denied'); } }] });
  await new Promise((r) => setTimeout(r, 10));
  assert.strictEqual(got.length, 3);
  assert.strictEqual(got[2].files.length, 0);
  // shared files kept by the worker: read once, then gone
  const id = '1730000000000-abc123';
  store.set(`https://opencadirrigation.com/__oci__/share/${id}`, new Response(JSON.stringify({ files: [{ name: 'photo.jpg', type: 'image/jpeg', key: `__oci__/share/${id}/0` }], text: 'look', time: 1 })));
  store.set(`https://opencadirrigation.com/__oci__/share/${id}/0`, new Response(new Blob(['JPEG'], { type: 'image/jpeg' })));
  const shared = await ociShared(id);
  assert.strictEqual(shared.files.length, 1);
  assert.strictEqual(shared.files[0].name, 'photo.jpg');
  assert.strictEqual(shared.files[0].type, 'image/jpeg');
  assert.strictEqual(await shared.files[0].text(), 'JPEG');
  assert.strictEqual(shared.text, 'look');
  assert.strictEqual(store.size, 0, 'read once');
  assert.strictEqual(await ociShared(id), null, 'nothing the second time');
  assert.strictEqual(await ociShared('../x'), null, 'only ids of the worker');
  console.log('bootstrap ok');
})().catch((e) => { console.error(e); process.exit(1); });
