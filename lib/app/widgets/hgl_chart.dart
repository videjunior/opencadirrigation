import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/results.dart';
import '../../core/units.dart';

/// Hydraulic grade line chart for an ordered list of pipe segments.
class HglChart extends StatelessWidget {
  const HglChart({super.key, required this.segments, required this.units, this.allowedMin, this.allowedMax, this.title = '', this.legend = ''});
  final List<PipeSegmentResult> segments;
  final Units units;
  final double? allowedMin;
  final double? allowedMax;
  final String title;
  final String legend;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const Center(child: Text('—'));
    return CustomPaint(painter: _HglPainter(segments, units, allowedMin, allowedMax, title, legend), size: Size.infinite);
  }
}

class _HglPainter extends CustomPainter {
  _HglPainter(this.segs, this.u, this.lo, this.hi, this.title, this.legend);
  final List<PipeSegmentResult> segs;
  final Units u;
  final double? lo;
  final double? hi;
  final String title;
  final String legend;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 56.0, right = 16.0, top = 22.0, bottom = 28.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;
    // build profile
    final xs = <double>[0];
    final elev = <double>[segs.first.elevationA];
    final head = <double>[segs.first.pressureStart + segs.first.elevationA];
    var d = 0.0;
    for (final s in segs) {
      d += s.length;
      xs.add(d);
      elev.add(s.elevationB);
      head.add(s.pressureEnd + s.elevationB);
    }
    var yMin = double.infinity, yMax = -double.infinity;
    for (var i = 0; i < xs.length; i++) {
      yMin = math.min(yMin, math.min(elev[i], head[i]));
      yMax = math.max(yMax, math.max(elev[i], head[i]));
      if (lo != null) yMin = math.min(yMin, elev[i] + lo!);
      if (hi != null) yMax = math.max(yMax, elev[i] + hi!);
    }
    if (yMax - yMin < 1) {
      yMax += 1;
      yMin -= 1;
    }
    final pad = (yMax - yMin) * 0.1;
    yMin -= pad;
    yMax += pad;
    final xMax = math.max(d, 1e-6);
    Offset pt(double x, double y) => Offset(left + x / xMax * w, top + (1 - (y - yMin) / (yMax - yMin)) * h);
    // axes/grid
    final gridPaint = Paint()
      ..color = const Color(0xFF2B333C)
      ..strokeWidth = 1;
    final txt = TextStyle(color: Colors.white60, fontSize: 10);
    for (var i = 0; i <= 5; i++) {
      final y = yMin + (yMax - yMin) * i / 5;
      final o = pt(0, y);
      canvas.drawLine(Offset(left, o.dy), Offset(left + w, o.dy), gridPaint);
      final tp = TextPainter(text: TextSpan(text: fmt(y, 1), style: txt), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(left - tp.width - 4, o.dy - tp.height / 2));
    }
    for (var i = 0; i <= 5; i++) {
      final x = xMax * i / 5;
      final o = pt(x, yMin);
      canvas.drawLine(Offset(o.dx, top), Offset(o.dx, top + h), gridPaint);
      final tp = TextPainter(text: TextSpan(text: '${fmt(u.lengthFromSi(x), 0)} ${u.lengthLabel}', style: txt), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, top + h + 4));
    }
    // limits band
    if (lo != null && hi != null) {
      final band = Path()..moveTo(pt(xs[0], elev[0] + lo!).dx, pt(xs[0], elev[0] + lo!).dy);
      for (var i = 1; i < xs.length; i++) {
        final o = pt(xs[i], elev[i] + lo!);
        band.lineTo(o.dx, o.dy);
      }
      for (var i = xs.length - 1; i >= 0; i--) {
        final o = pt(xs[i], elev[i] + hi!);
        band.lineTo(o.dx, o.dy);
      }
      band.close();
      canvas.drawPath(band, Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.15));
    }
    // ground
    final ground = Path()..moveTo(pt(0, elev[0]).dx, pt(0, elev[0]).dy);
    for (var i = 1; i < xs.length; i++) {
      final o = pt(xs[i], elev[i]);
      ground.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(ground, Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
    // hgl
    final hgl = Path()..moveTo(pt(0, head[0]).dx, pt(0, head[0]).dy);
    for (var i = 1; i < xs.length; i++) {
      final o = pt(xs[i], head[i]);
      hgl.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(hgl, Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
    // pressure fill between
    final fill = Path()..addPath(hgl, Offset.zero);
    for (var i = xs.length - 1; i >= 0; i--) {
      final o = pt(xs[i], elev[i]);
      fill.lineTo(o.dx, o.dy);
    }
    fill.close();
    canvas.drawPath(fill, Paint()..color = const Color(0xFF42A5F5).withValues(alpha: 0.08));
    final tp = TextPainter(text: TextSpan(text: '$title   $legend   ${u.pressureLabel}', style: const TextStyle(color: Colors.white70, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, const Offset(left, 4));
  }

  @override
  bool shouldRepaint(covariant _HglPainter old) => true;
}
