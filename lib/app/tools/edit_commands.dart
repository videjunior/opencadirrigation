/// Editing commands added in 1.6.0 on the controller, as an extension (the
/// way the block commands are kept in insert_block_tool.dart), and the
/// settings of the new tools. Each change is one undo step with its own
/// label in the history.
library;

import 'dart:math' as math;

import '../../core/model/edit_ops.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../state/controller.dart';
import 'selection_filters.dart';

/// Settings of the editing and selection tools of 1.6.0, one set per
/// project tab (see [EditCommands.editSettings]).
class EditSettings {
  /// Taps and clicks add to the selection (or take a selected item out of
  /// it) as Shift does: the touch screen has no Shift key.
  bool addToSelection = false;

  /// The lasso also takes what it crosses (else only what lies inside).
  bool lassoCrossing = false;

  /// Radius of the fillets (m; 0 makes a sharp corner).
  double filletRadius = 1;

  /// Distances of a chamfer from the corner along the first and the second
  /// side (m).
  double chamferDistance1 = 1;
  double chamferDistance2 = 1;

  /// What the Measure tool measures, and its last result (kept on the
  /// drawing and in the panel until the next one).
  MeasureMode measureMode = MeasureMode.distance;
  Measurement? lastMeasure;
}

/// The modes of the Measure tool: two points, a path of several points
/// (its length), an outline (its area and perimeter).
enum MeasureMode { distance, path, area }

/// One measurement: its mode and points.
class Measurement {
  const Measurement(this.mode, this.points);
  final MeasureMode mode;
  final List<Pt> points;

  /// Length of the path (the perimeter of an outline).
  double get length => polylineLength(mode == MeasureMode.area ? [...points, points.first] : points);

  /// Area of an outline (m²), 0 for the other modes.
  double get area => mode == MeasureMode.area ? polygonArea(points).abs() : 0;

  /// The result in the display units of [c].
  String text(ProjectController c) {
    final u = c.units;
    String len(double v, [int d = 2]) => '${u.lengthFromSi(v).toStringAsFixed(d)} ${u.lengthLabel}';
    switch (mode) {
      case MeasureMode.distance:
        final a = points.first, b = points.last;
        final dx = b.x - a.x, dy = b.y - a.y;
        return 'Δ = ${len(a.distanceTo(b), 3)}  (Δx ${u.lengthFromSi(dx).toStringAsFixed(2)}, Δy ${u.lengthFromSi(dy).toStringAsFixed(2)}, ${radToDeg(math.atan2(dy, dx)).toStringAsFixed(1)}°)';
      case MeasureMode.path:
        return c.t('meas.pathResult', {'l': len(length), 'n': '${points.length - 1}'});
      case MeasureMode.area:
        final k = u.lengthFromSi(1);
        return c.t('meas.areaResult', {'a': '${(area * k * k).toStringAsFixed(1)} ${u.lengthLabel}²', 'ha': '${u.areaFromSi(area).toStringAsFixed(4)} ${u.areaLabel}', 'p': len(length)});
    }
  }
}

/// Whether an edit of [e] changes the results of the design: the network,
/// the terrain, the areas and the electrical items.
bool editAffectsResults(Entity e) => e.isHydraulic || e is ContourEntity || e is SpotHeightEntity || e is BreaklineEntity || e is AreaEntity || e is WireEntity || e is ControllerEntity;

final _editSettings = Expando<EditSettings>('editSettings');

/// The tools whose clicks Shift (or [EditSettings.addToSelection]) turns
/// into "add to the selection".
bool usesAddToSelection(ToolId t) => t == ToolId.select || t == ToolId.trim || t == ToolId.extend || t == ToolId.lasso || t == ToolId.fence;

extension EditCommands on ProjectController {
  /// The settings of the 1.6.0 editing tools of this tab.
  EditSettings get editSettings => _editSettings[this] ??= EditSettings();

  /// Turns "add to the selection" on or off and says what taps do now.
  void setAddToSelection(bool on) {
    editSettings.addToSelection = on;
    notify(t(on ? 'sel.addModeOn' : 'sel.addModeOff'));
  }

  // ---------------------------------------------------------------- selection (CAD-25)

  /// The items a selection may take: on visible layers that are not locked.
  List<Entity> selectableEntities() {
    final layers = {for (final l in project.layers) l.name: l};
    return [
      for (final e in project.entities)
        if ((layers[e.layer]?.visible ?? true) && !(layers[e.layer]?.locked ?? false)) e,
    ];
  }

  /// Selects every item like the selected ones: the same kind and catalogue
  /// item, or the same kind on the same layer for the drawing (see
  /// [similarityKey]). Returns the size of the new selection.
  int selectSimilar() {
    track('selectSimilar');
    if (selection.isEmpty) {
      notify(t('msg.nothingSelected'));
      return 0;
    }
    final keys = {
      for (final e in project.entities)
        if (selection.contains(e.id)) similarityKey(e),
    };
    final ids = [
      for (final e in selectableEntities())
        if (keys.contains(similarityKey(e))) e.id,
    ];
    select(ids);
    notify(t('sel.similarDone', {'n': '${ids.length}'}));
    return ids.length;
  }

  /// The selectable items that meet [q].
  List<Entity> queryMatches(SelectionQuery q) {
    final members = q.zone == null ? null : zoneMembers(project, results, q.zone!);
    final cat = project.catalog;
    return [
      for (final e in selectableEntities())
        if (matchesQuery(e, q, cat, members: members)) e,
    ];
  }

  /// Changes the selection by the items that meet [q] ([mode]: replace it,
  /// add to it, take them out of it, or keep only them). Returns the size of
  /// the new selection.
  int selectByQuery(SelectionQuery q, {SelectionMode mode = SelectionMode.replace}) {
    track('quickSelect');
    final ids = {for (final e in queryMatches(q)) e.id};
    switch (mode) {
      case SelectionMode.replace:
        select(ids);
      case SelectionMode.add:
        select(ids, add: true);
      case SelectionMode.remove:
        selection.removeAll(ids);
        refresh();
      case SelectionMode.within:
        selection.retainAll(ids);
        refresh();
    }
    return selection.length;
  }

  /// Selects what lies inside the polygon [poly] (a lasso), or also what it
  /// crosses with [crossing]; [add] adds to the selection. Returns how many
  /// items it took.
  int selectInPolygon(List<Pt> poly, {bool crossing = false, bool add = false}) {
    track('lasso');
    if (poly.length < 3) return 0;
    final ids = [
      for (final e in entitiesIn(Bounds.ofPoints(poly)))
        if (!project.isLocked(e.layer) && inPolygon(e, poly, crossing: crossing)) e.id,
    ];
    select(ids, add: add);
    return ids.length;
  }

  /// Selects what the fence [fence] crosses; [add] adds to the selection.
  /// Returns how many items it took.
  int selectByFence(List<Pt> fence, {bool add = false}) {
    track('fence');
    if (fence.length < 2) return 0;
    final tol = snap.tolerancePx / camera.scale;
    final ids = [
      for (final e in entitiesIn(Bounds.ofPoints(fence).inflate(tol)))
        if (!project.isLocked(e.layer) && crossedByFence(e, fence, tol)) e.id,
    ];
    select(ids, add: add);
    return ids.length;
  }

  /// Selects every item of [layer] (the current layer when null); a hidden
  /// or locked layer selects nothing and says why. Returns how many.
  int selectOnLayer([String? layer, bool add = false]) {
    track('selectLayer');
    final name = layer ?? project.currentLayer;
    final l = project.findLayer(name);
    if (l != null && (l.locked || !l.visible)) {
      notify(t(l.locked ? 'msg.layerLocked' : 'sel.layerHidden'));
      return 0;
    }
    final ids = [
      for (final e in project.entities)
        if (e.layer == name) e.id,
    ];
    select(ids, add: add);
    notify(t('mob.selection', {'n': '${ids.length}'}));
    return ids.length;
  }
}

/// The geometry edits of 1.6.0 (CAD-26) on the selection or on picked
/// items, each one undo step with its own label in the history.
extension GeometryCommands on ProjectController {
  /// The selected items on layers that can be edited, in drawing order.
  List<Entity> _editable() {
    final locked = {
      for (final l in project.layers)
        if (l.locked) l.name,
    };
    return [
      for (final e in project.entities)
        if (selection.contains(e.id) && !locked.contains(e.layer)) e,
    ];
  }

  /// Replaces [gone] by [made] in one undo step labelled [label]: the new
  /// items take the place of the first item gone. Returns false when the
  /// edit was refused (a design runs).
  bool _replace(List<Entity> gone, List<Entity> made, String label) {
    final ids = {for (final e in gone) e.id};
    final affects = gone.any(editAffectsResults) || made.any(editAffectsResults);
    final done = mutate(
      () {
        final at = project.entities.indexWhere((e) => ids.contains(e.id));
        project.entities.removeWhere((e) => ids.contains(e.id));
        project.entities.insertAll(at < 0 ? project.entities.length : math.min(at, project.entities.length), made);
        return true;
      },
      invalidateResults: affects,
      label: label,
    );
    return done == true;
  }

  /// New ids for the pieces an edit made with placeholder ids.
  List<Entity> _withIds(List<Entity> pieces, Set<String> placeholders) => [for (final p in pieces) placeholders.contains(p.id) ? p.clone(newId: project.newId()) : p];

  /// A valve, an outlet or another point item of the network on [p]: a
  /// pipe joint there is a connection, not a bend to join through.
  bool _itemAt(Pt p) {
    final tol = math.max(project.params.connectTolerance, 1e-6);
    return entitiesIn(Bounds(p.x - tol, p.y - tol, p.x + tol, p.y + tol)).any((e) => e is PointEntity && e.isHydraulic && e.position.distanceTo(p) <= tol);
  }

  /// Joins the selected lines, polylines and arcs, pipes of one kind,
  /// wires, contours and breaklines whose ends meet into one item per chain
  /// (a closed polyline when the chain closes; a pipe joint with a valve or
  /// another item on it is not crossed). Returns how many items were
  /// joined; 0 tells the user why.
  int joinSelected() {
    track('join');
    final tol = math.max(project.params.connectTolerance, 1e-6);
    final chains = joinChains(_editable(), tol, blocked: _itemAt);
    if (chains.isEmpty) {
      notify(t(selection.isEmpty ? 'msg.nothingSelected' : 'edt.nothingToJoin'));
      return 0;
    }
    final gone = [for (final ch in chains) ...ch.members];
    final made = [for (final ch in chains) joinedEntity(ch, tol)];
    if (!_replace(gone, made, 'hist.join|${gone.length}')) return 0;
    select(made.map((e) => e.id));
    notify(t('edt.joined', {'n': '${gone.length}', 'm': '${made.length}'}));
    return gone.length;
  }

  /// Explodes the selected polylines, hatches, clouds, splines, leaders,
  /// pipes, laterals, tapes, contours, wires and breaklines (see
  /// [explodeEntity]); the pieces become the selection. Returns how many
  /// items were exploded.
  int explodeSelected() {
    track('explode');
    final gone = <Entity>[], made = <Entity>[];
    final placeholders = <String>{};
    for (final e in _editable()) {
      final pieces = explodeEntity(e, () {
        final id = '#explode${placeholders.length}';
        placeholders.add(id);
        return id;
      });
      if (pieces == null) continue;
      gone.add(e);
      made.addAll(pieces);
    }
    if (gone.isEmpty) {
      notify(t(selection.isEmpty ? 'msg.nothingSelected' : 'edt.nothingToExplode'));
      return 0;
    }
    final fixed = _withIds(made, placeholders);
    if (!_replace(gone, fixed, 'hist.explode|${gone.length}')) return 0;
    select(fixed.map((e) => e.id));
    notify(t('edt.exploded', {'n': '${gone.length}', 'm': '${fixed.length}'}));
    return gone.length;
  }

  /// Turns the selected closed outlines (closed polylines, hatches, clouds,
  /// closed splines, circles, polylines whose ends meet) into irrigated
  /// areas with the same outline. Returns how many areas were made.
  int convertSelectedToArea() {
    track('toArea');
    final tol = math.max(project.params.connectTolerance, 1e-6);
    final gone = <Entity>[], made = <Entity>[];
    var k = project.entities.whereType<AreaEntity>().length;
    for (final e in _editable()) {
      if (e is AreaEntity) continue;
      final outline = areaOutline(e, tol: tol);
      if (outline == null) continue;
      gone.add(e);
      made.add(AreaEntity(id: e.id, name: e.name.isNotEmpty ? e.name : '${t('name.area')} ${++k}', points: outline));
    }
    if (gone.isEmpty) {
      notify(t(selection.isEmpty ? 'msg.nothingSelected' : 'edt.notClosed'));
      return 0;
    }
    if (!_replace(gone, made, 'hist.toArea|${made.length}')) return 0;
    select(made.map((e) => e.id));
    notify(t('edt.areasMade', {'n': '${made.length}'}));
    return made.length;
  }

  /// The segment of [e] nearest to [p] (the index of its first vertex)
  /// and the vertices of [e]; null when [e] has no straight sides.
  (int, List<Pt>)? _segmentAt(Entity e, Pt p) {
    final List<Pt>? pts = switch (e) {
      LineEntity l => [l.a, l.b],
      SplineEntity _ => null,
      PolyEntity x => x.points,
      _ => null,
    };
    if (pts == null || pts.length < 2) return null;
    final n = pts.length + (e.isClosedShape ? 1 : 0);
    var best = 0;
    var bestD = double.infinity;
    for (var i = 1; i < n; i++) {
      final d = distanceToSegment(p, pts[i - 1], pts[i % pts.length]);
      if (d < bestD) {
        bestD = d;
        best = i - 1;
      }
    }
    return (best, pts);
  }

  /// Rounds (or, with [chamfer], cuts) the corner between the side of [idA]
  /// picked at [atA] and the side of [idB] picked at [atB]: two sides of
  /// one polyline-like item that meet at a vertex, or the end sides of two
  /// lines or open items — each trimmed or extended to the corner, the arc
  /// (or the cut) between them a drawing arc or line, or vertices of the
  /// first item when both are pipes, wires… of one kind. Radius and
  /// distances from [EditCommands.editSettings]; a radius of 0 makes a
  /// sharp corner. Returns false, telling why, when the corner cannot be
  /// made.
  bool cornerAt(String idA, Pt atA, String idB, Pt atB, {bool chamfer = false}) {
    track(chamfer ? 'chamfer' : 'fillet');
    final s = editSettings;
    final label = chamfer ? 'hist.chamfer' : 'hist.fillet';
    bool fail() {
      notify(t(chamfer ? 'edt.chamferFailed' : 'edt.filletFailed'));
      return false;
    }

    final a = project.byId(idA), b = project.byId(idB);
    if (a == null || b == null || project.isLocked(a.layer) || project.isLocked(b.layer)) return fail();
    final sa = _segmentAt(a, atA), sb = _segmentAt(b, atB);
    if (sa == null || sb == null) return fail();
    final r = s.filletRadius;
    // two sides of one item meeting at a vertex
    if (identical(a, b)) {
      if (a is! PolyEntity) return fail();
      final pts = sa.$2;
      final n = pts.length;
      final closed = a.isClosedShape;
      final i = sa.$1, j = sb.$1;
      final int vertex;
      if (j == i + 1 || (closed && j == (i + 1) % n)) {
        vertex = j;
      } else if (i == j + 1 || (closed && i == (j + 1) % n)) {
        vertex = i;
      } else {
        return fail();
      }
      final out = chamfer ? chamferVertex(pts, vertex, s.chamferDistance1, s.chamferDistance2, closed: closed) : (r <= 0 ? null : filletVertex(pts, vertex, r, closed: closed));
      if (out == null) return fail();
      final e = a.clone();
      (e as PolyEntity).points
        ..clear()
        ..addAll(out);
      return _replace([a], [e], label);
    }
    // the end sides of two items
    final pa = sa.$2, pb = sb.$2;
    if (a.isClosedShape || b.isClosedShape) return fail();
    final x = lineIntersection(pa[sa.$1], pa[sa.$1 + 1], pb[sb.$1], pb[sb.$1 + 1]);
    if (x == null) return fail();
    final ea = _cornerEnd(pa, sa.$1, atA, x), eb = _cornerEnd(pb, sb.$1, atB, x);
    if (ea == null || eb == null) return fail();
    final (endA, ua, reachA) = ea;
    final (endB, ub, reachB) = eb;
    Pt ta, tb;
    var bridge = const <Pt>[];
    FilletArc? arc;
    if (chamfer) {
      ta = x + ua * s.chamferDistance1;
      tb = x + ub * s.chamferDistance2;
      bridge = [ta, tb];
    } else if (r <= 0) {
      ta = tb = x;
    } else {
      arc = filletBetween(x, ua, ub, r);
      if (arc == null) return fail();
      ta = arc.ta;
      tb = arc.tb;
      bridge = arc.points();
    }
    // the corner must leave something of each kept side
    if ((ta - x).dot(ua) >= reachA - 1e-9 || (tb - x).dot(ub) >= reachB - 1e-9) return fail();
    final sameKind = a.runtimeType == b.runtimeType && a is PolyEntity && a is! PolylineEntity;
    final made = <Entity>[_movedEnd(a, endA, ta, extra: sameKind && bridge.isNotEmpty ? bridge.sublist(1) : const []), _movedEnd(b, endB, tb)];
    if (!sameKind && arc != null) made.add(ArcEntity(id: project.newId(), layer: a.layer, center: arc.center, radius: arc.radius, startRad: arc.startRad, sweepRad: arc.sweepRad));
    if (!sameKind && chamfer) made.add(LineEntity(id: project.newId(), layer: a.layer, a: ta, b: tb));
    return _replace([a, b], made, label);
  }

  /// The end of the vertices [pts] that a corner at [x] moves, for the
  /// side [seg] picked at [click]: the vertex index, the direction of the
  /// side kept (away from the corner) and how far it reaches from the
  /// corner. A line keeps the side of the click; a polyline-like item
  /// keeps its body, so only its first or last side can make a corner.
  (int, Pt, double)? _cornerEnd(List<Pt> pts, int seg, Pt click, Pt x) {
    final last = pts.length - 1;
    if (pts.length == 2) {
      final along = (pts.last - pts.first).normalized;
      if (along.length == 0) return null;
      final dir = (click - x).dot(along) >= 0 ? along : -along;
      // the end behind the corner (or the nearer one) moves
      final ia = (pts.first - x).dot(dir), ib = (pts.last - x).dot(dir);
      return ia <= ib ? (0, dir, ib) : (last, dir, ia);
    }
    final (end, anchor) = seg == 0 ? (0, pts[1]) : (seg == last - 1 ? (last, pts[last - 1]) : (-1, Pt.zero));
    if (end < 0) return null;
    // the corner lies on the side of the free end (else the side would fold back)
    if ((x - anchor).dot(pts[end] - anchor) <= 0) return null;
    final dir = (anchor - x).normalized;
    return dir.length == 0 ? null : (end, dir, anchor.distanceTo(x));
  }

  /// [e] with its vertex [end] moved to [to] and, for a polyline-like
  /// item, [extra] vertices added past it (the arc of a fillet).
  Entity _movedEnd(Entity e, int end, Pt to, {List<Pt> extra = const []}) {
    final c = e.clone();
    if (c is LineEntity) {
      if (end == 0) {
        c.a = to;
      } else {
        c.b = to;
      }
      return c;
    }
    final p = (c as PolyEntity).points;
    p[end] = to;
    if (extra.isNotEmpty) {
      if (end == 0) {
        p.insertAll(0, extra.reversed);
      } else {
        p.addAll(extra);
      }
    }
    return c;
  }

  /// Stretches what lies inside the window [w]: the vertices inside move
  /// by [d] and the others stay, an item wholly inside moves (see
  /// [stretchEntity]); a selection limits it to its items. Returns how
  /// many items changed.
  int stretchWindow(Bounds w, Pt d) {
    track('stretch');
    if (d.length < 1e-12) return 0;
    final limit = selection.isEmpty ? null : Set.of(selection);
    final changed = <String, Entity>{};
    for (final e in entitiesIn(w)) {
      if (project.isLocked(e.layer) || (limit != null && !limit.contains(e.id))) continue;
      final s = stretchEntity(e, w, d);
      if (s != null) changed[e.id] = s;
    }
    if (changed.isEmpty) return 0;
    final affects = project.entities.any((e) => changed.containsKey(e.id) && editAffectsResults(e));
    mutate(
      () {
        for (var i = 0; i < project.entities.length; i++) {
          final s = changed[project.entities[i].id];
          if (s != null) project.entities[i] = s;
        }
      },
      invalidateResults: affects,
      label: 'hist.stretch|${changed.length}',
    );
    return changed.length;
  }

  /// Takes out the part of [id] between the points of it nearest to [a]
  /// and [b] (see [breakEntity]); the pieces become the selection. Returns
  /// false, telling why, when it cannot be broken there.
  bool breakBetween(String id, Pt a, Pt b) {
    track('break');
    final e = project.byId(id);
    if (e == null || project.isLocked(e.layer)) return false;
    final placeholders = <String>{};
    final pieces = breakEntity(e, a, b, () {
      final id = '#break${placeholders.length}';
      placeholders.add(id);
      return id;
    });
    if (pieces == null) {
      notify(t('edt.breakFailed'));
      return false;
    }
    final fixed = _withIds(pieces, placeholders);
    if (!_replace([e], fixed, 'hist.break')) return false;
    select(fixed.map((p) => p.id));
    return true;
  }
}
