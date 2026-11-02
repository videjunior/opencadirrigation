/// Design check: a sweep of the drawing looking
/// for the errors that make a hydraulic design fail or mislead before it is
/// run: disconnected items, dead ends, pipes crossing without a junction,
/// zones without valves or emitters, duplicated items, missing catalogue
/// data, missing terrain and looped networks (informational).
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'auto_layout.dart' show LayoutRegion, evaluateSprayUniformity, polygonSelfCrossings;
import 'densogram.dart' show SpraySource, spraySources;
import 'electrical.dart';
import 'network_builder.dart';
import 'valve_in_head.dart';

enum CheckSeverity { error, warning, info }

/// Heads of one zone whose water per wetted area (flow over the sector they
/// wet, at the nominal pressure) differs by more than this factor do not
/// share a run time (sprays with rotors, part circles without matched
/// nozzles: precipitation classes of irrigation-association zoning practice).
const mixedRateRatio = 1.8;

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
    // 1.6.0 AUT: an area crossing itself is wrong before any pipe is drawn
    issues
      ..addAll(checkSelfCrossingAreas(project))
      ..add(const CheckIssue('no_hydraulics', CheckSeverity.info));
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
    // 1.6.0 AUT: zones joined without a valve are an error (the last valve
    // takes the other zone's nodes and both zones come out wrong)
    issues.add(CheckIssue(code, code.contains('missing') || code == 'zone_overlap' ? CheckSeverity.error : CheckSeverity.warning, entityIds: ids));
  }

  // ---- zones without emitters
  for (final v in valves) {
    final nodes = model.zoneNodes[v.id] ?? const <String>{};
    final emitters = nodes.fold<int>(0, (s, id) => s + (model.nodes[id]?.emitters.length ?? 0));
    if (nodes.length > 1 && emitters == 0) issues.add(CheckIssue('zone_no_emitters', CheckSeverity.error, entityIds: [v.id], value: v.zoneName));
  }
  // ---- zones mixing drip with overhead emitters, or emitters that apply
  // water at very different rates (sprays with rotors, part circles without
  // matched nozzles, tapes of 1 and 2 L/h, or 20 and 40 cm apart): one valve
  // cannot water them all right. 1.6.0 AUT: the rate of every emitter is its
  // flow over the ground it serves: a head its sector of the square of the
  // distance to its nearest neighbour in the zone (within half and twice its
  // own throw), a sprinkler of a spray line the outlet spacing by the
  // distance to the next line, a tape the emitter spacing by the distance to
  // the next tape, a dripper the square of the distance to the next one
  for (final v in valves) {
    final families = <bool>{}; // true = drip and bubblers, false = overhead
    final heads = <(Pt, double, double, double)>[]; // position, flow, radius, arc
    final lines = <String, (SpraylineEntity, double, double, double)>{}; // flow, radius, arc
    final tapes = <String, TapeEntity>{};
    final drippers = <(Pt, double)>[];
    for (final id in model.zoneNodes[v.id] ?? const <String>{}) {
      for (final em in model.nodes[id]?.emitters ?? const <EmitterRef>[]) {
        if (em.index == -2) continue; // open tape end of the flushing model
        final e = project.byId(em.entityId);
        final (specId, nozzleId, arc) = switch (e) {
          OutletEntity o => (o.outletSpecId, o.nozzleId, o.arcDeg),
          SpraylineEntity sl => (sl.outletSpecId, sl.nozzleId, sl.arcDeg),
          _ => (null, null, 360.0),
        };
        final spec = cat.outlet(specId);
        final kind = e is TapeEntity ? OutletKind.dripper : spec?.kind;
        if (kind == null || kind == OutletKind.demandPoint) continue;
        final drip = kind == OutletKind.dripper || kind == OutletKind.bubbler;
        families.add(drip);
        final q = em.curve.flow(em.nominalHead);
        if (drip) {
          if (e is TapeEntity) tapes[e.id] = e;
          if (e is OutletEntity && q > 0) drippers.add((e.position, q));
          continue;
        }
        final r = em.curve.radius(em.nominalHead);
        if (r <= 0 || q <= 0) continue;
        final a = (spec?.nozzle(nozzleId)?.effectiveArcDeg(arc) ?? arc).clamp(1.0, 360.0).toDouble();
        if (e is OutletEntity) heads.add((e.position, q, r, a));
        if (e is SpraylineEntity) lines[e.id] = (e, q, r, a);
      }
    }
    final rates = <double>[], dripRates = <double>[];
    for (final (p, q, r, a) in heads) {
      var nn = double.infinity;
      for (final (o, _, _, _) in heads) {
        final d = o.distanceTo(p);
        if (d > 1e-6 && d < nn) nn = d;
      }
      final s = nn.isFinite ? nn.clamp(0.5 * r, 2 * r).toDouble() : r;
      rates.add(q / (s * s * a / 360));
    }
    double nearestLine(PolyEntity l, Iterable<PolyEntity> others) {
      if (l.points.length < 2) return double.infinity;
      final mid = pointAlongPolyline(l.points, polylineLength(l.points) / 2);
      var best = double.infinity;
      for (final o in others) {
        if (identical(o, l) || o.points.length < 2) continue;
        for (var i = 1; i < o.points.length; i++) {
          best = math.min(best, distanceToSegment(mid, o.points[i - 1], o.points[i]));
        }
      }
      return best;
    }

    for (final (l, q, r, a) in lines.values) {
      final across = nearestLine(l, [for (final x in lines.values) x.$1]);
      final s = across.isFinite ? across.clamp(0.5 * r, 2 * r).toDouble() : r;
      if (l.spacing > 0) rates.add(q / (l.spacing * s * a / 360));
    }
    for (final t in tapes.values) {
      final spec = cat.tape(t.tapeSpecId);
      if (spec == null || !(spec.emitterSpacingM > 0)) continue;
      final across = nearestLine(t, tapes.values);
      if (!across.isFinite || across < 0.05) continue;
      dripRates.add(spec.emitter.flow(t.inletHeadM) / (spec.emitterSpacingM * across));
    }
    for (final (p, q) in drippers) {
      var nn = double.infinity;
      for (final (o, _) in drippers) {
        final d = o.distanceTo(p);
        if (d > 1e-6 && d < nn) nn = d;
      }
      if (nn.isFinite) dripRates.add(q / math.max(0.25, nn * nn));
    }
    bool spread(List<double> xs) => xs.length >= 2 && xs.reduce(math.max) > mixedRateRatio * xs.reduce(math.min);
    if (families.length > 1 || spread(rates) || spread(dripRates)) {
      issues.add(CheckIssue('zone_mixed_emitters', CheckSeverity.warning, entityIds: [v.id], value: v.zoneName));
    }
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
    // laterals are sampled along their length: their ends often sit on the
    // outline or outside it (a tape fed from a header beside the bed)
    bool lateralInside(List<Pt> pts) {
      if (pts.any((p) => pointInPolygon(p, a.points))) return true;
      final total = polylineLength(pts);
      for (var i = 0; i < 20; i++) {
        if (pointInPolygon(pointAlongPolyline(pts, total * (i + 0.5) / 20), a.points)) return true;
      }
      return false;
    }

    final any = ents.any(
      (e) =>
          (e is OutletEntity && project.outletWatersArea(e, a.points)) ||
          ((e is SpraylineEntity || e is TapeEntity) && lateralInside((e as PolyEntity).points)) ||
          (e is PivotEntity && watersArea(e.center, a.points)),
    );
    if (!any) issues.add(CheckIssue('area_no_emitters', CheckSeverity.info, entityIds: [a.id], value: a.name));
  }
  // ---- valve wiring (routes, stations, solenoid voltage), when drawn
  // as in the design: without system flows every zone runs at once, and
  // every flow runs the valve-in-head stations it schedules or no flow does
  final vih = VihStations.of(project);
  final wiring = designElectrical(
    project,
    flows: project.systemFlows.isEmpty
        ? [
            {for (final v in valves) v.id, ...vih.heads.keys},
          ]
        : [
            for (final f in project.systemFlows) {...f.valveIds, ...vih.runningIn(f.valveIds)},
          ],
  );
  for (final w in wiring?.warnings ?? const <String>[]) {
    final idx = w.indexOf(':');
    final code = idx > 0 ? w.substring(0, idx) : w;
    // the unwired heads of a valve-in-head station come in one message
    final ids = idx > 0 ? w.substring(idx + 1).split(':') : const <String>[];
    issues.add(CheckIssue(code, code == 'elec_stations' || code == 'elec_voltage' ? CheckSeverity.error : CheckSeverity.warning, entityIds: ids));
  }
  // 1.6.0 AUT: outlines that cross themselves, overlapping pipes and laterals
  issues.addAll(checkSelfCrossingAreas(project));
  issues.addAll(checkOverlappingLines(project, tol));
  // 1.6.0 AUT: sprinklers spaced too far apart, areas watered unevenly
  final sprinklers = _sprinklerSources(project);
  issues.addAll(checkSprinklerSpacing(project, model, sources: sprinklers));
  issues.addAll(checkAreaUniformity(project, sources: sprinklers));
  // errors first
  const order = {CheckSeverity.error: 0, CheckSeverity.warning: 1, CheckSeverity.info: 2};
  issues.sort((a, b) => order[a.severity]!.compareTo(order[b.severity]!));
  return DesignCheckReport(issues);
}

String _kind(Entity e) => e.type.name;

// ---------------------------------------------------------------- 1.6.0 AUT

/// Irrigated areas whose outline crosses itself (a bow tie made by
/// dragging a grip across another side, an outline read from a file): their
/// area, and so the water they need, would come out wrong.
List<CheckIssue> checkSelfCrossingAreas(Project project) => [
  for (final a in project.entities.whereType<AreaEntity>())
    if (a.points.length >= 4)
      if (polygonSelfCrossings(a.points) case final x when x.isNotEmpty) CheckIssue('area_self_intersect', CheckSeverity.error, entityIds: [a.id], at: x.first, value: a.name),
];

/// Pipes, laterals and tapes of one scope that run on top of each other for
/// more than [tol] (a pipe pasted twice, two pipes drawn over the same
/// stretch, a lateral that doubles back on itself): the design would take
/// them as pipes in parallel (too little friction) and the bill of
/// materials would count them twice. The segments are bucketed on a grid.
List<CheckIssue> checkOverlappingLines(Project project, double tol) {
  final lines = <PolyEntity>[
    for (final e in project.entities)
      if (e.isLinearHydraulic && e is PolyEntity && e.points.length >= 2) e,
  ];
  final segs = <(Pt, Pt, int, int)>[]; // a, b, line, segment
  var b = Bounds.empty;
  var total = 0.0;
  for (var k = 0; k < lines.length; k++) {
    final pts = lines[k].points;
    for (var i = 1; i < pts.length; i++) {
      if (pts[i - 1].distanceTo(pts[i]) <= 1e-9) continue;
      segs.add((pts[i - 1], pts[i], k, i));
      b = b.include(pts[i - 1]).include(pts[i]);
      total += pts[i - 1].distanceTo(pts[i]);
    }
  }
  if (segs.length < 2) return const [];
  final cell = math.max(total / segs.length, math.max(b.width, b.height) / 512) + 1e-9;
  final buckets = <int, List<int>>{};
  int key(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);
  for (var s = 0; s < segs.length; s++) {
    final (p, q, _, _) = segs[s];
    final x0 = ((math.min(p.x, q.x) - b.minX - tol) / cell).floor(), x1 = ((math.max(p.x, q.x) - b.minX + tol) / cell).floor();
    final y0 = ((math.min(p.y, q.y) - b.minY - tol) / cell).floor(), y1 = ((math.max(p.y, q.y) - b.minY + tol) / cell).floor();
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 65536) continue;
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        (buckets[key(ix, iy)] ??= []).add(s);
      }
    }
  }
  final found = <String, (List<String>, Pt)>{};
  final tested = <int>{};
  for (final list in buckets.values) {
    for (var x = 0; x < list.length; x++) {
      for (var y = x + 1; y < list.length; y++) {
        final s1 = list[x], s2 = list[y];
        if (!tested.add(s1 * segs.length + s2)) continue;
        final (a, c, l1, i1) = segs[s1];
        final (d0, d1, l2, i2) = segs[s2];
        final e1 = lines[l1] as Entity, e2 = lines[l2] as Entity;
        if (e1.hydraulicScope != e2.hydraulicScope) continue;
        if (l1 == l2 && i1 == i2) continue;
        final r = c - a;
        final len = r.length;
        // collinear: both ends of the second segment on the first one's line
        if ((d0 - a).cross(r).abs() / len > tol || (d1 - a).cross(r).abs() / len > tol) continue;
        final t0 = (d0 - a).dot(r) / len, t1 = (d1 - a).dot(r) / len;
        final lo = math.max(0.0, math.min(t0, t1)), hi = math.min(len, math.max(t0, t1));
        if (hi - lo <= tol) continue;
        final ids = [e1.id, e2.id]..sort();
        final at = a + r * ((lo + hi) / 2 / len);
        found.putIfAbsent(ids.toSet().join('|'), () => (ids.toSet().toList(), at));
      }
    }
  }
  return [for (final (ids, at) in found.values) CheckIssue('pipes_overlap', CheckSeverity.warning, entityIds: ids, at: at)];
}

/// Largest sprinkler spacing, as a share of the wetted diameter, of zones
/// whose heads form a square-like grid (or a triangle), and the limits of a
/// rectangular one (the smaller and the larger spacing): head to head is
/// 50 %; Keller & Bliesner (1990, table 5.2) allow about 55–60 % square and
/// 50–55 × 60–65 % rectangular in light wind, less as it blows.
const spacingLimitSquare = 0.60, spacingLimitNarrow = 0.55, spacingLimitWide = 0.65;

/// The two spacings of a grid of heads: the median distance of a head to
/// its nearest neighbour, and to its nearest neighbour across that
/// direction (60° to 120° from it); the second is null for a single row.
(double, double?) gridSpacings(List<Pt> heads) {
  if (heads.length < 2) return (0, null);
  final b = Bounds.ofPoints(heads);
  final cell = math.max(math.sqrt(math.max(b.width * b.height, 1e-6) / heads.length), math.max(b.width, b.height) / heads.length) + 1e-9;
  final buckets = <int, List<int>>{};
  int key(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);
  for (var i = 0; i < heads.length; i++) {
    (buckets[key(((heads[i].x - b.minX) / cell).floor(), ((heads[i].y - b.minY) / cell).floor())] ??= []).add(i);
  }
  final along = <double>[], across = <double>[];
  for (var i = 0; i < heads.length; i++) {
    final q = heads[i];
    final ix = ((q.x - b.minX) / cell).floor(), iy = ((q.y - b.minY) / cell).floor();
    // the neighbours within three cells, the nearest first
    final near = <(double, Pt)>[];
    for (var dx = -3; dx <= 3; dx++) {
      for (var dy = -3; dy <= 3; dy++) {
        for (final j in buckets[key(ix + dx, iy + dy)] ?? const <int>[]) {
          if (j != i && heads[j].distanceTo(q) > 1e-6) near.add((heads[j].distanceTo(q), heads[j] - q));
        }
      }
    }
    if (near.isEmpty) continue;
    near.sort((x, y) => x.$1.compareTo(y.$1));
    final (d1, v1) = near.first;
    along.add(d1);
    for (final (d, v) in near.skip(1)) {
      final c = (v.dot(v1) / (v.length * v1.length)).abs();
      if (c <= 0.5) {
        across.add(d);
        break;
      }
    }
  }
  double median(List<double> xs) => (xs..sort())[xs.length ~/ 2];
  if (along.isEmpty) return (0, null);
  return (median(along), across.length * 2 >= along.length ? median(across) : null);
}

/// Sprinklers of [project] (sprays, rotors, impact sprinklers and guns; not
/// micro-sprinklers, which wet part of the ground by design) as wetted
/// sectors at their nominal pressures.
List<SpraySource> _sprinklerSources(Project project) {
  final cat = project.catalog;
  return [
    for (final s in spraySources(project, measured: true))
      if (switch (project.byId(s.entityId)) {
            OutletEntity o => cat.outlet(o.outletSpecId)?.kind,
            SpraylineEntity l => cat.outlet(l.outletSpecId)?.kind,
            _ => null,
          }
          case OutletKind.sprinkler || OutletKind.gun)
        s,
  ];
}

String _pct(double v) => '${(v * 100).round()} %';

String _m(double v) => v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Zones whose full-circle sprinklers stand farther apart than their throw allows
/// ([spacingLimitSquare], [spacingLimitNarrow], [spacingLimitWide]): dry
/// spots between them that no run time makes up. The value gives the
/// spacings, the wetted radius and the share of the diameter.
List<CheckIssue> checkSprinklerSpacing(Project project, NetworkModel model, {List<SpraySource>? sources}) {
  sources ??= _sprinklerSources(project);
  if (sources.length < 3) return const [];
  final byEntity = <String, List<SpraySource>>{};
  for (final s in sources) {
    (byEntity[s.entityId] ??= []).add(s);
  }
  final out = <CheckIssue>[];
  for (final v in project.entities.whereType<ControlValveEntity>()) {
    final ids = <String>{
      for (final id in model.zoneNodes[v.id] ?? const <String>{})
        for (final em in model.nodes[id]?.emitters ?? const <EmitterRef>[]) em.entityId,
    };
    // the full circles: part circles stand on the edges, where the width of
    // the area, not a grid, sets how far they are from each other (the
    // uniformity check of the area judges those)
    final zone = [
      for (final id in ids)
        for (final s in byEntity[id] ?? const <SpraySource>[])
          if (s.fullCircle) s,
    ];
    if (zone.length < 3) continue;
    final radii = [for (final s in zone) s.radius]..sort();
    final r = radii[radii.length ~/ 2];
    if (!(r > 0)) continue;
    final (s1, s2) = gridSpacings([for (final s in zone) s.p]);
    if (!(s1 > 0)) continue;
    final small = s2 == null ? s1 : math.min(s1, s2), large = s2 == null ? s1 : math.max(s1, s2);
    final square = large <= 1.15 * small;
    final d = 2 * r;
    final wide = square ? large > spacingLimitSquare * d + 1e-9 : (small > spacingLimitNarrow * d + 1e-9 || large > spacingLimitWide * d + 1e-9);
    if (!wide) continue;
    final limit = square ? spacingLimitSquare * d : spacingLimitWide * d;
    out.add(
      CheckIssue(
        'zone_spacing_wide',
        CheckSeverity.warning,
        entityIds: [v.id],
        at: v.position,
        value: '${v.zoneName}: ${s2 == null ? _m(s1) : '${_m(small)} × ${_m(large)}'} m, R ${_m(r)} m (${_pct(large / d)} D; ≤ ${_m(limit)} m)',
      ),
    );
  }
  return out;
}

/// Irrigated areas their sprinklers water unevenly: the densogram of the
/// sprinklers at their nominal pressures over the area (every head that
/// throws onto it, of any zone) with a Christiansen CU below 75 %, a
/// low-quarter DU below 60 % or more than 5 % of it getting less than half
/// the mean. Areas a crop wets in part ([AreaEntity.wettedFraction] below
/// 0.95) are left out.
List<CheckIssue> checkAreaUniformity(Project project, {List<SpraySource>? sources}) {
  final areas = [
    for (final a in project.entities.whereType<AreaEntity>())
      if (a.points.length >= 3 && a.wettedFraction >= 0.95) a,
  ];
  if (areas.isEmpty) return const [];
  sources ??= _sprinklerSources(project);
  if (sources.isEmpty) return const [];
  final out = <CheckIssue>[];
  for (final a in areas) {
    final box = Bounds.ofPoints(a.points);
    final near = [
      for (final s in sources)
        if (Bounds(s.p.x - s.radius, s.p.y - s.radius, s.p.x + s.radius, s.p.y + s.radius).intersects(box)) s,
    ];
    if (near.length < 2) continue;
    final region = LayoutRegion(a.points);
    if (region.isEmpty) continue;
    // a quarter of the shortest throw, no coarser than a tenth of the area's
    // size (the check runs after every edit: no inscribed-circle search)
    final minR = near.fold(double.infinity, (m, s) => math.min(m, s.radius));
    final cell = math.max(0.05, math.min(minR / 4, math.sqrt(region.area) / 10));
    final m = evaluateSprayUniformity(region, near, cellSize: cell, maxCells: 40000);
    if (m.heads == 0 || m.areaM2 <= 0) continue;
    if (m.cu >= 75 && m.du >= 60 && m.dryPct <= 5) continue;
    out.add(
      CheckIssue(
        'area_uniformity_low',
        CheckSeverity.warning,
        entityIds: [a.id],
        value: '${a.name.isEmpty ? '' : '${a.name}: '}CU ${m.cu.toStringAsFixed(1)} % · DU ${m.du.toStringAsFixed(1)} % · ${m.dryPct.toStringAsFixed(1)} %',
      ),
    );
  }
  return out;
}
