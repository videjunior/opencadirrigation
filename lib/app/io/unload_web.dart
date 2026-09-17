import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool Function()? _isDirty;
bool _installed = false;

void setUnloadGuard(bool Function() isDirty) {
  _isDirty = isDirty;
  if (_installed) return;
  _installed = true;
  web.window.addEventListener(
    'beforeunload',
    ((web.Event e) {
      if (_isDirty?.call() ?? false) {
        e.preventDefault();
        (e as web.BeforeUnloadEvent).returnValue = 'unsaved';
      }
    }).toJS,
  );
}
