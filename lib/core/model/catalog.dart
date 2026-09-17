/// Component catalog (pipes, emitters, tapes, valves, pumps) with a generic
/// default database. All hydraulic values are stored in SI.
library;

import '../hydraulics/emitter.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/pump.dart';
import '../hydraulics/water_hammer.dart';
import '../units.dart';

enum PipeUsage { lateral, zone, mainline }

class PipeSpec {
  PipeSpec({
    required this.id,
    required this.name,
    required this.nominalMm,
    required this.innerDiameterMm,
    this.material = PipeMaterial.pvc,
    this.hazenC = 150,
    this.roughnessMm = 0.0015,
    this.pressureRatingM = 60,
    this.wallThicknessMm = 2,
    this.costPerM = 0,
    Set<PipeUsage>? usage,
    this.enabled = true,
    this.supplier = '',
    this.code = '',
  }) : usage = usage ?? {PipeUsage.zone, PipeUsage.mainline};

  final String id;
  String name;
  String supplier;
  String code;
  double nominalMm;
  double innerDiameterMm;
  PipeMaterial material;
  double hazenC;
  double roughnessMm;
  double pressureRatingM;
  double wallThicknessMm;
  double costPerM;
  Set<PipeUsage> usage;
  bool enabled;

  double get innerDiameter => innerDiameterMm / 1000;
  double get roughness => roughnessMm / 1000;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'nominalMm': nominalMm, 'idMm': innerDiameterMm,
    'material': material.name, 'c': hazenC, 'roughMm': roughnessMm,
    'ratingM': pressureRatingM, 'wallMm': wallThicknessMm, 'cost': costPerM,
    'usage': usage.map((u) => u.name).toList(), 'enabled': enabled, if (supplier.isNotEmpty) 'sup': supplier, if (code.isNotEmpty) 'code': code,
  };
  static PipeSpec fromJson(Map<String, dynamic> j) => PipeSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    supplier: j['sup'] as String? ?? '',
    code: j['code'] as String? ?? '',
    nominalMm: (j['nominalMm'] as num).toDouble(),
    innerDiameterMm: (j['idMm'] as num).toDouble(),
    material: PipeMaterial.values.byName(j['material'] as String? ?? 'pvc'),
    hazenC: (j['c'] as num?)?.toDouble() ?? 150,
    roughnessMm: (j['roughMm'] as num?)?.toDouble() ?? 0.0015,
    pressureRatingM: (j['ratingM'] as num?)?.toDouble() ?? 60,
    wallThicknessMm: (j['wallMm'] as num?)?.toDouble() ?? 2,
    costPerM: (j['cost'] as num?)?.toDouble() ?? 0,
    usage: ((j['usage'] as List?) ?? ['zone', 'mainline']).map((u) => PipeUsage.values.byName(u as String)).toSet(),
    enabled: j['enabled'] as bool? ?? true,
  );
}

enum OutletKind { sprinkler, microSprinkler, dripper, bubbler, gun, demandPoint }

class NozzleSpec {
  NozzleSpec({
    required this.id,
    required this.name,
    required this.curve,
    this.arcDeg = 360,
    this.minHeadM = 5,
    this.maxHeadM = 60,
    this.defaultHeadM = 20,
    this.cv = 0.03,
    this.flowTolBelow = 0.05,
    this.flowTolAbove = 0.05,
  });
  final String id;
  String name;
  EmitterCurve curve;
  double arcDeg;
  double minHeadM;
  double maxHeadM;
  double defaultHeadM;
  double cv;
  double flowTolBelow;
  double flowTolAbove;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'curve': curve.toJson(), 'arc': arcDeg, 'minH': minHeadM,
    'maxH': maxHeadM, 'defH': defaultHeadM, 'cv': cv, 'tolB': flowTolBelow, 'tolA': flowTolAbove,
  };
  static NozzleSpec fromJson(Map<String, dynamic> j) => NozzleSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    curve: EmitterCurve.fromJson(j['curve'] as Map<String, dynamic>),
    arcDeg: (j['arc'] as num?)?.toDouble() ?? 360,
    minHeadM: (j['minH'] as num?)?.toDouble() ?? 5,
    maxHeadM: (j['maxH'] as num?)?.toDouble() ?? 60,
    defaultHeadM: (j['defH'] as num?)?.toDouble() ?? 20,
    cv: (j['cv'] as num?)?.toDouble() ?? 0.03,
    flowTolBelow: (j['tolB'] as num?)?.toDouble() ?? 0.05,
    flowTolAbove: (j['tolA'] as num?)?.toDouble() ?? 0.05,
  );
}

class OutletSpec {
  OutletSpec({
    required this.id,
    required this.name,
    required this.kind,
    required this.nozzles,
    this.cost = 0,
    this.inletMm = 20,
    this.riserHeightM = 0,
    this.enabled = true,
    this.supplier = '',
    this.code = '',
  });
  final String id;
  String name;
  String supplier;
  String code;
  OutletKind kind;
  List<NozzleSpec> nozzles;
  double cost;
  double inletMm;
  double riserHeightM;
  bool enabled;

  NozzleSpec? nozzle(String? id) {
    if (nozzles.isEmpty) return null;
    return nozzles.firstWhere((n) => n.id == id, orElse: () => nozzles.first);
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'kind': kind.name, 'nozzles': nozzles.map((n) => n.toJson()).toList(),
    'cost': cost, 'inletMm': inletMm, 'riser': riserHeightM, 'enabled': enabled, if (supplier.isNotEmpty) 'sup': supplier, if (code.isNotEmpty) 'code': code,
  };
  static OutletSpec fromJson(Map<String, dynamic> j) => OutletSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    supplier: j['sup'] as String? ?? '',
    code: j['code'] as String? ?? '',
    kind: OutletKind.values.byName(j['kind'] as String),
    nozzles: (j['nozzles'] as List).map((n) => NozzleSpec.fromJson(n as Map<String, dynamic>)).toList(),
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    inletMm: (j['inletMm'] as num?)?.toDouble() ?? 20,
    riserHeightM: (j['riser'] as num?)?.toDouble() ?? 0,
    enabled: j['enabled'] as bool? ?? true,
  );
}

class TapeSpec {
  TapeSpec({
    required this.id,
    required this.name,
    required this.innerDiameterMm,
    required this.emitterSpacingM,
    required this.emitter,
    this.nominalMm = 16,
    this.barbK = 0.4,
    this.cv = 0.03,
    this.minHeadM = 4,
    this.maxHeadM = 15,
    this.defaultInletHeadM = 10,
    this.tolBelowPct = 30,
    this.tolAbovePct = 20,
    this.pressureRatingM = 25,
    this.roughnessMm = 0.002,
    this.hazenC = 140,
    this.costPerM = 0,
    this.enabled = true,
    this.supplier = '',
    this.code = '',
  });
  final String id;
  String name;
  String supplier;
  String code;
  double nominalMm;
  double innerDiameterMm;
  double emitterSpacingM;
  EmitterCurve emitter;
  double barbK;
  double cv;
  double minHeadM;
  double maxHeadM;
  double defaultInletHeadM;
  double tolBelowPct;
  double tolAbovePct;
  double pressureRatingM;
  double roughnessMm;
  double hazenC;
  double costPerM;
  bool enabled;

  double get innerDiameter => innerDiameterMm / 1000;

  /// Nominal specific discharge rate (m³/s per 100 m) at the default inlet head.
  double get nominalSdr => emitter.flow(defaultInletHeadM) * (100 / emitterSpacingM);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'nominalMm': nominalMm, 'idMm': innerDiameterMm, 'spacing': emitterSpacingM,
    'emitter': emitter.toJson(), 'barbK': barbK, 'cv': cv, 'minH': minHeadM, 'maxH': maxHeadM,
    'inletH': defaultInletHeadM, 'tolB': tolBelowPct, 'tolA': tolAbovePct, 'ratingM': pressureRatingM,
    'roughMm': roughnessMm, 'c': hazenC, 'cost': costPerM, 'enabled': enabled, if (supplier.isNotEmpty) 'sup': supplier, if (code.isNotEmpty) 'code': code,
  };
  static TapeSpec fromJson(Map<String, dynamic> j) => TapeSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    supplier: j['sup'] as String? ?? '',
    code: j['code'] as String? ?? '',
    nominalMm: (j['nominalMm'] as num?)?.toDouble() ?? 16,
    innerDiameterMm: (j['idMm'] as num).toDouble(),
    emitterSpacingM: (j['spacing'] as num).toDouble(),
    emitter: EmitterCurve.fromJson(j['emitter'] as Map<String, dynamic>),
    barbK: (j['barbK'] as num?)?.toDouble() ?? 0.4,
    cv: (j['cv'] as num?)?.toDouble() ?? 0.03,
    minHeadM: (j['minH'] as num?)?.toDouble() ?? 4,
    maxHeadM: (j['maxH'] as num?)?.toDouble() ?? 15,
    defaultInletHeadM: (j['inletH'] as num?)?.toDouble() ?? 10,
    tolBelowPct: (j['tolB'] as num?)?.toDouble() ?? 30,
    tolAbovePct: (j['tolA'] as num?)?.toDouble() ?? 20,
    pressureRatingM: (j['ratingM'] as num?)?.toDouble() ?? 25,
    roughnessMm: (j['roughMm'] as num?)?.toDouble() ?? 0.002,
    hazenC: (j['c'] as num?)?.toDouble() ?? 140,
    costPerM: (j['cost'] as num?)?.toDouble() ?? 0,
    enabled: j['enabled'] as bool? ?? true,
  );
}

enum ValveKind { control, prv, isolation, check, backflow, filter, meter, airRelease, other }

class ValveSpec {
  ValveSpec({
    required this.id,
    required this.name,
    required this.kind,
    required this.sizeMm,
    required this.loss,
    this.minFlow = 0,
    this.maxFlow = 1,
    this.cost = 0,
    this.defaultSettingM = 0,
    this.enabled = true,
    this.supplier = '',
    this.code = '',
  });
  final String id;
  String name;
  String supplier;
  String code;
  ValveKind kind;
  double sizeMm;

  /// Head loss law h = k·Q^n + c with Q in m³/s.
  DeviceLossCurve loss;
  double minFlow;
  double maxFlow;
  double cost;

  /// Default downstream pressure setting (PRV), metres.
  double defaultSettingM;
  bool enabled;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'kind': kind.name, 'sizeMm': sizeMm, 'loss': loss.toJson(),
    'minQ': minFlow, 'maxQ': maxFlow, 'cost': cost, 'setting': defaultSettingM, 'enabled': enabled, if (supplier.isNotEmpty) 'sup': supplier, if (code.isNotEmpty) 'code': code,
  };
  static ValveSpec fromJson(Map<String, dynamic> j) => ValveSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    supplier: j['sup'] as String? ?? '',
    code: j['code'] as String? ?? '',
    kind: ValveKind.values.byName(j['kind'] as String),
    sizeMm: (j['sizeMm'] as num).toDouble(),
    loss: DeviceLossCurve.fromJson(j['loss'] as Map<String, dynamic>),
    minFlow: (j['minQ'] as num?)?.toDouble() ?? 0,
    maxFlow: (j['maxQ'] as num?)?.toDouble() ?? 1,
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    defaultSettingM: (j['setting'] as num?)?.toDouble() ?? 0,
    enabled: j['enabled'] as bool? ?? true,
  );
}

class PumpSpec {
  PumpSpec({
    required this.id,
    required this.name,
    required this.points,
    this.efficiency = 0.7,
    this.minFlow = 0,
    this.maxFlow = 1,
    this.cost = 0,
    this.enabled = true,
    this.supplier = '',
    this.code = '',
    this.powerKw = 0,
  }) : curve = PumpCurve.fit(points);
  final String id;
  String name;
  String supplier;
  String code;

  /// Rated motor power (kW), informative.
  double powerKw;

  /// (Q m³/s, H m) samples of the manufacturer's curve.
  List<(double, double)> points;
  PumpCurve curve;
  double efficiency;
  double minFlow;
  double maxFlow;
  double cost;
  bool enabled;

  void refit() => curve = PumpCurve.fit(points);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'points': points.map((p) => [p.$1, p.$2]).toList(), 'eff': efficiency,
    'minQ': minFlow, 'maxQ': maxFlow, 'cost': cost, 'enabled': enabled, if (supplier.isNotEmpty) 'sup': supplier, if (code.isNotEmpty) 'code': code, if (powerKw > 0) 'kw': powerKw,
  };
  static PumpSpec fromJson(Map<String, dynamic> j) => PumpSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    supplier: j['sup'] as String? ?? '',
    code: j['code'] as String? ?? '',
    powerKw: (j['kw'] as num?)?.toDouble() ?? 0,
    points: (j['points'] as List).map((p) => ((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList(),
    efficiency: (j['eff'] as num?)?.toDouble() ?? 0.7,
    minFlow: (j['minQ'] as num?)?.toDouble() ?? 0,
    maxFlow: (j['maxQ'] as num?)?.toDouble() ?? 1,
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    enabled: j['enabled'] as bool? ?? true,
  );
}

/// Pipe connections selected automatically for the bill of materials.
enum FittingKind { coupler, elbow90, elbow45, tee, cross, reducer, endCap, adapter, takeOff, tapeEnd, riser }

class FittingSpec {
  FittingSpec({
    required this.id,
    required this.name,
    required this.kind,
    required this.sizeMm,
    this.size2Mm = 0,
    this.cost = 0,
    this.enabled = true,
    this.supplier = '',
    this.code = '',
    this.material = '',
  });
  final String id;
  String name;
  String supplier;
  String code;
  FittingKind kind;

  /// Main (run) size; [size2Mm] is the branch / reduced / lateral size (0 = same).
  double sizeMm;
  double size2Mm;
  double cost;
  bool enabled;
  String material;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'kind': kind.name, 'sizeMm': sizeMm, if (size2Mm > 0) 'size2Mm': size2Mm, 'cost': cost, 'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier, if (code.isNotEmpty) 'code': code, if (material.isNotEmpty) 'mat': material,
  };
  static FittingSpec fromJson(Map<String, dynamic> j) => FittingSpec(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: FittingKind.values.byName(j['kind'] as String),
    sizeMm: (j['sizeMm'] as num).toDouble(),
    size2Mm: (j['size2Mm'] as num?)?.toDouble() ?? 0,
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    enabled: j['enabled'] as bool? ?? true,
    supplier: j['sup'] as String? ?? '',
    code: j['code'] as String? ?? '',
    material: j['mat'] as String? ?? '',
  );
}

class Catalog {
  Catalog({List<PipeSpec>? pipes, List<OutletSpec>? outlets, List<TapeSpec>? tapes, List<ValveSpec>? valves, List<PumpSpec>? pumps, List<FittingSpec>? fittings})
      : pipes = pipes ?? [],
        outlets = outlets ?? [],
        tapes = tapes ?? [],
        valves = valves ?? [],
        pumps = pumps ?? [],
        fittings = fittings ?? [];

  final List<PipeSpec> pipes;
  final List<OutletSpec> outlets;
  final List<TapeSpec> tapes;
  final List<ValveSpec> valves;
  final List<PumpSpec> pumps;
  final List<FittingSpec> fittings;

  FittingSpec? fitting(String? id) => id == null ? null : fittings.cast<FittingSpec?>().firstWhere((p) => p!.id == id, orElse: () => null);

  /// Enabled fitting of [kind] with the closest size at or above [sizeMm]
  /// (and [size2Mm] when given), or null when the catalog has none.
  FittingSpec? findFitting(FittingKind kind, double sizeMm, {double size2Mm = 0}) {
    FittingSpec? best;
    var bestScore = double.infinity;
    for (final f in fittings) {
      if (!f.enabled || f.kind != kind) continue;
      final d1 = f.sizeMm - sizeMm;
      if (d1 < -0.5) continue;
      var score = d1.abs();
      if (size2Mm > 0) {
        final s2 = f.size2Mm > 0 ? f.size2Mm : f.sizeMm;
        final d2 = s2 - size2Mm;
        if (d2 < -0.5) continue;
        score += d2.abs();
      } else if (f.size2Mm > 0 && (f.size2Mm - f.sizeMm).abs() > 0.5) {
        continue; // reducing fitting when an equal one was asked
      }
      if (score < bestScore) {
        bestScore = score;
        best = f;
      }
    }
    return best;
  }

  /// Unique id for a new catalog item with the given prefix.
  String newId(String prefix) {
    final used = {...pipes.map((e) => e.id), ...outlets.map((e) => e.id), ...tapes.map((e) => e.id), ...valves.map((e) => e.id), ...pumps.map((e) => e.id), ...fittings.map((e) => e.id)};
    var i = 1;
    while (used.contains('$prefix$i')) {
      i++;
    }
    return '$prefix$i';
  }

  /// Adds every item of [other] whose id is not present yet (or replaces
  /// when [replace]). Returns the number of items added or replaced.
  int merge(Catalog other, {bool replace = false}) {
    var n = 0;
    void go<T>(List<T> mine, List<T> theirs, String Function(T) idOf) {
      for (final t in theirs) {
        final i = mine.indexWhere((m) => idOf(m) == idOf(t));
        if (i < 0) {
          mine.add(t);
          n++;
        } else if (replace) {
          mine[i] = t;
          n++;
        }
      }
    }

    go(pipes, other.pipes, (p) => p.id);
    go(outlets, other.outlets, (p) => p.id);
    go(tapes, other.tapes, (p) => p.id);
    go(valves, other.valves, (p) => p.id);
    go(pumps, other.pumps, (p) => p.id);
    go(fittings, other.fittings, (p) => p.id);
    return n;
  }

  int get itemCount => pipes.length + outlets.length + tapes.length + valves.length + pumps.length + fittings.length;

  Catalog copy() => Catalog.fromJson(toJson());

  PipeSpec? pipe(String? id) => id == null ? null : pipes.cast<PipeSpec?>().firstWhere((p) => p!.id == id, orElse: () => null);
  OutletSpec? outlet(String? id) => id == null ? null : outlets.cast<OutletSpec?>().firstWhere((p) => p!.id == id, orElse: () => null);
  TapeSpec? tape(String? id) => id == null ? null : tapes.cast<TapeSpec?>().firstWhere((p) => p!.id == id, orElse: () => null);
  ValveSpec? valve(String? id) => id == null ? null : valves.cast<ValveSpec?>().firstWhere((p) => p!.id == id, orElse: () => null);
  PumpSpec? pump(String? id) => id == null ? null : pumps.cast<PumpSpec?>().firstWhere((p) => p!.id == id, orElse: () => null);

  List<PipeSpec> pipesFor(PipeUsage usage) =>
      pipes.where((p) => p.enabled && p.usage.contains(usage)).toList()..sort((a, b) => a.innerDiameterMm.compareTo(b.innerDiameterMm));

  Map<String, dynamic> toJson() => {
    'pipes': pipes.map((p) => p.toJson()).toList(),
    'outlets': outlets.map((p) => p.toJson()).toList(),
    'tapes': tapes.map((p) => p.toJson()).toList(),
    'valves': valves.map((p) => p.toJson()).toList(),
    'pumps': pumps.map((p) => p.toJson()).toList(),
    'fittings': fittings.map((p) => p.toJson()).toList(),
  };
  static Catalog fromJson(Map<String, dynamic> j) => Catalog(
    pipes: ((j['pipes'] as List?) ?? []).map((p) => PipeSpec.fromJson(p as Map<String, dynamic>)).toList(),
    outlets: ((j['outlets'] as List?) ?? []).map((p) => OutletSpec.fromJson(p as Map<String, dynamic>)).toList(),
    tapes: ((j['tapes'] as List?) ?? []).map((p) => TapeSpec.fromJson(p as Map<String, dynamic>)).toList(),
    valves: ((j['valves'] as List?) ?? []).map((p) => ValveSpec.fromJson(p as Map<String, dynamic>)).toList(),
    pumps: ((j['pumps'] as List?) ?? []).map((p) => PumpSpec.fromJson(p as Map<String, dynamic>)).toList(),
    fittings: ((j['fittings'] as List?) ?? []).map((p) => FittingSpec.fromJson(p as Map<String, dynamic>)).toList(),
  );

  /// Generic default database (metric, illustrative prices) with names in the
  /// requested language. Curves are power-law fits of typical manufacturer data.
  static Catalog defaultCatalog({String lang = 'en'}) {
    String n(String pt, String en, String es) => switch (lang) { 'pt' => pt, 'es' => es, _ => en };
    EmitterCurve q(double lph, double headM, double x, {double radiusM = 0}) =>
        EmitterCurve.fromNominal(flow: lph * m3sPerLph, head: headM, x: x, radius: radiusM, radiusB: radiusM > 0 ? 0.35 : 0);

    final pipes = <PipeSpec>[
      // PE laterals (PN 4 / PN 6)
      PipeSpec(id: 'pe16', name: 'PE 16 mm (PN 4)', nominalMm: 16, innerDiameterMm: 13.6, material: PipeMaterial.peld, hazenC: 140, roughnessMm: 0.003, pressureRatingM: 40, wallThicknessMm: 1.2, costPerM: 0.9, usage: {PipeUsage.lateral}),
      PipeSpec(id: 'pe20', name: 'PE 20 mm (PN 4)', nominalMm: 20, innerDiameterMm: 17.0, material: PipeMaterial.peld, hazenC: 140, roughnessMm: 0.003, pressureRatingM: 40, wallThicknessMm: 1.5, costPerM: 1.3, usage: {PipeUsage.lateral}),
      PipeSpec(id: 'pe25', name: 'PE 25 mm (PN 6)', nominalMm: 25, innerDiameterMm: 21.0, material: PipeMaterial.pehd, hazenC: 145, roughnessMm: 0.003, pressureRatingM: 60, wallThicknessMm: 2.0, costPerM: 2.1, usage: {PipeUsage.lateral, PipeUsage.zone}),
      PipeSpec(id: 'pe32', name: 'PE 32 mm (PN 6)', nominalMm: 32, innerDiameterMm: 27.2, material: PipeMaterial.pehd, hazenC: 145, roughnessMm: 0.003, pressureRatingM: 60, wallThicknessMm: 2.4, costPerM: 3.2, usage: {PipeUsage.lateral, PipeUsage.zone}),
      PipeSpec(id: 'pe40', name: 'PE 40 mm (PN 6)', nominalMm: 40, innerDiameterMm: 34.0, material: PipeMaterial.pehd, hazenC: 145, roughnessMm: 0.003, pressureRatingM: 60, wallThicknessMm: 3.0, costPerM: 4.9, usage: {PipeUsage.zone}),
      PipeSpec(id: 'pe50', name: 'PE 50 mm (PN 6)', nominalMm: 50, innerDiameterMm: 42.6, material: PipeMaterial.pehd, hazenC: 145, roughnessMm: 0.003, pressureRatingM: 60, wallThicknessMm: 3.7, costPerM: 7.4, usage: {PipeUsage.zone}),
      // PVC irrigation (PN 40 / PN 60 / PN 80 - metres of head)
      PipeSpec(id: 'pvc35', name: 'PVC DN 35 PN 80', nominalMm: 35, innerDiameterMm: 32.0, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 1.5, costPerM: 4.5, usage: {PipeUsage.zone, PipeUsage.mainline}),
      PipeSpec(id: 'pvc50', name: 'PVC DN 50 PN 80', nominalMm: 50, innerDiameterMm: 46.4, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 1.8, costPerM: 7.2, usage: {PipeUsage.zone, PipeUsage.mainline}),
      PipeSpec(id: 'pvc75', name: 'PVC DN 75 PN 80', nominalMm: 75, innerDiameterMm: 70.6, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 2.2, costPerM: 14.5, usage: {PipeUsage.zone, PipeUsage.mainline}),
      PipeSpec(id: 'pvc100', name: 'PVC DN 100 PN 80', nominalMm: 100, innerDiameterMm: 96.0, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 2.5, costPerM: 24.0, usage: {PipeUsage.zone, PipeUsage.mainline}),
      PipeSpec(id: 'pvc125', name: 'PVC DN 125 PN 80', nominalMm: 125, innerDiameterMm: 118.6, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 3.2, costPerM: 36.0, usage: {PipeUsage.mainline}),
      PipeSpec(id: 'pvc150', name: 'PVC DN 150 PN 80', nominalMm: 150, innerDiameterMm: 144.0, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 3.8, costPerM: 52.0, usage: {PipeUsage.mainline}),
      PipeSpec(id: 'pvc200', name: 'PVC DN 200 PN 80', nominalMm: 200, innerDiameterMm: 191.6, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 4.9, costPerM: 88.0, usage: {PipeUsage.mainline}),
      PipeSpec(id: 'pvc250', name: 'PVC DN 250 PN 80', nominalMm: 250, innerDiameterMm: 239.4, hazenC: 150, roughnessMm: 0.0015, pressureRatingM: 80, wallThicknessMm: 6.2, costPerM: 135.0, usage: {PipeUsage.mainline}),
      PipeSpec(id: 'pead110', name: 'PEAD 110 mm PN 10', nominalMm: 110, innerDiameterMm: 96.8, material: PipeMaterial.pehd, hazenC: 150, roughnessMm: 0.002, pressureRatingM: 100, wallThicknessMm: 6.6, costPerM: 42.0, usage: {PipeUsage.mainline}),
      PipeSpec(id: 'pead160', name: 'PEAD 160 mm PN 10', nominalMm: 160, innerDiameterMm: 141.0, material: PipeMaterial.pehd, hazenC: 150, roughnessMm: 0.002, pressureRatingM: 100, wallThicknessMm: 9.5, costPerM: 85.0, usage: {PipeUsage.mainline}),
      PipeSpec(id: 'steel150', name: n('Aço galvanizado 6"', 'Galvanised steel 6"', 'Acero galvanizado 6"'), nominalMm: 150, innerDiameterMm: 154.0, material: PipeMaterial.steel, hazenC: 120, roughnessMm: 0.15, pressureRatingM: 200, wallThicknessMm: 4.5, costPerM: 160.0, usage: {PipeUsage.mainline}, enabled: false),
    ];

    final outlets = <OutletSpec>[
      OutletSpec(id: 'drip_pc', name: n('Gotejador PC (botão)', 'PC dripper (button)', 'Gotero PC (botón)'), kind: OutletKind.dripper, inletMm: 0, nozzles: [
        NozzleSpec(id: 'pc2', name: '2 L/h PC', curve: q(2, 10, 0.03), minHeadM: 5, maxHeadM: 40, defaultHeadM: 10, cv: 0.03),
        NozzleSpec(id: 'pc4', name: '4 L/h PC', curve: q(4, 10, 0.03), minHeadM: 5, maxHeadM: 40, defaultHeadM: 10, cv: 0.03),
        NozzleSpec(id: 'pc8', name: '8 L/h PC', curve: q(8, 10, 0.03), minHeadM: 5, maxHeadM: 40, defaultHeadM: 10, cv: 0.03),
      ], cost: 0.6),
      OutletSpec(id: 'drip_turb', name: n('Gotejador turbulento', 'Turbulent dripper', 'Gotero turbulento'), kind: OutletKind.dripper, inletMm: 0, nozzles: [
        NozzleSpec(id: 't2', name: '2 L/h', curve: q(2, 10, 0.5), minHeadM: 5, maxHeadM: 25, defaultHeadM: 10, cv: 0.04),
        NozzleSpec(id: 't4', name: '4 L/h', curve: q(4, 10, 0.5), minHeadM: 5, maxHeadM: 25, defaultHeadM: 10, cv: 0.04),
        NozzleSpec(id: 't8', name: '8 L/h', curve: q(8, 10, 0.5), minHeadM: 5, maxHeadM: 25, defaultHeadM: 10, cv: 0.04),
      ], cost: 0.35),
      OutletSpec(id: 'micro', name: n('Microaspersor 360°', 'Micro-sprinkler 360°', 'Microaspersor 360°'), kind: OutletKind.microSprinkler, inletMm: 0, riserHeightM: 0.3, nozzles: [
        NozzleSpec(id: 'm35', name: n('35 L/h (raio 3,0 m)', '35 L/h (radius 3.0 m)', '35 L/h (radio 3,0 m)'), curve: q(35, 15, 0.5, radiusM: 3.0), minHeadM: 10, maxHeadM: 30, defaultHeadM: 15, cv: 0.05),
        NozzleSpec(id: 'm50', name: n('50 L/h (raio 3,5 m)', '50 L/h (radius 3.5 m)', '50 L/h (radio 3,5 m)'), curve: q(50, 15, 0.5, radiusM: 3.5), minHeadM: 10, maxHeadM: 30, defaultHeadM: 15, cv: 0.05),
        NozzleSpec(id: 'm70', name: n('70 L/h (raio 4,0 m)', '70 L/h (radius 4.0 m)', '70 L/h (radio 4,0 m)'), curve: q(70, 15, 0.5, radiusM: 4.0), minHeadM: 10, maxHeadM: 30, defaultHeadM: 15, cv: 0.05),
        NozzleSpec(id: 'm120', name: n('120 L/h (raio 5,0 m)', '120 L/h (radius 5.0 m)', '120 L/h (radio 5,0 m)'), curve: q(120, 20, 0.5, radiusM: 5.0), minHeadM: 15, maxHeadM: 35, defaultHeadM: 20, cv: 0.05),
      ], cost: 2.8),
      OutletSpec(id: 'micro_pc', name: n('Microaspersor PC', 'PC micro-sprinkler', 'Microaspersor PC'), kind: OutletKind.microSprinkler, inletMm: 0, riserHeightM: 0.3, nozzles: [
        NozzleSpec(id: 'mpc40', name: n('40 L/h PC (raio 3,5 m)', '40 L/h PC (radius 3.5 m)', '40 L/h PC (radio 3,5 m)'), curve: q(40, 15, 0.05, radiusM: 3.5), minHeadM: 12, maxHeadM: 40, defaultHeadM: 20, cv: 0.05),
        NozzleSpec(id: 'mpc70', name: n('70 L/h PC (raio 4,5 m)', '70 L/h PC (radius 4.5 m)', '70 L/h PC (radio 4,5 m)'), curve: q(70, 15, 0.05, radiusM: 4.5), minHeadM: 12, maxHeadM: 40, defaultHeadM: 20, cv: 0.05),
      ], cost: 3.9),
      OutletSpec(id: 'impact34', name: n('Aspersor de impacto 3/4"', 'Impact sprinkler 3/4"', 'Aspersor de impacto 3/4"'), kind: OutletKind.sprinkler, inletMm: 20, riserHeightM: 1.0, nozzles: [
        NozzleSpec(id: 'i3.5', name: n('Bocal 3,5 mm (0,9 m³/h, R 12 m)', 'Nozzle 3.5 mm (0.9 m³/h, R 12 m)', 'Boquilla 3,5 mm (0,9 m³/h, R 12 m)'), curve: q(900, 30, 0.5, radiusM: 12), minHeadM: 20, maxHeadM: 45, defaultHeadM: 30, cv: 0.03, arcDeg: 360),
        NozzleSpec(id: 'i4.0', name: n('Bocal 4,0 mm (1,2 m³/h, R 13 m)', 'Nozzle 4.0 mm (1.2 m³/h, R 13 m)', 'Boquilla 4,0 mm (1,2 m³/h, R 13 m)'), curve: q(1200, 30, 0.5, radiusM: 13), minHeadM: 20, maxHeadM: 45, defaultHeadM: 30, cv: 0.03, arcDeg: 360),
        NozzleSpec(id: 'i4.5', name: n('Bocal 4,5 mm (1,5 m³/h, R 14 m)', 'Nozzle 4.5 mm (1.5 m³/h, R 14 m)', 'Boquilla 4,5 mm (1,5 m³/h, R 14 m)'), curve: q(1500, 30, 0.5, radiusM: 14), minHeadM: 20, maxHeadM: 45, defaultHeadM: 30, cv: 0.03, arcDeg: 360),
        NozzleSpec(id: 'i5.0', name: n('Bocal 5,0 mm (1,9 m³/h, R 15 m)', 'Nozzle 5.0 mm (1.9 m³/h, R 15 m)', 'Boquilla 5,0 mm (1,9 m³/h, R 15 m)'), curve: q(1900, 30, 0.5, radiusM: 15), minHeadM: 25, maxHeadM: 50, defaultHeadM: 35, cv: 0.03, arcDeg: 360),
      ], cost: 18.0),
      OutletSpec(id: 'gun', name: n('Canhão hidráulico 1,5"', 'Big gun 1.5"', 'Cañón de riego 1,5"'), kind: OutletKind.gun, inletMm: 40, riserHeightM: 1.5, nozzles: [
        NozzleSpec(id: 'g14', name: n('Bocal 14 mm (15 m³/h, R 32 m)', 'Nozzle 14 mm (15 m³/h, R 32 m)', 'Boquilla 14 mm (15 m³/h, R 32 m)'), curve: q(15000, 40, 0.5, radiusM: 32), minHeadM: 30, maxHeadM: 70, defaultHeadM: 40, cv: 0.03),
        NozzleSpec(id: 'g18', name: n('Bocal 18 mm (25 m³/h, R 40 m)', 'Nozzle 18 mm (25 m³/h, R 40 m)', 'Boquilla 18 mm (25 m³/h, R 40 m)'), curve: q(25000, 45, 0.5, radiusM: 40), minHeadM: 35, maxHeadM: 80, defaultHeadM: 45, cv: 0.03),
      ], cost: 420.0),
      OutletSpec(id: 'rotor', name: n('Rotor de jardim 1/2"', 'Turf rotor 1/2"', 'Rotor de jardín 1/2"'), kind: OutletKind.sprinkler, inletMm: 15, riserHeightM: 0.1, nozzles: [
        NozzleSpec(id: 'r1.5', name: '#1.5 (0,35 m³/h, R 8 m)', curve: q(350, 25, 0.5, radiusM: 8), minHeadM: 17, maxHeadM: 45, defaultHeadM: 25, cv: 0.03, arcDeg: 360),
        NozzleSpec(id: 'r3', name: '#3 (0,70 m³/h, R 10 m)', curve: q(700, 25, 0.5, radiusM: 10), minHeadM: 17, maxHeadM: 45, defaultHeadM: 25, cv: 0.03, arcDeg: 360),
        NozzleSpec(id: 'r3_180', name: '#3 180° (0,35 m³/h, R 10 m)', curve: q(350, 25, 0.5, radiusM: 10), minHeadM: 17, maxHeadM: 45, defaultHeadM: 25, cv: 0.03, arcDeg: 180),
        NozzleSpec(id: 'r3_90', name: '#3 90° (0,18 m³/h, R 10 m)', curve: q(180, 25, 0.5, radiusM: 10), minHeadM: 17, maxHeadM: 45, defaultHeadM: 25, cv: 0.03, arcDeg: 90),
      ], cost: 45.0),
      OutletSpec(id: 'spray', name: n('Spray pop-up 4"', 'Pop-up spray 4"', 'Difusor emergente 4"'), kind: OutletKind.sprinkler, inletMm: 15, nozzles: [
        NozzleSpec(id: 's12', name: '12F (0,60 m³/h, R 3,7 m)', curve: q(600, 20, 0.5, radiusM: 3.7), minHeadM: 10, maxHeadM: 30, defaultHeadM: 20, cv: 0.04, arcDeg: 360),
        NozzleSpec(id: 's12h', name: '12H (0,30 m³/h, R 3,7 m)', curve: q(300, 20, 0.5, radiusM: 3.7), minHeadM: 10, maxHeadM: 30, defaultHeadM: 20, cv: 0.04, arcDeg: 180),
        NozzleSpec(id: 's12q', name: '12Q (0,15 m³/h, R 3,7 m)', curve: q(150, 20, 0.5, radiusM: 3.7), minHeadM: 10, maxHeadM: 30, defaultHeadM: 20, cv: 0.04, arcDeg: 90),
        NozzleSpec(id: 's15', name: '15F (0,84 m³/h, R 4,6 m)', curve: q(840, 20, 0.5, radiusM: 4.6), minHeadM: 10, maxHeadM: 30, defaultHeadM: 20, cv: 0.04, arcDeg: 360),
      ], cost: 12.0),
      OutletSpec(id: 'demand', name: n('Ponto de demanda', 'Demand point', 'Punto de demanda'), kind: OutletKind.demandPoint, inletMm: 50, nozzles: [
        NozzleSpec(id: 'd5', name: '5 m³/h @ 20 m', curve: q(5000, 20, 0.0), minHeadM: 20, maxHeadM: 80, defaultHeadM: 20, cv: 0, flowTolAbove: 0.5, flowTolBelow: 0.5),
        NozzleSpec(id: 'd10', name: '10 m³/h @ 20 m', curve: q(10000, 20, 0.0), minHeadM: 20, maxHeadM: 80, defaultHeadM: 20, cv: 0, flowTolAbove: 0.5, flowTolBelow: 0.5),
        NozzleSpec(id: 'd20', name: '20 m³/h @ 25 m', curve: q(20000, 25, 0.0), minHeadM: 25, maxHeadM: 80, defaultHeadM: 25, cv: 0, flowTolAbove: 0.5, flowTolBelow: 0.5),
      ], cost: 0),
    ];

    final tapes = <TapeSpec>[
      TapeSpec(id: 'tape16_10_30', name: n('Fita gotejadora 16 mm, 1,0 L/h @ 0,30 m', 'Drip tape 16 mm, 1.0 L/h @ 0.30 m', 'Cinta de goteo 16 mm, 1,0 L/h @ 0,30 m'), innerDiameterMm: 15.6, emitterSpacingM: 0.30, emitter: q(1.0, 7, 0.5), barbK: 0.3, cv: 0.03, minHeadM: 4, maxHeadM: 12, defaultInletHeadM: 8, pressureRatingM: 15, costPerM: 0.45),
      TapeSpec(id: 'tape16_16_20', name: n('Fita gotejadora 16 mm, 1,6 L/h @ 0,20 m', 'Drip tape 16 mm, 1.6 L/h @ 0.20 m', 'Cinta de goteo 16 mm, 1,6 L/h @ 0,20 m'), innerDiameterMm: 15.6, emitterSpacingM: 0.20, emitter: q(1.6, 7, 0.5), barbK: 0.3, cv: 0.03, minHeadM: 4, maxHeadM: 12, defaultInletHeadM: 8, pressureRatingM: 15, costPerM: 0.55),
      TapeSpec(id: 'drip16_16_50', name: n('Tubo gotejador 16 mm, 1,6 L/h @ 0,50 m', 'Dripline 16 mm, 1.6 L/h @ 0.50 m', 'Tubería de goteo 16 mm, 1,6 L/h @ 0,50 m'), innerDiameterMm: 13.8, emitterSpacingM: 0.50, emitter: q(1.6, 10, 0.5), barbK: 0.4, cv: 0.03, minHeadM: 5, maxHeadM: 25, defaultInletHeadM: 10, pressureRatingM: 30, costPerM: 1.1),
      TapeSpec(id: 'drip16_24_75', name: n('Tubo gotejador 16 mm, 2,4 L/h @ 0,75 m', 'Dripline 16 mm, 2.4 L/h @ 0.75 m', 'Tubería de goteo 16 mm, 2,4 L/h @ 0,75 m'), innerDiameterMm: 13.8, emitterSpacingM: 0.75, emitter: q(2.4, 10, 0.5), barbK: 0.4, cv: 0.03, minHeadM: 5, maxHeadM: 25, defaultInletHeadM: 10, pressureRatingM: 30, costPerM: 1.05),
      TapeSpec(id: 'drip16pc_16_50', name: n('Tubo gotejador PC 16 mm, 1,6 L/h @ 0,50 m', 'PC dripline 16 mm, 1.6 L/h @ 0.50 m', 'Tubería de goteo PC 16 mm, 1,6 L/h @ 0,50 m'), innerDiameterMm: 13.8, emitterSpacingM: 0.50, emitter: q(1.6, 10, 0.04), barbK: 0.4, cv: 0.03, minHeadM: 6, maxHeadM: 40, defaultInletHeadM: 15, tolBelowPct: 50, tolAbovePct: 150, pressureRatingM: 40, costPerM: 1.6),
      TapeSpec(id: 'drip20pc_23_75', name: n('Tubo gotejador PC 20 mm, 2,3 L/h @ 0,75 m', 'PC dripline 20 mm, 2.3 L/h @ 0.75 m', 'Tubería de goteo PC 20 mm, 2,3 L/h @ 0,75 m'), innerDiameterMm: 17.5, emitterSpacingM: 0.75, emitter: q(2.3, 10, 0.04), barbK: 0.4, cv: 0.03, minHeadM: 6, maxHeadM: 40, defaultInletHeadM: 15, tolBelowPct: 50, tolAbovePct: 150, pressureRatingM: 40, costPerM: 2.1, nominalMm: 20),
    ];

    DeviceLossCurve kv(double k, double dMm) => DeviceLossCurve.fromK(k, dMm / 1000);
    final valves = <ValveSpec>[
      ValveSpec(id: 'ev25', name: n('Válvula elétrica 1"', 'Solenoid valve 1"', 'Electroválvula 1"'), kind: ValveKind.control, sizeMm: 25, loss: kv(6.0, 25), minFlow: 0.2 * m3sPerM3h, maxFlow: 6 * m3sPerM3h, cost: 120),
      ValveSpec(id: 'ev40', name: n('Válvula elétrica 1½"', 'Solenoid valve 1½"', 'Electroválvula 1½"'), kind: ValveKind.control, sizeMm: 40, loss: kv(5.5, 40), minFlow: 1 * m3sPerM3h, maxFlow: 16 * m3sPerM3h, cost: 260),
      ValveSpec(id: 'ev50', name: n('Válvula elétrica 2"', 'Solenoid valve 2"', 'Electroválvula 2"'), kind: ValveKind.control, sizeMm: 50, loss: kv(5.0, 50), minFlow: 2 * m3sPerM3h, maxFlow: 30 * m3sPerM3h, cost: 380),
      ValveSpec(id: 'ev80', name: n('Válvula hidráulica 3"', 'Hydraulic valve 3"', 'Válvula hidráulica 3"'), kind: ValveKind.control, sizeMm: 80, loss: kv(4.5, 80), minFlow: 5 * m3sPerM3h, maxFlow: 80 * m3sPerM3h, cost: 900),
      ValveSpec(id: 'ev100', name: n('Válvula hidráulica 4"', 'Hydraulic valve 4"', 'Válvula hidráulica 4"'), kind: ValveKind.control, sizeMm: 100, loss: kv(4.0, 100), minFlow: 10 * m3sPerM3h, maxFlow: 140 * m3sPerM3h, cost: 1500),
      ValveSpec(id: 'prv50', name: n('Válvula reguladora de pressão 2"', 'Pressure reducing valve 2"', 'Válvula reguladora de presión 2"'), kind: ValveKind.prv, sizeMm: 50, loss: kv(3.0, 50), maxFlow: 30 * m3sPerM3h, cost: 650, defaultSettingM: 25),
      ValveSpec(id: 'prv80', name: n('Válvula reguladora de pressão 3"', 'Pressure reducing valve 3"', 'Válvula reguladora de presión 3"'), kind: ValveKind.prv, sizeMm: 80, loss: kv(3.0, 80), maxFlow: 80 * m3sPerM3h, cost: 1200, defaultSettingM: 30),
      ValveSpec(id: 'gate50', name: n('Registro gaveta 2"', 'Gate valve 2"', 'Válvula de compuerta 2"'), kind: ValveKind.isolation, sizeMm: 50, loss: kv(0.2, 50), maxFlow: 40 * m3sPerM3h, cost: 90),
      ValveSpec(id: 'gate100', name: n('Registro gaveta 4"', 'Gate valve 4"', 'Válvula de compuerta 4"'), kind: ValveKind.isolation, sizeMm: 100, loss: kv(0.2, 100), maxFlow: 150 * m3sPerM3h, cost: 420),
      ValveSpec(id: 'check100', name: n('Válvula de retenção 4"', 'Check valve 4"', 'Válvula de retención 4"'), kind: ValveKind.check, sizeMm: 100, loss: kv(2.0, 100), maxFlow: 150 * m3sPerM3h, cost: 380),
      ValveSpec(id: 'filter_disc50', name: n('Filtro de discos 2" (120 mesh)', 'Disc filter 2" (120 mesh)', 'Filtro de discos 2" (120 mesh)'), kind: ValveKind.filter, sizeMm: 50, loss: DeviceLossCurve(k: 3.0 / (25 * m3sPerM3h * 25 * m3sPerM3h), n: 2), maxFlow: 25 * m3sPerM3h, cost: 850),
      ValveSpec(id: 'filter_screen80', name: n('Filtro de tela 3"', 'Screen filter 3"', 'Filtro de malla 3"'), kind: ValveKind.filter, sizeMm: 80, loss: DeviceLossCurve(k: 2.5 / (60 * m3sPerM3h * 60 * m3sPerM3h), n: 2), maxFlow: 60 * m3sPerM3h, cost: 1400),
      ValveSpec(id: 'meter50', name: n('Hidrômetro 2"', 'Water meter 2"', 'Contador de agua 2"'), kind: ValveKind.meter, sizeMm: 50, loss: kv(7.0, 50), maxFlow: 20 * m3sPerM3h, cost: 700),
      ValveSpec(id: 'backflow50', name: n('Válvula anti-refluxo 2"', 'Backflow preventer 2"', 'Válvula antirretorno 2"'), kind: ValveKind.backflow, sizeMm: 50, loss: kv(8.0, 50), maxFlow: 25 * m3sPerM3h, cost: 900),
      ValveSpec(id: 'air50', name: n('Ventosa 2"', 'Air release valve 2"', 'Ventosa 2"'), kind: ValveKind.airRelease, sizeMm: 50, loss: const DeviceLossCurve(k: 0), cost: 180),
    ];

    final pumps = <PumpSpec>[
      PumpSpec(id: 'pump_small', name: n('Bomba centrífuga 3 cv (10 m³/h @ 35 m)', 'Centrifugal pump 3 hp (10 m³/h @ 35 m)', 'Bomba centrífuga 3 CV (10 m³/h @ 35 m)'), points: [(0, 45), (5 * m3sPerM3h, 41), (10 * m3sPerM3h, 35), (15 * m3sPerM3h, 25)], efficiency: 0.55, maxFlow: 15 * m3sPerM3h, cost: 2200),
      PumpSpec(id: 'pump_mid', name: n('Bomba centrífuga 10 cv (40 m³/h @ 45 m)', 'Centrifugal pump 10 hp (40 m³/h @ 45 m)', 'Bomba centrífuga 10 CV (40 m³/h @ 45 m)'), points: [(0, 58), (20 * m3sPerM3h, 53), (40 * m3sPerM3h, 45), (60 * m3sPerM3h, 30)], efficiency: 0.65, maxFlow: 60 * m3sPerM3h, cost: 6500),
      PumpSpec(id: 'pump_big', name: n('Bomba centrífuga 30 cv (120 m³/h @ 55 m)', 'Centrifugal pump 30 hp (120 m³/h @ 55 m)', 'Bomba centrífuga 30 CV (120 m³/h @ 55 m)'), points: [(0, 70), (60 * m3sPerM3h, 64), (120 * m3sPerM3h, 55), (180 * m3sPerM3h, 38)], efficiency: 0.72, maxFlow: 180 * m3sPerM3h, cost: 18000),
      PumpSpec(id: 'pump_sub', name: n('Bomba submersa 7,5 cv (25 m³/h @ 60 m)', 'Submersible pump 7.5 hp (25 m³/h @ 60 m)', 'Bomba sumergible 7,5 CV (25 m³/h @ 60 m)'), points: [(0, 80), (12 * m3sPerM3h, 72), (25 * m3sPerM3h, 60), (35 * m3sPerM3h, 40)], efficiency: 0.6, maxFlow: 35 * m3sPerM3h, cost: 5400),
    ];

    return Catalog(pipes: pipes, outlets: outlets, tapes: tapes, valves: valves, pumps: pumps, fittings: defaultFittings(pipes, lang: lang));
  }

  /// Generic fittings for every nominal pipe size (couplers, elbows, tees,
  /// crosses, reducers, end caps, adapters) plus lateral take-offs, tape ends
  /// and risers, with illustrative prices scaled by size.
  static List<FittingSpec> defaultFittings(List<PipeSpec> pipes, {String lang = 'en'}) {
    String n(String pt, String en, String es) => switch (lang) { 'pt' => pt, 'es' => es, _ => en };
    final sizes = pipes.map((p) => p.nominalMm).toSet().toList()..sort();
    final out = <FittingSpec>[];
    String mm(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    double price(double base, double size) => (base * (0.25 + size / 40)).roundToDouble();
    for (final s in sizes) {
      final sz = mm(s);
      out.add(FittingSpec(id: 'cpl$sz', name: '${n('Luva', 'Coupler', 'Manguito')} $sz mm', kind: FittingKind.coupler, sizeMm: s, cost: price(4, s)));
      out.add(FittingSpec(id: 'el90_$sz', name: '${n('Cotovelo 90°', 'Elbow 90°', 'Codo 90°')} $sz mm', kind: FittingKind.elbow90, sizeMm: s, cost: price(6, s)));
      out.add(FittingSpec(id: 'el45_$sz', name: '${n('Cotovelo 45°', 'Elbow 45°', 'Codo 45°')} $sz mm', kind: FittingKind.elbow45, sizeMm: s, cost: price(6, s)));
      out.add(FittingSpec(id: 'tee$sz', name: '${n('Tê', 'Tee', 'Te')} $sz mm', kind: FittingKind.tee, sizeMm: s, cost: price(8, s)));
      out.add(FittingSpec(id: 'cross$sz', name: '${n('Cruzeta', 'Cross', 'Cruz')} $sz mm', kind: FittingKind.cross, sizeMm: s, cost: price(11, s)));
      out.add(FittingSpec(id: 'cap$sz', name: '${n('Tampão (cap)', 'End cap', 'Tapón')} $sz mm', kind: FittingKind.endCap, sizeMm: s, cost: price(3, s)));
      out.add(FittingSpec(id: 'adp$sz', name: '${n('Adaptador roscado', 'Threaded adapter', 'Adaptador roscado')} $sz mm', kind: FittingKind.adapter, sizeMm: s, cost: price(5, s)));
      for (final s2 in sizes) {
        if (s2 >= s) continue;
        final sz2 = mm(s2);
        out.add(FittingSpec(id: 'red${sz}x$sz2', name: '${n('Redução', 'Reducer', 'Reducción')} $sz × $sz2 mm', kind: FittingKind.reducer, sizeMm: s, size2Mm: s2, cost: price(5, s)));
        if (s2 >= 20 || s <= 75) out.add(FittingSpec(id: 'teer${sz}x$sz2', name: '${n('Tê de redução', 'Reducing tee', 'Te de reducción')} $sz × $sz2 mm', kind: FittingKind.tee, sizeMm: s, size2Mm: s2, cost: price(9, s)));
      }
    }
    final lateralSizes = {16.0, 20.0, ...pipes.where((p) => p.usage.contains(PipeUsage.lateral)).map((p) => p.nominalMm)}.toList()..sort();
    for (final s in lateralSizes) {
      final sz = mm(s);
      out.add(FittingSpec(id: 'to$sz', name: '${n('Conector inicial de lateral', 'Lateral take-off', 'Conector inicial de lateral')} $sz mm', kind: FittingKind.takeOff, sizeMm: s, cost: 1.2));
      out.add(FittingSpec(id: 'te$sz', name: '${n('Final de linha', 'Line end', 'Final de línea')} $sz mm', kind: FittingKind.tapeEnd, sizeMm: s, cost: 0.9));
    }
    out.add(FittingSpec(id: 'riser_micro', name: n('Haste/tubinho de microaspersor', 'Micro-sprinkler stake/tube', 'Estaca/microtubo de microaspersor'), kind: FittingKind.riser, sizeMm: 0, cost: 1.1));
    out.add(FittingSpec(id: 'riser20', name: '${n('Tubo de subida', 'Riser', 'Tubo de subida')} 20 mm', kind: FittingKind.riser, sizeMm: 20, cost: 6));
    out.add(FittingSpec(id: 'riser25', name: '${n('Tubo de subida', 'Riser', 'Tubo de subida')} 25 mm', kind: FittingKind.riser, sizeMm: 25, cost: 8));
    out.add(FittingSpec(id: 'riser40', name: '${n('Tubo de subida', 'Riser', 'Tubo de subida')} 40 mm', kind: FittingKind.riser, sizeMm: 40, cost: 18));
    return out;
  }
}
