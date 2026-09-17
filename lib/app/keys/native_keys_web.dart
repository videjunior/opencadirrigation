/// Browser: a capture-phase `keydown`/`keyup` listener on `window`, ahead of
/// Flutter and of the browser's own bindings. Keys the dispatcher consumes
/// are default-prevented (no page reload on F5, no "save page" on Ctrl+S)
/// and hidden from Flutter (so a focused button never also reacts); their
/// release is hidden too, keeping Flutter's key state consistent. Keys typed
/// into a DOM text input are never touched.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'hotkeys.dart';
import 'native_keys.dart';

NativeHotkeys createNativeHotkeys(bool Function(HotkeyEvent e) handler) => _WindowHotkeys(handler);

class _WindowHotkeys implements NativeHotkeys {
  _WindowHotkeys(this.handler);
  final bool Function(HotkeyEvent e) handler;
  final Set<String> _consumed = {};
  JSFunction? _down;
  JSFunction? _up;

  static bool _isTextTarget(web.EventTarget? t) {
    if (t == null) return false;
    if (t.isA<web.HTMLInputElement>() || t.isA<web.HTMLTextAreaElement>()) return true;
    if (t.isA<web.HTMLElement>()) return (t as web.HTMLElement).isContentEditable;
    return false;
  }

  static HotkeyEvent _convert(web.KeyboardEvent e, {required bool down}) => HotkeyEvent(e.key, code: e.code, ctrl: e.ctrlKey, shift: e.shiftKey, alt: e.altKey, meta: e.metaKey, repeat: e.repeat, down: down);

  @override
  void install() {
    _down = ((web.KeyboardEvent e) {
      if (_isTextTarget(e.target)) return;
      if (handler(_convert(e, down: true))) {
        e.preventDefault();
        e.stopImmediatePropagation();
        _consumed.add(e.code);
      }
    }).toJS;
    _up = ((web.KeyboardEvent e) {
      final wasConsumed = _consumed.remove(e.code);
      if (!wasConsumed && _isTextTarget(e.target)) return;
      final handled = handler(_convert(e, down: false));
      if (wasConsumed || handled) {
        e.preventDefault();
        e.stopImmediatePropagation();
      }
    }).toJS;
    web.window.addEventListener('keydown', _down, true.toJS);
    web.window.addEventListener('keyup', _up, true.toJS);
  }

  @override
  void dispose() {
    if (_down != null) web.window.removeEventListener('keydown', _down, true.toJS);
    if (_up != null) web.window.removeEventListener('keyup', _up, true.toJS);
    _down = null;
    _up = null;
  }
}
