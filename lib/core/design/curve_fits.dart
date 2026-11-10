/// The curves read off a chart (lib/core/design/curve_digitiser.dart),
/// fitted the way the engine already fits a data sheet, and put into the
/// project's catalogue (1.7.0, DGZ):
///
/// - a pump's flow–head points become [PumpSpec.points], fitted by
///   [PumpCurve.fit] (the least-squares parabola when it stands for them
///   within the ISO 9906 grade 1B tolerance, else the monotone cubic through
///   them); its efficiency and NPSH required points are kept as the
///   catalogue keeps them (straight lines between the points); a shaft
///   power curve without an efficiency curve gives the efficiency
///   η = ρ·g·Q·H / P (ISO 9906's pump efficiency: the hydraulic power over
///   the shaft power) at each power point, H read on the fitted head curve;
/// - an outlet's flow–pressure points are fitted to q = k·Hˣ by
///   [EmitterCurve.fitTable] (least squares in log–log space);
/// - a sprinkler's distance–rate points become the measured radial profile
///   of a nozzle with [profileFromTable], the form the densogram reads
///   (distance over the wetted radius, rate over its largest value).
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../hydraulics/pump.dart';
import '../model/catalog.dart';
import '../units.dart';

/// [pts] with what a chart cannot mean left out: values not finite, and
/// negative ones beyond a click's error (a click on an axis can read a hair
/// below zero: within 2 % of the largest value it is taken as zero).
List<(double, double)> cleanChartPoints(List<(double, double)> pts, {bool positive = false}) {
  final fin = [
    for (final p in pts)
      if (p.$1.isFinite && p.$2.isFinite) p,
  ];
  if (fin.isEmpty) return const [];
  final mx = fin.fold(0.0, (m, p) => math.max(m, p.$1.abs()));
  final my = fin.fold(0.0, (m, p) => math.max(m, p.$2.abs()));
  double fix(double v, double top) => v < 0 && -v <= 0.02 * top ? 0 : v;
  final out = <(double, double)>[];
  for (final (x, y) in fin) {
    final a = fix(x, mx), b = fix(y, my);
    if (a < 0 || b < 0 || (positive && (a <= 0 || b <= 0))) continue;
    out.add((a, b));
  }
  return out..sort((p, q) => p.$1.compareTo(q.$1));
}

/// Fewest flow–head points a new pump takes (as edit_catalog asks).
const int minPumpHeadPoints = 3;

/// Fewest points of the other curves.
const int minCurvePoints = 2;

/// A pump's chart, fitted: every list is (Q m³/s, value) sorted by flow.
class PumpChartFit {
  PumpChartFit._(this.head, this.curve, this.headGaps, this.efficiency, this.efficiencyFromPower, this.npsh, this.power, this.rejectedEfficiency);

  /// Flow–head points (H m).
  final List<(double, double)> head;

  /// The engine's curve of [head]; null with fewer than two points.
  final PumpCurve? curve;

  /// H − H(Q) of the fitted curve at each point of [head] (m).
  final List<double> headGaps;

  /// Efficiency points (0–1): the chart's, or the ones of the power curve.
  final List<(double, double)> efficiency;
  final bool efficiencyFromPower;

  /// NPSH required points (m).
  final List<(double, double)> npsh;

  /// Shaft power points (kW).
  final List<(double, double)> power;

  /// Power points whose efficiency came out of (0, 1] (a power or head axis
  /// misread) or outside the head curve's flows, left out.
  final int rejectedEfficiency;

  /// The largest |gap| of the head points (m).
  double get maxGap => headGaps.fold(0.0, (m, g) => math.max(m, g.abs()));

  /// The root mean square of the gaps (m).
  double get rmsGap => headGaps.isEmpty ? 0 : math.sqrt(headGaps.fold(0.0, (s, g) => s + g * g) / headGaps.length);

  /// The highest head of the points (m).
  double get topHead => head.fold(0.0, (m, p) => math.max(m, p.$2));

  /// The best efficiency of the curve (0–1), or null.
  double? get bestEfficiency => efficiency.isEmpty ? null : efficiency.fold<double>(0, (m, p) => math.max(m, p.$2));

  /// The largest shaft power read (kW), or null.
  double? get maxPowerKw => power.isEmpty ? null : power.fold<double>(0, (m, p) => math.max(m, p.$2));

  /// Whether anything can go into a pump of the catalogue.
  bool get isEmpty => head.length < minCurvePoints && efficiency.length < minCurvePoints && npsh.length < minCurvePoints;
}

/// Fits a pump's chart (see the library comment); the lists are in the
/// engine's units: Q m³/s against H m, efficiency 0–1, NPSH m, power kW.
PumpChartFit fitPumpChart({List<(double, double)> head = const [], List<(double, double)> efficiency = const [], List<(double, double)> npsh = const [], List<(double, double)> power = const []}) {
  final h = cleanChartPoints(head);
  final curve = h.length >= minCurvePoints ? PumpCurve.fit(h) : null;
  final gaps = curve == null ? const <double>[] : [for (final (q, hh) in h) hh - curve.head(q)];
  var eff = [
    for (final p in cleanChartPoints(efficiency))
      if (p.$2 > 0 && p.$2 <= 1) p,
  ];
  final pw = cleanChartPoints(power);
  var fromPower = false;
  var rejected = 0;
  if (eff.length < minCurvePoints && pw.length >= minCurvePoints && curve != null) {
    final qMin = h.first.$1, qMax = h.last.$1;
    final derived = <(double, double)>[];
    for (final (q, kw) in pw) {
      if (q <= 0 || kw <= 0) continue;
      if (q < qMin - 1e-12 || q > qMax + 1e-12) {
        rejected++;
        continue;
      }
      final eta = waterDensity * gravity * q * curve.head(q) / (kw * 1000);
      if (eta > 0 && eta <= 1) {
        derived.add((q, eta));
      } else {
        rejected++;
      }
    }
    if (derived.length >= minCurvePoints) {
      eff = derived;
      fromPower = true;
    }
  }
  return PumpChartFit._(h, curve, gaps, eff, fromPower, cleanChartPoints(npsh), pw, rejected);
}

/// An outlet's chart, fitted.
class EmitterChartFit {
  EmitterChartFit._(this.points, this.fit, this.gaps);

  /// (H m, q m³/s), both above zero, sorted by head.
  final List<(double, double)> points;
  final EmitterFit fit;

  /// (q − q(H)) / q(H) of the fitted law at each point.
  final List<double> gaps;

  EmitterCurve get curve => fit.curve;
  bool get isUsable => fit.isUsable && fit.flowRows >= minCurvePoints;
  double get minHead => points.isEmpty ? 0 : points.first.$1;
  double get maxHead => points.isEmpty ? 0 : points.last.$1;
}

/// Fits an outlet's (H m, q m³/s) points to q = k·Hˣ.
EmitterChartFit fitEmitterChart(List<(double, double)> points) {
  final pts = cleanChartPoints(points, positive: true);
  final fit = EmitterCurve.fitTable([for (final (h, q) in pts) (h, q, null)]);
  final gaps = [
    for (final (h, q) in pts)
      if (fit.curve.flow(h) > 0) (q - fit.curve.flow(h)) / fit.curve.flow(h) else 0.0,
  ];
  return EmitterChartFit._(pts, fit, gaps);
}

/// A sprinkler's radial profile read off a chart.
class ProfileChartFit {
  ProfileChartFit._(this.points, this.profile);

  /// (distance m, rate mm/h), sorted by distance.
  final List<(double, double)> points;

  /// The nozzle's measured profile ([NozzleSpec.profile]), or null with
  /// fewer than two points with water.
  final List<(double, double)>? profile;

  bool get isUsable => profile != null;

  /// The wetted radius read: the farthest distance with water (m).
  double get radiusM => points.where((p) => p.$2 > 0).fold(0.0, (m, p) => math.max(m, p.$1));

  /// The largest rate (mm/h).
  double get peakRate => points.fold(0.0, (m, p) => math.max(m, p.$2));
}

/// The profile of the (distance m, rate) points.
ProfileChartFit fitProfileChart(List<(double, double)> points) {
  final pts = cleanChartPoints(points);
  return ProfileChartFit._(pts, profileFromTable(pts));
}

/// Why a curve cannot go into the catalogue.
class ChartApplyError implements Exception {
  const ChartApplyError(this.code);

  /// `pump_head` (a new pump needs [minPumpHeadPoints] flow–head points),
  /// `pump_empty`, `no_item` (the item to update is not in the catalogue),
  /// `emitter_fit` (fewer than two usable points), `profile` (fewer than
  /// two points with water).
  final String code;

  @override
  String toString() => 'ChartApplyError($code)';
}

/// Puts the pump chart [f] into [cat]: updates the pump [pumpId], or adds a
/// pump named [name]. The flow–head points replace the curve (and its range
/// of flows becomes the pump's), the efficiency and NPSH points replace
/// those of the pump (the single efficiency becomes the best one); the
/// largest shaft power read becomes the pump's rated power when the pump
/// has none (the motor's own rating is not on the chart). Throws
/// [ChartApplyError].
PumpSpec putPumpChart(Catalog cat, PumpChartFit f, {String? pumpId, String name = ''}) {
  if (f.isEmpty) throw const ChartApplyError('pump_empty');
  PumpSpec spec;
  if (pumpId != null) {
    final found = cat.pump(pumpId);
    if (found == null) throw const ChartApplyError('no_item');
    spec = found;
    if (name.trim().isNotEmpty) spec.name = name.trim();
  } else {
    if (f.head.length < minPumpHeadPoints) throw const ChartApplyError('pump_head');
    spec = PumpSpec(id: cat.newId('pump'), name: name.trim().isEmpty ? 'Pump' : name.trim(), points: f.head);
    cat.pumps.add(spec);
  }
  if (f.head.length >= minCurvePoints) {
    spec.points = [...f.head];
    spec.refit();
    spec.minFlow = f.head.first.$1;
    spec.maxFlow = f.head.last.$1;
  }
  if (f.efficiency.length >= minCurvePoints) {
    spec.efficiencyPoints = [...f.efficiency];
    spec.efficiency = f.bestEfficiency!;
  }
  if (f.npsh.length >= minCurvePoints) spec.npshPoints = [...f.npsh];
  final kw = f.maxPowerKw;
  if (kw != null && kw > 0 && spec.powerKw <= 0) spec.powerKw = kw;
  return spec;
}

/// Adds an outlet named [name] of [kind] with one nozzle of the fitted law
/// [f]: its range of pressures is the chart's, its default pressure the
/// middle of it. Throws [ChartApplyError].
OutletSpec putNewOutlet(Catalog cat, EmitterChartFit f, {required String name, OutletKind kind = OutletKind.dripper, String nozzleName = ''}) {
  if (!f.isUsable) throw const ChartApplyError('emitter_fit');
  final id = cat.newId('out');
  final mid = (f.minHead + f.maxHead) / 2;
  final o = OutletSpec(
    id: id,
    name: name.trim().isEmpty ? id : name.trim(),
    kind: kind,
    nozzles: [
      NozzleSpec(
        id: '${id}_n1',
        name: nozzleName.trim().isEmpty ? name.trim() : nozzleName.trim(),
        curve: EmitterCurve(k: f.curve.k, x: f.curve.x),
        minHeadM: f.minHead,
        maxHeadM: f.maxHead,
        defaultHeadM: mid,
      ),
    ],
  );
  cat.outlets.add(o);
  return o;
}

/// The fitted law [f] on nozzle [n]: k and x change, its wetted radius and
/// compensation start stay. Throws [ChartApplyError].
void putNozzleCurve(NozzleSpec n, EmitterChartFit f) {
  if (!f.isUsable) throw const ChartApplyError('emitter_fit');
  n.curve = EmitterCurve(k: f.curve.k, x: f.curve.x, radiusA: n.curve.radiusA, radiusB: n.curve.radiusB, compensationHead: n.curve.compensationHead);
}

/// The fitted law [f] as the emitter of drip tape [tp] (its compensation
/// start stays). Throws [ChartApplyError].
void putTapeEmitter(TapeSpec tp, EmitterChartFit f) {
  if (!f.isUsable) throw const ChartApplyError('emitter_fit');
  tp.emitter = EmitterCurve(k: f.curve.k, x: f.curve.x, compensationHead: tp.emitter.compensationHead);
}

/// The profile [f] as the measured profile of nozzle [n]. Throws
/// [ChartApplyError].
void putNozzleProfile(NozzleSpec n, ProfileChartFit f) {
  final p = f.profile;
  if (p == null) throw const ChartApplyError('profile');
  n.profile = p;
}
