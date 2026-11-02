import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/results.dart';
import '../../core/units.dart';
import '../theme.dart';
import 'fields.dart' show fmtUi;

/// Hydraulic grade line chart for an ordered list of pipe segments: the
/// ground and the head along the pipe in the length unit (elevations and
/// heads, not pressures), the allowed band, and under the pointer (mouse or
/// finger) the distance, the ground, the head and the pressure there.
class HglChart extends StatefulWidget {
  const HglChart({super.key, required this.segments, required this.units, this.allowedMin, this.allowedMax, this.title = '', this.legend = '', this.axisLabel = '', this.readout});
  final List<PipeSegmentResult> segments;
  final Units units;
  final double? allowedMin;
  final double? allowedMax;
  final String title;
  final String legend;

  /// Name of the vertical axis, with its unit ("elevation / head (m)").
  final String axisLabel;

  /// The line under the pointer from the distance, the ground, the head and
  /// the pressure there (already formatted with their units).
  final String Function(String d, String z, String h, String p)? readout;

  @override
  State<HglChart> createState() => _HglChartState();
}

class _HglChartState extends State<HglChart> {
  /// The pointer's x in the chart (null: away).
  double? _x;

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) return const Center(child: Text('—'));
    final profile = HglProfile.of(widget.segments);
    return MouseRegion(
      onHover: (e) => setState(() => _x = e.localPosition.dx),
      onExit: (_) => setState(() => _x = null),
      child: GestureDetector(
        onPanDown: (e) => setState(() => _x = e.localPosition.dx),
        onPanUpdate: (e) => setState(() => _x = e.localPosition.dx),
        onPanEnd: (_) => setState(() => _x = null),
        child: CustomPaint(key: const Key('hgl_chart'), painter: _HglPainter(profile, widget, _x), size: Size.infinite),
      ),
    );
  }
}

/// The ground and the head of an ordered list of segments, by distance.
class HglProfile {
  HglProfile(this.xs, this.elev, this.head);
  final List<double> xs, elev, head;

  factory HglProfile.of(List<PipeSegmentResult> segs) {
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
    return HglProfile(xs, elev, head);
  }

  double get length => xs.last;

  /// Ground and head at distance [d] (linear along each segment).
  (double, double) at(double d) {
    if (d <= 0) return (elev.first, head.first);
    for (var i = 1; i < xs.length; i++) {
      if (d <= xs[i]) {
        final f = xs[i] > xs[i - 1] ? (d - xs[i - 1]) / (xs[i] - xs[i - 1]) : 1.0;
        return (elev[i - 1] + (elev[i] - elev[i - 1]) * f, head[i - 1] + (head[i] - head[i - 1]) * f);
      }
    }
    return (elev.last, head.last);
  }
}

class _HglPainter extends CustomPainter {
  _HglPainter(this.p, this.w, this.cursorX);
  final HglProfile p;
  final HglChart w;
  final double? cursorX;

  static const left = 56.0, right = 16.0, top = 22.0, bottom = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final u = w.units;
    final lo = w.allowedMin, hi = w.allowedMax;
    final cw = size.width - left - right, ch = size.height - top - bottom;
    if (cw <= 0 || ch <= 0) return;
    final xs = p.xs, elev = p.elev, head = p.head;
    var yMin = double.infinity, yMax = -double.infinity;
    for (var i = 0; i < xs.length; i++) {
      yMin = math.min(yMin, math.min(elev[i], head[i]));
      yMax = math.max(yMax, math.max(elev[i], head[i]));
      if (lo != null) yMin = math.min(yMin, elev[i] + lo);
      if (hi != null) yMax = math.max(yMax, elev[i] + hi);
    }
    if (yMax - yMin < 1) {
      yMax += 1;
      yMin -= 1;
    }
    final pad = (yMax - yMin) * 0.1;
    yMin -= pad;
    yMax += pad;
    final xMax = math.max(p.length, 1e-6);
    Offset pt(double x, double y) => Offset(left + x / xMax * cw, top + (1 - (y - yMin) / (yMax - yMin)) * ch);
    // axes/grid: the vertical axis holds elevations and heads, in the length unit
    final gridPaint = Paint()
      ..color = Cad.chartGrid
      ..strokeWidth = 1;
    final txt = TextStyle(color: Cad.fg60, fontSize: 10);
    for (var i = 0; i <= 5; i++) {
      final y = yMin + (yMax - yMin) * i / 5;
      final o = pt(0, y);
      canvas.drawLine(Offset(left, o.dy), Offset(left + cw, o.dy), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: fmtUi(u.lengthFromSi(y), 1), style: txt),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 4, o.dy - tp.height / 2));
    }
    for (var i = 0; i <= 5; i++) {
      final x = xMax * i / 5;
      final o = pt(x, yMin);
      canvas.drawLine(Offset(o.dx, top), Offset(o.dx, top + ch), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${fmtUi(u.lengthFromSi(x), 0)} ${u.lengthLabel}', style: txt),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, top + ch + 4));
    }
    // limits band
    if (lo != null && hi != null) {
      final band = Path()..moveTo(pt(xs[0], elev[0] + lo).dx, pt(xs[0], elev[0] + lo).dy);
      for (var i = 1; i < xs.length; i++) {
        final o = pt(xs[i], elev[i] + lo);
        band.lineTo(o.dx, o.dy);
      }
      for (var i = xs.length - 1; i >= 0; i--) {
        final o = pt(xs[i], elev[i] + hi);
        band.lineTo(o.dx, o.dy);
      }
      band.close();
      canvas.drawPath(band, Paint()..color = Cad.chartHgl.withValues(alpha: 0.15));
    }
    // ground
    final ground = Path()..moveTo(pt(0, elev[0]).dx, pt(0, elev[0]).dy);
    for (var i = 1; i < xs.length; i++) {
      final o = pt(xs[i], elev[i]);
      ground.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      ground,
      Paint()
        ..color = Cad.chartGround
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    // hgl
    final hgl = Path()..moveTo(pt(0, head[0]).dx, pt(0, head[0]).dy);
    for (var i = 1; i < xs.length; i++) {
      final o = pt(xs[i], head[i]);
      hgl.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      hgl,
      Paint()
        ..color = Cad.chartPipe
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    // pressure fill between
    final fill = Path()..addPath(hgl, Offset.zero);
    for (var i = xs.length - 1; i >= 0; i--) {
      final o = pt(xs[i], elev[i]);
      fill.lineTo(o.dx, o.dy);
    }
    fill.close();
    canvas.drawPath(fill, Paint()..color = Cad.chartPipe.withValues(alpha: 0.08));
    final axis = w.axisLabel.isEmpty ? u.lengthLabel : w.axisLabel;
    final tp = TextPainter(
      text: TextSpan(
        text: '${w.title}   ${w.legend}   $axis',
        style: TextStyle(color: Cad.fg70, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(0, size.width - left));
    tp.paint(canvas, const Offset(left, 4));
    // the reading under the pointer
    final cx = cursorX;
    final readout = w.readout;
    if (cx != null && readout != null && cx >= left && cx <= left + cw) {
      final d = (cx - left) / cw * xMax;
      final (z, h) = p.at(d);
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx, top + ch),
        Paint()
          ..color = Cad.fg54
          ..strokeWidth = 1,
      );
      for (final (y, col) in [(z, Cad.chartGround), (h, Cad.chartPipe)]) {
        canvas.drawCircle(pt(d, y), 3.5, Paint()..color = col);
      }
      final line = readout(
        '${fmtUi(u.lengthFromSi(d), 1)} ${u.lengthLabel}',
        '${fmtUi(u.lengthFromSi(z), 2)} ${u.lengthLabel}',
        '${fmtUi(u.lengthFromSi(h), 2)} ${u.lengthLabel}',
        '${fmtUi(u.pressureFromHead(h - z), 2)} ${u.pressureLabel}',
      );
      final rp = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(color: Cad.fg, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(40, cw - 8));
      final bx = (cx + 8 + rp.width + 8 > left + cw ? cx - 8 - rp.width - 8 : cx + 8).clamp(left, math.max(left, left + cw - rp.width - 8)).toDouble();
      final box = Rect.fromLTWH(bx, top + 4, rp.width + 8, rp.height + 6);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), Paint()..color = Cad.raisedTranslucent);
      rp.paint(canvas, Offset(box.left + 4, box.top + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _HglPainter old) => true;
}
