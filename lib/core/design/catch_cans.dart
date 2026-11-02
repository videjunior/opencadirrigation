/// The water the sprinklers lay on the ground in one irrigation, and the
/// evaluation of the uniformity in the field (1.6.0, PRD-28):
/// - the depth densogram: every sprinkler's rate (densogram.dart) times
///   the hours its zone runs in one event of the controller programme
///   (the system flow it belongs to, agronomy.dart), summed over the
///   zones: the depth (mm) each spot gets, what a catch can measures;
/// - virtual catch cans on a grid over an area: the depth and the volume
///   each can would hold (for laying out a field test and checking it);
/// - a field evaluation: the volumes read in the cans after a test of one
///   zone (or the emitter flows measured in a drip zone) give the
///   Christiansen uniformity CU, the low-quarter distribution uniformity
///   DU (ASABE S436.1 for sprinklers; Merriam & Keller 1978 for the field
///   emission uniformity of drip, the low-quarter mean over the mean) and
///   the statistical uniformity, set against the design's (the same cans
///   on the rate map of the zone, or the zone's design flows).
library;

import 'dart:math' as math;

import '../hydraulics/uniformity.dart';
import '../model/agronomy_plan.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'agronomy.dart';
import 'densogram.dart';
import 'network_builder.dart';
import 'results.dart';
import 'valve_in_head.dart';

/// Hours of one event of every sprinkler entity: the run time per event of
/// the system flow its zone belongs to in the programme of the design
/// month (or [month]); an entity of no flow runs 0 h.
Map<String, double> eventHoursByEntity(Project p, DesignResults? results, {int? month}) {
  final prog = buildControllerProgram(p, results, days: 1, month: month);
  final model = NetworkBuilder(p).build();
  final vih = VihStations.of(p);
  final flows = p.systemFlows.isNotEmpty
      ? {for (final f in p.systemFlows) f.id: f.valveIds}
      : {
          'auto': {...model.zoneNodes.keys, ...vih.heads.keys},
        };
  final out = <String, double>{};
  for (final e in flows.entries) {
    final h = prog.perFlowHours[e.key] ?? 0.0;
    if (h <= 0) continue;
    for (final v in e.value) {
      // the heads of a valve-in-head station run with it
      for (final head in vih.heads[v] ?? const <String>[]) {
        out[head] = math.max(out[head] ?? 0.0, h);
      }
      for (final nid in model.zoneNodes[v] ?? const <String>{}) {
        for (final em in model.nodes[nid]?.emitters ?? const <EmitterRef>[]) {
          out[em.entityId] = math.max(out[em.entityId] ?? 0.0, h);
        }
      }
    }
  }
  return out;
}

/// The depth densogram of one event of the programme ([base] options for
/// the profile, cell, wind and pressures).
Densogram depthDensogram(Project p, DesignResults? results, {DensogramOptions? base, int? month}) {
  final b = base ?? DensogramOptions();
  final o = DensogramOptions(
    cellSize: b.cellSize,
    profile: b.profile,
    useResults: b.useResults,
    valveIds: b.valveIds,
    maxCells: b.maxCells,
    useMeasured: b.useMeasured,
    windSpeed: b.windSpeed,
    windTowardsDeg: b.windTowardsDeg,
    windDrift: b.windDrift,
    depthHours: eventHoursByEntity(p, results, month: month),
  );
  return computeDensogram(p, results: results, options: o);
}

/// Area of the mouth of a can [mouthMm] wide (mm²).
double canMouthAreaMm2(double mouthMm) => math.pi * mouthMm * mouthMm / 4;

/// Depth (mm) of [volumeMl] millilitres caught by a can [mouthMm] wide.
double canDepthMm(double volumeMl, double mouthMm) => volumeMl * 1000 / canMouthAreaMm2(mouthMm);

/// Volume (mL) a can [mouthMm] wide holds for [depthMm].
double canVolumeMl(double depthMm, double mouthMm) => depthMm * canMouthAreaMm2(mouthMm) / 1000;

/// A grid of cans over [polygon]: every [dx] × [dy] metres along the
/// direction [angleDeg] from the lower corner of the polygon's box in that
/// direction, half a spacing in from it; the cans outside the polygon are
/// left out ([FieldTest] layout with the first can at [FieldTest.origin]).
FieldTest canGridOver(List<Pt> polygon, {required String id, double dx = 3, double dy = 3, double angleDeg = 0, double mouthMm = 100, double hours = 1, String zoneId = '', String areaId = ''}) {
  final rad = angleDeg * math.pi / 180;
  final local = [for (final q in polygon) q.rotate(-rad)];
  final b = Bounds.ofPoints(local);
  final cols = math.max(1, ((b.width - dx / 2) / dx).floor() + 1);
  final rows = math.max(1, ((b.height - dy / 2) / dy).floor() + 1);
  final origin = Pt(b.minX + dx / 2, b.minY + dy / 2).rotate(rad);
  final t = FieldTest(id: id, zoneId: zoneId, areaId: areaId, canMouthMm: mouthMm, durationH: hours, spacingXM: dx, spacingYM: dy, origin: origin, angleDeg: angleDeg, cols: cols);
  // a can outside the polygon has no value (null) and is not read
  for (var k = 0; k < rows * cols; k++) {
    t.values.add(pointInPolygon(t.position(k), polygon) ? 0 : null);
  }
  return t;
}

/// Uniformity of a set of depths or flows.
class FieldStats {
  const FieldStats({required this.count, required this.mean, required this.min, required this.max, required this.cu, required this.du, required this.us});
  static const empty = FieldStats(count: 0, mean: 0, min: 0, max: 0, cu: 0, du: 0, us: 0);
  final int count;
  final double mean, min, max;

  /// Christiansen CU, low-quarter DU and statistical uniformity (%).
  final double cu, du, us;

  static FieldStats of(Iterable<double> values) {
    final v = [
      for (final x in values)
        if (x.isFinite && x >= 0) x,
    ];
    if (v.isEmpty) return empty;
    final u = UniformityStats.compute(v);
    return FieldStats(count: u.count, mean: u.mean, min: u.min, max: u.max, cu: u.cu, du: u.du, us: u.us);
  }
}

/// A field evaluation set against the design.
class FieldEvaluation {
  const FieldEvaluation({
    required this.test,
    required this.measured,
    required this.measuredStats,
    required this.predicted,
    required this.predictedStats,
    required this.meanRateMmH,
    required this.designMean,
  });
  final FieldTest test;

  /// The values read as depths (mm, cans) or flows (L/h, emitters), slot by
  /// slot (null where there is none).
  final List<double?> measured;
  final FieldStats measuredStats;

  /// What the design gives in the same slots (cans: the rate map of the
  /// zone times the test hours; emitters: none, see [designMean]).
  final List<double?> predicted;
  final FieldStats predictedStats;

  /// Mean application rate of the test (mm/h, cans; 0 for emitters).
  final double meanRateMmH;

  /// Design mean: depth of the cans (mm) or the zone's mean emitter flow
  /// (L/h); 0 when unknown.
  final double designMean;

  /// Measured mean over the design mean (1 = as designed).
  double get meanRatio => designMean > 0 ? measuredStats.mean / designMean : 0;
}

/// Evaluates [test] of [p] against the design (the zone's sprinklers at the
/// pressures of [results] when given).
FieldEvaluation evaluateFieldTest(Project p, FieldTest test, {DesignResults? results}) {
  if (test.kind == FieldTestKind.emitters) {
    final flows = [for (final v in test.values) v];
    final z = results?.zones[test.zoneId];
    var mean = 0.0;
    if (z != null) {
      var q = 0.0, n = 0;
      for (final o in z.outlets) {
        q += o.flow * o.count;
        n += o.count;
      }
      if (n > 0) mean = q / n * 3.6e6;
    }
    return FieldEvaluation(
      test: test,
      measured: flows,
      measuredStats: FieldStats.of(flows.whereType<double>()),
      predicted: const [],
      predictedStats: FieldStats.empty,
      meanRateMmH: 0,
      designMean: mean,
    );
  }
  final depths = [for (final v in test.values) v == null ? null : canDepthMm(v, test.canMouthMm)];
  final map = computeDensogram(
    p,
    results: results,
    options: DensogramOptions(valveIds: test.zoneId.isEmpty ? null : {test.zoneId}),
  );
  final predicted = <double?>[
    for (var k = 0; k < test.values.length; k++)
      if (test.values[k] == null) null else (map.isEmpty ? 0.0 : map.rateAt(test.position(k)) * test.durationH),
  ];
  final ms = FieldStats.of(depths.whereType<double>());
  final ps = FieldStats.of([
    for (var k = 0; k < predicted.length; k++)
      if (depths[k] != null && predicted[k] != null) predicted[k]!,
  ]);
  return FieldEvaluation(
    test: test,
    measured: depths,
    measuredStats: ms,
    predicted: predicted,
    predictedStats: ps,
    meanRateMmH: test.durationH > 0 ? ms.mean / test.durationH : 0,
    designMean: ps.mean,
  );
}

/// Values pasted or typed as text: numbers split by line breaks, tabs,
/// semicolons or spaces (a decimal comma is read as a point when no
/// semicolon or tab separates the values); `-`, `x` or an empty cell is a
/// missing can.
List<double?> parseFieldValues(String text) {
  final out = <double?>[];
  final commaDecimal = text.contains(';') || text.contains('\t') || !RegExp(r'\d,\d{3}(?!\d)').hasMatch(text);
  for (final line in text.split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    for (final raw in line.split(RegExp(r'[;\t ]+'))) {
      final cell = raw.trim();
      if (cell.isEmpty) continue;
      if (cell == '-' || cell.toLowerCase() == 'x') {
        out.add(null);
        continue;
      }
      final v = double.tryParse(commaDecimal ? cell.replaceAll(',', '.') : cell.replaceAll(',', ''));
      out.add(v != null && v.isFinite && v >= 0 ? v : null);
    }
  }
  return out;
}
