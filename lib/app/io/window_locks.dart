/// Coordination between the windows of this browser that run the app on
/// this site (conditional import): the Web Locks API in the browser, nothing
/// elsewhere (desktop builds and tests run one window).
///
/// Each window holds a lock named after the uid of every project it has
/// open, which the browser releases by itself when the window closes or
/// crashes. Another window that opens the same project sees it held and
/// opens a copy instead, and the start-up recovery leaves out the projects
/// alive in another window. The project index of the browser store is read
/// and written under one more lock, so two windows saving at once do not
/// lose each other's entries.
library;

import 'window_locks_stub.dart' if (dart.library.js_interop) 'window_locks_web.dart' as impl;

abstract class WindowLocks {
  /// Holds the lock of project [uid] for this window until [release]:
  /// true once held, false when another window holds it, null when the
  /// browser cannot tell (no Web Locks).
  Future<bool?> claim(String uid);

  void release(String uid);

  /// The uids of the projects other windows hold (empty when the browser
  /// cannot tell).
  Future<Set<String>> openElsewhere();

  /// Runs [body] while no other window runs one.
  Future<T> exclusive<T>(Future<T> Function() body);
}

/// The coordination of this platform (one per page).
WindowLocks get windowLocks => _locks ??= impl.platformWindowLocks();
WindowLocks? _locks;

/// No other window (desktop builds, tests): every claim is granted.
class LoneWindowLocks implements WindowLocks {
  final Set<String> held = {};

  @override
  Future<bool?> claim(String uid) async {
    held.add(uid);
    return true;
  }

  @override
  void release(String uid) => held.remove(uid);

  @override
  Future<Set<String>> openElsewhere() async => const {};

  @override
  Future<T> exclusive<T>(Future<T> Function() body) => body();
}
