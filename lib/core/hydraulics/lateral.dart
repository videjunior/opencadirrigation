/// Step-by-step analysis of a multi-outlet lateral (sprayline or drip tape),
/// following Wu & Gitlin (1975) / Keller & Bliesner (1990).
library;

import 'dart:math' as math;

import 'emitter.dart';
import 'friction.dart';
import 'minor_losses.dart';
import 'uniformity.dart';

typedef ElevationAt = double Function(double distanceFromInlet);

class LateralSpec {
  const LateralSpec({
    required this.length,
    required this.diameter,
    required this.spacing,
    required this.emitter,
    this.firstOffset,
    this.emittersPerOutlet = 1,
    this.barbK = 0,
    this.method = FrictionMethod.hazenWilliams,
    this.hazenC = 140,
    this.roughness = 1.5e-6,
    this.kinematicViscosity = 1.004e-6,
    this.endFlow = 0,
  });

  final double length;
  final double diameter;
  final double spacing;
  final EmitterCurve emitter;

  /// Distance from inlet to the first outlet (defaults to [spacing]).
  final double? firstOffset;
  final int emittersPerOutlet;

  /// Local loss coefficient per outlet connection (barb), velocity-head form.
  final double barbK;
  final FrictionMethod method;
  final double hazenC;
  final double roughness;
  final double kinematicViscosity;

  /// Extra flow leaving the distal end (flushing) in m³/s.
  final double endFlow;

  int get outletCount {
    final off = firstOffset ?? spacing;
    if (!off.isFinite || off < 0 || length < off) return 0;
    if (!(spacing > 0)) return 1;
    return ((length - off) / spacing).floor() + 1;
  }

  LateralSpec copyWith({double? length, double? diameter, double? spacing, double? endFlow}) => LateralSpec(
    length: length ?? this.length,
    diameter: diameter ?? this.diameter,
    spacing: spacing ?? this.spacing,
    emitter: emitter,
    firstOffset: firstOffset,
    emittersPerOutlet: emittersPerOutlet,
    barbK: barbK,
    method: method,
    hazenC: hazenC,
    roughness: roughness,
    kinematicViscosity: kinematicViscosity,
    endFlow: endFlow ?? this.endFlow,
  );
}

class LateralPoint {
  const LateralPoint({required this.distance, required this.elevation, required this.pressure, required this.flowIn, required this.emitterFlow});
  final double distance;
  final double elevation;
  final double pressure;

  /// Flow in the pipe just upstream of this outlet.
  final double flowIn;
  final double emitterFlow;
}

class LateralResult {
  const LateralResult({
    required this.inletPressure,
    required this.endPressure,
    required this.inletFlow,
    required this.frictionLoss,
    required this.minPressure,
    required this.maxPressure,
    required this.minPressureDistance,
    required this.maxPressureDistance,
    required this.points,
    required this.uniformity,
    required this.maxVelocity,
  });
  final double inletPressure;
  final double endPressure;
  final double inletFlow;
  final double frictionLoss;
  final double minPressure;
  final double maxPressure;
  final double minPressureDistance;
  final double maxPressureDistance;
  final List<LateralPoint> points;
  final UniformityStats uniformity;
  final double maxVelocity;

  double get meanPressure => points.isEmpty ? 0 : points.fold<double>(0, (s, p) => s + p.pressure) / points.length;
  double get pressureVariationPct => maxPressure > 0 ? 100 * (maxPressure - minPressure) / maxPressure : 0;
}

/// Analyses a lateral working upstream from a known distal-end pressure.
LateralResult analyzeLateralFromEnd(
  LateralSpec spec,
  double endPressure, {
  ElevationAt? elevationAt,
  double manufacturerCv = 0,
}) {
  final n = spec.outletCount;
  final z = elevationAt ?? (_) => 0.0;
  final off = spec.firstOffset ?? spec.spacing;
  final positions = List<double>.generate(n, (i) => off + i * spec.spacing);
  final pts = <LateralPoint>[];
  var flow = spec.endFlow;
  var totalHead = endPressure + z(spec.length);
  var loss = 0.0;
  var maxV = 0.0;
  // Segment from distal end to last outlet.
  var prevPos = spec.length;
  for (var i = n - 1; i >= 0; i--) {
    final pos = positions[i];
    final segLen = prevPos - pos;
    if (segLen > 0 && flow > 0) {
      final hf = frictionLoss(
        method: spec.method,
        flow: flow,
        diameter: spec.diameter,
        length: segLen,
        c: spec.hazenC,
        roughness: spec.roughness,
        kinematicViscosity: spec.kinematicViscosity,
      );
      totalHead += hf;
      loss += hf;
      maxV = math.max(maxV, velocity(flow: flow, diameter: spec.diameter));
    }
    final elev = z(pos);
    final p = totalHead - elev;
    final qe = spec.emitter.flow(math.max(p, 0)) * spec.emittersPerOutlet;
    // barb loss applies to flow passing the outlet
    if (spec.barbK > 0 && flow > 0) {
      final hb = minorLoss(k: spec.barbK, flow: flow, diameter: spec.diameter);
      totalHead += hb;
      loss += hb;
    }
    flow += qe;
    pts.add(LateralPoint(distance: pos, elevation: elev, pressure: p, flowIn: flow, emitterFlow: qe));
    prevPos = pos;
  }
  // inlet segment
  if (prevPos > 0 && flow > 0) {
    final hf = frictionLoss(
      method: spec.method,
      flow: flow,
      diameter: spec.diameter,
      length: prevPos,
      c: spec.hazenC,
      roughness: spec.roughness,
      kinematicViscosity: spec.kinematicViscosity,
    );
    totalHead += hf;
    loss += hf;
    maxV = math.max(maxV, velocity(flow: flow, diameter: spec.diameter));
  }
  final inletPressure = totalHead - z(0);
  final ordered = pts.reversed.toList();
  var minP = double.infinity, maxP = -double.infinity, minD = 0.0, maxD = 0.0;
  for (final p in ordered) {
    if (p.pressure < minP) {
      minP = p.pressure;
      minD = p.distance;
    }
    if (p.pressure > maxP) {
      maxP = p.pressure;
      maxD = p.distance;
    }
  }
  if (ordered.isEmpty) {
    minP = maxP = inletPressure;
  }
  final stats = UniformityStats.compute(
    ordered.map((p) => p.emitterFlow).toList(),
    manufacturerCv: manufacturerCv,
    emittersPerPlant: spec.emittersPerOutlet,
  );
  return LateralResult(
    inletPressure: inletPressure,
    endPressure: endPressure,
    inletFlow: flow,
    frictionLoss: loss,
    minPressure: minP,
    maxPressure: maxP,
    minPressureDistance: minD,
    maxPressureDistance: maxD,
    points: ordered,
    uniformity: stats,
    maxVelocity: maxV,
  );
}

/// Analyses a lateral for a known inlet pressure (iterates on the end pressure).
LateralResult analyzeLateralFromInlet(
  LateralSpec spec,
  double inletPressure, {
  ElevationAt? elevationAt,
  double manufacturerCv = 0,
}) {
  var lo = 0.0;
  var hi = math.max(inletPressure * 2, 1.0);
  final z = elevationAt ?? (_) => 0.0;
  // Elevation gain can make end pressure exceed inlet pressure.
  final dz = z(0) - z(spec.length);
  if (dz > 0) hi += dz * 2;
  LateralResult res = analyzeLateralFromEnd(spec, hi, elevationAt: elevationAt, manufacturerCv: manufacturerCv);
  var it = 0;
  while (res.inletPressure < inletPressure && it < 40) {
    hi *= 2;
    res = analyzeLateralFromEnd(spec, hi, elevationAt: elevationAt, manufacturerCv: manufacturerCv);
    it++;
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    res = analyzeLateralFromEnd(spec, mid, elevationAt: elevationAt, manufacturerCv: manufacturerCv);
    if (res.inletPressure > inletPressure) {
      hi = mid;
    } else {
      lo = mid;
    }
    if ((hi - lo) < 1e-6) break;
  }
  return res;
}

/// Finds the inlet pressure that makes the mean emitter pressure equal to
/// [targetMeanPressure] (design condition used to set the valve pressure).
LateralResult analyzeLateralForMeanPressure(
  LateralSpec spec,
  double targetMeanPressure, {
  ElevationAt? elevationAt,
  double manufacturerCv = 0,
}) {
  var lo = 0.0, hi = math.max(targetMeanPressure * 3, 1.0);
  LateralResult res = analyzeLateralFromEnd(spec, hi, elevationAt: elevationAt, manufacturerCv: manufacturerCv);
  var it = 0;
  while (res.meanPressure < targetMeanPressure && it < 40) {
    hi *= 2;
    res = analyzeLateralFromEnd(spec, hi, elevationAt: elevationAt, manufacturerCv: manufacturerCv);
    it++;
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    res = analyzeLateralFromEnd(spec, mid, elevationAt: elevationAt, manufacturerCv: manufacturerCv);
    if (res.meanPressure > targetMeanPressure) {
      hi = mid;
    } else {
      lo = mid;
    }
    if ((hi - lo) < 1e-6) break;
  }
  return res;
}

/// Maximum lateral length (multiple of spacing) such that the pressure
/// variation stays within [minPressure, maxPressure] when the mean emitter
/// pressure equals [nominalPressure]. Returns the length in metres.
double maxLateralLength(
  LateralSpec spec, {
  required double nominalPressure,
  required double minPressure,
  required double maxPressure,
  ElevationAt? elevationAt,
  double maxVelocity = 3.0,
  double maxLength = 1000,
}) {
  bool ok(double length) {
    final s = spec.copyWith(length: length);
    if (s.outletCount < 1) return true;
    final r = analyzeLateralForMeanPressure(s, nominalPressure, elevationAt: elevationAt);
    return r.minPressure >= minPressure - 1e-9 && r.maxPressure <= maxPressure + 1e-9 && r.maxVelocity <= maxVelocity;
  }

  if (!(spec.spacing > 0)) return 0;
  var lo = spec.spacing;
  var hi = maxLength;
  if (!ok(lo)) return 0;
  if (ok(hi)) return hi;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (ok(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
    if (hi - lo < spec.spacing / 4) break;
  }
  final n = ((lo - (spec.firstOffset ?? spec.spacing)) / spec.spacing).floor() + 1;
  return (spec.firstOffset ?? spec.spacing) + (n - 1) * spec.spacing;
}

class FeedPositionResult {
  const FeedPositionResult({required this.fraction, required this.ok, required this.minPressure, required this.maxPressure, required this.inletPressure, required this.variation});
  final double fraction;
  final bool ok;
  final double minPressure;
  final double maxPressure;
  final double inletPressure;
  final double variation;
}

/// Evaluates feeding a lateral of total length L at a fraction f of its
/// length (0 = one end, 0.5 = centre). Both branches share the inlet pressure,
/// chosen so that the overall mean pressure equals [nominalPressure].
/// Returns the acceptable range of feed positions and the optimum.
List<FeedPositionResult> allowableFeedPositions(
  LateralSpec spec, {
  required double nominalPressure,
  required double minPressure,
  required double maxPressure,
  ElevationAt? elevationAt,
  int steps = 21,
}) {
  final z = elevationAt ?? (_) => 0.0;
  final out = <FeedPositionResult>[];
  for (var s = 0; s < steps; s++) {
    final frac = s / (steps - 1);
    final feed = frac * spec.length;
    final lenA = feed; // branch running back towards the start
    final lenB = spec.length - feed;
    final specA = spec.copyWith(length: lenA);
    final specB = spec.copyWith(length: lenB);
    double zA(double d) => z(feed - d);
    double zB(double d) => z(feed + d);
    // bisection on inlet pressure so that combined mean = nominal
    double meanFor(double inlet, {List<LateralResult>? keep}) {
      var sum = 0.0;
      var cnt = 0;
      for (final (sp, ze) in [(specA, zA), (specB, zB)]) {
        if (sp.outletCount < 1) continue;
        final r = analyzeLateralFromInlet(sp, inlet, elevationAt: ze);
        keep?.add(r);
        sum += r.meanPressure * r.points.length;
        cnt += r.points.length;
      }
      return cnt == 0 ? inlet : sum / cnt;
    }

    // a long or thin lateral may need far more than 3× the nominal pressure
    // at its inlet: widen the bracket (it used to stop at 3×, leaving the
    // mean pressure below nominal without saying so)
    var lo = 0.0, hi = nominalPressure * 3;
    for (var k = 0; k < 30 && meanFor(hi) < nominalPressure; k++) {
      lo = hi;
      hi *= 2;
    }
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (meanFor(mid) > nominalPressure) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    final inlet = (lo + hi) / 2;
    final results = <LateralResult>[];
    meanFor(inlet, keep: results);
    var mn = double.infinity, mx = -double.infinity;
    for (final r in results) {
      mn = math.min(mn, r.minPressure);
      mx = math.max(mx, r.maxPressure);
    }
    if (results.isEmpty) {
      mn = mx = inlet;
    }
    out.add(FeedPositionResult(
      fraction: frac,
      ok: mn >= minPressure && mx <= maxPressure,
      minPressure: mn,
      maxPressure: mx,
      inletPressure: inlet,
      variation: mx - mn,
    ));
  }
  return out;
}
