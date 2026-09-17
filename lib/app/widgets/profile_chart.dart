import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/units.dart';

/// Ground elevation profile along a path: (station, elevation) samples,
/// optionally with the pipe line (below the ground by its depth) and the
/// hydraulic grade line of a designed pipe, a legend and a hover readout.
class ProfileChart extends StatefulWidget {
  const ProfileChart({
    super.key,
    required this.samples,
    required this.units,
    this.title = '',
    this.xLabel = '',
    this.yLabel = '',
    this.pipe,
    this.hgl,
    this.legendGround = '',
    this.legendPipe = '',
    this.legendHgl = '',
    this.legendLow = '',
    this.legendHigh = '',
    this.stationLabel = '',
    this.pressureLabel = '',
  });
  final List<(double, double)> samples;
  final Units units;
  final String title;
  final String xLabel;
  final String yLabel;

  /// Pipe elevation (station, z) and hydraulic grade line (station, head).
  final List<(double, double)>? pipe;
  final List<(double, double)>? hgl;
  final String legendGround, legendPipe, legendHgl, legendLow, legendHigh, stationLabel, pressureLabel;

  @override
  State<ProfileChart> createState() => _ProfileChartState();
}

class _ProfileChartState extends State<ProfileChart> {
  Offset? _hover;

  @override
  Widget build(BuildContext context) {
    if (widget.samples.length < 2) return const Center(child: Text('—'));
    return MouseRegion(
      onHover: (e) => setState(() => _hover = e.localPosition),
      onExit: (_) => setState(() => _hover = null),
      child: GestureDetector(
        onTapDown: (d) => setState(() => _hover = d.localPosition),
        onPanUpdate: (d) => setState(() => _hover = d.localPosition),
        child: CustomPaint(painter: _ProfilePainter(widget, _hover), size: Size.infinite),
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.w, this.hover);
  final ProfileChart w;
  final Offset? hover;

  static const groundColor = Color(0xFF8D6E63);
  static const pipeColor = Color(0xFF42A5F5);
  static const hglColor = Color(0xFF66BB6A);
  static const lowColor = Color(0xFF29B6F6);
  static const highColor = Color(0xFFFFA726);

  @override
  void paint(Canvas canvas, Size size) {
    final s = w.samples;
    final u = w.units;
    const left = 56.0, right = 16.0, top = 22.0, bottom = 44.0;
    final width = size.width - left - right, h = size.height - top - bottom;
    if (width <= 0 || h <= 0) return;
    var yMin = double.infinity, yMax = -double.infinity;
    void span(Iterable<(double, double)>? list) {
      if (list == null) return;
      for (final (_, z) in list) {
        yMin = math.min(yMin, z);
        yMax = math.max(yMax, z);
      }
    }

    span(s);
    span(w.pipe);
    span(w.hgl);
    if (yMax - yMin < 1) {
      yMax += 0.5;
      yMin -= 0.5;
    }
    final pad = (yMax - yMin) * 0.15;
    yMin -= pad;
    yMax += pad;
    var xMax = math.max(s.last.$1, 1e-6);
    for (final l in [w.pipe, w.hgl]) {
      if (l != null && l.isNotEmpty) xMax = math.max(xMax, l.last.$1);
    }
    Offset pt(double x, double y) => Offset(left + x / xMax * width, top + (1 - (y - yMin) / (yMax - yMin)) * h);
    final gridPaint = Paint()
      ..color = const Color(0xFF2B333C)
      ..strokeWidth = 1;
    const txt = TextStyle(color: Colors.white60, fontSize: 10);
    for (var i = 0; i <= 5; i++) {
      final y = yMin + (yMax - yMin) * i / 5;
      final o = pt(0, y);
      canvas.drawLine(Offset(left, o.dy), Offset(left + width, o.dy), gridPaint);
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
    Path line(List<(double, double)> list) {
      final p = Path()..moveTo(pt(list[0].$1, list[0].$2).dx, pt(list[0].$1, list[0].$2).dy);
      for (var i = 1; i < list.length; i++) {
        final o = pt(list[i].$1, list[i].$2);
        p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    final ground = line(s);
    final fill = Path()..addPath(ground, Offset.zero);
    fill.lineTo(pt(s.last.$1, yMin).dx, pt(s.last.$1, yMin).dy);
    fill.lineTo(pt(0, yMin).dx, pt(0, yMin).dy);
    fill.close();
    canvas.drawPath(fill, Paint()..color = groundColor.withValues(alpha: 0.2));
    canvas.drawPath(ground, Paint()
      ..color = groundColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
    if (w.pipe != null && w.pipe!.length >= 2) {
      canvas.drawPath(line(w.pipe!), Paint()
        ..color = pipeColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke);
    }
    if (w.hgl != null && w.hgl!.length >= 2) {
      canvas.drawPath(line(w.hgl!), Paint()
        ..color = hglColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke);
    }
    // min / max markers
    var lo = s.first, hi = s.first;
    for (final p in s) {
      if (p.$2 < lo.$2) lo = p;
      if (p.$2 > hi.$2) hi = p;
    }
    for (final (p, col) in [(lo, lowColor), (hi, highColor)]) {
      final o = pt(p.$1, p.$2);
      canvas.drawCircle(o, 3.5, Paint()..color = col);
      final tp = TextPainter(text: TextSpan(text: fmt(p.$2, 2), style: TextStyle(color: col, fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o + Offset(5, identical(p, hi) ? -13 : 3));
    }
    final tp = TextPainter(text: TextSpan(text: '${w.title}   ${w.yLabel}', style: const TextStyle(color: Colors.white70, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, const Offset(left, 4));
    // legend (bottom row)
    var lx = left;
    final ly = size.height - 12;
    void legend(Color col, String label, {bool dot = false}) {
      if (label.isEmpty) return;
      if (dot) {
        canvas.drawCircle(Offset(lx + 6, ly), 3.5, Paint()..color = col);
      } else {
        canvas.drawLine(Offset(lx, ly), Offset(lx + 14, ly), Paint()
          ..color = col
          ..strokeWidth = 2.5);
      }
      final t = TextPainter(text: TextSpan(text: label, style: const TextStyle(color: Colors.white60, fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      t.paint(canvas, Offset(lx + 18, ly - t.height / 2));
      lx += 18 + t.width + 14;
    }

    legend(groundColor, w.legendGround);
    if (w.pipe != null && w.pipe!.length >= 2) legend(pipeColor, w.legendPipe);
    if (w.hgl != null && w.hgl!.length >= 2) legend(hglColor, w.legendHgl);
    legend(lowColor, w.legendLow, dot: true);
    legend(highColor, w.legendHigh, dot: true);
    // hover readout
    final hv = hover;
    if (hv != null && hv.dx >= left && hv.dx <= left + width && hv.dy >= top && hv.dy <= top + h) {
      final x = (hv.dx - left) / width * xMax;
      final z = _interp(s, x);
      final o = pt(x, z);
      canvas.drawLine(Offset(o.dx, top), Offset(o.dx, top + h), Paint()
        ..color = Colors.white30
        ..strokeWidth = 1);
      canvas.drawCircle(o, 4, Paint()..color = Colors.white);
      var text = '${w.stationLabel} ${fmt(u.lengthFromSi(x), 1)} ${u.lengthLabel}   ${fmt(z, 2)} m';
      final hg = w.hgl;
      if (hg != null && hg.length >= 2 && x <= hg.last.$1 + 1e-9) {
        final head = _interp(hg, x);
        final pz = w.pipe != null && w.pipe!.length >= 2 ? _interp(w.pipe!, x) : z;
        text += '   ${w.pressureLabel} ${fmt(u.pressureFromHead(head - pz), 1)} ${u.pressureLabel}';
      }
      final t = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 10.5)), textDirection: TextDirection.ltr)..layout();
      var tx = o.dx + 8;
      if (tx + t.width > size.width - 4) tx = o.dx - t.width - 8;
      final ty = (o.dy - 24).clamp(top, top + h - t.height);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tx - 3, ty - 2, t.width + 6, t.height + 4), const Radius.circular(3)), Paint()..color = const Color(0xDD1B1F24));
      t.paint(canvas, Offset(tx, ty));
    }
  }

  static double _interp(List<(double, double)> list, double x) {
    if (x <= list.first.$1) return list.first.$2;
    for (var i = 1; i < list.length; i++) {
      if (x <= list[i].$1) {
        final (x0, y0) = list[i - 1];
        final (x1, y1) = list[i];
        final f = x1 - x0 < 1e-12 ? 0.0 : (x - x0) / (x1 - x0);
        return y0 + (y1 - y0) * f;
      }
    }
    return list.last.$2;
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) => true;
}
