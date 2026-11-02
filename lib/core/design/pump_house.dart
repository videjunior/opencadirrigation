/// Electrical design of the pump house: for every electric pump the motor,
/// its current, the starting method and the feeder cable from the supply,
/// and for the supply the transformer (or generator), the short-circuit
/// level, the installed load and the probable tariff group; and the supply
/// of every centre pivot or linear move with an electrical design (span
/// cable ampacity, collector ring, end tower, transformer).
///
/// * Motor: rated output from the pump data (or the next standard motor of
///   the largest shaft power of its duties, `pump_selection.dart`),
///   efficiency of IEC 60034-30-1 class IE3 (4 poles; at 60 Hz the values
///   equal NEMA Premium), a typical full-load power factor, rated current
///   I = P/(√3·U·η·cos φ).
/// * Starting current: direct on line k·I (locked rotor, k ≈ 7 for IE3
///   motors), star-delta k·I/3 (the star connection draws a third of the
///   line current, IEC 60947-4-1), soft-starter at its current limit
///   (≈ 3·I for pumps) and the frequency drive at the rated current. The
///   design starts direct up to the utility's limit, and above it with a
///   drive when the pump is speed controlled, a soft-starter when it is
///   submersible (three-lead motors cannot run star-delta) or above 75 kW,
///   star-delta otherwise; a start that still drops too much moves to the
///   next method.
/// * Feeder (NBR 5410:2004 = IEC 60364-5-52): design current = rated
///   current × service factor (6.5.1.3.1); ampacity of Tabelas 36/37
///   (methods B1, C, D) and 38/39 (method E), copper, three loaded
///   conductors, times the temperature factor of Tabela 40 and the grouping
///   factor; voltage drop ΔU = √3·I·L·(R·cos φ + X·sin φ) with R at the
///   conductor's service temperature (R20·(1 + 0.00393·(θ − 20)), θ = 70 °C
///   PVC, 90 °C XLPE) and X = 0.08 Ω/km (IEC 60364-5-52 Annex G), within
///   6.2.7.1 running (7 % from a transformer or generator of its own, 5 %
///   from the low-voltage network, + 0.005 %/m beyond 100 m up to 0.5 %)
///   and 10 % at the starter while the motor starts (6.5.1.3.3, the source
///   impedance included); thermal withstand S ≥ I·√t/k with k = 115 (PVC)
///   or 143 (XLPE) (5.3.5.5.2, IEC 60364-4-43); protective conductor of
///   Tabela 58. Conductor resistance of IEC 60228 class 2.
/// * Transformer: the smallest standard rating (15–300 kVA of the
///   distribution transformers of NBR 5440, then 500–2500 kVA) that carries
///   the largest simultaneous load (the pumps of a system flow, the pivots
///   fed from it and the other loads) within the loading allowed and lets
///   every motor start within the limit; short-circuit voltage typical for
///   the size unless given, load losses of Portaria Interministerial
///   MME/MCTI/MDIC 1/2013 (15 kV class).
/// * Short circuit (IEC 60909-0): Ik3 = c·U/(√3·|Z|), c = 1.05, the
///   transformer impedance Z = uk·U²/S (and the network upstream when its
///   short-circuit power is given) plus the feeder at 20 °C.
/// * Generator: the larger of the running kVA over its loading and the size
///   that keeps the dip of the largest start within the limit
///   (`pivot_electrical.dart`, IEEE Std 399 and 446).
/// * Tariff group: secondary voltage (group B) up to 75 kW installed,
///   primary (group A) above (REN ANEEL 1.000/2021, art. 23).
library;

import 'dart:math' as math;

import '../hydraulics/pump.dart';
import '../model/agb_settings.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'pivot_electrical.dart';
import 'pump_selection.dart' show standardMotor;
import 'results.dart';

/// Copper sections of the feeder tables (mm²).
const powerCableSections = <double>[1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300];

/// IEC 60228 class 2 copper: maximum resistance at 20 °C (Ω/km) of [powerCableSections].
const _r20 = <double>[12.1, 7.41, 4.61, 3.08, 1.83, 1.15, 0.727, 0.524, 0.387, 0.268, 0.193, 0.153, 0.124, 0.0991, 0.0754, 0.0601];

/// NBR 5410:2004 ampacity (A), copper, three loaded conductors, 30 °C air
/// or 20 °C soil (method D): Tabela 36 (PVC) and 37 (EPR/XLPE) for methods
/// B1, C and D, Tabela 38 and 39 for method E (multicore cables).
const _ampacity = <CableInsulation, Map<CableMethod, List<double>>>{
  CableInsulation.pvc: {
    CableMethod.b1: [15.5, 21, 28, 36, 50, 68, 89, 110, 134, 171, 207, 239, 275, 314, 370, 426],
    CableMethod.c: [17.5, 24, 32, 41, 57, 76, 96, 119, 144, 184, 223, 259, 299, 341, 403, 464],
    CableMethod.d: [18, 24, 31, 39, 52, 67, 86, 103, 122, 151, 179, 203, 230, 258, 297, 336],
    CableMethod.e: [18.5, 25, 34, 43, 60, 80, 101, 126, 153, 196, 238, 276, 319, 364, 430, 497],
  },
  CableInsulation.xlpe: {
    CableMethod.b1: [20, 28, 37, 48, 66, 88, 117, 144, 175, 222, 269, 312, 358, 408, 481, 553],
    CableMethod.c: [22, 30, 40, 52, 71, 96, 119, 147, 179, 229, 278, 322, 371, 424, 500, 576],
    CableMethod.d: [22, 29, 37, 46, 61, 79, 101, 122, 144, 178, 211, 240, 271, 304, 351, 396],
    CableMethod.e: [23, 32, 42, 54, 75, 100, 127, 158, 192, 246, 298, 346, 399, 456, 538, 621],
  },
};

/// NBR 5410 Tabela 40: correction factors by temperature (°C) for lines in
/// air (reference 30 °C) and in the ground (reference 20 °C).
const _tempAir = <CableInsulation, List<(double, double)>>{
  CableInsulation.pvc: [(10, 1.22), (15, 1.17), (20, 1.12), (25, 1.06), (30, 1), (35, 0.94), (40, 0.87), (45, 0.79), (50, 0.71), (55, 0.61), (60, 0.50)],
  CableInsulation.xlpe: [
    (10, 1.15),
    (15, 1.12),
    (20, 1.08),
    (25, 1.04),
    (30, 1),
    (35, 0.96),
    (40, 0.91),
    (45, 0.87),
    (50, 0.82),
    (55, 0.76),
    (60, 0.71),
    (65, 0.65),
    (70, 0.58),
    (75, 0.50),
    (80, 0.41),
  ],
};
const _tempSoil = <CableInsulation, List<(double, double)>>{
  CableInsulation.pvc: [(10, 1.10), (15, 1.05), (20, 1), (25, 0.95), (30, 0.89), (35, 0.84), (40, 0.77), (45, 0.71), (50, 0.63), (55, 0.55), (60, 0.45)],
  CableInsulation.xlpe: [
    (10, 1.07),
    (15, 1.04),
    (20, 1),
    (25, 0.96),
    (30, 0.93),
    (35, 0.89),
    (40, 0.85),
    (45, 0.80),
    (50, 0.76),
    (55, 0.71),
    (60, 0.65),
    (65, 0.60),
    (70, 0.53),
    (75, 0.46),
    (80, 0.38),
  ],
};

double _interp(List<(double, double)> t, double x) {
  if (x <= t.first.$1) return t.first.$2;
  for (var i = 1; i < t.length; i++) {
    if (x <= t[i].$1) {
      final (x0, y0) = t[i - 1];
      final (x1, y1) = t[i];
      return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
    }
  }
  return t.last.$2;
}

/// Ampacity (A) of [mm2] at the reference temperature, or 0 when the
/// section is not in the tables.
double cableAmpacity(double mm2, CableInsulation insulation, CableMethod method) {
  final i = powerCableSections.indexWhere((s) => (s - mm2).abs() < 1e-9);
  return i < 0 ? 0 : _ampacity[insulation]![method]![i];
}

/// Temperature factor of NBR 5410 Tabela 40 ([ambientC] null = the
/// reference: 1); method D lies in the ground.
double cableTemperatureFactor(CableInsulation insulation, CableMethod method, double? ambientC) {
  if (ambientC == null) return 1;
  return math.max(0.0, _interp((method == CableMethod.d ? _tempSoil : _tempAir)[insulation]!, ambientC));
}

/// Resistance of one copper conductor at 20 °C (Ω/km): IEC 60228 class 2
/// for the sections of the tables, else from the resistivity with the
/// stranding allowance.
double cableResistance20(double mm2) {
  final i = powerCableSections.indexWhere((s) => (s - mm2).abs() < 1e-9);
  return i >= 0 ? _r20[i] : (mm2 > 0 ? 18.1 / mm2 : double.infinity);
}

/// Service temperature of the insulation (°C).
double cableServiceTemperature(CableInsulation insulation) => insulation == CableInsulation.pvc ? 70 : 90;

/// Resistance at the service temperature (Ω/km), α = 0.00393/°C for copper.
double cableResistanceHot(double mm2, CableInsulation insulation) => cableResistance20(mm2) * (1 + 0.00393 * (cableServiceTemperature(insulation) - 20));

/// Reactance of a low-voltage cable when unknown (Ω/km, IEC 60364-5-52 Annex G).
const cableReactanceOhmPerKm = 0.08;

/// Factor k of the thermal withstand S ≥ I·√t/k (copper; NBR 5410 Tabela 30, IEC 60364-4-43 Table 43A).
double shortCircuitK(CableInsulation insulation) => insulation == CableInsulation.pvc ? 115 : 143;

/// Section of the protective conductor (NBR 5410 Tabela 58): the phase up
/// to 16 mm², 16 mm² up to 35 mm², half above (the next section of the list).
double protectiveConductorMm2(double phaseMm2) {
  if (phaseMm2 <= 16) return phaseMm2;
  if (phaseMm2 <= 35) return 16;
  final half = phaseMm2 / 2;
  return powerCableSections.firstWhere((s) => s >= half - 1e-9, orElse: () => half);
}

/// IEC 60034-30-1 IE3 efficiency of 4-pole motors, 60 Hz (NEMA Premium).
const _ie3At60 = <(double, double)>[
  (0.75, 0.855),
  (1.1, 0.865),
  (1.5, 0.865),
  (2.2, 0.895),
  (3.7, 0.895),
  (5.5, 0.917),
  (7.5, 0.917),
  (11, 0.924),
  (15, 0.930),
  (18.5, 0.936),
  (22, 0.936),
  (30, 0.941),
  (37, 0.945),
  (45, 0.950),
  (55, 0.954),
  (75, 0.954),
  (90, 0.954),
  (110, 0.958),
  (150, 0.962),
  (185, 0.962),
  (220, 0.962),
  (375, 0.962),
];

/// IEC 60034-30-1 IE3 efficiency of 4-pole motors, 50 Hz.
const _ie3At50 = <(double, double)>[
  (0.75, 0.825),
  (1.1, 0.841),
  (1.5, 0.853),
  (2.2, 0.867),
  (3, 0.877),
  (4, 0.886),
  (5.5, 0.896),
  (7.5, 0.904),
  (11, 0.914),
  (15, 0.921),
  (18.5, 0.926),
  (22, 0.930),
  (30, 0.936),
  (37, 0.939),
  (45, 0.942),
  (55, 0.946),
  (75, 0.950),
  (90, 0.952),
  (110, 0.954),
  (132, 0.956),
  (160, 0.958),
  (200, 0.960),
  (1000, 0.960),
];

/// IE3 efficiency of a 4-pole motor of [kw] on [hz] mains, interpolated on
/// the logarithm of the rating.
double ie3Efficiency(double kw, {double hz = 60}) {
  final t = hz < 55 ? _ie3At50 : _ie3At60;
  if (kw <= t.first.$1) return t.first.$2;
  final lk = math.log(kw);
  for (var i = 1; i < t.length; i++) {
    if (kw <= t[i].$1) {
      final a = math.log(t[i - 1].$1), b = math.log(t[i].$1);
      return t[i - 1].$2 + (t[i].$2 - t[i - 1].$2) * (lk - a) / (b - a);
    }
  }
  return t.last.$2;
}

/// Typical full-load power factor of 4-pole squirrel-cage motors (a value
/// of order: the motor's data sheet replaces it).
double typicalMotorPowerFactor(double kw) => _interp(const [(0.75, 0.72), (1.5, 0.78), (3.7, 0.82), (7.5, 0.84), (15, 0.85), (30, 0.86), (75, 0.87), (160, 0.88)], kw);

/// Starting method the design picks (see the library comment).
StarterKind recommendedStarter({required double kw, required double directMaxKw, bool speedControlled = false, bool submersible = false}) {
  if (speedControlled) return StarterKind.vfd;
  if (kw <= directMaxKw + 1e-9) return StarterKind.direct;
  if (submersible || kw > 75) return StarterKind.softStarter;
  return StarterKind.starDelta;
}

/// The next method when a start drops too much (null after the drive).
StarterKind? gentlerStarter(StarterKind k, {bool submersible = false}) => switch (k) {
  StarterKind.direct => submersible ? StarterKind.softStarter : StarterKind.starDelta,
  StarterKind.starDelta => StarterKind.softStarter,
  StarterKind.softStarter => StarterKind.vfd,
  _ => null,
};

/// Line current while starting, in multiples of the rated current.
double startingMultipleOf(StarterKind k, {double lockedRotor = 7, double softStarter = 3}) => switch (k) {
  StarterKind.direct || StarterKind.auto => lockedRotor,
  StarterKind.starDelta => lockedRotor / 3,
  StarterKind.softStarter => softStarter,
  StarterKind.vfd => 1,
};

/// Power factor while starting.
double startingPowerFactorOf(StarterKind k) => switch (k) {
  StarterKind.vfd => 0.95,
  StarterKind.softStarter => 0.4,
  _ => 0.35,
};

/// Standard ratings (kVA) of three-phase transformers: the distribution
/// series (15–300 kVA) and the next usual sizes.
const standardTransformerKva = <double>[15, 30, 45, 75, 112.5, 150, 225, 300, 500, 750, 1000, 1500, 2000, 2500];

/// Typical short-circuit voltage (%) of a transformer of [kva].
double typicalTransformerUkPct(double kva) => kva <= 150 ? 3.5 : (kva <= 300 ? 4.5 : (kva <= 1000 ? 5 : 6));

/// Load losses (% of the rating) of a distribution transformer: the
/// maximum total minus the no-load losses of Portaria MME/MCTI/MDIC 1/2013
/// (15 kV class), 1 % above 300 kVA.
double transformerLoadLossPct(double kva) {
  const t = <(double, double, double)>[(15, 410, 85), (30, 695, 150), (45, 945, 195), (75, 1395, 295), (112.5, 1890, 390), (150, 2335, 485), (225, 3260, 650), (300, 4060, 810)];
  for (final (s, total, noLoad) in t) {
    if (kva <= s + 1e-9) return 100 * (total - noLoad) / (s * 1000);
  }
  return 1;
}

/// One electric motor of the pump house.
class PumpCircuit {
  PumpCircuit({
    required this.pumpId,
    required this.name,
    required this.motorKw,
    required this.efficiency,
    required this.powerFactor,
    required this.currentA,
    required this.designCurrentA,
    required this.starter,
    required this.startMultiple,
    required this.startCurrentA,
    required this.lengthM,
    required this.sectionMm2,
    required this.peMm2,
    required this.ampacityA,
    required this.runningDropPct,
    required this.startingDropPct,
    required this.runningLimitPct,
    required this.ik3EndKa,
    required this.thermalMinMm2,
    this.warnings = const [],
  });
  final String pumpId;
  final String name;

  /// Rated output (kW), efficiency, power factor, rated and design current (A).
  final double motorKw;
  final double efficiency;
  final double powerFactor;
  final double currentA;
  final double designCurrentA;

  /// Starting method and its line current (× rated, A).
  final StarterKind starter;
  final double startMultiple;
  final double startCurrentA;

  /// Feeder: length (m), phase and protective conductor sections (mm²), the
  /// corrected ampacity (A), the running drop and its limit and the drop at
  /// the starter while starting (%), the short-circuit current at the
  /// starter (kA) and the least section of the thermal withstand (mm²).
  final double lengthM;
  final double sectionMm2;
  final double peMm2;
  final double ampacityA;
  final double runningDropPct;
  final double startingDropPct;
  final double runningLimitPct;
  final double ik3EndKa;
  final double thermalMinMm2;

  /// Codes `agb_feeder_*:<pump id>`.
  final List<String> warnings;

  /// Apparent power at the rated output (kVA) and electrical input (kW).
  double get kva => motorKw / (efficiency * powerFactor);
  double get inputKw => motorKw / efficiency;

  Map<String, dynamic> toJson() => {
    'id': pumpId,
    'name': name,
    'kw': motorKw,
    'eff': efficiency,
    'pf': powerFactor,
    'i': currentA,
    'ib': designCurrentA,
    'start': starter.name,
    'k': startMultiple,
    'is': startCurrentA,
    'len': lengthM,
    'mm2': sectionMm2,
    'pe': peMm2,
    'iz': ampacityA,
    'du': runningDropPct,
    'dus': startingDropPct,
    'lim': runningLimitPct,
    'ik': ik3EndKa,
    'smin': thermalMinMm2,
    if (warnings.isNotEmpty) 'warn': warnings,
  };
  static PumpCircuit fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PumpCircuit(
      pumpId: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      motorKw: d('kw'),
      efficiency: d('eff'),
      powerFactor: d('pf'),
      currentA: d('i'),
      designCurrentA: d('ib'),
      starter: StarterKind.values.asNameMap()[j['start']] ?? StarterKind.direct,
      startMultiple: d('k'),
      startCurrentA: d('is'),
      lengthM: d('len'),
      sectionMm2: d('mm2'),
      peMm2: d('pe'),
      ampacityA: d('iz'),
      runningDropPct: d('du'),
      startingDropPct: d('dus'),
      runningLimitPct: d('lim'),
      ik3EndKa: d('ik'),
      thermalMinMm2: d('smin'),
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Supply of one centre pivot or linear move with an electrical design.
class PivotSupply {
  PivotSupply({
    required this.pivotId,
    required this.name,
    required this.spanCableMm2,
    required this.spanCurrentA,
    required this.spanAmpacityA,
    required this.spanMinMm2,
    required this.awg,
    required this.collectorRingA,
    required this.endTowerVolts,
    required this.endTowerDropPct,
    required this.boosterKw,
    required this.runningKva,
    required this.connectedKw,
    required this.transformerKva,
    this.warnings = const [],
  });
  final String pivotId;
  final String name;

  /// Span cable chosen by the voltage drop (mm²), current in the first span
  /// (A), its ampacity as a multicore cable in free air (method E, PVC, A),
  /// the least section that carries the current (mm²) and the American gauge
  /// of the same copper (0 = beyond the list).
  final double spanCableMm2;
  final double spanCurrentA;
  final double spanAmpacityA;
  final double spanMinMm2;
  final int awg;

  /// Current the collector ring at the pivot point carries to the spans (A).
  final double collectorRingA;

  /// Voltage and drop at the end tower, everything running (V, %), and the
  /// booster motor there (kW).
  final double endTowerVolts;
  final double endTowerDropPct;
  final double boosterKw;

  /// Running apparent power (kVA), connected load (kW) and the transformer
  /// that would feed the machine alone (kVA).
  final double runningKva;
  final double connectedKw;
  final double transformerKva;

  /// Codes `agb_pivot_*:<pivot id>`.
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'id': pivotId,
    'name': name,
    'mm2': spanCableMm2,
    'i': spanCurrentA,
    'iz': spanAmpacityA,
    'smin': spanMinMm2,
    'awg': awg,
    'ring': collectorRingA,
    'v': endTowerVolts,
    'du': endTowerDropPct,
    'boost': boosterKw,
    'kva': runningKva,
    'kw': connectedKw,
    'tr': transformerKva,
    if (warnings.isNotEmpty) 'warn': warnings,
  };
  static PivotSupply fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PivotSupply(
      pivotId: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      spanCableMm2: d('mm2'),
      spanCurrentA: d('i'),
      spanAmpacityA: d('iz'),
      spanMinMm2: d('smin'),
      awg: (j['awg'] as num?)?.toInt() ?? 0,
      collectorRingA: d('ring'),
      endTowerVolts: d('v'),
      endTowerDropPct: d('du'),
      boosterKw: d('boost'),
      runningKva: d('kva'),
      connectedKw: d('kw'),
      transformerKva: d('tr'),
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Electrical design of the pump house and of the pivots' supply.
class PumpHouseResult {
  PumpHouseResult({
    required this.voltage,
    required this.supply,
    required this.circuits,
    required this.pivots,
    required this.runningKva,
    required this.demandKw,
    required this.installedKw,
    required this.largestStartKva,
    required this.sourceKvaRequired,
    required this.sourceKva,
    required this.ukPct,
    required this.ik3SourceKa,
    required this.tariffGroup,
    this.worstFlow = '',
    this.warnings = const [],
  });
  final double voltage;
  final PowerSupplyKind supply;
  final List<PumpCircuit> circuits;
  final List<PivotSupply> pivots;

  /// Largest simultaneous load (kVA, kW of demand), installed load (kW) and
  /// the locked-rotor kVA of the largest start.
  final double runningKva;
  final double demandKw;
  final double installedKw;
  final double largestStartKva;

  /// Transformer or generator needed and the standard rating chosen (kVA; 0
  /// on the low-voltage network), the short-circuit voltage used (%) and the
  /// short-circuit current at the supply (kA; infinite without impedance).
  final double sourceKvaRequired;
  final double sourceKva;
  final double ukPct;
  final double ik3SourceKa;

  /// 'B' (secondary voltage) or 'A' (primary), REN ANEEL 1.000/2021 art. 23.
  final String tariffGroup;

  /// System flow of the largest load ('' = every pump together).
  final String worstFlow;

  /// Codes `agb_*` (with `:<id>`).
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'v': voltage,
    'supply': supply.name,
    'circuits': [for (final c in circuits) c.toJson()],
    if (pivots.isNotEmpty) 'pivots': [for (final p in pivots) p.toJson()],
    'kva': runningKva,
    'kw': demandKw,
    'inst': installedKw,
    'slr': largestStartKva,
    'sreq': sourceKvaRequired,
    's': sourceKva,
    'uk': ukPct,
    'ik': ik3SourceKa.isFinite ? ik3SourceKa : null,
    'group': tariffGroup,
    if (worstFlow.isNotEmpty) 'flow': worstFlow,
    if (warnings.isNotEmpty) 'warn': warnings,
  };
  static PumpHouseResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PumpHouseResult(
      voltage: d('v'),
      supply: PowerSupplyKind.values.asNameMap()[j['supply']] ?? PowerSupplyKind.ownTransformer,
      circuits: [for (final c in (j['circuits'] as List?) ?? const []) PumpCircuit.fromJson((c as Map).cast<String, dynamic>())],
      pivots: [for (final c in (j['pivots'] as List?) ?? const []) PivotSupply.fromJson((c as Map).cast<String, dynamic>())],
      runningKva: d('kva'),
      demandKw: d('kw'),
      installedKw: d('inst'),
      largestStartKva: d('slr'),
      sourceKvaRequired: d('sreq'),
      sourceKva: d('s'),
      ukPct: d('uk'),
      ik3SourceKa: (j['ik'] as num?)?.toDouble() ?? double.infinity,
      tariffGroup: j['group'] as String? ?? 'B',
      worstFlow: j['flow'] as String? ?? '',
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// A motor to feed, before its feeder is sized.
class _Motor {
  _Motor(this.id, this.name, this.kw, this.eff, this.pf, this.starter, this.auto, this.submersible, this.length, this.flows);
  final String id;
  final String name;
  final double kw;
  final double eff;
  final double pf;
  StarterKind starter;
  final bool auto;
  final bool submersible;
  final double length;

  /// System flows it runs in (null = every one).
  final Set<String>? flows;
  double get kva => kw / (eff * pf);
  double get kwIn => kw / eff;
  bool runsIn(String flow) => flows == null || flows!.contains(flow);
}

/// Rated output (kW) the motor of pump [e] needs: the typed one, the pump's
/// data, else the next standard motor of the largest shaft power of its
/// duties in [results] (or of its curve when there are none).
double pumpMotorKw(Project p, PumpEntity e, PumpFeeder f, DesignResults? results) {
  if (f.motorKw > 0) return f.motorKw;
  final spec = p.catalog.pump(e.pumpSpecId);
  if (spec != null && spec.powerKw > 0) return spec.powerKw;
  var shaft = 0.0;
  for (final flow in results?.systemFlows ?? const <SystemFlowResult>[]) {
    for (final d in flow.devices) {
      if (d.entityId != e.id || d.pumpHead <= 0 || d.flow <= 0) continue;
      final eta = spec?.efficiencyAt(d.flow, speed: d.speedRatio) ?? p.params.pumpEfficiency;
      shaft = math.max(shaft, shaftPower(flow: d.flow, head: d.pumpHead, efficiency: eta) / 1000);
    }
  }
  if (shaft <= 0 && spec != null) {
    for (final (q, h) in spec.points) {
      if (q > 0 && h > 0) shaft = math.max(shaft, shaftPower(flow: q, head: h, efficiency: spec.efficiencyAt(q)) / 1000);
    }
  }
  return shaft > 0 ? standardMotor(shaft)!.$1 : 0;
}

/// The system flows pump [id] runs in according to [results] (null = all,
/// when there are no results).
Set<String>? _flowsOfPump(String id, DesignResults? results) {
  if (results == null || results.systemFlows.isEmpty) return null;
  return {
    for (final f in results.systemFlows)
      if (f.devices.any((d) => d.entityId == id && d.pumpHead > 0)) f.flowId,
  };
}

/// Pivot ids a system flow runs (all of them when there are no flows).
Set<String>? _pivotsOfFlow(Project p, String flow) {
  final f = p.systemFlows.where((x) => x.id == flow).firstOrNull;
  return f?.valveIds;
}

/// The American gauge (14 … 2) with at least [mm2] of copper, 0 beyond.
int awgFor(double mm2) {
  for (final g in const [14, 12, 10, 8, 6, 4, 2, 1]) {
    if (awgMm2(g) >= mm2 - 0.05) return g;
  }
  return 0;
}

/// Pump house and pivot supplies of [p] with the design [results] (null:
/// every pump at its curve's largest power, all at once). Pumps whose
/// motor is unknown are reported (`agb_pump_no_power:<id>`).
PumpHouseResult designPumpHouse(Project p, DesignResults? results) {
  final s = p.agb.pumpHouse;
  final u = s.voltage > 0 ? s.voltage : 380.0;
  final hz = p.params.mainsHz;
  final warnings = <String>[];
  void warn(String c) {
    if (!warnings.contains(c)) warnings.add(c);
  }

  // ---- motors
  final motors = <_Motor>[];
  for (final e in p.entities.whereType<PumpEntity>()) {
    final f = s.feederOf(e.id);
    if (!f.electric) continue;
    final kw = pumpMotorKw(p, e, f, results);
    if (kw <= 0) {
      warn('agb_pump_no_power:${e.id}');
      continue;
    }
    final spec = p.catalog.pump(e.pumpSpecId);
    final eff = f.efficiency > 0 ? f.efficiency.clamp(0.3, 1.0).toDouble() : (e.motorEfficiency < 1 ? e.motorEfficiency : ie3Efficiency(kw, hz: hz));
    final pf = f.powerFactor > 0 ? f.powerFactor.clamp(0.3, 1.0).toDouble() : typicalMotorPowerFactor(kw);
    final sub = spec?.submersible ?? false;
    final auto = f.starter == StarterKind.auto;
    final starter = auto ? recommendedStarter(kw: kw, directMaxKw: s.directMaxKw, speedControlled: e.targetPressureM > 0, submersible: sub) : f.starter;
    final name = e.name.isNotEmpty ? e.name : (spec?.name ?? e.id);
    motors.add(_Motor(e.id, name, kw, eff, pf, starter, auto, sub, math.max(1.0, f.lengthM ?? s.defaultFeederM), _flowsOfPump(e.id, results)));
  }

  // ---- pivots with an electrical design (their own supply data)
  final pivotSupplies = <PivotSupply>[];
  final pivotKva = <String, double>{};
  for (final e in p.entities.whereType<PivotEntity>()) {
    final mech = results?.mechanised[e.id];
    final el = mech?.electrical;
    if (el == null) continue;
    final ps = pivotSupplyOf(e, el);
    pivotSupplies.add(ps);
    if (s.includePivots) pivotKva[e.id] = el.runningKva;
  }

  // ---- the largest simultaneous load
  final flows = [for (final f in results?.systemFlows ?? const <SystemFlowResult>[]) f.flowId];
  var worstKva = 0.0, worstKw = 0.0;
  var worstFlow = '';
  (double, double) loadOf(String? flow) {
    var kva = s.otherLoadsKva, kw = s.otherLoadsKva * 0.9;
    for (final m in motors) {
      if (flow == null || m.runsIn(flow)) {
        kva += m.kva;
        kw += m.kwIn;
      }
    }
    final listed = flow == null ? null : _pivotsOfFlow(p, flow);
    for (final e in pivotKva.entries) {
      if (listed == null || listed.contains(e.key)) {
        kva += e.value;
        kw += e.value * 0.8;
      }
    }
    return (kva, kw);
  }

  if (flows.isEmpty) {
    (worstKva, worstKw) = loadOf(null);
  } else {
    for (final f in flows) {
      final (kva, kw) = loadOf(f);
      if (kva > worstKva) {
        worstKva = kva;
        worstKw = kw;
        worstFlow = f;
      }
    }
  }
  final installed = motors.fold(0.0, (a, m) => a + m.kw) + (s.includePivots ? pivotSupplies.fold(0.0, (a, x) => a + x.connectedKw) : 0.0) + s.otherLoadsKva * 0.9;
  final largestStart = motors.fold(0.0, (a, m) => math.max(a, m.kva * startingMultipleOf(m.starter, lockedRotor: s.lockedRotorMultiple, softStarter: s.softStartMultiple)));

  // ---- source impedance (Ω at u) of a transformer of [kva]
  double ukOf(double kva) => s.transformerUkPct > 0 ? s.transformerUkPct : typicalTransformerUkPct(kva);
  (double, double) transformerZ(double kva) {
    if (kva <= 0) return (0, 0);
    final zBase = u * u / (kva * 1000);
    final z = ukOf(kva) / 100 * zBase;
    final r = math.min(z, transformerLoadLossPct(kva) / 100 * zBase);
    return (r, math.sqrt(math.max(0.0, z * z - r * r)));
  }

  (double, double) upstreamZ() {
    if (s.upstreamMva <= 0) return (0, 0);
    final z = 1.1 * u * u / (s.upstreamMva * 1e6);
    return (0.1 * z, 0.995 * z);
  }

  // ---- feeders for a source of (r, x)
  final dropBase = s.maxRunningDropPct > 0 ? s.maxRunningDropPct : (s.supply == PowerSupplyKind.lowVoltage ? 5.0 : 7.0);
  final fT = cableTemperatureFactor(s.insulation, s.method, s.ambientC);
  final fG = s.groupingFactor.clamp(0.3, 1.0).toDouble();
  final x = cableReactanceOhmPerKm;
  // the least section for the current, the running drop and the short
  // circuit, then up to [maxUpsize] sections more for the start; [escalate]
  // lets an automatic starter move to a gentler one
  (List<PumpCircuit>, bool) feeders(double rs, double xs, {bool generator = false, int maxUpsize = 2, bool escalate = false}) {
    final out = <PumpCircuit>[];
    var allOk = true;
    final zs = math.sqrt(rs * rs + xs * xs);
    final ikSource = zs > 0 ? 1.05 * u / (math.sqrt(3) * zs) : double.infinity;
    for (final m in motors) {
      final i = motorCurrent(kw: m.kw, voltage: u, efficiency: m.eff, powerFactor: m.pf);
      final ib = i * math.max(1.0, s.serviceFactor);
      final limit = dropBase + (m.length > 100 && s.supply != PowerSupplyKind.lowVoltage ? math.min(0.5, 0.005 * (m.length - 100)) : 0.0);
      // the others of its heaviest flow running while it starts
      var op = 0.0, oq = 0.0;
      final flow = m.flows == null ? null : (m.flows!.isEmpty ? null : m.flows!.reduce((a, b) => loadOf(a).$1 >= loadOf(b).$1 ? a : b));
      for (final o in motors) {
        if (identical(o, m) || (flow != null && !o.runsIn(flow))) continue;
        final io = motorCurrent(kw: o.kw, voltage: u, efficiency: o.eff, powerFactor: o.pf);
        op += io * o.pf;
        oq += io * math.sqrt(1 - o.pf * o.pf);
      }
      PumpCircuit? best;
      var starter = m.starter;
      while (true) {
        final k = startingMultipleOf(starter, lockedRotor: s.lockedRotorMultiple, softStarter: s.softStartMultiple);
        final pfs = startingPowerFactorOf(starter);
        final ist = i * k;
        final sp = ist * pfs, sq = ist * math.sqrt(1 - pfs * pfs);
        // the generator's own dip is checked on its rating, not at the starter
        final srcDrop = generator ? 0.0 : math.sqrt(3) * (rs * (sp + op) + xs * (sq + oq)) / u * 100;
        final thermal = ikSource.isFinite ? ikSource * math.sqrt(math.max(s.clearingTimeS, 0.0)) / shortCircuitK(s.insulation) : 0.0;
        PumpCircuit circuitFor(double mm2) {
          final rh = cableResistanceHot(mm2, s.insulation);
          final run = 100 * math.sqrt(3) * m.length / 1000 * i * (rh * m.pf + x * math.sqrt(1 - m.pf * m.pf)) / u;
          final start = srcDrop + 100 * math.sqrt(3) * m.length / 1000 * (rh * sp + x * sq) / u;
          final rc = cableResistance20(mm2) * m.length / 1000, xc = x * m.length / 1000;
          final zEnd = math.sqrt(math.pow(rs + rc, 2) + math.pow(xs + xc, 2));
          final iz = cableAmpacity(mm2, s.insulation, s.method) * fT * fG;
          final w = <String>[
            if (iz < ib - 1e-9) 'agb_feeder_ampacity:${m.id}',
            if (run > limit + 1e-9) 'agb_feeder_drop:${m.id}',
            if (start > s.maxStartingDropPct + 1e-9) 'agb_feeder_start_drop:${m.id}',
            if (mm2 < thermal - 1e-9) 'agb_feeder_thermal:${m.id}',
          ];
          return PumpCircuit(
            pumpId: m.id,
            name: m.name,
            motorKw: m.kw,
            efficiency: m.eff,
            powerFactor: m.pf,
            currentA: i,
            designCurrentA: ib,
            starter: starter,
            startMultiple: k,
            startCurrentA: ist,
            lengthM: m.length,
            sectionMm2: mm2,
            peMm2: protectiveConductorMm2(mm2),
            ampacityA: iz,
            runningDropPct: run,
            startingDropPct: start,
            runningLimitPct: limit,
            ik3EndKa: zEnd > 0 ? 1.05 * u / (math.sqrt(3) * zEnd) / 1000 : double.infinity,
            thermalMinMm2: thermal,
            warnings: w,
          );
        }

        final base = powerCableSections.indexWhere((mm2) => circuitFor(mm2).warnings.every((w) => w.startsWith('agb_feeder_start_drop')));
        final last = powerCableSections.length - 1;
        PumpCircuit? ok;
        if (base >= 0) {
          for (var k2 = base; k2 <= math.min(last, base + maxUpsize); k2++) {
            final c = circuitFor(powerCableSections[k2]);
            if (c.warnings.isEmpty) {
              ok = c;
              break;
            }
          }
        }
        if (ok != null) {
          best = ok;
          break;
        }
        // nothing passes: a gentler start when the design may choose one,
        // else the section reached with its messages
        final next = escalate && m.auto ? gentlerStarter(starter, submersible: m.submersible) : null;
        if (next == null) {
          best = circuitFor(powerCableSections[base < 0 ? last : math.min(last, base + maxUpsize)]);
          allOk = false;
          break;
        }
        starter = next;
      }
      out.add(best);
    }
    return (out, allOk);
  }

  // ---- the source: transformer, generator or the network
  var circuits = <PumpCircuit>[];
  var sourceReq = 0.0, source = 0.0, uk = 0.0, ik = double.infinity;
  final loading = (s.transformerLoadingPct / 100).clamp(0.3, 1.5).toDouble();
  final (ru, xu) = upstreamZ();
  switch (s.supply) {
    case PowerSupplyKind.ownTransformer:
      sourceReq = worstKva / loading;
      // a larger transformer before a heavier cable or a gentler starter
      List<PumpCircuit>? found;
      var chosen = standardTransformerKva.firstWhere((kva) => kva >= sourceReq - 1e-9, orElse: () => standardTransformerKva.last);
      for (final kva in standardTransformerKva) {
        if (kva < sourceReq - 1e-9) continue;
        final (rt, xt) = transformerZ(kva);
        final (cs, ok) = feeders(rt + ru, xt + xu);
        if (ok) {
          chosen = kva;
          found = cs;
          break;
        }
      }
      if (sourceReq > standardTransformerKva.last + 1e-9) warn('agb_transformer_large');
      final (rt, xt) = transformerZ(chosen);
      if (found == null) {
        final (cs, ok) = feeders(rt + ru, xt + xu, maxUpsize: powerCableSections.length, escalate: true);
        found = cs;
        if (!ok) warn('agb_transformer_start');
      }
      circuits = found;
      source = chosen;
      uk = ukOf(chosen);
      final z = math.sqrt(math.pow(rt + ru, 2) + math.pow(xt + xu, 2));
      ik = z > 0 ? 1.05 * u / (math.sqrt(3) * z) / 1000 : double.infinity;
    case PowerSupplyKind.lowVoltage:
      circuits = feeders(ru, xu, maxUpsize: powerCableSections.length, escalate: true).$1;
      final z = math.sqrt(ru * ru + xu * xu);
      ik = z > 0 ? 1.05 * u / (math.sqrt(3) * z) / 1000 : double.infinity;
    case PowerSupplyKind.generator:
      sourceReq = math.max(worstKva / loading, generatorKvaForStart(startingKva: largestStart, reactance: s.generatorReactance, dip: (s.allowedDipPct / 100).clamp(0.01, 0.99).toDouble()));
      source = standardGeneratorKva.firstWhere((g) => g >= sourceReq - 1e-9, orElse: () => sourceReq);
      if (source < sourceReq - 1e-9) warn('agb_generator_large');
      circuits = feeders(0, 0, generator: true, maxUpsize: powerCableSections.length, escalate: true).$1;
      uk = s.generatorReactance * 100;
  }
  for (final c in circuits) {
    for (final w in c.warnings) {
      warn(w);
    }
  }
  for (final ps in pivotSupplies) {
    for (final w in ps.warnings) {
      warn(w);
    }
  }
  if (motors.isEmpty && pivotSupplies.isEmpty) warn('agb_pump_house_empty');
  return PumpHouseResult(
    voltage: u,
    supply: s.supply,
    circuits: circuits,
    pivots: pivotSupplies,
    runningKva: worstKva,
    demandKw: worstKw,
    installedKw: installed,
    largestStartKva: largestStart,
    sourceKvaRequired: sourceReq,
    sourceKva: source,
    ukPct: uk,
    ik3SourceKa: ik,
    tariffGroup: installed <= 75 + 1e-9 ? 'B' : 'A',
    worstFlow: worstFlow,
    warnings: warnings,
  );
}

/// Supply of pivot [e] from its machine analysis: span cable ampacity
/// (method E, PVC, 30 °C), American gauge, collector ring, end tower and a
/// transformer of its own.
PivotSupply pivotSupplyOf(PivotEntity e, PivotElectricalResult el) {
  final w = <String>[];
  final first = el.towers.isEmpty ? null : el.towers.first;
  final last = el.towers.isEmpty ? null : el.towers.last;
  final current = first?.spanCurrentA ?? 0;
  final iz = cableAmpacity(el.cableMm2, CableInsulation.pvc, CableMethod.e);
  var minMm2 = el.cableMm2;
  if (current > 0) {
    minMm2 = powerCableSections.firstWhere((sct) => cableAmpacity(sct, CableInsulation.pvc, CableMethod.e) >= current - 1e-9, orElse: () => powerCableSections.last);
  }
  if (iz > 0 && current > iz + 1e-9) w.add('agb_pivot_span_ampacity:${e.id}');
  final kva = el.runningKva;
  final start = el.largestStartingKva;
  // a transformer of its own: running load within the rating, and the start
  // of the largest motor within a 10 % dip at the pivot point
  var tr = standardTransformerKva.last;
  for (final s in standardTransformerKva) {
    if (s < kva - 1e-9) continue;
    final dip = typicalTransformerUkPct(s) * start / s;
    if (dip <= 10 + 1e-9) {
      tr = s;
      break;
    }
  }
  final mm2 = math.max(el.cableMm2, minMm2);
  return PivotSupply(
    pivotId: e.id,
    name: e.name.isNotEmpty ? e.name : (e.zoneName.isNotEmpty ? e.zoneName : e.id),
    spanCableMm2: el.cableMm2,
    spanCurrentA: current,
    spanAmpacityA: iz,
    spanMinMm2: minMm2,
    awg: awgFor(mm2),
    collectorRingA: current,
    endTowerVolts: last?.volts ?? 0,
    endTowerDropPct: last?.runningDropPct ?? 0,
    boosterKw: el.boosterMotorKw,
    runningKva: kva,
    connectedKw: el.connectedKw,
    transformerKva: tr,
    warnings: w,
  );
}
