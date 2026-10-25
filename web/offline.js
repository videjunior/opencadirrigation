// Offline start (see web/sw.js). Loaded by flutter_bootstrap.js once the app
// has painted its first frame and the browser is idle, so it never competes
// with the start-up: registers the service worker, then hands it the files
// this start fetched before the worker existed (the CanvasKit variant of this
// browser, the fonts the engine downloaded) so the next start finds them all.
// In the installed app it also asks the browser to keep the site's storage
// (the cached app and the autosaved projects) under storage pressure.
(function () {
  'use strict';
  // Replaced by tool/gen_sw.dart in production builds; still a placeholder
  // under flutter run and in a plain flutter build web.
  var script = '__OCI_SW_URL__';
  var sw = navigator.serviceWorker;
  if (!sw) return;
  if (script.charAt(0) === '_') {
    // Not a production build: no offline cache, and none left over from an
    // earlier production build served at this address.
    sw.getRegistrations().then(function (regs) {
      regs.forEach(function (r) {
        var w = r.active || r.waiting || r.installing;
        if (w && /\/sw\.js$/.test(new URL(w.scriptURL).pathname)) r.unregister();
      });
    }).catch(function () {});
    return;
  }
  sw.register(script, { updateViaCache: 'none' }).then(function () {
    return sw.ready;
  }).then(function (reg) {
    var used = [];
    if (window.performance && performance.getEntriesByType) {
      performance.getEntriesByType('resource').forEach(function (e) { used.push(e.name); });
    }
    if (reg.active) reg.active.postMessage({ type: 'oci-keep', urls: used });
  }).catch(function (e) {
    console.warn('OpenCADIrrigation: offline start unavailable', e);
  });
  var standalone = window.matchMedia && matchMedia('(display-mode: standalone), (display-mode: window-controls-overlay), (display-mode: minimal-ui), (display-mode: fullscreen)').matches;
  // Firefox asks the user; the other browsers decide by themselves.
  if (standalone && navigator.storage && navigator.storage.persist && !/firefox/i.test(navigator.userAgent)) {
    navigator.storage.persisted().then(function (yes) { if (!yes) return navigator.storage.persist(); }).catch(function () {});
  }
})();
