import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/terrain.dart';
import '../../core/units.dart';
import '../state/controller.dart';

/// Rotatable 3D view of the DEM (shaded mesh, painter's algorithm) with the
/// pipes and laterals draped on the surface.
class DemView extends StatefulWidget {
  const DemView({super.key, required this.c});
  final ProjectController c;

  @override
  State<DemView> createState() => _DemViewState();
}

class _DemViewState extends State<DemView> {
  double _azimuth = -0.6;
  double _tilt = 0.9;
  double _zoom = 1;
  double _exaggeration = 2;
  late final Terrain _terrain = widget.c.project.buildTerrain();
  late final _Mesh _mesh = _Mesh.build(widget.c, _terrain, 48);

  @override
  Widget build(BuildContext context) {
    final t = widget.c.t;
    if (_terrain.isEmpty) return Center(child: Text(t('dem.noData'), style: const TextStyle(color: Colors.white54)));
    final (lo, hi) = _terrain.elevationRange;
    return Column(children: [
      Row(children: [
        Text(t('dem.exaggeration'), style: const TextStyle(fontSize: 11.5)),
        Expanded(child: Slider(value: _exaggeration, min: 0.5, max: 10, divisions: 19, label: '${_exaggeration.toStringAsFixed(1)}×', onChanged: (v) => setState(() => _exaggeration = v))),
        Text(t('dem.range', {'a': fmt(lo, 1), 'b': fmt(hi, 1)}), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
      Expanded(
        child: Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) setState(() => _zoom = (_zoom * (e.scrollDelta.dy > 0 ? 0.9 : 1.1)).clamp(0.3, 6));
          },
          child: GestureDetector(
            onPanUpdate: (d) => setState(() {
              _azimuth += d.delta.dx * 0.01;
              _tilt = (_tilt - d.delta.dy * 0.01).clamp(0.15, 1.5);
            }),
            child: ClipRect(child: CustomPaint(painter: _DemPainter(_mesh, _azimuth, _tilt, _zoom, _exaggeration), size: Size.infinite)),
          ),
        ),
      ),
      Text(t('dem.hint'), style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
    ]);
  }
}

class _Mesh {
  _Mesh(this.n, this.x0, this.y0, this.dx, this.dy, this.z, this.zMin, this.zMax, this.lines);
  final int n;
  final double x0, y0, dx, dy;
  final List<double> z; // (n+1)×(n+1)
  final double zMin, zMax;

  /// Draped polylines: (points with elevation, colour, width).
  final List<(List<(double, double, double)>, Color, double)> lines;

  static _Mesh build(ProjectController c, Terrain terrain, int n) {
    var b = c.project.bounds;
    if (b.isEmpty) b = const Bounds(0, 0, 100, 100);
    b = b.inflate(math.max(b.width, b.height) * 0.05 + 1);
    final dx = b.width / n, dy = b.height / n;
    final z = List<double>.filled((n + 1) * (n + 1), 0);
    var zMin = double.infinity, zMax = -double.infinity;
    for (var j = 0; j <= n; j++) {
      for (var i = 0; i <= n; i++) {
        final v = terrain.elevationAt(Pt(b.minX + i * dx, b.minY + j * dy));
        z[j * (n + 1) + i] = v;
        zMin = math.min(zMin, v);
        zMax = math.max(zMax, v);
      }
    }
    final lines = <(List<(double, double, double)>, Color, double)>[];
    var count = 0;
    for (final e in c.project.entities) {
      if (count > 600) break;
      List<Pt>? pts;
      Color col;
      double w;
      switch (e) {
        case PipeEntity p:
          pts = p.points;
          col = Color(c.project.layerNamed(p.layer).color);
          w = p.scope == HydraulicScope.mainline ? 2.5 : 1.8;
        case SpraylineEntity s:
          pts = s.points;
          col = Color(c.project.layerNamed(s.layer).color);
          w = 1;
        case TapeEntity tp:
          pts = tp.points;
          col = Color(c.project.layerNamed(tp.layer).color);
          w = 1;
        case ContourEntity ct:
          pts = ct.points;
          col = Color(c.project.layerNamed(ct.layer).color).withValues(alpha: 0.6);
          w = 0.7;
        default:
          continue;
      }
      if (pts.length < 2) continue;
      count++;
      final total = polylineLength(pts);
      final step = math.max(total / 40, 1.0);
      final out = <(double, double, double)>[];
      for (var d = 0.0; d <= total + 1e-9; d += step) {
        final p = pointAlongPolyline(pts, math.min(d, total));
        out.add((p.x, p.y, terrain.elevationAt(p) + 0.3));
        if (d >= total) break;
      }
      final last = pts.last;
      out.add((last.x, last.y, terrain.elevationAt(last) + 0.3));
      lines.add((out, col, w));
    }
    return _Mesh(n, b.minX, b.minY, dx, dy, z, zMin, zMax, lines);
  }
}

class _DemPainter extends CustomPainter {
  _DemPainter(this.m, this.azimuth, this.tilt, this.zoom, this.exaggeration);
  final _Mesh m;
  final double azimuth, tilt, zoom, exaggeration;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14171B));
    final cx = m.x0 + m.dx * m.n / 2, cy = m.y0 + m.dy * m.n / 2;
    final span = math.max(m.dx * m.n, m.dy * m.n);
    final zMid = (m.zMin + m.zMax) / 2;
    final scale = math.min(size.width, size.height) / span * 0.8 * zoom;
    final ca = math.cos(azimuth), sa = math.sin(azimuth);
    final ct = math.cos(tilt), st = math.sin(tilt);
    // world → screen (rotate about z by azimuth, tilt about x, orthographic)
    (Offset, double) proj(double x, double y, double z) {
      final rx = (x - cx) * ca - (y - cy) * sa;
      final ry = (x - cx) * sa + (y - cy) * ca;
      final rz = (z - zMid) * exaggeration;
      final sx = rx;
      final sy = ry * ct + rz * st;
      final depth = -ry * st + rz * ct;
      return (Offset(size.width / 2 + sx * scale, size.height / 2 - sy * scale), depth);
    }

    // quads sorted back to front
    final quads = <(double, Path, Color)>[];
    final n = m.n;
    final zRange = math.max(m.zMax - m.zMin, 1e-6);
    // light direction for shading
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final x = m.x0 + i * m.dx, y = m.y0 + j * m.dy;
        final z00 = m.z[j * (n + 1) + i], z10 = m.z[j * (n + 1) + i + 1], z01 = m.z[(j + 1) * (n + 1) + i], z11 = m.z[(j + 1) * (n + 1) + i + 1];
        final (p00, d00) = proj(x, y, z00);
        final (p10, d10) = proj(x + m.dx, y, z10);
        final (p11, d11) = proj(x + m.dx, y + m.dy, z11);
        final (p01, d01) = proj(x, y + m.dy, z01);
        final depth = (d00 + d10 + d11 + d01) / 4;
        final zAvg = (z00 + z10 + z11 + z01) / 4;
        // normal from slopes
        final sx = (z10 - z00 + z11 - z01) / (2 * m.dx), sy = (z01 - z00 + z11 - z10) / (2 * m.dy);
        final nx = -sx * exaggeration, ny = -sy * exaggeration, nz = 1.0;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        final light = ((nx * -0.4 + ny * 0.3 + nz * 0.85) / nl).clamp(0.2, 1.0);
        final t = (zAvg - m.zMin) / zRange;
        final base = Color.lerp(Color.lerp(const Color(0xFF2E7D32), const Color(0xFFC0CA33), (t * 2).clamp(0, 1)), const Color(0xFF8D6E63), ((t - 0.5) * 2).clamp(0, 1))!;
        final col = Color.fromARGB(255, (base.r * 255 * light).round(), (base.g * 255 * light).round(), (base.b * 255 * light).round());
        final path = Path()
          ..moveTo(p00.dx, p00.dy)
          ..lineTo(p10.dx, p10.dy)
          ..lineTo(p11.dx, p11.dy)
          ..lineTo(p01.dx, p01.dy)
          ..close();
        quads.add((depth, path, col));
      }
    }
    quads.sort((a, b) => a.$1.compareTo(b.$1));
    final edge = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (final (_, path, col) in quads) {
      canvas.drawPath(path, Paint()..color = col);
      if (n <= 64) canvas.drawPath(path, edge);
    }
    // draped lines (drawn after the mesh; simple and readable)
    for (final (pts, col, w) in m.lines) {
      final path = Path();
      for (var k = 0; k < pts.length; k++) {
        final (o, _) = proj(pts[k].$1, pts[k].$2, pts[k].$3);
        if (k == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = w);
    }
    // north arrow
    final (o1, _) = proj(cx, cy, zMid);
    final (o2, _) = proj(cx, cy + span * 0.25, zMid);
    final arrow = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5;
    final origin = Offset(60, size.height - 40);
    final dir = (o2 - o1);
    if (dir.distance > 1e-6) {
      final u = dir / dir.distance * 28;
      canvas.drawLine(origin, origin + u, arrow);
      final tp = TextPainter(text: const TextSpan(text: 'N', style: TextStyle(color: Colors.white70, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, origin + u * 1.25 - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DemPainter old) => true;
}
