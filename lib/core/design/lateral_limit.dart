/// The longest lateral a block can have, computed instead of typed: how far
/// a drip tape, or a lateral pipe with emitters or sprinklers at a spacing,
/// can run from its inlet before the flow of its emitters varies more than
/// allowed — the usual design rule is 10 % of flow (Keller & Bliesner,
/// *Sprinkle and Trickle Irrigation*, 1990, chap. 15 and 23; about 20 % of
/// pressure for sprinklers, whose flow follows the square root of the
/// pressure) — over ground of a uniform slope along it, the inlet set so
/// that the mean emitter pressure is the nominal one. The emitters also
/// stay inside their pressure window (a compensating dripper or tape leaves
/// its range, a lateral pipe its rating) and the water under a velocity
/// limit. A lateral fed uphill is shorter than a level one; fed downhill it
/// is longer, up to the slope where the gain of elevation outweighs the
/// friction and the far end gets too much.
///
/// The block (B), the subdivision of a field (SUBDIV) and the automatic
/// layout (LAYOUT) offer it: the step-by-step lateral analysis of
/// `hydraulics/lateral.dart` (Wu & Gitlin) on a growing number of emitters.
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../hydraulics/friction.dart';
import '../hydraulics/lateral.dart';
import '../model/catalog.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';

/// Usual flow variation allowed along a lateral (%).
const defaultLateralFlowVariationPct = 10.0;

/// Longest lateral looked at (m).
const maxLateralRunLength = 1000.0;

/// What stopped the lateral from being longer.
enum LateralLimitBy {
  /// The emitter flows vary more than allowed.
  flowVariation,

  /// An emitter would work outside its pressure window.
  pressure,

  /// The water would flow faster than the limit in the pipe.
  velocity,

  /// Longer than [maxLateralRunLength]: practically no limit.
  maxLength,

  /// Not even one emitter works within the limits.
  none,
}

/// The longest lateral of [maxLateralRun].
class LateralRun {
  const LateralRun({
    required this.length,
    required this.emitters,
    required this.inletHeadM,
    required this.inletFlow,
    required this.flowVariationPct,
    required this.minHeadM,
    required this.maxHeadM,
    required this.maxVelocity,
    required this.limitedBy,
    required this.slopePct,
  });

  /// Length from the inlet to the last emitter (m) and its emitters.
  final double length;
  final int emitters;

  /// Inlet pressure (m) for the nominal mean, the flow it takes (m³/s), the
  /// flow variation of its emitters (%), their least and greatest pressure
  /// (m) and the fastest water (m/s).
  final double inletHeadM, inletFlow, flowVariationPct, minHeadM, maxHeadM, maxVelocity;
  final LateralLimitBy limitedBy;

  /// Slope along the lateral from its inlet (%; uphill positive).
  final double slopePct;

  static const none = LateralRun(length: 0, emitters: 0, inletHeadM: 0, inletFlow: 0, flowVariationPct: 0, minHeadM: 0, maxHeadM: 0, maxVelocity: 0, limitedBy: LateralLimitBy.none, slopePct: 0);
}

/// A drip tape as a lateral for [maxLateralRun]: its own diameter, emitter
/// spacing and law, barb loss and roughness, with the friction method and
/// water of [p].
LateralSpec tapeLateralSpec(TapeSpec tape, DesignParameters p, {double length = 100}) => LateralSpec(
  length: length,
  diameter: tape.innerDiameter,
  spacing: tape.emitterSpacingM,
  emitter: tape.emitter,
  barbK: tape.barbK,
  method: p.frictionMethod,
  hazenC: p.adjustedC(tape.hazenC),
  roughness: tape.roughnessMm / 1000,
  kinematicViscosity: p.kinematicViscosity,
);

/// A lateral pipe [pipe] with an emitter or sprinkler of law [emitter]
/// every [spacing] metres, the first [firstOffset] from the inlet (half a
/// spacing by default), with the friction method and water of [p].
LateralSpec emitterLateralSpec(EmitterCurve emitter, PipeSpec pipe, double spacing, DesignParameters p, {double? firstOffset, double length = 100}) => LateralSpec(
  length: length,
  diameter: pipe.innerDiameter,
  spacing: spacing,
  emitter: emitter,
  firstOffset: firstOffset ?? spacing / 2,
  method: p.frictionMethod,
  hazenC: p.adjustedC(pipe.hazenC),
  roughness: pipe.roughness,
  kinematicViscosity: p.kinematicViscosity,
  scobeyKs: pipe.scobeyKs,
  manningN: pipe.manningN,
);

/// The longest lateral of [spec] (its length is ignored) whose emitters, at
/// a mean pressure of [nominalHeadM], vary in flow by at most
/// [allowedFlowVariationPct] (q_max − q_min over q_max), stay within
/// [minHeadM] and [maxHeadM] when given, and keep the water under
/// [maxVelocity], laid on a uniform slope of [slopePct] from the inlet
/// (uphill positive). The lateral ends at its last emitter. The number of
/// emitters doubles until a limit is passed, then the last one that holds
/// is found by bisection (a lateral laid downhill may pass its limit only
/// past the slope's best length: the first length that fails counts).
LateralRun maxLateralRun(
  LateralSpec spec, {
  required double nominalHeadM,
  double allowedFlowVariationPct = defaultLateralFlowVariationPct,
  double slopePct = 0,
  double? minHeadM,
  double? maxHeadM,
  double maxVelocity = 3,
  double maxLength = maxLateralRunLength,
  double manufacturerCv = 0,
}) {
  if (!(spec.spacing > 0) || !(nominalHeadM > 0) || !spec.diameter.isFinite || !(spec.diameter > 0)) return LateralRun.none;
  final off = math.max(0.0, spec.firstOffset ?? spec.spacing);
  final s = slopePct.isFinite ? slopePct : 0.0;
  double z(double d) => s / 100 * d;
  double lengthOf(int n) => off + (n - 1) * spec.spacing;
  final cap = math.max(1, ((maxLength - off) / spec.spacing).floor() + 1);
  // (result, the limit it passes, or null when it holds)
  (LateralRun, LateralLimitBy?) at(int n) {
    final l = lengthOf(n);
    final r = analyzeLateralForMeanPressure(spec.copyWith(length: l), nominalHeadM, elevationAt: z, manufacturerCv: manufacturerCv);
    var qMin = double.infinity, qMax = 0.0;
    for (final p in r.points) {
      qMin = math.min(qMin, p.emitterFlow);
      qMax = math.max(qMax, p.emitterFlow);
    }
    final qVar = qMax > 0 ? 100 * (qMax - qMin) / qMax : 0.0;
    LateralLimitBy? fails;
    if ((minHeadM != null && r.minPressure < minHeadM - 1e-9) || (maxHeadM != null && r.maxPressure > maxHeadM + 1e-9) || r.minPressure <= 0) {
      fails = LateralLimitBy.pressure;
    } else if (qVar > allowedFlowVariationPct + 1e-9) {
      fails = LateralLimitBy.flowVariation;
    } else if (r.maxVelocity > maxVelocity + 1e-9) {
      fails = LateralLimitBy.velocity;
    }
    return (
      LateralRun(
        length: l,
        emitters: r.points.length,
        inletHeadM: r.inletPressure,
        inletFlow: r.inletFlow,
        flowVariationPct: qVar,
        minHeadM: r.minPressure,
        maxHeadM: r.maxPressure,
        maxVelocity: r.maxVelocity,
        limitedBy: fails ?? LateralLimitBy.maxLength,
        slopePct: s,
      ),
      fails,
    );
  }

  final one = at(1);
  if (one.$2 != null) return LateralRun.none;
  var good = 1;
  var best = one.$1;
  int? bad;
  LateralLimitBy? why;
  // doubling until a limit is passed (or the longest lateral looked at)
  for (var n = 2; n <= cap; n = math.min(cap, n * 2)) {
    final r = at(n);
    if (r.$2 != null) {
      bad = n;
      why = r.$2;
      break;
    }
    good = n;
    best = r.$1;
    if (n == cap) break;
  }
  if (bad == null) return best;
  // bisection between the last that holds and the first that fails
  while (bad - good > 1) {
    final mid = (good + bad) ~/ 2;
    final r = at(mid);
    if (r.$2 == null) {
      good = mid;
      best = r.$1;
    } else {
      bad = mid;
      why = r.$2;
    }
  }
  return LateralRun(
    length: best.length,
    emitters: best.emitters,
    inletHeadM: best.inletHeadM,
    inletFlow: best.inletFlow,
    flowVariationPct: best.flowVariationPct,
    minHeadM: best.minHeadM,
    maxHeadM: best.maxHeadM,
    maxVelocity: best.maxVelocity,
    limitedBy: why ?? LateralLimitBy.maxLength,
    slopePct: s,
  );
}

/// The two ways a row can be fed: from its low end up the slope and from
/// its high end down it (on level ground both alike).
class LateralRunsBothWays {
  const LateralRunsBothWays(this.uphill, this.downhill, this.slopePct);
  final LateralRun uphill, downhill;

  /// Slope of the ground along the rows (%, the steeper way positive).
  final double slopePct;

  /// The shorter of the two: the limit wherever the inlet is.
  LateralRun get shorter => uphill.length <= downhill.length ? uphill : downhill;
}

/// [maxLateralRun] for a lateral laid up and down a slope of [slopePct].
LateralRunsBothWays maxLateralRunsBothWays(
  LateralSpec spec, {
  required double nominalHeadM,
  double allowedFlowVariationPct = defaultLateralFlowVariationPct,
  double slopePct = 0,
  double? minHeadM,
  double? maxHeadM,
  double maxVelocity = 3,
  double maxLength = maxLateralRunLength,
}) {
  final s = slopePct.isFinite ? slopePct.abs() : 0.0;
  LateralRun run(double slope) => maxLateralRun(
    spec,
    nominalHeadM: nominalHeadM,
    allowedFlowVariationPct: allowedFlowVariationPct,
    slopePct: slope,
    minHeadM: minHeadM,
    maxHeadM: maxHeadM,
    maxVelocity: maxVelocity,
    maxLength: maxLength,
  );
  final up = run(s);
  return LateralRunsBothWays(up, s < 1e-9 ? up : run(-s), s);
}

/// Slope (%) of the ground along [direction] over [polygon], from the plane
/// fitted to the terrain at about [samples] points inside it (rising along
/// [direction] positive); null without terrain data or with too few points.
double? terrainSlopeAlong(Terrain terrain, List<Pt> polygon, Pt direction, {int samples = 400}) {
  if (terrain.isEmpty || polygon.length < 3 || direction.length == 0) return null;
  final dir = direction.normalized, across = dir.perpendicular;
  final b = Bounds.ofPoints(polygon);
  final area = polygonArea(polygon).abs();
  if (area <= 0 || b.isEmpty) return null;
  final h = math.max(math.sqrt(area / samples), 1e-3);
  // least squares z = a + bu·u + bv·v over the samples
  var n = 0.0, su = 0.0, sv = 0.0, sz = 0.0, suu = 0.0, svv = 0.0, suv = 0.0, suz = 0.0, svz = 0.0;
  final c = b.center;
  for (var y = b.minY + h / 2; y < b.maxY; y += h) {
    for (var x = b.minX + h / 2; x < b.maxX; x += h) {
      final q = Pt(x, y);
      if (!pointInPolygon(q, polygon)) continue;
      final zq = terrain.elevationAt(q, fallback: double.nan);
      if (!zq.isFinite) continue;
      final u = (q - c).dot(dir), v = (q - c).dot(across);
      n++;
      su += u;
      sv += v;
      sz += zq;
      suu += u * u;
      svv += v * v;
      suv += u * v;
      suz += u * zq;
      svz += v * zq;
    }
  }
  if (n < 3) return null;
  // centred sums: solve the 2 × 2 normal equations for the slopes
  final cuu = suu - su * su / n, cvv = svv - sv * sv / n, cuv = suv - su * sv / n;
  final cuz = suz - su * sz / n, cvz = svz - sv * sz / n;
  final det = cuu * cvv - cuv * cuv;
  if (det.abs() < 1e-12) return cuu > 1e-12 ? 100 * cuz / cuu : null;
  return 100 * (cuz * cvv - cvz * cuv) / det;
}

/// Velocity (m/s) of [flow] (m³/s) in [pipe].
double pipeVelocity(PipeSpec pipe, double flow) => velocity(flow: flow, diameter: pipe.innerDiameter);

/// Length (m) of the longest lateral of a block of rows along [direction]
/// every [spacing] metres over [polygon] (the first half a spacing in), each
/// row cut by the outline and by [exclusions]; with the submain in the
/// middle ([centre]) every row feeds two laterals of half its length.
double longestRowLength(List<Pt> polygon, Pt direction, double spacing, {List<List<Pt>> exclusions = const [], bool centre = false}) {
  if (polygon.length < 3 || !(spacing > 0) || direction.length == 0) return 0;
  final dir = direction.normalized, across = dir.perpendicular;
  var vMin = double.infinity, vMax = -double.infinity, uMin = double.infinity, uMax = -double.infinity;
  for (final q in polygon) {
    vMin = math.min(vMin, q.dot(across));
    vMax = math.max(vMax, q.dot(across));
    uMin = math.min(uMin, q.dot(dir));
    uMax = math.max(uMax, q.dot(dir));
  }
  if ((vMax - vMin) / spacing > 20000) return 0;
  var best = 0.0;
  for (var v = vMin + spacing / 2; v <= vMax + 1e-9; v += spacing) {
    final line = [dir * (uMin - 1) + across * v, dir * (uMax + 1) + across * v];
    for (final piece in clipPolylineToPolygon(line, polygon)) {
      var parts = [piece];
      for (final h in exclusions) {
        parts = [
          for (final p in parts) ..._outside(p, h),
        ];
      }
      for (final p in parts) {
        best = math.max(best, polylineLength(p));
      }
    }
  }
  return centre ? best / 2 : best;
}

/// The pieces of the two-point line [p] outside the closed shape [hole].
List<List<Pt>> _outside(List<Pt> p, List<Pt> hole) {
  if (hole.length < 3) return [p];
  final inside = clipPolylineToPolygon(p, hole);
  if (inside.isEmpty) return [p];
  final a = p.first, dir = p.last - p.first;
  final len = dir.length;
  if (len <= 0) return const [];
  final u = dir / len;
  // the stretches inside the shape, as distances along the line
  double along(Pt q) => (q - a).dot(u);
  final cuts = <(double, double)>[for (final q in inside) (math.min(along(q.first), along(q.last)), math.max(along(q.first), along(q.last)))]..sort((x, y) => x.$1.compareTo(y.$1));
  final out = <List<Pt>>[];
  var from = 0.0;
  for (final (s0, s1) in cuts) {
    if (s0 > from + 1e-9) out.add([a + u * from, a + u * s0]);
    from = math.max(from, s1);
  }
  if (len > from + 1e-9) out.add([a + u * from, p.last]);
  return out;
}

/// The smallest enabled pipe of [usage] in [cat] that carries [flow] (m³/s)
/// within [maxVelocity] (m/s), as the design sizes the first stretch of a
/// pipe; the largest when none does; null without pipes of that use.
PipeSpec? pipeForFlow(Catalog cat, PipeUsage usage, double flow, double maxVelocity) {
  final list = cat.pipesFor(usage);
  if (list.isEmpty) return null;
  for (final x in list) {
    if (pipeVelocity(x, flow) <= maxVelocity + 1e-12) return x;
  }
  return list.last;
}
