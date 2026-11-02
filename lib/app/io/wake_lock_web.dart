import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

web.WakeLockSentinel? _sentinel;
bool _wanted = false;
bool _listening = false;

bool get screenWakeLockSupported {
  try {
    return (web.window.navigator as JSObject).has('wakeLock');
  } catch (_) {
    return false;
  }
}

Future<bool> keepScreenOn() async {
  _wanted = true;
  if (!screenWakeLockSupported) return false;
  if (!_listening) {
    _listening = true;
    // the browser releases the lock while the page is hidden: asked again on return
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (_wanted && web.document.visibilityState == 'visible' && _sentinel == null) keepScreenOn();
      }).toJS,
    );
  }
  if (_sentinel != null) return true;
  try {
    final s = await web.window.navigator.wakeLock.request('screen').toDart;
    s.onrelease = ((web.Event _) {
      if (identical(_sentinel, s)) _sentinel = null;
    }).toJS;
    if (!_wanted) {
      s.release();
      return false;
    }
    _sentinel = s;
    return true;
  } catch (_) {
    return false;
  }
}

void releaseScreenWakeLock() {
  _wanted = false;
  final s = _sentinel;
  _sentinel = null;
  if (s == null) return;
  try {
    s.release();
  } catch (_) {}
}
