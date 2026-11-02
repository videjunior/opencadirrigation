/// Geometry edits of the drawing (CAD-26): join, explode, fillet, chamfer,
/// stretch, break at two points and the outline that becomes an area. Pure
/// functions over entities; the editor applies them as undo steps.
///
/// A fillet follows the simple circular curve of route surveying: two
/// sides meeting at an interior angle θ (deflection Δ = π − θ) take an arc
/// of radius R tangent to both at T = R·tan(Δ/2) from the corner, of
/// length L = R·Δ, its centre R / sin(θ/2) from the corner along the
/// bisector.
library;

import 'dart:math' as math;

import 'entities.dart';
import 'geometry.dart';
import 'split.dart';

// ---------------------------------------------------------------- join

/// What [e] can be joined with (null: it cannot): lines, open polylines
/// and arcs of the drawing together; pipes of the same scope, catalogue
/// item, sizing and depth; wires; contours of the same elevation;
/// breaklines.
String? joinFamily(Entity e) => switch (e) {
  LineEntity _ || ArcEntity _ => 'drawing',
  PolylineEntity p when !p.closed => 'drawing',
  PipeEntity p => 'pipe|${p.scope.name}|${p.pipeSpecId}|${p.computerSized}|${p.depth}',
  WireEntity _ => 'wire',
  ContourEntity c when !c.derived => 'contour|${c.elevation}',
  BreaklineEntity _ => 'breakline',
  _ => null,
};

/// The vertices of [e] as joining sees them (an arc sampled every 5°).
List<Pt> _joinPoints(Entity e) => switch (e) {
  LineEntity l => [l.a, l.b],
  ArcEntity a => a.polyline(72),
  PolyEntity p => List.of(p.points),
  _ => const [],
};

/// A chain of joined items: the vertices, the elevation of each (for
/// breaklines) and the members, the first one first.
class JoinChain {
  JoinChain(this.points, this.elevations, this.members);
  final List<Pt> points;
  final List<double> elevations;
  final List<Entity> members;

  /// The chain came back to its first point.
  bool closedWithin(double tol) => points.length > 3 && points.first.distanceTo(points.last) <= tol;
}

/// Chains [items] whose ends meet within [tol]: each chain grows from its
/// first member at both ends with the members of its family, turning them
/// around as needed. A joint where [blocked] is true (a valve on a pipe
/// joint) is never crossed. Items left alone make no chain.
List<JoinChain> joinChains(List<Entity> items, double tol, {bool Function(Pt joint)? blocked}) {
  final pending = [
    for (final e in items)
      if (joinFamily(e) != null && _joinPoints(e).length >= 2) e,
  ];
  final used = <String>{};
  final out = <JoinChain>[];
  List<double> zsOf(Entity e, int n) => e is BreaklineEntity ? [for (var i = 0; i < n; i++) e.elevationOf(i)] : List.filled(n, double.nan);
  for (final first in pending) {
    if (used.contains(first.id)) continue;
    final family = joinFamily(first);
    var pts = _joinPoints(first);
    var zs = zsOf(first, pts.length);
    final members = [first];
    used.add(first.id);
    var grown = true;
    while (grown) {
      grown = false;
      for (final e in pending) {
        if (used.contains(e.id) || joinFamily(e) != family) continue;
        final head = pts.first, tail = pts.last;
        // a chain back at its start is closed: nothing more joins it
        if (members.length >= 2 && head.distanceTo(tail) <= tol) break;
        var q = _joinPoints(e);
        var qz = zsOf(e, q.length);
        // a joint with a valve or another item on it is not crossed
        bool ok(Pt joint) => blocked == null || !blocked(joint);
        if (q.first.distanceTo(tail) <= tol && ok(tail)) {
          pts = [...pts, ...q.skip(1)];
          zs = [...zs, ...qz.skip(1)];
        } else if (q.last.distanceTo(tail) <= tol && ok(tail)) {
          q = q.reversed.toList();
          qz = qz.reversed.toList();
          pts = [...pts, ...q.skip(1)];
          zs = [...zs, ...qz.skip(1)];
        } else if (q.last.distanceTo(head) <= tol && ok(head)) {
          pts = [...q.take(q.length - 1), ...pts];
          zs = [...qz.take(qz.length - 1), ...zs];
        } else if (q.first.distanceTo(head) <= tol && ok(head)) {
          q = q.reversed.toList();
          qz = qz.reversed.toList();
          pts = [...q.take(q.length - 1), ...pts];
          zs = [...qz.take(qz.length - 1), ...zs];
        } else {
          continue;
        }
        members.add(e);
        used.add(e.id);
        grown = true;
      }
    }
    if (members.length >= 2) out.add(JoinChain(pts, zs, members));
  }
  return out;
}

/// The one item a chain becomes, with the id, layer and name of its first
/// member: a polyline of the drawing (closed when the chain came back to
/// its start), a pipe, a wire, a contour, a breakline.
Entity joinedEntity(JoinChain chain, double tol) {
  final first = chain.members.first;
  final pts = chain.points;
  switch (first) {
    case PipeEntity p:
      return PipeEntity(id: p.id, layer: p.layer, name: p.name, points: pts, scope: p.scope, pipeSpecId: p.pipeSpecId, computerSized: p.computerSized, depth: p.depth);
    case WireEntity w:
      return WireEntity(id: w.id, layer: w.layer, name: w.name, points: pts);
    case ContourEntity c:
      return ContourEntity(id: c.id, layer: c.layer, name: c.name, points: pts, elevation: c.elevation);
    case BreaklineEntity b:
      return BreaklineEntity(id: b.id, layer: b.layer, name: b.name, points: pts, elevations: chain.elevations);
    default:
      final closed = chain.closedWithin(tol);
      return PolylineEntity(id: first.id, layer: first.layer, name: first.name, points: closed ? pts.sublist(0, pts.length - 1) : pts, closed: closed);
  }
}

// ---------------------------------------------------------------- explode

/// The pieces [e] explodes into, or null when it does not: a polyline
/// into its lines (the closing one too), a hatch and a revision cloud into
/// their outline, a spline into a polyline along its curve, a leader into
/// its polyline and its text, a pipe, lateral, tape, contour, wire or
/// breakline into one item per segment (the outlets of a lateral stay
/// where they were). The first piece keeps the id of [e].
List<Entity>? explodeEntity(Entity e, String Function() newId) {
  String idAt(int i) => i == 0 ? e.id : newId();
  switch (e) {
    case PolylineEntity p:
      final pts = p.points;
      if (pts.length < 2 || (pts.length == 2 && !p.closed)) return null;
      final segs = [for (var i = 1; i < pts.length; i++) (pts[i - 1], pts[i]), if (p.closed && pts.length > 2) (pts.last, pts.first)];
      return [for (var i = 0; i < segs.length; i++) LineEntity(id: idAt(i), layer: p.layer, name: p.name, a: segs[i].$1, b: segs[i].$2)];
    case HatchEntity h:
      return h.points.length < 3 ? null : [PolylineEntity(id: h.id, layer: h.layer, name: h.name, points: List.of(h.points), closed: true)];
    case RevisionCloudEntity r:
      return r.points.length < 3 ? null : [PolylineEntity(id: r.id, layer: r.layer, name: r.name, points: List.of(r.points), closed: true)];
    case SplineEntity s:
      if (s.points.length < 2) return null;
      final curve = s.curve();
      final closed = s.closed && curve.length > 3;
      return [PolylineEntity(id: s.id, layer: s.layer, name: s.name, points: closed ? curve.sublist(0, curve.length - 1) : curve, closed: closed)];
    case LeaderEntity l:
      if (l.points.length < 2) return null;
      return [
        PolylineEntity(id: l.id, layer: l.layer, name: l.name, points: List.of(l.points)),
        if (l.text.isNotEmpty) TextEntity(id: newId(), layer: l.layer, position: l.points.last, text: l.text, height: l.height),
      ];
    case WireEntity w:
      if (w.points.length < 3) return null;
      return [
        for (var i = 1; i < w.points.length; i++) WireEntity(id: idAt(i - 1), layer: w.layer, name: w.name, points: [w.points[i - 1], w.points[i]]),
      ];
    case BreaklineEntity b:
      if (b.points.length < 3) return null;
      return [
        for (var i = 1; i < b.points.length; i++)
          BreaklineEntity(id: idAt(i - 1), layer: b.layer, name: b.name, points: [b.points[i - 1], b.points[i]], elevations: [b.elevationOf(i - 1), b.elevationOf(i)]),
      ];
    case PipeEntity _ || SpraylineEntity _ || TapeEntity _ || ContourEntity _:
      final pts = (e as PolyEntity).points;
      if (pts.length < 3) return null;
      final stations = <double>[];
      var acc = 0.0;
      for (var i = 1; i < pts.length - 1; i++) {
        acc += pts[i - 1].distanceTo(pts[i]);
        stations.add(acc);
      }
      final pieces = splitLinearEntity(e, stations, newId);
      return pieces.length < 2 ? null : pieces;
    default:
      return null;
  }
}

// ---------------------------------------------------------------- area outline

/// Sides of the polygon a circle becomes as an area.
const circleAreaSides = 64;

/// The outline [e] gives an area, or null: a closed polyline, a hatch, a
/// revision cloud, a closed spline (its curve), a circle (a polygon of
/// [circleAreaSides] sides), an open polyline whose ends meet within [tol].
List<Pt>? areaOutline(Entity e, {double tol = 1e-6}) {
  List<Pt>? ring(List<Pt> pts) {
    final p = List.of(pts);
    if (p.length > 3 && p.first.distanceTo(p.last) <= tol) p.removeLast();
    return p.length >= 3 && polygonArea(p).abs() > 1e-12 ? p : null;
  }

  return switch (e) {
    PolylineEntity p when p.closed => ring(p.points),
    PolylineEntity p when p.points.length > 3 && p.points.first.distanceTo(p.points.last) <= tol => ring(p.points),
    HatchEntity h => ring(h.points),
    RevisionCloudEntity r => ring(r.points),
    SplineEntity s when s.closed => ring(s.curve()),
    CircleEntity c when c.radius > 0 => [for (var i = 0; i < circleAreaSides; i++) c.center + Pt.polar(c.radius, 2 * math.pi * i / circleAreaSides)],
    _ => null,
  };
}

// ---------------------------------------------------------------- fillet and chamfer

/// The arc of a fillet: tangent points [ta] and [tb] on the two sides, the
/// corner [corner] where the sides meet, the centre, the radius and the
/// angles of the arc from [ta] to [tb] ([sweepRad] signed: positive
/// counter-clockwise).
class FilletArc {
  const FilletArc({required this.corner, required this.ta, required this.tb, required this.center, required this.radius, required this.startRad, required this.sweepRad});
  final Pt corner, ta, tb, center;
  final double radius, startRad, sweepRad;

  /// The arc from [ta] to [tb], a vertex at least every [maxStepRad].
  List<Pt> points({double maxStepRad = math.pi / 18}) {
    final n = math.max(2, (sweepRad.abs() / maxStepRad).ceil());
    return [ta, for (var k = 1; k < n; k++) center + Pt.polar(radius, startRad + sweepRad * k / n), tb];
  }
}

/// The fillet of radius [r] between the side from [corner] along [ua] and
/// the side along [ub] (unit vectors away from the corner, the sides that
/// are kept), or null when they are in line. [ta] and [tb] lie
/// r / tan(θ/2) from the corner, θ the angle between the sides.
FilletArc? filletBetween(Pt corner, Pt ua, Pt ub, double r) {
  final cosT = ua.dot(ub).clamp(-1.0, 1.0);
  final theta = math.acos(cosT);
  if (theta < 1e-6 || math.pi - theta < 1e-6 || r <= 0) return null;
  final t = r / math.tan(theta / 2);
  final ta = corner + ua * t, tb = corner + ub * t;
  final bis = (ua + ub).normalized;
  final center = corner + bis * (r / math.sin(theta / 2));
  final a1 = (ta - center).angle;
  final sweep = (math.pi - theta) * ((ta - center).cross(tb - center) >= 0 ? 1 : -1);
  return FilletArc(corner: corner, ta: ta, tb: tb, center: center, radius: r, startRad: a1, sweepRad: sweep);
}

/// The vertices of [pts] with the corner at vertex [i] rounded with
/// radius [r] (the vertex becomes the arc), or null when a side is too
/// short for the radius or the sides are in line. A closed outline wraps
/// around for its first and last vertex.
List<Pt>? filletVertex(List<Pt> pts, int i, double r, {bool closed = false}) {
  final n = pts.length;
  if (n < 3 || i < 0 || i >= n || (!closed && (i == 0 || i == n - 1))) return null;
  final v = pts[i], p = pts[(i - 1 + n) % n], q = pts[(i + 1) % n];
  final f = filletBetween(v, (p - v).normalized, (q - v).normalized, r);
  if (f == null) return null;
  final t = f.ta.distanceTo(v);
  if (t > p.distanceTo(v) + 1e-9 || t > q.distanceTo(v) + 1e-9) return null;
  final arc = f.points();
  // a tangent point on a neighbour vertex replaces it
  if (arc.first.distanceTo(p) < 1e-9) arc.removeAt(0);
  if (arc.last.distanceTo(q) < 1e-9) arc.removeLast();
  return [...pts.sublist(0, i), ...arc, ...pts.sublist(i + 1)];
}

/// The vertices of [pts] with the corner at vertex [i] cut [d1] along the
/// side towards the previous vertex and [d2] towards the next one, or null
/// when a side is shorter than its distance.
List<Pt>? chamferVertex(List<Pt> pts, int i, double d1, double d2, {bool closed = false}) {
  final n = pts.length;
  if (n < 3 || i < 0 || i >= n || (!closed && (i == 0 || i == n - 1)) || d1 <= 0 || d2 <= 0) return null;
  final v = pts[i], p = pts[(i - 1 + n) % n], q = pts[(i + 1) % n];
  if (d1 > p.distanceTo(v) + 1e-9 || d2 > q.distanceTo(v) + 1e-9) return null;
  final a = v + (p - v).normalized * d1, b = v + (q - v).normalized * d2;
  return [...pts.sublist(0, i), if (a.distanceTo(p) > 1e-9) a, if (b.distanceTo(q) > 1e-9) b, ...pts.sublist(i + 1)];
}

// ---------------------------------------------------------------- stretch

/// [e] with what lies inside the window [w] moved by [d], or null when
/// nothing of it does: an item wholly inside moves, the vertices of a line
/// or of a polyline-like item inside move and the others stay, a point
/// item, a circle, an arc or a pivot moves with its centre or position,
/// the points of a linear or an ordinate dimension move.
Entity? stretchEntity(Entity e, Bounds w, Pt d) {
  bool inside(Pt p) => w.contains(p);
  final b = e.bounds;
  if (!b.isEmpty && w.contains(Pt(b.minX, b.minY)) && w.contains(Pt(b.maxX, b.maxY))) return e.translated(d);
  switch (e) {
    case LineEntity l:
      if (!inside(l.a) && !inside(l.b)) return null;
      return LineEntity(id: l.id, layer: l.layer, name: l.name, a: inside(l.a) ? l.a + d : l.a, b: inside(l.b) ? l.b + d : l.b);
    case PolyEntity p:
      if (!p.points.any(inside)) return null;
      final c = e.clone() as PolyEntity;
      final pts = c.points;
      for (var i = 0; i < pts.length; i++) {
        if (inside(pts[i])) pts[i] = pts[i] + d;
      }
      return c as Entity;
    case PointEntity p:
      return inside(p.position) ? e.translated(d) : null;
    case CircleEntity c:
      return inside(c.center) ? e.translated(d) : null;
    case ArcEntity a:
      return inside(a.center) ? e.translated(d) : null;
    case PivotEntity p:
      return inside(p.center) ? e.translated(d) : null;
    case DimensionEntity m:
      if (!inside(m.a) && !inside(m.b)) return null;
      return DimensionEntity(id: m.id, layer: m.layer, name: m.name, a: inside(m.a) ? m.a + d : m.a, b: inside(m.b) ? m.b + d : m.b, offset: m.offset);
    case OrdinateDimensionEntity o:
      if (!inside(o.point) && !inside(o.leaderEnd)) return null;
      return OrdinateDimensionEntity(
        id: o.id,
        layer: o.layer,
        name: o.name,
        point: inside(o.point) ? o.point + d : o.point,
        leaderEnd: inside(o.leaderEnd) ? o.leaderEnd + d : o.leaderEnd,
        origin: o.origin,
        xAxis: o.xAxis,
      );
    default:
      return null;
  }
}

// ---------------------------------------------------------------- break

/// What remains of [e] when the part between the points of it nearest to
/// [a] and [b] is taken out, or null when it cannot be broken: two pieces
/// of an open item (one when a point is at an end, and two at one point
/// when [a] and [b] coincide), the rest of a closed polyline as an open
/// one (the part from [a] to [b] in the order of its vertices goes), an
/// arc of a circle (the part counter-clockwise from [a] to [b] goes), up
/// to two arcs of an arc. Areas, hatches and clouds stay whole.
List<Entity>? breakEntity(Entity e, Pt a, Pt b, String Function() newId) {
  switch (e) {
    case CircleEntity c:
      final ta = (a - c.center).angle, tb = (b - c.center).angle;
      var keep = (ta - tb) % (2 * math.pi);
      if (keep < 0) keep += 2 * math.pi;
      if (keep < 1e-9 || keep > 2 * math.pi - 1e-9) return null;
      return [ArcEntity(id: c.id, layer: c.layer, name: c.name, center: c.center, radius: c.radius, startRad: tb, sweepRad: keep)];
    case ArcEntity arc:
      double at(Pt p) {
        var rel = ((p - arc.center).angle - arc.startRad) * arc.sweepRad.sign % (2 * math.pi);
        if (rel < 0) rel += 2 * math.pi;
        return math.min(rel, arc.sweepRad.abs());
      }
      final s1 = math.min(at(a), at(b)), s2 = math.max(at(a), at(b));
      final dir = arc.sweepRad.sign;
      final out = <Entity>[
        if (s1 > 1e-9) ArcEntity(id: arc.id, layer: arc.layer, name: arc.name, center: arc.center, radius: arc.radius, startRad: arc.startRad, sweepRad: dir * s1),
        if (arc.sweepRad.abs() - s2 > 1e-9)
          ArcEntity(
            id: s1 > 1e-9 ? newId() : arc.id,
            layer: arc.layer,
            name: arc.name,
            center: arc.center,
            radius: arc.radius,
            startRad: arc.startRad + dir * s2,
            sweepRad: dir * (arc.sweepRad.abs() - s2),
          ),
      ];
      return out.isEmpty ? null : out;
    case AreaEntity _ || HatchEntity _ || RevisionCloudEntity _:
      return null;
    case PolylineEntity p when p.closed:
      final ring = [...p.points, p.points.first];
      final total = polylineLength(ring);
      final s1 = polylineStationOf(ring, a).$1, s2 = polylineStationOf(ring, b).$1;
      if ((s2 - s1).abs() < 1e-9) return null;
      // the rest runs from the second point on, round to the first
      final rest = _subPath([...ring, ...ring.skip(1)], s2, s1 < s2 ? s1 + total : s1);
      return rest.length < 2 ? null : [PolylineEntity(id: p.id, layer: p.layer, name: p.name, points: rest)];
    case WireEntity _ || BreaklineEntity _:
      final pts = (e as PolyEntity).points;
      final (s1, s2) = _sorted(polylineStationOf(pts, a).$1, polylineStationOf(pts, b).$1);
      final total = polylineLength(pts);
      final keep = [if (s1 > 1e-9) _subPath(pts, 0, s1), if (total - s2 > 1e-9) _subPath(pts, s2, total)];
      if (keep.isEmpty || (keep.length == 1 && polylineLength(keep.first) >= total - 1e-9)) return null;
      // a breakline keeps the surveyed elevation of the vertices it keeps
      double zAt(Pt q) {
        if (e is! BreaklineEntity) return double.nan;
        for (var i = 0; i < pts.length; i++) {
          if (pts[i].distanceTo(q) < 1e-9) return e.elevationOf(i);
        }
        return double.nan;
      }

      var k = 0;
      return [
        for (final piece in keep)
          if (e is WireEntity)
            WireEntity(id: k++ == 0 ? e.id : newId(), layer: e.layer, name: e.name, points: piece)
          else
            BreaklineEntity(id: k++ == 0 ? e.id : newId(), layer: e.layer, name: e.name, points: piece, elevations: [for (final q in piece) zAt(q)]),
      ];
    default:
      final pts = e.linearPoints;
      if (pts == null || pts.length < 2) return null;
      final (s1, s2) = _sorted(polylineStationOf(pts, a).$1, polylineStationOf(pts, b).$1);
      final pieces = splitLinearEntity(e, [s1, s2], newId);
      if (s2 - s1 < 1e-9) return pieces.length < 2 ? null : pieces;
      final out = <Entity>[];
      var start = 0.0;
      for (final piece in pieces) {
        final len = polylineLength(piece.linearPoints!);
        final mid = start + len / 2;
        if (!(mid > s1 && mid < s2)) out.add(piece);
        start += len;
      }
      // nothing taken out, or all of it (a delete, not a break)
      if (out.isEmpty || (out.length == 1 && identical(out.first, e))) return null;
      return out;
  }
}

(double, double) _sorted(double a, double b) => a <= b ? (a, b) : (b, a);

/// The part of the polyline [pts] from station [from] to station [to].
List<Pt> _subPath(List<Pt> pts, double from, double to) {
  final out = <Pt>[pointAlongPolyline(pts, from)];
  var acc = 0.0;
  for (var i = 1; i < pts.length; i++) {
    acc += pts[i - 1].distanceTo(pts[i]);
    if (acc > from + 1e-9 && acc < to - 1e-9) out.add(pts[i]);
  }
  final end = pointAlongPolyline(pts, to);
  if (end.distanceTo(out.last) > 1e-12) out.add(end);
  return out;
}
