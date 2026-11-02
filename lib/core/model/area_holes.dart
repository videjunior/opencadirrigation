/// Islands of irrigated areas (1.6.0 MOD): taking a closed shape out of an
/// area. A shape inside the outline becomes a hole of the area (a pond, a
/// building, a bed of other plants), one across the outline cuts a notch,
/// one that crosses the area from side to side splits it in pieces; holes
/// that overlap are merged. The geometry is that of the layout region
/// ([LayoutRegion]): the outline less its exclusions.
library;

import '../design/auto_layout.dart' show LayoutRegion;
import 'edit_ops.dart' show areaOutline;
import 'entities.dart';
import 'geometry.dart';
import 'project.dart';

/// One piece of an area: its outline and its holes.
typedef AreaPiece = ({List<Pt> outline, List<List<Pt>> holes});

/// [outline] less [holes] and [cut] (closed polygons, any orientation): the
/// pieces left, the largest first (outlines counter-clockwise, holes
/// clockwise); empty when nothing is left.
List<AreaPiece> subtractPolygon(List<Pt> outline, List<List<Pt>> holes, List<Pt> cut) {
  final region = LayoutRegion(outline, exclusions: [...holes, cut]);
  if (region.isEmpty) return const [];
  final outers = <List<Pt>>[], inners = <List<Pt>>[];
  for (final l in region.loops) {
    (polygonArea(l.points) > 0 ? outers : inners).add(List.of(l.points));
  }
  outers.sort((a, b) => polygonArea(b).compareTo(polygonArea(a)));
  final pieces = <AreaPiece>[for (final o in outers) (outline: o, holes: <List<Pt>>[])];
  for (final h in inners) {
    if (h.length < 3 || pieces.isEmpty) continue;
    // the outer loops do not nest: the one that holds a point of the hole
    final probe = Pt.lerp(h[0], h[1], 0.5);
    final owner = pieces.indexWhere((p) => pointInPolygon(probe, p.outline));
    pieces[owner < 0 ? 0 : owner].holes.add(h);
  }
  return pieces;
}

/// Whether [cut] lies strictly inside the outline of [a], apart from its
/// holes (neither crossing, holding nor inside one): it then simply becomes
/// one more hole, the outline as it was.
bool fitsAsHole(AreaEntity a, List<Pt> cut) {
  if (cut.length < 3 || a.points.length < 3) return false;
  if (polylineIntersections(cut, a.points, closedA: true, closedB: true).isNotEmpty) return false;
  if (!cut.every((p) => pointInPolygon(p, a.points) && !pointOnPolygonBoundary(p, a.points, tol: 1e-6))) return false;
  for (final h in a.holes) {
    if (polylineIntersections(cut, h, closedA: true, closedB: true).isNotEmpty) return false;
    if (pointInPolygon(cut.first, h) || pointInPolygon(h.first, cut)) return false;
  }
  return true;
}

/// [a] less the closed shape [cut]: the areas that replace it, [a] itself
/// (same id and properties) with its new outline and holes first, then one
/// copy of it per further piece with an id from [newId] and the name
/// numbered; empty when the cut takes the whole area; null when the cut
/// misses the area or leaves it as it was.
List<AreaEntity>? subtractFromArea(AreaEntity a, List<Pt> cut, String Function() newId) {
  if (cut.length < 3 || polygonArea(cut).abs() < 1e-9 || a.points.length < 3) return null;
  if (fitsAsHole(a, cut)) {
    return [
      a.clone()..holes = [...a.holes.map(List<Pt>.of), List.of(cut)],
    ];
  }
  if (!Bounds.ofPoints(cut).intersects(Bounds.ofPoints(a.points))) return null;
  final before = a.area;
  final pieces = subtractPolygon(a.points, a.holes, cut);
  if (pieces.isEmpty) return const [];
  final after = pieces.fold(0.0, (s, p) => s + polygonArea(p.outline).abs() - p.holes.fold(0.0, (t, h) => t + polygonArea(h).abs()));
  if ((before - after).abs() <= 1e-6 * before.clamp(1.0, double.infinity)) return null;
  return [
    for (var k = 0; k < pieces.length; k++)
      a.clone(newId: k == 0 ? a.id : newId())
        ..points = pieces[k].outline
        ..holes = pieces[k].holes
        ..name = k == 0 || a.name.isEmpty ? a.name : '${a.name} (${k + 1})',
  ];
}

/// The holes of [e] when it is an area (copies), else none: what the layout
/// and the other automatic tools keep dry besides the exclusions chosen.
List<List<Pt>> holesOf(Entity? e) => e is AreaEntity ? [for (final h in e.holes) List.of(h)] : const [];

/// The holes of [a] that lie inside the polygon [part] (by a point of each),
/// for a piece of [a] cut off by another operation.
List<List<Pt>> holesWithin(AreaEntity a, List<Pt> part) => [
  for (final h in a.holes)
    if (h.length >= 3 && pointInPolygon(Pt.lerp(h[0], h[1], 0.5), part)) List.of(h),
];

/// The closed outline [e] cuts out of an area: that of a closed polyline (or
/// one whose ends meet within [tol]), a hatch, a revision cloud, a closed
/// spline, a circle ([areaOutline]) or another area; null for anything else.
List<Pt>? cutOutlineOf(Entity e, {double tol = 1e-6}) => e is AreaEntity ? (e.points.length >= 3 ? List.of(e.points) : null) : areaOutline(e, tol: tol);

/// Takes the closed outlines [cuts] out of the [areas] of [p] they meet, in
/// place: each area changed is replaced, where it was in the list, by what
/// [subtractFromArea] leaves of it (several pieces when a cut splits it,
/// none when the cuts take it all). The ids of the areas changed or made,
/// and of those removed; both empty when no cut meets an area.
({List<String> changed, List<String> removed}) subtractFromAreas(Project p, List<AreaEntity> areas, List<List<Pt>> cuts) {
  final changed = <String>[], removed = <String>[];
  for (final area in areas) {
    var current = <AreaEntity>[area];
    var touched = false;
    for (final cut in cuts) {
      final next = <AreaEntity>[];
      for (final a in current) {
        final r = subtractFromArea(a, cut, p.newId);
        if (r == null) {
          next.add(a);
        } else {
          touched = true;
          next.addAll(r);
        }
      }
      current = next;
    }
    if (!touched) continue;
    final idx = p.entities.indexWhere((e) => e.id == area.id);
    if (idx < 0) continue;
    p.entities
      ..removeAt(idx)
      ..insertAll(idx, current);
    if (current.isEmpty) removed.add(area.id);
    changed.addAll(current.map((e) => e.id));
  }
  return (changed: changed, removed: removed);
}
