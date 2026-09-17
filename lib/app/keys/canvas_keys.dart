/// What the canvas exposes to the keyboard dispatcher (registered on the
/// controller while the canvas is mounted).
library;

abstract class CanvasKeyTarget {
  /// 'Escape', 'Enter' or 'Backspace' to the active tool, then repaint.
  void toolKey(String key);

  /// No polyline in progress.
  bool get toolIdle;

  /// Space held: the next drag pans.
  void setSpaceHeld(bool held);

  /// Shift changed: recompute the rubber band (angle lock).
  void modifiersChanged();
  void redraw();
}
