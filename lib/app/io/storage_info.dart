/// What the browser says about the storage of this site (conditional
/// import): whether it is kept under pressure ("persistent"), how much is
/// used of how much, and which browser this is (Safari erases the storage of
/// a site not visited for seven days unless the app is installed).
/// Elsewhere (desktop builds, tests) there is nothing to ask.
library;

import 'storage_info_stub.dart' if (dart.library.js_interop) 'storage_info_web.dart' as impl;

/// Whether the browser keeps the storage of this site when it runs short of
/// space; null when it cannot say.
Future<bool?> storagePersisted() => impl.storagePersisted();

/// Asks the browser to keep the storage of this site (Firefox asks the
/// user; the others decide by themselves): true when granted, null when the
/// browser cannot be asked.
Future<bool?> requestPersistentStorage() => impl.requestPersistentStorage();

/// Bytes used and available to this site; null when unknown.
Future<(int used, int quota)?> storageEstimate() => impl.storageEstimate();

/// Firefox (asking for persistent storage shows the user a question).
bool get browserIsFirefox => impl.browserIsFirefox;

/// Safari (its storage of a site goes after seven days without a visit).
bool get browserIsSafari => impl.browserIsSafari;
