import 'dart:math' as math;

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../state/controller.dart';

class SnapResult {
  const SnapResult(this.point, this.kind, {this.entityId, this.locked = false});
  final Pt point;

  /// The Shift angle lock shaped this point (an object snap may still have won).
  final bool locked;

  /// endpoint | midpoint | node | on | ortho | grid | none
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
    }
    final locked = angleLock && reference != null;
    if (!s.enabled) return SnapResult(p, lockKind, locked: locked);
    final tol = s.tolerancePx / c.camera.scale;
    SnapResult? best;
    var bestScore = double.infinity;
    void consider(Pt q, String kind, double priority, String? id) {
      final d = q.distanceTo(p);
      if (d > tol) return;
      final score = d * priority;
      if (score < bestScore) {
        bestScore = score;
        best = SnapResult(q, kind, entityId: id, locked: locked);
      }
    }

    // only the entities within reach of the cursor (spatial index)
    for (final e in c.entitiesIn(Bounds(p.x - tol, p.y - tol, p.x + tol, p.y + tol))) {
      if (ignoreSelection && c.selection.contains(e.id)) continue;
      switch (e) {
        case PointEntity pe when e is! TextEntity:
          consider(pe.position, 'node', 0.4, e.id);
        case LineEntity l:
          consider(l.a, 'endpoint', 0.5, e.id);
          consider(l.b, 'endpoint', 0.5, e.id);
          consider(Pt.lerp(l.a, l.b, 0.5), 'midpoint', 0.8, e.id);
        case PolyEntity pl:
          final pts = pl.points;
          for (var i = 0; i < pts.length; i++) {
            consider(pts[i], 'endpoint', 0.5, e.id);
            if (i > 0) {
              consider(Pt.lerp(pts[i - 1], pts[i], 0.5), 'midpoint', 0.8, e.id);
              if (e is PipeEntity || e is SpraylineEntity || e is TapeEntity) {
                final (cp, _) = closestPointOnSegment(p, pts[i - 1], pts[i]);
                consider(cp, 'on', 1.0, e.id);
              }
            }
          }
          if (e is PolylineEntity && e.closed && pts.length > 2) {
            final (cp, _) = closestPointOnSegment(p, pts.last, pts.first);
            consider(cp, 'on', 1.2, e.id);
          }
        case CircleEntity ci:
          consider(ci.center, 'node', 0.6, e.id);
          final dir = (p - ci.center).normalized;
          consider(ci.center + dir * ci.radius, 'on', 1.1, e.id);
        default:
          break;
      }
    }
    if (best != null) return best!;
    if (s.grid && s.gridSize > 0) {
      final g = s.gridSize;
      final q = Pt((p.x / g).round() * g, (p.y / g).round() * g);
      if (q.distanceTo(p) <= tol * 1.5) return SnapResult(q, 'grid', locked: locked);
    }
    return SnapResult(p, lockKind, locked: locked);
  }

  double get tolerance => c.snap.tolerancePx / math.max(c.camera.scale, 1e-9);
}

/// Projects [raw] onto the direction from [reference] nearest to a multiple
/// of [stepDeg] degrees (Photoshop-style Shift constraint, AutoCAD ortho).
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
