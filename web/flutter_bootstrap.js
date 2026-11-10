{{flutter_js}}
{{flutter_build_config}}

// Files for the app, kept until it asks for them (lib/app/io/launch_files_web.dart):
// - those the installed app is asked to open (the file handlers of its
//   manifest: "Open with" a project or a drawing) and the launches of a window
//   already open (its manifest asks to focus it: a shortcut, a file), from the
//   browser's launch queue;
// - those shared with it (the share target of its manifest), which web/sw.js
//   keeps under __oci__/share/<id> and sends the page to ?share=<id>.
// The launch that opened this page brings the page's own address, which the
// app reads at start: only its files count. (Compared without the fragment:
// site.js has already taken a shared project, #p=…, out of the address.)
(function () {
  var queue = [];
  var consumer = null;
  function bare(u) {
    var at = u.indexOf('#');
    return at < 0 ? u : u.slice(0, at);
  }
  var initial = bare(location.href);
  var seen = false;
  function deliver(item) {
    if (consumer) consumer(item);
    else queue.push(item);
  }
  if (window.launchQueue && typeof window.launchQueue.setConsumer === 'function') {
    window.launchQueue.setConsumer(function (params) {
      var url = (params && params.targetURL) || '';
      var first = !seen && bare(url) === initial;
      seen = true;
      var handles = (params && params.files) || [];
      Promise.all(Array.prototype.map.call(handles, function (h) { return h.getFile(); })).then(
        function (files) { deliver({ url: first ? '' : url, files: files, text: '' }); },
        function () { deliver({ url: first ? '' : url, files: [], text: '' }); }
      );
    });
  }
  window.ociLaunches = function (callback) {
    consumer = callback;
    var pending = queue;
    queue = [];
    pending.forEach(function (item) { callback(item); });
  };
  window.ociShared = function (id) {
    if (!window.caches || !/^[0-9a-z-]{1,40}$/.test(String(id))) return Promise.resolve(null);
    var metaUrl = new URL('__oci__/share/' + id, document.baseURI).href;
    return caches.open('oci-share').then(function (cache) {
      return cache.match(metaUrl).then(function (r) { return r ? r.json() : null; }).then(function (meta) {
        if (!meta) return null;
        var entries = meta.files || [];
        return Promise.all(entries.map(function (f) {
          return cache.match(new URL(f.key, document.baseURI).href).then(function (r) {
            return r ? r.blob().then(function (b) { return new File([b], f.name || 'file', { type: f.type || b.type || '' }); }) : null;
          });
        })).then(function (files) {
          // read once: the copies leave the cache
          var keys = [metaUrl].concat(entries.map(function (f) { return new URL(f.key, document.baseURI).href; }));
          return Promise.all(keys.map(function (k) { return cache.delete(k); })).then(function () {
            return { url: '', files: files.filter(function (f) { return f; }), text: meta.text || '' };
          });
        });
      });
    }).catch(function () { return null; });
  };
})();

// Started by the entry page (tool/site.dart) when the app is wanted. Not
// Flutter's service worker: it is deprecated, only unregisters itself, and
// waiting for it delayed every start.
// The fallback fonts of the engine (the glyphs of the other scripts, the
// symbols, the emoji) come from this site: tool/site_fonts.dart, run by
// tool/build_web.sh, copies them into the build under fonts/ and writes that
// address below. Left as the placeholder (flutter run, a plain flutter build
// web), the engine fetches them from Google's font server.
(function () {
  var fonts = '__OCI_FONTS__';
  _flutter.loader.load(fonts.charAt(0) === '_' ? {} : { config: { fontFallbackBaseUrl: fonts } });
})();

// Offline start: once the first frame is on screen and the browser is idle,
// offline.js registers the app's own worker (web/sw.js). Nothing here delays
// this start.
window.addEventListener('flutter-first-frame', function () {
  function later() {
    var s = document.createElement('script');
    s.src = 'offline.js';
    s.async = true;
    document.body.appendChild(s);
  }
  if (window.requestIdleCallback) {
    requestIdleCallback(later, { timeout: 10000 });
  } else {
    setTimeout(later, 3000);
  }
}, { once: true });
