import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool _announced = false;

void watchForAppUpdate(void Function() onReady) {
  void ready() {
    if (_announced) return;
    _announced = true;
    onReady();
  }

  web.window.addEventListener('oci-update-ready', ((web.Event _) => ready()).toJS);
  final flag = globalContext.getProperty<JSAny?>('ociUpdateReady'.toJS);
  if (flag.isA<JSBoolean>() && (flag as JSBoolean).toDart) ready();
}

void applyAppUpdate() {
  final apply = globalContext.getProperty<JSAny?>('ociApplyUpdate'.toJS);
  if (apply.isA<JSFunction>()) {
    (apply as JSFunction).callAsFunction();
  } else {
    web.window.location.reload();
  }
}
