/// Centre-pivot and linear-move hydraulics: system capacity from the
/// irrigated area, depth and cycle time; flow distribution along the machine
/// (∝ r for a pivot, uniform for a linear); friction by numeric integration
/// of the friction gradient along the span pipe; inlet pressure for the
/// worst (highest) position of the end sprinkler; per-tower pressures and
/// the peak application rate at the outer end (Keller & Bliesner 1990,
/// chap. 14; Chu & Moe 1972 for the pivot friction factor ≈ 0.543).
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../hydraulics/friction.dart';
import '../model/geometry.dart';

enum PivotKind { pivot, linear }

class PivotSpec {
  const PivotSpec({
    required this.kind,
    required this.lengthM,
    this.travelM = 0,
    this.spanLengthM = 50,
    this.pipeInnerMm = 162,
    this.hazenC = 130,
    this.roughnessMm = 0.15,
    this.method = FrictionMethod.hazenWilliams,
    this.kinematicViscosity = 1.004e-6,
    this.pipeHeightM = 3.5,
    this.endPressureM = 14,
    this.endGunFlow = 0,
    this.endGunPressureM = 0,
    this.endThrowM = 5,
    this.grossDepthMm = 8,
    this.hoursPerCycle = 24,
    this.wettedWidthM = 18,
    this.machineLossM = 2,
    this.maxAppRateMmH = 0,
    this.sectorDeg = 360,
    this.maxVelocity = 3.0,
    this.sprinklerSpacingM = 2.5,
  });

  final PivotKind kind;

  /// Spacing of the sprinklers along the span pipe (m), for the sprinkler
  /// chart and the bill of materials.
  final double sprinklerSpacingM;

  /// Pipe length from the pivot point (or from the inlet of a linear) to
  /// the last sprinkler, metres (spans + overhang).
  final double lengthM;

  /// Linear only: length of travel of the machine (field length), metres.
  final double travelM;
  final double spanLengthM;
  final double pipeInnerMm;
  final double hazenC;
  final double roughnessMm;
  final FrictionMethod method;
  final double kinematicViscosity;

  /// Height of the span pipe above the ground (static head at the inlet).
  final double pipeHeightM;

  /// Pressure head needed at the last sprinkler (m).
  final double endPressureM;

  /// End gun flow (m³/s) and pressure it needs when on (0 = none).
  final double endGunFlow;
  final double endGunPressureM;

  /// Throw of the last sprinkler beyond the pipe end (irrigated radius = length + throw).
  final double endThrowM;

  /// Gross depth applied per cycle (mm) in [hoursPerCycle] hours.
  final double grossDepthMm;
  final double hoursPerCycle;

  /// Wetted width of the outer sprinklers (m), for the application rate.
  final double wettedWidthM;

  /// Fixed losses of the machine (pivot elbow, swivel, tower connections), m.
  final double machineLossM;

  /// Soil intake limit (mm/h); 0 disables the check.
  final double maxAppRateMmH;

  /// Angle irrigated (pivot only; 360 = full circle).
  final double sectorDeg;
  final double maxVelocity;

  double get irrigatedRadius => lengthM + endThrowM;

  /// Irrigated area (m²).
  double get area => kind == PivotKind.pivot ? math.pi * irrigatedRadius * irrigatedRadius * (sectorDeg.clamp(1.0, 360.0) / 360) : irrigatedRadius * math.max(travelM, 0.0);

  /// Sprinkler flow (m³/s) needed for the depth in the cycle time.
  double get sprinklerFlow => hoursPerCycle <= 0 ? 0 : area * grossDepthMm / 1000 / (hoursPerCycle * 3600);

  int get towerCount => spanLengthM <= 0 ? 0 : math.max(1, (lengthM / spanLengthM).floor());
  double get overhangM => lengthM - towerCount * spanLengthM;
}

class PivotTowerRow {
  const PivotTowerRow({required this.index, required this.distance, required this.flowPast, required this.pressure, required this.groundRise});

  /// 0 = pivot point / inlet.
  final int index;
  final double distance;

  /// Flow carried by the pipe beyond this point (m³/s).
  final double flowPast;

  /// Pressure head at the sprinklers of this point in the worst position (m).
  final double pressure;

  /// Ground rise from the inlet at the worst azimuth (m).
  final double groundRise;

  Map<String, dynamic> toJson() => {'i': index, 'd': distance, 'q': flowPast, 'h': pressure, 'dz': groundRise};
  static PivotTowerRow fromJson(Map<String, dynamic> j) => PivotTowerRow(index: (j['i'] as num).toInt(), distance: (j['d'] as num).toDouble(), flowPast: (j['q'] as num).toDouble(), pressure: (j['h'] as num).toDouble(), groundRise: (j['dz'] as num?)?.toDouble() ?? 0);
}

/// One span of the machine in the sprinkler chart: sprinklers, flow each
/// and pressure at mid-span, with the catalogue nozzle closest to that flow.
class PivotSpanRow {
  const PivotSpanRow({required this.index, required this.rStart, required this.rEnd, required this.sprinklers, required this.flowPerSprinkler, required this.pressure, this.nozzle = ''});
  final int index;
  final double rStart;
  final double rEnd;
  final int sprinklers;

  /// Flow each sprinkler must deliver (m³/s).
  final double flowPerSprinkler;

  /// Pressure head at mid-span in the worst position (m).
  final double pressure;
  final String nozzle;

  Map<String, dynamic> toJson() => {'i': index, 'r0': rStart, 'r1': rEnd, 'n': sprinklers, 'q': flowPerSprinkler, 'h': pressure, if (nozzle.isNotEmpty) 'noz': nozzle};
  static PivotSpanRow fromJson(Map<String, dynamic> j) => PivotSpanRow(index: (j['i'] as num).toInt(), rStart: (j['r0'] as num).toDouble(), rEnd: (j['r1'] as num).toDouble(), sprinklers: (j['n'] as num).toInt(), flowPerSprinkler: (j['q'] as num).toDouble(), pressure: (j['h'] as num).toDouble(), nozzle: j['noz'] as String? ?? '');
}

class PivotResult {
  PivotResult({
    required this.pivotId,
    required this.name,
    required this.kind,
    required this.flow,
    required this.endGunFlow,
    required this.inletHead,
    required this.frictionLoss,
    required this.elevationRise,
    required this.endPressure,
    required this.pipeHeight,
    required this.machineLoss,
    required this.towerCount,
    required this.towers,
    required this.areaM2,
    required this.depthPerCycleMm,
    required this.hoursPerCycle,
    required this.appRateEndAvg,
    required this.appRateEndPeak,
    required this.inletVelocity,
    required this.warnings,
    this.availableHead,
    this.spans = const [],
  });

  final String pivotId;

  /// Sprinkler chart per span.
  final List<PivotSpanRow> spans;

  /// Sprinklers along the whole machine.
  int get sprinklerCount => spans.fold(0, (s, r) => s + r.sprinklers);
  final String name;
  final PivotKind kind;

  /// Total flow at the inlet (sprinklers + end gun), m³/s.
  final double flow;
  final double endGunFlow;

  /// Pressure head required at the inlet (ground level at the pivot point), m.
  final double inletHead;
  final double frictionLoss;
  final double elevationRise;
  final double endPressure;
  final double pipeHeight;
  final double machineLoss;
  final int towerCount;
  final List<PivotTowerRow> towers;
  final double areaM2;
  final double depthPerCycleMm;
  final double hoursPerCycle;

  /// Average and peak application rates under the outer end (mm/h).
  final double appRateEndAvg;
  final double appRateEndPeak;
  final double inletVelocity;
  final List<String> warnings;

  /// Pressure available at the inlet from the mainline analysis (m), when known.
  double? availableHead;

  double get deficit => availableHead == null ? 0 : inletHead - availableHead!;

  Map<String, dynamic> toJson() => {
    'id': pivotId, 'name': name, 'kind': kind.name, 'q': flow, 'qg': endGunFlow, 'hin': inletHead, 'hf': frictionLoss, 'dz': elevationRise, 'hend': endPressure, 'hp': pipeHeight, 'hm': machineLoss,
    'n': towerCount, 'towers': towers.map((t) => t.toJson()).toList(), 'area': areaM2, 'depth': depthPerCycleMm, 'hours': hoursPerCycle, 'iavg': appRateEndAvg, 'ipeak': appRateEndPeak, 'v': inletVelocity,
    'warn': warnings, if (availableHead != null) 'havail': availableHead, if (spans.isNotEmpty) 'spans': spans.map((s) => s.toJson()).toList(),
  };
  static PivotResult fromJson(Map<String, dynamic> j) {
    double d(String k, [double def = 0]) => (j[k] as num?)?.toDouble() ?? def;
    return PivotResult(
      pivotId: j['id'] as String, name: j['name'] as String? ?? '', kind: PivotKind.values.byName(j['kind'] as String? ?? 'pivot'), flow: d('q'), endGunFlow: d('qg'), inletHead: d('hin'), frictionLoss: d('hf'), elevationRise: d('dz'),
      endPressure: d('hend'), pipeHeight: d('hp'), machineLoss: d('hm'), towerCount: (j['n'] as num?)?.toInt() ?? 0, towers: ((j['towers'] as List?) ?? []).map((t) => PivotTowerRow.fromJson(t as Map<String, dynamic>)).toList(),
      areaM2: d('area'), depthPerCycleMm: d('depth'), hoursPerCycle: d('hours'), appRateEndAvg: d('iavg'), appRateEndPeak: d('ipeak'), inletVelocity: d('v'), warnings: ((j['warn'] as List?) ?? []).cast<String>(),
      availableHead: (j['havail'] as num?)?.toDouble(),
      spans: ((j['spans'] as List?) ?? []).map((s) => PivotSpanRow.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

/// Friction gradient (m/m) at [flow] in the span pipe.
double _gradient(PivotSpec s, double flow) {
  final d = s.pipeInnerMm / 1000;
  if (flow <= 0 || d <= 0) return 0;
  switch (s.method) {
    case FrictionMethod.hazenWilliams:
      return hazenWilliamsLoss(flow: flow, diameter: d, length: 1, c: s.hazenC);
    case FrictionMethod.darcyWeisbach:
      return darcyWeisbachLoss(flow: flow, diameter: d, length: 1, roughness: s.roughnessMm / 1000, kinematicViscosity: s.kinematicViscosity);
  }
}

/// Flow carried by the pipe beyond distance [r] from the inlet (sprinklers only).
double flowBeyond(PivotSpec s, double r) {
  final q = s.sprinklerFlow;
  final rr = s.irrigatedRadius;
  if (q <= 0 || rr <= 0) return 0;
  final x = (r / rr).clamp(0.0, 1.0);
  return s.kind == PivotKind.pivot ? q * (1 - x * x) : q * (1 - x);
}

/// Friction loss (m) from the inlet to distance [r].
double frictionTo(PivotSpec s, double r, {int steps = 200}) {
  if (r <= 0) return 0;
  final n = math.max(4, steps);
  final h = r / n;
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    final a = i * h, b = (i + 1) * h, m = (a + b) / 2;
    final ga = _gradient(s, flowBeyond(s, a) + s.endGunFlow);
    final gm = _gradient(s, flowBeyond(s, m) + s.endGunFlow);
    final gb = _gradient(s, flowBeyond(s, b) + s.endGunFlow);
    sum += (ga + 4 * gm + gb) / 6 * h; // Simpson
  }
  return sum;
}

/// Ground rise profile: [groundRiseAt] gives the rise of the ground at a
/// distance from the inlet, for the worst azimuth (highest end position).
PivotResult analyzePivot(
  PivotSpec s, {
  required String id,
  required String name,
  double Function(double distance)? groundRiseAt,
  List<(String, EmitterCurve)> nozzles = const [],
}) {
  final warnings = <String>[];
  final rise = groundRiseAt ?? (_) => 0.0;
  final q = s.sprinklerFlow;
  final total = q + s.endGunFlow;
  final hfEnd = frictionTo(s, s.lengthM);
  final dzEnd = rise(s.lengthM);
  // pressure needed at the pivot point (ground level): end sprinkler or end gun,
  // whichever governs, plus static height of the pipe, friction and ground rise
  final endNeed = math.max(s.endPressureM, s.endGunFlow > 0 ? s.endGunPressureM : 0.0);
  var inlet = endNeed + hfEnd + dzEnd + s.pipeHeightM + s.machineLossM;
  // any intermediate point may govern when the ground rises sharply mid-way
  final towers = <PivotTowerRow>[];
  final nTowers = s.towerCount;
  final stations = <double>[0, for (var i = 1; i <= nTowers; i++) i * s.spanLengthM, if (s.overhangM > 1e-6) s.lengthM];
  for (final r in stations) {
    final need = s.endPressureM + frictionTo(s, r) + rise(r) + s.pipeHeightM + s.machineLossM;
    if (need > inlet) inlet = need;
  }
  var idx = 0;
  for (final r in stations) {
    final p = inlet - s.pipeHeightM - s.machineLossM - frictionTo(s, r) - rise(r);
    towers.add(PivotTowerRow(index: idx++, distance: r, flowPast: flowBeyond(s, r) + s.endGunFlow, pressure: p, groundRise: rise(r)));
  }
  final d = s.pipeInnerMm / 1000;
  final v = d > 0 ? velocity(flow: total, diameter: d) : 0.0;
  if (v > s.maxVelocity + 1e-6) warnings.add('velocity_exceeded:$id');
  // application rate at the outer end (mm/h)
  final qh = q * 3600; // m³/h
  double iAvg, iPeak;
  if (s.kind == PivotKind.pivot) {
    // I(R) = 2·Q·R/(R²·w): the flow per unit length at the outer end over the
    // wetted width. Q is already the sector flow (area·depth/cycle), and a
    // sector machine sweeps its angle in the same cycle time, so no further
    // sector correction applies.
    final rr = s.irrigatedRadius;
    iAvg = rr > 0 && s.wettedWidthM > 0 ? 1000 * 2 * qh / (rr * s.wettedWidthM) : 0.0;
  } else {
    iAvg = s.irrigatedRadius > 0 && s.wettedWidthM > 0 ? 1000 * qh / (s.irrigatedRadius * s.wettedWidthM) : 0.0;
  }
  iPeak = iAvg * 4 / math.pi;
  if (s.maxAppRateMmH > 0 && iPeak > s.maxAppRateMmH + 1e-6) warnings.add('pivot_app_rate:$id');
  if (q <= 0) warnings.add('pivot_no_flow:$id');
  if (s.endPressureM <= 0) warnings.add('pivot_no_end_pressure:$id');
  // sprinkler chart per span
  final spans = <PivotSpanRow>[];
  if (s.spanLengthM > 0 && s.lengthM > 0) {
    final rr = s.irrigatedRadius;
    var i = 0;
    for (var r0 = 0.0; r0 < s.lengthM - 1e-6; r0 += s.spanLengthM) {
      final r1 = math.min(r0 + s.spanLengthM, s.lengthM);
      final count = math.max(1, ((r1 - r0) / math.max(s.sprinklerSpacingM, 0.1)).round());
      final qSeg = rr <= 0 ? 0.0 : (s.kind == PivotKind.pivot ? q * (r1 * r1 - r0 * r0) / (rr * rr) : q * (r1 - r0) / rr);
      final mid = (r0 + r1) / 2;
      final p = inlet - s.pipeHeightM - s.machineLossM - frictionTo(s, mid) - rise(mid);
      final each = qSeg / count;
      var nozzle = '';
      if (nozzles.isNotEmpty && each > 0) {
        var best = double.infinity;
        for (final (nm, curve) in nozzles) {
          final d = (curve.flow(math.max(p, 0.1)) - each).abs();
          if (d < best) {
            best = d;
            nozzle = nm;
          }
        }
      }
      spans.add(PivotSpanRow(index: ++i, rStart: r0, rEnd: r1, sprinklers: count, flowPerSprinkler: each, pressure: p, nozzle: nozzle));
    }
  }
  return PivotResult(
    pivotId: id,
    name: name,
    kind: s.kind,
    flow: total,
    endGunFlow: s.endGunFlow,
    inletHead: inlet,
    frictionLoss: hfEnd,
    elevationRise: dzEnd,
    endPressure: endNeed,
    pipeHeight: s.pipeHeightM,
    machineLoss: s.machineLossM,
    towerCount: nTowers,
    towers: towers,
    areaM2: s.area,
    depthPerCycleMm: s.grossDepthMm,
    hoursPerCycle: s.hoursPerCycle,
    appRateEndAvg: iAvg,
    appRateEndPeak: iPeak,
    inletVelocity: v,
    warnings: warnings,
    spans: spans,
  );
}

/// Worst-case ground rise along the machine: for a pivot the maximum over
/// the azimuths of the sector of the ground at distance r from the centre;
/// for a linear the maximum over the travel positions.
double Function(double) groundRiseFunction(PivotSpec s, Pt inlet, double angleRad, double Function(Pt) elevationAt, {int azimuths = 72}) {
  final z0 = elevationAt(inlet);
  final cache = <int, double>{};
  return (double r) {
    final key = (r * 10).round();
    final c = cache[key];
    if (c != null) return c;
    var worst = -double.infinity;
    if (s.kind == PivotKind.pivot) {
      final sweep = s.sectorDeg.clamp(1.0, 360.0) * math.pi / 180;
      final n = math.max(8, (azimuths * sweep / (2 * math.pi)).round());
      for (var i = 0; i <= n; i++) {
        final a = angleRad + sweep * i / n - (sweep >= 2 * math.pi - 1e-9 ? 0 : sweep / 2);
        worst = math.max(worst, elevationAt(inlet + Pt.polar(r, a)) - z0);
      }
    } else {
      final along = Pt.polar(1, angleRad);
      final travel = along.perpendicular;
      final n = math.max(4, (s.travelM / 25).round());
      for (var i = 0; i <= n; i++) {
        final p = inlet + along * r + travel * (s.travelM * i / n);
        worst = math.max(worst, elevationAt(p) - elevationAt(inlet + travel * (s.travelM * i / n)));
      }
    }
    final v = worst.isFinite ? math.max(worst, 0.0).toDouble() : 0.0;
    cache[key] = v;
    return v;
  };
}
