// The share target and the hosted fonts of the service worker (web/sw.js), with fake caches and a fake network:
// shared files kept for the page of the language, fonts kept once in the cache every build shares, an aborted font
// download answered without an unhandled error, stale shares dropped.
// Run by test/web_js_test.dart: node test/js/sw_share_fonts.test.js web/sw.js
'use strict';
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const src = fs.readFileSync(process.argv[2], 'utf8').replace("const BUILD = '__OCI_BUILD__';", "const BUILD = 'test-build';");

function makeCaches() {
  const all = new Map();
  const cacheFor = (name) => {
    if (!all.has(name)) all.set(name, new Map());
    const m = all.get(name);
    const key = (r) => (typeof r === 'string' ? r : r.url);
    return {
      match: async (r, o) => {
        let k = key(r);
        if (o && o.ignoreSearch) k = k.split('?')[0];
        const hit = m.get(k);
        return hit ? hit.clone() : undefined;
      },
      put: async (r, res) => { m.set(key(r), res); },
      delete: async (r) => m.delete(key(r)),
      keys: async () => [...m.keys()].map((u) => ({ url: u })),
    };
  };
  return {
    all,
    open: async (name) => cacheFor(name),
    has: async (name) => all.has(name),
    keys: async () => [...all.keys()],
    delete: async (name) => all.delete(name),
    match: async (u) => {
      for (const name of all.keys()) {
        const hit = await cacheFor(name).match(u);
        if (hit) return hit;
      }
      return undefined;
    },
  };
}

const caches = makeCaches();
const handlers = {};
let network = async () => new Response('x');
const fetched = [];
const self = {
  location: new URL('https://opencadirrigation.com/sw.js'),
  addEventListener: (t, f) => { handlers[t] = f; },
  skipWaiting: () => {},
  registration: { unregister: async () => {} },
  clients: { claim: async () => {}, matchAll: async () => [] },
};
const ctx = {
  self, caches, URL, Request, Response, FormData, Blob, File, Promise, console, Intl, Date, Math, JSON, Map, Set, Array, Object, String, Number, setTimeout,
  fetch: (r, o) => { fetched.push(typeof r === 'string' ? r : r.url); return network(r, o); },
};
vm.createContext(ctx);
vm.runInContext(src, ctx);

function event(request) {
  const e = { request, clientId: 'c1', resultingClientId: '', waits: [], respondWith(p) { this.response = p; }, waitUntil(p) { this.waits.push(p); } };
  handlers.fetch(e);
  return e;
}

(async () => {
  // ---- share target: files and text kept, the page of the language opens with the id
  const form = new FormData();
  form.append('files', new File(['%PDF-1.4'], 'plan.pdf', { type: 'application/pdf' }));
  form.append('files', new File(['{"format":"opencadirrigation"}'], 'farm.oci.json', { type: 'application/json' }));
  form.append('text', 'see this');
  const post = event(new Request('https://opencadirrigation.com/pt/share-target', { method: 'POST', body: form }));
  const res = await post.response;
  assert.strictEqual(res.status, 303);
  const location = new URL(res.headers.get('location'));
  assert.strictEqual(location.pathname, '/pt/');
  const id = location.searchParams.get('share');
  assert.match(id, /^[0-9]+-[0-9a-z]+$/);
  const share = await caches.open('oci-share');
  const meta = await (await share.match(`https://opencadirrigation.com/__oci__/share/${id}`)).json();
  assert.deepStrictEqual(meta.files.map((f) => f.name), ['plan.pdf', 'farm.oci.json']);
  assert.strictEqual(meta.text, 'see this');
  assert.strictEqual(await (await share.match(`https://opencadirrigation.com/${meta.files[1].key}`)).text(), '{"format":"opencadirrigation"}');
  // the root page for the English manifest; a post elsewhere is not the worker's
  const root = event(new Request('https://opencadirrigation.com/share-target', { method: 'POST', body: (() => { const f = new FormData(); f.append('url', 'https://example.com'); return f; })() }));
  assert.strictEqual(new URL((await root.response).headers.get('location')).pathname, '/');
  const other = event(new Request('https://opencadirrigation.com/api', { method: 'POST', body: 'x' }));
  assert.strictEqual(other.response, undefined);
  // nothing readable: the app still opens
  const empty = event(new Request('https://opencadirrigation.com/share-target', { method: 'POST', body: 'not a form', headers: { 'Content-Type': 'text/plain' } }));
  assert.strictEqual(new URL((await empty.response).headers.get('location')).searchParams.get('share'), 'failed');

  // ---- hosted fonts: fetched once, kept for every build
  network = async () => Object.defineProperty(new Response(new Uint8Array([0x77, 0x4f, 0x46, 0x32]), { status: 200 }), 'type', { value: 'basic' });
  const fontUrl = 'https://opencadirrigation.com/fonts/notosanssc/v37/k3k.4.woff2';
  fetched.length = 0;
  const first = event(new Request(fontUrl));
  const r1 = await first.response;
  await Promise.all(first.waits);
  assert.strictEqual(r1.status, 200);
  assert.deepStrictEqual(fetched, [fontUrl]);
  const second = event(new Request(fontUrl));
  assert.strictEqual((await second.response).status, 200);
  assert.deepStrictEqual(fetched, [fontUrl], 'the second time from the cache');
  assert.ok(await (await caches.open('oci-runtime')).match(fontUrl), 'in the shared cache, not a build cache');
  // an aborted (or offline) font download: a network error for the page, nothing unhandled here
  network = async () => { throw new DOMException('The operation was aborted.', 'AbortError'); };
  const aborted = event(new Request('https://opencadirrigation.com/fonts/notocoloremoji/v32/Yq6.0.woff2'));
  const r3 = await aborted.response;
  assert.strictEqual(r3.type, 'error');
  // not a font address: the app's own files go to the build cache as before
  assert.strictEqual(vm.runInContext("hostedFont('fonts/OFL.txt')", ctx), false);
  assert.strictEqual(vm.runInContext("hostedFont('fonts/roboto/v32/KFOm.woff2')", ctx), true);
  assert.strictEqual(vm.runInContext("hostedFont('assets/fonts/MaterialIcons-Regular.otf')", ctx), false);
  assert.strictEqual(vm.runInContext("kept(new URL('https://fonts.gstatic.com/s/roboto/v32/a.woff2'))", ctx), false, 'no font service');

  // ---- a share nobody picked up within a day is dropped, a fresh one stays
  await share.put(`https://opencadirrigation.com/__oci__/share/1-old`, new Response(JSON.stringify({ files: [{ key: '__oci__/share/1-old/0' }], time: 1 })));
  await share.put(`https://opencadirrigation.com/__oci__/share/1-old/0`, new Response('old'));
  await vm.runInContext('pruneShares()', ctx);
  assert.strictEqual(await share.match('https://opencadirrigation.com/__oci__/share/1-old'), undefined);
  assert.strictEqual(await share.match('https://opencadirrigation.com/__oci__/share/1-old/0'), undefined);
  assert.ok(await share.match(`https://opencadirrigation.com/__oci__/share/${id}`), 'the fresh share stays');
  console.log('sw ok');
})().catch((e) => { console.error(e); process.exit(1); });
