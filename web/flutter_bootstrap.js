{{flutter_js}}
{{flutter_build_config}}

// Started by the entry page (tool/site.dart) when the app is wanted. Not
// Flutter's service worker: it is deprecated, only unregisters itself, and
// waiting for it delayed every start.
_flutter.loader.load();

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
