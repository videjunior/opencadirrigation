/// The tools that mark the drawing for the AI assistant (ai_marks.dart):
/// the user points at places — "the pump goes here", "the mainline along
/// here" — instead of describing them. A mark is no project item: it goes
/// to [ProjectController.aiMarks] with no undo step and is never saved. The
/// canvas painter draws the marks and the line being marked (painter.dart),
/// so the screen and the assistant's pictures show them alike.
library;

import 'dart:ui';

import '../../core/model/geometry.dart';
import '../canvas/camera.dart';
import '../state/controller.dart';
import 'tools.dart';

/// Orange of the marks, the same on every theme and in the assistant's
/// pictures (the assistant is told to look for orange).
const aiMarkColor = Color(0xFFFF6D00);

/// Marks a point at each click ([ToolId.aiMarkPoint]) or takes the
/// vertices of a line ([ToolId.aiMarkLine]), snapping as the drawing tools
/// do; taps on a phone work as clicks. A line ends as one mark with Enter or
/// a double click and the tool waits for the next one; Esc drops the line
/// in progress and keeps the tool, Esc with no line leaves it, and so does
/// Enter with nothing in progress (Done on a phone).
class AiMarkTool extends Tool {
  /// [id] is [ToolId.aiMarkPoint] or [ToolId.aiMarkLine].
  AiMarkTool(super.c, super.host, this.id);
  @override
  final ToolId id;
  @override
  String get hintKey => 'hint.${hintKeyOf(id)}';

  /// It marks lines (else points).
  bool get line => id == ToolId.aiMarkLine;

  /// The vertices of the line in progress.
  final List<Pt> pts = [];

  /// The last Esc dropped a line in progress: the tool stays for the next
  /// one (see [idle]).
  bool _dropped = false;

  @override
  Pt? get referencePoint => pts.isEmpty ? null : pts.last;

  @override
  bool get idle => pts.isEmpty && !_dropped;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    _dropped = false;
    if (!line) {
      c.aiMarks.add([p]);
    } else if (pts.isEmpty || pts.last.distanceTo(p) > 1e-9) {
      pts.add(p);
    }
  }

  /// The second click of a double click ends the line; a point was marked
  /// by the first click already.
  @override
  void onDoubleClick(Pt p) {
    if (line) finish();
  }

  @override
  void onKey(String key) {
    _dropped = key == 'Escape' && pts.isNotEmpty;
    switch (key) {
      case 'Escape':
        pts.clear();
      case 'Enter' when pts.isEmpty:
        c.setTool(ToolId.select);
      case 'Enter':
        finish();
      case 'Backspace' when pts.isNotEmpty:
        pts.removeLast();
    }
  }

  /// Ends the line in progress as one mark (a single vertex marks a point).
  void finish() {
    if (pts.isNotEmpty) c.aiMarks.add(List.of(pts));
    pts.clear();
  }

  @override
  void cancel() {
    pts.clear();
    _dropped = false;
  }

  /// The painter draws the marks and the line in progress; the status bar
  /// shows the line's length as the polyline tool does.
  @override
  void paint(Canvas canvas, Camera cam) {
    final at = cursor;
    if (pts.isEmpty || at == null) return;
    final u = c.units;
    host.setStatus('d = ${u.lengthFromSi(pts.last.distanceTo(at)).toStringAsFixed(2)} ${u.lengthLabel}   L = ${u.lengthFromSi(polylineLength([...pts, at])).toStringAsFixed(2)} ${u.lengthLabel}');
  }
}
