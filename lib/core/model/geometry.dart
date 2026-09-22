/// 2D geometry primitives (world coordinates in metres).
library;

import 'dart:math' as math;

class Pt {
  const Pt(this.x, this.y);
  final double x;
  final double y;

  static const zero = Pt(0, 0);

  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator *(double s) => Pt(x * s, y * s);
  Pt operator /(double s) => Pt(x / s, y / s);
  Pt operator -() => Pt(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double get angle => math.atan2(y, x);
  Pt get normalized {
    final l = length;
    return l == 0 ? zero : Pt(x / l, y / l);
  }

  Pt get perpendicular => Pt(-y, x);
  double dot(Pt o) => x * o.x + y * o.y;
  double cross(Pt o) => x * o.y - y * o.x;
  double distanceTo(Pt o) => (this - o).length;
  Pt rotate(double rad) {
    final c = math.cos(rad), s = math.sin(rad);
    return Pt(x * c - y * s, x * s + y * c);
  }

  static Pt lerp(Pt a, Pt b, double t) => Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  static Pt polar(double radius, double angle) => Pt(radius * math.cos(angle), radius * math.sin(angle));

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  static Pt fromJson(Map<String, dynamic> j) => Pt((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
  List<double> toList() => [x, y];
  static Pt fromList(List<dynamic> l) => Pt((l[0] as num).toDouble(), (l[1] as num).toDouble());

  @override
  bool operator ==(Object other) => other is Pt && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'Pt(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

class Bounds {
  const Bounds(this.minX, this.minY, this.maxX, this.maxY);
  final double minX, minY, maxX, maxY;

  static const empty = Bounds(double.infinity, double.infinity, -double.infinity, -double.infinity);
  bool get isEmpty => minX > maxX || minY > maxY;
  double get width => maxX - minX;
  double get height => maxY - minY;
  Pt get center => Pt((minX + maxX) / 2, (minY + maxY) / 2);

  Bounds include(Pt p) => Bounds(math.min(minX, p.x), math.min(minY, p.y), math.max(maxX, p.x), math.max(maxY, p.y));
  Bounds union(Bounds b) => b.isEmpty ? this : (isEmpty ? b : Bounds(math.min(minX, b.minX), math.min(minY, b.minY), math.max(maxX, b.maxX), math.max(maxY, b.maxY)));
  Bounds inflate(double d) => Bounds(minX - d, minY - d, maxX + d, maxY + d);
  bool contains(Pt p) => p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;
  bool intersects(Bounds b) => !(b.minX > maxX || b.maxX < minX || b.minY > maxY || b.maxY < minY);

  static Bounds ofPoints(Iterable<Pt> pts) {
    var b = empty;
    for (final p in pts) {
      b = b.include(p);
    }
    return b;
  }
}

/// Closest point on segment ab to p, with the parameter t in [0,1].
(Pt, double) closestPointOnSegment(Pt p, Pt a, Pt b) {
  final ab = b - a;
  final l2 = ab.dot(ab);
  if (l2 == 0) return (a, 0);
  var t = (p - a).dot(ab) / l2;
  t = t.clamp(0.0, 1.0);
  return (a + ab * t, t);
}

double distanceToSegment(Pt p, Pt a, Pt b) => p.distanceTo(closestPointOnSegment(p, a, b).$1);

/// Intersection of segments ab and cd (proper, not touching at ends), or null.
Pt? segmentIntersection(Pt a, Pt b, Pt c, Pt d, {double eps = 1e-9}) {
  final r = b - a, s = d - c;
  final denom = r.cross(s);
  if (denom.abs() < eps) return null;
  final qp = c - a;
  final t = qp.cross(s) / denom;
  final u = qp.cross(r) / denom;
  if (t < -eps || t > 1 + eps || u < -eps || u > 1 + eps) return null;
  return a + r * t;
}

double polylineLength(List<Pt> pts) {
  var l = 0.0;
  for (var i = 1; i < pts.length; i++) {
    l += pts[i - 1].distanceTo(pts[i]);
  }
  return l;
}

/// Signed area (positive when counter-clockwise).
double polygonArea(List<Pt> pts) {
  if (pts.length < 3) return 0;
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.cross(q);
  }
  return a / 2;
}

Pt polygonCentroid(List<Pt> pts) {
  if (pts.isEmpty) return Pt.zero;
  final a = polygonArea(pts);
  if (a.abs() < 1e-12) {
    var s = Pt.zero;
    for (final p in pts) {
      s = s + p;
    }
    return s / pts.length.toDouble();
  }
  var cx = 0.0, cy = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    final f = p.cross(q);
    cx += (p.x + q.x) * f;
    cy += (p.y + q.y) * f;
  }
  return Pt(cx / (6 * a), cy / (6 * a));
}

bool pointInPolygon(Pt p, List<Pt> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i], pj = poly[j];
    if ((pi.y > p.y) != (pj.y > p.y) && p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// Point along a polyline at a given distance from its start.
Pt pointAlongPolyline(List<Pt> pts, double distance) {
  if (pts.isEmpty) return Pt.zero;
  var d = distance;
  for (var i = 1; i < pts.length; i++) {
    final seg = pts[i - 1].distanceTo(pts[i]);
    if (d <= seg || i == pts.length - 1) {
      final t = seg == 0 ? 0.0 : (d / seg).clamp(0.0, 1.0);
      return Pt.lerp(pts[i - 1], pts[i], t);
    }
    d -= seg;
  }
  return pts.last;
}

/// Returns the pieces of a polyline split at the given distances (sorted).
List<List<Pt>> splitPolylineAt(List<Pt> pts, List<double> distances) {
  final ds = distances.where((d) => d > 1e-9 && d < polylineLength(pts) - 1e-9).toList()..sort();
  if (ds.isEmpty) return [List.of(pts)];
  final pieces = <List<Pt>>[];
  var current = <Pt>[pts.first];
  var acc = 0.0;
  var di = 0;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final seg = a.distanceTo(b);
    while (di < ds.length && ds[di] <= acc + seg + 1e-12) {
      final t = seg == 0 ? 0.0 : (ds[di] - acc) / seg;
      final p = Pt.lerp(a, b, t);
      current.add(p);
      pieces.add(current);
      current = [p];
      di++;
    }
    current.add(b);
    acc += seg;
  }
  pieces.add(current);
  return pieces.where((p) => polylineLength(p) > 1e-9).toList();
}

/// Offsets a polyline laterally by [d] (positive = left of direction).
List<Pt> offsetPolyline(List<Pt> pts, double d) {
  if (pts.length < 2) return List.of(pts);
  final out = <Pt>[];
  for (var i = 0; i < pts.length; i++) {
    final prev = i > 0 ? pts[i - 1] : null;
    final next = i < pts.length - 1 ? pts[i + 1] : null;
    Pt n;
    if (prev == null) {
      n = (next! - pts[i]).normalized.perpendicular;
    } else if (next == null) {
      n = (pts[i] - prev).normalized.perpendicular;
    } else {
      final n1 = (pts[i] - prev).normalized.perpendicular;
      final n2 = (next - pts[i]).normalized.perpendicular;
      n = (n1 + n2).normalized;
      final cosHalf = n.dot(n1);
      if (cosHalf.abs() > 1e-6) n = n / cosHalf;
    }
    out.add(pts[i] + n * d);
  }
  return out;
}

double degToRad(double d) => d * math.pi / 180;
double radToDeg(double r) => r * 180 / math.pi;

// ---------------------------------------------------------------- affine transforms

/// 2D affine transform: x' = a·x + c·y + e, y' = b·x + d·y + f.
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  final double a, b, c, d, e, f;

  static const identity = Affine(1, 0, 0, 1, 0, 0);

  static Affine translation(Pt t) => Affine(1, 0, 0, 1, t.x, t.y);

  /// Rotation by [rad] (counter-clockwise) about [center].
  static Affine rotation(double rad, [Pt center = Pt.zero]) {
    final cs = math.cos(rad), sn = math.sin(rad);
    return Affine(cs, sn, -sn, cs, center.x - cs * center.x + sn * center.y, center.y - sn * center.x - cs * center.y);
  }

  /// Uniform scale by [s] about [center].
  static Affine scaling(double s, [Pt center = Pt.zero]) => Affine(s, 0, 0, s, center.x * (1 - s), center.y * (1 - s));

  /// Reflection about the line through [p1] and [p2].
  static Affine mirror(Pt p1, Pt p2) {
    final dir = (p2 - p1).normalized;
    if (dir.length == 0) return identity;
    final cs = dir.x * dir.x - dir.y * dir.y;
    final sn = 2 * dir.x * dir.y;
    // reflect about the line through the origin, conjugated by translation
    final a = cs, b = sn, c = sn, d = -cs;
    return Affine(a, b, c, d, p1.x - a * p1.x - c * p1.y, p1.y - b * p1.x - d * p1.y);
  }

  Pt apply(Pt p) => Pt(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Transforms a direction vector (no translation).
  Pt applyVector(Pt v) => Pt(a * v.x + c * v.y, b * v.x + d * v.y);

  /// This transform followed by [o].
  Affine then(Affine o) => Affine(
    o.a * a + o.c * b,
    o.b * a + o.d * b,
    o.a * c + o.c * d,
    o.b * c + o.d * d,
    o.a * e + o.c * f + o.e,
    o.b * e + o.d * f + o.f,
  );

  double get determinant => a * d - b * c;
  bool get isMirror => determinant < 0;

  /// Uniform scale factor (assumes similarity transform).
  double get scale => math.sqrt(determinant.abs());

  /// Angle (radians) of a transformed direction that was at [rad].
  double transformAngle(double rad) => applyVector(Pt.polar(1, rad)).angle;

  bool get isIdentity => a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;
}

// ---------------------------------------------------------------- misc helpers

/// Intersection of the infinite lines through ab and cd; null when parallel.
Pt? lineIntersection(Pt a, Pt b, Pt c, Pt d, {double eps = 1e-12}) {
  final r = b - a, s = d - c;
  final denom = r.cross(s);
  if (denom.abs() < eps) return null;
  final t = (c - a).cross(s) / denom;
  return a + r * t;
}

/// Distance along the polyline of the point closest to [p], and that point.
(double, Pt) polylineStationOf(List<Pt> pts, Pt p) {
  var acc = 0.0, best = double.infinity, bestD = 0.0;
  var bestP = pts.isEmpty ? Pt.zero : pts.first;
  for (var i = 1; i < pts.length; i++) {
    final (cp, t) = closestPointOnSegment(p, pts[i - 1], pts[i]);
    final d = cp.distanceTo(p);
    final seg = pts[i - 1].distanceTo(pts[i]);
    if (d < best) {
      best = d;
      bestD = acc + t * seg;
      bestP = cp;
    }
    acc += seg;
  }
  return (bestD, bestP);
}

/// Circle through three points: (center, radius) or null when collinear.
(Pt, double)? circleThrough(Pt p1, Pt p2, Pt p3) {
  final ax = p1.x, ay = p1.y, bx = p2.x, by = p2.y, cx = p3.x, cy = p3.y;
  final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
  if (d.abs() < 1e-12) return null;
  final ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d;
  final uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d;
  final c = Pt(ux, uy);
  return (c, c.distanceTo(p1));
}

/// Arc through three points as (center, radius, startRad, sweepRad); the arc
/// runs from p1 through p2 to p3.
(Pt, double, double, double)? arcThrough(Pt p1, Pt p2, Pt p3) {
  final c = circleThrough(p1, p2, p3);
  if (c == null) return null;
  final (center, r) = c;
  final a1 = (p1 - center).angle, a2 = (p2 - center).angle, a3 = (p3 - center).angle;
  double norm(double a) {
    var v = a % (2 * math.pi);
    if (v < 0) v += 2 * math.pi;
    return v;
  }

  final ccwTo2 = norm(a2 - a1), ccwTo3 = norm(a3 - a1);
  // counter-clockwise if p2 comes before p3 going ccw from p1
  final sweep = ccwTo2 < ccwTo3 ? ccwTo3 : ccwTo3 - 2 * math.pi;
  return (center, r, a1, sweep);
}

/// Catmull-Rom spline through [pts] (centripetal, alpha 0.5), [segments]
/// samples per span; closed splines wrap around.
List<Pt> catmullRom(List<Pt> pts, {bool closed = false, int segments = 8}) {
  if (pts.length < 2) return List.of(pts);
  if (pts.length == 2) return [pts[0], pts[1]];
  final n = pts.length;
  // open curves: phantom points mirrored beyond the ends (repeating the end
  // point would make the first and last spans degenerate, i.e. straight)
  Pt at(int i) {
    if (closed) return pts[(i % n + n) % n];
    if (i < 0) return pts[0] * 2 - pts[1];
    if (i >= n) return pts[n - 1] * 2 - pts[n - 2];
    return pts[i];
  }
  final out = <Pt>[];
  final spans = closed ? n : n - 1;
  for (var i = 0; i < spans; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    double tj(double ti, Pt a, Pt b) => ti + math.pow(a.distanceTo(b), 0.5).toDouble();
    final t0 = 0.0, t1 = tj(t0, p0, p1), t2 = tj(t1, p1, p2), t3 = tj(t2, p2, p3);
    if (t1 - t0 < 1e-9 || t2 - t1 < 1e-9 || t3 - t2 < 1e-9) {
      out.add(p1);
      continue;
    }
    for (var s = 0; s < segments; s++) {
      final t = t1 + (t2 - t1) * s / segments;
      final a1 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0));
      final a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1));
      final a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2));
      final b1 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0));
      final b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1));
      out.add(b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1)));
    }
  }
  out.add(closed ? pts.first : pts.last);
  return out;
}

/// Segments of the family of parallel lines (angle [angleRad], spacing
/// [spacing]) clipped to the polygon (even-odd rule). Used by hatches.
List<List<Pt>> hatchLines(List<Pt> poly, double angleRad, double spacing) {
  if (poly.length < 3 || spacing <= 0) return const [];
  final dir = Pt.polar(1, angleRad);
  final perp = dir.perpendicular;
  var vMin = double.infinity, vMax = -double.infinity;
  for (final p in poly) {
    final v = p.dot(perp);
    vMin = math.min(vMin, v);
    vMax = math.max(vMax, v);
  }
  final out = <List<Pt>>[];
  final count = ((vMax - vMin) / spacing).floor();
  if (count > 20000) return const [];
  for (var v = (vMin / spacing).ceil() * spacing; v <= vMax; v += spacing) {
    final origin = perp * v;
    final ts = <double>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final e = b - a;
      final denom = dir.cross(e);
      if (denom.abs() < 1e-12) continue;
      final ao = a - origin;
      final t = ao.cross(e) / denom;
      final u = ao.cross(dir) / denom;
      if (u >= 0 && u < 1) ts.add(t);
    }
    ts.sort();
    for (var i = 0; i + 1 < ts.length; i += 2) {
      if (ts[i + 1] - ts[i] > 1e-9) out.add([origin + dir * ts[i], origin + dir * ts[i + 1]]);
    }
  }
  return out;
}

/// All intersection points between two polylines (open unless [closedA]/[closedB]).
List<Pt> polylineIntersections(List<Pt> a, List<Pt> b, {bool closedA = false, bool closedB = false}) {
  final out = <Pt>[];
  List<(Pt, Pt)> segs(List<Pt> pts, bool closed) => [
    for (var i = 1; i < pts.length; i++) (pts[i - 1], pts[i]),
    if (closed && pts.length > 2) (pts.last, pts.first),
  ];
  for (final (a1, a2) in segs(a, closedA)) {
    for (final (b1, b2) in segs(b, closedB)) {
      final p = segmentIntersection(a1, a2, b1, b2);
      if (p != null) out.add(p);
    }
  }
  return out;
}

// ---------------------------------------------------------------- alignment and clipping

/// Similarity transform (uniform scale + rotation + translation) that maps
/// [srcA]→[dstA] and [srcB]→[dstB]: the "align by two reference points"
/// operation used to register a scanned map or an image on the drawing.
/// Returns null when the source points coincide.
Affine? similarityFromPairs(Pt srcA, Pt srcB, Pt dstA, Pt dstB, {bool keepScale = false}) {
  final s = srcB - srcA, d = dstB - dstA;
  if (s.length < 1e-12 || d.length < 1e-12) return null;
  final k = keepScale ? 1.0 : d.length / s.length;
  final rot = d.angle - s.angle;
  final cs = math.cos(rot) * k, sn = math.sin(rot) * k;
  // p' = R·k·(p - srcA) + dstA
  final e = dstA.x - (cs * srcA.x - sn * srcA.y);
  final f = dstA.y - (sn * srcA.x + cs * srcA.y);
  return Affine(cs, sn, -sn, cs, e, f);
}

/// Pieces of the polyline that lie inside the polygon (segments are cut at
/// the polygon boundary; pieces shorter than [minLength] are dropped).
List<List<Pt>> clipPolylineToPolygon(List<Pt> pts, List<Pt> poly, {double minLength = 1e-6}) {
  if (pts.length < 2 || poly.length < 3) return const [];
  final out = <List<Pt>>[];
  var cur = <Pt>[];
  void flush() {
    if (cur.length >= 2 && polylineLength(cur) >= minLength) out.add(cur);
    cur = <Pt>[];
  }

  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    // parameters where the segment crosses the polygon boundary
    final ts = <double>[0, 1];
    for (var k = 0; k < poly.length; k++) {
      final c = poly[k], d = poly[(k + 1) % poly.length];
      final r = b - a, s = d - c;
      final denom = r.cross(s);
      if (denom.abs() < 1e-12) continue;
      final t = (c - a).cross(s) / denom;
      final u = (c - a).cross(r) / denom;
      if (t > 1e-9 && t < 1 - 1e-9 && u >= -1e-9 && u <= 1 + 1e-9) ts.add(t);
    }
    ts.sort();
    for (var k = 0; k + 1 < ts.length; k++) {
      if (ts[k + 1] - ts[k] < 1e-9) continue;
      final p0 = Pt.lerp(a, b, ts[k]), p1 = Pt.lerp(a, b, ts[k + 1]);
      final inside = pointInPolygon(Pt.lerp(p0, p1, 0.5), poly);
      if (inside) {
        if (cur.isEmpty || cur.last.distanceTo(p0) > 1e-9) {
          flush();
          cur = [p0];
        }
        cur.add(p1);
      } else {
        flush();
      }
    }
  }
  flush();
  return out;
}
