/// What the canvas exposes to the keyboard dispatcher (registered on the
/// controller while the canvas is mounted).
library;

import '../../core/model/geometry.dart';

abstract class CanvasKeyTarget {
  /// 'Escape', 'Enter' or 'Backspace' to the active tool, then repaint;
  /// 'Cancel' drops what the tool has in progress (Esc may keep it).
  void toolKey(String key);

  /// No polyline in progress.
  bool get toolIdle;

  /// Space held: the next drag pans.
  void setSpaceHeld(bool held);

  /// Shift changed: recompute the rubber band (angle lock).
  void modifiersChanged();
  void redraw();

  /// The previous point of the active tool and the cursor (world), for
  /// coordinates typed relative to them.
  Pt? get referencePoint;
  Pt? get cursorPoint;

  /// Gives the active tool [p] as if it had been clicked there.
  void feedPoint(Pt p);

  /// Gives the active tool the text typed on the command line before it is
  /// read as a point or an alias (an option, the value of its step); true
  /// when the tool took it.
  bool toolInput(String text);
}
