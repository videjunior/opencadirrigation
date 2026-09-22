/// Splitting of linear entities (pipes, spraylines, tapes, drawing lines)
/// at stations along their length. Used by the Cut Pipe tool, by inserting
/// point items in the middle of a pipe and by telescoped LP sizing.
library;

import 'dart:math' as math;

import 'entities.dart';
import 'geometry.dart';

/// Splits [e] at the given distances from its start (metres). Returns the
/// pieces in order; the first keeps the original id, the others get ids from
/// [newId]. Outlet positions of spraylines are preserved (the first-outlet
/// offset of each piece is recomputed). Returns [e] alone when no valid cut.
List<Entity> splitLinearEntity(Entity e, List<double> distances, String Function() newId) {
  final pts = e.linearPoints;
  if (pts == null || pts.length < 2) return [e];
  final total = polylineLength(pts);
  final ds = distances.where((d) => d > 1e-6 && d < total - 1e-6).toSet().toList()..sort();
  if (ds.isEmpty) return [e];
  final pieces = splitPolylineAt(pts, ds);
  if (pieces.length < 2) return [e];
  final out = <Entity>[];
  var start = 0.0;
  for (var i = 0; i < pieces.length; i++) {
    final id = i == 0 ? e.id : newId();
    final name = e.name.isEmpty ? '' : (i == 0 ? e.name : '${e.name} (${i + 1})');
    final piece = pieces[i];
    final pieceLen = polylineLength(piece);
    switch (e) {
      case LineEntity l:
        out.add(LineEntity(id: id, layer: l.layer, name: name, a: piece.first, b: piece.last));
      case PolylineEntity p:
        out.add(PolylineEntity(id: id, layer: p.layer, name: name, points: piece, closed: false));
      case ContourEntity c:
        out.add(ContourEntity(id: id, layer: c.layer, name: name, points: piece, elevation: c.elevation, derived: c.derived));
      case PipeEntity p:
        out.add(PipeEntity(id: id, layer: p.layer, name: name, points: piece, scope: p.scope, pipeSpecId: p.pipeSpecId, computerSized: p.computerSized, depth: p.depth));
      case SpraylineEntity s when !(s.spacing > 0):
        // no spacing: the one outlet goes with the piece that holds it
        final at = s.firstOutletDistance - start;
        final holds = i == 0 ? at >= 0 && at <= pieceLen + 1e-9 : at > 1e-9 && at <= pieceLen + 1e-9;
        out.add(s.clone(newId: id)
          ..name = name
          ..points = piece
          ..offset = holds ? math.max(at, 1e-9) : pieceLen + 1);
      case SpraylineEntity s:
        // first outlet of this piece: next outlet station at or after `start`
        final first = s.firstOutletDistance;
        var k = ((start - first) / s.spacing).ceil();
        if (k < 0) k = 0;
        var station = first + k * s.spacing;
        if (station < start - 1e-9) station += s.spacing;
        // an outlet right on the cut is the last one of the previous piece
        // (which counts its outlets up to its end with the same tolerance)
        if (i > 0 && station <= start + 1e-9 * s.spacing) station += s.spacing;
        final off = station - start;
        out.add(SpraylineEntity(id: id, layer: s.layer, name: name, points: piece, pipeSpecId: s.pipeSpecId, computerSized: s.computerSized, outletSpecId: s.outletSpecId, nozzleId: s.nozzleId, headM: s.headM, spacing: s.spacing, offset: off <= 1e-9 ? 1e-9 : off, arcDeg: s.arcDeg, riserHeight: s.riserHeight, depth: s.depth));
      case TapeEntity t:
        out.add(TapeEntity(id: id, layer: t.layer, name: name, points: piece, tapeSpecId: t.tapeSpecId, inletHeadM: t.inletHeadM, regulated: t.regulated, submainMinHeadM: t.submainMinHeadM, depth: t.depth, flushingFlow: i == pieces.length - 1 ? t.flushingFlow : 0));
      case SplineEntity s:
        out.add(SplineEntity(id: id, layer: s.layer, name: name, points: piece));
      case LeaderEntity l:
        out.add(LeaderEntity(id: id, layer: l.layer, name: name, points: piece, text: l.text, height: l.height));
      default:
        return [e];
    }
    start += pieceLen;
  }
  return out;
}

/// Trims the portion of a linear entity around station [at]: the pieces
/// between the nearest cut stations on either side of [at] are removed.
/// [cuts] are stations along the entity (from intersections). Returns the
/// remaining pieces (possibly empty when the whole entity is removed).
List<Entity> trimLinearEntity(Entity e, double at, List<double> cuts, String Function() newId) {
  final pts = e.linearPoints;
  if (pts == null || pts.length < 2) return [e];
  final total = polylineLength(pts);
  double? before, after;
  for (final c in cuts) {
    if (c <= 1e-6 || c >= total - 1e-6) continue;
    if (c < at && (before == null || c > before)) before = c;
    if (c > at && (after == null || c < after)) after = c;
  }
  if (before == null && after == null) return const [];
  final pieces = splitLinearEntity(e, [?before, ?after], newId);
  final out = <Entity>[];
  var start = 0.0;
  for (final p in pieces) {
    final len = polylineLength(p.linearPoints!);
    final end = start + len;
    final keep = !(at >= start - 1e-9 && at <= end + 1e-9);
    if (keep) out.add(p);
    start = end;
  }
  return out;
}

/// Extends the end of a linear entity nearest to [near] until it meets one
/// of the [boundaries] polylines along its last segment direction. Returns
/// true when an intersection was found and the entity was modified.
bool extendLinearEntity(Entity e, Pt near, List<List<Pt>> boundaries) {
  final pts = e.linearPoints;
  if (pts == null || pts.length < 2) return false;
  final atStart = near.distanceTo(pts.first) < near.distanceTo(pts.last);
  final end = atStart ? pts.first : pts.last;
  final prev = atStart ? pts[1] : pts[pts.length - 2];
  final dir = (end - prev).normalized;
  if (dir.length == 0) return false;
  Pt? best;
  var bestT = double.infinity;
  for (final b in boundaries) {
    for (var i = 1; i < b.length; i++) {
      final p = lineIntersection(end, end + dir, b[i - 1], b[i]);
      if (p == null) continue;
      // must be within the boundary segment and ahead of the end
      final (cp, _) = closestPointOnSegment(p, b[i - 1], b[i]);
      if (cp.distanceTo(p) > 1e-6) continue;
      final t = (p - end).dot(dir);
      if (t > 1e-6 && t < bestT) {
        bestT = t;
        best = p;
      }
    }
  }
  if (best == null) return false;
  switch (e) {
    case LineEntity l:
      if (atStart) {
        l.a = best;
      } else {
        l.b = best;
      }
    case PolyEntity p:
      p.setGrip(atStart ? 0 : p.points.length - 1, best);
    default:
      return false;
  }
  return true;
}

/// Offset copy of a linear entity by [d] metres (positive = left of the
/// drawing direction). Circles change radius; closed shapes stay closed.
Entity? offsetEntity(Entity e, double d, String newId) {
  switch (e) {
    case LineEntity l:
      final n = (l.b - l.a).normalized.perpendicular * d;
      return LineEntity(id: newId, layer: l.layer, name: l.name, a: l.a + n, b: l.b + n);
    case CircleEntity c:
      final r = c.radius + d;
      return r > 1e-6 ? CircleEntity(id: newId, layer: c.layer, name: c.name, center: c.center, radius: r) : null;
    case ArcEntity a:
      final r = a.radius + d;
      return r > 1e-6 ? ArcEntity(id: newId, layer: a.layer, name: a.name, center: a.center, radius: r, startRad: a.startRad, sweepRad: a.sweepRad) : null;
    case PolylineEntity p:
      final pts = p.closed ? _offsetClosed(p.points, d) : offsetPolyline(p.points, d);
      return PolylineEntity(id: newId, layer: p.layer, name: p.name, points: pts, closed: p.closed);
    case ContourEntity c:
      return ContourEntity(id: newId, layer: c.layer, name: c.name, points: offsetPolyline(c.points, d), elevation: c.elevation);
    case PipeEntity p:
      return PipeEntity(id: newId, layer: p.layer, name: p.name, points: offsetPolyline(p.points, d), scope: p.scope, pipeSpecId: p.pipeSpecId, computerSized: p.computerSized, depth: p.depth);
    case SpraylineEntity s:
      return s.clone(newId: newId)..points = offsetPolyline(s.points, d);
    case TapeEntity t:
      return t.clone(newId: newId)..points = offsetPolyline(t.points, d);
    case AreaEntity a:
      return a.clone(newId: newId)..points = _offsetClosed(a.points, d);
    case SplineEntity s:
      return SplineEntity(id: newId, layer: s.layer, name: s.name, points: offsetPolyline(s.points, d), closed: s.closed);
    default:
      return null;
  }
}

List<Pt> _offsetClosed(List<Pt> pts, double d) {
  if (pts.length < 3) return offsetPolyline(pts, d);
  final ring = [pts.last, ...pts, pts.first];
  final off = offsetPolyline(ring, d);
  return off.sublist(1, off.length - 1);
}
