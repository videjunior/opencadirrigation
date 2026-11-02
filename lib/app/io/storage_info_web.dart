import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool get _hasStorage {
  try {
    return (web.window.navigator as JSObject).has('storage');
  } catch (_) {
    return false;
  }
}

Future<bool?> storagePersisted() async {
  if (!_hasStorage) return null;
  try {
    return (await web.window.navigator.storage.persisted().toDart).toDart;
  } catch (_) {
    return null;
  }
}

Future<bool?> requestPersistentStorage() async {
  if (!_hasStorage) return null;
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } catch (_) {
    return null;
  }
}

Future<(int, int)?> storageEstimate() async {
  if (!_hasStorage) return null;
  try {
    final e = await web.window.navigator.storage.estimate().toDart;
    return (e.usage, e.quota);
  } catch (_) {
    return null;
  }
}

String get _agent {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}

bool get browserIsFirefox => _agent.toLowerCase().contains('firefox');

/// Safari reports itself as Safari without the names the other engines add.
bool get browserIsSafari {
  final a = _agent.toLowerCase();
  return a.contains('safari') && !a.contains('chrome') && !a.contains('chromium') && !a.contains('crios') && !a.contains('fxios') && !a.contains('edg') && !a.contains('android');
}
