/// Outline by a click inside (1.6.0 CAD): the smallest region around a
/// point that the drawn lines close, as the BOUNDARY command of CAD
/// programs. The lines are split where they cross or touch, the loose ends
/// are pruned, and the faces of the planar graph left are traced; the face
/// with the least area that holds the point is the outline.
library;

import 'dart:math' as math;

import 'geometry.dart';
import 'split.dart';

/// The straight segments of [edge]: a path with its closing side, a circle
/// or an arc sampled every 5°.
List<(Pt, Pt)> boundarySegments(CutEdge edge) {
  final out = <(Pt, Pt)>[];
  void path(List<Pt> pts, bool closed) {
    for (var i = 1; i < pts.length; i++) {
      out.add((pts[i - 1], pts[i]));
    }
    if (closed && pts.length > 2) out.add((pts.last, pts.first));
  }

  final c = edge.center;
  if (c != null) {
    final n = math.max(2, (edge.sweepRad.abs() / (math.pi / 36)).ceil());
    path([for (var i = 0; i <= n; i++) c + Pt.polar(edge.radius, edge.startRad + edge.sweepRad * i / n)], false);
  } else {
    path(edge.points, edge.closed);
  }
  return out;
}

/// The outline (counter-clockwise, no repeated last point) of the smallest
/// region around [p] closed by [segments], or null when none holds it (the
/// lines leave a gap, or [p] lies on a line). Ends closer than [tol] meet.
List<Pt>? boundaryAround(Pt p, List<(Pt, Pt)> segments, {double tol = 1e-6}) {
  final segs = [
    for (final s in segments)
      if (s.$1.distanceTo(s.$2) > tol && s.$1.x.isFinite && s.$1.y.isFinite && s.$2.x.isFinite && s.$2.y.isFinite) s,
  ];
  if (segs.length < 3) return null;
  final nodes = _Nodes(tol);
  // ---- the stations where each segment meets another (its ends included)
  final cuts = List.generate(segs.length, (_) => <double>[0, 1]);
  var box = Bounds.empty;
  for (final s in segs) {
    box = box.include(s.$1).include(s.$2);
  }
  final grid = _Grid(box, segs.length);
  for (var i = 0; i < segs.length; i++) {
    grid.add(i, segs[i]);
  }
  final seen = List<int>.filled(segs.length, -1);
  for (var i = 0; i < segs.length; i++) {
    final (a, b) = segs[i];
    for (final j in grid.near(segs[i])) {
      if (j <= i || seen[j] == i) continue;
      seen[j] = i;
      final (c, d) = segs[j];
      _meet(a, b, c, d, tol, (ti, tj) {
        cuts[i].add(ti);
        cuts[j].add(tj);
      });
    }
  }
  // ---- the edges between the nodes (each once)
  final edges = <(int, int)>{};
  for (var i = 0; i < segs.length; i++) {
    final (a, b) = segs[i];
    final ts = cuts[i]..sort();
    int? prev;
    for (final t in ts) {
      final n = nodes.of(Pt.lerp(a, b, t.clamp(0.0, 1.0)));
      if (prev != null && prev != n) edges.add(prev < n ? (prev, n) : (n, prev));
      prev = n;
    }
  }
  // ---- loose ends take no part in a region: prune them
  final adj = <int, Set<int>>{};
  for (final (u, v) in edges) {
    (adj[u] ??= {}).add(v);
    (adj[v] ??= {}).add(u);
  }
  final loose = [
    for (final e in adj.entries)
      if (e.value.length < 2) e.key,
  ];
  while (loose.isNotEmpty) {
    final n = loose.removeLast();
    final others = adj.remove(n);
    for (final m in others ?? const <int>{}) {
      final s = adj[m];
      if (s == null) continue;
      s.remove(n);
      if (s.length < 2) loose.add(m);
    }
  }
  if (adj.isEmpty) return null;
  // ---- the outgoing half-edges of each node, counter-clockwise
  final pos = nodes.points;
  final around = <int, List<int>>{};
  for (final e in adj.entries) {
    final o = pos[e.key];
    around[e.key] = e.value.toList()..sort((x, y) => (pos[x] - o).angle.compareTo((pos[y] - o).angle));
  }
  // ---- the faces: every half-edge u→v once, the face on its left
  final used = <int>{};
  int key(int u, int v) => u * (pos.length + 1) + v;
  List<Pt>? best;
  var bestArea = double.infinity;
  for (final u in around.keys) {
    for (final v in around[u]!) {
      if (used.contains(key(u, v))) continue;
      final ring = <int>[];
      var a = u, b = v;
      var guard = 0;
      while (used.add(key(a, b)) && guard++ < 1000000) {
        ring.add(a);
        // at b, the edge just before b→a counter-clockwise (the sharpest left turn)
        final out = around[b]!;
        final k = out.indexOf(a);
        final next = out[(k - 1 + out.length) % out.length];
        a = b;
        b = next;
      }
      if (ring.length < 3) continue;
      final poly = [for (final n in ring) pos[n]];
      final area = polygonArea(poly);
      // the outer side of a group of lines winds clockwise: no region
      if (area <= tol * tol || area >= bestArea) continue;
      if (!pointInPolygon(p, poly) || pointOnPolygonBoundary(p, poly, tol: tol)) continue;
      best = poly;
      bestArea = area;
    }
  }
  return best == null ? null : _simplify(best, tol);
}

/// Calls [hit] with the stations along ab and cd where they meet: a
/// crossing, an end on the other segment, or the ends of a collinear
/// overlap.
void _meet(Pt a, Pt b, Pt c, Pt d, double tol, void Function(double ti, double tj) hit) {
  final r = b - a, s = d - c;
  final lr = r.length, ls = s.length;
  final denom = r.cross(s);
  if (denom.abs() > 1e-12 * lr * ls) {
    final qp = c - a;
    final t = qp.cross(s) / denom, u = qp.cross(r) / denom;
    final et = tol / lr, eu = tol / ls;
    if (t >= -et && t <= 1 + et && u >= -eu && u <= 1 + eu) hit(t.clamp(0.0, 1.0), u.clamp(0.0, 1.0));
    return;
  }
  // parallel: only a collinear overlap meets, at the ends of each on the other
  if (distanceToSegment(c, a, b) > tol && distanceToSegment(d, a, b) > tol && distanceToSegment(a, c, d) > tol && distanceToSegment(b, c, d) > tol) return;
  double along(Pt q, Pt o, Pt dir, double len) => (q - o).dot(dir) / (len * len);
  for (final q in [c, d]) {
    if (distanceToSegment(q, a, b) <= tol) hit(along(q, a, r, lr).clamp(0.0, 1.0), q == c ? 0 : 1);
  }
  for (final q in [a, b]) {
    if (distanceToSegment(q, c, d) <= tol) hit(q == a ? 0 : 1, along(q, c, s, ls).clamp(0.0, 1.0));
  }
}

/// [ring] without the vertices that lie on the line of their neighbours.
List<Pt> _simplify(List<Pt> ring, double tol) {
  final out = List.of(ring);
  var changed = true;
  while (changed && out.length > 3) {
    changed = false;
    for (var i = 0; i < out.length && out.length > 3; i++) {
      final prev = out[(i - 1 + out.length) % out.length], next = out[(i + 1) % out.length];
      if (distanceToSegment(out[i], prev, next) <= tol) {
        out.removeAt(i);
        changed = true;
        i--;
      }
    }
  }
  return out;
}

/// The nodes of the graph: points closer than the tolerance are one.
class _Nodes {
  _Nodes(this.tol) : cell = math.max(tol, 1e-12) * 2;
  final double tol, cell;
  final points = <Pt>[];
  final _cells = <(int, int), List<int>>{};

  int of(Pt p) {
    final cx = (p.x / cell).floor(), cy = (p.y / cell).floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final i in _cells[(cx + dx, cy + dy)] ?? const <int>[]) {
          if (points[i].distanceTo(p) <= tol) return i;
        }
      }
    }
    points.add(p);
    (_cells[(cx, cy)] ??= []).add(points.length - 1);
    return points.length - 1;
  }
}

/// A uniform grid over the segments, for the pairs that may meet.
class _Grid {
  _Grid(this.box, int n) {
    final w = math.max(box.width, 1e-9), h = math.max(box.height, 1e-9);
    // about two segments a cell
    final cells = math.max(1, math.sqrt(n / 2).ceil());
    size = math.max(w, h) / cells;
  }
  final Bounds box;
  late final double size;
  final _cells = <(int, int), List<int>>{};

  /// The cells the box of [s] covers, [pad] cells more on each side.
  Iterable<(int, int)> _covered((Pt, Pt) s, int pad) sync* {
    final x0 = ((math.min(s.$1.x, s.$2.x) - box.minX) / size).floor(), x1 = ((math.max(s.$1.x, s.$2.x) - box.minX) / size).floor();
    final y0 = ((math.min(s.$1.y, s.$2.y) - box.minY) / size).floor(), y1 = ((math.max(s.$1.y, s.$2.y) - box.minY) / size).floor();
    for (var x = x0 - pad; x <= x1 + pad; x++) {
      for (var y = y0 - pad; y <= y1 + pad; y++) {
        yield (x, y);
      }
    }
  }

  void add(int i, (Pt, Pt) s) {
    for (final k in _covered(s, 0)) {
      (_cells[k] ??= []).add(i);
    }
  }

  /// The segments in the cells around [s] (a touch on a cell's side included).
  Iterable<int> near((Pt, Pt) s) sync* {
    for (final k in _covered(s, 1)) {
      yield* _cells[k] ?? const <int>[];
    }
  }
}
