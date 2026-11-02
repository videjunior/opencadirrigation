/// Physical plausibility of catalogue data (the default catalogue,
/// manufacturer packs, imported price lists): a wall too thin for the
/// pressure class, a nozzle passing more water than an ideal orifice of its
/// bore, a pump curve asking more power than its motor can give. Each rule
/// catches a value misread from a data sheet, not a design choice.
library;

import 'dart:math' as math;

import '../hydraulics/water_hammer.dart';
import '../units.dart';
import 'catalog.dart';

/// Largest hoop stress (MPa) a thermoplastic pipe of [material] may work
/// at, its minimum required strength over the design coefficient: PVC-U
/// MRS 25 MPa with C = 1.7, the least coefficient of the published
/// irrigation series (ISO 1452 uses 2.0 to 2.5); PE 100 MRS 10 MPa with
/// C = 1.25 (ISO 4427); low-density PE (PE 40) MRS 4 MPa with C = 1.25.
/// Null for materials rated otherwise (metals, concrete).
double? pipeDesignStressMpa(PipeMaterial material) => switch (material) {
  PipeMaterial.pvc => 25 / 1.7,
  PipeMaterial.pehd => 10 / 1.25,
  PipeMaterial.peld => 4 / 1.25,
  _ => null,
};

/// Hoop stress (MPa) in the wall of [p] at its pressure rating (Barlow, the
/// relation of ISO 4065 between PN and SDR): σ = P·(SDR − 1)/2 with
/// SDR = outside diameter / wall; null without a wall or a rating.
double? pipeHoopStressMpa(PipeSpec p) {
  final e = p.wallThicknessMm;
  if (!(e > 0) || !(p.pressureRatingM > 0) || !(p.innerDiameterMm > 0)) return null;
  final sdr = (p.innerDiameterMm + 2 * e) / e;
  final mpa = p.pressureRatingM * waterDensity * gravity / 1e6;
  return mpa * (sdr - 1) / 2;
}

/// Service factor of a motor of [kw] (the share of its rating it carries
/// continuously, NEMA MG 1): 4" submersible motors 1.75 at 0.25 kW, 1.6 at
/// 0.37, 1.5 at 0.55, 1.4 at 0.75, 1.3 at 1.1, 1.25 at 1.5 and 1.15 from
/// 2.2 kW; other motors 1.15.
double motorServiceFactor(double kw, {bool submersible = false}) {
  if (!submersible) return 1.15;
  const table = [(0.25, 1.75), (0.37, 1.6), (0.55, 1.5), (0.75, 1.4), (1.1, 1.3), (1.5, 1.25)];
  for (final (p, sf) in table) {
    if (kw <= p * 1.02) return sf;
  }
  return 1.15;
}

/// Largest shaft power (kW) along the curve of [p] at full speed: ρ·g·Q·H
/// over the efficiency at each point.
double pumpCurveShaftKw(PumpSpec p) {
  var worst = 0.0;
  for (final (q, h) in p.points) {
    if (!(q > 0) || !(h > 0)) continue;
    worst = math.max(worst, waterDensity * gravity * q * h / p.efficiencyAt(q) / 1000);
  }
  return worst;
}

/// How the motor of [spec] copes with the duty [flow] (m³/s) at [pumpHead]
/// (m) and [speed] ratio, from the shaft power ρ·g·Q·H/η:
/// `pump_motor_overload` above its rating times its service factor
/// ([motorServiceFactor]), `pump_motor_sf` above the rating alone (1 % for
/// the rounding of the curve), null within it or without a rated power.
String? pumpMotorLoad(PumpSpec spec, double flow, double pumpHead, {double speed = 1}) {
  if (!(spec.powerKw > 0) || !(flow > 0) || !(pumpHead > 0)) return null;
  final kw = waterDensity * gravity * flow * pumpHead / spec.efficiencyAt(flow, speed: speed) / 1000;
  if (kw > spec.powerKw * motorServiceFactor(spec.powerKw, submersible: spec.submersible) * 1.01) return 'pump_motor_overload';
  if (kw > spec.powerKw * 1.01) return 'pump_motor_sf';
  return null;
}

/// Largest hydraulic power (kW) along the curve of [p]: ρ·g·Q·H.
double pumpCurveHydraulicKw(PumpSpec p) {
  var worst = 0.0;
  for (final (q, h) in p.points) {
    if (q > 0 && h > 0) worst = math.max(worst, waterDensity * gravity * q * h / 1000);
  }
  return worst;
}

/// The bores (mm) a nozzle name gives: `3.5 mm`, `4,0 mm`, a main and a
/// spreader `3.0 × 1.8 mm`; empty when it names none.
List<double> nozzleBoresMm(String name) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:[×x]\s*(\d+(?:[.,]\d+)?)\s*)?mm\b').firstMatch(name);
  if (m == null) return const [];
  return [
    for (final g in [m.group(1), m.group(2)])
      if (g != null) double.parse(g.replaceAll(',', '.')),
  ];
}

/// Discharge coefficient a nozzle of [bores] (mm) needs to pass [flow]
/// (m³/s) at [headM]: flow over that of ideal orifices, π/4·d²·√(2gH).
double nozzleDischargeCoefficient(List<double> bores, double flow, double headM) {
  final area = bores.fold(0.0, (a, d) => a + math.pi / 4 * math.pow(d / 1000, 2));
  if (!(area > 0) || !(headM > 0)) return 0;
  return flow / (area * math.sqrt(2 * gravity * headM));
}

/// The implausible items of [c], one line each (`code:item:value`):
/// - `pipe_wall`: the wall of a thermoplastic pipe would work above the
///   material's design stress ([pipeDesignStressMpa]) at its rating;
/// - `nozzle_cd`: a sprinkler or micro-sprinkler nozzle whose name gives its
///   bore passes more than an ideal orifice (discharge coefficient > 1);
/// - `pump_power`: the hydraulic power on a pump curve exceeds 0.85 of what
///   its motor gives at its service factor ([motorServiceFactor]).
/// [tolerance] allows for the rounding of published figures.
List<String> catalogPlausibility(Catalog c, {double tolerance = 0.03}) {
  final out = <String>[];
  String f(double v) => v.toStringAsFixed(2);
  for (final p in c.pipes) {
    final limit = pipeDesignStressMpa(p.material), s = pipeHoopStressMpa(p);
    if (limit != null && s != null && s > limit * (1 + tolerance)) out.add('pipe_wall:${p.id}:${f(s)}');
  }
  for (final o in c.outlets) {
    if (o.kind != OutletKind.sprinkler && o.kind != OutletKind.microSprinkler && o.kind != OutletKind.gun) continue;
    for (final n in o.nozzles) {
      final bores = nozzleBoresMm(n.name);
      if (bores.isEmpty) continue;
      final cd = nozzleDischargeCoefficient(bores, n.curve.flow(n.defaultHeadM), n.defaultHeadM);
      if (cd > 1 + tolerance) out.add('nozzle_cd:${o.id}/${n.id}:${f(cd)}');
    }
  }
  for (final p in c.pumps) {
    if (!(p.powerKw > 0)) continue;
    final hyd = pumpCurveHydraulicKw(p), max = p.powerKw * motorServiceFactor(p.powerKw, submersible: p.submersible);
    if (hyd > 0.85 * max * (1 + tolerance)) out.add('pump_power:${p.id}:${f(hyd / p.powerKw)}');
  }
  return out;
}
