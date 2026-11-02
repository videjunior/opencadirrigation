import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function()? _hidden, _closing;
bool _installed = false;

void watchPageLifecycle({required void Function() hidden, required void Function() closing}) {
  _hidden = hidden;
  _closing = closing;
  if (_installed) return;
  _installed = true;
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'hidden') _hidden?.call();
    }).toJS,
  );
  web.window.addEventListener('pagehide', ((web.Event _) => _closing?.call()).toJS);
}
