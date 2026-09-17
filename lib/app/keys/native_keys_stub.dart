/// Desktop/tests: every key event, before focus dispatch, through
/// `HardwareKeyboard`.
library;

import 'package:flutter/services.dart';

import 'hotkeys.dart';
import 'native_keys.dart';

NativeHotkeys createNativeHotkeys(bool Function(HotkeyEvent e) handler) => _HardwareHotkeys(handler);

class _HardwareHotkeys implements NativeHotkeys {
  _HardwareHotkeys(this.handler);
  final bool Function(HotkeyEvent e) handler;

  bool _onKey(KeyEvent e) => handler(HotkeyEvent.fromKeyEvent(e));

  @override
  void install() => HardwareKeyboard.instance.addHandler(_onKey);

  @override
  void dispose() => HardwareKeyboard.instance.removeHandler(_onKey);
}
