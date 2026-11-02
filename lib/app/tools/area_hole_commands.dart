/// "Subtract from area" (1.6.0 MOD): closed shapes taken out of irrigated
/// areas as islands (a pond, a building, a bed of other plants), notches or
/// pieces ([subtractFromAreas]), one undo step with its own label in the
/// history; and the islands of an area taken away again.
library;

import 'dart:math' as math;

import '../../core/model/area_holes.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../state/controller.dart';

/// The commands on the islands of areas, on the controller.
extension AreaHoleCommands on ProjectController {
  /// Takes the selected closed shapes (closed polylines, circles, closed
  /// splines, hatches, revision clouds) out of the selected areas, or of
  /// every area they meet when no area is selected. A shape inside an area
  /// becomes an island of it, one across its outline a notch, one across the
  /// whole area splits it; the shapes are removed (their outlines are the
  /// islands now), unless their layer is locked. One undo step; returns how
  /// many areas changed.
  int subtractSelectedFromAreas() {
    track('subtractArea');
    final locked = {
      for (final l in project.layers)
        if (l.locked) l.name,
    };
    final picked = [
      for (final e in project.entities)
        if (selection.contains(e.id)) e,
    ];
    final tol = math.max(project.params.connectTolerance, 1e-6);
    final shapes = <(Entity, List<Pt>)>[
      for (final e in picked)
        if (e is! AreaEntity)
          if (cutOutlineOf(e, tol: tol) case final o?) (e, o),
    ];
    if (shapes.isEmpty) {
      notify(t(picked.isEmpty ? 'msg.nothingSelected' : 'area.subtract.noShape'));
      return 0;
    }
    final chosen = [
      for (final e in picked)
        if (e is AreaEntity && !locked.contains(e.layer)) e,
    ];
    final targets = chosen.isNotEmpty
        ? chosen
        : [
            for (final e in project.entities)
              if (e is AreaEntity && !locked.contains(e.layer) && shapes.any((s) => Bounds.ofPoints(s.$2).intersects(e.bounds))) e,
          ];
    // a dry run first: a cut that misses every area is no undo step
    final hits = targets.any((a) => shapes.any((s) => subtractFromArea(a, s.$2, () => 'probe') != null));
    if (!hits) {
      notify(t(targets.isEmpty ? 'area.subtract.noArea' : 'area.subtract.missed'));
      return 0;
    }
    final done = mutate(() {
      final r = subtractFromAreas(project, targets, [for (final s in shapes) s.$2]);
      final gone = {
        for (final s in shapes)
          if (!locked.contains(s.$1.layer)) s.$1.id,
      };
      project.entities.removeWhere((e) => gone.contains(e.id));
      return r;
    }, label: 'hist.subtractArea|${shapes.length}');
    if (done == null) return 0;
    select(done.changed);
    // the areas cut (a split one counts once), and the pieces they left
    final areas = targets.where((a) => done.changed.contains(a.id) || done.removed.contains(a.id)).length;
    notify(t('area.subtract.done', {'n': '$areas', 'm': '${done.changed.length}'}));
    return areas;
  }

  /// Takes every island out of the selected areas (the whole outline is
  /// irrigated again). One undo step; returns how many areas changed.
  int clearSelectedAreaHoles() {
    track('clearAreaHoles');
    final areas = [
      for (final e in project.entities)
        if (selection.contains(e.id) && e is AreaEntity && e.holes.isNotEmpty && !project.isLocked(e.layer)) e,
    ];
    if (areas.isEmpty) {
      notify(t('area.holes.none'));
      return 0;
    }
    final ids = {for (final a in areas) a.id};
    final n = mutate(() {
      for (final e in project.entities) {
        if (e is AreaEntity && ids.contains(e.id)) e.holes = [];
      }
      return ids.length;
    }, label: 'hist.clearAreaHoles|${ids.length}');
    if (n == null) return 0;
    notify(t('area.holes.cleared', {'n': '$n'}));
    return n;
  }
}
