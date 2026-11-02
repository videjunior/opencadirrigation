/// Browser: the Web Locks API (`navigator.locks`). A browser without it
/// (an old one, a page not served over HTTPS) coordinates nothing, as before
/// 1.6.0.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'window_locks.dart';

WindowLocks platformWindowLocks() => _supported() ? _WebLocks() : LoneWindowLocks();

bool _supported() {
  try {
    return (web.window.navigator as JSObject).has('locks');
  } catch (_) {
    return false;
  }
}

class _WebLocks implements WindowLocks {
  static const _prefix = 'opencadirrigation.project.';
  static const _store = 'opencadirrigation.store';

  /// The locks this window holds: completing one releases it.
  final Map<String, Completer<void>> _held = {};

  web.LockManager get _locks => web.window.navigator.locks;

  @override
  Future<bool?> claim(String uid) {
    if (_held.containsKey(uid)) return Future.value(true);
    final granted = Completer<bool?>();
    final release = Completer<void>();
    _held[uid] = release;
    try {
      _locks
          .request(
            '$_prefix$uid',
            web.LockOptions(mode: 'exclusive', ifAvailable: true),
            ((JSAny? lock) {
              if (lock == null) {
                if (identical(_held[uid], release)) _held.remove(uid);
                if (!granted.isCompleted) granted.complete(false);
                return null;
              }
              if (!granted.isCompleted) granted.complete(true);
              // held until release() completes it
              return release.future.toJS;
            }).toJS,
          )
          .toDart
          .catchError((Object _) => null);
    } catch (_) {
      _held.remove(uid);
      if (!granted.isCompleted) granted.complete(null);
    }
    return granted.future;
  }

  @override
  void release(String uid) {
    final r = _held.remove(uid);
    if (r != null && !r.isCompleted) r.complete();
  }

  @override
  Future<Set<String>> openElsewhere() async {
    try {
      final snap = await _locks.query().toDart;
      final out = <String>{};
      for (final info in snap.held.toDart) {
        final name = info.name;
        if (!name.startsWith(_prefix)) continue;
        final uid = name.substring(_prefix.length);
        if (!_held.containsKey(uid)) out.add(uid);
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<T> exclusive<T>(Future<T> Function() body) {
    final out = Completer<T>();
    try {
      _locks
          .request(
            _store,
            ((JSAny? _) {
              final run = () async {
                try {
                  out.complete(await body());
                } catch (e, st) {
                  out.completeError(e, st);
                }
              }();
              return run.toJS;
            }).toJS,
          )
          .toDart
          .catchError((Object _) => null);
    } catch (_) {
      if (!out.isCompleted) return body();
    }
    return out.future;
  }
}
