/// Keeps the screen on (conditional import): the Screen Wake Lock API in
/// the browser, nothing elsewhere. With the screen off the browsers stop
/// giving positions, which ended a GPS walk with the phone in the pocket.
library;

import 'wake_lock_stub.dart' if (dart.library.js_interop) 'wake_lock_web.dart' as impl;

/// Whether the platform can keep the screen on.
bool get screenWakeLockSupported => impl.screenWakeLockSupported;

/// Keeps the screen on until [releaseScreenWakeLock] (asked again when the
/// page comes back to the front: the browser lets the lock go while it is
/// hidden). True when the browser granted it.
Future<bool> keepScreenOn() => impl.keepScreenOn();

void releaseScreenWakeLock() => impl.releaseScreenWakeLock();
