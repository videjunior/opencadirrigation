/// Variable-rate irrigation (VRI) prescription for a centre pivot: the
/// percent-timer (speed) setting of every angular sector and, with zone
/// control, the duty of the radial sprinkler banks, so the machine applies
/// target depths given by zones (polygons) or by sectors.
///
/// * Speed control: the depth of a pass is inversely proportional to the
///   speed, d(p) = d100·100/p (the timer chart of the machine; Kansas State
///   Univ. MF3608), so a sector with target d runs at p = 100·d100/d,
///   limited to [minimum timer, 100 %]: targets below d100 cannot be reached
///   by speed alone and targets beyond the slowest setting are capped.
/// * Zone control: the sector runs at the speed of its wettest bank and the
///   other banks pulse on and off with a duty d_bank/d_sector (the speed and
///   zone control modes of site-specific sprinkler VRI, Evans et al. 2013,
///   Irrigation Science 31: 871–887).
/// * Zone depths are sampled on equal-area points of every sector and ring;
///   a sector's speed target is the area-weighted mean of its points (or
///   their maximum or minimum, by choice).
/// Angles are the drawing's: degrees counter-clockwise from +x; the CSV can
/// also give compass bearings (clockwise from north).
library;

import 'dart:math' as math;

import '../model/geometry.dart';

/// A prescription zone: polygon (world coordinates) and target gross depth (mm).
class VriZone {
  const VriZone({required this.polygon, required this.depthMm});
  final List<Pt> polygon;
  final double depthMm;
}

/// A prescription sector: from [startDeg] counter-clockwise to [endDeg], target gross depth (mm).
class VriSectorTarget {
  const VriSectorTarget({required this.startDeg, required this.endDeg, required this.depthMm});
  final double startDeg;
  final double endDeg;
  final double depthMm;
}

/// How the points of a sector make its speed target.
enum VriSectorRule { areaWeighted, maximum, minimum }

/// Machine and prescription grid for [vriFromZones] and [vriFromSectors].
class VriSpec {
  const VriSpec({
    required this.center,
    required this.radiusM,
    required this.depthAt100Mm,
    this.innerRadiusM = 0,
    this.startDeg = 0,
    this.sweepDeg = 360,
    this.sectorStepDeg = 2,
    this.minTimerPct = 5,
    this.bankEdgesM = const [],
    this.rule = VriSectorRule.areaWeighted,
    this.baseDepthMm = 0,
    this.radialSamples = 8,
    this.angularSamples = 4,
  });

  /// Pivot point and the irrigated radius (m); the inner radius leaves out the centre.
  final Pt center;
  final double radiusM;
  final double innerRadiusM;

  /// Gross depth at 100 % timer (mm), from the timer chart.
  final double depthAt100Mm;

  /// Sector grid: first angle, angle covered and sector width (degrees).
  final double startDeg;
  final double sweepDeg;
  final double sectorStepDeg;

  /// Slowest timer setting the panel accepts (%).
  final double minTimerPct;

  /// Boundaries between radial sprinkler banks (m from the pivot point) for
  /// zone control; empty = speed control only.
  final List<double> bankEdgesM;

  final VriSectorRule rule;

  /// Depth outside every zone or sector (mm); 0 = the depth at 100 %.
  final double baseDepthMm;

  /// Sampling of each sector and ring (equal-area points).
  final int radialSamples;
  final int angularSamples;

  /// Ring boundaries from the inner to the irrigated radius.
  List<double> rings() {
    final inner = math.max(innerRadiusM, 0.0);
    return [inner, for (final e in [...bankEdgesM]..sort()) if (e > inner + 1e-9 && e < radiusM - 1e-9) e, radiusM];
  }
}

/// One line of the prescription.
class VriRow {
  const VriRow({required this.startDeg, required this.endDeg, required this.timerPct, required this.depthMm, required this.targetMm, this.bankDutyPct = const [], this.limit = 0});

  /// Sector from [startDeg] counter-clockwise to [endDeg] (degrees).
  final double startDeg;
  final double endDeg;

  /// Timer (speed) setting (%), depth applied at that speed (mm) and the target that set it (mm).
  final double timerPct;
  final double depthMm;
  final double targetMm;

  /// Zone control: on-time of every bank (% of the time), from the pivot point out.
  final List<double> bankDutyPct;

  /// 0 = target met; 1 = target below the depth at 100 % (runs at 100 %); 2 = beyond the slowest setting.
  final int limit;

  Map<String, dynamic> toJson() => {'a0': startDeg, 'a1': endDeg, 'p': timerPct, 'd': depthMm, 't': targetMm, if (bankDutyPct.isNotEmpty) 'duty': bankDutyPct, if (limit != 0) 'lim': limit};
  static VriRow fromJson(Map<String, dynamic> j) => VriRow(
    startDeg: (j['a0'] as num).toDouble(), endDeg: (j['a1'] as num).toDouble(), timerPct: (j['p'] as num).toDouble(), depthMm: (j['d'] as num).toDouble(), targetMm: (j['t'] as num).toDouble(),
    bankDutyPct: ((j['duty'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(), limit: (j['lim'] as num?)?.toInt() ?? 0,
  );
}

/// VRI prescription of a pivot.
class VriResult {
  const VriResult({required this.rows, required this.bankEdgesM, required this.depthAt100Mm, required this.maxDepthMm, required this.warnings});
  final List<VriRow> rows;

  /// Ring boundaries of the banks (m), inner and outer radius included.
  final List<double> bankEdgesM;
  final double depthAt100Mm;

  /// Deepest depth the machine applies, at the slowest setting (mm).
  final double maxDepthMm;

  /// Message codes (`vri_*`, with `:<id>` when an id was given).
  final List<String> warnings;

  /// The prescription as CSV (comma separator, point decimal): start, end,
  /// timer %, depth, target and one duty column per bank. [compass] turns the
  /// angles into bearings clockwise from north (start and end swapped so the
  /// sector still runs clockwise from start to end); [header] replaces the
  /// default column codes.
  String toCsv({bool compass = false, List<String>? header}) {
    final banks = rows.isEmpty ? 0 : rows.first.bankDutyPct.length;
    final cols = header ?? ['start_deg', 'end_deg', 'timer_pct', 'depth_mm', 'target_mm', for (var b = 1; b <= banks; b++) 'bank${b}_pct'];
    double bearing(double a) => ((90 - a) % 360 + 360) % 360;
    final lines = [cols.join(',')];
    for (final r in rows) {
      final a0 = compass ? bearing(r.endDeg) : r.startDeg, a1 = compass ? bearing(r.startDeg) : r.endDeg;
      lines.add([a0, a1, r.timerPct, r.depthMm, r.targetMm, ...r.bankDutyPct].map((v) => v.toStringAsFixed(2)).join(','));
    }
    return '${lines.join('\n')}\n';
  }

  Map<String, dynamic> toJson() => {'rows': rows.map((e) => e.toJson()).toList(), 'edges': bankEdgesM, 'd100': depthAt100Mm, 'dmax': maxDepthMm, 'warn': warnings};
  static VriResult fromJson(Map<String, dynamic> j) => VriResult(
    rows: ((j['rows'] as List?) ?? const []).map((e) => VriRow.fromJson(e as Map<String, dynamic>)).toList(), bankEdgesM: ((j['edges'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
    depthAt100Mm: (j['d100'] as num?)?.toDouble() ?? 0, maxDepthMm: (j['dmax'] as num?)?.toDouble() ?? 0, warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
  );
}

/// Prescription from zones (polygons with depths): the first zone holding a
/// point gives its depth.
VriResult vriFromZones(VriSpec s, List<VriZone> zones, {String id = ''}) {
  final base = s.baseDepthMm > 0 ? s.baseDepthMm : s.depthAt100Mm;
  double depthAt(Pt p) {
    for (final z in zones) {
      if (z.polygon.length >= 3 && pointInPolygon(p, z.polygon)) return z.depthMm;
    }
    return base;
  }

  return _prescribe(s, id, (a0, a1, r0, r1) {
    final na = math.max(1, s.angularSamples), nr = math.max(1, s.radialSamples);
    var sum = 0.0, mx = -double.infinity, mn = double.infinity;
    for (var i = 0; i < na; i++) {
      final a = degToRad(a0 + (a1 - a0) * (i + 0.5) / na);
      for (var k = 0; k < nr; k++) {
        // equal-area radial samples
        final r = math.sqrt(r0 * r0 + (r1 * r1 - r0 * r0) * (k + 0.5) / nr);
        final d = depthAt(s.center + Pt.polar(r, a));
        sum += d;
        mx = math.max(mx, d);
        mn = math.min(mn, d);
      }
    }
    return (sum / (na * nr), mx, mn);
  });
}

/// Prescription from sectors with depths (angles counter-clockwise; a sector
/// may cross 0°); the parts no sector covers get the base depth.
VriResult vriFromSectors(VriSpec s, List<VriSectorTarget> sectors, {String id = ''}) {
  final base = s.baseDepthMm > 0 ? s.baseDepthMm : s.depthAt100Mm;
  // overlap (degrees) of [a0, a1] with a sector, counting its turns around the circle
  double overlap(double a0, double a1, VriSectorTarget t) {
    var span = (t.endDeg - t.startDeg) % 360;
    if (span <= 0) span += 360;
    var o = 0.0;
    for (final shift in const [-720.0, -360.0, 0.0, 360.0, 720.0]) {
      final lo = t.startDeg + shift, hi = lo + span;
      o += math.max(0.0, math.min(a1, hi) - math.max(a0, lo));
    }
    return o;
  }

  return _prescribe(s, id, (a0, a1, r0, r1) {
    final width = a1 - a0;
    var covered = 0.0, sum = 0.0, mx = -double.infinity, mn = double.infinity;
    for (final t in sectors) {
      final o = math.min(overlap(a0, a1, t), width - covered);
      if (o <= 1e-12) continue;
      covered += o;
      sum += o * t.depthMm;
      mx = math.max(mx, t.depthMm);
      mn = math.min(mn, t.depthMm);
    }
    if (covered < width - 1e-9) {
      sum += (width - covered) * base;
      mx = math.max(mx, base);
      mn = math.min(mn, base);
    }
    return (width > 0 ? sum / width : base, mx, mn);
  });
}

/// Builds the rows from a sampler returning (mean, max, min) target depth of
/// a sector [a0, a1] (degrees) and ring [r0, r1] (m).
VriResult _prescribe(VriSpec s, String id, (double, double, double) Function(double a0, double a1, double r0, double r1) sample) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  final d100 = s.depthAt100Mm;
  final minTimer = s.minTimerPct.clamp(0.1, 100.0).toDouble();
  final maxDepth = d100 > 0 ? d100 * 100 / minTimer : 0.0;
  final rings = s.rings();
  if (d100 <= 0 || s.radiusM <= 0) {
    warn('vri_no_depth');
    return VriResult(rows: const [], bankEdgesM: rings, depthAt100Mm: d100, maxDepthMm: maxDepth, warnings: warnings);
  }
  final zoneControl = rings.length > 2;
  final sweep = s.sweepDeg.clamp(0.1, 360.0).toDouble();
  final step = s.sectorStepDeg.clamp(0.1, 90.0).toDouble();
  final n = (sweep / step - 1e-9).ceil();
  (double, int) timerFor(double target) {
    if (target <= d100 + 1e-9) return (100, target < d100 - 1e-9 ? 1 : 0);
    final p = 100 * d100 / target;
    return p < minTimer ? (minTimer, 2) : (p, 0);
  }

  final raw = <VriRow>[];
  for (var k = 0; k < n; k++) {
    final a0 = s.startDeg + k * step, a1 = math.min(s.startDeg + (k + 1) * step, s.startDeg + sweep);
    final (mean, mx, mn) = sample(a0, a1, rings.first, rings.last);
    if (!zoneControl) {
      final target = switch (s.rule) { VriSectorRule.areaWeighted => mean, VriSectorRule.maximum => mx, VriSectorRule.minimum => mn };
      final (p, limit) = timerFor(target);
      raw.add(VriRow(startDeg: a0, endDeg: a1, timerPct: p, depthMm: d100 * 100 / p, targetMm: target, limit: limit));
      continue;
    }
    final bankTargets = [for (var b = 0; b + 1 < rings.length; b++) sample(a0, a1, rings[b], rings[b + 1]).$1];
    final target = bankTargets.reduce(math.max);
    final (p, limit) = timerFor(target);
    final applied = d100 * 100 / p;
    raw.add(VriRow(startDeg: a0, endDeg: a1, timerPct: p, depthMm: applied, targetMm: target, bankDutyPct: [for (final t in bankTargets) 100 * (t / applied).clamp(0.0, 1.0)], limit: limit));
  }
  if (raw.any((r) => r.limit == 1)) warn('vri_below_minimum');
  if (raw.any((r) => r.limit == 2)) warn('vri_above_maximum');

  // merge neighbouring sectors with the same settings
  final rows = <VriRow>[];
  for (final r in raw) {
    final last = rows.isEmpty ? null : rows.last;
    var same = last != null && (last.timerPct - r.timerPct).abs() < 0.05 && last.limit == r.limit && last.bankDutyPct.length == r.bankDutyPct.length;
    for (var b = 0; same && b < r.bankDutyPct.length; b++) {
      if ((last!.bankDutyPct[b] - r.bankDutyPct[b]).abs() >= 0.5) same = false;
    }
    if (same) {
      final w0 = last!.endDeg - last.startDeg, w1 = r.endDeg - r.startDeg;
      rows[rows.length - 1] = VriRow(
        startDeg: last.startDeg, endDeg: r.endDeg, timerPct: last.timerPct, depthMm: last.depthMm, targetMm: (last.targetMm * w0 + r.targetMm * w1) / (w0 + w1), bankDutyPct: last.bankDutyPct, limit: last.limit,
      );
    } else {
      rows.add(r);
    }
  }
  return VriResult(rows: rows, bankEdgesM: rings, depthAt100Mm: d100, maxDepthMm: maxDepth, warnings: warnings);
}
