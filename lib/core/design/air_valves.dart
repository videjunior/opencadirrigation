/// Air valve locations and sizes along a pipeline profile, following the
/// practice of AWWA Manual M51, *Air-Release, Air/Vacuum, and Combination
/// Air Valves*:
///
/// - high points of the pipe (and of the pipe against the hydraulic grade
///   line): combination valves;
/// - increases in downward slope: air/vacuum (or combination) valves, which
///   admit air when the line drains; decreases in upward slope: air-release
///   (or combination) valves, where air collects in operation;
/// - long ascents, descents and horizontal runs: a valve at least every
///   400–800 m (1/4 to 1/2 mile);
/// - the discharge of a pump (air/vacuum) and downstream of check valves;
/// - the end of the line;
/// - points where the steady grade line comes close to the pipe, and where a
///   transient minimum envelope drops below atmospheric pressure (vacuum
///   protection).
///
/// Sizing (M51 procedure): the large orifice of an air/vacuum or
/// combination valve passes the air that replaces the largest drainage flow
/// with the inside pressure below atmospheric by an allowable differential,
/// and exhausts the air displaced by the filling flow with an allowable
/// differential above it, by the isentropic orifice flow of
/// [airOrificeMassFlow] (Wylie & Streeter 1993). The drainage flow is the
/// pipe flowing full by gravity on the slope that drains away from the valve
/// (Hazen-Williams); the filling flow defaults to 0.3 m/s (1 ft/s), the
/// filling rate M51 recommends. The small orifice of an air-release valve
/// releases the air carried by the water, 2 % of the flow by volume (the
/// usual M51 assumption), at the operating pressure.
///
/// Units are SI: lengths and heads m, flows m³/s, pressures Pa.
library;

import 'dart:math' as math;

import '../hydraulics/transient.dart' show airGasConstant, airOrificeMassFlow;
import '../model/geometry.dart';
import '../units.dart';

/// Air valve types (AWWA M51).
enum AirValveType {
  /// Small orifice: releases air pockets while the line is under pressure.
  airRelease,

  /// Large orifice: exhausts air while filling, admits air while draining.
  airVacuum,

  /// Both orifices.
  combination,
}

/// Why a valve is suggested, in priority order.
enum AirValveReason {
  highPoint('high_point'),
  lineEnd('line_end'),
  pumpDischarge('pump_discharge'),
  checkValve('downstream_check_valve'),
  transientVacuum('transient_vacuum'),
  hglClose('hgl_close'),
  steeperDescent('steeper_descent'),
  flatterAscent('flatter_ascent'),
  longAscent('long_ascent'),
  longDescent('long_descent'),
  longHorizontal('long_horizontal');

  const AirValveReason(this.code);

  /// Code for the interface (`air_valve_<code>`).
  final String code;
}

/// A point of the profile.
class ProfilePoint {
  const ProfilePoint({required this.chainage, required this.pipe, double? ground, this.hgl, this.minHgl, this.position, this.diameter}) : ground = ground ?? pipe;

  /// Distance along the line (m).
  final double chainage;

  /// Pipe (centreline) and ground elevations (m).
  final double pipe;
  final double ground;

  /// Steady hydraulic grade line and the minimum of a transient envelope (m).
  final double? hgl;
  final double? minHgl;

  /// Plan position, interpolated into the suggestions.
  final Pt? position;

  /// Inner diameter (m) of the pipe from this point to the next (a
  /// telescoped line); null = [PipelineProfile.diameter].
  final double? diameter;
}

/// A pipeline: its profile, bore and flows.
class PipelineProfile {
  const PipelineProfile({
    required this.points,
    required this.diameter,
    this.hazenC = 140,
    this.designFlow = 0,
    this.fillFlow,
    this.drainFlow,
    this.pumpDischarges = const [],
    this.checkValves = const [],
  });

  /// Points in any order (sorted by chainage).
  final List<ProfilePoint> points;

  /// Inner diameter (m) where the points give none, and Hazen-Williams C,
  /// for the drainage and filling flows.
  final double diameter;
  final double hazenC;

  /// Operating flow (m³/s), for the air released by air-release valves.
  final double designFlow;

  /// Filling flow and largest drainage flow (m³/s); null = a 0.3 m/s fill
  /// and the gravity drainage on the slopes.
  final double? fillFlow;
  final double? drainFlow;

  /// Chainages of pump discharges and of check valves.
  final List<double> pumpDischarges;
  final List<double> checkValves;
}

/// Placement and sizing settings.
class AirValveOptions {
  const AirValveOptions({
    this.minSpacing = 400,
    this.maxSpacing = 800,
    this.flatSlope = 0.0005,
    this.slopeChange = 0.005,
    this.minRelief = 0.1,
    this.hglClearance = 2,
    this.transientVacuumLimit = 0,
    this.mergeDistance = 20,
    this.checkValveOffset = 1,
    this.inflowDifferential = 34474,
    this.exhaustDifferential = 13790,
    this.dischargeCoefficient = 0.6,
    this.airContent = 0.02,
    this.fillVelocity = 0.3,
    this.barometricHead = 10.33,
    this.temperature = 293.15,
    this.preferCombination = true,
  });

  /// Interval between valves on long runs (m): M51 gives 1/4 to 1/2 mile.
  /// Gaps longer than [maxSpacing] are split into equal parts, which stay
  /// above [minSpacing] while it is at most half of [maxSpacing].
  final double minSpacing;
  final double maxSpacing;

  /// Slopes below this (m/m) count as horizontal.
  final double flatSlope;

  /// Change of slope (m/m) that counts at a vertex.
  final double slopeChange;

  /// Smallest rise and fall (m) around a high point.
  final double minRelief;

  /// Pressure head (m) under which the grade line is "close to the pipe".
  final double hglClearance;

  /// Transient minimum pressure head (m, gauge) under which air/vacuum
  /// protection is suggested.
  final double transientVacuumLimit;

  /// Suggestions closer than this (m) are merged.
  final double mergeDistance;

  /// Distance (m) of the valve downstream of a check valve.
  final double checkValveOffset;

  /// Allowable pressure differentials of the large orifice (Pa): 5 psi
  /// (34.5 kPa) below atmospheric admitting air and 2 psi (13.8 kPa) above it
  /// exhausting air, the values M51 sizing usually takes.
  final double inflowDifferential;
  final double exhaustDifferential;

  /// Discharge coefficient of the orifices.
  final double dischargeCoefficient;

  /// Air carried by the water, by volume at atmospheric pressure.
  final double airContent;

  /// Filling velocity (m/s) when no filling flow is given.
  final double fillVelocity;

  /// Atmospheric pressure head (m) and air temperature (K).
  final double barometricHead;
  final double temperature;

  /// Combination valves where M51 accepts either type; false takes the
  /// single-function valve (air release on ascents, air/vacuum on descents).
  final bool preferCombination;
}

/// Size of a suggested valve.
class AirValveSizing {
  const AirValveSizing({required this.largeOrifice, required this.smallOrifice, required this.nominalSize, required this.drainFlow, required this.fillFlow, required this.releaseAirFlow});

  /// Diameter (m) of the air/vacuum orifice (0 for an air-release valve).
  final double largeOrifice;

  /// Diameter (m) of the air-release orifice (0 for an air/vacuum valve or
  /// without a design flow).
  final double smallOrifice;

  /// Standard inlet size (m) of the valve.
  final double nominalSize;

  /// Water flows (m³/s) the large orifice is sized for: drainage and filling.
  final double drainFlow;
  final double fillFlow;

  /// Free air (m³/s at atmospheric conditions) the small orifice releases.
  final double releaseAirFlow;
}

/// A suggested air valve.
class AirValveSuggestion {
  const AirValveSuggestion({required this.chainage, required this.pipe, required this.ground, required this.type, required this.reasons, required this.sizing, this.position});
  final double chainage;
  final double pipe;
  final double ground;
  final Pt? position;
  final AirValveType type;

  /// Every reason, the main one first.
  final List<AirValveReason> reasons;
  final AirValveSizing sizing;
  AirValveReason get reason => reasons.first;

  /// `air_valve_<reason>` of the main reason.
  String get code => 'air_valve_${reason.code}';
}

/// Result of [suggestAirValves].
class AirValvePlan {
  const AirValvePlan(this.suggestions, this.messages);

  /// Sorted by chainage.
  final List<AirValveSuggestion> suggestions;

  /// `air_hgl_below_pipe:<chainage>` where the steady grade line runs below
  /// the pipe (negative pressure: a hydraulic problem air valves do not
  /// solve); `air_profile_too_short` with fewer than two points.
  final List<String> messages;
}

// ---------------------------------------------------------------- sizing

double _pa(double barometricHead) => waterDensity * gravity * barometricHead;

double _diameter(double area) => area > 0 ? math.sqrt(4 * area / math.pi) : 0;

/// Diameter (m) of the orifice that admits the air replacing [waterFlow]
/// (m³/s) drained from the pipe with the inside pressure [differential] Pa
/// below atmospheric: ṁ = ρ_air(p)·Q through Cd·A at the isentropic orifice
/// flow from the atmosphere to p (Wylie & Streeter 1993; AWWA M51).
double airInflowOrificeDiameter({required double waterFlow, required double differential, double cd = 0.6, double barometricHead = 10.33, double temperature = 293.15}) {
  if (!(waterFlow > 0)) return 0;
  final pa = _pa(barometricHead);
  final p = math.max(pa - math.max(differential, 1.0), 0.05 * pa);
  final mdot = p / (airGasConstant * temperature) * waterFlow;
  final perArea = airOrificeMassFlow(cdArea: 1, upstream: pa, downstream: p, temperature: temperature);
  return _diameter(mdot / (cd * perArea));
}

/// Diameter (m) of the orifice that exhausts the air displaced by the
/// filling flow [waterFlow] (m³/s) with the inside pressure [differential]
/// Pa above atmospheric (isentropic orifice flow from p to the atmosphere).
double airExhaustOrificeDiameter({required double waterFlow, required double differential, double cd = 0.6, double barometricHead = 10.33, double temperature = 293.15}) {
  if (!(waterFlow > 0)) return 0;
  final pa = _pa(barometricHead);
  final p = pa + math.max(differential, 1.0);
  final mdot = p / (airGasConstant * temperature) * waterFlow;
  final perArea = airOrificeMassFlow(cdArea: 1, upstream: p, downstream: pa, temperature: temperature);
  return _diameter(mdot / (cd * perArea));
}

/// Diameter (m) of an air-release orifice that releases the air carried by
/// [waterFlow] (m³/s), [airContent] by volume at atmospheric pressure, at the
/// pressure head [pressureHead] (m) of the line (AWWA M51: about 2 %).
double airReleaseOrificeDiameter({required double waterFlow, required double pressureHead, double airContent = 0.02, double cd = 0.6, double barometricHead = 10.33, double temperature = 293.15}) {
  if (!(waterFlow > 0) || !(airContent > 0)) return 0;
  final pa = _pa(barometricHead);
  final p = pa + waterDensity * gravity * math.max(pressureHead, 0.1);
  final mdot = pa / (airGasConstant * temperature) * airContent * waterFlow;
  final perArea = airOrificeMassFlow(cdArea: 1, upstream: p, downstream: pa, temperature: temperature);
  return _diameter(mdot / (cd * perArea));
}

/// Flow (m³/s) of a pipe of [diameter] running full by gravity down
/// [slope] (m/m): the Hazen-Williams loss equal to the slope,
/// Q = (S·C^1.852·D^4.871/10.67)^(1/1.852) (≈ 0.278·C·D^2.63·S^0.54).
double gravityDrainageFlow({required double diameter, required double slope, double hazenC = 140}) {
  if (!(slope > 0) || !(diameter > 0)) return 0;
  return math.pow(slope * math.pow(hazenC, 1.852) * math.pow(diameter, 4.871) / 10.67, 1 / 1.852).toDouble();
}

/// Standard inlet sizes (m) of air/vacuum and combination valves, and of
/// air-release valves.
const airValveSizes = [0.025, 0.05, 0.08, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6];
const airReleaseSizes = [0.0125, 0.02, 0.025, 0.05];

double _nominal(double d, List<double> sizes) {
  for (final s in sizes) {
    if (s >= d - 1e-9) return s;
  }
  return (d / 0.1).ceil() * 0.1;
}

// ---------------------------------------------------------------- placement

class _Candidate {
  _Candidate(this.x, this.type, this.reason);
  double x;
  AirValveType type;
  final List<AirValveReason> reasons = [];
  AirValveReason reason;
}

/// Suggested air valves for [profile] (AWWA M51 practice; see the library
/// documentation).
AirValvePlan suggestAirValves(PipelineProfile profile, {AirValveOptions options = const AirValveOptions()}) {
  final o = options;
  final messages = <String>[];
  final pts = [...profile.points]..sort((a, b) => a.chainage.compareTo(b.chainage));
  final p = <ProfilePoint>[];
  for (final q in pts) {
    if (p.isNotEmpty && q.chainage - p.last.chainage < 1e-6) continue;
    p.add(q);
  }
  if (p.length < 2) return AirValvePlan(const [], const ['air_profile_too_short']);
  final n = p.length;
  final x0 = p.first.chainage, x1 = p.last.chainage;
  final slope = [for (var i = 0; i < n - 1; i++) (p[i + 1].pipe - p[i].pipe) / (p[i + 1].chainage - p[i].chainage)];
  int cls(double s) => s > o.flatSlope ? 1 : (s < -o.flatSlope ? -1 : 0);
  final cands = <_Candidate>[];
  void add(double x, AirValveType t, AirValveReason r) => cands.add(_Candidate(x.clamp(x0, x1), t, r)..reasons.add(r));
  final ascentType = o.preferCombination ? AirValveType.combination : AirValveType.airRelease;
  final descentType = o.preferCombination ? AirValveType.combination : AirValveType.airVacuum;

  // runs of segments with the same class: (class, first segment, last segment)
  final runs = <(int, int, int)>[];
  for (var i = 0; i < n - 1; i++) {
    final c = cls(slope[i]);
    if (runs.isNotEmpty && runs.last.$1 == c) {
      runs[runs.length - 1] = (c, runs.last.$2, i);
    } else {
      runs.add((c, i, i));
    }
  }
  double zAt(int i) => p[i].pipe;

  // high points: an ascent followed by a descent, maybe through a flat top
  for (var k = 0; k < runs.length; k++) {
    if (runs[k].$1 != 1) continue;
    var j = k + 1;
    if (j < runs.length && runs[j].$1 == 0) j++;
    if (j >= runs.length || runs[j].$1 != -1) continue;
    final up = runs[k], down = runs[j];
    final rise = zAt(up.$3 + 1) - zAt(up.$2);
    final fall = zAt(down.$2) - zAt(down.$3 + 1);
    if (rise < o.minRelief || fall < o.minRelief) continue;
    final a = p[up.$3 + 1].chainage, b = p[down.$2].chainage;
    if (b - a > o.mergeDistance) {
      // a flat top: at both of its ends
      add(a, AirValveType.combination, AirValveReason.highPoint);
      add(b, AirValveType.combination, AirValveReason.highPoint);
    } else {
      add(0.5 * (a + b), AirValveType.combination, AirValveReason.highPoint);
    }
  }

  // changes of slope inside ascents and descents
  for (var i = 1; i < n - 1; i++) {
    final s0 = slope[i - 1], s1 = slope[i];
    final c0 = cls(s0), c1 = cls(s1);
    if (c0 >= 0 && c1 >= 0 && (c0 == 1 || c1 == 1) && s0 - s1 >= o.slopeChange) {
      // flatter going up (also up → flat): air collects
      add(p[i].chainage, ascentType, AirValveReason.flatterAscent);
    } else if (c0 <= 0 && c1 <= 0 && (c0 == -1 || c1 == -1) && s0 - s1 >= o.slopeChange) {
      // steeper going down (also flat → down): vacuum when draining
      add(p[i].chainage, descentType, AirValveReason.steeperDescent);
    }
  }

  // pumps, check valves, the end of the line
  for (final c in profile.pumpDischarges) {
    add(c, AirValveType.airVacuum, AirValveReason.pumpDischarge);
  }
  for (final c in profile.checkValves) {
    add(c + o.checkValveOffset, AirValveType.combination, AirValveReason.checkValve);
  }
  add(x1, AirValveType.combination, AirValveReason.lineEnd);

  // grade lines: steady close to the pipe, transient below atmospheric
  final hgl = [for (final q in p) q.hgl];
  if (hgl.every((h) => h != null)) {
    final pr = [for (var i = 0; i < n; i++) hgl[i]! - p[i].pipe];
    for (var i = 0; i < n; i++) {
      final isMin = (i == 0 || pr[i] <= pr[i - 1]) && (i == n - 1 || pr[i] < pr[i + 1]);
      if (!isMin) continue;
      if (pr[i] < 0) {
        messages.add('air_hgl_below_pipe:${p[i].chainage.toStringAsFixed(1)}');
      } else if (pr[i] < o.hglClearance) {
        add(p[i].chainage, ascentType, AirValveReason.hglClose);
      }
    }
  }
  final minH = [for (final q in p) q.minHgl];
  if (minH.every((h) => h != null)) {
    final pr = [for (var i = 0; i < n; i++) minH[i]! - p[i].pipe];
    for (var i = 0; i < n; i++) {
      final isMin = (i == 0 || pr[i] <= pr[i - 1]) && (i == n - 1 || pr[i] < pr[i + 1]);
      if (isMin && pr[i] < o.transientVacuumLimit) add(p[i].chainage, AirValveType.airVacuum, AirValveReason.transientVacuum);
    }
  }

  // long runs: no gap between valves (or the run ends) above the interval
  for (final (c, a, b) in runs) {
    final xa = p[a].chainage, xb = p[b + 1].chainage;
    if (xb - xa <= o.maxSpacing) continue;
    final anchors = <double>[
      xa,
      for (final q in cands)
        if (q.x > xa + 1e-9 && q.x < xb - 1e-9) q.x,
      xb,
    ]..sort();
    final reason = c == 1 ? AirValveReason.longAscent : (c == -1 ? AirValveReason.longDescent : AirValveReason.longHorizontal);
    final type = c == -1 ? descentType : (o.preferCombination ? AirValveType.combination : AirValveType.airRelease);
    for (var i = 1; i < anchors.length; i++) {
      final gap = anchors[i] - anchors[i - 1];
      if (gap <= o.maxSpacing + 1e-9) continue;
      final k = (gap / o.maxSpacing - 1e-9).ceil() - 1;
      for (var j = 1; j <= k; j++) {
        add(anchors[i - 1] + gap * j / (k + 1), type, reason);
      }
    }
  }

  // merge close suggestions: the main reason's place, combined function
  cands.sort((a, b) => a.x.compareTo(b.x));
  final merged = <_Candidate>[];
  for (final c in cands) {
    final last = merged.isEmpty ? null : merged.last;
    if (last != null && c.x - last.x <= o.mergeDistance) {
      if (c.reason.index < last.reason.index) {
        last.x = c.x;
        last.reason = c.reason;
      }
      for (final r in c.reasons) {
        if (!last.reasons.contains(r)) last.reasons.add(r);
      }
      if (last.type != c.type) last.type = AirValveType.combination;
      continue;
    }
    merged.add(c);
  }

  final out = <AirValveSuggestion>[];
  for (final c in merged) {
    c.reasons.sort((a, b) => a.index.compareTo(b.index));
    final (pipe, ground, hglAt, pos) = _interpolate(p, c.x);
    final sizing = _size(profile, o, p, slope, c.x, c.type, hglAt == null ? null : hglAt - pipe);
    out.add(AirValveSuggestion(chainage: c.x, pipe: pipe, ground: ground, position: pos, type: c.type, reasons: List.unmodifiable(c.reasons), sizing: sizing));
  }
  return AirValvePlan(out, messages);
}

(double, double, double?, Pt?) _interpolate(List<ProfilePoint> p, double x) {
  var i = 0;
  while (i < p.length - 2 && p[i + 1].chainage < x) {
    i++;
  }
  final a = p[i], b = p[i + 1];
  final w = ((x - a.chainage) / (b.chainage - a.chainage)).clamp(0.0, 1.0);
  final ha = a.hgl, hb = b.hgl;
  final pa = a.position, pb = b.position;
  return (a.pipe + (b.pipe - a.pipe) * w, a.ground + (b.ground - a.ground) * w, ha != null && hb != null ? ha + (hb - ha) * w : null, pa != null && pb != null ? pa + (pb - pa) * w : null);
}

/// Sizes a valve at chainage [x]: drainage by gravity on the slopes that
/// fall away from it (or the profile's drain flow), filling flow, and the
/// released air at the local pressure ([pressure] null = 10 m).
AirValveSizing _size(PipelineProfile profile, AirValveOptions o, List<ProfilePoint> p, List<double> slope, double x, AirValveType type, double? pressure) {
  final large = type != AirValveType.airRelease;
  final small = type != AirValveType.airVacuum;
  // the segments on each side (slope and bore); at a vertex the two neighbours
  int? left, right;
  for (var i = 0; i < slope.length; i++) {
    final a = p[i].chainage, b = p[i + 1].chainage;
    if (b <= x + 1e-9 && b >= x - 1e-9) left = i;
    if (a <= x + 1e-9 && a >= x - 1e-9) right = i;
    if (a < x - 1e-9 && b > x + 1e-9) {
      left = i;
      right = i;
    }
  }
  double bore(int? i) => i == null ? 0 : (p[i].diameter ?? profile.diameter);
  final d = math.max(bore(left), bore(right)) > 0 ? math.max(bore(left), bore(right)) : profile.diameter;
  var drain = profile.drainFlow ?? 0.0;
  if (profile.drainFlow == null) {
    // the left side drains away when it rises towards the valve, the right
    // side when it falls from it
    if (left != null && slope[left] > 0) drain += gravityDrainageFlow(diameter: bore(left), slope: slope[left], hazenC: profile.hazenC);
    if (right != null && slope[right] < 0) drain += gravityDrainageFlow(diameter: bore(right), slope: -slope[right], hazenC: profile.hazenC);
  }
  final fill = profile.fillFlow ?? o.fillVelocity * math.pi * d * d / 4;
  var dLarge = 0.0;
  if (large) {
    final dIn = airInflowOrificeDiameter(waterFlow: drain, differential: o.inflowDifferential, cd: o.dischargeCoefficient, barometricHead: o.barometricHead, temperature: o.temperature);
    final dOut = airExhaustOrificeDiameter(waterFlow: fill, differential: o.exhaustDifferential, cd: o.dischargeCoefficient, barometricHead: o.barometricHead, temperature: o.temperature);
    dLarge = math.max(dIn, dOut);
  }
  var dSmall = 0.0, release = 0.0;
  if (small && profile.designFlow > 0) {
    release = o.airContent * profile.designFlow;
    dSmall = airReleaseOrificeDiameter(
      waterFlow: profile.designFlow,
      pressureHead: pressure ?? 10,
      airContent: o.airContent,
      cd: o.dischargeCoefficient,
      barometricHead: o.barometricHead,
      temperature: o.temperature,
    );
  }
  final nominal = large ? _nominal(dLarge, airValveSizes) : _nominal(dSmall, airReleaseSizes);
  return AirValveSizing(largeOrifice: dLarge, smallOrifice: dSmall, nominalSize: nominal, drainFlow: large ? drain : 0, fillFlow: large ? fill : 0, releaseAirFlow: release);
}
