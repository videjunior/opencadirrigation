/// Platform source of keyboard events for [Hotkeys]: a native window
/// listener in the browser, `HardwareKeyboard` elsewhere.
library;

import 'hotkeys.dart';
import 'native_keys_stub.dart' if (dart.library.js_interop) 'native_keys_web.dart' as impl;

/// Installs the platform listener; call [NativeHotkeys.dispose] to remove it.
abstract class NativeHotkeys {
  factory NativeHotkeys(bool Function(HotkeyEvent e) handler) => impl.createNativeHotkeys(handler);
  void install();
  void dispose();
}
