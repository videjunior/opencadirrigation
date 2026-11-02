/// Travelling-gun lanes and furrow sets as parts of the design: what each
/// one asks of the mainline at its inlet (flow and pressure head), its times
/// and depths, and the pressure the design leaves there.
///
/// * Lane (`traveller.dart`, NRCS NEH 623 ch. 11): the gun of the catalogue
///   at its pressure (or the flow and wetted diameter typed), the lane
///   spacing of the wind table unless given, the speed of the target depth
///   d = q/(S·v), the travel and set-up times, the hose friction and the
///   head at the hydrant H = gun pressure + hose friction + drive loss +
///   gun height + the rise of the ground from the hydrant to the far end.
/// * Furrow set (`surface_irrigation.dart`, FAO 45 volume balance;
///   `gated_pipe.dart`): the inflow of the highest application efficiency
///   (or the one given) with its cutoff for the depth, the furrows irrigated
///   together, the sets and the time of an irrigation; the gated pipe of the
///   farthest set (its whole length carries the set flow) gives the head at
///   the inlet, a head ditch none.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';
import 'gated_pipe.dart';
import 'results.dart';
import 'surface_irrigation.dart';
import 'traveller.dart';

/// Head (m) a head ditch needs at its inlet (the water level over the siphons).
const ditchInletHeadM = 0.3;

/// One lane analysed.
class TravellerLaneResult {
  TravellerLaneResult({
    required this.laneId,
    required this.name,
    required this.machine,
    required this.flow,
    required this.wettedDiameterM,
    required this.gunPressureM,
    required this.groundRiseM,
    required this.result,
    this.availableHead,
  });
  final String laneId;
  final String name;
  final String machine;

  /// Gun flow (m³/s), wetted diameter (m) and pressure (m) used.
  final double flow;
  final double wettedDiameterM;
  final double gunPressureM;

  /// Rise of the ground from the hydrant to the far end (m).
  final double groundRiseM;
  final TravellerResult result;

  /// Pressure head the design leaves at the hydrant (m; the least of the
  /// system flows that run the lane), null without results.
  double? availableHead;

  double get requiredHead => result.inletHeadM;
  double get deficit => availableHead == null ? 0 : requiredHead - availableHead!;

  Map<String, dynamic> toJson() => {
    'id': laneId,
    'name': name,
    'mach': machine,
    'q': flow,
    'dw': wettedDiameterM,
    'hg': gunPressureM,
    'rise': groundRiseM,
    'r': result.toJson(),
    if (availableHead != null) 'h': availableHead,
  };
  static TravellerLaneResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return TravellerLaneResult(
      laneId: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      machine: j['mach'] as String? ?? '',
      flow: d('q'),
      wettedDiameterM: d('dw'),
      gunPressureM: d('hg'),
      groundRiseM: d('rise'),
      result: TravellerResult.fromJson((j['r'] as Map).cast<String, dynamic>()),
      availableHead: (j['h'] as num?)?.toDouble(),
    );
  }
}

/// One furrow set analysed.
class FurrowSetResult {
  FurrowSetResult({
    required this.setId,
    required this.name,
    required this.furrows,
    required this.perSet,
    required this.sets,
    required this.inflow,
    required this.setFlow,
    required this.advanceS,
    required this.cutoffS,
    required this.efficiency,
    required this.lowQuarterDu,
    required this.tailwaterRatio,
    required this.deepPercolationRatio,
    required this.inletHeadM,
    required this.frictionLossM,
    required this.gateCu,
    this.warnings = const [],
    this.availableHead,
  });
  final String setId;
  final String name;

  /// Furrows along the head line, irrigated together, and the sets.
  final int furrows;
  final int perSet;
  final int sets;

  /// Inflow of a furrow and of a set (m³/s).
  final double inflow;
  final double setFlow;

  /// Advance to the end and cutoff time (s).
  final double advanceS;
  final double cutoffS;

  /// Application efficiency, low-quarter distribution uniformity, tailwater
  /// and deep percolation ratios (0–1).
  final double efficiency;
  final double lowQuarterDu;
  final double tailwaterRatio;
  final double deepPercolationRatio;

  /// Head at the inlet (m), friction of the gated pipe (m) and the
  /// uniformity of the gate flows (Christiansen CU, 0–1).
  final double inletHeadM;
  final double frictionLossM;
  final double gateCu;

  /// Codes `surface_*`, `gated_*`.
  final List<String> warnings;

  /// Pressure head the design leaves at the inlet (m), null without results.
  double? availableHead;

  /// Hours of one irrigation of every set.
  double get irrigationHours => sets * cutoffS / 3600;

  Map<String, dynamic> toJson() => {
    'id': setId,
    'name': name,
    'n': furrows,
    'set': perSet,
    'sets': sets,
    'q': inflow,
    'qs': setFlow,
    'tl': advanceS,
    'tco': cutoffS,
    'ea': efficiency,
    'du': lowQuarterDu,
    'tw': tailwaterRatio,
    'dp': deepPercolationRatio,
    'hin': inletHeadM,
    'hf': frictionLossM,
    'cu': gateCu,
    if (warnings.isNotEmpty) 'warn': warnings,
    if (availableHead != null) 'h': availableHead,
  };
  static FurrowSetResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return FurrowSetResult(
      setId: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      furrows: n('n'),
      perSet: n('set'),
      sets: n('sets'),
      inflow: d('q'),
      setFlow: d('qs'),
      advanceS: d('tl'),
      cutoffS: d('tco'),
      efficiency: d('ea'),
      lowQuarterDu: d('du'),
      tailwaterRatio: d('tw'),
      deepPercolationRatio: d('dp'),
      inletHeadM: d('hin'),
      frictionLossM: d('hf'),
      gateCu: d('cu'),
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
      availableHead: (j['h'] as num?)?.toDouble(),
    );
  }
}

String _nameOf(Entity e, String fallback) => e.name.isNotEmpty ? e.name : fallback;

/// The lane [e] analysed with the ground of [terrain].
TravellerLaneResult analyzeTravellerLane(Project p, TravellerEntity e, {Terrain? terrain}) {
  var q = e.gunFlow, dw = e.wettedDiameterM;
  final nozzle = p.catalog.outlet(e.gunSpecId)?.nozzle(e.gunNozzleId);
  if (nozzle != null) {
    final (fq, fd) = gunPerformance(nozzle, e.gunPressureM);
    if (fq > 0) q = fq;
    if (fd > 0) dw = fd;
  }
  final t = terrain == null || terrain.isEmpty ? null : terrain;
  final rise = t == null ? 0.0 : math.max(0.0, t.elevationAt(e.end) - t.elevationAt(e.start));
  final run = e.runLengthM;
  final r = analyzeTraveller(
    TravellerSpec(
      gunFlow: q,
      gunPressureM: e.gunPressureM,
      wettedDiameterM: dw,
      sectorDeg: e.sectorDeg,
      hoseLengthM: e.hoseLengthM > 0 ? e.hoseLengthM : run,
      hoseInnerMm: e.hoseInnerMm,
      driveLossM: e.driveLossM,
      gunHeightM: e.gunHeightM,
      groundRiseM: rise,
      wind: e.wind,
      taperedNozzle: e.taperedNozzle,
      laneSpacingM: e.laneWidthM,
      laneLengthM: run,
      targetDepthMm: e.speedMPerMin > 0 ? 0 : e.targetDepthMm,
      speedMPerMin: e.speedMPerMin,
      setupHours: e.setupHours,
      hoursPerDay: e.hoursPerDay,
      pumpEfficiency: p.params.pumpEfficiency,
    ),
    id: e.id,
  );
  return TravellerLaneResult(laneId: e.id, name: _nameOf(e, e.id), machine: e.machine, flow: q, wettedDiameterM: dw, gunPressureM: e.gunPressureM, groundRiseM: rise, result: r);
}

/// The furrow set [e] analysed with the ground of [terrain].
FurrowSetResult analyzeFurrowSet(Project p, FurrowEntity e, {Terrain? terrain}) {
  final warnings = <String>[];
  final spec = SurfaceSpec(
    system: SurfaceSystem.furrow,
    lengthM: math.max(e.furrowLengthM, 1),
    slope: math.max(e.slope, 0),
    manningN: e.manningN > 0 ? e.manningN : 0.04,
    intake: nrcsFurrowIntake(e.intakeFamily),
    furrowSpacingM: e.furrowSpacingM > 0 ? e.furrowSpacingM : 1,
  );
  final depth = math.max(e.requiredDepthMm, 1) / 1000;
  SurfaceEvaluation? ev;
  if (e.inflowLps > 0) {
    final q = e.inflowLps / 1000;
    final tco = designCutoffTime(spec, inflow: q, requiredDepthM: depth);
    if (tco.isFinite) {
      ev = evaluateSurface(spec, inflow: q, cutoffS: tco, requiredDepthM: depth, id: e.id);
    } else {
      warnings.add('surface_no_advance:${e.id}');
    }
  } else {
    final d = designSurface(spec, requiredDepthM: depth, id: e.id);
    ev = d.best;
    warnings.addAll(d.warnings);
  }
  if (ev != null) {
    for (final w in ev.warnings) {
      if (!warnings.contains(w)) warnings.add(w);
    }
  }
  final count = e.furrowCount;
  final perSet = e.furrowsPerSet > 0 ? math.min(e.furrowsPerSet, math.max(count, 1)) : math.max(count, 1);
  final sets = (count / perSet - 1e-9).ceil().clamp(1, 1 << 20);
  final inflow = ev?.inflow ?? 0;
  final setFlow = inflow * perSet;
  var head = ditchInletHeadM, friction = 0.0, cu = 1.0;
  if (e.gatedPipe && perSet > 0 && inflow > 0) {
    final t = terrain == null || terrain.isEmpty ? null : terrain;
    final len = e.length;
    final fall = t == null || len <= 0 ? 0.0 : (t.elevationAt(e.points.first) - t.elevationAt(e.points.last)) / len;
    final g = designGatedPipe(
      GatedPipeSpec(
        outlets: perSet,
        outletSpacingM: e.furrowSpacingM,
        targetFlow: inflow,
        // the farthest set: the whole pipe carries the set flow
        firstOutletM: math.max(e.furrowSpacingM / 2, len - perSet * e.furrowSpacingM + e.furrowSpacingM / 2),
        pipeInnerMm: e.pipeInnerMm,
        hazenC: e.hazenC,
        slope: fall,
      ),
      id: e.id,
    );
    head = g.inletHeadM;
    friction = g.frictionLossM;
    cu = g.flowCu;
    for (final w in g.warnings) {
      if (!warnings.contains(w)) warnings.add(w);
    }
  }
  return FurrowSetResult(
    setId: e.id,
    name: _nameOf(e, e.id),
    furrows: count,
    perSet: perSet,
    sets: sets,
    inflow: inflow,
    setFlow: setFlow,
    advanceS: ev?.advanceS ?? 0,
    cutoffS: ev?.cutoffS ?? 0,
    efficiency: ev?.efficiency ?? 0,
    lowQuarterDu: ev?.lowQuarterDu ?? 0,
    tailwaterRatio: ev?.tailwaterRatio ?? 0,
    deepPercolationRatio: ev?.deepPercolationRatio ?? 0,
    inletHeadM: head,
    frictionLossM: friction,
    gateCu: cu,
    warnings: warnings,
  );
}

/// Recent demands by the entity's data (the design asks for them again in
/// every system flow and sizing pass).
final _demands = <String, (double, double)>{};

/// Flow (m³/s) and head (m) lane or furrow set [e] asks of the mainline at
/// its inlet; null for other entities.
(double, double)? fieldMachineDemand(Project p, Entity e, {Terrain? terrain}) {
  if (e is! TravellerEntity && e is! FurrowEntity) return null;
  final gun = e is TravellerEntity ? p.catalog.outlet(e.gunSpecId)?.nozzle(e.gunNozzleId)?.toJson() : null;
  final key = '${identityHashCode(terrain)}|$gun|${e.toJson()}';
  final hit = _demands.remove(key);
  if (hit != null) return _demands[key] = hit;
  final d = switch (e) {
    TravellerEntity t => () {
      final r = analyzeTravellerLane(p, t, terrain: terrain);
      return (r.flow, r.requiredHead);
    }(),
    FurrowEntity f => () {
      final r = analyzeFurrowSet(p, f, terrain: terrain);
      return (r.setFlow, r.inletHeadM);
    }(),
    _ => (0.0, 0.0),
  };
  _demands[key] = d;
  while (_demands.length > 128) {
    _demands.remove(_demands.keys.first);
  }
  return d;
}

/// The least pressure head the system flows of [r] leave at demand [id].
double? availableHeadOf(DesignResults r, String id) {
  double? h;
  for (final f in r.systemFlows) {
    for (final v in f.valves) {
      if (v.valveId == id) h = h == null ? v.availableHead : math.min(h, v.availableHead);
    }
  }
  return h;
}

/// Lanes of the machine of [template] across [field]: parallel to
/// [angleDeg] (counter-clockwise from east), spaced by the template's lane
/// spacing (or that of the wind table for its gun), centred over the field;
/// each lane starts at a hydrant on the field edge and runs the hose length,
/// stopping a wetted radius short of the far edge. The lanes copy the
/// template's data; [newId] gives their ids and [name] their names.
List<TravellerEntity> layoutTravellerLanes(Project p, List<Pt> field, TravellerEntity template, {required double angleDeg, required String Function() newId, String Function(int i)? name}) {
  if (field.length < 3) return const [];
  final dir = Pt.polar(1, degToRad(angleDeg)), across = dir.perpendicular;
  final probe = analyzeTravellerLane(
    p,
    template.clone()
      ..start = Pt.zero
      ..end = dir * 100,
  );
  final spacing = probe.result.laneSpacingM;
  final radius = probe.wettedDiameterM / 2;
  if (spacing <= 0) return const [];
  final as = [for (final q in field) q.dot(across)];
  final lo = as.reduce(math.min), hi = as.reduce(math.max);
  final n = math.max(1, ((hi - lo) / spacing - 1e-9).ceil());
  final mid = (lo + hi) / 2;
  final out = <TravellerEntity>[];
  for (var k = 0; k < n; k++) {
    final a = mid + (k - (n - 1) / 2) * spacing;
    // where the lane's line crosses the outline, along the lane
    final cuts = <double>[];
    for (var i = 0; i < field.length; i++) {
      final p0 = field[i], p1 = field[(i + 1) % field.length];
      final d0 = p0.dot(across) - a, d1 = p1.dot(across) - a;
      if ((d0 > 0) == (d1 > 0) || (d0 - d1).abs() < 1e-12) continue;
      final q = p0 + (p1 - p0) * (d0 / (d0 - d1));
      cuts.add(q.dot(dir));
    }
    cuts.sort();
    var best = (0.0, 0.0);
    for (var i = 0; i + 1 < cuts.length; i += 2) {
      if (cuts[i + 1] - cuts[i] > best.$2 - best.$1) best = (cuts[i], cuts[i + 1]);
    }
    final chord = best.$2 - best.$1;
    if (chord < 10) continue;
    final hose = template.hoseLengthM > 0 ? template.hoseLengthM : chord;
    final run = math.min(hose, math.max(10.0, chord - radius));
    final base = across * a;
    out.add(
      template.clone(newId: newId())
        ..name = name?.call(out.length) ?? template.name
        ..start = base + dir * best.$1
        ..end = base + dir * (best.$1 + run),
    );
  }
  return out;
}
