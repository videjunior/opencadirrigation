/// Triangulated irregular network (Delaunay triangulation, Bowyer–Watson)
/// with linear interpolation inside the triangles: the digital terrain model
/// (DTM) that CAD packages build from contour vertices and spot heights.
library;

import 'dart:math' as math;

import 'geometry.dart';

class TinTriangle {
  TinTriangle(this.a, this.b, this.c);

  /// Vertex indices (counter-clockwise).
  final int a, b, c;

  /// Circumcircle (filled by the triangulation).
  double cx = 0, cy = 0, r2 = 0;
}

/// Delaunay triangulation of a point set (x, y, z). Duplicate positions are
/// merged (last value wins) before triangulating.
class Tin {
  Tin._(this.xs, this.ys, this.zs, this.triangles) {
    _index();
  }

  final List<double> xs, ys, zs;
  final List<TinTriangle> triangles;

  /// Uniform grid over the triangle bounding boxes for point location.
  final Map<int, List<int>> _grid = {};
  double _cell = 1;
  double _minX = 0, _minY = 0;

  int get pointCount => xs.length;
  bool get isEmpty => triangles.isEmpty;

  Pt vertex(int i) => Pt(xs[i], ys[i]);

  /// Builds the triangulation. Returns an empty TIN for fewer than three
  /// non-collinear points.
  static Tin build(Iterable<(double, double, double)> points) {
    // merge duplicates (grid-snapped to 1 mm)
    final seen = <String, int>{};
    final xs = <double>[], ys = <double>[], zs = <double>[];
    for (final (x, y, z) in points) {
      if (!x.isFinite || !y.isFinite || !z.isFinite) continue;
      final k = '${(x * 1000).round()}|${(y * 1000).round()}';
      final i = seen[k];
      if (i != null) {
        zs[i] = z;
        continue;
      }
      seen[k] = xs.length;
      xs.add(x);
      ys.add(y);
      zs.add(z);
    }
    final n = xs.length;
    if (n < 3) return Tin._(xs, ys, zs, []);
    var minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    var minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final span = math.max(math.max(maxX - minX, maxY - minY), 1e-6);
    if (span < 1e-9) return Tin._(xs, ys, zs, []);
    // The triangulation works relative to the lower-left corner, so its
    // in-circle tests round the same wherever the drawing lies (moving or
    // georeferencing a project must not change its terrain), and four
    // co-circular points (a cell of a regular grid, spot heights at the
    // corners of a rectangle) keep the diagonal their insertion order gives.
    final mx = (maxX - minX) / 2, my = (maxY - minY) / 2;
    final px = [for (final x in xs) x - minX, mx - 20 * span, mx, mx + 20 * span];
    final py = [for (final y in ys) y - minY, my - span * 20, my + 20 * span, my - 20 * span];
    final s0 = n, s1 = n + 1, s2 = n + 2;
    final tris = <TinTriangle>[];
    void circum(TinTriangle t) {
      final ax = px[t.a], ay = py[t.a], bx = px[t.b], by = py[t.b], cx = px[t.c], cy = py[t.c];
      final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
      if (d.abs() < 1e-18) {
        t.cx = ax;
        t.cy = ay;
        t.r2 = double.infinity;
        return;
      }
      final a2 = ax * ax + ay * ay, b2 = bx * bx + by * by, c2 = cx * cx + cy * cy;
      t.cx = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d;
      t.cy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d;
      t.r2 = (ax - t.cx) * (ax - t.cx) + (ay - t.cy) * (ay - t.cy);
    }

    final root = TinTriangle(s0, s1, s2);
    circum(root);
    tris.add(root);
    // insert points in a spatially coherent order (Hilbert-ish: sort by
    // grid cell) so the "bad triangle" search stays local
    final order = List<int>.generate(n, (i) => i);
    final cells = (math.sqrt(n) / 2).ceil().clamp(1, 512);
    int cellOf(int i) {
      final gx = (px[i] / span * cells).floor().clamp(0, cells - 1);
      final gy = (py[i] / span * cells).floor().clamp(0, cells - 1);
      return gy.isEven ? gy * cells + gx : gy * cells + (cells - 1 - gx);
    }

    order.sort((a, b) => cellOf(a).compareTo(cellOf(b)));
    var alive = <TinTriangle>[];
    alive.add(root);
    for (final i in order) {
      final x = px[i], y = py[i];
      final bad = <TinTriangle>[];
      final keep = <TinTriangle>[];
      for (final t in alive) {
        final dx = x - t.cx, dy = y - t.cy;
        // strictly inside: a point on the circle (a tie, within rounding)
        // leaves the triangle alone, whichever way the rounding went
        if (dx * dx + dy * dy < t.r2 * (1 - 1e-9)) {
          bad.add(t);
        } else {
          keep.add(t);
        }
      }
      if (bad.isEmpty) {
        // numerically outside every circumcircle (should not happen inside
        // the super triangle); skip the point
        continue;
      }
      // boundary of the cavity: edges that belong to exactly one bad triangle
      final edgeCount = <int, int>{};
      final edgeList = <(int, int)>[];
      void edge(int u, int v) {
        final key = u < v ? u * 4194304 + v : v * 4194304 + u;
        final c = edgeCount[key];
        if (c == null) {
          edgeCount[key] = 1;
          edgeList.add((u, v));
        } else {
          edgeCount[key] = c + 1;
        }
      }

      for (final t in bad) {
        edge(t.a, t.b);
        edge(t.b, t.c);
        edge(t.c, t.a);
      }
      for (final (u, v) in edgeList) {
        final key = u < v ? u * 4194304 + v : v * 4194304 + u;
        if (edgeCount[key] != 1) continue;
        final t = TinTriangle(u, v, i);
        circum(t);
        keep.add(t);
      }
      alive = keep;
    }
    // drop triangles touching the super triangle; orient counter-clockwise
    final out = <TinTriangle>[];
    for (final t in alive) {
      if (t.a >= n || t.b >= n || t.c >= n) continue;
      final area = (px[t.b] - px[t.a]) * (py[t.c] - py[t.a]) - (py[t.b] - py[t.a]) * (px[t.c] - px[t.a]);
      if (area.abs() < 1e-12) continue;
      out.add(area > 0 ? t : TinTriangle(t.a, t.c, t.b));
    }
    return Tin._(xs, ys, zs, out);
  }

  void _index() {
    _grid.clear();
    if (triangles.isEmpty) return;
    _minX = xs.reduce(math.min);
    _minY = ys.reduce(math.min);
    final w = xs.reduce(math.max) - _minX, h = ys.reduce(math.max) - _minY;
    _cell = math.max(1e-6, math.max(w, h) / math.max(4, math.sqrt(triangles.length)));
    for (var i = 0; i < triangles.length; i++) {
      final t = triangles[i];
      final x0 = math.min(xs[t.a], math.min(xs[t.b], xs[t.c])), x1 = math.max(xs[t.a], math.max(xs[t.b], xs[t.c]));
      final y0 = math.min(ys[t.a], math.min(ys[t.b], ys[t.c])), y1 = math.max(ys[t.a], math.max(ys[t.b], ys[t.c]));
      for (var gx = ((x0 - _minX) / _cell).floor(); gx <= ((x1 - _minX) / _cell).floor(); gx++) {
        for (var gy = ((y0 - _minY) / _cell).floor(); gy <= ((y1 - _minY) / _cell).floor(); gy++) {
          _grid.putIfAbsent(gx * 73856093 ^ gy * 19349663, () => []).add(i);
        }
      }
    }
  }

  /// Index of the triangle containing [p], or -1 outside the hull.
  int locate(Pt p) {
    if (triangles.isEmpty) return -1;
    final gx = ((p.x - _minX) / _cell).floor(), gy = ((p.y - _minY) / _cell).floor();
    final list = _grid[gx * 73856093 ^ gy * 19349663];
    if (list == null) return -1;
    for (final i in list) {
      if (_bary(triangles[i], p) != null) return i;
    }
    return -1;
  }

  /// Barycentric coordinates of [p] in [t] (null when outside).
  (double, double, double)? _bary(TinTriangle t, Pt p) {
    final ax = xs[t.a], ay = ys[t.a], bx = xs[t.b], by = ys[t.b], cx = xs[t.c], cy = ys[t.c];
    final d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
    if (d.abs() < 1e-18) return null;
    final l1 = ((by - cy) * (p.x - cx) + (cx - bx) * (p.y - cy)) / d;
    final l2 = ((cy - ay) * (p.x - cx) + (ax - cx) * (p.y - cy)) / d;
    final l3 = 1 - l1 - l2;
    const eps = -1e-9;
    if (l1 < eps || l2 < eps || l3 < eps) return null;
    return (l1, l2, l3);
  }

  /// Linear interpolation inside the hull; null outside.
  double? elevationAt(Pt p) {
    final i = locate(p);
    if (i < 0) return null;
    final t = triangles[i];
    final (l1, l2, l3) = _bary(t, p)!;
    return l1 * zs[t.a] + l2 * zs[t.b] + l3 * zs[t.c];
  }

  /// Slope (m/m) and aspect (radians, direction of descent) of the triangle
  /// under [p]; null outside the hull.
  (double, double)? slopeAt(Pt p) {
    final i = locate(p);
    if (i < 0) return null;
    final t = triangles[i];
    final ax = xs[t.a], ay = ys[t.a], az = zs[t.a];
    final bx = xs[t.b] - ax, by = ys[t.b] - ay, bz = zs[t.b] - az;
    final cx = xs[t.c] - ax, cy = ys[t.c] - ay, cz = zs[t.c] - az;
    // normal = (b × c)
    final nx = by * cz - bz * cy, ny = bz * cx - bx * cz, nz = bx * cy - by * cx;
    if (nz.abs() < 1e-18) return (double.infinity, 0);
    final gx = -nx / nz, gy = -ny / nz; // dz/dx, dz/dy
    return (math.sqrt(gx * gx + gy * gy), math.atan2(-gy, -gx));
  }

  (double, double) get elevationRange {
    if (zs.isEmpty) return (0, 0);
    return (zs.reduce(math.min), zs.reduce(math.max));
  }

  /// Contour polylines at [level] (marching over the triangles, segments
  /// chained into polylines).
  List<List<Pt>> contour(double level) {
    final segs = <(Pt, Pt)>[];
    for (final t in triangles) {
      final ids = [t.a, t.b, t.c];
      final pts = <Pt>[];
      for (var k = 0; k < 3; k++) {
        final i = ids[k], j = ids[(k + 1) % 3];
        final zi = zs[i], zj = zs[j];
        if ((zi < level) == (zj < level)) continue;
        if (zi == zj) continue;
        final f = (level - zi) / (zj - zi);
        pts.add(Pt(xs[i] + (xs[j] - xs[i]) * f, ys[i] + (ys[j] - ys[i]) * f));
      }
      if (pts.length == 2 && pts[0].distanceTo(pts[1]) > 1e-9) segs.add((pts[0], pts[1]));
    }
    return chainSegments(segs);
  }

  /// Contours every [interval] between the model's min and max elevation.
  List<(double, List<Pt>)> contours(double interval, {double? from, double? to}) {
    if (triangles.isEmpty || interval <= 0) return const [];
    final (lo, hi) = elevationRange;
    final start = (from ?? lo / interval).let((v) => from == null ? (lo / interval).ceil() * interval : v);
    final end = to ?? hi;
    final out = <(double, List<Pt>)>[];
    var guard = 0;
    for (var z = start; z <= end + 1e-9 && guard < 5000; z += interval, guard++) {
      final level = (z / interval).round() * interval;
      for (final line in contour(level)) {
        if (line.length >= 2) out.add((level, line));
      }
    }
    return out;
  }
}

/// Chains unordered segments into polylines (endpoints matched within a
/// small tolerance). Closed rings get their first point repeated at the end.
List<List<Pt>> chainSegments(List<(Pt, Pt)> segs, {double tol = 1e-6}) {
  if (segs.isEmpty) return const [];
  String key(Pt p) => '${(p.x / tol).round()}|${(p.y / tol).round()}';
  final byEnd = <String, List<int>>{};
  for (var i = 0; i < segs.length; i++) {
    byEnd.putIfAbsent(key(segs[i].$1), () => []).add(i);
    byEnd.putIfAbsent(key(segs[i].$2), () => []).add(i);
  }
  final used = List<bool>.filled(segs.length, false);
  final out = <List<Pt>>[];
  int? next(Pt p, int exclude) {
    final list = byEnd[key(p)];
    if (list == null) return null;
    for (final i in list) {
      if (!used[i] && i != exclude) return i;
    }
    return null;
  }

  for (var s = 0; s < segs.length; s++) {
    if (used[s]) continue;
    used[s] = true;
    final line = <Pt>[segs[s].$1, segs[s].$2];
    // extend forward
    var cur = s;
    while (true) {
      final n = next(line.last, cur);
      if (n == null) break;
      used[n] = true;
      final (a, b) = segs[n];
      line.add(a.distanceTo(line.last) <= tol ? b : a);
      cur = n;
      if (line.first.distanceTo(line.last) <= tol) break;
    }
    // extend backward
    cur = s;
    while (line.first.distanceTo(line.last) > tol) {
      final n = next(line.first, cur);
      if (n == null) break;
      used[n] = true;
      final (a, b) = segs[n];
      line.insert(0, a.distanceTo(line.first) <= tol ? b : a);
      cur = n;
    }
    out.add(line);
  }
  return out;
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
