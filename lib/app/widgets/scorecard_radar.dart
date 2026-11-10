/// Radar chart of the design scorecard (1.7.0 SCR): one spoke per category,
/// the rings at the grade limits (60, 70, 80, 90 and 100), the polygon of
/// the assessed categories and, dashed, the one compared with. A category
/// not assessed has a dashed spoke and no vertex.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// One spoke: its label and the scores (null: not assessed).
typedef RadarAxis = ({String label, double? score, double? compare});

class ScorecardRadar extends StatelessWidget {
  const ScorecardRadar({super.key, required this.axes, this.size = 260, this.semanticLabel = ''});
  final List<RadarAxis> axes;
  final double size;

  /// What a screen reader says (the scores in words).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RadarPainter(axes, Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 11), MediaQuery.textScalerOf(context), Directionality.of(context))),
    ),
  );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.axes, this.style, this.scaler, this.direction);
  final List<RadarAxis> axes;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) return;
    // room for the labels around the polygon
    final c = size.center(Offset.zero);
    final r = math.max(10.0, size.shortestSide / 2 - scaler.scale(30));
    Offset at(int i, double score) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      return c + Offset(math.cos(a), math.sin(a)) * (r * score.clamp(0, 100) / 100);
    }

    Path poly(double score) => Path()..addPolygon([for (var i = 0; i < n; i++) at(i, score)], true);
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Cad.fg12;
    for (final ring in const [60.0, 70.0, 80.0, 90.0]) {
      canvas.drawPath(poly(ring), grid);
    }
    canvas.drawPath(poly(100), grid..color = Cad.fg24);
    for (var i = 0; i < n; i++) {
      final assessed = axes[i].score != null;
      _dashedOrSolid(
        canvas,
        c,
        at(i, 100),
        Paint()
          ..strokeWidth = 1
          ..color = assessed ? Cad.fg24 : Cad.fg12,
        dashed: !assessed,
      );
    }
    // ring values on the first spoke
    for (final ring in const [60.0, 80.0, 100.0]) {
      _text(canvas, ring.toStringAsFixed(0), at(0, ring) + const Offset(3, -6), style.copyWith(fontSize: 9, color: Cad.fg38), align: TextAlign.left);
    }
    // the compared polygon, dashed
    final cmp = [
      for (var i = 0; i < n; i++)
        if (axes[i].compare != null) at(i, axes[i].compare!),
    ];
    if (cmp.length >= 2) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Cad.fg54;
      for (var k = 0; k < cmp.length; k++) {
        if (k == cmp.length - 1 && cmp.length < 3) break;
        _dashedOrSolid(canvas, cmp[k], cmp[(k + 1) % cmp.length], paint, dashed: true);
      }
    }
    // the scores
    final pts = [
      for (var i = 0; i < n; i++)
        if (axes[i].score != null) at(i, axes[i].score!),
    ];
    final accent = Cad.accent;
    if (pts.length >= 3) {
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, Paint()..color = accent.withValues(alpha: 0.22));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent,
      );
    } else if (pts.length == 2) {
      canvas.drawLine(
        pts[0],
        pts[1],
        Paint()
          ..strokeWidth = 2
          ..color = accent,
      );
    }
    for (var i = 0; i < n; i++) {
      final s = axes[i].score;
      if (s != null) canvas.drawCircle(at(i, s), 3.5, Paint()..color = s < 60 ? Cad.error : (s < 80 ? Cad.caution : Cad.ok));
    }
    // labels outside the 100 ring
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      final q = c + Offset(math.cos(a), math.sin(a)) * (r + 6);
      final s = axes[i].score;
      final label = '${axes[i].label}\n${s == null ? '–' : s.toStringAsFixed(0)}';
      final cosA = math.cos(a);
      final align = cosA.abs() < 0.25 ? TextAlign.center : (cosA > 0 ? TextAlign.left : TextAlign.right);
      _text(
        canvas,
        label,
        q,
        style.copyWith(fontSize: 10.5, color: s == null ? Cad.fg38 : Cad.fg87, fontWeight: s == null ? null : FontWeight.w600),
        align: align,
        below: math.sin(a) > 0.25,
        above: math.sin(a) < -0.25,
        maxWidth: size.width / 3.2,
      );
    }
  }

  void _dashedOrSolid(Canvas canvas, Offset a, Offset b, Paint p, {bool dashed = false}) {
    if (!dashed) {
      canvas.drawLine(a, b, p);
      return;
    }
    final d = b - a;
    final len = d.distance;
    if (len <= 0) return;
    final u = d / len;
    for (var s = 0.0; s < len; s += 8) {
      canvas.drawLine(a + u * s, a + u * math.min(len, s + 4), p);
    }
  }

  void _text(Canvas canvas, String s, Offset at, TextStyle st, {TextAlign align = TextAlign.center, bool below = false, bool above = false, double maxWidth = 120}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: st),
      textAlign: align,
      textDirection: direction,
      textScaler: scaler,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    var x = at.dx;
    if (align == TextAlign.center) x -= tp.width / 2;
    if (align == TextAlign.right) x -= tp.width;
    var y = at.dy - tp.height / 2;
    if (below) y = at.dy;
    if (above) y = at.dy - tp.height;
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}
