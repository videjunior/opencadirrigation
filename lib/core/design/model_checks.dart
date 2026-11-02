/// Checks of the drawing data themselves, run with the design check:
/// hydraulic items placed where the terrain data do not reach (their
/// elevation is extrapolated) and area outlines that cross themselves
/// (their area, and everything computed from it, comes out wrong).
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'design_check.dart';

/// Distance (m) beyond the outline of the terrain data from which an item's
/// elevation counts as extrapolated: the larger of 10 m and two densify
/// steps (items on the edge of a survey are interpolated well enough).
double extrapolationMargin(Project p) => math.max(10, 2 * p.params.terrainDensify);

/// The issues of [project]'s data (see the library comment):
/// `outside_terrain` (warning, the items whose elevation is extrapolated)
/// and `area_self_intersecting` (warning, one per area).
List<CheckIssue> modelChecks(Project project) {
  final out = <CheckIssue>[];
  final terrain = project.buildTerrain();
  if (!terrain.isEmpty) {
    final margin = extrapolationMargin(project);
    final far = <String>[];
    Pt? first;
    for (final e in project.entities) {
      final pts = switch (e) {
        PivotEntity p => [p.center],
        PolyEntity l when e.isLinearHydraulic => l.points,
        PointEntity q when e.isHydraulic => [q.position],
        _ => const <Pt>[],
      };
      for (final q in pts) {
        if (!terrain.extrapolatesAt(q, margin: margin)) continue;
        far.add(e.id);
        first ??= q;
        break;
      }
    }
    if (far.isNotEmpty) out.add(CheckIssue('outside_terrain', CheckSeverity.warning, entityIds: far, at: first, value: '${far.length}'));
  }
  for (final a in project.entities.whereType<AreaEntity>()) {
    final x = polygonSelfCrossing(a.points);
    if (x != null) out.add(CheckIssue('area_self_intersecting', CheckSeverity.warning, entityIds: [a.id], at: x.$3, value: a.name));
  }
  return out;
}
