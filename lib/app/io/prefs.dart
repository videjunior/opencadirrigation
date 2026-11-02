/// Small persistent key/value store (localStorage on web, memory elsewhere).
library;

import 'prefs_stub.dart' if (dart.library.js_interop) 'prefs_web.dart' as impl;

String? getPref(String key) => impl.getPref(key);
void setPref(String key, String value) => impl.setPref(key, value);
void removePref(String key) => impl.removePref(key);

/// Every key and value kept (tests compare them; empty in the browser, whose
/// localStorage holds the site's other data too).
Map<String, String> debugPrefs() => impl.debugPrefs();
