/// 1.6.0 AUT (AUT-05): an irrigated area whose outline crosses itself is
/// said at once, when it is drawn and when one of its vertices is moved or
/// taken away (a grip dragged across another side): until it is split or
/// its vertices moved, its computed area — and with it the water need, the
/// volume, the permit and the schedule — comes out wrong. The design check
/// flags it too (`area_self_intersect`), with the correction that splits it
/// into the simple areas its loops enclose.
library;

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import 'controller.dart';

/// The first of [changed] that is an irrigated area of the project whose
/// outline crosses itself, or null.
AreaEntity? selfCrossingArea(ProjectController c, Iterable<Entity> changed) {
  for (final e in changed) {
    if (e is! AreaEntity || e.points.length < 4) continue;
    if (!identical(c.entityById(e.id), e)) continue;
    if (polygonSelfCrossingEdges(e.points).isNotEmpty) return e;
  }
  return null;
}

/// Tells the user when one of [changed] is an irrigated area whose outline
/// crosses itself (see the library comment); true when it did.
bool warnSelfCrossingAreas(ProjectController c, Iterable<Entity> changed) {
  final a = selfCrossingArea(c, changed);
  if (a == null) return false;
  c.notify(c.t('aut.areaCrosses', {'n': a.name.trim().isEmpty ? c.t('tool.area') : a.name.trim()}));
  return true;
}
