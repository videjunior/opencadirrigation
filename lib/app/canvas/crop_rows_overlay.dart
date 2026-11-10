/// 1.7.0 ROW: the crop rows read from the image, drawn over the drawing
/// while the dialog that read them is open (nothing is added to the project
/// until the user applies them).
library;

import 'dart:ui';

import '../../core/model/geometry.dart';
import '../io/crop_row_pixels.dart' show CropRowSession;
import '../state/controller.dart';
import 'camera.dart';

/// Amber with a dark edge: it reads on aerial imagery and on both canvas
/// themes alike.
const _ink = Color(0xFFFFD740), _edge = Color(0xB3000000);

/// Paints the rows of [c]'s crop row session, if any, through [cam].
void paintCropRowPreview(Canvas canvas, Camera cam, ProjectController c) {
  final lines = CropRowSession.of(c).preview;
  if (lines.isEmpty) return;
  final vis = cam.visible;
  final edge = Paint()
    ..color = _edge
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;
  final ink = Paint()
    ..color = _ink
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  final path = Path();
  var n = 0;
  for (final l in lines) {
    if (l.length < 2 || !Bounds.ofPoints(l).intersects(vis)) continue;
    if (++n > 5000) break;
    final a = cam.toScreen(l.first), b = cam.toScreen(l.last);
    path
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
  }
  if (n == 0) return;
  canvas.drawPath(path, edge);
  canvas.drawPath(path, ink);
}
