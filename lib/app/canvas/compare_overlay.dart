/// The differences of a comparison with another copy of the project
/// (1.6.0 CAD, PRD-11) drawn over the drawing: a frame round each item
/// added (green), changed (amber) and removed (red, with what it was drawn
/// thin), until the next edit.
library;

import 'dart:ui';

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/project_compare.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'camera.dart';

/// The comparison shown on the drawing of each tab, and the edit it was
/// made at (it stops showing after the next edit).
final _shown = Expando<(ProjectComparison, int)>('comparison');

extension ComparisonView on ProjectController {
  /// The comparison shown on the drawing, or null (none, or the drawing
  /// changed since).
  ProjectComparison? get shownComparison {
    final s = _shown[this];
    return s == null || s.$2 != editSeq ? null : s.$1;
  }

  /// Shows [cmp] on the drawing (null hides it).
  void showComparison(ProjectComparison? cmp) {
    _shown[this] = cmp == null ? null : (cmp, editSeq);
    refresh();
  }
}

/// Draws [ProjectController.shownComparison] of [c] with [cam].
void paintComparison(Canvas canvas, Camera cam, ProjectController c) {
  final cmp = c.shownComparison;
  if (cmp == null) return;
  final vis = cam.visible.inflate(10 / cam.scale);
  final removed = {for (final e in cmp.before.entities) e.id: e};
  var n = 0;
  for (final ch in cmp.changes) {
    if (!ch.bounds.intersects(vis)) continue;
    if (++n > 3000) break;
    final color = switch (ch.kind) {
      ChangeKind.added => Cad.ok,
      ChangeKind.changed => Cad.attention,
      ChangeKind.removed => Cad.error,
    };
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final a = cam.toScreen(Pt(ch.bounds.minX, ch.bounds.maxY)), b = cam.toScreen(Pt(ch.bounds.maxX, ch.bounds.minY));
    final r = Rect.fromPoints(a, b).inflate(5);
    canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.10));
    canvas.drawRect(r, stroke);
    if (ch.kind == ChangeKind.removed) {
      // what it was
      final pts = removed[ch.id]?.linearPoints;
      if (pts != null && pts.length >= 2) {
        final path = Path()..moveTo(cam.toScreen(pts.first).dx, cam.toScreen(pts.first).dy);
        for (final p in pts.skip(1)) {
          final o = cam.toScreen(p);
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, stroke..strokeWidth = 1);
      }
    }
  }
}
