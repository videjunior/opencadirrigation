/// Potential runoff of the sprinkler irrigation of a design: the
/// application of a centre pivot or linear move along its length against
/// the infiltration of the soil under it, and the rate of the sprinkler
/// zones of every area against what its soil takes in.
///
/// Machines: the sprinklers of a moving lateral wet a strip of width w with
/// an elliptical pattern (Heermann & Hein 1968; Keller & Bliesner 1990,
/// chapter 14): at distance r from the pivot point the mean rate is the
/// flow per metre of the machine over w (2·Q·r/R² for a pivot, Q/L for a
/// linear) and the peak is 4/π of it, whatever the speed; the depth of a
/// pass sets how long the strip takes to pass a point, t = d/(π/4·Ip). The
/// rate i(t) = Ip·√(1 − (2t/t − 1)²) is laid against the infiltration
/// capacity of the soil — the revised NRCS intake family of NEH Part 623
/// chapter 4 (borders and basins, later irrigations by default) through the
/// time-compression approximation (the capacity at a cumulative depth Z is
/// the intake rate at the time the family needs to take in Z) — with the
/// surface storage of the soil and slope (allowable surface accumulation
/// of the SWAT/EPA table, soils.dart) held before any runoff. The result is
/// the runoff of a pass at the design depth, the largest depth per pass
/// without runoff and the smallest timer setting that keeps it.
///
/// Sprinkler zones (solid set): the application rate of the area's
/// sprinklers against the basic intake rate and the surface storage of the
/// SWAT/EPA table — the runoff of an event run without a pause, (PR − IR)·T
/// − ASA, the longest run before it and the cycles of cycle and soak
/// (water_budget.dart), the rule the controller programme uses.
///
/// The intake family of a soil texture, when none is typed, is the middle
/// of the sprinkler intake range of NEH Part 652 Table 2-6 (the family is
/// itself an average intake rate in in/h; open ranges take 2.0): an
/// estimate, field tests of infiltration take precedence.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'area_water.dart';
import 'designer.dart' show areaRequirements;
import 'mechanised.dart' show pivotSpecOf;
import 'results.dart';
import 'soils.dart';
import 'surface_irrigation.dart';
import 'water_budget.dart';

/// NRCS intake family (in/h) estimated for a texture class (see the
/// library notes).
double intakeFamilyFor(SoilTexture texture) {
  final (lo, hi) = soilOf(texture).sprinkleIntakeInH;
  if (!hi.isFinite) return 2.0;
  return ((lo + hi) / 2).clamp(0.05, 4.0).toDouble();
}

/// Infiltration capacity of an NRCS family by the time-compression
/// approximation: the cumulative depth and the intake rate tabulated over
/// opportunity times from one second to two days.
class IntakeCapacity {
  IntakeCapacity(this.law) {
    for (var k = 0; k <= _n; k++) {
      final tau = math.pow(10, k * _decades / _n).toDouble(); // 1 s to about two days
      _z.add(law.z(tau) * 1000);
      _f.add(law.rate(tau) * 1000 * 3600);
    }
  }

  /// The family's border and basin law (depth in m, time in s).
  final KostiakovLewis law;
  static const _n = 240;
  static const _decades = 5.24;
  final _z = <double>[];
  final _f = <double>[];

  /// From an NRCS family (in/h).
  factory IntakeCapacity.family(double family, {bool later = true}) => IntakeCapacity(nrcsBorderIntake(family, later: later));

  /// Intake rate (mm/h) once [zMm] has infiltrated.
  double rateAt(double zMm) {
    if (zMm <= _z.first) return _f.first;
    if (zMm >= _z.last) return _f.last;
    var lo = 0, hi = _n;
    while (hi - lo > 1) {
      final m = (lo + hi) >> 1;
      if (_z[m] <= zMm) {
        lo = m;
      } else {
        hi = m;
      }
    }
    final w = (zMm - _z[lo]) / (_z[hi] - _z[lo]);
    return _f[lo] + (_f[hi] - _f[lo]) * w;
  }
}

/// Runoff (mm) of one pass of an elliptical pattern of peak rate
/// [peakRateMmH] that applies [depthMm], on a soil of infiltration
/// [capacity] holding [surfaceStorageMm] on its surface.
double passRunoffMm({required double peakRateMmH, required double depthMm, required IntakeCapacity capacity, required double surfaceStorageMm, int steps = 400}) {
  if (peakRateMmH <= 0 || depthMm <= 0) return 0;
  final passH = depthMm / (math.pi / 4 * peakRateMmH);
  final dt = passH / steps;
  var z = 0.0, ponded = 0.0, runoff = 0.0;
  final storage = math.max(surfaceStorageMm, 0.0);
  for (var k = 0; k < steps; k++) {
    final x = (k + 0.5) / steps;
    final rate = peakRateMmH * math.sqrt(math.max(0.0, 1 - math.pow(2 * x - 1, 2)));
    final supply = rate * dt + ponded;
    final take = math.min(supply, capacity.rateAt(z) * dt);
    z += take;
    ponded = supply - take;
    if (ponded > storage) {
      runoff += ponded - storage;
      ponded = storage;
    }
  }
  return runoff;
}

/// The largest depth per pass (mm) at [peakRateMmH] without runoff (at most
/// [maxDepthMm]).
double maxRunoffFreeDepthMm({required double peakRateMmH, required IntakeCapacity capacity, required double surfaceStorageMm, double maxDepthMm = 150}) {
  bool runs(double d) => passRunoffMm(peakRateMmH: peakRateMmH, depthMm: d, capacity: capacity, surfaceStorageMm: surfaceStorageMm) > 0.01;
  if (!runs(maxDepthMm)) return maxDepthMm;
  var lo = 0.0, hi = maxDepthMm;
  for (var i = 0; i < 40 && hi - lo > 0.02; i++) {
    final m = (lo + hi) / 2;
    if (runs(m)) {
      hi = m;
    } else {
      lo = m;
    }
  }
  return lo;
}

/// Soil of the runoff analysis: an NRCS intake family (in/h) and the
/// surface storage (mm).
class RunoffSoil {
  const RunoffSoil({required this.family, required this.surfaceStorageMm, this.areaId, this.texture, this.slopePct = 0});
  final double family;
  final double surfaceStorageMm;
  final String? areaId;
  final SoilTexture? texture;
  final double slopePct;
}

/// The soil under point [at]: the first irrigated area holding it with a
/// soil class; null when none.
RunoffSoil? runoffSoilAt(Project p, Pt at) {
  for (final a in p.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3 || !pointInPolygon(at, a.points)) continue;
    final soil = soilTable[a.soilKey];
    if (soil == null) continue;
    return RunoffSoil(family: intakeFamilyFor(soil.texture), surfaceStorageMm: allowableSurfaceAccumulationMm(soil.texture, a.slopePct), areaId: a.id, texture: soil.texture, slopePct: a.slopePct);
  }
  return null;
}

/// One station along a machine.
class MachineRunoffRow {
  const MachineRunoffRow({
    required this.radiusM,
    required this.meanRateMmH,
    required this.peakRateMmH,
    required this.passMinutes,
    required this.depthMm,
    required this.runoffMm,
    required this.maxDepthMm,
    this.minTimerPct,
  });

  /// Distance from the pivot point (or along a linear, where every point
  /// is alike).
  final double radiusM;
  final double meanRateMmH;
  final double peakRateMmH;

  /// Time the wetted strip takes to pass at the design depth.
  final double passMinutes;
  final double depthMm;
  final double runoffMm;

  /// Largest depth per pass without runoff, and the timer setting that
  /// gives it (null without the depth at 100 %).
  final double maxDepthMm;
  final double? minTimerPct;

  double get runoffPct => depthMm > 0 ? 100 * runoffMm / depthMm : 0.0;
}

/// Runoff analysis of one machine.
class MachineRunoff {
  const MachineRunoff({required this.pivotId, required this.name, required this.soil, required this.rows, required this.depthAt100Mm});
  final String pivotId;
  final String name;
  final RunoffSoil soil;

  /// Station by station from the pivot point out (a linear has one row).
  final List<MachineRunoffRow> rows;

  /// Depth of a pass at 100 % of the timer (0 = unknown).
  final double depthAt100Mm;

  /// The worst station (the most runoff, then the smallest depth without
  /// it: the outer end of a pivot).
  MachineRunoffRow get worst {
    var w = rows.first;
    for (final r in rows.skip(1)) {
      if (r.runoffMm > w.runoffMm + 1e-9 || ((r.runoffMm - w.runoffMm).abs() <= 1e-9 && r.maxDepthMm < w.maxDepthMm)) w = r;
    }
    return w;
  }
}

/// Runoff analysis of machine [m] of [p] at its design depth, over [soil]
/// (the soil of the area under its pivot point when null); with [results]
/// the depth at 100 % of its timer gives the smallest timer setting. Null
/// without a soil or a flow.
MachineRunoff? machineRunoff(Project p, PivotEntity m, {RunoffSoil? soil, DesignResults? results, bool laterIrrigations = true}) {
  final s = soil ?? runoffSoilAt(p, m.center);
  if (s == null) return null;
  final spec = pivotSpecOf(p, m);
  final q = spec.sprinklerFlow * 3600; // m³/h
  final rr = spec.irrigatedRadius;
  final w = spec.wettedWidthM;
  if (q <= 0 || rr <= 0 || w <= 0) return null;
  final cap = IntakeCapacity.family(s.family, later: laterIrrigations);
  final d100 = results?.mechanised[m.id]?.package.depthAt100Mm ?? 0.0;
  final depth = spec.grossDepthMm;
  MachineRunoffRow row(double r) {
    final mean = m.kind == PivotKind.pivot ? 1000 * 2 * q * r / (rr * rr * w) : 1000 * q / (rr * w);
    final peak = mean * 4 / math.pi;
    final runoff = passRunoffMm(peakRateMmH: peak, depthMm: depth, capacity: cap, surfaceStorageMm: s.surfaceStorageMm);
    final maxD = maxRunoffFreeDepthMm(peakRateMmH: peak, capacity: cap, surfaceStorageMm: s.surfaceStorageMm, maxDepthMm: math.max(150.0, 4 * depth));
    return MachineRunoffRow(
      radiusM: r,
      meanRateMmH: mean,
      peakRateMmH: peak,
      passMinutes: peak > 0 ? 60 * depth / (math.pi / 4 * peak) : 0.0,
      depthMm: depth,
      runoffMm: runoff,
      maxDepthMm: maxD,
      minTimerPct: d100 > 0 && maxD > 0 ? math.min(100.0, 100 * d100 / maxD) : null,
    );
  }

  final rows = <MachineRunoffRow>[];
  if (m.kind == PivotKind.pivot) {
    final n = spec.towerCount;
    for (var i = 1; i <= n; i++) {
      rows.add(row(i * spec.spanLengthM));
    }
    if (rows.isEmpty || rows.last.radiusM < rr - 1e-6) rows.add(row(rr));
  } else {
    rows.add(row(rr));
  }
  return MachineRunoff(pivotId: m.id, name: m.name.isNotEmpty ? m.name : m.id, soil: s, rows: rows, depthAt100Mm: d100);
}

/// Runoff of the sprinklers of one irrigated area.
class ZoneRunoff {
  const ZoneRunoff({
    required this.areaId,
    required this.name,
    required this.rateMmH,
    required this.intakeMmH,
    required this.surfaceStorageMm,
    required this.runHours,
    required this.runoffMm,
    required this.maxRunMinutes,
    required this.cycles,
    required this.soakMinutes,
    required this.depthMm,
  });
  final String areaId;
  final String name;

  /// Application rate of the sprinklers over the area and the soil's basic
  /// intake rate (mm/h), surface storage (mm).
  final double rateMmH;
  final double intakeMmH;
  final double surfaceStorageMm;

  /// Run time (h) and gross depth (mm) of one event, the runoff of the
  /// event run without a pause (mm).
  final double runHours;
  final double depthMm;
  final double runoffMm;

  /// Longest run before runoff (minutes; infinite when the soil takes the
  /// rate), and the cycles and pause of cycle and soak.
  final double maxRunMinutes;
  final int cycles;
  final double soakMinutes;

  double get runoffPct => depthMm > 0 ? 100 * runoffMm / depthMm : 0.0;
}

/// Runoff of the sprinkler zones of every area of [p] with a soil class
/// (sprinkler irrigation only), at the event depth of the water rule
/// (area_water.dart) and the rate of its sprinklers ([results] when given,
/// else the nominal flows).
List<ZoneRunoff> zoneRunoff(Project p, {DesignResults? results}) {
  final rates = {for (final r in areaRequirements(p, results)) r.areaId: r};
  final out = <ZoneRunoff>[];
  for (final a in p.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3 || areaIrrigationMethod(a) != 'sprinkler') continue;
    final soil = soilTable[a.soilKey];
    final req = rates[a.id];
    if (soil == null || req == null || req.precipitationMmH <= 0 || req.machineFlow > 0.5 * req.flow) continue;
    final pr = req.precipitationMmH;
    final ir = soil.basicIntakeMmH;
    final asa = allowableSurfaceAccumulationMm(soil.texture, a.slopePct);
    final depth = areaWaterBasis(p, a).grossPerEventMm;
    final hours = depth / pr;
    final cs = cycleAndSoakForSoil(precipitationRateMmH: pr, depthMm: depth, texture: soil.texture, slopePct: a.slopePct);
    out.add(
      ZoneRunoff(
        areaId: a.id,
        name: a.name.isEmpty ? a.id : a.name,
        rateMmH: pr,
        intakeMmH: ir,
        surfaceStorageMm: asa,
        runHours: hours,
        depthMm: depth,
        runoffMm: pr > ir ? math.max(0.0, (pr - ir) * hours - asa) : 0.0,
        maxRunMinutes: cs.maxCycleMinutes,
        cycles: cs.cycles,
        soakMinutes: cs.soakMinutes,
      ),
    );
  }
  return out;
}
