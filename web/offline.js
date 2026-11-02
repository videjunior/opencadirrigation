// Offline start (see web/sw.js). Loaded by flutter_bootstrap.js once the app
// has painted its first frame and the browser is idle, so it never competes
// with the start-up: registers the service worker, then hands it the files
// this start fetched before the worker existed (the CanvasKit variant of this
// browser, the fonts the engine downloaded) so the next start finds them all.
// In the installed app it also asks the browser to keep the site's storage
// (the cached app and the autosaved projects) under storage pressure.
//
// It also tells the app when a newer build is ready: the window gets
// `ociUpdateReady = true` and an `oci-update-ready` event, and
// `ociApplyUpdate()` reloads into that build (the app asks the user first).
// A page open for days looks for a new build every hour and when it comes
// back to the screen.
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
  // A page the worker already served: a build installed from now on is newer than the one running here.
  var controlled = !!sw.controller;
  var registration = null;

  function announce() {
    if (window.ociUpdateReady) return;
    window.ociUpdateReady = true;
    window.dispatchEvent(new Event('oci-update-ready'));
  }

  function watch(reg) {
    registration = reg;
    if (reg.waiting && controlled) announce();
    reg.addEventListener('updatefound', function () {
      var w = reg.installing;
      if (!w) return;
      w.addEventListener('statechange', function () {
        // waiting for the pages of the old build (installed), or taking over at once (activated)
        if (controlled && (w.state === 'installed' || w.state === 'activated')) announce();
      });
    });
    var last = Date.now();
    function check() {
      last = Date.now();
      reg.update().catch(function () {});
    }
    setInterval(check, 3600 * 1000);
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState === 'visible' && Date.now() - last > 15 * 60 * 1000) check();
    });
  }

  // The build this page runs against the newest the worker has (where the browser tells pages apart).
  function compare(worker) {
    if (!worker || !window.MessageChannel) return;
    var channel = new MessageChannel();
    channel.port1.onmessage = function (e) {
      var d = e.data || {};
      if (d.page && d.build && d.page !== d.build) announce();
    };
    worker.postMessage({ type: 'oci-build' }, [channel.port2]);
  }

  // Reloads into the newer build: a waiting one takes over first, the other open pages keeping the build they run.
  window.ociApplyUpdate = function () {
    var reg = registration;
    var waiting = reg && reg.waiting;
    var done = false;
    function reload() {
      if (done) return;
      done = true;
      location.reload();
    }
    if (!waiting) {
      reload();
      return;
    }
    sw.addEventListener('controllerchange', reload);
    setTimeout(reload, 5000);
    function takeOver() {
      waiting.postMessage({ type: 'oci-skip-waiting' });
    }
    if (reg.active && window.MessageChannel) {
      var channel = new MessageChannel();
      channel.port1.onmessage = takeOver;
      reg.active.postMessage({ type: 'oci-pin-open' }, [channel.port2]);
      setTimeout(takeOver, 1500);
    } else {
      takeOver();
    }
  };

  sw.register(script, { updateViaCache: 'none' }).then(function (reg) {
    watch(reg);
    return sw.ready;
  }).then(function (reg) {
    var used = [];
    if (window.performance && performance.getEntriesByType) {
      performance.getEntriesByType('resource').forEach(function (e) { used.push(e.name); });
    }
    if (reg.active) {
      reg.active.postMessage({ type: 'oci-keep', urls: used });
      if (controlled) compare(reg.active);
    }
  }).catch(function (e) {
    console.warn('OpenCADIrrigation: offline start unavailable', e);
  });
  var standalone = window.matchMedia && matchMedia('(display-mode: standalone), (display-mode: window-controls-overlay), (display-mode: minimal-ui), (display-mode: fullscreen)').matches;
  // Firefox asks the user; the other browsers decide by themselves.
  if (standalone && navigator.storage && navigator.storage.persist && !/firefox/i.test(navigator.userAgent)) {
    navigator.storage.persisted().then(function (yes) { if (!yes) return navigator.storage.persist(); }).catch(function () {});
  }
})();
