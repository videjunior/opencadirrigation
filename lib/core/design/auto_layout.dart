/// Automatic layout of landscape sprinklers: corner, edge and interior heads
/// for a lawn or a bed (convex or concave, with buildings and beds left
/// out), every arc opening into the area, matched-precipitation nozzles and
/// the uniformity of the result (Christiansen CU, low-quarter DU and the
/// scheduling coefficient of the densogram model).
///
/// The rules are those of landscape and sprinkler design practice
/// (Irrigation Association, *Landscape Irrigation Best Management
/// Practices*, 2014; Keller & Bliesner, *Sprinkle and Trickle Irrigation*,
/// 1990, chap. 5 and 6; USDA NRCS, *National Engineering Handbook* part 623,
/// chap. 11): heads go in the corners first, then along every edge at no
/// more than the spacing, then on a grid inside, kept away from the edges;
/// with head-to-head spacing (spacing = wetted radius, or a percentage of
/// the wetted diameter) every head throws to its neighbours; a part circle
/// gets the nozzle whose flow is proportional to its arc, so that every head
/// applies the same depth (matched precipitation: q = q_full·arc/360).
///
/// Conventions (those of [OutletEntity], the painter and the densogram): the
/// wetted sector of a head sweeps counter-clockwise from `orientationDeg`
/// over `arcDeg` degrees, world angles measured from the x axis.
///
/// Also the shared plumbing of the automatic design tools
/// (`zoning.dart`, `routing.dart`, `templates.dart`, `pivot_fit.dart`): the
/// irrigated region (outline minus exclusions), a point hash grid and the
/// largest inscribed circle.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'block_generator.dart' show GridPattern;
import 'densogram.dart';

// ---------------------------------------------------------------- small helpers

/// Angle (degrees, in [0, 360)) of [a] reduced to one turn.
double normalizeDeg(double a) {
  if (!a.isFinite) return 0;
  var v = a % 360;
  if (v < 0) v += 360;
  return v >= 360 ? 0 : v;
}

/// Counter-clockwise angle (degrees, in (0, 360]) that turns the direction
/// [from] onto the direction [to].
double ccwAngleDeg(Pt from, Pt to) {
  var a = radToDeg(math.atan2(from.cross(to), from.dot(to)));
  if (a <= 1e-9) a += 360;
  return a;
}

/// [poly] without repeated or non-finite vertices nor a closing vertex equal
/// to the first one, turned counter-clockwise (or clockwise when [ccw] is
/// false).
List<Pt> normalizePolygon(List<Pt> poly, {bool ccw = true}) {
  final out = <Pt>[];
  for (final p in poly) {
    if (!p.x.isFinite || !p.y.isFinite) continue;
    if (out.isNotEmpty && out.last.distanceTo(p) < 1e-9) continue;
    out.add(p);
  }
  while (out.length > 1 && out.first.distanceTo(out.last) < 1e-9) {
    out.removeLast();
  }
  if (out.length < 3) return out;
  final a = polygonArea(out);
  return (a < 0) == ccw ? out.reversed.toList() : out;
}

/// Crossings of the closed polygon [poly] with itself: where two edges that
/// do not follow each other cross or touch, and the vertices it passes
/// twice (an outline drawn by hand with a grip dragged across another
/// side, or read from a file, may do both). Empty for a simple polygon.
/// The edges are bucketed on a grid, so long outlines are cheap.
List<Pt> polygonSelfCrossings(List<Pt> poly) {
  final p = <Pt>[];
  for (final q in poly) {
    if (!q.x.isFinite || !q.y.isFinite) continue;
    if (p.isNotEmpty && p.last.distanceTo(q) < 1e-9) continue;
    p.add(q);
  }
  while (p.length > 1 && p.first.distanceTo(p.last) < 1e-9) {
    p.removeLast();
  }
  final n = p.length;
  if (n < 4) return const [];
  final b = Bounds.ofPoints(p);
  final scale = math.max(b.width, b.height);
  final eps = math.max(1e-9, scale * 1e-9);
  final cell = math.max(polylineLength([...p, p.first]) / n, scale / 1024) + 1e-12;
  final buckets = <int, List<int>>{};
  int key(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);
  Iterable<int> keys(Pt a, Pt c) sync* {
    final x0 = ((math.min(a.x, c.x) - b.minX) / cell).floor(), x1 = ((math.max(a.x, c.x) - b.minX) / cell).floor();
    final y0 = ((math.min(a.y, c.y) - b.minY) / cell).floor(), y1 = ((math.max(a.y, c.y) - b.minY) / cell).floor();
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        yield key(ix, iy);
      }
    }
  }

  for (var i = 0; i < n; i++) {
    for (final k in keys(p[i], p[(i + 1) % n])) {
      (buckets[k] ??= []).add(i);
    }
  }
  final out = <Pt>[];
  for (var i = 0; i < n; i++) {
    final a = p[i], c = p[(i + 1) % n];
    final seen = <int>{};
    for (final k in keys(a, c)) {
      for (final j in buckets[k] ?? const <int>[]) {
        if (j <= i || !seen.add(j)) continue;
        // neighbouring edges share a vertex: that is no crossing
        if (j == i + 1 || (i == 0 && j == n - 1)) continue;
        final x = segmentIntersection(a, c, p[j], p[(j + 1) % n], eps: 1e-12);
        if (x != null) {
          out.add(x);
        } else if (distanceToSegment(p[j], a, c) <= eps || distanceToSegment(a, p[j], p[(j + 1) % n]) <= eps) {
          // collinear overlap or a vertex resting on another edge
          out.add(distanceToSegment(p[j], a, c) <= eps ? p[j] : a);
        }
      }
    }
  }
  return out;
}

/// The simple loops a self-crossing outline [poly] encloses: walking it,
/// each time it comes back to a crossing (or to a vertex it passed) the
/// loop since then is cut off. Every part is counter-clockwise; a simple
/// polygon comes back as itself (normalised). A bow tie gives its two
/// triangles, a figure of eight its two rings.
List<List<Pt>> simplePolygonParts(List<Pt> poly) {
  final base = normalizePolygon(poly);
  if (base.length < 3) return const [];
  if (polygonSelfCrossings(base).isEmpty) return [base];
  final p = <Pt>[];
  for (final q in poly) {
    if (!q.x.isFinite || !q.y.isFinite) continue;
    if (p.isNotEmpty && p.last.distanceTo(q) < 1e-9) continue;
    p.add(q);
  }
  while (p.length > 1 && p.first.distanceTo(p.last) < 1e-9) {
    p.removeLast();
  }
  final n = p.length;
  final b = Bounds.ofPoints(p);
  final eps = math.max(1e-9, math.max(b.width, b.height) * 1e-9);
  // every edge with the points where other edges cross it, in order
  final cuts = [for (var i = 0; i < n; i++) <(double, Pt)>[]];
  for (var i = 0; i < n; i++) {
    final a = p[i], c = p[(i + 1) % n];
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue;
      final d0 = p[j], d1 = p[(j + 1) % n];
      final x = segmentIntersection(a, c, d0, d1, eps: 1e-12);
      if (x == null) continue;
      final r = c - a, s = d1 - d0;
      final ti = r.length > 0 ? (x - a).dot(r) / r.dot(r) : 0.0, tj = s.length > 0 ? (x - d0).dot(s) / s.dot(s) : 0.0;
      if (ti > 1e-9 && ti < 1 - 1e-9) cuts[i].add((ti, x));
      if (tj > 1e-9 && tj < 1 - 1e-9) cuts[j].add((tj, x));
    }
  }
  final seq = <Pt>[
    for (var i = 0; i < n; i++) ...[p[i], ...(cuts[i]..sort((x, y) => x.$1.compareTo(y.$1))).map((c) => c.$2)],
  ];
  // the walk: a point met again closes the loop since it was first met
  final parts = <List<Pt>>[];
  final stack = <Pt>[];
  int? onStack(Pt q) {
    for (var k = stack.length - 1; k >= 0; k--) {
      if (stack[k].distanceTo(q) <= eps * 10) return k;
    }
    return null;
  }

  for (final q in [...seq, seq.first]) {
    final k = onStack(q);
    if (k != null) {
      final loop = stack.sublist(k);
      stack.removeRange(k + 1, stack.length);
      if (loop.length >= 3) parts.add(loop);
      continue;
    }
    stack.add(q);
  }
  if (stack.length >= 3) parts.add(List.of(stack));
  return [
    for (final part in parts)
      if (normalizePolygon(part) case final q when q.length >= 3 && polygonArea(q).abs() > eps) q,
  ];
}

/// Direction of the longest edge of the closed polygon [poly] (the x axis
/// for a degenerate one): rows of heads, laterals and strips usually run
/// along the longest straight side of an area.
Pt longestEdgeDirection(List<Pt> poly) {
  var best = -1.0;
  var dir = const Pt(1, 0);
  for (var i = 0; i < poly.length; i++) {
    final d = poly[(i + 1) % poly.length] - poly[i];
    if (d.length > best + 1e-9) {
      best = d.length;
      dir = d;
    }
  }
  return best > 0 ? dir.normalized : const Pt(1, 0);
}

/// Cell size for a [PointGrid] of [count] points spread over [b]: about one
/// point a cell, also when the points lie on a line (no area).
double pointGridCell(Bounds b, int count, {double minimum = 1e-3}) {
  if (b.isEmpty || count <= 0) return math.max(minimum, 1);
  final n = math.max(1, count);
  return math.max(minimum, math.max(math.sqrt(b.width * b.height / n), math.max(b.width, b.height) / n));
}

/// Uniform hash grid of points for nearest-neighbour and range queries,
/// with positions taken relative to [origin] in cells of [cell] metres.
/// Ties are broken by the lower index, so every query is deterministic.
class PointGrid {
  PointGrid(double cell, {this.origin = Pt.zero}) : cell = cell > 0 && cell.isFinite ? cell : 1;

  final double cell;
  final Pt origin;

  /// The points, by index (removed ones stay, flagged in [isRemoved]).
  final List<Pt> points = [];
  final List<bool> _removed = [];
  final Map<int, List<int>> _cells = {};
  int _minX = 0, _maxX = -1, _minY = 0, _maxY = -1;

  int _ix(double x) => ((x - origin.x) / cell).floor();
  int _iy(double y) => ((y - origin.y) / cell).floor();
  static int _key(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);

  int get length => points.length;
  bool isRemoved(int i) => _removed[i];

  /// Adds [p] and returns its index.
  int add(Pt p) {
    final i = points.length;
    points.add(p);
    _removed.add(false);
    _insert(i, p);
    return i;
  }

  void _insert(int i, Pt p) {
    final ix = _ix(p.x), iy = _iy(p.y);
    (_cells[_key(ix, iy)] ??= <int>[]).add(i);
    if (_maxX < _minX) {
      _minX = _maxX = ix;
      _minY = _maxY = iy;
    } else {
      _minX = math.min(_minX, ix);
      _maxX = math.max(_maxX, ix);
      _minY = math.min(_minY, iy);
      _maxY = math.max(_maxY, iy);
    }
  }

  /// Moves point [i] to [p].
  void move(int i, Pt p) {
    final old = points[i];
    final k0 = _key(_ix(old.x), _iy(old.y)), k1 = _key(_ix(p.x), _iy(p.y));
    points[i] = p;
    if (k0 != k1) {
      _cells[k0]?.remove(i);
      _insert(i, p);
    }
  }

  /// Leaves point [i] out of every later query.
  void remove(int i) => _removed[i] = true;

  /// Index of the nearest point within [maxDistance] (−1 when none),
  /// leaving out the points [skip] rejects.
  int nearest(Pt p, {double maxDistance = double.infinity, bool Function(int i)? skip}) {
    if (_maxX < _minX) return -1;
    final cx = _ix(p.x), cy = _iy(p.y);
    var best = -1;
    var bestD = maxDistance;
    final maxRing = math.max(math.max((cx - _minX).abs(), (_maxX - cx).abs()), math.max((cy - _minY).abs(), (_maxY - cy).abs()));
    void visit(int ix, int iy) {
      final list = _cells[_key(ix, iy)];
      if (list == null) return;
      for (final i in list) {
        if (_removed[i] || (skip != null && skip(i))) continue;
        final d = points[i].distanceTo(p);
        if (d > maxDistance) continue;
        if (best < 0 || d < bestD || (d == bestD && i < best)) {
          best = i;
          bestD = d;
        }
      }
    }

    for (var r = 0; r <= maxRing; r++) {
      if ((r - 1) * cell > bestD) break;
      if (r == 0) {
        visit(cx, cy);
        continue;
      }
      for (var ix = cx - r; ix <= cx + r; ix++) {
        visit(ix, cy - r);
        visit(ix, cy + r);
      }
      for (var iy = cy - r + 1; iy <= cy + r - 1; iy++) {
        visit(cx - r, iy);
        visit(cx + r, iy);
      }
    }
    return best;
  }

  /// Indices of the [k] points nearest to [p] (nearest first, ties by
  /// index) within [maxDistance], leaving out the points [skip] rejects.
  List<int> kNearest(Pt p, int k, {double maxDistance = double.infinity, bool Function(int i)? skip}) {
    final found = <(double, int)>[];
    if (_maxX < _minX || k <= 0) return const [];
    final cx = _ix(p.x), cy = _iy(p.y);
    final maxRing = math.max(math.max((cx - _minX).abs(), (_maxX - cx).abs()), math.max((cy - _minY).abs(), (_maxY - cy).abs()));
    int cmp((double, int) a, (double, int) b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2);
    void visit(int ix, int iy) {
      final list = _cells[_key(ix, iy)];
      if (list == null) return;
      for (final i in list) {
        if (_removed[i] || (skip != null && skip(i))) continue;
        final d = points[i].distanceTo(p);
        if (d <= maxDistance) found.add((d, i));
      }
    }

    for (var r = 0; r <= maxRing; r++) {
      if ((r - 1) * cell > maxDistance) break;
      if (found.length >= k) {
        found.sort(cmp);
        if ((r - 1) * cell > found[k - 1].$1) break;
      }
      if (r == 0) {
        visit(cx, cy);
        continue;
      }
      for (var ix = cx - r; ix <= cx + r; ix++) {
        visit(ix, cy - r);
        visit(ix, cy + r);
      }
      for (var iy = cy - r + 1; iy <= cy + r - 1; iy++) {
        visit(cx - r, iy);
        visit(cx + r, iy);
      }
    }
    found.sort(cmp);
    return [for (final f in found.take(k)) f.$2];
  }

  /// Indices of the points within [r] of [p], ascending.
  List<int> within(Pt p, double r) {
    final out = <int>[];
    if (_maxX < _minX || !(r >= 0)) return out;
    final x0 = math.max(_minX, _ix(p.x - r)), x1 = math.min(_maxX, _ix(p.x + r));
    final y0 = math.max(_minY, _iy(p.y - r)), y1 = math.min(_maxY, _iy(p.y + r));
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        final list = _cells[_key(ix, iy)];
        if (list == null) continue;
        for (final i in list) {
          if (!_removed[i] && points[i].distanceTo(p) <= r) out.add(i);
        }
      }
    }
    out.sort();
    return out;
  }
}

/// Segments bucketed by the grid cells they cross, for distance queries
/// bounded by a search radius.
class _SegmentGrid {
  _SegmentGrid(this.segs, double cell, Pt origin) : _grid = PointGrid(cell, origin: origin) {
    for (var s = 0; s < segs.length; s++) {
      final (a, b) = segs[s];
      final len = a.distanceTo(b);
      final steps = math.max(1, (len / (_grid.cell / 4)).ceil());
      var lastKey = -1;
      for (var k = 0; k <= steps; k++) {
        final q = Pt.lerp(a, b, k / steps);
        final key = PointGrid._key(_grid._ix(q.x), _grid._iy(q.y));
        if (key == lastKey) continue;
        lastKey = key;
        final list = _buckets[key] ??= <int>[];
        if (list.isEmpty || list.last != s) list.add(s);
      }
    }
  }

  final List<(Pt, Pt)> segs;
  final PointGrid _grid;
  final Map<int, List<int>> _buckets = {};
  final List<int> _stamp = [];
  int _query = 0;

  /// Distance from [p] to the nearest segment, or [maxDistance] when none is
  /// closer.
  double distance(Pt p, double maxDistance) {
    if (!maxDistance.isFinite) {
      var best = double.infinity;
      for (final (a, b) in segs) {
        best = math.min(best, distanceToSegment(p, a, b));
      }
      return best;
    }
    if (_stamp.length != segs.length) {
      _stamp
        ..clear()
        ..addAll(List.filled(segs.length, -1));
    }
    _query++;
    final c = _grid.cell;
    final x0 = _grid._ix(p.x - maxDistance) - 1, x1 = _grid._ix(p.x + maxDistance) + 1;
    final y0 = _grid._iy(p.y - maxDistance) - 1, y1 = _grid._iy(p.y + maxDistance) + 1;
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 4 * segs.length + 64 || c <= 0) return distance(p, double.infinity).clamp(0, maxDistance).toDouble();
    var best = maxDistance;
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        final list = _buckets[PointGrid._key(ix, iy)];
        if (list == null) continue;
        for (final s in list) {
          if (_stamp[s] == _query) continue;
          _stamp[s] = _query;
          final (a, b) = segs[s];
          final d = distanceToSegment(p, a, b);
          if (d < best) best = d;
        }
      }
    }
    return best;
  }
}

// ---------------------------------------------------------------- region

/// One closed loop of a region boundary, with arc lengths for walking it.
class RegionLoop {
  RegionLoop(this.points) : cum = Float64List(points.length + 1) {
    for (var i = 0; i < points.length; i++) {
      cum[i + 1] = cum[i] + points[i].distanceTo(points[(i + 1) % points.length]);
    }
  }

  /// Vertices; the region lies to the left of every edge (outer loops run
  /// counter-clockwise, holes clockwise).
  final List<Pt> points;

  /// Arc length at every vertex (`cum[n]` = perimeter).
  final Float64List cum;

  int get vertexCount => points.length;
  double get length => cum[points.length];
  bool get isHole => polygonArea(points) < 0;

  Pt vertex(int i) => points[((i % points.length) + points.length) % points.length];

  /// Point at arc length [s] (wrapping around the loop).
  Pt at(double s) {
    final l = length;
    if (l <= 0) return points.first;
    var t = s % l;
    if (t < 0) t += l;
    var lo = 0, hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (cum[mid] <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final seg = cum[lo + 1] - cum[lo];
    return Pt.lerp(points[lo], points[(lo + 1) % points.length], seg > 0 ? (t - cum[lo]) / seg : 0);
  }

  /// Turning angle at vertex [i] (degrees, left turns positive): a convex
  /// corner of the region turns left, a re-entrant one right.
  double turnDeg(int i) {
    final a = vertex(i) - vertex(i - 1), b = vertex(i + 1) - vertex(i);
    if (a.length == 0 || b.length == 0) return 0;
    return radToDeg(math.atan2(a.cross(b), a.dot(b)));
  }

  /// Arc length and distance of the loop point nearest to [p].
  (double, double) nearest(Pt p) {
    var best = double.infinity, bestS = 0.0;
    for (var i = 0; i < points.length; i++) {
      final (cp, t) = closestPointOnSegment(p, points[i], points[(i + 1) % points.length]);
      final d = cp.distanceTo(p);
      if (d < best) {
        best = d;
        bestS = cum[i] + t * (cum[i + 1] - cum[i]);
      }
    }
    return (bestS, best);
  }

  /// Wetted sector of a head on the loop at arc length [s] that opens into
  /// the region between the boundary points [delta] ahead and behind it (the
  /// edge's own arc: 180° on a straight edge, less on a convex curve, more on
  /// a concave one): (orientationDeg, arcDeg).
  (double, double) edgeSector(double s, double delta) {
    final p = at(s), f = at(s + delta), b = at(s - delta);
    final df = f - p, db = b - p;
    if (df.length < 1e-9 || db.length < 1e-9) return (0, 360);
    return (normalizeDeg(radToDeg(df.angle)), ccwAngleDeg(df, db));
  }
}

/// The area to irrigate: an outline minus exclusions (buildings, beds,
/// paths), held as closed loops with the region to their left. Exclusions
/// may lie inside the outline, cross it or overlap each other.
class LayoutRegion {
  LayoutRegion._(this.outline, this.exclusions, this.loops, this.bounds, this._segments, {List<List<Pt>>? parts, this.selfCrossing = false}) : parts = parts ?? [if (outline.length >= 3) outline];

  /// Builds the region of [outline] minus [exclusions] (any orientation).
  /// An outline that crosses itself (a bow tie, a figure of eight) is cut
  /// into the simple loops it encloses, every one counted with its own
  /// area and its arcs opening into it ([selfCrossing] tells).
  factory LayoutRegion(List<Pt> outline, {List<List<Pt>> exclusions = const []}) {
    final out = normalizePolygon(outline);
    final crossing = out.length >= 4 && polygonSelfCrossings(out).isNotEmpty;
    final parts = crossing ? (simplePolygonParts(outline)..sort((a, b) => polygonArea(b).abs().compareTo(polygonArea(a).abs()))) : [out];
    if (out.length < 3 || parts.isEmpty || polygonArea(parts.first).abs() < 1e-9) {
      return LayoutRegion._(out, const [], const [], Bounds.ofPoints(out), _SegmentGrid(const [], 1, Pt.zero), parts: const [], selfCrossing: crossing);
    }
    final ob = Bounds.ofPoints([for (final part in parts) ...part]);
    final holes = <List<Pt>>[
      for (final e in exclusions)
        if (normalizePolygon(e) case final h when h.length >= 3 && polygonArea(h).abs() > 1e-9 && Bounds.ofPoints(h).intersects(ob)) h,
    ];
    final loops = [
      for (final part in parts)
        for (final l in _assemble(part, [
          for (final h in holes)
            if (Bounds.ofPoints(h).intersects(Bounds.ofPoints(part))) h,
        ]))
          RegionLoop(l),
    ];
    final segs = <(Pt, Pt)>[
      for (final l in loops)
        for (var i = 0; i < l.points.length; i++) (l.points[i], l.points[(i + 1) % l.points.length]),
    ];
    final b = Bounds.ofPoints([for (final l in loops) ...l.points]);
    final scale = math.max(b.width, b.height);
    final avg = segs.isEmpty ? 1.0 : segs.fold(0.0, (s, e) => s + e.$1.distanceTo(e.$2)) / segs.length;
    final cell = math.max(math.max(avg, scale / 256), 1e-3);
    return LayoutRegion._(out, holes, loops, b, _SegmentGrid(segs, cell, Pt(b.minX, b.minY)), parts: parts, selfCrossing: crossing);
  }

  /// The outline, counter-clockwise (as drawn when it crosses itself).
  final List<Pt> outline;

  /// The simple loops of the outline, the largest first: the outline itself,
  /// or the pieces of one that crosses itself.
  final List<List<Pt>> parts;

  /// Whether the outline crosses itself (see [LayoutRegion.new]).
  final bool selfCrossing;

  /// The exclusions that touch the outline's bounds, counter-clockwise.
  final List<List<Pt>> exclusions;

  /// Boundary loops of the region (outer counter-clockwise, holes clockwise).
  final List<RegionLoop> loops;
  final Bounds bounds;
  final _SegmentGrid _segments;

  bool get isEmpty => loops.isEmpty || area <= 1e-9;

  /// Area (m²).
  late final double area = loops.fold(0.0, (s, l) => s + polygonArea(l.points));

  /// Total boundary length (m).
  late final double perimeter = loops.fold(0.0, (s, l) => s + l.length);

  /// Whether [p] lies in the region (even-odd rule over the loops).
  bool contains(Pt p) {
    var inside = false;
    for (final l in loops) {
      final poly = l.points;
      for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
        final pi = poly[i], pj = poly[j];
        if ((pi.y > p.y) != (pj.y > p.y) && p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x) inside = !inside;
      }
    }
    return inside;
  }

  /// Distance from [p] to the region boundary (outline or exclusion), or
  /// [maxDistance] when the boundary is farther.
  double distanceToBoundary(Pt p, {double maxDistance = double.infinity}) => _segments.distance(p, maxDistance);

  /// Distance inside the region (positive) or outside it (negative).
  double signedDistance(Pt p) {
    final d = distanceToBoundary(p);
    return contains(p) ? d : -d;
  }

  /// Parameter intervals (t along [dir], unit) of the line through [origin]
  /// that lie in the region, sorted.
  List<(double, double)> clipLine(Pt origin, Pt dir) {
    final d = dir.normalized, n = d.perpendicular;
    final v0 = origin.dot(n), u0 = origin.dot(d);
    final ts = <double>[];
    for (final l in loops) {
      final poly = l.points;
      for (var i = 0; i < poly.length; i++) {
        final a = poly[i], b = poly[(i + 1) % poly.length];
        final va = a.dot(n) - v0, vb = b.dot(n) - v0;
        if ((va > 0) == (vb > 0)) continue;
        final ua = a.dot(d) - u0, ub = b.dot(d) - u0;
        ts.add(ua + (ub - ua) * va / (va - vb));
      }
    }
    ts.sort();
    return [
      for (var i = 0; i + 1 < ts.length; i += 2)
        if (ts[i + 1] - ts[i] > 1e-9) (ts[i], ts[i + 1]),
    ];
  }

  /// Loop index, arc length and distance of the boundary point nearest to [p].
  (int, double, double) nearestBoundary(Pt p) {
    var bl = -1;
    var bs = 0.0, bd = double.infinity;
    for (var k = 0; k < loops.length; k++) {
      final (s, d) = loops[k].nearest(p);
      if (d < bd) {
        bl = k;
        bs = s;
        bd = d;
      }
    }
    return (bl, bs, bd);
  }

  /// Boundary loops of [outline] (counter-clockwise) minus [holes]
  /// (counter-clockwise polygons): every edge is cut where it crosses
  /// another polygon, the pieces with the region on their left (and not on
  /// their right) are kept and stitched into loops.
  static List<List<Pt>> _assemble(List<Pt> outline, List<List<Pt>> holes) {
    if (holes.isEmpty) return [outline];
    final scale = math.max(Bounds.ofPoints(outline).width, Bounds.ofPoints(outline).height);
    final tol = math.max(1e-9, scale * 1e-9);
    final polys = [outline, ...holes];
    // fast path: holes strictly inside the outline and apart from each other
    var simple = true;
    for (var k = 1; k < polys.length && simple; k++) {
      for (var j = 0; j < polys.length && simple; j++) {
        if (j == k) continue;
        if (polylineIntersections(polys[k], polys[j], closedA: true, closedB: true).isNotEmpty) simple = false;
      }
      if (simple && !polys[k].every((p) => pointInPolygon(p, outline) && !pointOnPolygonBoundary(p, outline, tol: tol * 10))) simple = false;
      for (var j = 1; j < polys.length && simple; j++) {
        if (j != k && pointInPolygon(polys[k].first, polys[j])) simple = false;
      }
    }
    if (simple) return [outline, for (final h in holes) h.reversed.toList()];

    bool inRegion(Pt q) => pointInPolygon(q, outline) && !holes.any((h) => pointInPolygon(q, h));
    // edges in traversal order: the outline counter-clockwise, holes clockwise
    final edges = <(int, Pt, Pt)>[];
    for (var k = 0; k < polys.length; k++) {
      final p = polys[k];
      final m = p.length;
      if (k == 0) {
        for (var i = 0; i < m; i++) {
          edges.add((0, p[i], p[(i + 1) % m]));
        }
      } else {
        for (var i = m - 1; i >= 0; i--) {
          edges.add((k, p[(i + 1) % m], p[i]));
        }
      }
    }
    final cuts = [for (final _ in edges) <(double, Pt)>[]];
    for (var i = 0; i < edges.length; i++) {
      final (pi, a, b) = edges[i];
      final bi = Bounds.ofPoints([a, b]).inflate(tol);
      for (var j = i + 1; j < edges.length; j++) {
        final (pj, c, d) = edges[j];
        if (pi == pj) continue;
        if (!bi.intersects(Bounds.ofPoints([c, d]).inflate(tol))) continue;
        final r = b - a, s = d - c;
        final den = r.cross(s);
        if (den.abs() <= 1e-12 * r.length * s.length) continue;
        final qp = c - a;
        final t = qp.cross(s) / den, u = qp.cross(r) / den;
        final et = tol / r.length, eu = tol / s.length;
        if (t < -et || t > 1 + et || u < -eu || u > 1 + eu) continue;
        var x = a + r * t;
        for (final e in [a, b, c, d]) {
          if (e.distanceTo(x) <= tol * 10) {
            x = e;
            break;
          }
        }
        if (x.distanceTo(a) > tol * 10 && x.distanceTo(b) > tol * 10) cuts[i].add((t, x));
        if (x.distanceTo(c) > tol * 10 && x.distanceTo(d) > tol * 10) cuts[j].add((u, x));
      }
    }
    final eps = math.max(scale * 1e-7, 1e-9);
    final kept = <(Pt, Pt)>[];
    final keptKeys = <(Pt, Pt)>{};
    for (var i = 0; i < edges.length; i++) {
      final (_, a, b) = edges[i];
      final pts = [a, ...(cuts[i]..sort((x, y) => x.$1.compareTo(y.$1))).map((c) => c.$2), b];
      for (var k = 1; k < pts.length; k++) {
        final s = pts[k - 1], e = pts[k];
        if (s.distanceTo(e) <= eps * 10) continue;
        final m = Pt.lerp(s, e, 0.5), n = (e - s).normalized.perpendicular;
        // an edge shared by the outline and an exclusion outside it counts once
        if (inRegion(m + n * eps) && !inRegion(m - n * eps) && keptKeys.add((s, e))) kept.add((s, e));
      }
    }
    // stitch: from every end, the unused piece leaving it with the sharpest
    // right turn keeps the region on the left
    final starts = <Pt, List<int>>{};
    for (var i = 0; i < kept.length; i++) {
      (starts[kept[i].$1] ??= <int>[]).add(i);
    }
    final used = List.filled(kept.length, false);
    final loops = <List<Pt>>[];
    for (var i0 = 0; i0 < kept.length; i0++) {
      if (used[i0]) continue;
      final loop = <Pt>[kept[i0].$1];
      var cur = i0;
      for (var guard = 0; guard <= kept.length; guard++) {
        used[cur] = true;
        final (s, e) = kept[cur];
        if (e == loop.first || e.distanceTo(loop.first) <= tol * 10) break;
        var cands = (starts[e] ?? const <int>[]).where((k) => !used[k]).toList();
        if (cands.isEmpty) {
          cands = [
            for (var k = 0; k < kept.length; k++)
              if (!used[k] && kept[k].$1.distanceTo(e) <= eps * 100) k,
          ];
        }
        if (cands.isEmpty) break;
        final back = s - e;
        var next = cands.first;
        var bestA = double.infinity;
        for (final k in cands) {
          final a = ccwAngleDeg(back, kept[k].$2 - kept[k].$1);
          if (a < bestA - 1e-9) {
            bestA = a;
            next = k;
          }
        }
        loop.add(e);
        cur = next;
      }
      final clean = normalizePolygon(loop, ccw: polygonArea(loop) >= 0);
      if (clean.length >= 3 && polygonArea(clean).abs() > tol) loops.add(clean);
    }
    return loops;
  }
}

/// A queue cell of the pole-of-inaccessibility search.
class _PoleCell {
  _PoleCell(this.c, this.h, this.d) : max = d + h * math.sqrt2;
  final Pt c;
  final double h, d, max;
}

/// Centre and distance of the point of [bounds] farthest inside a shape
/// given by its [signedDistance] (positive inside): the pole of
/// inaccessibility, found by the quadtree search of Garcia-Castellanos &
/// Lombardo (2007, *Scottish Geographical Journal* 123) to within
/// [precision] metres. [hint] seeds the search (the centroid, say).
(Pt, double) poleOfInaccessibility(Bounds bounds, double Function(Pt p) signedDistance, {required double precision, Pt? hint, int maxCells = 200000}) {
  if (bounds.isEmpty) return (Pt.zero, 0);
  final size = math.min(bounds.width, bounds.height);
  final prec = precision > 0 ? precision : math.max(1e-3, math.max(bounds.width, bounds.height) / 1000);
  if (size <= 0) return (bounds.center, math.max(0, signedDistance(bounds.center)));
  final heap = <_PoleCell>[];
  void push(_PoleCell c) {
    heap.add(c);
    var i = heap.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (heap[p].max >= heap[i].max) break;
      final t = heap[p];
      heap[p] = heap[i];
      heap[i] = t;
      i = p;
    }
  }

  _PoleCell pop() {
    final top = heap.first;
    final last = heap.removeLast();
    if (heap.isNotEmpty) {
      heap[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < heap.length && heap[l].max > heap[m].max) m = l;
        if (r < heap.length && heap[r].max > heap[m].max) m = r;
        if (m == i) break;
        final t = heap[m];
        heap[m] = heap[i];
        heap[i] = t;
        i = m;
      }
    }
    return top;
  }

  final h0 = size / 2;
  for (var x = bounds.minX; x < bounds.maxX; x += size) {
    for (var y = bounds.minY; y < bounds.maxY; y += size) {
      final c = Pt(x + h0, y + h0);
      push(_PoleCell(c, h0, signedDistance(c)));
    }
  }
  var best = _PoleCell(hint ?? bounds.center, 0, signedDistance(hint ?? bounds.center));
  final bc = _PoleCell(bounds.center, 0, signedDistance(bounds.center));
  if (bc.d > best.d) best = bc;
  var n = 0;
  while (heap.isNotEmpty && n < maxCells) {
    final cell = pop();
    n++;
    if (cell.d > best.d) best = cell;
    if (cell.max - best.d <= prec) continue;
    final h = cell.h / 2;
    for (final (dx, dy) in const [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
      final c = Pt(cell.c.x + dx * h, cell.c.y + dy * h);
      push(_PoleCell(c, h, signedDistance(c)));
    }
  }
  return (best.c, math.max(0, best.d));
}

/// Centre and radius of the largest circle inside [region] (see
/// [poleOfInaccessibility]).
(Pt, double) maximumInscribedCircle(LayoutRegion region, {double precision = 0}) {
  if (region.isEmpty) return (Pt.zero, 0);
  final b = region.bounds;
  final prec = precision > 0 ? precision : math.max(1e-3, math.max(b.width, b.height) / 500);
  final hint = polygonCentroid(region.outline);
  return poleOfInaccessibility(b, region.signedDistance, precision: prec, hint: region.contains(hint) ? hint : null);
}

// ---------------------------------------------------------------- heads and nozzles

/// Where a head sits in a layout.
enum HeadRole { corner, edge, interior }

/// One head of an automatic layout.
class LayoutHead {
  const LayoutHead({required this.position, required this.arcDeg, this.orientationDeg = 0, this.role = HeadRole.interior, this.nozzleId, this.flow = 0, this.radius = 0, this.targetFlow = 0});

  final Pt position;

  /// Wetted sector (degrees, 360 = full circle) swept counter-clockwise
  /// from [orientationDeg] (world angle of the x axis).
  final double arcDeg;
  final double orientationDeg;
  final HeadRole role;

  /// Catalogue nozzle chosen for matched precipitation.
  final String? nozzleId;

  /// Discharge (m³/s) and wetted radius (m) of the nozzle at the design
  /// pressure.
  final double flow;
  final double radius;

  /// Matched-precipitation flow for the arc: q_full·arc/360 (m³/s).
  final double targetFlow;

  bool get fullCircle => arcDeg >= 360 - 1e-6;

  /// Nozzle flow over the matched-precipitation flow (1 = matched).
  double get precipitationRatio => targetFlow > 0 && flow > 0 ? flow / targetFlow : 1;

  LayoutHead copyWith({Pt? position, double? arcDeg, double? orientationDeg, HeadRole? role, String? nozzleId, double? flow, double? radius, double? targetFlow}) => LayoutHead(
    position: position ?? this.position,
    arcDeg: arcDeg ?? this.arcDeg,
    orientationDeg: orientationDeg ?? this.orientationDeg,
    role: role ?? this.role,
    nozzleId: nozzleId ?? this.nozzleId,
    flow: flow ?? this.flow,
    radius: radius ?? this.radius,
    targetFlow: targetFlow ?? this.targetFlow,
  );

  /// Wetted sector for the densogram model.
  SpraySource toSource(String id) => SpraySource(entityId: id, p: position, flow: flow, radius: radius, startRad: degToRad(orientationDeg), sweepRad: degToRad(arcDeg.clamp(1.0, 360.0)));
}

/// A nozzle chosen for one head.
class NozzleChoice {
  const NozzleChoice({required this.nozzle, required this.flow, required this.radius, required this.targetFlow, required this.score});
  final NozzleSpec nozzle;

  /// Flow (m³/s) and wetted radius (m) at the design pressure.
  final double flow, radius;

  /// Matched-precipitation flow (m³/s).
  final double targetFlow;

  /// Mismatch score (0 = flow, arc and radius all matched).
  final double score;

  double get ratio => targetFlow > 0 ? flow / targetFlow : 1;
}

/// Pressure (m) a layout of [family] works at by default: the median
/// default pressure of its nozzles.
double defaultLayoutHead(OutletSpec family) {
  final hs = [for (final n in family.nozzles) n.defaultHeadM]..sort();
  return hs.isEmpty ? 20 : hs[hs.length ~/ 2];
}

/// Flow of a full circle with nozzle [n] at [headM] (a part-circle nozzle
/// scaled to 360°).
double fullCircleFlow(NozzleSpec n, double headM) => n.curve.flow(headM) * (n.arcDeg >= 360 - 1e-6 ? 1 : 360 / n.arcDeg.clamp(1.0, 360.0));

/// How many of the quarter and half circles the nozzles of [family] match
/// for the full circle of [full] at [headM] (0–2): a part-circle nozzle of
/// that arc (±5°) throwing about as far (±15 %) with the flow of its share
/// of the arc (±20 %). A family without them (micro-sprinklers, impact
/// sprinklers) cannot water the edges with part circles at the same depth.
int matchedPartCircles(OutletSpec family, NozzleSpec full, double headM) {
  final qf = fullCircleFlow(full, headM), rf = full.curve.radius(headM);
  if (!(qf > 0) || !(rf > 0)) return 0;
  var c = 0;
  for (final arc in const [90.0, 180.0]) {
    final match = family.nozzles.any((n) => (n.arcDeg - arc).abs() <= 5 && (n.curve.radius(headM) / rf - 1).abs() <= 0.15 && (n.curve.flow(headM) / (qf * arc / 360) - 1).abs() <= 0.2);
    if (match) c++;
  }
  return c;
}

/// The full-circle nozzle of [family] that sets the spacing of a layout at
/// [headM]: one that comes with matched part-circle nozzles (a quarter and
/// a half of its flow at about its radius, see [matchedPartCircles]) and
/// whose wetted radius does not exceed [maxRadius] (heads on opposite edges
/// of the widest part of the area throw to each other); the largest such
/// radius, so the fewest heads. When none fits, the smallest radius. Null
/// when no nozzle has a radius.
NozzleSpec? referenceNozzle(OutletSpec family, double headM, {double maxRadius = double.infinity}) {
  final withRadius = [
    for (final n in family.nozzles)
      if (n.curve.radius(headM) > 0 && n.curve.flow(headM) > 0) n,
  ];
  if (withRadius.isEmpty) return null;
  final full = [
    for (final n in withRadius)
      if (n.arcDeg >= 360 - 1e-6) n,
  ];
  final cands = full.isNotEmpty ? full : withRadius;
  int completeness(NozzleSpec f) => matchedPartCircles(family, f, headM);
  final fits = [
    for (final n in cands)
      if (n.curve.radius(headM) <= maxRadius * (1 + 1e-9)) n,
  ];
  if (fits.isEmpty) {
    var best = cands.first;
    for (final n in cands) {
      if (n.curve.radius(headM) < best.curve.radius(headM) - 1e-12) best = n;
    }
    return best;
  }
  var best = fits.first;
  var bc = completeness(best);
  for (final n in fits.skip(1)) {
    final c = completeness(n);
    final r = n.curve.radius(headM), rb = best.curve.radius(headM);
    if (c > bc || (c == bc && r > rb + 1e-9)) {
      best = n;
      bc = c;
    }
  }
  return best;
}

/// The nozzle of [family] for a head watering [arcDeg] degrees at [headM]
/// metres with matched precipitation: the flow closest (on a log scale) to
/// [fullFlow]·arc/360, a part-circle nozzle near its own arc (a full-circle
/// nozzle is taken as adjustable to any arc on the head), the wetted radius
/// close to [radius] and not shorter than [minRadiusRatio]·[radius], the
/// pressure inside the nozzle's range. A full circle only takes full-circle
/// nozzles. Ties keep the catalogue order. Null when no nozzle has a flow.
NozzleChoice? matchedPrecipitationNozzle(OutletSpec family, double arcDeg, {required double headM, required double fullFlow, required double radius, double minRadiusRatio = 0.9}) {
  final a = arcDeg.clamp(1.0, 360.0).toDouble();
  final full = a >= 360 - 1e-6;
  final target = fullFlow * a / 360;
  NozzleChoice? best;
  for (final n in family.nozzles) {
    if (full && n.arcDeg < 360 - 1e-6) continue;
    final q = n.curve.flow(headM), r = n.curve.radius(headM);
    if (!(q > 0)) continue;
    var score = target > 0 ? (math.log(q / target)).abs() : 0.0;
    if (n.arcDeg < 360 - 1e-6) score += 0.5 * (n.arcDeg - a).abs() / 180;
    if (radius > 0) {
      if (r > 0) {
        score += 0.5 * (math.log(r / radius)).abs();
        if (r < minRadiusRatio * radius) score += 1 + 5 * (minRadiusRatio * radius - r) / radius;
      } else {
        score += 2;
      }
    }
    if (headM < n.minHeadM - 1e-9 || headM > n.maxHeadM + 1e-9) score += 1;
    if (best == null || score < best.score - 1e-12) best = NozzleChoice(nozzle: n, flow: q, radius: r, targetFlow: target, score: score);
  }
  return best;
}

// ---------------------------------------------------------------- evaluation

/// Uniformity and efficiency of a head layout over its region.
class LayoutMetrics {
  const LayoutMetrics({
    required this.cu,
    required this.du,
    required this.sc,
    required this.dryPct,
    required this.meanRateMmH,
    required this.minRateMmH,
    required this.maxRateMmH,
    required this.oversprayPct,
    required this.areaM2,
    required this.totalFlow,
    required this.heads,
    required this.cellSize,
  });

  static const empty = LayoutMetrics(cu: 0, du: 0, sc: 0, dryPct: 100, meanRateMmH: 0, minRateMmH: 0, maxRateMmH: 0, oversprayPct: 0, areaM2: 0, totalFlow: 0, heads: 0, cellSize: 0);

  /// Christiansen coefficient of uniformity (%) inside the region.
  final double cu;

  /// Low-quarter distribution uniformity (%).
  final double du;

  /// Scheduling coefficient (mean over the mean of the driest 5 %).
  final double sc;

  /// Share of the region receiving less than half the mean (%).
  final double dryPct;

  /// Application rate inside the region (mm/h).
  final double meanRateMmH, minRateMmH, maxRateMmH;

  /// Share of the water thrown outside the region (%): over the outline,
  /// on buildings and beds.
  final double oversprayPct;

  /// Area evaluated (m²).
  final double areaM2;

  /// Flow of all the heads (m³/s).
  final double totalFlow;
  final int heads;

  /// Cell of the evaluation grid (m).
  final double cellSize;
}

/// Raster of a region: cells of [h] metres from [origin] whose centres lie
/// inside it.
class _Raster {
  _Raster(LayoutRegion region, double cell) : h = cell {
    final b = region.bounds;
    origin = Pt(b.minX, b.minY);
    nx = math.max(1, (b.width / h).ceil());
    ny = math.max(1, (b.height / h).ceil());
    mask = Uint8List(nx * ny);
    for (var j = 0; j < ny; j++) {
      final y = origin.y + (j + 0.5) * h;
      for (final (x0, x1) in region.clipLine(Pt(0, y), const Pt(1, 0))) {
        final i0 = math.max(0, ((x0 - origin.x) / h - 0.5).ceil()), i1 = math.min(nx - 1, ((x1 - origin.x) / h - 0.5).floor());
        for (var i = i0; i <= i1; i++) {
          mask[j * nx + i] = 1;
          count++;
        }
      }
    }
  }

  final double h;
  late final Pt origin;
  late final int nx, ny;
  late final Uint8List mask;
  int count = 0;

  Pt center(int k) => Pt(origin.x + (k % nx + 0.5) * h, origin.y + (k ~/ nx + 0.5) * h);
}

double _rasterCell(LayoutRegion region, double wanted, int maxCells) {
  var h = wanted > 0 && wanted.isFinite ? wanted : 1.0;
  final b = region.bounds;
  while ((b.width / h).ceil() * (b.height / h).ceil() > maxCells) {
    h *= 1.25;
  }
  return h;
}

/// Uniformity of [heads] over [region] with the densogram model: the water
/// of every head spread over its sector with [profile], Christiansen CU,
/// low-quarter DU, scheduling coefficient and dry share inside the region
/// (see `densogramStats`), and the share thrown outside it. [cellSize] 0 =
/// a quarter of the smallest wetted radius, coarser beyond [maxCells].
LayoutMetrics evaluateHeadLayout(LayoutRegion region, List<LayoutHead> heads, {SprayProfile profile = SprayProfile.triangular, double cellSize = 0, int maxCells = 250000}) => evaluateSprayUniformity(
  region,
  [
    for (var i = 0; i < heads.length; i++)
      if (heads[i].flow > 0 && heads[i].radius > 0) heads[i].toSource('$i'),
  ],
  profile: profile,
  cellSize: cellSize,
  maxCells: maxCells,
);

/// [evaluateHeadLayout] for wetted sectors already built (the sprinklers of
/// a drawing, see `spraySources`).
LayoutMetrics evaluateSprayUniformity(LayoutRegion region, List<SpraySource> sources, {SprayProfile profile = SprayProfile.triangular, double cellSize = 0, int maxCells = 250000}) {
  if (region.isEmpty || sources.isEmpty) return LayoutMetrics.empty;
  final minR = sources.fold(double.infinity, (m, s) => math.min(m, s.radius));
  // a cell no wider than the area: a strip narrower than a quarter of the
  // radius would otherwise have no cell centre inside it (CU 0, all dry)
  var wanted = cellSize > 0 ? cellSize : math.max(0.05, minR / 4);
  if (cellSize <= 0) {
    final (_, rIn) = maximumInscribedCircle(region);
    if (rIn > 0) wanted = math.min(wanted, math.max(0.01, rIn));
  }
  final raster = _Raster(region, _rasterCell(region, wanted, maxCells));
  final h = raster.h, nx = raster.nx, ny = raster.ny, o = raster.origin;
  final rate = Float64List(nx * ny);
  for (final s in sources) {
    final i0 = math.max(0, ((s.p.x - s.radius - o.x) / h).floor()), i1 = math.min(nx - 1, ((s.p.x + s.radius - o.x) / h).floor());
    final j0 = math.max(0, ((s.p.y - s.radius - o.y) / h).floor()), j1 = math.min(ny - 1, ((s.p.y + s.radius - o.y) / h).floor());
    for (var j = j0; j <= j1; j++) {
      final cy = o.y + (j + 0.5) * h - s.p.y;
      for (var i = i0; i <= i1; i++) {
        final k = j * nx + i;
        if (raster.mask[k] == 0) continue;
        final cx = o.x + (i + 0.5) * h - s.p.x;
        final d = math.sqrt(cx * cx + cy * cy);
        if (d >= s.radius) continue;
        if (!s.fullCircle && d > 1e-9 && !s.covers(math.atan2(cy, cx))) continue;
        rate[k] += s.rateAt(d, profile);
      }
    }
  }
  final values = <double>[];
  var inside = 0.0;
  for (var k = 0; k < rate.length; k++) {
    if (raster.mask[k] == 0) continue;
    values.add(rate[k] * 1000 * 3600);
    inside += rate[k] * h * h;
  }
  final total = sources.fold(0.0, (s, e) => s + e.flow);
  final st = densogramStats(values, h * h);
  return LayoutMetrics(
    // Christiansen's CU falls below zero when the mean deviation exceeds
    // the mean (most of the area dry): 0 is the floor of the scale
    cu: math.max(0.0, st.cu),
    du: st.du,
    sc: st.sc,
    dryPct: st.dryPct,
    meanRateMmH: st.mean,
    minRateMmH: st.min,
    maxRateMmH: st.max,
    oversprayPct: total > 0 ? (100 * (1 - inside / total)).clamp(0.0, 100.0).toDouble() : 0,
    areaM2: st.areaM2,
    totalFlow: total,
    heads: sources.length,
    cellSize: h,
  );
}

// ---------------------------------------------------------------- landscape layout

/// How the head spacing follows from the reference nozzle.
enum SpacingRule {
  /// Spacing = wetted radius (head to head).
  headToHead,

  /// Spacing = a percentage of the wetted diameter (50 % = head to head;
  /// Keller & Bliesner 1990, table 5.2, ask for 50–65 % by wind).
  percentOfDiameter,

  /// A spacing typed in metres.
  fixed,
}

/// Whether the edges get part circles.
enum PartCircleMode {
  /// Part circles when the family has matched part-circle nozzles (see
  /// [matchedPartCircles]), else full circles only.
  auto,

  /// Corner and edge heads with part circles in any case.
  always,

  /// Full circles only, on a grid inset half a spacing from the edges (the
  /// layout of agricultural sprinklers and micro-sprinklers).
  never,
}

/// Options of [layoutLandscape].
class LandscapeLayoutOptions {
  LandscapeLayoutOptions({
    this.headM = 0,
    this.referenceNozzleId,
    this.spacingRule = SpacingRule.headToHead,
    this.spacingPercent = 50,
    this.spacingM = 0,
    this.pattern = GridPattern.square,
    this.direction,
    this.partCircles = PartCircleMode.auto,
    this.cornerAngleDeg = 25,
    this.minCornerArcDeg = 45,
    this.minSpacingFraction = 0.4,
    this.narrowStripFraction = 0.6,
    this.edgeClearanceFraction = 0.5,
    this.coverageFraction,
    this.rowStretchFraction = 0.12,
    this.smallExclusionFactor = 3,
    this.relaxIterations = 4,
    this.minRadiusRatio = 0.9,
    this.profile = SprayProfile.triangular,
    this.evaluate = true,
    this.maxHeads = 20000,
  });

  /// Design pressure at the heads (m); 0 = the family's default.
  double headM;

  /// Full-circle nozzle that sets the spacing (null = chosen: see
  /// [referenceNozzle]).
  String? referenceNozzleId;
  SpacingRule spacingRule;

  /// For [SpacingRule.percentOfDiameter]: spacing as % of the wetted
  /// diameter.
  double spacingPercent;

  /// For [SpacingRule.fixed]: the spacing (m).
  double spacingM;

  /// Interior grid: square (rows one spacing apart) or triangular
  /// (equilateral, rows 0.866 spacing apart, alternate rows shifted half a
  /// spacing).
  GridPattern pattern;

  /// Direction of the rows of the interior grid (null = along the longest
  /// edge of the outline).
  Pt? direction;

  /// Part circles on the edges, or full circles only.
  PartCircleMode partCircles;

  /// A boundary vertex turning more than this (degrees) is a corner and
  /// gets a head; gentler vertices are part of a curved edge.
  double cornerAngleDeg;

  /// A corner sharper than this (degrees) gets no head: the first heads of
  /// its two edges water the tip.
  double minCornerArcDeg;

  /// Heads never closer than this fraction of the spacing (corners closer
  /// than it are merged; interior heads closer than it are left out).
  double minSpacingFraction;

  /// Across a strip narrower than this fraction of the spacing (between a
  /// building and the lot line, a narrow notch) only one row of edge heads
  /// is laid.
  double narrowStripFraction;

  /// Interior (full-circle) heads keep this fraction of the spacing from
  /// the outline and the exclusions (half of it in a layout of full circles
  /// only, whose outer heads stand half a spacing in).
  double edgeClearanceFraction;

  /// After the grid, a head is added wherever a point of the area is
  /// farther than this fraction of the spacing from every head (null =
  /// 0.72 for a square grid, whose farthest point is at 0.707, and 0.66 for
  /// a triangular one, at 0.577).
  double? coverageFraction;

  /// A row of the interior grid stretches its heads up to this fraction
  /// beyond the spacing before taking one more (a strip a little wider than
  /// the spacing is within reach of its edge heads).
  double rowStretchFraction;

  /// An exclusion whose perimeter is shorter than this many spacings (a
  /// tree ring, a small bed) gets no heads round it: the heads keep out of
  /// it and throw over it (counted as overspray). 0 = every exclusion is
  /// ringed with heads.
  double smallExclusionFactor;

  /// Rounds of centroidal relaxation of the interior heads near irregular
  /// edges (0 = keep the grid as placed).
  int relaxIterations;

  /// Part circles take nozzles throwing at least this fraction of the
  /// reference radius.
  double minRadiusRatio;

  /// Distribution profile of the evaluation.
  SprayProfile profile;

  /// Evaluate the uniformity (densogram) of the result.
  bool evaluate;

  /// Most heads a layout may place (a spacing far too small for the area
  /// returns an empty layout with `layout_too_many_heads`).
  int maxHeads;

  /// A copy (the templates fill in the direction of their rows).
  LandscapeLayoutOptions copy() => LandscapeLayoutOptions(
    headM: headM,
    referenceNozzleId: referenceNozzleId,
    spacingRule: spacingRule,
    spacingPercent: spacingPercent,
    spacingM: spacingM,
    pattern: pattern,
    direction: direction,
    partCircles: partCircles,
    cornerAngleDeg: cornerAngleDeg,
    minCornerArcDeg: minCornerArcDeg,
    minSpacingFraction: minSpacingFraction,
    narrowStripFraction: narrowStripFraction,
    edgeClearanceFraction: edgeClearanceFraction,
    coverageFraction: coverageFraction,
    rowStretchFraction: rowStretchFraction,
    smallExclusionFactor: smallExclusionFactor,
    relaxIterations: relaxIterations,
    minRadiusRatio: minRadiusRatio,
    profile: profile,
    evaluate: evaluate,
    maxHeads: maxHeads,
  );
}

/// Result of an automatic head layout ([layoutLandscape] and the
/// templates).
class LandscapeLayout {
  LandscapeLayout({
    required this.region,
    required this.outletSpecId,
    required this.heads,
    required this.headM,
    this.referenceNozzleId,
    this.spacing = 0,
    this.rowSpacing = 0,
    this.direction = const Pt(1, 0),
    this.metrics,
    this.messages = const [],
  });

  /// The area the layout waters (outline minus every exclusion).
  final LayoutRegion region;
  final String outletSpecId;
  final List<LayoutHead> heads;

  /// Design pressure (m).
  final double headM;
  final String? referenceNozzleId;

  /// Spacing along the rows and the edges, and between rows (m).
  final double spacing, rowSpacing;

  /// Direction of the rows.
  final Pt direction;

  /// Uniformity of the layout (null when not evaluated).
  final LayoutMetrics? metrics;

  /// Message codes: `layout_self_intersect` (the outline crosses itself: its
  /// loops are laid out apart), `layout_empty`, `layout_no_nozzle`, `layout_no_radius`,
  /// `layout_no_spacing`, `layout_too_many_heads` (nothing laid out);
  /// `layout_spacing_clamped` (a spacing beyond the wetted diameter),
  /// `layout_radius_large` (the heads throw farther than the area is wide),
  /// `layout_narrow_strip` (edge heads left out across a strip narrower
  /// than the minimum gap), `layout_full_circles` (no matched part circles:
  /// full circles inset from the edges), `layout_mp_mismatch:<head>` and
  /// `layout_radius_short:<head>` (see [finishHeadLayout]).
  final List<String> messages;

  bool get isEmpty => heads.isEmpty;

  /// Flow of every head together (m³/s).
  double get totalFlow => heads.fold(0.0, (s, h) => s + h.flow);

  /// Precipitation rate of the layout (mm/h): the total flow over the area.
  double get grossRateMmH => region.area > 0 ? totalFlow / region.area * 1000 * 3600 : 0;

  /// Worst matched-precipitation mismatch: max |flow/target − 1|.
  double get maxPrecipitationMismatch => heads.fold(0.0, (m, h) => math.max(m, (h.precipitationRatio - 1).abs()));

  /// The heads as outlets of [p] (new ids), working at [headM]; [zoneName]
  /// names the zone of head i (empty by default).
  List<OutletEntity> toOutlets(Project p, {String Function(int index)? zoneName, HydraulicScope scope = HydraulicScope.zone, double riserHeight = 0}) => [
    for (var i = 0; i < heads.length; i++)
      OutletEntity(
        id: p.newId(),
        position: heads[i].position,
        scope: scope,
        outletSpecId: outletSpecId,
        nozzleId: heads[i].nozzleId,
        headM: headM,
        arcDeg: heads[i].fullCircle ? 360 : _round(heads[i].arcDeg, 1e-6),
        orientationDeg: heads[i].fullCircle ? 0 : _round(normalizeDeg(heads[i].orientationDeg), 1e-6),
        riserHeight: riserHeight,
        zoneName: zoneName?.call(i) ?? '',
      ),
  ];
}

double _round(double v, double step) => (v / step).roundToDouble() * step;

/// Mutable head while a layout is built.
class _Head {
  _Head(this.p, this.arc, this.orient, this.role, {this.movable = false, this.loop = -1, this.s = 0});
  Pt p;
  double arc;
  double orient;
  HeadRole role;
  bool movable;

  /// Boundary loop and arc length of a corner or edge head (−1 inside).
  int loop;
  double s;
}

/// Lays out heads of [family] over [outline] minus [exclusions] (see the
/// library comment): corners, edges, an interior grid inset from the edges,
/// heads added where the area is out of reach, a centroidal relaxation of
/// the interior heads near irregular edges, matched-precipitation nozzles
/// and the uniformity of the result. A family without matched part circles
/// gets full circles on a grid inset half a spacing (see
/// [PartCircleMode]).
LandscapeLayout layoutLandscape({required List<Pt> outline, List<List<Pt>> exclusions = const [], required OutletSpec family, LandscapeLayoutOptions? options}) {
  final o = options ?? LandscapeLayoutOptions();
  final region = LayoutRegion(outline, exclusions: exclusions);
  final headM = o.headM > 0 ? o.headM : defaultLayoutHead(family);
  LandscapeLayout empty(String code) => LandscapeLayout(region: region, outletSpecId: family.id, heads: const [], headM: headM, messages: [code]);
  if (region.isEmpty) return empty('layout_empty');
  final (_, rIn) = maximumInscribedCircle(region);
  NozzleSpec? ref;
  if (o.referenceNozzleId != null) {
    for (final n in family.nozzles) {
      if (n.id == o.referenceNozzleId) ref = n;
    }
  }
  ref ??= referenceNozzle(family, headM, maxRadius: 2 * rIn);
  if (ref == null) return empty('layout_no_nozzle');
  final rRef = ref.curve.radius(headM);
  if (!(rRef > 0)) return empty('layout_no_radius');
  final messages = <String>[if (region.selfCrossing) 'layout_self_intersect'];
  var spacing = switch (o.spacingRule) {
    SpacingRule.headToHead => rRef,
    SpacingRule.percentOfDiameter => 2 * rRef * (o.spacingPercent > 0 ? o.spacingPercent : 50) / 100,
    SpacingRule.fixed => o.spacingM,
  };
  if (!(spacing > 0) || !spacing.isFinite) return empty('layout_no_spacing');
  if (spacing > 2 * rRef) {
    spacing = 2 * rRef;
    messages.add('layout_spacing_clamped');
  }
  if (rRef > 2 * rIn + 1e-9) messages.add('layout_radius_large');
  if (region.area / (spacing * spacing) > o.maxHeads || region.perimeter / spacing > o.maxHeads) return empty('layout_too_many_heads');
  final partCircles = switch (o.partCircles) {
    PartCircleMode.always => true,
    PartCircleMode.never => false,
    PartCircleMode.auto => matchedPartCircles(family, ref, headM) > 0,
  };
  if (!partCircles) messages.add('layout_full_circles');
  // small exclusions get no heads round them: the heads are placed over the
  // area without them, kept out of them, and the evaluation leaves them out
  final soft = <List<Pt>>[], hard = <List<Pt>>[];
  for (final e in region.exclusions) {
    (polylineLength([...e, e.first]) < o.smallExclusionFactor * spacing ? soft : hard).add(e);
  }
  final place = soft.isEmpty ? region : LayoutRegion(region.outline, exclusions: hard);
  bool inSoft(Pt p) => soft.any((e) => pointInPolygon(p, e) || pointOnPolygonBoundary(p, e, tol: 1e-6));
  final dir = (o.direction != null && o.direction!.length > 0 ? o.direction! : longestEdgeDirection(region.outline)).normalized;
  final triangular = o.pattern == GridPattern.triangular;
  final rowTarget = triangular ? spacing * math.sqrt(3) / 2 : spacing;
  final minGap = math.max(0.0, o.minSpacingFraction) * spacing;
  final clearance = math.max(0.0, o.edgeClearanceFraction) * spacing * (partCircles ? 1 : 0.5);
  final reach = (o.coverageFraction ?? (triangular ? 0.66 : 0.72)) * spacing;
  final b = region.bounds;
  final heads = <_Head>[];
  final grid = PointGrid(spacing / 2, origin: Pt(b.minX, b.minY));
  void addHead(_Head h) {
    heads.add(h);
    grid.add(h.p);
  }

  // 1. corners and edges of every loop
  if (partCircles) {
    for (var k = 0; k < place.loops.length; k++) {
      final loop = place.loops[k];
      if (loop.isHole && loop.length < spacing) continue;
      for (final h in _loopHeads(loop, spacing, cornerDeg: o.cornerAngleDeg, minGap: minGap, minCornerArc: o.minCornerArcDeg)) {
        if (inSoft(h.p)) continue;
        // the corner of a house or bed a little off the lot line (or off a
        // corner of another loop) merges into the head already there: two
        // heads never closer than the minimum gap
        if (h.role == HeadRole.corner && grid.nearest(h.p, maxDistance: minGap - 1e-9) >= 0) continue;
        h.loop = k;
        // across a strip much narrower than the spacing (a house a few
        // metres from the lot line) one row of heads is enough: an edge head
        // facing a head of another edge is left out
        if (h.role == HeadRole.edge) {
          final facing = grid.within(h.p, o.narrowStripFraction * spacing).any((i) {
            final other = heads[i];
            if (other.loop != k) return true;
            final d = (other.s - h.s).abs();
            return math.min(d, loop.length - d) > 1.5 * spacing;
          });
          if (facing || grid.nearest(h.p, maxDistance: minGap) >= 0) {
            if (!messages.contains('layout_narrow_strip')) messages.add('layout_narrow_strip');
            continue;
          }
        }
        addHead(h);
      }
    }
  }
  // 2. interior grid: rows evenly spread across the area, heads evenly
  // spread along every row between the edges it crosses (with part circles
  // the outer rows are the edges themselves; with full circles every row
  // and head is inset half a step)
  final perp = dir.perpendicular;
  var vMin = double.infinity, vMax = -double.infinity;
  for (final l in place.loops) {
    for (final p in l.points) {
      vMin = math.min(vMin, p.dot(perp));
      vMax = math.max(vMax, p.dot(perp));
    }
  }
  final nRows = math.max(1, ((vMax - vMin) / rowTarget - (partCircles ? 1e-9 : o.rowStretchFraction)).ceil());
  final rowSp = (vMax - vMin) / nRows;
  for (var r = partCircles ? 1 : 0; r < nRows; r++) {
    final v = vMin + (partCircles ? r : r + 0.5) * rowSp;
    final origin = perp * v;
    final shifted = triangular && r.isOdd;
    for (final (u0, u1) in place.clipLine(origin, dir)) {
      final len = u1 - u0;
      // a row may stretch a little beyond the spacing, as the gap filling
      // does, so that a narrow arm gets the same heads whichever way the
      // rows cross it
      final m = math.max(1, (len / spacing - o.rowStretchFraction).ceil());
      final s = len / m;
      final offsets = partCircles
          ? [for (var j = 0; j < (shifted ? m : m - 1); j++) shifted ? (j + 0.5) * s : (j + 1) * s]
          : [for (var j = 0; j < (shifted ? m - 1 : m); j++) shifted ? (j + 1) * s : (j + 0.5) * s];
      for (final du in offsets) {
        final p = origin + dir * (u0 + du);
        if (inSoft(p)) continue;
        if (place.distanceToBoundary(p, maxDistance: clearance) < clearance - 1e-9) continue;
        if (grid.nearest(p, maxDistance: minGap - 1e-9) >= 0) continue;
        addHead(_Head(p, 360, 0, HeadRole.interior, movable: true));
      }
    }
  }
  // 3. heads where the area is out of reach of every head, then 4. a
  // centroidal (Lloyd) relaxation of the interior heads
  final raster = _Raster(place, _rasterCell(place, spacing / 6, 300000));
  if (raster.count > 0) {
    _fillGaps(place, raster, grid, spacing: spacing, reach: reach, clearance: clearance, minGap: minGap, onBoundary: partCircles, inSoft: inSoft, addHead: addHead);
    for (var it = 0; it < o.relaxIterations; it++) {
      if (!_relax(place, raster, heads, grid, clearance: clearance, minGap: minGap, spacing: spacing, inSoft: inSoft)) break;
    }
  }
  // 5. matched-precipitation nozzles and the uniformity
  final laid = [for (final h in heads) LayoutHead(position: h.p, arcDeg: h.arc, orientationDeg: normalizeDeg(h.orient), role: h.role)];
  return finishHeadLayout(
    region: region,
    family: family,
    heads: laid,
    headM: headM,
    reference: ref,
    spacing: spacing,
    rowSpacing: rowSp,
    direction: dir,
    messages: messages,
    evaluate: o.evaluate,
    profile: o.profile,
    minRadiusRatio: o.minRadiusRatio,
  );
}

/// Gives every head of [heads] the nozzle of [family] for matched
/// precipitation at [headM] (the flow of [reference] at a full circle,
/// scaled by the arc) and returns the layout with its uniformity. Codes:
/// `layout_mp_mismatch:<head>` when a nozzle misses its flow by more than
/// 15 %, `layout_radius_short:<head>` when it throws less than
/// [minRadiusRatio] of the reference radius.
LandscapeLayout finishHeadLayout({
  required LayoutRegion region,
  required OutletSpec family,
  required List<LayoutHead> heads,
  required double headM,
  NozzleSpec? reference,
  double spacing = 0,
  double rowSpacing = 0,
  Pt direction = const Pt(1, 0),
  List<String> messages = const [],
  bool evaluate = true,
  SprayProfile profile = SprayProfile.triangular,
  double minRadiusRatio = 0.9,
}) {
  final msgs = List.of(messages);
  final ref = reference ?? referenceNozzle(family, headM);
  final qFull = ref == null ? 0.0 : fullCircleFlow(ref, headM);
  final rRef = ref?.curve.radius(headM) ?? 0.0;
  final done = <LayoutHead>[];
  for (var i = 0; i < heads.length; i++) {
    final h = heads[i];
    final c = matchedPrecipitationNozzle(family, h.arcDeg, headM: headM, fullFlow: qFull, radius: rRef, minRadiusRatio: minRadiusRatio);
    if (c == null) {
      done.add(h);
      continue;
    }
    if ((c.ratio - 1).abs() > 0.15) msgs.add('layout_mp_mismatch:$i');
    if (rRef > 0 && c.radius < minRadiusRatio * rRef) msgs.add('layout_radius_short:$i');
    done.add(h.copyWith(nozzleId: c.nozzle.id, flow: c.flow, radius: c.radius, targetFlow: c.targetFlow));
  }
  return LandscapeLayout(
    region: region,
    outletSpecId: family.id,
    heads: done,
    headM: headM,
    referenceNozzleId: ref?.id,
    spacing: spacing,
    rowSpacing: rowSpacing,
    direction: direction,
    metrics: evaluate ? evaluateHeadLayout(region, done, profile: profile) : null,
    messages: msgs,
  );
}

/// Corner and edge heads of one boundary loop; a corner sharper than
/// [minCornerArc] gets no head of its own (no nozzle matches so small an
/// arc, and the first heads of its two edges water the tip).
List<_Head> _loopHeads(RegionLoop loop, double spacing, {required double cornerDeg, required double minGap, double minCornerArc = 0}) {
  final n = loop.vertexCount;
  final total = loop.length;
  if (n < 3 || total <= 0) return const [];
  final turns = [for (var i = 0; i < n; i++) loop.turnDeg(i)];
  final corners = [
    for (var i = 0; i < n; i++)
      if (turns[i].abs() >= cornerDeg) i,
  ];
  final out = <_Head>[];
  if (corners.isEmpty) {
    // a smooth loop (a round bed): heads evenly round it
    var start = 0;
    for (var i = 1; i < n; i++) {
      if (turns[i].abs() > turns[start].abs() + 1e-9) start = i;
    }
    final m = math.max(3, (total / spacing - 1e-9).ceil());
    final step = total / m;
    for (var j = 0; j < m; j++) {
      final s = loop.cum[start] + j * step;
      final (orient, arc) = loop.edgeSector(s, step / 2);
      out.add(_Head(loop.at(s), arc, orient, HeadRole.edge, s: s % total));
    }
    return out;
  }
  // corners closer than the minimum gap along the loop form one corner
  // (a chamfer, a rounded corner drawn with a few segments)
  // (a group spans less than the gap from its first corner)
  // (a group never turns through half a circle or more: the corners of an
  // area smaller than the gap stay apart, each opening into the area)
  final groups = <List<int>>[];
  double turnOf(Iterable<int> g) => g.fold(0.0, (s, i) => s + turns[i]);
  for (final c in corners) {
    if (groups.isNotEmpty && loop.cum[c] - loop.cum[groups.last.first] < minGap && (turnOf(groups.last) + turns[c]).abs() < 180 - 1e-9) {
      groups.last.add(c);
    } else {
      groups.add([c]);
    }
  }
  if (groups.length > 1 && total - loop.cum[groups.last.first] + loop.cum[groups.first.last] < minGap && (turnOf(groups.last) + turnOf(groups.first)).abs() < 180 - 1e-9) {
    groups.first.insertAll(0, groups.removeLast());
  }
  final positions = <double>[];
  for (final g in groups) {
    final first = g.first, last = g.last;
    var s0 = loop.cum[first], s1 = loop.cum[last];
    if (s1 < s0) s1 += total;
    final s = g.length == 1 ? s0 : (s0 + s1) / 2;
    // the sector between the edge leaving the group and the edge entering it
    final dOut = loop.vertex(last + 1) - loop.vertex(last), dBack = loop.vertex(first - 1) - loop.vertex(first);
    final arc = ccwAngleDeg(dOut, dBack);
    if (arc >= minCornerArc) out.add(_Head(loop.at(s), arc, radToDeg(dOut.angle), HeadRole.corner, s: s % total));
    positions.add(s % total);
  }
  // sides: heads evenly spread between consecutive corners
  for (var k = 0; k < positions.length; k++) {
    final s0 = positions[k];
    var s1 = positions[(k + 1) % positions.length];
    if (s1 <= s0 + 1e-9) s1 += total;
    final len = s1 - s0;
    final m = math.max(1, (len / spacing - 1e-9).ceil());
    final step = len / m;
    for (var j = 1; j < m; j++) {
      final s = s0 + j * step;
      final (orient, arc) = loop.edgeSector(s, step / 2);
      out.add(_Head(loop.at(s), arc, orient, HeadRole.edge, s: s % total));
    }
  }
  return out;
}

/// Adds a head wherever the area is farther than [reach] from every head,
/// the largest empty circle first: every raster cell near or beyond reach
/// climbs to the farthest point around it (a vertex of the Voronoi diagram
/// of the heads), and a head goes there when it is out of reach: inside the
/// area, or on the boundary as an edge head when [onBoundary] and the spot
/// is within [clearance] of it. Nothing goes in [inSoft] exclusions.
void _fillGaps(
  LayoutRegion region,
  _Raster raster,
  PointGrid grid, {
  required double spacing,
  required double reach,
  required double clearance,
  required double minGap,
  required bool onBoundary,
  required bool Function(Pt) inSoft,
  required void Function(_Head) addHead,
}) {
  if (!(reach > 0)) return;
  double far(Pt q) {
    final i = grid.nearest(q);
    return i < 0 ? double.infinity : q.distanceTo(grid.points[i]);
  }

  // candidates: cells that a coarse raster may show short of the real gap;
  // a max-heap of their distances (stale entries are skipped: distances
  // only shrink)
  final slack = 0.75 * raster.h;
  final floor = reach - slack;
  final centers = <Pt>[];
  final dist = <double>[];
  for (var k = 0; k < raster.mask.length; k++) {
    if (raster.mask[k] == 0) continue;
    final c = raster.center(k);
    if (grid.nearest(c, maxDistance: floor) >= 0) continue;
    centers.add(c);
    dist.add(far(c));
  }
  if (centers.isEmpty) return;
  final b = Bounds.ofPoints(centers);
  final index = PointGrid(math.max(raster.h, spacing / 2), origin: Pt(b.minX, b.minY));
  for (final c in centers) {
    index.add(c);
  }
  final heap = _MaxHeap();
  for (var c = 0; c < centers.length; c++) {
    heap.push(dist[c], c);
  }
  void settle(Pt p) {
    for (final c in index.within(p, 2 * raster.h)) {
      dist[c] = 0;
    }
  }

  final limit = math.max(16, (region.area / (spacing * spacing) * 0.5).ceil());
  var added = 0;
  while (added < limit && heap.isNotEmpty) {
    final (d0, bi) = heap.pop();
    if (d0 != dist[bi]) {
      if (dist[bi] > floor) heap.push(dist[bi], bi);
      continue;
    }
    if (d0 <= floor) break;
    // climb to the farthest point nearby
    var p = centers[bi];
    var d = d0;
    for (var step = raster.h; step > spacing * 0.005; step /= 2) {
      var improved = true;
      while (improved) {
        improved = false;
        for (final (dx, dy) in const [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0), (0.7071, 0.7071), (-0.7071, 0.7071), (0.7071, -0.7071), (-0.7071, -0.7071)]) {
          final q = Pt(p.x + dx * step, p.y + dy * step);
          if (!region.contains(q)) continue;
          final dq = far(q);
          if (dq > d + 1e-9) {
            p = q;
            d = dq;
            improved = true;
          }
        }
      }
    }
    dist[bi] = 0;
    if (d <= reach || inSoft(p)) {
      // within reach after all: the cells around that spot are settled
      settle(p);
      continue;
    }
    _Head h;
    if (onBoundary && region.distanceToBoundary(p, maxDistance: clearance) < clearance) {
      final (li, s, _) = region.nearestBoundary(p);
      final loop = region.loops[li];
      p = loop.at(s);
      final (orient, arc) = loop.edgeSector(s, spacing / 2);
      h = _Head(p, arc, orient, HeadRole.edge, loop: li, s: s);
    } else {
      h = _Head(p, 360, 0, HeadRole.interior, movable: true);
    }
    if (inSoft(p) || grid.nearest(p, maxDistance: minGap * 0.5) >= 0) {
      // the spot sits on a head already: nothing more can be done there
      settle(p);
      continue;
    }
    addHead(h);
    added++;
    // the cells the new head brings within reach (farther cells keep an
    // estimate that is too high: they climb, find the gap closed and settle)
    for (final c in index.within(p, 2 * spacing)) {
      final dc = centers[c].distanceTo(p);
      if (dc < dist[c]) dist[c] = dc;
    }
  }
}

/// Binary max-heap of (value, index), ties by the lower index.
class _MaxHeap {
  final List<(double, int)> _a = [];
  bool get isNotEmpty => _a.isNotEmpty;
  bool _more((double, int) x, (double, int) y) => x.$1 != y.$1 ? x.$1 > y.$1 : x.$2 < y.$2;

  void push(double v, int i) {
    _a.add((v, i));
    var k = _a.length - 1;
    while (k > 0) {
      final p = (k - 1) >> 1;
      if (!_more(_a[k], _a[p])) break;
      final t = _a[p];
      _a[p] = _a[k];
      _a[k] = t;
      k = p;
    }
  }

  (double, int) pop() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var k = 0;
      while (true) {
        final l = 2 * k + 1, r = l + 1;
        var m = k;
        if (l < _a.length && _more(_a[l], _a[m])) m = l;
        if (r < _a.length && _more(_a[r], _a[m])) m = r;
        if (m == k) break;
        final t = _a[m];
        _a[m] = _a[k];
        _a[k] = t;
        k = m;
      }
    }
    return top;
  }
}

/// One round of centroidal relaxation: every movable head goes to the
/// centroid of the raster cells nearest to it, when that keeps it inside
/// the area, [clearance] from the boundary and [minGap] from the other
/// heads. Returns whether any head moved.
bool _relax(LayoutRegion region, _Raster raster, List<_Head> heads, PointGrid grid, {required double clearance, required double minGap, required double spacing, required bool Function(Pt) inSoft}) {
  // heads deep inside a regular grid sit on their centroids already: only
  // those near the boundary or off the grid are worth the raster work
  final active = <int>[
    for (var i = 0; i < heads.length; i++)
      if (heads[i].movable && region.distanceToBoundary(heads[i].p, maxDistance: 1.6 * spacing) < 1.6 * spacing) i,
  ];
  if (active.isEmpty) return false;
  final isActive = Uint8List(heads.length);
  for (final i in active) {
    isActive[i] = 1;
  }
  final sx = Float64List(heads.length), sy = Float64List(heads.length), cnt = Float64List(heads.length);
  final seen = Uint8List(raster.mask.length);
  final reach = 1.2 * spacing, cellH = raster.h;
  for (final a in active) {
    final p = heads[a].p;
    final i0 = math.max(0, ((p.x - reach - raster.origin.x) / cellH).floor()), i1 = math.min(raster.nx - 1, ((p.x + reach - raster.origin.x) / cellH).floor());
    final j0 = math.max(0, ((p.y - reach - raster.origin.y) / cellH).floor()), j1 = math.min(raster.ny - 1, ((p.y + reach - raster.origin.y) / cellH).floor());
    for (var j = j0; j <= j1; j++) {
      for (var i = i0; i <= i1; i++) {
        final k = j * raster.nx + i;
        if (raster.mask[k] == 0 || seen[k] == 1) continue;
        seen[k] = 1;
        final c = raster.center(k);
        final n = grid.nearest(c, maxDistance: 2 * spacing);
        if (n < 0 || isActive[n] == 0) continue;
        sx[n] += c.x;
        sy[n] += c.y;
        cnt[n] += 1;
      }
    }
  }
  var moved = false;
  final jitter = 0.03 * spacing;
  for (final i in active) {
    final h = heads[i];
    if (cnt[i] == 0) continue;
    final target = Pt(sx[i] / cnt[i], sy[i] / cnt[i]);
    if (target.distanceTo(h.p) < jitter) continue;
    for (final w in const [1.0, 0.5]) {
      final q = h.p + (target - h.p) * w;
      if (!region.contains(q) || inSoft(q)) continue;
      if (region.distanceToBoundary(q, maxDistance: clearance) < clearance - 1e-9) continue;
      if (grid.nearest(q, maxDistance: minGap - 1e-9, skip: (j) => j == i) >= 0) continue;
      h.p = q;
      grid.move(i, q);
      moved = true;
      break;
    }
  }
  return moved;
}
