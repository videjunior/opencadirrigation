/// Design check: a sweep of the drawing looking
/// for the errors that make a hydraulic design fail or mislead before it is
/// run: disconnected items, dead ends, pipes crossing without a junction,
/// zones without valves or emitters, duplicated items, missing catalogue
/// data, missing terrain and looped networks (informational).
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'network_builder.dart';

enum CheckSeverity { error, warning, info }

class CheckIssue {
  const CheckIssue(this.code, this.severity, {this.entityIds = const [], this.at, this.value = ''});

  /// Message key (translated as `check.<code>`).
  final String code;
  final CheckSeverity severity;
  final List<String> entityIds;

  /// Where to zoom (null: use the first entity).
  final Pt? at;

  /// Extra text appended to the message (count, name…).
  final String value;

  Map<String, dynamic> toJson() => {'code': code, 'sev': severity.name, 'ids': entityIds, if (at != null) 'at': at!.toList(), if (value.isNotEmpty) 'v': value};
}

class DesignCheckReport {
  DesignCheckReport(this.issues);
  final List<CheckIssue> issues;
  int get errors => issues.where((i) => i.severity == CheckSeverity.error).length;
  int get warnings => issues.where((i) => i.severity == CheckSeverity.warning).length;
  bool get ok => errors == 0;
}

/// Runs every check on [project].
DesignCheckReport runDesignCheck(Project project) {
  final issues = <CheckIssue>[];
  final ents = project.entities;
  final cat = project.catalog;
  final tol = math.max(project.params.connectTolerance, 1e-3);

  final supplies = ents.whereType<WaterSupplyEntity>().toList();
  final valves = ents.whereType<ControlValveEntity>().toList();
  final pivots = ents.whereType<PivotEntity>().toList();
  final hydraulic = ents.where((e) => e.isHydraulic || e is PivotEntity).toList();
  if (hydraulic.isEmpty) {
    issues.add(const CheckIssue('no_hydraulics', CheckSeverity.info));
    return DesignCheckReport(issues);
  }
  if (supplies.isEmpty) issues.add(const CheckIssue('no_supply', CheckSeverity.error));
  if (valves.isEmpty && pivots.isEmpty && ents.any((e) => e is SpraylineEntity || e is TapeEntity || (e is OutletEntity && e.scope == HydraulicScope.zone))) {
    issues.add(const CheckIssue('no_valves', CheckSeverity.error));
  }

  // ---- connectivity from the network builder
  final model = NetworkBuilder(project).build();
  for (final id in model.unconnectedEntities) {
    final e = project.byId(id);
    if (e == null) continue;
    issues.add(CheckIssue('unconnected', CheckSeverity.error, entityIds: [id], value: _kind(e)));
  }
  for (final w in model.warnings) {
    final idx = w.indexOf(':');
    final code = idx > 0 ? w.substring(0, idx) : w;
    final rest = idx > 0 ? w.substring(idx + 1) : '';
    final ids = rest.isEmpty ? const <String>[] : rest.split(':');
    issues.add(CheckIssue(code, code.contains('missing') ? CheckSeverity.error : CheckSeverity.warning, entityIds: ids));
  }

  // ---- zones without emitters
  for (final v in valves) {
    final nodes = model.zoneNodes[v.id] ?? const <String>{};
    final emitters = nodes.fold<int>(0, (s, id) => s + (model.nodes[id]?.emitters.length ?? 0));
    if (nodes.length > 1 && emitters == 0) issues.add(CheckIssue('zone_no_emitters', CheckSeverity.error, entityIds: [v.id], value: v.zoneName));
  }
  // ---- duplicated zone names
  final byName = <String, List<String>>{};
  for (final v in valves) {
    byName.putIfAbsent(v.zoneName.trim().toLowerCase(), () => []).add(v.id);
  }
  for (final e in byName.entries) {
    if (e.key.isNotEmpty && e.value.length > 1) issues.add(CheckIssue('duplicate_zone_name', CheckSeverity.warning, entityIds: e.value, value: project.byId(e.value.first)?.name ?? e.key));
  }

  // ---- dead ends on the mainline (pipe end with nothing attached)
  for (final n in model.nodes.values) {
    if (!model.mainlineNodes.contains(n.id)) continue;
    if (n.links.length != 1 || n.isSupply || n.emitters.isNotEmpty) continue;
    final hasItem = n.entityIds.any((id) {
      final e = project.byId(id);
      return e is ControlValveEntity || e is OutletEntity || e is PivotEntity || e is WaterSupplyEntity;
    });
    if (hasItem) continue;
    final pipeIds = n.entityIds.where((id) => project.byId(id) is PipeEntity).toList();
    issues.add(CheckIssue('mainline_dead_end', CheckSeverity.warning, entityIds: pipeIds, at: n.p));
  }
  // ---- zone pipe dead ends (submain ending with no lateral)
  for (final n in model.nodes.values) {
    if (n.scope != HydraulicScope.zone || n.zoneId == null) continue;
    if (n.links.length != 1 || n.emitters.isNotEmpty) continue;
    final onlyPipes = n.entityIds.every((id) => project.byId(id) is PipeEntity);
    if (!onlyPipes || n.entityIds.isEmpty) continue;
    issues.add(CheckIssue('zone_dead_end', CheckSeverity.info, entityIds: n.entityIds.toList(), at: n.p));
  }

  // ---- zero-length / tiny segments
  for (final e in ents) {
    if (e is! PolyEntity || !e.isLinearHydraulic) continue;
    final pts = e.points;
    if (pts.length < 2 || polylineLength(pts) < tol) {
      issues.add(CheckIssue('zero_length', CheckSeverity.error, entityIds: [e.id]));
      continue;
    }
    for (var i = 1; i < pts.length; i++) {
      if (pts[i - 1].distanceTo(pts[i]) < tol) {
        issues.add(CheckIssue('tiny_segment', CheckSeverity.warning, entityIds: [e.id], at: pts[i]));
        break;
      }
    }
  }

  // ---- duplicated point items at the same position
  final points = <(Entity, Pt)>[];
  for (final e in ents) {
    if (e is PointEntity && e.isHydraulic) points.add((e, e.position));
    if (e is PivotEntity) points.add((e, e.center));
  }
  final seenPairs = <String>{};
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      final (a, pa) = points[i];
      final (b, pb) = points[j];
      if (a.runtimeType != b.runtimeType) continue;
      if (pa.distanceTo(pb) <= tol && seenPairs.add('${a.id}|${b.id}')) {
        issues.add(CheckIssue('duplicate_item', CheckSeverity.warning, entityIds: [a.id, b.id], at: pa, value: _kind(a)));
      }
    }
  }

  // ---- pipes crossing without a junction (same scope)
  final linear = ents.where((e) => e.isLinearHydraulic).toList();
  var comparisons = 0;
  final crossings = <String>{};
  for (var i = 0; i < linear.length && comparisons < 3000000; i++) {
    final a = linear[i];
    final ba = a.bounds.inflate(tol);
    final pa = (a as PolyEntity).points;
    for (var j = i + 1; j < linear.length && comparisons < 3000000; j++) {
      final b = linear[j];
      if (a.hydraulicScope != b.hydraulicScope) continue;
      if (!ba.intersects(b.bounds.inflate(tol))) continue;
      final pb = (b as PolyEntity).points;
      for (var s = 1; s < pa.length; s++) {
        for (var t = 1; t < pb.length; t++) {
          comparisons++;
          final x = segmentIntersection(pa[s - 1], pa[s], pb[t - 1], pb[t]);
          if (x == null) continue;
          // interior of both segments (not touching at a vertex / T-junction)
          final nearA = pa[s - 1].distanceTo(x) <= tol || pa[s].distanceTo(x) <= tol;
          final nearB = pb[t - 1].distanceTo(x) <= tol || pb[t].distanceTo(x) <= tol;
          if (nearA || nearB) continue;
          // a junction / valve exactly there makes it a real connection
          final hasNode = points.any((p) => p.$2.distanceTo(x) <= tol);
          if (hasNode) continue;
          if (crossings.add('${a.id}|${b.id}')) issues.add(CheckIssue('pipes_cross', CheckSeverity.warning, entityIds: [a.id, b.id], at: x));
        }
      }
    }
  }

  // ---- catalogue data
  for (final e in ents) {
    switch (e) {
      case PipeEntity p when p.pipeSpecId != null && cat.pipe(p.pipeSpecId) == null:
        issues.add(CheckIssue('spec_missing', CheckSeverity.error, entityIds: [e.id], value: p.pipeSpecId!));
      case ControlValveEntity v when v.valveSpecId != null && cat.valve(v.valveSpecId) == null:
        issues.add(CheckIssue('spec_missing', CheckSeverity.error, entityIds: [e.id], value: v.valveSpecId!));
      case PumpEntity p when cat.pump(p.pumpSpecId) == null:
        issues.add(CheckIssue('spec_missing', CheckSeverity.error, entityIds: [e.id], value: p.pumpSpecId ?? '-'));
      case PivotEntity p when p.pipeSpecId != null && cat.pipe(p.pipeSpecId) == null:
        issues.add(CheckIssue('spec_missing', CheckSeverity.error, entityIds: [e.id], value: p.pipeSpecId!));
      default:
        break;
    }
  }
  // ---- supplies
  for (final s in supplies) {
    if (!s.calculatePressure && s.designHeadM <= 0) issues.add(CheckIssue('supply_no_head', CheckSeverity.warning, entityIds: [s.id]));
  }
  // ---- pivots need a mainline connection
  for (final p in pivots) {
    final n = model.pivotNodes[p.id];
    if (n == null || !model.mainlineNodes.contains(n)) issues.add(CheckIssue('pivot_unconnected', CheckSeverity.error, entityIds: [p.id]));
  }
  // ---- terrain
  if (!ents.any((e) => e is ContourEntity || e is SpotHeightEntity)) issues.add(const CheckIssue('no_terrain', CheckSeverity.info));
  // ---- looped mainline (informational: solved by the network solver)
  final mlNodes = model.mainlineNodes.length;
  final mlLinks = model.mainlineLinks.where((l) => model.linkById(l)?.kind == GLinkKind.pipe).length;
  if (mlNodes > 0 && mlLinks >= mlNodes) issues.add(CheckIssue('looped_mainline', CheckSeverity.info, value: '${mlLinks - mlNodes + 1}'));
  // ---- areas without emitters
  for (final a in ents.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    final any = ents.any((e) => (e is OutletEntity && pointInPolygon(e.position, a.points)) || ((e is SpraylineEntity || e is TapeEntity) && (e as PolyEntity).points.any((p) => pointInPolygon(p, a.points))) || (e is PivotEntity && pointInPolygon(e.center, a.points)));
    if (!any) issues.add(CheckIssue('area_no_emitters', CheckSeverity.info, entityIds: [a.id], value: a.name));
  }
  // errors first
  const order = {CheckSeverity.error: 0, CheckSeverity.warning: 1, CheckSeverity.info: 2};
  issues.sort((a, b) => order[a.severity]!.compareTo(order[b.severity]!));
  return DesignCheckReport(issues);
}

String _kind(Entity e) => e.type.name;
