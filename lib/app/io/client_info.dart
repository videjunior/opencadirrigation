/// What the browser says it is (its user agent), for the diagnostics of a
/// report to the project (Help → Report a problem); empty on the desktop
/// builds and in the tests (conditional import).
library;

import 'client_info_stub.dart' if (dart.library.js_interop) 'client_info_web.dart' as impl;

/// The browser's user agent string, or ''.
String get clientUserAgent => impl.clientUserAgent;
