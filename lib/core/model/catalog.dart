/// Component catalog (pipes, emitters, tapes, valves, pumps) with a generic
/// default database. All hydraulic values are stored in SI.
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../i18n/language_packs.dart';
import 'currency.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/pump.dart';
import '../hydraulics/water_hammer.dart';
import '../units.dart';
import 'read_report.dart';

enum PipeUsage { lateral, zone, mainline }

/// Share of the nominal pressure rating a thermoplastic pipe keeps at the
/// water temperature [tempC] (°C): PVC 1.0 up to 25 °C, 0.9 at 30, 0.8 at 35,
/// 0.7 at 40 and 0.6 at 45 °C (ISO 1452-2 Annex A and the NBR 14312 data
/// sheets); PE 1.0 up to 20 °C, 0.87 at 30 and 0.74 at 40 °C (ISO 4427-1
/// Annex A, 50 years); linear in between, held at the last value above the
/// table. Metals and concrete keep their rating.
double pipeTemperatureDerating(PipeMaterial material, double tempC) {
  const pvc = [(25.0, 1.0), (30.0, 0.9), (35.0, 0.8), (40.0, 0.7), (45.0, 0.6)];
  const pe = [(20.0, 1.0), (30.0, 0.87), (40.0, 0.74)];
  final table = switch (material) {
    PipeMaterial.pvc => pvc,
    PipeMaterial.pehd || PipeMaterial.peld => pe,
    _ => null,
  };
  if (table == null || !tempC.isFinite || tempC <= table.first.$1) return 1.0;
  for (var i = 1; i < table.length; i++) {
    final (t0, f0) = table[i - 1];
    final (t1, f1) = table[i];
    if (tempC <= t1) return f0 + (f1 - f0) * (tempC - t0) / (t1 - t0);
  }
  return table.last.$2;
}

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

  /// Pressure rating (m) at the water temperature [tempC], after the
  /// thermoplastic derating ([pipeTemperatureDerating]).
  double ratingAt(double tempC) => pressureRatingM * pipeTemperatureDerating(material, tempC);

  /// Scobey coefficient Ks of the material (Keller & Bliesner 1990: plastic
  /// 0.32, aluminium with couplers 0.40, galvanised steel 0.42).
  double get scobeyKs => switch (material) {
    PipeMaterial.pvc || PipeMaterial.pehd || PipeMaterial.peld => 0.32,
    PipeMaterial.aluminium || PipeMaterial.concrete => 0.40,
    PipeMaterial.steel || PipeMaterial.ductileIron => 0.42,
  };

  /// Manning n of the material (Chow 1959: plastic 0.009, aluminium 0.011,
  /// steel 0.012, ductile iron and concrete 0.013).
  double get manningN => switch (material) {
    PipeMaterial.pvc || PipeMaterial.pehd || PipeMaterial.peld => 0.009,
    PipeMaterial.aluminium => 0.011,
    PipeMaterial.steel => 0.012,
    PipeMaterial.ductileIron || PipeMaterial.concrete => 0.013,
  };

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'nominalMm': nominalMm,
    'idMm': innerDiameterMm,
    'material': material.name,
    'c': hazenC,
    'roughMm': roughnessMm,
    'ratingM': pressureRatingM,
    'wallMm': wallThicknessMm,
    'cost': costPerM,
    'usage': usage.map((u) => u.name).toList(),
    'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (code.isNotEmpty) 'code': code,
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static PipeSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return PipeSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      supplier: j['sup'] as String? ?? '',
      code: j['code'] as String? ?? '',
      nominalMm: (j['nominalMm'] as num).toDouble(),
      innerDiameterMm: (j['idMm'] as num).toDouble(),
      material: enumByName(PipeMaterial.values, j['material'], PipeMaterial.pvc, report: report, key: 'material'),
      hazenC: (j['c'] as num?)?.toDouble() ?? 150,
      roughnessMm: (j['roughMm'] as num?)?.toDouble() ?? 0.0015,
      pressureRatingM: (j['ratingM'] as num?)?.toDouble() ?? 60,
      wallThicknessMm: (j['wallMm'] as num?)?.toDouble() ?? 2,
      costPerM: (j['cost'] as num?)?.toDouble() ?? 0,
      usage: {
        for (final u in (j['usage'] as List?) ?? const ['zone', 'mainline']) ?enumOrNull(PipeUsage.values, u, report: report, key: 'usage'),
      },
      enabled: j['enabled'] as bool? ?? true,
    )..extra = j.unread;
  }
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
    List<(double, double)>? profile,
  }) : profile = profile ?? const [];
  final String id;
  String name;
  EmitterCurve curve;
  double arcDeg;

  /// Measured radial distribution of the water (catch-can test): pairs of
  /// distance as a fraction of the wetted radius (0–1) and the relative
  /// depth there; empty = the profile chosen in the densogram.
  List<(double, double)> profile;
  double minHeadM;
  double maxHeadM;
  double defaultHeadM;
  double cv;
  double flowTolBelow;
  double flowTolAbove;

  /// Sector (degrees, 1–360) a head with this nozzle waters when the arc
  /// set on the head is [headArcDeg]: a part-circle nozzle on a head left at
  /// a full circle still waters only its own arc.
  double effectiveArcDeg(double headArcDeg) => (arcDeg < 360 && headArcDeg >= 360 ? arcDeg : headArcDeg).clamp(1.0, 360.0).toDouble();

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'curve': curve.toJson(),
    'arc': arcDeg,
    'minH': minHeadM,
    'maxH': maxHeadM,
    'defH': defaultHeadM,
    'cv': cv,
    'tolB': flowTolBelow,
    'tolA': flowTolAbove,
    if (profile.isNotEmpty)
      'prof': [
        for (final (x, y) in profile) [x, y],
      ],
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static NozzleSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return NozzleSpec(
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
      profile: [for (final e in (j['prof'] as List?) ?? const []) (((e as List)[0] as num).toDouble(), (e[1] as num).toDouble())],
    )..extra = j.unread;
  }
}

/// Radial profile of a nozzle from a catch-can table: [rows] of (distance
/// from the head in m, depth or rate in any unit), sorted, scaled to the
/// largest distance with water (that is the wetted radius) and to the
/// largest depth; null when fewer than two rows carry water.
List<(double, double)>? profileFromTable(List<(double, double)> rows) {
  final pts = [
    for (final r in rows)
      if (r.$1 >= 0 && r.$2 >= 0 && r.$1.isFinite && r.$2.isFinite) r,
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final wet = pts.where((r) => r.$2 > 0).toList();
  if (wet.length < 2) return null;
  final radius = pts.where((r) => r.$2 > 0).map((r) => r.$1).reduce(math.max);
  final top = wet.map((r) => r.$2).reduce(math.max);
  if (radius <= 0 || top <= 0) return null;
  return [
    for (final (d, v) in pts)
      if (d <= radius) (d / radius, v / top),
  ];
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

  /// The nozzle [id]: the first one when no id is given; null when the item
  /// has no nozzle of that id (deleted, renamed, or heads pasted from a
  /// project whose item of the same id has other nozzles), so the design
  /// reports `nozzle_missing` instead of quietly using another nozzle.
  NozzleSpec? nozzle(String? id) {
    if (nozzles.isEmpty) return null;
    if (id == null || id.isEmpty) return nozzles.first;
    for (final n in nozzles) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'kind': kind.name,
    'nozzles': nozzles.map((n) => n.toJson()).toList(),
    'cost': cost,
    'inletMm': inletMm,
    'riser': riserHeightM,
    'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (code.isNotEmpty) 'code': code,
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static OutletSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return OutletSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      supplier: j['sup'] as String? ?? '',
      code: j['code'] as String? ?? '',
      kind: enumByName(OutletKind.values, j['kind'], OutletKind.sprinkler, report: report, key: 'kind'),
      nozzles: (j['nozzles'] as List).map((n) => NozzleSpec.fromJson(n as Map<String, dynamic>, report: report)).toList(),
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      inletMm: (j['inletMm'] as num?)?.toDouble() ?? 20,
      riserHeightM: (j['riser'] as num?)?.toDouble() ?? 0,
      enabled: j['enabled'] as bool? ?? true,
    )..extra = j.unread;
  }
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

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'nominalMm': nominalMm,
    'idMm': innerDiameterMm,
    'spacing': emitterSpacingM,
    'emitter': emitter.toJson(),
    'barbK': barbK,
    'cv': cv,
    'minH': minHeadM,
    'maxH': maxHeadM,
    'inletH': defaultInletHeadM,
    'tolB': tolBelowPct,
    'tolA': tolAbovePct,
    'ratingM': pressureRatingM,
    'roughMm': roughnessMm,
    'c': hazenC,
    'cost': costPerM,
    'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (code.isNotEmpty) 'code': code,
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static TapeSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return TapeSpec(
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
    )..extra = j.unread;
  }
}

/// Kinds of valves and devices; [master] is the master valve on the
/// mainline that the controller opens with every zone, [psv] sustains the
/// pressure upstream of it and [fcv] limits the flow through it (the flow
/// limiter of a hydrant).
enum ValveKind { control, prv, isolation, check, backflow, filter, meter, airRelease, other, master, psv, fcv }

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

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'kind': kind.name,
    'sizeMm': sizeMm,
    'loss': loss.toJson(),
    'minQ': minFlow,
    'maxQ': maxFlow,
    'cost': cost,
    'setting': defaultSettingM,
    'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (code.isNotEmpty) 'code': code,
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static ValveSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return ValveSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      supplier: j['sup'] as String? ?? '',
      code: j['code'] as String? ?? '',
      kind: enumByName(ValveKind.values, j['kind'], ValveKind.other, report: report, key: 'kind'),
      sizeMm: (j['sizeMm'] as num).toDouble(),
      loss: DeviceLossCurve.fromJson(j['loss'] as Map<String, dynamic>),
      minFlow: (j['minQ'] as num?)?.toDouble() ?? 0,
      maxFlow: (j['maxQ'] as num?)?.toDouble() ?? 1,
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      defaultSettingM: (j['setting'] as num?)?.toDouble() ?? 0,
      enabled: j['enabled'] as bool? ?? true,
    )..extra = j.unread;
  }
}

/// Ids of the submersible pumps of the default catalog.
const defaultSubmersiblePumpIds = {'pump_s3', 'pump_s5', 'pump_sub', 'pump_s15', 'pump_s25', 'pump_s30'};

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
    this.submersible = false,
    this.ratedHz = 0,
    List<(double, double)>? efficiencyPoints,
    List<(double, double)>? npshPoints,
  }) : curve = PumpCurve.fit(points),
       efficiencyPoints = efficiencyPoints ?? const [],
       npshPoints = npshPoints ?? const [];
  final String id;
  String name;
  String supplier;
  String code;

  /// Rated motor power (kW), informative.
  double powerKw;

  /// Installed in the well below the water level (no suction lift); a
  /// surface pump draws water up its suction pipe, limited by the NPSH.
  bool submersible;

  /// Mains frequency (Hz) the curve was measured at; 0 = not stated. On
  /// other mains a fixed-speed motor turns that much slower or faster
  /// ([mainsSpeedRatio]).
  double ratedHz;

  /// Speed ratio of a fixed-speed motor of this pump on [mainsHz] mains
  /// (affinity laws: 60 Hz curves on 50 Hz mains run at 5/6 of the speed).
  double mainsSpeedRatio(double mainsHz) => ratedHz > 0 && mainsHz > 0 ? mainsHz / ratedHz : 1;

  /// (Q m³/s, H m) samples of the manufacturer's curve.
  List<(double, double)> points;
  PumpCurve curve;
  double efficiency;
  double minFlow;
  double maxFlow;
  double cost;
  bool enabled;

  /// (Q m³/s, efficiency 0–1) of the manufacturer's efficiency curve at
  /// full speed; empty = the single [efficiency].
  List<(double, double)> efficiencyPoints;

  /// (Q m³/s, NPSH required m) at full speed; empty = no NPSH check beyond
  /// the practical suction lift.
  List<(double, double)> npshPoints;

  void refit() => curve = PumpCurve.fit(points);

  /// Efficiency at flow [q] and [speed] ratio: the full-speed curve read at
  /// the homologous flow q/speed (affinity laws keep the efficiency of
  /// homologous points), else the single value.
  double efficiencyAt(double q, {double speed = 1}) {
    if (efficiencyPoints.length < 2) return efficiency;
    return math.max(0.05, _interp(efficiencyPoints, q / math.max(speed, 0.05)));
  }

  /// NPSH required (m) at flow [q] and [speed] ratio (NPSHr ∝ n²), or null
  /// when the curve is unknown.
  double? npshrAt(double q, {double speed = 1}) {
    if (npshPoints.isEmpty) return null;
    final s = math.max(speed, 0.05);
    return _interp(npshPoints, q / s) * s * s;
  }

  static double _interp(List<(double, double)> pts, double x) {
    final p = [...pts]..sort((a, b) => a.$1.compareTo(b.$1));
    if (p.length == 1 || x <= p.first.$1) return p.first.$2;
    for (var i = 1; i < p.length; i++) {
      if (x <= p[i].$1) {
        final (x0, y0) = p[i - 1];
        final (x1, y1) = p[i];
        return x1 > x0 ? y0 + (y1 - y0) * (x - x0) / (x1 - x0) : y1;
      }
    }
    // beyond the last point: extend the last segment (the required NPSH
    // keeps rising towards run-out)
    final (x0, y0) = p[p.length - 2];
    final (x1, y1) = p.last;
    return x1 > x0 ? y1 + (y1 - y0) * (x - x1) / (x1 - x0) : y1;
  }

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'points': points.map((p) => [p.$1, p.$2]).toList(),
    'eff': efficiency,
    'minQ': minFlow,
    'maxQ': maxFlow,
    'cost': cost,
    'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (code.isNotEmpty) 'code': code,
    if (powerKw > 0) 'kw': powerKw,
    'sub': submersible,
    if (ratedHz > 0) 'hz': ratedHz,
    if (efficiencyPoints.isNotEmpty)
      'effPts': [
        for (final (q, e) in efficiencyPoints) [q, e],
      ],
    if (npshPoints.isNotEmpty)
      'npsh': [
        for (final (q, n) in npshPoints) [q, n],
      ],
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static PumpSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return PumpSpec(
      id: j['id'] as String,
      // catalogs saved before the flag existed: the generic submersible units
      submersible: j['sub'] as bool? ?? defaultSubmersiblePumpIds.contains(j['id']),
      name: j['name'] as String,
      supplier: j['sup'] as String? ?? '',
      code: j['code'] as String? ?? '',
      powerKw: (j['kw'] as num?)?.toDouble() ?? 0,
      ratedHz: (j['hz'] as num?)?.toDouble() ?? 0,
      points: (j['points'] as List).map((p) => ((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList(),
      efficiency: (j['eff'] as num?)?.toDouble() ?? 0.7,
      minFlow: (j['minQ'] as num?)?.toDouble() ?? 0,
      maxFlow: (j['maxQ'] as num?)?.toDouble() ?? 1,
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      enabled: j['enabled'] as bool? ?? true,
      efficiencyPoints: [for (final p in (j['effPts'] as List?) ?? const []) (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())],
      npshPoints: [for (final p in (j['npsh'] as List?) ?? const []) (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())],
    )..extra = j.unread;
  }
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

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'kind': kind.name,
    'sizeMm': sizeMm,
    if (size2Mm > 0) 'size2Mm': size2Mm,
    'cost': cost,
    'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (code.isNotEmpty) 'code': code,
    if (material.isNotEmpty) 'mat': material,
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static FittingSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return FittingSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      kind: enumByName(FittingKind.values, j['kind'], FittingKind.adapter, report: report, key: 'kind'),
      sizeMm: (j['sizeMm'] as num).toDouble(),
      size2Mm: (j['size2Mm'] as num?)?.toDouble() ?? 0,
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      enabled: j['enabled'] as bool? ?? true,
      supplier: j['sup'] as String? ?? '',
      code: j['code'] as String? ?? '',
      material: j['mat'] as String? ?? '',
    )..extra = j.unread;
  }
}

/// Electrical wire (one insulated conductor for direct burial) that carries
/// the 24 V AC from the controller to the valve solenoids.
class WireSpec {
  WireSpec({required this.id, required this.name, required this.sectionMm2, required this.ohmPerKm, this.costPerM = 0, this.enabled = true, this.supplier = '', this.code = ''});
  final String id;
  String name;
  String supplier;
  String code;

  /// Conductor cross-section (mm²).
  double sectionMm2;

  /// Resistance of one conductor (Ω per km at 20 °C).
  double ohmPerKm;
  double costPerM;
  bool enabled;

  /// Resistance of [lengthM] metres of this conductor (Ω).
  double resistance(double lengthM) => ohmPerKm * lengthM / 1000;

  /// Fields of a newer version, kept as read and written back.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'id': id,
    'name': name,
    'mm2': sectionMm2,
    'ohm': ohmPerKm,
    'cost': costPerM,
    'enabled': enabled,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (code.isNotEmpty) 'code': code,
  };

  /// Reads the item; options this version does not know take their
  /// default (noted in [report]), fields it does not know are kept.
  static WireSpec fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    return WireSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      sectionMm2: (j['mm2'] as num?)?.toDouble() ?? 1.5,
      // a copper conductor when the file gives only the section
      ohmPerKm: (j['ohm'] as num?)?.toDouble() ?? copperOhmPerKm((j['mm2'] as num?)?.toDouble() ?? 1.5),
      costPerM: (j['cost'] as num?)?.toDouble() ?? 0,
      enabled: j['enabled'] as bool? ?? true,
      supplier: j['sup'] as String? ?? '',
      code: j['code'] as String? ?? '',
    )..extra = j.unread;
  }
}

/// Resistance (Ω/km at 20 °C) of a stranded copper conductor of [mm2]
/// (resistivity 0.0178 Ω·mm²/m with the IEC 60228 stranding allowance).
double copperOhmPerKm(double mm2) => mm2 > 0 ? 18.1 / mm2 : double.infinity;

/// Cross-section (mm²) of American Wire Gauge [awg].
double awgMm2(int awg) => math.pi / 4 * math.pow(0.127 * math.pow(92, (36 - awg) / 39), 2);

class Catalog {
  Catalog({
    List<PipeSpec>? pipes,
    List<OutletSpec>? outlets,
    List<TapeSpec>? tapes,
    List<ValveSpec>? valves,
    List<PumpSpec>? pumps,
    List<FittingSpec>? fittings,
    List<WireSpec>? wires,
    Map<String, String>? finame,
  }) : pipes = pipes ?? [],
       outlets = outlets ?? [],
       tapes = tapes ?? [],
       valves = valves ?? [],
       pumps = pumps ?? [],
       fittings = fittings ?? [],
       wires = wires ?? [],
       finame = finame ?? {};

  /// Code under which an item is credentialed for financing by the
  /// Brazilian development bank (BNDES FINAME), by item id; the bill of
  /// materials and the quote show which part of the purchase it covers.
  final Map<String, String> finame;

  final List<PipeSpec> pipes;
  final List<OutletSpec> outlets;
  final List<TapeSpec> tapes;
  final List<ValveSpec> valves;
  final List<PumpSpec> pumps;
  final List<FittingSpec> fittings;
  final List<WireSpec> wires;

  WireSpec? wire(String? id) => _wireAt.find(wires, id);

  /// Enabled wires, thinnest (highest resistance) first.
  List<WireSpec> get enabledWires => wires.where((w) => w.enabled && w.ohmPerKm > 0).toList()..sort((a, b) => b.ohmPerKm.compareTo(a.ohmPerKm));

  FittingSpec? fitting(String? id) => _fittingAt.find(fittings, id);

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
    final used = {
      ...pipes.map((e) => e.id),
      ...outlets.map((e) => e.id),
      ...tapes.map((e) => e.id),
      ...valves.map((e) => e.id),
      ...pumps.map((e) => e.id),
      ...fittings.map((e) => e.id),
      ...wires.map((e) => e.id),
    };
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
    go(wires, other.wires, (p) => p.id);
    for (final e in other.finame.entries) {
      if (replace || !finame.containsKey(e.key)) finame[e.key] = e.value;
    }
    return n;
  }

  int get itemCount => pipes.length + outlets.length + tapes.length + valves.length + pumps.length + fittings.length + wires.length;

  Catalog copy() => Catalog.fromJson(toJson());

  PipeSpec? pipe(String? id) => _pipeAt.find(pipes, id);
  OutletSpec? outlet(String? id) => _outletAt.find(outlets, id);
  TapeSpec? tape(String? id) => _tapeAt.find(tapes, id);
  ValveSpec? valve(String? id) => _valveAt.find(valves, id);
  PumpSpec? pump(String? id) => _pumpAt.find(pumps, id);

  final _pipeAt = _IdLookup<PipeSpec>((p) => p.id);
  final _outletAt = _IdLookup<OutletSpec>((p) => p.id);
  final _tapeAt = _IdLookup<TapeSpec>((p) => p.id);
  final _valveAt = _IdLookup<ValveSpec>((p) => p.id);
  final _pumpAt = _IdLookup<PumpSpec>((p) => p.id);
  final _fittingAt = _IdLookup<FittingSpec>((p) => p.id);
  final _wireAt = _IdLookup<WireSpec>((p) => p.id);

  List<PipeSpec> pipesFor(PipeUsage usage) => pipes.where((p) => p.enabled && p.usage.contains(usage)).toList()..sort((a, b) => a.innerDiameterMm.compareTo(b.innerDiameterMm));

  /// Items that could not be read, by list (`pipes`, `outlets`…), kept as
  /// they were and written back under `unreadable` (every read tries them
  /// again).
  final Map<String, List<Object?>> unreadable = {};

  /// Top-level fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'pipes': pipes.map((p) => p.toJson()).toList(),
    'outlets': outlets.map((p) => p.toJson()).toList(),
    'tapes': tapes.map((p) => p.toJson()).toList(),
    'valves': valves.map((p) => p.toJson()).toList(),
    'pumps': pumps.map((p) => p.toJson()).toList(),
    'fittings': fittings.map((p) => p.toJson()).toList(),
    if (wires.isNotEmpty) 'wires': wires.map((p) => p.toJson()).toList(),
    if (finame.isNotEmpty) 'finame': finame,
    if (unreadable.isNotEmpty) 'unreadable': {for (final e in unreadable.entries) e.key: List.of(e.value)},
  };

  /// Reads a catalogue item by item: an item that cannot be read is set
  /// aside in [unreadable] (counted in [report]), options this version does
  /// not know take their default and unknown fields are kept.
  static Catalog fromJson(Map<String, dynamic> json, {ProjectReadReport? report}) {
    final j = KeyLog(json);
    final aside = <String, List<Object?>>{};
    List<T> each<T>(String key, T Function(Map<String, dynamic>) read) {
      final out = <T>[];
      final retry = j['unreadable'] is Map ? (j['unreadable'] as Map)[key] : null;
      for (final list in [j[key], retry]) {
        if (list is! List) continue;
        for (final x in list) {
          try {
            out.add(read((x as Map).cast<String, dynamic>()));
          } catch (_) {
            report?.skip('catalog');
            if (x is Map) (aside[key] ??= []).add(x);
          }
        }
      }
      return out;
    }

    final c = Catalog(
      finame: {
        for (final e in ((j['finame'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String && (e.value as String).trim().isNotEmpty) e.key as String: (e.value as String).trim(),
      },
      pipes: each('pipes', (m) => PipeSpec.fromJson(m, report: report)),
      outlets: each('outlets', (m) => OutletSpec.fromJson(m, report: report)),
      tapes: each('tapes', (m) => TapeSpec.fromJson(m, report: report)),
      valves: each('valves', (m) => ValveSpec.fromJson(m, report: report)),
      pumps: each('pumps', (m) => PumpSpec.fromJson(m, report: report)),
      fittings: each('fittings', (m) => FittingSpec.fromJson(m, report: report)),
      wires: each('wires', (m) => WireSpec.fromJson(m, report: report)),
    );
    c.unreadable.addAll(aside);
    c.extra = j.unread;
    return c;
  }

  /// Price per metre used by the economic sizing: the catalogue price, or
  /// for a pipe without one (a manufacturer pack, prices still to be filled
  /// in) an estimate proportional to the wall cross-section, the price per
  /// mm² of wall being the median of the priced pipes of the same material
  /// (of any material when none is priced). Without any priced pipe the
  /// estimate only orders the diameters. Keyed by pipe id.
  Map<String, double> sizingPipeCosts() {
    double wall(PipeSpec s) {
      final di = s.innerDiameterMm;
      final t = s.wallThicknessMm > 0 ? s.wallThicknessMm : math.max(0.0, (s.nominalMm - di) / 2);
      final dout = di + 2 * math.max(t, 0.1);
      return math.pi / 4 * (dout * dout - di * di);
    }

    double? median(Iterable<double> v) {
      final l = v.where((x) => x.isFinite && x > 0).toList()..sort();
      if (l.isEmpty) return null;
      return l.length.isOdd ? l[l.length ~/ 2] : (l[l.length ~/ 2 - 1] + l[l.length ~/ 2]) / 2;
    }

    final priced = pipes.where((s) => s.costPerM > 0).toList();
    final all = median(priced.map((s) => s.costPerM / wall(s)));
    final out = <String, double>{};
    for (final s in pipes) {
      if (s.costPerM > 0) {
        out[s.id] = s.costPerM;
        continue;
      }
      final perMm2 = median(priced.where((x) => x.material == s.material).map((x) => x.costPerM / wall(x))) ?? all ?? 1e-4;
      out[s.id] = perMm2 * wall(s);
    }
    return out;
  }

  /// Generic default database (metric, illustrative prices) with names in the
  /// requested language. Curves are power-law fits of typical manufacturer data.
  /// The prices are written in [catalogPriceCurrency] and converted to
  /// [currency] (an ISO 4217 code) with the reference exchange rates.
  static Catalog defaultCatalog({String lang = 'en', String currency = catalogPriceCurrency}) {
    final c = _defaultCatalog(lang);
    final rate = exchangeRate(catalogPriceCurrency, currency);
    if (rate != null) scaleCatalogPrices(c, rate);
    return c;
  }

  static Catalog _defaultCatalog(String lang) {
    String n(String pt, String en, String es) => switch (lang) {
      'pt' => pt,
      'es' => es,
      'en' => en,
      _ => packCatalogName(lang, en) ?? en,
    };
    EmitterCurve q(double lph, double headM, double x, {double radiusM = 0}) => EmitterCurve.fromNominal(flow: lph * m3sPerLph, head: headM, x: x, radius: radiusM, radiusB: radiusM > 0 ? 0.35 : 0);

    final pipes = <PipeSpec>[
      // PE laterals: PN 4 in low-density PE, PN 6 in PE 80 (ISO 4427-2 SDR 21,
      // 2 mm least wall)
      PipeSpec(
        id: 'pe16',
        name: 'PE 16 mm (PN 4)',
        nominalMm: 16,
        innerDiameterMm: 13.6,
        material: PipeMaterial.peld,
        hazenC: 140,
        roughnessMm: 0.003,
        pressureRatingM: 40,
        wallThicknessMm: 1.2,
        costPerM: 0.9,
        usage: {PipeUsage.lateral},
      ),
      PipeSpec(
        id: 'pe20',
        name: 'PE 20 mm (PN 4)',
        nominalMm: 20,
        innerDiameterMm: 17.0,
        material: PipeMaterial.peld,
        hazenC: 140,
        roughnessMm: 0.003,
        pressureRatingM: 40,
        wallThicknessMm: 1.5,
        costPerM: 1.3,
        usage: {PipeUsage.lateral},
      ),
      PipeSpec(
        id: 'pe25',
        name: 'PE 25 mm (PN 6)',
        nominalMm: 25,
        innerDiameterMm: 21.0,
        material: PipeMaterial.pehd,
        hazenC: 145,
        roughnessMm: 0.003,
        pressureRatingM: 60,
        wallThicknessMm: 2.0,
        costPerM: 2.1,
        usage: {PipeUsage.lateral, PipeUsage.zone},
      ),
      PipeSpec(
        id: 'pe32',
        name: 'PE 32 mm (PN 6)',
        nominalMm: 32,
        innerDiameterMm: 28.0,
        material: PipeMaterial.pehd,
        hazenC: 145,
        roughnessMm: 0.003,
        pressureRatingM: 60,
        wallThicknessMm: 2.0,
        costPerM: 3.2,
        usage: {PipeUsage.lateral, PipeUsage.zone},
      ),
      PipeSpec(
        id: 'pe40',
        name: 'PE 40 mm (PN 6)',
        nominalMm: 40,
        innerDiameterMm: 36.0,
        material: PipeMaterial.pehd,
        hazenC: 145,
        roughnessMm: 0.003,
        pressureRatingM: 60,
        wallThicknessMm: 2.0,
        costPerM: 4.9,
        usage: {PipeUsage.zone},
      ),
      PipeSpec(
        id: 'pe50',
        name: 'PE 50 mm (PN 6)',
        nominalMm: 50,
        innerDiameterMm: 45.2,
        material: PipeMaterial.pehd,
        hazenC: 145,
        roughnessMm: 0.003,
        pressureRatingM: 60,
        wallThicknessMm: 2.4,
        costPerM: 7.4,
        usage: {PipeUsage.zone},
      ),
      // PVC irrigation PN 80 (metres of head): the walls and bores of NBR
      // 14312 up to DN 150 and of ISO 1452-2 S 12.5 (PN 8) above it
      PipeSpec(
        id: 'pvc35',
        name: 'PVC DN 35 PN 80',
        nominalMm: 35,
        innerDiameterMm: 34.3,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 1.9,
        costPerM: 4.5,
        usage: {PipeUsage.zone, PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pvc50',
        name: 'PVC DN 50 PN 80',
        nominalMm: 50,
        innerDiameterMm: 46.7,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 1.9,
        costPerM: 7.2,
        usage: {PipeUsage.zone, PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pvc75',
        name: 'PVC DN 75 PN 80',
        nominalMm: 75,
        innerDiameterMm: 70.5,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 2.5,
        costPerM: 14.5,
        usage: {PipeUsage.zone, PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pvc100',
        name: 'PVC DN 100 PN 80',
        nominalMm: 100,
        innerDiameterMm: 94.4,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 3.6,
        costPerM: 24.0,
        usage: {PipeUsage.zone, PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pvc125',
        name: 'PVC DN 125 PN 80',
        nominalMm: 125,
        innerDiameterMm: 116.6,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 4.2,
        costPerM: 36.0,
        usage: {PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pvc150',
        name: 'PVC DN 150 PN 80',
        nominalMm: 150,
        innerDiameterMm: 140.0,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 5.0,
        costPerM: 52.0,
        usage: {PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pvc200',
        name: 'PVC DN 200 PN 80',
        nominalMm: 200,
        innerDiameterMm: 184.6,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 7.7,
        costPerM: 88.0,
        usage: {PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pvc250',
        name: 'PVC DN 250 PN 80',
        nominalMm: 250,
        innerDiameterMm: 230.8,
        hazenC: 150,
        roughnessMm: 0.0015,
        pressureRatingM: 80,
        wallThicknessMm: 9.6,
        costPerM: 135.0,
        usage: {PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pead110',
        name: 'PEAD 110 mm PN 10',
        nominalMm: 110,
        innerDiameterMm: 96.8,
        material: PipeMaterial.pehd,
        hazenC: 150,
        roughnessMm: 0.002,
        pressureRatingM: 100,
        wallThicknessMm: 6.6,
        costPerM: 42.0,
        usage: {PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'pead160',
        name: 'PEAD 160 mm PN 10',
        nominalMm: 160,
        innerDiameterMm: 141.0,
        material: PipeMaterial.pehd,
        hazenC: 150,
        roughnessMm: 0.002,
        pressureRatingM: 100,
        wallThicknessMm: 9.5,
        costPerM: 85.0,
        usage: {PipeUsage.mainline},
      ),
      PipeSpec(
        id: 'steel150',
        name: n('Aço galvanizado 6"', 'Galvanised steel 6"', 'Acero galvanizado 6"'),
        nominalMm: 150,
        innerDiameterMm: 154.0,
        material: PipeMaterial.steel,
        hazenC: 120,
        roughnessMm: 0.15,
        pressureRatingM: 200,
        wallThicknessMm: 4.5,
        costPerM: 160.0,
        usage: {PipeUsage.mainline},
        enabled: false,
      ),
    ];

    final outlets = <OutletSpec>[
      OutletSpec(
        id: 'drip_pc',
        name: n('Gotejador PC (botão)', 'PC dripper (button)', 'Gotero PC (botón)'),
        kind: OutletKind.dripper,
        inletMm: 0,
        nozzles: [
          NozzleSpec(id: 'pc2', name: '2 L/h PC', curve: q(2, 10, 0.03), minHeadM: 5, maxHeadM: 40, defaultHeadM: 10, cv: 0.03),
          NozzleSpec(id: 'pc4', name: '4 L/h PC', curve: q(4, 10, 0.03), minHeadM: 5, maxHeadM: 40, defaultHeadM: 10, cv: 0.03),
          NozzleSpec(id: 'pc8', name: '8 L/h PC', curve: q(8, 10, 0.03), minHeadM: 5, maxHeadM: 40, defaultHeadM: 10, cv: 0.03),
        ],
        cost: 0.6,
      ),
      OutletSpec(
        id: 'drip_turb',
        name: n('Gotejador turbulento', 'Turbulent dripper', 'Gotero turbulento'),
        kind: OutletKind.dripper,
        inletMm: 0,
        nozzles: [
          NozzleSpec(id: 't2', name: '2 L/h', curve: q(2, 10, 0.5), minHeadM: 5, maxHeadM: 25, defaultHeadM: 10, cv: 0.04),
          NozzleSpec(id: 't4', name: '4 L/h', curve: q(4, 10, 0.5), minHeadM: 5, maxHeadM: 25, defaultHeadM: 10, cv: 0.04),
          NozzleSpec(id: 't8', name: '8 L/h', curve: q(8, 10, 0.5), minHeadM: 5, maxHeadM: 25, defaultHeadM: 10, cv: 0.04),
        ],
        cost: 0.35,
      ),
      OutletSpec(
        id: 'micro',
        name: n('Microaspersor 360°', 'Micro-sprinkler 360°', 'Microaspersor 360°'),
        kind: OutletKind.microSprinkler,
        inletMm: 0,
        riserHeightM: 0.3,
        nozzles: [
          NozzleSpec(
            id: 'm35',
            name: n('35 L/h (raio 3,0 m)', '35 L/h (radius 3.0 m)', '35 L/h (radio 3,0 m)'),
            curve: q(35, 15, 0.5, radiusM: 3.0),
            minHeadM: 10,
            maxHeadM: 30,
            defaultHeadM: 15,
            cv: 0.05,
          ),
          NozzleSpec(
            id: 'm50',
            name: n('50 L/h (raio 3,5 m)', '50 L/h (radius 3.5 m)', '50 L/h (radio 3,5 m)'),
            curve: q(50, 15, 0.5, radiusM: 3.5),
            minHeadM: 10,
            maxHeadM: 30,
            defaultHeadM: 15,
            cv: 0.05,
          ),
          NozzleSpec(
            id: 'm70',
            name: n('70 L/h (raio 4,0 m)', '70 L/h (radius 4.0 m)', '70 L/h (radio 4,0 m)'),
            curve: q(70, 15, 0.5, radiusM: 4.0),
            minHeadM: 10,
            maxHeadM: 30,
            defaultHeadM: 15,
            cv: 0.05,
          ),
          NozzleSpec(
            id: 'm120',
            name: n('120 L/h (raio 5,0 m)', '120 L/h (radius 5.0 m)', '120 L/h (radio 5,0 m)'),
            curve: q(120, 20, 0.5, radiusM: 5.0),
            minHeadM: 15,
            maxHeadM: 35,
            defaultHeadM: 20,
            cv: 0.05,
          ),
        ],
        cost: 2.8,
      ),
      OutletSpec(
        id: 'micro_pc',
        name: n('Microaspersor PC', 'PC micro-sprinkler', 'Microaspersor PC'),
        kind: OutletKind.microSprinkler,
        inletMm: 0,
        riserHeightM: 0.3,
        nozzles: [
          NozzleSpec(
            id: 'mpc40',
            name: n('40 L/h PC (raio 3,5 m)', '40 L/h PC (radius 3.5 m)', '40 L/h PC (radio 3,5 m)'),
            curve: q(40, 15, 0.05, radiusM: 3.5),
            minHeadM: 12,
            maxHeadM: 40,
            defaultHeadM: 20,
            cv: 0.05,
          ),
          NozzleSpec(
            id: 'mpc70',
            name: n('70 L/h PC (raio 4,5 m)', '70 L/h PC (radius 4.5 m)', '70 L/h PC (radio 4,5 m)'),
            curve: q(70, 15, 0.05, radiusM: 4.5),
            minHeadM: 12,
            maxHeadM: 40,
            defaultHeadM: 20,
            cv: 0.05,
          ),
        ],
        cost: 3.9,
      ),
      // bubblers flood a tree basin or a planter: pressure compensating, a
      // short stream, the flows of the usual 0.25 to 2 gpm series
      OutletSpec(
        id: 'bubbler_pc',
        name: n('Borbulhador PC', 'PC bubbler', 'Burbujeador PC'),
        kind: OutletKind.bubbler,
        inletMm: 15,
        riserHeightM: 0.15,
        nozzles: [
          NozzleSpec(id: 'b57', name: '57 L/h', curve: q(57, 20, 0.05, radiusM: 0.4), minHeadM: 14, maxHeadM: 60, defaultHeadM: 20, cv: 0.05),
          NozzleSpec(id: 'b114', name: '114 L/h', curve: q(114, 20, 0.05, radiusM: 0.5), minHeadM: 14, maxHeadM: 60, defaultHeadM: 20, cv: 0.05),
          NozzleSpec(id: 'b227', name: '227 L/h', curve: q(227, 20, 0.05, radiusM: 0.6), minHeadM: 14, maxHeadM: 60, defaultHeadM: 20, cv: 0.05),
          NozzleSpec(id: 'b454', name: '454 L/h', curve: q(454, 20, 0.05, radiusM: 0.8), minHeadM: 14, maxHeadM: 60, defaultHeadM: 20, cv: 0.05),
        ],
        cost: 1.9,
      ),
      // flows of a single round nozzle at a discharge coefficient of 0.96
      // (q = Cd·π/4·d²·√(2gH)); the 5 mm nozzle is rated at 35 m
      OutletSpec(
        id: 'impact34',
        name: n('Aspersor de impacto 3/4"', 'Impact sprinkler 3/4"', 'Aspersor de impacto 3/4"'),
        kind: OutletKind.sprinkler,
        inletMm: 20,
        riserHeightM: 1.0,
        nozzles: [
          NozzleSpec(
            id: 'i2.5',
            name: n('Bocal 2,5 mm (0,41 m³/h, R 10,5 m)', 'Nozzle 2.5 mm (0.41 m³/h, R 10.5 m)', 'Boquilla 2,5 mm (0,41 m³/h, R 10,5 m)'),
            curve: q(411, 30, 0.5, radiusM: 10.5),
            minHeadM: 20,
            maxHeadM: 45,
            defaultHeadM: 30,
            cv: 0.03,
            arcDeg: 360,
          ),
          NozzleSpec(
            id: 'i3.5',
            name: n('Bocal 3,5 mm (0,81 m³/h, R 12 m)', 'Nozzle 3.5 mm (0.81 m³/h, R 12 m)', 'Boquilla 3,5 mm (0,81 m³/h, R 12 m)'),
            curve: q(807, 30, 0.5, radiusM: 12),
            minHeadM: 20,
            maxHeadM: 45,
            defaultHeadM: 30,
            cv: 0.03,
            arcDeg: 360,
          ),
          NozzleSpec(
            id: 'i4.0',
            name: n('Bocal 4,0 mm (1,05 m³/h, R 13 m)', 'Nozzle 4.0 mm (1.05 m³/h, R 13 m)', 'Boquilla 4,0 mm (1,05 m³/h, R 13 m)'),
            curve: q(1053, 30, 0.5, radiusM: 13),
            minHeadM: 20,
            maxHeadM: 45,
            defaultHeadM: 30,
            cv: 0.03,
            arcDeg: 360,
          ),
          NozzleSpec(
            id: 'i4.5',
            name: n('Bocal 4,5 mm (1,33 m³/h, R 14 m)', 'Nozzle 4.5 mm (1.33 m³/h, R 14 m)', 'Boquilla 4,5 mm (1,33 m³/h, R 14 m)'),
            curve: q(1333, 30, 0.5, radiusM: 14),
            minHeadM: 20,
            maxHeadM: 45,
            defaultHeadM: 30,
            cv: 0.03,
            arcDeg: 360,
          ),
          NozzleSpec(
            id: 'i5.0',
            name: n('Bocal 5,0 mm (1,78 m³/h, R 15 m)', 'Nozzle 5.0 mm (1.78 m³/h, R 15 m)', 'Boquilla 5,0 mm (1,78 m³/h, R 15 m)'),
            curve: q(1778, 35, 0.5, radiusM: 15),
            minHeadM: 25,
            maxHeadM: 50,
            defaultHeadM: 35,
            cv: 0.03,
            arcDeg: 360,
          ),
        ],
        cost: 18.0,
      ),
      OutletSpec(
        id: 'gun',
        name: n('Canhão hidráulico 1,5"', 'Big gun 1.5"', 'Cañón de riego 1,5"'),
        kind: OutletKind.gun,
        inletMm: 40,
        riserHeightM: 1.5,
        nozzles: [
          NozzleSpec(
            id: 'g14',
            name: n('Bocal 14 mm (15 m³/h, R 32 m)', 'Nozzle 14 mm (15 m³/h, R 32 m)', 'Boquilla 14 mm (15 m³/h, R 32 m)'),
            curve: q(15000, 40, 0.5, radiusM: 32),
            minHeadM: 30,
            maxHeadM: 70,
            defaultHeadM: 40,
            cv: 0.03,
          ),
          NozzleSpec(
            id: 'g18',
            name: n('Bocal 18 mm (25 m³/h, R 40 m)', 'Nozzle 18 mm (25 m³/h, R 40 m)', 'Boquilla 18 mm (25 m³/h, R 40 m)'),
            curve: q(25000, 45, 0.5, radiusM: 40),
            minHeadM: 35,
            maxHeadM: 80,
            defaultHeadM: 45,
            cv: 0.03,
          ),
        ],
        cost: 420.0,
      ),
      OutletSpec(
        id: 'rotor',
        name: n('Rotor de jardim 1/2"', 'Turf rotor 1/2"', 'Rotor de jardín 1/2"'),
        kind: OutletKind.sprinkler,
        inletMm: 15,
        riserHeightM: 0.1,
        nozzles: [
          NozzleSpec(
            id: 'r1.5',
            name: n('#1.5 (0,35 m³/h, R 8 m)', '#1.5 (0.35 m³/h, R 8 m)', '#1.5 (0,35 m³/h, R 8 m)'),
            curve: q(350, 25, 0.5, radiusM: 8),
            minHeadM: 17,
            maxHeadM: 45,
            defaultHeadM: 25,
            cv: 0.03,
            arcDeg: 360,
          ),
          NozzleSpec(
            id: 'r3',
            name: n('#3 (0,70 m³/h, R 10 m)', '#3 (0.70 m³/h, R 10 m)', '#3 (0,70 m³/h, R 10 m)'),
            curve: q(700, 25, 0.5, radiusM: 10),
            minHeadM: 17,
            maxHeadM: 45,
            defaultHeadM: 25,
            cv: 0.03,
            arcDeg: 360,
          ),
          NozzleSpec(
            id: 'r3_180',
            name: n('#3 180° (0,35 m³/h, R 10 m)', '#3 180° (0.35 m³/h, R 10 m)', '#3 180° (0,35 m³/h, R 10 m)'),
            curve: q(350, 25, 0.5, radiusM: 10),
            minHeadM: 17,
            maxHeadM: 45,
            defaultHeadM: 25,
            cv: 0.03,
            arcDeg: 180,
          ),
          NozzleSpec(
            id: 'r3_90',
            name: n('#3 90° (0,18 m³/h, R 10 m)', '#3 90° (0.18 m³/h, R 10 m)', '#3 90° (0,18 m³/h, R 10 m)'),
            curve: q(180, 25, 0.5, radiusM: 10),
            minHeadM: 17,
            maxHeadM: 45,
            defaultHeadM: 25,
            cv: 0.03,
            arcDeg: 90,
          ),
        ],
        cost: 45.0,
      ),
      OutletSpec(
        id: 'spray',
        name: n('Spray pop-up 4"', 'Pop-up spray 4"', 'Difusor emergente 4"'),
        kind: OutletKind.sprinkler,
        inletMm: 15,
        nozzles: [
          NozzleSpec(
            id: 's12',
            name: n('12F (0,60 m³/h, R 3,7 m)', '12F (0.60 m³/h, R 3.7 m)', '12F (0,60 m³/h, R 3,7 m)'),
            curve: q(600, 20, 0.5, radiusM: 3.7),
            minHeadM: 10,
            maxHeadM: 30,
            defaultHeadM: 20,
            cv: 0.04,
            arcDeg: 360,
          ),
          NozzleSpec(
            id: 's12h',
            name: n('12H (0,30 m³/h, R 3,7 m)', '12H (0.30 m³/h, R 3.7 m)', '12H (0,30 m³/h, R 3,7 m)'),
            curve: q(300, 20, 0.5, radiusM: 3.7),
            minHeadM: 10,
            maxHeadM: 30,
            defaultHeadM: 20,
            cv: 0.04,
            arcDeg: 180,
          ),
          NozzleSpec(
            id: 's12q',
            name: n('12Q (0,15 m³/h, R 3,7 m)', '12Q (0.15 m³/h, R 3.7 m)', '12Q (0,15 m³/h, R 3,7 m)'),
            curve: q(150, 20, 0.5, radiusM: 3.7),
            minHeadM: 10,
            maxHeadM: 30,
            defaultHeadM: 20,
            cv: 0.04,
            arcDeg: 90,
          ),
          NozzleSpec(
            id: 's15',
            name: n('15F (0,84 m³/h, R 4,6 m)', '15F (0.84 m³/h, R 4.6 m)', '15F (0,84 m³/h, R 4,6 m)'),
            curve: q(840, 20, 0.5, radiusM: 4.6),
            minHeadM: 10,
            maxHeadM: 30,
            defaultHeadM: 20,
            cv: 0.04,
            arcDeg: 360,
          ),
        ],
        cost: 12.0,
      ),
      OutletSpec(
        id: 'demand',
        name: n('Ponto de demanda', 'Demand point', 'Punto de demanda'),
        kind: OutletKind.demandPoint,
        inletMm: 50,
        nozzles: [
          NozzleSpec(id: 'd5', name: '5 m³/h @ 20 m', curve: q(5000, 20, 0.0), minHeadM: 20, maxHeadM: 80, defaultHeadM: 20, cv: 0, flowTolAbove: 0.5, flowTolBelow: 0.5),
          NozzleSpec(id: 'd10', name: '10 m³/h @ 20 m', curve: q(10000, 20, 0.0), minHeadM: 20, maxHeadM: 80, defaultHeadM: 20, cv: 0, flowTolAbove: 0.5, flowTolBelow: 0.5),
          NozzleSpec(id: 'd20', name: '20 m³/h @ 25 m', curve: q(20000, 25, 0.0), minHeadM: 25, maxHeadM: 80, defaultHeadM: 25, cv: 0, flowTolAbove: 0.5, flowTolBelow: 0.5),
        ],
        cost: 0,
      ),
    ];

    final tapes = <TapeSpec>[
      TapeSpec(
        id: 'tape16_10_30',
        name: n('Fita gotejadora 16 mm, 1,0 L/h @ 0,30 m', 'Drip tape 16 mm, 1.0 L/h @ 0.30 m', 'Cinta de goteo 16 mm, 1,0 L/h @ 0,30 m'),
        innerDiameterMm: 15.6,
        emitterSpacingM: 0.30,
        emitter: q(1.0, 7, 0.5),
        barbK: 0.3,
        cv: 0.03,
        minHeadM: 4,
        maxHeadM: 12,
        defaultInletHeadM: 8,
        pressureRatingM: 15,
        costPerM: 0.45,
      ),
      TapeSpec(
        id: 'tape16_16_20',
        name: n('Fita gotejadora 16 mm, 1,6 L/h @ 0,20 m', 'Drip tape 16 mm, 1.6 L/h @ 0.20 m', 'Cinta de goteo 16 mm, 1,6 L/h @ 0,20 m'),
        innerDiameterMm: 15.6,
        emitterSpacingM: 0.20,
        emitter: q(1.6, 7, 0.5),
        barbK: 0.3,
        cv: 0.03,
        minHeadM: 4,
        maxHeadM: 12,
        defaultInletHeadM: 8,
        pressureRatingM: 15,
        costPerM: 0.55,
      ),
      TapeSpec(
        id: 'drip16_16_50',
        name: n('Tubo gotejador 16 mm, 1,6 L/h @ 0,50 m', 'Dripline 16 mm, 1.6 L/h @ 0.50 m', 'Tubería de goteo 16 mm, 1,6 L/h @ 0,50 m'),
        innerDiameterMm: 13.8,
        emitterSpacingM: 0.50,
        emitter: q(1.6, 10, 0.5),
        barbK: 0.4,
        cv: 0.03,
        minHeadM: 5,
        maxHeadM: 25,
        defaultInletHeadM: 10,
        pressureRatingM: 30,
        costPerM: 1.1,
      ),
      TapeSpec(
        id: 'drip16_24_75',
        name: n('Tubo gotejador 16 mm, 2,4 L/h @ 0,75 m', 'Dripline 16 mm, 2.4 L/h @ 0.75 m', 'Tubería de goteo 16 mm, 2,4 L/h @ 0,75 m'),
        innerDiameterMm: 13.8,
        emitterSpacingM: 0.75,
        emitter: q(2.4, 10, 0.5),
        barbK: 0.4,
        cv: 0.03,
        minHeadM: 5,
        maxHeadM: 25,
        defaultInletHeadM: 10,
        pressureRatingM: 30,
        costPerM: 1.05,
      ),
      TapeSpec(
        id: 'drip16pc_16_50',
        name: n('Tubo gotejador PC 16 mm, 1,6 L/h @ 0,50 m', 'PC dripline 16 mm, 1.6 L/h @ 0.50 m', 'Tubería de goteo PC 16 mm, 1,6 L/h @ 0,50 m'),
        innerDiameterMm: 13.8,
        emitterSpacingM: 0.50,
        emitter: q(1.6, 10, 0.04),
        barbK: 0.4,
        cv: 0.03,
        minHeadM: 6,
        maxHeadM: 40,
        defaultInletHeadM: 15,
        tolBelowPct: 50,
        tolAbovePct: 150,
        pressureRatingM: 40,
        costPerM: 1.6,
      ),
      TapeSpec(
        id: 'drip20pc_23_75',
        name: n('Tubo gotejador PC 20 mm, 2,3 L/h @ 0,75 m', 'PC dripline 20 mm, 2.3 L/h @ 0.75 m', 'Tubería de goteo PC 20 mm, 2,3 L/h @ 0,75 m'),
        innerDiameterMm: 17.5,
        emitterSpacingM: 0.75,
        emitter: q(2.3, 10, 0.04),
        barbK: 0.4,
        cv: 0.03,
        minHeadM: 6,
        maxHeadM: 40,
        defaultInletHeadM: 15,
        tolBelowPct: 50,
        tolAbovePct: 150,
        pressureRatingM: 40,
        costPerM: 2.1,
        nominalMm: 20,
      ),
    ];

    DeviceLossCurve kv(double k, double dMm) => DeviceLossCurve.fromK(k, dMm / 1000);
    final valves = <ValveSpec>[
      ValveSpec(
        id: 'ev25',
        name: n('Válvula elétrica 1"', 'Solenoid valve 1"', 'Electroválvula 1"'),
        kind: ValveKind.control,
        sizeMm: 25,
        loss: kv(6.0, 25),
        minFlow: 0.2 * m3sPerM3h,
        maxFlow: 6 * m3sPerM3h,
        cost: 120,
      ),
      ValveSpec(
        id: 'ev40',
        name: n('Válvula elétrica 1½"', 'Solenoid valve 1½"', 'Electroválvula 1½"'),
        kind: ValveKind.control,
        sizeMm: 40,
        loss: kv(5.5, 40),
        minFlow: 1 * m3sPerM3h,
        maxFlow: 16 * m3sPerM3h,
        cost: 260,
      ),
      ValveSpec(
        id: 'ev50',
        name: n('Válvula elétrica 2"', 'Solenoid valve 2"', 'Electroválvula 2"'),
        kind: ValveKind.control,
        sizeMm: 50,
        loss: kv(5.0, 50),
        minFlow: 2 * m3sPerM3h,
        maxFlow: 30 * m3sPerM3h,
        cost: 380,
      ),
      ValveSpec(
        id: 'ev80',
        name: n('Válvula hidráulica 3"', 'Hydraulic valve 3"', 'Válvula hidráulica 3"'),
        kind: ValveKind.control,
        sizeMm: 80,
        loss: kv(4.5, 80),
        minFlow: 5 * m3sPerM3h,
        maxFlow: 80 * m3sPerM3h,
        cost: 900,
      ),
      ValveSpec(
        id: 'ev100',
        name: n('Válvula hidráulica 4"', 'Hydraulic valve 4"', 'Válvula hidráulica 4"'),
        kind: ValveKind.control,
        sizeMm: 100,
        loss: kv(4.0, 100),
        minFlow: 10 * m3sPerM3h,
        maxFlow: 140 * m3sPerM3h,
        cost: 1500,
      ),
      ValveSpec(
        id: 'ev150',
        name: n('Válvula hidráulica 6"', 'Hydraulic valve 6"', 'Válvula hidráulica 6"'),
        kind: ValveKind.control,
        sizeMm: 150,
        loss: kv(3.5, 150),
        minFlow: 25 * m3sPerM3h,
        maxFlow: 300 * m3sPerM3h,
        cost: 2800,
      ),
      ValveSpec(
        id: 'mv25',
        name: n('Válvula mestra 1"', 'Master valve 1"', 'Válvula maestra 1"'),
        kind: ValveKind.master,
        sizeMm: 25,
        loss: kv(6.0, 25),
        minFlow: 0.2 * m3sPerM3h,
        maxFlow: 6 * m3sPerM3h,
        cost: 120,
      ),
      ValveSpec(
        id: 'mv50',
        name: n('Válvula mestra 2"', 'Master valve 2"', 'Válvula maestra 2"'),
        kind: ValveKind.master,
        sizeMm: 50,
        loss: kv(5.0, 50),
        minFlow: 2 * m3sPerM3h,
        maxFlow: 30 * m3sPerM3h,
        cost: 380,
      ),
      ValveSpec(
        id: 'prv50',
        name: n('Válvula reguladora de pressão 2"', 'Pressure reducing valve 2"', 'Válvula reguladora de presión 2"'),
        kind: ValveKind.prv,
        sizeMm: 50,
        loss: kv(3.0, 50),
        maxFlow: 30 * m3sPerM3h,
        cost: 650,
        defaultSettingM: 25,
      ),
      ValveSpec(
        id: 'prv80',
        name: n('Válvula reguladora de pressão 3"', 'Pressure reducing valve 3"', 'Válvula reguladora de presión 3"'),
        kind: ValveKind.prv,
        sizeMm: 80,
        loss: kv(3.0, 80),
        maxFlow: 80 * m3sPerM3h,
        cost: 1200,
        defaultSettingM: 30,
      ),
      ValveSpec(
        id: 'prv100',
        name: n('Válvula reguladora de pressão 4"', 'Pressure reducing valve 4"', 'Válvula reguladora de presión 4"'),
        kind: ValveKind.prv,
        sizeMm: 100,
        loss: kv(3.0, 100),
        maxFlow: 140 * m3sPerM3h,
        cost: 2100,
        defaultSettingM: 30,
      ),
      ValveSpec(
        id: 'psv50',
        name: n('Válvula sustentadora de pressão 2"', 'Pressure sustaining valve 2"', 'Válvula sostenedora de presión 2"'),
        kind: ValveKind.psv,
        sizeMm: 50,
        loss: kv(3.0, 50),
        maxFlow: 30 * m3sPerM3h,
        cost: 650,
        defaultSettingM: 20,
      ),
      ValveSpec(
        id: 'psv80',
        name: n('Válvula sustentadora de pressão 3"', 'Pressure sustaining valve 3"', 'Válvula sostenedora de presión 3"'),
        kind: ValveKind.psv,
        sizeMm: 80,
        loss: kv(3.0, 80),
        maxFlow: 80 * m3sPerM3h,
        cost: 1200,
        defaultSettingM: 20,
      ),
      ValveSpec(
        id: 'fcv50',
        name: n('Hidrante com limitador de vazão 2"', 'Hydrant with flow limiter 2"', 'Hidrante con limitador de caudal 2"'),
        kind: ValveKind.fcv,
        sizeMm: 50,
        loss: kv(3.5, 50),
        maxFlow: 30 * m3sPerM3h,
        cost: 700,
      ),
      ValveSpec(
        id: 'fcv80',
        name: n('Hidrante com limitador de vazão 3"', 'Hydrant with flow limiter 3"', 'Hidrante con limitador de caudal 3"'),
        kind: ValveKind.fcv,
        sizeMm: 80,
        loss: kv(3.5, 80),
        maxFlow: 80 * m3sPerM3h,
        cost: 1300,
      ),
      ValveSpec(id: 'gate50', name: n('Registro gaveta 2"', 'Gate valve 2"', 'Válvula de compuerta 2"'), kind: ValveKind.isolation, sizeMm: 50, loss: kv(0.2, 50), maxFlow: 40 * m3sPerM3h, cost: 90),
      ValveSpec(id: 'gate80', name: n('Registro gaveta 3"', 'Gate valve 3"', 'Válvula de compuerta 3"'), kind: ValveKind.isolation, sizeMm: 80, loss: kv(0.2, 80), maxFlow: 90 * m3sPerM3h, cost: 220),
      ValveSpec(
        id: 'gate100',
        name: n('Registro gaveta 4"', 'Gate valve 4"', 'Válvula de compuerta 4"'),
        kind: ValveKind.isolation,
        sizeMm: 100,
        loss: kv(0.2, 100),
        maxFlow: 150 * m3sPerM3h,
        cost: 420,
      ),
      ValveSpec(
        id: 'gate150',
        name: n('Registro gaveta 6"', 'Gate valve 6"', 'Válvula de compuerta 6"'),
        kind: ValveKind.isolation,
        sizeMm: 150,
        loss: kv(0.2, 150),
        maxFlow: 350 * m3sPerM3h,
        cost: 900,
      ),
      ValveSpec(
        id: 'check50',
        name: n('Válvula de retenção 2"', 'Check valve 2"', 'Válvula de retención 2"'),
        kind: ValveKind.check,
        sizeMm: 50,
        loss: kv(2.0, 50),
        maxFlow: 40 * m3sPerM3h,
        cost: 150,
      ),
      ValveSpec(
        id: 'check80',
        name: n('Válvula de retenção 3"', 'Check valve 3"', 'Válvula de retención 3"'),
        kind: ValveKind.check,
        sizeMm: 80,
        loss: kv(2.0, 80),
        maxFlow: 90 * m3sPerM3h,
        cost: 260,
      ),
      ValveSpec(
        id: 'check100',
        name: n('Válvula de retenção 4"', 'Check valve 4"', 'Válvula de retención 4"'),
        kind: ValveKind.check,
        sizeMm: 100,
        loss: kv(2.0, 100),
        maxFlow: 150 * m3sPerM3h,
        cost: 380,
      ),
      ValveSpec(
        id: 'filter_disc50',
        name: n('Filtro de discos 2" (120 mesh)', 'Disc filter 2" (120 mesh)', 'Filtro de discos 2" (120 mesh)'),
        kind: ValveKind.filter,
        sizeMm: 50,
        loss: DeviceLossCurve(k: 3.0 / (25 * m3sPerM3h * 25 * m3sPerM3h), n: 2),
        maxFlow: 25 * m3sPerM3h,
        cost: 850,
      ),
      ValveSpec(
        id: 'filter_disc80',
        name: n('Filtro de discos 3" (120 mesh)', 'Disc filter 3" (120 mesh)', 'Filtro de discos 3" (120 mesh)'),
        kind: ValveKind.filter,
        sizeMm: 80,
        loss: DeviceLossCurve(k: 3.0 / (50 * m3sPerM3h * 50 * m3sPerM3h), n: 2),
        maxFlow: 50 * m3sPerM3h,
        cost: 1600,
      ),
      ValveSpec(
        id: 'filter_disc100',
        name: n('Filtro de discos 4" (120 mesh)', 'Disc filter 4" (120 mesh)', 'Filtro de discos 4" (120 mesh)'),
        kind: ValveKind.filter,
        sizeMm: 100,
        loss: DeviceLossCurve(k: 3.0 / (90 * m3sPerM3h * 90 * m3sPerM3h), n: 2),
        maxFlow: 90 * m3sPerM3h,
        cost: 2600,
      ),
      ValveSpec(
        id: 'filter_screen80',
        name: n('Filtro de tela 3"', 'Screen filter 3"', 'Filtro de malla 3"'),
        kind: ValveKind.filter,
        sizeMm: 80,
        loss: DeviceLossCurve(k: 2.5 / (60 * m3sPerM3h * 60 * m3sPerM3h), n: 2),
        maxFlow: 60 * m3sPerM3h,
        cost: 1400,
      ),
      ValveSpec(
        id: 'filter_screen100',
        name: n('Filtro de tela 4"', 'Screen filter 4"', 'Filtro de malla 4"'),
        kind: ValveKind.filter,
        sizeMm: 100,
        loss: DeviceLossCurve(k: 2.5 / (100 * m3sPerM3h * 100 * m3sPerM3h), n: 2),
        maxFlow: 100 * m3sPerM3h,
        cost: 2100,
      ),
      ValveSpec(
        id: 'filter_screen150',
        name: n('Filtro de tela 6"', 'Screen filter 6"', 'Filtro de malla 6"'),
        kind: ValveKind.filter,
        sizeMm: 150,
        loss: DeviceLossCurve(k: 2.5 / (200 * m3sPerM3h * 200 * m3sPerM3h), n: 2),
        maxFlow: 200 * m3sPerM3h,
        cost: 3800,
      ),
      ValveSpec(id: 'meter50', name: n('Hidrômetro 2"', 'Water meter 2"', 'Contador de agua 2"'), kind: ValveKind.meter, sizeMm: 50, loss: kv(7.0, 50), maxFlow: 20 * m3sPerM3h, cost: 700),
      ValveSpec(id: 'meter80', name: n('Hidrômetro 3"', 'Water meter 3"', 'Contador de agua 3"'), kind: ValveKind.meter, sizeMm: 80, loss: kv(7.0, 80), maxFlow: 60 * m3sPerM3h, cost: 1100),
      ValveSpec(id: 'meter100', name: n('Hidrômetro 4"', 'Water meter 4"', 'Contador de agua 4"'), kind: ValveKind.meter, sizeMm: 100, loss: kv(7.0, 100), maxFlow: 120 * m3sPerM3h, cost: 1600),
      ValveSpec(
        id: 'backflow50',
        name: n('Válvula anti-refluxo 2"', 'Backflow preventer 2"', 'Válvula antirretorno 2"'),
        kind: ValveKind.backflow,
        sizeMm: 50,
        loss: kv(8.0, 50),
        maxFlow: 25 * m3sPerM3h,
        cost: 900,
      ),
      ValveSpec(
        id: 'backflow80',
        name: n('Válvula anti-refluxo 3"', 'Backflow preventer 3"', 'Válvula antirretorno 3"'),
        kind: ValveKind.backflow,
        sizeMm: 80,
        loss: kv(8.0, 80),
        maxFlow: 60 * m3sPerM3h,
        cost: 1500,
      ),
      ValveSpec(id: 'air25', name: n('Ventosa 1"', 'Air release valve 1"', 'Ventosa 1"'), kind: ValveKind.airRelease, sizeMm: 25, loss: const DeviceLossCurve(k: 0), cost: 90),
      ValveSpec(id: 'air50', name: n('Ventosa 2"', 'Air release valve 2"', 'Ventosa 2"'), kind: ValveKind.airRelease, sizeMm: 50, loss: const DeviceLossCurve(k: 0), cost: 180),
      ValveSpec(id: 'air80', name: n('Ventosa 3"', 'Air release valve 3"', 'Ventosa 3"'), kind: ValveKind.airRelease, sizeMm: 80, loss: const DeviceLossCurve(k: 0), cost: 320),
    ];

    // Generic pumps: an illustrative range of centrifugal (1 to 100 cv) and
    // submersible (3 to 30 cv) units; the shaft power at every point of the
    // curve stays within the rated motor (powerKw, checked by
    // catalogPlausibility). Manufacturer curves replace them.
    final pumps = <PumpSpec>[
      PumpSpec(
        id: 'pump_c1',
        name: n('Bomba centrífuga 1 cv (4 m³/h @ 20 m)', 'Centrifugal pump 1 hp (4 m³/h @ 20 m)', 'Bomba centrífuga 1 CV (4 m³/h @ 20 m)'),
        points: [(0, 27), (2 * m3sPerM3h, 25), (4 * m3sPerM3h, 20), (6 * m3sPerM3h, 12)],
        efficiency: 0.45,
        maxFlow: 6 * m3sPerM3h,
        cost: 900,
        powerKw: 0.75,
      ),
      PumpSpec(
        id: 'pump_c2',
        name: n('Bomba centrífuga 2 cv (7 m³/h @ 28 m)', 'Centrifugal pump 2 hp (7 m³/h @ 28 m)', 'Bomba centrífuga 2 CV (7 m³/h @ 28 m)'),
        points: [(0, 37), (3.5 * m3sPerM3h, 34), (7 * m3sPerM3h, 28), (10 * m3sPerM3h, 18)],
        efficiency: 0.5,
        maxFlow: 10 * m3sPerM3h,
        cost: 1500,
        powerKw: 1.5,
      ),
      PumpSpec(
        id: 'pump_small',
        name: n('Bomba centrífuga 3 cv (10 m³/h @ 35 m)', 'Centrifugal pump 3 hp (10 m³/h @ 35 m)', 'Bomba centrífuga 3 CV (10 m³/h @ 35 m)'),
        points: [(0, 45), (5 * m3sPerM3h, 41), (10 * m3sPerM3h, 35), (15 * m3sPerM3h, 25)],
        efficiency: 0.55,
        maxFlow: 15 * m3sPerM3h,
        cost: 2200,
        powerKw: 2.2,
      ),
      PumpSpec(
        id: 'pump_c5',
        name: n('Bomba centrífuga 5 cv (18 m³/h @ 38 m)', 'Centrifugal pump 5 hp (18 m³/h @ 38 m)', 'Bomba centrífuga 5 CV (18 m³/h @ 38 m)'),
        points: [(0, 50), (9 * m3sPerM3h, 46), (18 * m3sPerM3h, 38), (27 * m3sPerM3h, 26)],
        efficiency: 0.6,
        maxFlow: 27 * m3sPerM3h,
        cost: 3200,
        powerKw: 3.7,
      ),
      PumpSpec(
        id: 'pump_c7_5',
        name: n('Bomba centrífuga 7,5 cv (28 m³/h @ 40 m)', 'Centrifugal pump 7.5 hp (28 m³/h @ 40 m)', 'Bomba centrífuga 7,5 CV (28 m³/h @ 40 m)'),
        points: [(0, 53), (14 * m3sPerM3h, 49), (28 * m3sPerM3h, 40), (42 * m3sPerM3h, 27)],
        efficiency: 0.62,
        maxFlow: 42 * m3sPerM3h,
        cost: 4500,
        powerKw: 5.5,
      ),
      PumpSpec(
        id: 'pump_mid',
        name: n('Bomba centrífuga 10 cv (40 m³/h @ 45 m)', 'Centrifugal pump 10 hp (40 m³/h @ 45 m)', 'Bomba centrífuga 10 CV (40 m³/h @ 45 m)'),
        points: [(0, 58), (20 * m3sPerM3h, 53), (40 * m3sPerM3h, 45), (60 * m3sPerM3h, 30)],
        efficiency: 0.65,
        maxFlow: 60 * m3sPerM3h,
        cost: 6500,
        powerKw: 7.5,
      ),
      PumpSpec(
        id: 'pump_c15',
        name: n('Bomba centrífuga 15 cv (55 m³/h @ 45 m)', 'Centrifugal pump 15 hp (55 m³/h @ 45 m)', 'Bomba centrífuga 15 CV (55 m³/h @ 45 m)'),
        points: [(0, 60), (28 * m3sPerM3h, 55), (55 * m3sPerM3h, 45), (80 * m3sPerM3h, 31)],
        efficiency: 0.68,
        maxFlow: 80 * m3sPerM3h,
        cost: 9000,
        powerKw: 11,
      ),
      PumpSpec(
        id: 'pump_c20',
        name: n('Bomba centrífuga 20 cv (70 m³/h @ 48 m)', 'Centrifugal pump 20 hp (70 m³/h @ 48 m)', 'Bomba centrífuga 20 CV (70 m³/h @ 48 m)'),
        points: [(0, 63), (35 * m3sPerM3h, 58), (70 * m3sPerM3h, 48), (100 * m3sPerM3h, 33)],
        efficiency: 0.7,
        maxFlow: 100 * m3sPerM3h,
        cost: 12000,
        powerKw: 15,
      ),
      PumpSpec(
        id: 'pump_big',
        name: n('Bomba centrífuga 40 cv (120 m³/h @ 55 m)', 'Centrifugal pump 40 hp (120 m³/h @ 55 m)', 'Bomba centrífuga 40 CV (120 m³/h @ 55 m)'),
        points: [(0, 70), (60 * m3sPerM3h, 64), (120 * m3sPerM3h, 55), (180 * m3sPerM3h, 38)],
        efficiency: 0.72,
        maxFlow: 180 * m3sPerM3h,
        cost: 18000,
        powerKw: 30,
      ),
      PumpSpec(
        id: 'pump_c50',
        name: n('Bomba centrífuga 50 cv (160 m³/h @ 55 m)', 'Centrifugal pump 50 hp (160 m³/h @ 55 m)', 'Bomba centrífuga 50 CV (160 m³/h @ 55 m)'),
        points: [(0, 72), (80 * m3sPerM3h, 66), (160 * m3sPerM3h, 55), (230 * m3sPerM3h, 38)],
        efficiency: 0.74,
        maxFlow: 230 * m3sPerM3h,
        cost: 28000,
        powerKw: 37,
      ),
      PumpSpec(
        id: 'pump_c75',
        name: n('Bomba centrífuga 75 cv (230 m³/h @ 60 m)', 'Centrifugal pump 75 hp (230 m³/h @ 60 m)', 'Bomba centrífuga 75 CV (230 m³/h @ 60 m)'),
        points: [(0, 78), (115 * m3sPerM3h, 72), (230 * m3sPerM3h, 60), (330 * m3sPerM3h, 42)],
        efficiency: 0.76,
        maxFlow: 330 * m3sPerM3h,
        cost: 40000,
        powerKw: 55,
      ),
      PumpSpec(
        id: 'pump_c100',
        name: n('Bomba centrífuga 100 cv (300 m³/h @ 65 m)', 'Centrifugal pump 100 hp (300 m³/h @ 65 m)', 'Bomba centrífuga 100 CV (300 m³/h @ 65 m)'),
        points: [(0, 85), (150 * m3sPerM3h, 78), (300 * m3sPerM3h, 65), (420 * m3sPerM3h, 45)],
        efficiency: 0.78,
        maxFlow: 420 * m3sPerM3h,
        cost: 55000,
        powerKw: 75,
      ),
      PumpSpec(
        id: 'pump_s3',
        name: n('Bomba submersa 3 cv (8 m³/h @ 55 m)', 'Submersible pump 3 hp (8 m³/h @ 55 m)', 'Bomba sumergible 3 CV (8 m³/h @ 55 m)'),
        points: [(0, 78), (4 * m3sPerM3h, 68), (8 * m3sPerM3h, 55), (12 * m3sPerM3h, 36)],
        efficiency: 0.55,
        maxFlow: 12 * m3sPerM3h,
        cost: 2800,
        powerKw: 2.2,
        submersible: true,
      ),
      PumpSpec(
        id: 'pump_s5',
        name: n('Bomba submersa 5 cv (12 m³/h @ 65 m)', 'Submersible pump 5 hp (12 m³/h @ 65 m)', 'Bomba sumergible 5 CV (12 m³/h @ 65 m)'),
        points: [(0, 90), (6 * m3sPerM3h, 80), (12 * m3sPerM3h, 65), (18 * m3sPerM3h, 42)],
        efficiency: 0.58,
        maxFlow: 18 * m3sPerM3h,
        cost: 3900,
        powerKw: 3.7,
        submersible: true,
      ),
      PumpSpec(
        id: 'pump_sub',
        name: n('Bomba submersa 7,5 cv (25 m³/h @ 60 m)', 'Submersible pump 7.5 hp (25 m³/h @ 60 m)', 'Bomba sumergible 7,5 CV (25 m³/h @ 60 m)'),
        points: [(0, 80), (12 * m3sPerM3h, 72), (25 * m3sPerM3h, 60), (35 * m3sPerM3h, 40)],
        efficiency: 0.75,
        maxFlow: 35 * m3sPerM3h,
        cost: 5400,
        powerKw: 5.5,
        submersible: true,
      ),
      PumpSpec(
        id: 'pump_s15',
        name: n('Bomba submersa 15 cv (40 m³/h @ 65 m)', 'Submersible pump 15 hp (40 m³/h @ 65 m)', 'Bomba sumergible 15 CV (40 m³/h @ 65 m)'),
        points: [(0, 90), (20 * m3sPerM3h, 80), (40 * m3sPerM3h, 65), (60 * m3sPerM3h, 42)],
        efficiency: 0.65,
        maxFlow: 60 * m3sPerM3h,
        cost: 9500,
        powerKw: 11,
        submersible: true,
      ),
      PumpSpec(
        id: 'pump_s25',
        name: n('Bomba submersa 25 cv (55 m³/h @ 80 m)', 'Submersible pump 25 hp (55 m³/h @ 80 m)', 'Bomba sumergible 25 CV (55 m³/h @ 80 m)'),
        points: [(0, 110), (28 * m3sPerM3h, 98), (55 * m3sPerM3h, 80), (80 * m3sPerM3h, 52)],
        efficiency: 0.68,
        maxFlow: 80 * m3sPerM3h,
        cost: 15000,
        powerKw: 18.5,
        submersible: true,
      ),
      PumpSpec(
        id: 'pump_s30',
        name: n('Bomba submersa 30 cv (100 m³/h @ 60 m)', 'Submersible pump 30 hp (100 m³/h @ 60 m)', 'Bomba sumergible 30 CV (100 m³/h @ 60 m)'),
        points: [(0, 82), (50 * m3sPerM3h, 74), (100 * m3sPerM3h, 60), (140 * m3sPerM3h, 40)],
        efficiency: 0.75,
        maxFlow: 140 * m3sPerM3h,
        cost: 19000,
        powerKw: 22,
        submersible: true,
      ),
    ];

    return Catalog(
      pipes: pipes,
      outlets: outlets,
      tapes: tapes,
      valves: valves,
      pumps: pumps,
      fittings: defaultFittings(pipes, lang: lang),
      wires: defaultWires(lang: lang),
    );
  }

  /// Single copper conductors for direct burial: metric sections (enabled)
  /// and American gauges (disabled; enable them in the catalogue where AWG
  /// is the norm), with illustrative prices in [catalogPriceCurrency].
  static List<WireSpec> defaultWires({String lang = 'en', String? currency}) {
    String n(String pt, String en, String es) => switch (lang) {
      'pt' => pt,
      'es' => es,
      'en' => en,
      _ => packCatalogName(lang, en) ?? en,
    };
    final name = n('Fio de cobre', 'Copper wire', 'Cable de cobre');
    String mm(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    final out = <WireSpec>[
      for (final (mm2, cost) in const [(1.0, 1.3), (1.5, 1.7), (2.5, 2.6), (4.0, 4.0), (6.0, 5.9), (10.0, 9.6)])
        WireSpec(id: 'w${mm(mm2)}', name: '$name ${mm(mm2)} mm²', sectionMm2: mm2, ohmPerKm: copperOhmPerKm(mm2), costPerM: cost),
      for (final (awg, cost) in const [(18, 1.2), (16, 1.6), (14, 2.4), (12, 3.7), (10, 5.7), (8, 8.9)])
        WireSpec(
          id: 'awg$awg',
          name: '$name AWG $awg',
          sectionMm2: double.parse(awgMm2(awg).toStringAsFixed(2)),
          ohmPerKm: double.parse(copperOhmPerKm(awgMm2(awg)).toStringAsFixed(2)),
          costPerM: cost,
          enabled: false,
        ),
    ];
    final rate = currency == null ? null : exchangeRate(catalogPriceCurrency, currency);
    if (rate != null && rate != 1) {
      for (final w in out) {
        w.costPerM *= rate;
      }
    }
    return out;
  }

  /// Generic fittings for every nominal pipe size (couplers, elbows, tees,
  /// crosses, reducers, end caps, adapters) plus lateral take-offs, tape ends
  /// and risers, with illustrative prices scaled by size.
  static List<FittingSpec> defaultFittings(List<PipeSpec> pipes, {String lang = 'en', String? currency}) {
    final out = _defaultFittings(pipes, lang);
    final rate = currency == null ? null : exchangeRate(catalogPriceCurrency, currency);
    if (rate != null && rate != 1) {
      for (final f in out) {
        f.cost *= rate;
      }
    }
    return out;
  }

  static List<FittingSpec> _defaultFittings(List<PipeSpec> pipes, String lang) {
    String n(String pt, String en, String es) => switch (lang) {
      'pt' => pt,
      'es' => es,
      'en' => en,
      _ => packCatalogName(lang, en) ?? en,
    };
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
        if (s2 >= 20 || s <= 75) {
          out.add(FittingSpec(id: 'teer${sz}x$sz2', name: '${n('Tê de redução', 'Reducing tee', 'Te de reducción')} $sz × $sz2 mm', kind: FittingKind.tee, sizeMm: s, size2Mm: s2, cost: price(9, s)));
        }
      }
    }
    // take-offs and line ends for every size a lateral can have (lateral pipes
    // plus the small sizes of the other pipes used as sprinkler lines)
    final lateralSizes = {16.0, 20.0, ...pipes.where((p) => p.usage.contains(PipeUsage.lateral) || p.nominalMm <= 50).map((p) => p.nominalMm)}.toList()..sort();
    for (final s in lateralSizes) {
      final sz = mm(s);
      out.add(FittingSpec(id: 'to$sz', name: '${n('Conector inicial de lateral', 'Lateral take-off', 'Conector inicial de lateral')} $sz mm', kind: FittingKind.takeOff, sizeMm: s, cost: 1.2));
      out.add(FittingSpec(id: 'te$sz', name: '${n('Final de linha', 'Line end', 'Final de línea')} $sz mm', kind: FittingKind.tapeEnd, sizeMm: s, cost: 0.9));
    }
    out.add(
      FittingSpec(id: 'riser_micro', name: n('Haste/tubinho de microaspersor', 'Micro-sprinkler stake/tube', 'Estaca/microtubo de microaspersor'), kind: FittingKind.riser, sizeMm: 0, cost: 1.1),
    );
    out.add(FittingSpec(id: 'riser20', name: '${n('Tubo de subida', 'Riser', 'Tubo de subida')} 20 mm', kind: FittingKind.riser, sizeMm: 20, cost: 6));
    out.add(FittingSpec(id: 'riser25', name: '${n('Tubo de subida', 'Riser', 'Tubo de subida')} 25 mm', kind: FittingKind.riser, sizeMm: 25, cost: 8));
    out.add(FittingSpec(id: 'riser40', name: '${n('Tubo de subida', 'Riser', 'Tubo de subida')} 40 mm', kind: FittingKind.riser, sizeMm: 40, cost: 18));
    return out;
  }
}

/// The first item of a catalog list with an id, found through the position
/// of every id, which each lookup checks against the list since the lists
/// are edited in place: a scan per lookup, casting every item, was a good
/// part of each network the designer builds.
class _IdLookup<T> {
  _IdLookup(this._idOf);

  final String Function(T item) _idOf;
  Map<String, int>? _at;

  T? find(List<T> list, String? id) {
    if (id == null) return null;
    final at = _at ??= _index(list);
    final i = at[id];
    if (i != null && i < list.length) {
      final item = list[i];
      if (_idOf(item) == id) return item;
    }
    // added or moved since the index was made: as before, and index again
    for (var k = 0; k < list.length; k++) {
      if (_idOf(list[k]) == id) {
        _at = null;
        return list[k];
      }
    }
    return null;
  }

  Map<String, int> _index(List<T> list) {
    final at = <String, int>{};
    for (var k = 0; k < list.length; k++) {
      at.putIfAbsent(_idOf(list[k]), () => k);
    }
    return at;
  }
}
