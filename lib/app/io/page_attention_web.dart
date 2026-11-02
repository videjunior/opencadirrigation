/// Browser: `document.hidden` and `document.hasFocus()`, the title of the
/// tab, and the Notifications API where the browser has it.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'page_attention.dart';

PageAttention platformPageAttention() => _WebAttention();

class _WebAttention implements PageAttention {
  _WebAttention() {
    try {
      final back = ((web.Event _) {
        if (inBackground) return;
        stopBlink();
        for (final f in [..._foreground]) {
          try {
            f();
          } catch (_) {}
        }
      }).toJS;
      web.document.addEventListener('visibilitychange', back);
      web.window.addEventListener('focus', back);
    } catch (_) {
      // a page without these events: the blinking stops on its own call
    }
  }

  final List<void Function()> _foreground = [];
  Timer? _blink;

  /// The title of the tab before the blinking started.
  String? _title;

  @override
  bool get inBackground {
    try {
      return web.document.hidden || !web.document.hasFocus();
    } catch (_) {
      return false;
    }
  }

  @override
  void blinkTitle(String text) {
    try {
      _title ??= web.document.title;
      _blink?.cancel();
      var on = true;
      web.document.title = text;
      _blink = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        on = !on;
        try {
          web.document.title = on ? text : (_title ?? '');
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  void stopBlink() {
    _blink?.cancel();
    _blink = null;
    final t = _title;
    _title = null;
    if (t == null) return;
    try {
      web.document.title = t;
    } catch (_) {}
  }

  bool get _supported {
    try {
      return globalContext.has('Notification');
    } catch (_) {
      return false;
    }
  }

  @override
  String get notificationPermission {
    if (!_supported) return 'unsupported';
    try {
      return web.Notification.permission;
    } catch (_) {
      return 'unsupported';
    }
  }

  @override
  Future<String> requestNotifications() async {
    if (!_supported) return 'unsupported';
    try {
      return (await web.Notification.requestPermission().toDart).toDart;
    } catch (_) {
      return notificationPermission;
    }
  }

  @override
  void notify(String title, String body, {String tag = ''}) {
    if (notificationPermission != 'granted') return;
    try {
      final n = web.Notification(title, web.NotificationOptions(body: body, tag: tag));
      n.onclick = ((web.Event _) {
        try {
          web.window.focus();
          n.close();
        } catch (_) {}
      }).toJS;
    } catch (_) {}
  }

  @override
  void onForeground(void Function() f) => _foreground.add(f);
}
