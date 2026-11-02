/// Review without a server (1.6.0 CAD, PRD-11): what changed between two
/// copies of a project — the items added, removed and changed (matched by
/// id), the settings that differ and the main figures of each (items,
/// lengths, areas and, with design results, flows, pressures and cost) —
/// and the review comments and revision clouds of a copy brought back into
/// the original (matched by id, else by place and text).
library;

import 'dart:convert';

import '../design/results.dart';
import 'entities.dart';
import 'geometry.dart';
import 'project.dart';

enum ChangeKind { added, removed, changed }

/// One item that differs: in [ProjectComparison.after] only (added), in
/// [ProjectComparison.before] only (removed) or in both with other values
/// ([keys]: the fields of the file that differ).
class EntityChange {
  const EntityChange(this.kind, this.id, this.type, this.name, this.bounds, {this.keys = const []});
  final ChangeKind kind;
  final String id;

  /// The item type ([EntityType] name) and name.
  final String type;
  final String name;

  /// Where it is (in the copy that has it; the newer for a change).
  final Bounds bounds;
  final List<String> keys;
}

/// One figure of both copies (null where it does not apply).
class ComparedFigure {
  const ComparedFigure(this.key, this.before, this.after, {this.unit = ''});

  /// What it is: `items`, `pipeLength`, `lateralLength`, `outlets`,
  /// `valves`, `areaHa`, `flow`, `minPressure`, `maxPressure`, `cost`.
  final String key;
  final double? before, after;
  final String unit;
  bool get differs {
    final b = before, a = after;
    return b != a && !(b != null && a != null && (b - a).abs() < 1e-9);
  }
}

class ProjectComparison {
  ProjectComparison(this.before, this.after, this.changes, this.settings, this.figures);
  final Project before, after;
  final List<EntityChange> changes;

  /// The sections of the settings that differ: `meta`, `params`,
  /// `catalog`, `layers`, `systemFlows`, `blocks`.
  final List<String> settings;
  final List<ComparedFigure> figures;

  int count(ChangeKind k) => changes.where((c) => c.kind == k).length;
  bool get isEmpty => changes.isEmpty && settings.isEmpty;

  /// The change of item [id], or null.
  EntityChange? of(String id) {
    for (final c in changes) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// The JSON of [e] without what is not its content (the id).
Map<String, dynamic> _content(Entity e) => e.toJson()..remove('id');

/// What changed from [before] to [after] (see [ProjectComparison]); the
/// results give the figures of the design when both are given.
ProjectComparison compareProjects(Project before, Project after, {DesignResults? beforeResults, DesignResults? afterResults}) {
  final old = {for (final e in before.entities) e.id: e};
  final now = {for (final e in after.entities) e.id: e};
  final changes = <EntityChange>[];
  for (final e in after.entities) {
    final o = old[e.id];
    if (o == null) {
      changes.add(EntityChange(ChangeKind.added, e.id, e.type.name, e.name, e.bounds));
      continue;
    }
    final a = _content(o), b = _content(e);
    final keys = <String>[
      for (final k in {...a.keys, ...b.keys})
        if (jsonEncode(a[k]) != jsonEncode(b[k])) k,
    ];
    if (keys.isNotEmpty) changes.add(EntityChange(ChangeKind.changed, e.id, e.type.name, e.name, e.bounds, keys: keys));
  }
  for (final e in before.entities) {
    if (!now.containsKey(e.id)) changes.add(EntityChange(ChangeKind.removed, e.id, e.type.name, e.name, e.bounds));
  }
  final ja = before.toJson(includeEntities: false), jb = after.toJson(includeEntities: false);
  String part(Map<String, dynamic> j, String k) => switch (k) {
    'meta' => jsonEncode({...(j['meta'] as Map<String, dynamic>)}..remove('modified')),
    _ => jsonEncode(j[k]),
  };
  final settings = [
    for (final k in const ['meta', 'params', 'catalog', 'layers', 'systemFlows', 'blocks'])
      if (part(ja, k) != part(jb, k)) k,
  ];
  return ProjectComparison(before, after, changes, settings, _figures(before, after, beforeResults, afterResults));
}

List<ComparedFigure> _figures(Project a, Project b, DesignResults? ra, DesignResults? rb) {
  double length(Project p, bool Function(Entity e) f) => p.entities.where(f).fold(0.0, (s, e) => s + (e is PolyEntity ? polylineLength(e.points) : 0));
  double count(Project p, bool Function(Entity e) f) => p.entities.where(f).length.toDouble();
  double area(Project p) => p.entities.whereType<AreaEntity>().fold(0.0, (s, e) => s + e.area) / 10000;
  final out = [
    ComparedFigure('items', a.entities.length.toDouble(), b.entities.length.toDouble()),
    ComparedFigure('pipeLength', length(a, (e) => e is PipeEntity), length(b, (e) => e is PipeEntity), unit: 'm'),
    ComparedFigure('lateralLength', length(a, (e) => e is SpraylineEntity || e is TapeEntity), length(b, (e) => e is SpraylineEntity || e is TapeEntity), unit: 'm'),
    ComparedFigure('outlets', count(a, (e) => e is OutletEntity), count(b, (e) => e is OutletEntity)),
    ComparedFigure('valves', count(a, (e) => e is ControlValveEntity), count(b, (e) => e is ControlValveEntity)),
    ComparedFigure('areaHa', area(a), area(b), unit: 'ha'),
  ];
  if (ra != null || rb != null) {
    double? flow(DesignResults? r) => r == null || r.systemFlows.isEmpty ? null : r.systemFlows.map((f) => f.totalFlow).reduce((x, y) => x > y ? x : y) * 3600;
    double? minP(DesignResults? r) => r == null || r.zones.isEmpty ? null : r.zones.values.map((z) => z.minOutletPressure).reduce((x, y) => x < y ? x : y);
    double? maxP(DesignResults? r) => r == null || r.zones.isEmpty ? null : r.zones.values.map((z) => z.maxOutletPressure).reduce((x, y) => x > y ? x : y);
    double? cost(DesignResults? r) => r?.bom.fold<double>(0, (s, l) => s + l.total);
    out.addAll([
      ComparedFigure('flow', flow(ra), flow(rb), unit: 'm³/h'),
      ComparedFigure('minPressure', minP(ra), minP(rb), unit: 'm'),
      ComparedFigure('maxPressure', maxP(ra), maxP(rb), unit: 'm'),
      ComparedFigure('cost', cost(ra), cost(rb)),
    ]);
  }
  return out;
}

// ---------------------------------------------------------------- comments of a copy

/// What [mergeReview] did.
class ReviewMerge {
  int added = 0, updated = 0, unchanged = 0;

  /// The ids of the items added and updated.
  final List<String> ids = [];
  bool get isEmpty => added == 0 && updated == 0;
}

/// The review comments and revision clouds of [from] (a copy sent for
/// review and returned) brought into [into]: an item of the same id is
/// updated to the copy's text, state and photo (its place too); one of the
/// same kind at the same place (within [tol] metres) with the same text is
/// already there; the others are added with new ids of [into]. Changes
/// [into] in place.
ReviewMerge mergeReview(Project into, Project from, {double tol = 0.5}) {
  final out = ReviewMerge();
  final byId = {for (final e in into.entities) e.id: e};
  for (final e in from.entities) {
    if (e is! CommentEntity && e is! RevisionCloudEntity) continue;
    final same = byId[e.id];
    if (same != null && same.runtimeType == e.runtimeType) {
      if (jsonEncode(_content(same)) == jsonEncode(_content(e))) {
        out.unchanged++;
        continue;
      }
      into.entities[into.entities.indexOf(same)] = e.clone();
      out.updated++;
      out.ids.add(e.id);
      continue;
    }
    final twin = into.entities.any(
      (x) => switch ((x, e)) {
        (CommentEntity a, CommentEntity b) => a.position.distanceTo(b.position) <= tol && a.text.trim() == b.text.trim(),
        (RevisionCloudEntity a, RevisionCloudEntity b) => a.revision == b.revision && a.bounds.center.distanceTo(b.bounds.center) <= tol,
        _ => false,
      },
    );
    if (twin) {
      out.unchanged++;
      continue;
    }
    final copy = e.clone(newId: into.newId());
    if (into.findLayer(copy.layer) == null) into.layerNamed(copy.layer);
    into.entities.add(copy);
    out.added++;
    out.ids.add(copy.id);
  }
  return out;
}
