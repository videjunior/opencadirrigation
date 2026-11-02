import 'dart:math' as math;

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../state/controller.dart';

class SnapResult {
  const SnapResult(this.point, this.kind, {this.entityId, this.locked = false});
  final Pt point;

  /// The Shift angle lock shaped this point (an object snap may still have won).
  final bool locked;

  /// endpoint | midpoint | node | center | quadrant | intersection |
  /// perpendicular | tangent | extension | on | polar | ortho | 45° | grid |
  /// none
  final String kind;
  final String? entityId;
  bool get isSnapped => kind != 'none';
}

class Snapper {
  Snapper(this.c);
  final ProjectController c;

  /// [angleLock] (Shift held) constrains the point to the 45° directions
  /// from [reference]; ortho mode constrains it to 0°/90°. Object snaps
  /// near the constrained point still win.
  SnapResult snap(Pt raw, {Pt? reference, bool ignoreSelection = false, bool angleLock = false}) {
    final s = c.snap;
    Pt p = raw;
    var lockKind = 'none';
    if (reference != null && (angleLock || s.ortho)) {
      p = lockAngle(raw, reference, angleLock ? 45 : 90);
      lockKind = angleLock ? '45°' : 'ortho';
    } else if (reference != null && s.polarStepDeg > 0) {
      // polar tracking: the cursor is pulled onto the nearest multiple of
      // the step when it is within a few degrees of it
      final d = raw - reference;
      if (d.length > 1e-9) {
        final step = s.polarStepDeg * math.pi / 180;
        final a = math.atan2(d.y, d.x);
        if ((a - (a / step).round() * step).abs() <= polarCaptureDeg * math.pi / 180) {
          p = lockAngle(raw, reference, s.polarStepDeg);
          lockKind = 'polar';
        }
      }
    }
    final locked = angleLock && reference != null;
    // 1.6.0 CAD: a snap chosen for the next point works with the snap off
    if (!s.enabled && s.once == null) return SnapResult(p, lockKind, locked: locked);
    final tol = s.tolerancePx / c.camera.scale;
    SnapResult? best;
    var bestScore = double.infinity;
    void consider(Pt q, String kind, double priority, String? id) {
      // 1.6.0 CAD: only the snaps that are on (the pipes' "on" is "nearest")
      if (!s.allows(kind == 'on' ? 'nearest' : kind)) return;
      final d = q.distanceTo(p);
      if (d > tol) return;
      final score = d * priority;
      if (score < bestScore) {
        bestScore = score;
        best = SnapResult(q, kind, entityId: id, locked: locked);
      }
    }

    // nearest point on drawing geometry (circles, arcs, closed outlines):
    // used only when no other snap is in reach, so that intersections,
    // tangents and quadrants on them win (pipes keep their weighted "on")
    SnapResult? nearest;
    var nearestD = double.infinity;
    void considerNearest(Pt q, String? id) {
      if (!s.allows('nearest')) return;
      final d = q.distanceTo(p);
      if (d > tol || d >= nearestD) return;
      nearestD = d;
      nearest = SnapResult(q, 'on', entityId: id, locked: locked);
    }

    // straight segments and circles (arcs with their sweep) within reach,
    // for the intersection, perpendicular and tangent snaps
    final segs = <(Pt, Pt, String)>[];
    final rings = <(Pt, double, double, double, String)>[]; // centre, radius, start, sweep (2π for circles)
    // only the entities within reach of the cursor (spatial index), and of
    // a long polyline only the vertices and segments within reach: every
    // snap point lies within the tolerance, so a segment that does not come
    // near the cursor gives none (and pairing all the segments of long
    // contours for their crossings took seconds)
    final win = Bounds(p.x - tol, p.y - tol, p.x + tol, p.y + tol);
    bool near(Pt a, Pt b) => !(math.max(a.x, b.x) < win.minX || math.min(a.x, b.x) > win.maxX || math.max(a.y, b.y) < win.minY || math.min(a.y, b.y) > win.maxY);
    for (final e0 in c.entitiesIn(win)) {
      if (ignoreSelection && c.selection.contains(e0.id)) continue;
      // 1.6.0 CAD: a block reference snaps on the items it draws
      for (final e in e0 is BlockRefEntity ? e0.expanded() : [e0]) {
      switch (e) {
        case PointEntity pe when e is! TextEntity:
          consider(pe.position, 'node', 0.4, e.id);
        case LineEntity l:
          consider(l.a, 'endpoint', 0.5, e.id);
          consider(l.b, 'endpoint', 0.5, e.id);
          consider(Pt.lerp(l.a, l.b, 0.5), 'midpoint', 0.8, e.id);
          segs.add((l.a, l.b, e.id));
        case PolyEntity pl:
          final pts = pl.points;
          final straight = e is! SplineEntity;
          final hydraulic = e is PipeEntity || e is SpraylineEntity || e is TapeEntity;
          for (var i = 0; i < pts.length; i++) {
            if (win.contains(pts[i])) consider(pts[i], 'endpoint', 0.5, e.id);
            if (i > 0 && near(pts[i - 1], pts[i])) {
              consider(Pt.lerp(pts[i - 1], pts[i], 0.5), 'midpoint', 0.8, e.id);
              if (straight) segs.add((pts[i - 1], pts[i], e.id));
              if (hydraulic) {
                final (cp, _) = closestPointOnSegment(p, pts[i - 1], pts[i]);
                consider(cp, 'on', 1.0, e.id);
              }
            }
          }
          if (e is PolylineEntity && e.closed && pts.length > 2) {
            final (cp, _) = closestPointOnSegment(p, pts.last, pts.first);
            considerNearest(cp, e.id);
          }
          if (((e is PolylineEntity && e.closed) || e is AreaEntity || e is HatchEntity) && pts.length > 2 && near(pts.last, pts.first)) segs.add((pts.last, pts.first, e.id));
        case CircleEntity ci:
          consider(ci.center, 'center', 0.6, e.id);
          for (var q = 0; q < 4; q++) {
            consider(ci.center + Pt.polar(ci.radius, q * math.pi / 2), 'quadrant', 0.55, e.id);
          }
          final dir = (p - ci.center).normalized;
          considerNearest(ci.center + dir * ci.radius, e.id);
          rings.add((ci.center, ci.radius, 0, 2 * math.pi, e.id));
        case ArcEntity ar:
          consider(ar.startPoint, 'endpoint', 0.5, e.id);
          consider(ar.endPoint, 'endpoint', 0.5, e.id);
          consider(ar.midPoint, 'midpoint', 0.8, e.id);
          consider(ar.center, 'center', 0.6, e.id);
          for (var q = 0; q < 4; q++) {
            final a = q * math.pi / 2;
            if (_onArc(a, ar.startRad, ar.sweepRad)) consider(ar.center + Pt.polar(ar.radius, a), 'quadrant', 0.55, e.id);
          }
          final a = (p - ar.center).angle;
          if (_onArc(a, ar.startRad, ar.sweepRad)) considerNearest(ar.center + Pt.polar(ar.radius, a), e.id);
          rings.add((ar.center, ar.radius, ar.startRad, ar.sweepRad, e.id));
        default:
          break;
      }
      }
    }
    // intersections of what passes near the cursor
    for (var i = 0; i < segs.length; i++) {
      final (a, b, ida) = segs[i];
      for (var j = i + 1; j < segs.length; j++) {
        final (c2, d2, idb) = segs[j];
        // consecutive segments of one polyline meet at their vertex already
        if (ida == idb && (a == c2 || a == d2 || b == c2 || b == d2)) continue;
        final x = segmentIntersection(a, b, c2, d2);
        if (x != null) consider(x, 'intersection', 0.45, ida);
      }
      for (final r in rings) {
        for (final x in _segmentCircle(a, b, r.$1, r.$2)) {
          if (_onArc((x - r.$1).angle, r.$3, r.$4)) consider(x, 'intersection', 0.45, ida);
        }
      }
    }
    for (var i = 0; i < rings.length; i++) {
      for (var j = i + 1; j < rings.length; j++) {
        for (final x in _circleCircle(rings[i].$1, rings[i].$2, rings[j].$1, rings[j].$2)) {
          if (_onArc((x - rings[i].$1).angle, rings[i].$3, rings[i].$4) && _onArc((x - rings[j].$1).angle, rings[j].$3, rings[j].$4)) consider(x, 'intersection', 0.45, rings[i].$5);
        }
      }
    }
    if (reference != null) {
      // perpendicular from the previous point to a segment, tangent to a
      // circle or arc
      for (final (a, b, id) in segs) {
        final ab = b - a;
        final len2 = ab.dot(ab);
        if (len2 < 1e-18) continue;
        final t = (reference - a).dot(ab) / len2;
        if (t > 1e-9 && t < 1 - 1e-9) consider(a + ab * t, 'perpendicular', 0.7, id);
      }
      for (final (center, r, start, sweep, id) in rings) {
        final d = reference.distanceTo(center);
        if (d <= r + 1e-9) continue;
        final base = (reference - center).angle, alpha = math.acos(r / d);
        for (final a in [base + alpha, base - alpha]) {
          if (_onArc(a, start, sweep)) consider(center + Pt.polar(r, a), 'tangent', 0.7, id);
        }
      }
    }
    if (best != null) return best!;
    if (nearest != null) return nearest!;
    // extension of a straight segment beyond its end (looked up in a wider
    // window: the segment itself may be far from the cursor)
    final reach = tol * 25;
    SnapResult? ext;
    var extScore = double.infinity;
    for (final e in s.allows('extension') ? c.entitiesIn(Bounds(p.x - reach, p.y - reach, p.x + reach, p.y + reach)) : const <Entity>[]) {
      if (ignoreSelection && c.selection.contains(e.id)) continue;
      final pts = switch (e) {
        LineEntity l => [l.a, l.b],
        PolyEntity pl when e is! SplineEntity && e is! AreaEntity && e is! HatchEntity && !(e is PolylineEntity && e.closed) => pl.points,
        _ => const <Pt>[],
      };
      if (pts.length < 2) continue;
      for (final (from, end) in [(pts[1], pts[0]), (pts[pts.length - 2], pts.last)]) {
        final dir = (end - from).normalized;
        if (dir.length < 0.5) continue;
        final along = (p - end).dot(dir);
        if (along <= tol || along > reach) continue;
        final q = end + dir * along;
        final off = q.distanceTo(p);
        if (off <= tol && off < extScore) {
          extScore = off;
          ext = SnapResult(q, 'extension', entityId: e.id, locked: locked);
        }
      }
    }
    if (ext != null) return ext;
    if (s.grid && s.gridSize > 0 && s.once == null) {
      final g = s.gridSize;
      final q = Pt((p.x / g).round() * g, (p.y / g).round() * g);
      if (q.distanceTo(p) <= tol * 1.5) return SnapResult(q, 'grid', locked: locked);
    }
    return SnapResult(p, lockKind, locked: locked);
  }

  double get tolerance => c.snap.tolerancePx / math.max(c.camera.scale, 1e-9);

  /// Whether the direction [a] (radians) lies on the arc that starts at
  /// [start] and sweeps [sweep] (either sense; 2π or more is a full circle).
  static bool _onArc(double a, double start, double sweep) {
    if (sweep.abs() >= 2 * math.pi - 1e-9) return true;
    const two = 2 * math.pi;
    final lo = sweep >= 0 ? start : start + sweep;
    final rel = ((a - lo) % two + two) % two;
    return rel <= sweep.abs() + 1e-9;
  }

  /// Points where segment [a]–[b] crosses the circle of [center] and [r].
  static List<Pt> _segmentCircle(Pt a, Pt b, Pt center, double r) {
    final d = b - a, f = a - center;
    final qa = d.dot(d), qb = 2 * f.dot(d), qc = f.dot(f) - r * r;
    final disc = qb * qb - 4 * qa * qc;
    if (qa < 1e-18 || disc < 0) return const [];
    final sq = math.sqrt(disc);
    return [
      for (final t in {(-qb - sq) / (2 * qa), (-qb + sq) / (2 * qa)})
        if (t >= -1e-9 && t <= 1 + 1e-9) a + d * t,
    ];
  }

  /// Points where two circles cross.
  static List<Pt> _circleCircle(Pt c1, double r1, Pt c2, double r2) {
    final d = c1.distanceTo(c2);
    if (d < 1e-12 || d > r1 + r2 + 1e-9 || d < (r1 - r2).abs() - 1e-9) return const [];
    final a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
    final h = math.sqrt(math.max(0, r1 * r1 - a * a));
    final m = c1 + (c2 - c1) * (a / d);
    final n = (c2 - c1).perpendicular.normalized;
    return h < 1e-12 ? [m] : [m + n * h, m - n * h];
  }
}

/// i18n key naming a snap kind in the status bar.
String snapKindKey(String kind) => kind == '45°' ? 'snapk.lock45' : 'snapk.$kind';

/// Polar tracking pulls the cursor onto a multiple of the step when it is
/// within this many degrees of it.
const polarCaptureDeg = 3.0;

/// Projects [raw] onto the direction from [reference] nearest to a multiple
/// of [stepDeg] degrees (the Shift constraint of drawing programs, the ortho mode of CAD programs).
Pt lockAngle(Pt raw, Pt reference, double stepDeg) {
  final d = raw - reference;
  final len = math.sqrt(d.x * d.x + d.y * d.y);
  if (len < 1e-12) return reference;
  final step = stepDeg * math.pi / 180;
  final a = (math.atan2(d.y, d.x) / step).round() * step;
  double clean(double v) => v.abs() < 1e-12 ? 0 : v;
  final dir = Pt(clean(math.cos(a)), clean(math.sin(a)));
  final along = d.x * dir.x + d.y * dir.y;
  return Pt(reference.x + dir.x * along, reference.y + dir.y * along);
}

/// 1.6.0 CAD: the names typed on the command line for a snap of the next
/// point only (the usual three letters of CAD programs, and Portuguese
/// and Spanish ones); NON clears it.
const snapOnceAliases = <String, String>{
  'END': 'endpoint',
  'ENDP': 'endpoint',
  'FIM': 'endpoint',
  'EXTREMO': 'endpoint',
  'MID': 'midpoint',
  'MEIO': 'midpoint',
  'MEDIO': 'midpoint',
  'CEN': 'center',
  'CENTRO': 'center',
  'QUA': 'quadrant',
  'QUAD': 'quadrant',
  'NOD': 'node',
  'NODE': 'node',
  'INT': 'intersection',
  'INTER': 'intersection',
  'PER': 'perpendicular',
  'PERP': 'perpendicular',
  'TAN': 'tangent',
  'TANG': 'tangent',
  'NEA': 'nearest',
  'PROX': 'nearest',
  'EXT': 'extension',
  'NON': 'none',
  'NONE': 'none',
};

/// 1.6.0 CAD: i18n key naming the snap mode [mode] (one of [snapModes]).
String snapModeKey(String mode) => mode == 'nearest' ? 'cadp.snapNearest' : 'snapk.$mode';
