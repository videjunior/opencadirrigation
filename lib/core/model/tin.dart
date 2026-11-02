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

  /// Last point whose cavity took this triangle (during the triangulation).
  int _mark = -1;
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
  /// non-collinear points. [breaklines] are polylines of (x, y, z) whose
  /// segments become edges of the triangulation (a constrained Delaunay
  /// triangulation): the surface folds along a ridge, a channel or the edge
  /// of a terrace instead of being interpolated across it.
  static Tin build(Iterable<(double, double, double)> points, {List<List<(double, double, double)>> breaklines = const []}) {
    // merge duplicates (grid-snapped to 1 mm)
    final seen = <String, int>{};
    final xs = <double>[], ys = <double>[], zs = <double>[];
    int add(double x, double y, double z) {
      final k = '${(x * 1000).round()}|${(y * 1000).round()}';
      final i = seen[k];
      if (i != null) {
        zs[i] = z;
        return i;
      }
      seen[k] = xs.length;
      xs.add(x);
      ys.add(y);
      zs.add(z);
      return xs.length - 1;
    }

    for (final (x, y, z) in points) {
      if (!x.isFinite || !y.isFinite || !z.isFinite) continue;
      add(x, y, z);
    }
    // breakline vertices are points too; their segments are constraints
    final constraints = <(int, int)>[];
    for (final line in breaklines) {
      int? prev;
      for (final (x, y, z) in line) {
        if (!x.isFinite || !y.isFinite || !z.isFinite) {
          prev = null;
          continue;
        }
        final i = add(x, y, z);
        if (prev != null && prev != i) constraints.add((prev, i));
        prev = i;
      }
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
    // Every triangle in the order it was made (null once destroyed: the
    // order the triangulation keeps) and the directed edges of the live
    // ones (u → v of triangle k, key u·m + v): the neighbour across an edge
    // holds the reverse edge. All triangles turn the same way (the super
    // triangle is clockwise and each new one inherits its edge's sense).
    final all = <TinTriangle?>[root];
    final m = n + 3;
    final edgeOf = <int, int>{s0 * m + s1: 0, s1 * m + s2: 0, s2 * m + s0: 0};
    double side(int a, int b, double x, double y) => (px[b] - px[a]) * (y - py[a]) - (py[b] - py[a]) * (x - px[a]);
    // strictly inside: a point on the circle (a tie, within rounding) leaves
    // the triangle alone, whichever way the rounding went
    bool inCircle(TinTriangle t, double x, double y) {
      final dx = x - t.cx, dy = y - t.cy;
      return dx * dx + dy * dy < t.r2 * (1 - 1e-9);
    }

    // walk from triangle k towards (x, y), crossing an edge with the point on
    // its far side (the first edge tried turns with the step, so the walk
    // cannot circle); -1 when it gets lost
    int walk(int k, double x, double y) {
      final limit = 64 + 8 * all.length;
      for (var step = 0; step < limit; step++) {
        final t = all[k]!;
        var next = -1;
        for (var j = 0; j < 3 && next < 0; j++) {
          final e = (step + j) % 3;
          final u = e == 0 ? t.a : (e == 1 ? t.b : t.c), v = e == 0 ? t.b : (e == 1 ? t.c : t.a);
          if (side(u, v, x, y) > 0) next = edgeOf[v * m + u] ?? -2;
        }
        if (next == -1) return k;
        if (next == -2) return -1;
        k = next;
      }
      return -1;
    }

    var last = 0;
    for (final i in order) {
      final x = px[i], y = py[i];
      var start = walk(last, x, y);
      if (start < 0) {
        // lost on a degenerate triangulation: any triangle whose circle holds it
        for (var k = 0; k < all.length && start < 0; k++) {
          if (all[k] != null && inCircle(all[k]!, x, y)) start = k;
        }
        if (start < 0) continue;
      }
      // the cavity: the triangles whose circumcircle holds the point, grown
      // from the one containing it across shared edges
      final bad = <int>[start];
      all[start]!._mark = i;
      for (var q = 0; q < bad.length; q++) {
        final t = all[bad[q]]!;
        for (var e = 0; e < 3; e++) {
          final u = e == 0 ? t.a : (e == 1 ? t.b : t.c), v = e == 0 ? t.b : (e == 1 ? t.c : t.a);
          final nb = edgeOf[v * m + u];
          if (nb == null) continue;
          final o = all[nb]!;
          if (o._mark == i || !inCircle(o, x, y)) continue;
          o._mark = i;
          bad.add(nb);
        }
      }
      // boundary of the cavity, in the order its triangles were made and
      // a→b, b→c, c→a in each: the new triangles keep the order the
      // triangulation always had
      bad.sort();
      final boundary = <int>[];
      for (final k in bad) {
        final t = all[k]!;
        for (var e = 0; e < 3; e++) {
          final u = e == 0 ? t.a : (e == 1 ? t.b : t.c), v = e == 0 ? t.b : (e == 1 ? t.c : t.a);
          final nb = edgeOf[v * m + u];
          if (nb != null && all[nb]!._mark == i) continue;
          boundary
            ..add(u)
            ..add(v);
        }
      }
      for (final k in bad) {
        final t = all[k]!;
        edgeOf
          ..remove(t.a * m + t.b)
          ..remove(t.b * m + t.c)
          ..remove(t.c * m + t.a);
        all[k] = null;
      }
      for (var j = 0; j < boundary.length; j += 2) {
        final u = boundary[j], v = boundary[j + 1];
        final t = TinTriangle(u, v, i);
        circum(t);
        final k = all.length;
        all.add(t);
        edgeOf[u * m + v] = k;
        edgeOf[v * m + i] = k;
        edgeOf[i * m + u] = k;
        last = k;
      }
    }
    var alive = [for (final t in all) ?t];
    if (constraints.isNotEmpty) alive = _constrain(alive, px, py, constraints);
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

  /// Makes every constraint segment an edge of the triangulation [tris] by
  /// flipping the diagonals it crosses (Sloan 1993, *Computers & Structures*
  /// 47(3): 441–450): an edge crossing the segment is flipped when its
  /// two triangles form a convex quadrilateral, else it waits for its
  /// neighbours to be flipped first. A segment passing through another vertex
  /// is split there.
  static List<TinTriangle> _constrain(List<TinTriangle> input, List<double> px, List<double> py, List<(int, int)> constraints) {
    double orient(int a, int b, int c) => (px[b] - px[a]) * (py[c] - py[a]) - (py[b] - py[a]) * (px[c] - px[a]);
    TinTriangle ccw(int a, int b, int c) => orient(a, b, c) >= 0 ? TinTriangle(a, b, c) : TinTriangle(a, c, b);
    final tris = [for (final t in input) ccw(t.a, t.b, t.c)];
    int key(int u, int v) => u < v ? u * 4194304 + v : v * 4194304 + u;
    final edges = <int, List<int>>{};
    void link(int k) {
      final t = tris[k];
      for (final (u, v) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)]) {
        (edges[key(u, v)] ??= <int>[]).add(k);
      }
    }

    void unlink(int k) {
      final t = tris[k];
      for (final (u, v) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)]) {
        final l = edges[key(u, v)];
        l?.remove(k);
        if (l != null && l.isEmpty) edges.remove(key(u, v));
      }
    }

    for (var k = 0; k < tris.length; k++) {
      link(k);
    }
    final scale = [for (var i = 0; i < px.length; i++) math.max(px[i].abs(), py[i].abs())].fold(1.0, math.max);
    final eps = scale * scale * 1e-12;
    // segments that properly cross (no shared end, not touching)
    bool crosses(int a, int b, int c, int d) {
      if (a == c || a == d || b == c || b == d) return false;
      final o1 = orient(a, b, c), o2 = orient(a, b, d), o3 = orient(c, d, a), o4 = orient(c, d, b);
      return ((o1 > eps && o2 < -eps) || (o1 < -eps && o2 > eps)) && ((o3 > eps && o4 < -eps) || (o3 < -eps && o4 > eps));
    }

    int third(TinTriangle t, int u, int v) => t.a != u && t.a != v ? t.a : (t.b != u && t.b != v ? t.b : t.c);
    // split the constraints at the vertices lying on them
    final pending = <(int, int)>[];
    for (final (a, b) in constraints) {
      final dx = px[b] - px[a], dy = py[b] - py[a];
      final len2 = dx * dx + dy * dy;
      if (len2 <= 0) continue;
      final on = <(double, int)>[];
      for (var i = 0; i < px.length - 3; i++) {
        if (i == a || i == b) continue;
        final t = ((px[i] - px[a]) * dx + (py[i] - py[a]) * dy) / len2;
        if (t <= 1e-9 || t >= 1 - 1e-9) continue;
        if (orient(a, b, i).abs() <= 1e-9 * len2) on.add((t, i));
      }
      on.sort((x, y) => x.$1.compareTo(y.$1));
      var prev = a;
      for (final (_, i) in on) {
        pending.add((prev, i));
        prev = i;
      }
      pending.add((prev, b));
    }
    for (final (a, b) in pending) {
      if (edges.containsKey(key(a, b))) continue;
      final queue = <(int, int)>[
        for (final k in edges.keys)
          if ((k ~/ 4194304, k % 4194304) case (final u, final v) when crosses(a, b, u, v)) (u, v),
      ];
      var guard = 0;
      while (queue.isNotEmpty && guard++ < 200000) {
        final (u, v) = queue.removeAt(0);
        final ts = edges[key(u, v)];
        if (ts == null || ts.length != 2) continue;
        final k1 = ts[0], k2 = ts[1];
        final p = third(tris[k1], u, v), q = third(tris[k2], u, v);
        // flippable when the quadrilateral u-q-v-p is convex
        if (!crosses(u, v, p, q)) {
          queue.add((u, v));
          continue;
        }
        unlink(k1);
        unlink(k2);
        tris[k1] = ccw(p, u, q);
        tris[k2] = ccw(p, q, v);
        link(k1);
        link(k2);
        if (crosses(a, b, p, q)) queue.add((p, q));
      }
    }
    return tris;
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
