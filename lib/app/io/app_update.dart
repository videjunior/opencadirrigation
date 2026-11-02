/// A newer build of the web app, installed by the offline service worker
/// (web/sw.js) while this page runs the one it started with: web/offline.js
/// says so and reloads into it on request.
library;

import 'app_update_stub.dart' if (dart.library.js_interop) 'app_update_web.dart' as impl;

/// Calls [onReady] once, when a newer build is ready to be reloaded into
/// (at once when it already is). Never on other platforms.
void watchForAppUpdate(void Function() onReady) => impl.watchForAppUpdate(onReady);

/// Reloads the page into the newer build (a waiting build takes over first).
void applyAppUpdate() => impl.applyAppUpdate();
