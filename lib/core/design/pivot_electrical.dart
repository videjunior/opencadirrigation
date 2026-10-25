/// Electrical design of a centre pivot or linear move: tower drive motors,
/// voltage drop along the span cable of a three-phase supply, the end-gun
/// booster pump and the size of a generator.
///
/// * Motor current I = P/(√3·U·η·cos φ), P the rated output; starting
///   (locked-rotor) current k·I at a low power factor (direct-on-line
///   starting, k ≈ 6).
/// * Voltage drop span by span with the current of every motor beyond the
///   span: ΔU = √3·L·(R·ΣI·cos φ + X·ΣI·sin φ), the three-phase form of
///   IEC 60364-5-52 Annex G (b = 1; conductor resistance in service 1.25 ×
///   the value at 20 °C; reactance λ = 0.08 mΩ/m when unknown). Checked
///   running (every motor and the booster on, the worst case of the
///   alignment cycling) and while each motor starts with the others running.
/// * Cable: the smallest section of the list (IEC 60228 class-2 copper,
///   maximum resistance at 20 °C) that keeps both drops within the limits.
/// * Booster pump: shaft power ρ·g·q·ΔH/η and the next standard motor.
/// * Generator: the larger of the running kVA over the allowed loading and
///   the size that limits the voltage dip when the largest motor starts,
///   S = X''d·S_LR·(1 − dip)/dip, from the dip of a generator with
///   subtransient reactance X''d feeding a locked rotor (IEEE Std 399,
///   motor-starting studies; IEEE Std 446, generator sizing), rounded up to
///   a standard rating.
/// * Average power at a timer setting: a tower keeps aligned with the last
///   one, so it runs a share of the time proportional to its radius; the
///   last tower runs the timer fraction (Keller & Bliesner 1990, ch. 16).
library;

import 'dart:math' as math;

import '../hydraulics/pump.dart';
import 'pump_selection.dart' show standardMotor;

/// A cable section and its conductor resistance at 20 °C.
class CableOption {
  const CableOption(this.sectionMm2, this.ohmPerKm);
  final double sectionMm2;

  /// Resistance of one conductor (Ω/km at 20 °C).
  final double ohmPerKm;
}

/// IEC 60228 class-2 (stranded) copper conductors: maximum resistance at 20 °C (Ω/km).
const iecCopperCables = <CableOption>[
  CableOption(1.5, 12.1), CableOption(2.5, 7.41), CableOption(4, 4.61), CableOption(6, 3.08), CableOption(10, 1.83), CableOption(16, 1.15), CableOption(25, 0.727), CableOption(35, 0.524),
  CableOption(50, 0.387), CableOption(70, 0.268), CableOption(95, 0.193),
];

/// Standard generator-set ratings (kVA).
const standardGeneratorKva = <double>[7.5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60, 75, 100, 125, 150, 200, 250, 300, 400, 500, 625, 800, 1000];

/// Electrical data of a machine for [designPivotElectrical]. SI and kW.
class PivotElectricalSpec {
  const PivotElectricalSpec({
    required this.towerRadiiM,
    this.motorKw = 0.55,
    this.motorEfficiency = 0.70,
    this.motorPowerFactor = 0.72,
    this.startingMultiple = 6,
    this.startingPowerFactor = 0.4,
    this.voltage = 480,
    this.cables = iecCopperCables,
    this.cableSlack = 0.02,
    this.resistanceFactor = 1.25,
    this.reactanceOhmPerKm = 0.08,
    this.maxRunningDropPct = 5,
    this.maxStartingDropPct = 15,
    this.supplyCableM = 0,
    this.supplyCableMm2 = 0,
    this.boosterFlow = 0,
    this.boosterHeadM = 0,
    this.boosterPumpEfficiency = 0.65,
    this.boosterKw = 0,
    this.boosterMotorEfficiency = 0.8,
    this.boosterPowerFactor = 0.8,
    this.auxiliaryKw = 0,
    this.otherMotorKw = 0,
    this.otherMotorEfficiency = 0.9,
    this.otherMotorPowerFactor = 0.85,
    this.otherStartingMultiple = 6,
    this.generatorReactance = 0.2,
    this.allowedDip = 0.2,
    this.generatorLoading = 0.8,
    this.timerPct = 100,
  });

  /// Distance of every drive tower from the pivot point (m); a corner arm's towers may be added.
  final List<double> towerRadiiM;

  /// Tower motors: rated output (kW; 0.37–1.1 kW are usual), efficiency, power factor,
  /// locked-rotor to full-load current and the power factor while starting.
  final double motorKw;
  final double motorEfficiency;
  final double motorPowerFactor;
  final double startingMultiple;
  final double startingPowerFactor;

  /// Line-to-line voltage of the three-phase supply (V; 380, 440, 480…).
  final double voltage;

  /// Span cable sections to choose from, the extra length over the spans
  /// (fraction), the in-service resistance factor and the reactance (Ω/km).
  final List<CableOption> cables;
  final double cableSlack;
  final double resistanceFactor;
  final double reactanceOhmPerKm;

  /// Limits of the drop from the supply to a motor, running and starting (% of the voltage).
  final double maxRunningDropPct;
  final double maxStartingDropPct;

  /// Cable from the transformer or generator to the pivot point: length (m)
  /// and section (mm²; 0 = the span cable section).
  final double supplyCableM;
  final double supplyCableMm2;

  /// End-gun booster: flow (m³/s), head (m) and pump efficiency, or the rated
  /// motor (kW) when given; motor efficiency and power factor.
  final double boosterFlow;
  final double boosterHeadM;
  final double boosterPumpEfficiency;
  final double boosterKw;
  final double boosterMotorEfficiency;
  final double boosterPowerFactor;

  /// Loads at the pivot point: control panel and others (kW, unity power
  /// factor) and a motor fed by the same supply (kW, e.g. the pump) with its data.
  final double auxiliaryKw;
  final double otherMotorKw;
  final double otherMotorEfficiency;
  final double otherMotorPowerFactor;
  final double otherStartingMultiple;

  /// Generator subtransient reactance (per unit), allowed voltage dip while a
  /// motor starts (fraction) and continuous loading (fraction of the rating).
  final double generatorReactance;
  final double allowedDip;
  final double generatorLoading;

  /// Timer setting for the average power (%).
  final double timerPct;
}

/// One drive tower of the electrical table.
class PivotTowerElectrical {
  const PivotTowerElectrical({required this.index, required this.radiusM, required this.cableM, required this.spanCurrentA, required this.volts, required this.runningDropPct, required this.startingDropPct});

  /// 1-based tower number, distance from the pivot point (m) and cable length to it (m).
  final int index;
  final double radiusM;
  final double cableM;

  /// Current in the span cable feeding the tower, everything beyond it running (A).
  final double spanCurrentA;

  /// Voltage at the tower and drop from the supply, running (V, %), and the drop while its motor starts (%).
  final double volts;
  final double runningDropPct;
  final double startingDropPct;

  Map<String, dynamic> toJson() => {'i': index, 'r': radiusM, 'l': cableM, 'a': spanCurrentA, 'v': volts, 'du': runningDropPct, 'dus': startingDropPct};
  static PivotTowerElectrical fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PivotTowerElectrical(index: (j['i'] as num?)?.toInt() ?? 0, radiusM: d('r'), cableM: d('l'), spanCurrentA: d('a'), volts: d('v'), runningDropPct: d('du'), startingDropPct: d('dus'));
  }
}

/// Electrical design of a machine.
class PivotElectricalResult {
  const PivotElectricalResult({
    required this.towers,
    required this.cableMm2,
    required this.supplyCableMm2,
    required this.motorCurrentA,
    required this.connectedKw,
    required this.runningCurrentA,
    required this.runningKva,
    required this.maxRunningDropPct,
    required this.maxStartingDropPct,
    required this.boosterShaftKw,
    required this.boosterMotorKw,
    required this.boosterCurrentA,
    required this.largestStartingKva,
    required this.generatorKvaRequired,
    required this.generatorKva,
    required this.averagePowerKw,
    required this.warnings,
  });

  final List<PivotTowerElectrical> towers;

  /// Span cable and supply cable sections chosen (mm²).
  final double cableMm2;
  final double supplyCableMm2;

  /// Full-load current of a tower motor (A).
  final double motorCurrentA;

  /// Connected load (kW, rated outputs plus auxiliaries), current and apparent power with everything running (A, kVA).
  final double connectedKw;
  final double runningCurrentA;
  final double runningKva;

  /// Largest drop running and while a motor starts (%).
  final double maxRunningDropPct;
  final double maxStartingDropPct;

  /// Booster pump shaft power, its motor (kW) and current (A).
  final double boosterShaftKw;
  final double boosterMotorKw;
  final double boosterCurrentA;

  /// Locked-rotor kVA of the largest motor, generator size needed and the standard rating (kVA).
  final double largestStartingKva;
  final double generatorKvaRequired;
  final double generatorKva;

  /// Average electrical input at the timer setting (kW).
  final double averagePowerKw;

  /// Message codes (`pivot_elec_*`, with `:<id>` when an id was given).
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'towers': towers.map((t) => t.toJson()).toList(), 'mm2': cableMm2, 'smm2': supplyCableMm2, 'im': motorCurrentA, 'kw': connectedKw, 'irun': runningCurrentA, 'kva': runningKva, 'du': maxRunningDropPct,
    'dus': maxStartingDropPct, 'bsh': boosterShaftKw, 'bkw': boosterMotorKw, 'bi': boosterCurrentA, 'slr': largestStartingKva, 'greq': generatorKvaRequired, 'gkva': generatorKva, 'pavg': averagePowerKw, 'warn': warnings,
  };
  static PivotElectricalResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PivotElectricalResult(
      towers: ((j['towers'] as List?) ?? const []).map((t) => PivotTowerElectrical.fromJson(t as Map<String, dynamic>)).toList(), cableMm2: d('mm2'), supplyCableMm2: d('smm2'), motorCurrentA: d('im'),
      connectedKw: d('kw'), runningCurrentA: d('irun'), runningKva: d('kva'), maxRunningDropPct: d('du'), maxStartingDropPct: d('dus'), boosterShaftKw: d('bsh'), boosterMotorKw: d('bkw'), boosterCurrentA: d('bi'),
      largestStartingKva: d('slr'), generatorKvaRequired: d('greq'), generatorKva: d('gkva'), averagePowerKw: d('pavg'), warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Full-load current (A) of a three-phase motor: P/(√3·U·η·cos φ).
double motorCurrent({required double kw, required double voltage, double efficiency = 0.8, double powerFactor = 0.8}) =>
    kw <= 0 || voltage <= 0 ? 0 : kw * 1000 / (math.sqrt(3) * voltage * math.max(efficiency, 0.05) * math.max(powerFactor, 0.05));

/// Generator rating (kVA) whose voltage dip is [dip] when a locked rotor of
/// [startingKva] starts: X''d·S_LR·(1 − dip)/dip.
double generatorKvaForStart({required double startingKva, double reactance = 0.2, double dip = 0.2}) => dip <= 0 || dip >= 1 ? double.infinity : reactance * startingKva * (1 - dip) / dip;

class _Load {
  _Load(this.radius, this.amps, this.pf, this.startAmps, this.startPf, this.kva, this.startKva);
  final double radius;
  final double amps;
  final double pf;
  final double startAmps;
  final double startPf;
  final double kva;
  final double startKva;
  double get active => amps * pf;
  double get reactive => amps * math.sqrt(math.max(0.0, 1 - pf * pf));
}

/// Tower motor currents, span-cable drop and section, booster, generator and average power.
PivotElectricalResult designPivotElectrical(PivotElectricalSpec s, {String id = ''}) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  final radii = [...s.towerRadiiM.where((r) => r > 0)]..sort();
  if (radii.isEmpty) warn('pivot_elec_no_towers');
  final u = s.voltage;
  final im = motorCurrent(kw: s.motorKw, voltage: u, efficiency: s.motorEfficiency, powerFactor: s.motorPowerFactor);
  final motorKva = s.motorKw > 0 ? s.motorKw / (s.motorEfficiency * s.motorPowerFactor) : 0.0;
  final loads = <_Load>[for (final r in radii) _Load(r, im, s.motorPowerFactor, im * s.startingMultiple, s.startingPowerFactor, motorKva, motorKva * s.startingMultiple)];
  // booster at the last tower
  final boosterShaft = s.boosterFlow > 0 && s.boosterHeadM > 0 ? shaftPower(flow: s.boosterFlow, head: s.boosterHeadM, efficiency: s.boosterPumpEfficiency) / 1000 : 0.0;
  final boosterKw = s.boosterKw > 0 ? s.boosterKw : (boosterShaft > 0 ? standardMotor(boosterShaft)!.$1 : 0.0);
  final boosterAmps = motorCurrent(kw: boosterKw, voltage: u, efficiency: s.boosterMotorEfficiency, powerFactor: s.boosterPowerFactor);
  if (boosterKw > 0 && radii.isNotEmpty) {
    final kva = boosterKw / (s.boosterMotorEfficiency * s.boosterPowerFactor);
    loads.add(_Load(radii.last, boosterAmps, s.boosterPowerFactor, boosterAmps * s.startingMultiple, s.startingPowerFactor, kva, kva * s.startingMultiple));
  }
  // loads at the pivot point
  if (s.auxiliaryKw > 0) {
    final a = s.auxiliaryKw * 1000 / (math.sqrt(3) * u);
    loads.add(_Load(0, a, 1, a, 1, s.auxiliaryKw, s.auxiliaryKw));
  }
  if (s.otherMotorKw > 0) {
    final a = motorCurrent(kw: s.otherMotorKw, voltage: u, efficiency: s.otherMotorEfficiency, powerFactor: s.otherMotorPowerFactor);
    final kva = s.otherMotorKw / (s.otherMotorEfficiency * s.otherMotorPowerFactor);
    loads.add(_Load(0, a, s.otherMotorPowerFactor, a * s.otherStartingMultiple, s.startingPowerFactor, kva, kva * s.otherStartingMultiple));
  }

  final x = s.reactanceOhmPerKm;
  final cables = [...s.cables.where((c) => c.sectionMm2 > 0 && c.ohmPerKm > 0)]..sort((a, b) => a.sectionMm2.compareTo(b.sectionMm2));
  double ohmOf(double mm2) {
    for (final c in cables) {
      if ((c.sectionMm2 - mm2).abs() < 1e-9) return c.ohmPerKm;
    }
    return mm2 > 0 ? 18.1 / mm2 : double.infinity; // copper, IEC 60228 resistivity with stranding allowance
  }

  // drop (V) at the pivot point and at every tower with load [starting]
  // (index into loads, or -1) starting and the others running
  (double, List<double>) drops(double spanOhm, double supplyOhm, int starting) {
    double act(int i) => i == starting ? loads[i].startAmps * loads[i].startPf : loads[i].active;
    double rea(int i) => i == starting ? loads[i].startAmps * math.sqrt(math.max(0.0, 1 - loads[i].startPf * loads[i].startPf)) : loads[i].reactive;
    var ip = 0.0, iq = 0.0;
    for (var i = 0; i < loads.length; i++) {
      ip += act(i);
      iq += rea(i);
    }
    final atPivot = s.supplyCableM > 0 ? math.sqrt(3) * s.supplyCableM / 1000 * (s.resistanceFactor * supplyOhm * ip + x * iq) : 0.0;
    var du = atPivot;
    final out = <double>[];
    var prev = 0.0;
    for (final r in radii) {
      var sp = 0.0, sq = 0.0;
      for (var i = 0; i < loads.length; i++) {
        if (loads[i].radius >= r - 1e-9) {
          sp += act(i);
          sq += rea(i);
        }
      }
      final len = (r - prev) * (1 + s.cableSlack);
      du += math.sqrt(3) * len / 1000 * (s.resistanceFactor * spanOhm * sp + x * sq);
      out.add(du);
      prev = r;
    }
    return (atPivot, out);
  }

  (double, double, List<double>, List<double>) check(double spanMm2) {
    final spanOhm = ohmOf(spanMm2);
    final supplyOhm = s.supplyCableMm2 > 0 ? ohmOf(s.supplyCableMm2) : spanOhm;
    final running = drops(spanOhm, supplyOhm, -1).$2;
    final startAt = List<double>.filled(radii.length, 0);
    var worstStart = 0.0;
    for (var i = 0; i < loads.length; i++) {
      final (atPivot, d) = drops(spanOhm, supplyOhm, i);
      // the drop at the starting motor: at its tower, or at the pivot point
      final at = loads[i].radius > 0 ? radii.indexWhere((r) => (r - loads[i].radius).abs() < 1e-9) : -1;
      final v = at >= 0 ? d[at] : atPivot;
      worstStart = math.max(worstStart, v);
      if (at >= 0) startAt[at] = math.max(startAt[at], v);
    }
    return (running.isEmpty ? 0.0 : running.reduce(math.max), worstStart, running, startAt);
  }

  var chosen = cables.isEmpty ? 0.0 : cables.last.sectionMm2;
  var result = check(chosen);
  for (final c in cables) {
    final r = check(c.sectionMm2);
    if (100 * r.$1 / u <= s.maxRunningDropPct + 1e-9 && 100 * r.$2 / u <= s.maxStartingDropPct + 1e-9) {
      chosen = c.sectionMm2;
      result = r;
      break;
    }
  }
  final (runDrop, startDrop, running, startAt) = result;
  if (100 * runDrop / u > s.maxRunningDropPct + 1e-9) warn('pivot_elec_drop');
  if (100 * startDrop / u > s.maxStartingDropPct + 1e-9) warn('pivot_elec_start_drop');

  final towers = <PivotTowerElectrical>[];
  var prev = 0.0, cable = 0.0;
  for (var t = 0; t < radii.length; t++) {
    cable += (radii[t] - prev) * (1 + s.cableSlack);
    prev = radii[t];
    var sp = 0.0, sq = 0.0;
    for (final l in loads) {
      if (l.radius >= radii[t] - 1e-9) {
        sp += l.active;
        sq += l.reactive;
      }
    }
    towers.add(PivotTowerElectrical(index: t + 1, radiusM: radii[t], cableM: cable, spanCurrentA: math.sqrt(sp * sp + sq * sq), volts: u - running[t], runningDropPct: 100 * running[t] / u, startingDropPct: 100 * startAt[t] / u));
  }
  var ip = 0.0, iq = 0.0, kva = 0.0, startKva = 0.0;
  for (final l in loads) {
    ip += l.active;
    iq += l.reactive;
    kva += l.kva;
    startKva = math.max(startKva, l.startKva);
  }
  final genNeed = math.max(s.generatorLoading > 0 ? kva / s.generatorLoading : kva, generatorKvaForStart(startingKva: startKva, reactance: s.generatorReactance, dip: s.allowedDip));
  final gen = standardGeneratorKva.firstWhere((g) => g >= genNeed - 1e-9, orElse: () => genNeed);
  // average input at the timer setting
  final rLast = radii.isEmpty ? 1.0 : radii.last;
  final timer = s.timerPct.clamp(0.0, 100.0) / 100;
  var avg = s.auxiliaryKw + (s.otherMotorKw > 0 ? s.otherMotorKw / s.otherMotorEfficiency : 0.0) + (boosterKw > 0 ? boosterKw / s.boosterMotorEfficiency : 0.0);
  for (final r in radii) {
    avg += s.motorKw / s.motorEfficiency * timer * r / rLast;
  }
  return PivotElectricalResult(
    towers: towers, cableMm2: chosen, supplyCableMm2: s.supplyCableM > 0 ? (s.supplyCableMm2 > 0 ? s.supplyCableMm2 : chosen) : 0, motorCurrentA: im,
    connectedKw: s.motorKw * radii.length + boosterKw + s.auxiliaryKw + s.otherMotorKw, runningCurrentA: math.sqrt(ip * ip + iq * iq), runningKva: kva, maxRunningDropPct: 100 * runDrop / u,
    maxStartingDropPct: 100 * startDrop / u, boosterShaftKw: boosterShaft, boosterMotorKw: boosterKw, boosterCurrentA: boosterAmps, largestStartingKva: startKva, generatorKvaRequired: genNeed,
    generatorKva: gen, averagePowerKw: avg, warnings: warnings,
  );
}
