/// How the window is arranged: chosen by its width, its height and the
/// pointer in use, so a phone held sideways (844 × 390) gets the touch
/// layout and a tablet in portrait keeps the drawing in view.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The three arrangements of the main window.
enum ShellLayout {
  /// Phones (any orientation) and windows narrower than [phoneMaxWidth]:
  /// ☰ menu, bottom tool bar, floating Done / Cancel buttons, panels in
  /// sheets.
  phone,

  /// Tablets and small windows: the desktop layout with the side panel in a
  /// drawer over the drawing and the AI assistant in a sheet.
  narrow,

  /// Everything docked: side panel and AI assistant beside the drawing.
  wide,
}

/// Below this width the phone layout is used whatever the pointer.
const phoneMaxWidth = 700.0;

/// A touch screen whose short side is below this is a phone.
const phoneMaxShortSide = 500.0;

/// From this width on the side panel and the AI assistant dock beside the
/// drawing.
const wideMinWidth = 1100.0;

/// Kind of the last pointer pressed on the screen (null before any).
final ValueNotifier<PointerDeviceKind?> lastPointerKind = ValueNotifier<PointerDeviceKind?>(null);

void _trackPointer(PointerEvent e) {
  if (e is PointerDownEvent && lastPointerKind.value != e.kind) lastPointerKind.value = e.kind;
}

var _tracking = 0;

/// Starts following the pointer kind (see [lastPointerKind]); balanced by
/// [stopPointerKindTracking].
void startPointerKindTracking() {
  if (_tracking++ == 0) GestureBinding.instance.pointerRouter.addGlobalRoute(_trackPointer);
}

void stopPointerKindTracking() {
  if (_tracking == 0) return;
  if (--_tracking == 0) GestureBinding.instance.pointerRouter.removeGlobalRoute(_trackPointer);
}

/// Whether the user works with a finger or a pen: the last pointer was a
/// touch or a stylus, or, before any, the device is a phone or a tablet.
bool get touchInput => switch (lastPointerKind.value) {
  PointerDeviceKind.touch || PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => true,
  null => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
  _ => false,
};

/// The arrangement for a window of [size]; [touch] as [touchInput].
ShellLayout shellLayoutFor(Size size, {required bool touch}) {
  if (size.width < phoneMaxWidth) return ShellLayout.phone;
  if (touch && size.shortestSide < phoneMaxShortSide) return ShellLayout.phone;
  return size.width < wideMinWidth ? ShellLayout.narrow : ShellLayout.wide;
}

/// The arrangement of the window [context] is in.
ShellLayout shellLayoutOf(BuildContext context) => shellLayoutFor(MediaQuery.sizeOf(context), touch: touchInput);

/// Whether the AI assistant docks beside the drawing (else it opens in a
/// sheet or a dialog).
bool assistantDocks(BuildContext context) => shellLayoutOf(context) == ShellLayout.wide;
