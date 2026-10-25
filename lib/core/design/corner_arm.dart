/// Corner arm (swing arm) of a centre pivot: a rigid span hinged at the last
/// regular tower whose tip follows a guidance path (a buried wire laid along
/// the field boundary offset inwards), so the machine swings out into the
/// corners of a square field and folds back along the sides.
///
/// Model (geometric, after the description of corner systems in Keller &
/// Bliesner 1990, ch. 16, and NRCS NEH 623 ch. 11):
/// * the hinge H(θ) = C + R0·(cos θ, sin θ) turns with the machine at a
///   constant angular speed; the tip T is the point of the path at the arm
///   length Lc from H on the trailing side, |T − H| = Lc, with the arm angle
///   φ (0 = in line with the machine, positive trailing) limited to φmax;
///   where the path is beyond reach the arm stays straight (shortfall), where
///   it is closer than the folded arm reaches the arm stays at φmax (overrun);
/// * the area the arm adds is the area between the hinge circle and the
///   trajectory of the arm end (tip + overhang + throw of the last
///   sprinkler, taken along the arm), assumed star-shaped around the pivot
///   point, which holds for convex guide paths;
/// * uniform depth: a stretch of arm must deliver q = κ·dA/dθ, with dA/dθ the
///   area it sweeps per radian of machine rotation (only forward motion
///   counts) and κ = 2π·d/T_rev the machine's gross depth per revolution
///   time times 2π — the same rule that gives the main machine
///   q = Q·(b₂² − b₁²)/R² (Heermann & Hein 1968);
/// * the arm's sprinklers form banks sized for the straight arm,
///   q_bank = κ·((R0 + s₁)² − (R0 + s₀)²)/2, switched on in sequence as the
///   arm extends: a bank is on when the flow it should deliver reaches the
///   switching threshold (default half) of its design flow; the duty ratio
///   is also reported for packages that pulse their banks.
/// Simplifications: level ground, rigid arm, the tip exactly on the path,
/// constant machine speed (the speed limits of the arm drive are not
/// modelled, only the tip speed ratio is reported), the throw of the last
/// sprinkler continues the arm line, the path is a closed polygon around the
/// pivot point.
library;

import 'dart:math' as math;

import '../model/geometry.dart';

/// Guidance path for a corner arm: the closed field [boundary] offset
/// inwards by [offsetM] (mitred corners, either orientation). The edges must
/// be longer than the offset.
List<Pt> guidancePathFromBoundary(List<Pt> boundary, double offsetM) {
  final pts = [...boundary];
  if (pts.length > 1 && pts.first.distanceTo(pts.last) < 1e-9) pts.removeLast();
  if (pts.length < 3) return pts;
  final ccw = polygonArea(pts) > 0;
  final n = pts.length;
  Pt inward(int i) {
    final d = (pts[(i + 1) % n] - pts[i]).normalized;
    return ccw ? d.perpendicular : -d.perpendicular;
  }

  final out = <Pt>[];
  for (var i = 0; i < n; i++) {
    final prev = (i - 1 + n) % n;
    final n1 = inward(prev), n2 = inward(i);
    final a1 = pts[prev] + n1 * offsetM, b1 = pts[i] + n1 * offsetM;
    final a2 = pts[i] + n2 * offsetM, b2 = pts[(i + 1) % n] + n2 * offsetM;
    out.add(lineIntersection(a1, b1, a2, b2) ?? pts[i] + n2 * offsetM);
  }
  return out;
}

/// Largest tip speed over the hinge tower speed an arm drive follows; a
/// faster tip means the arm jumped across the guide path.
const cornerArmMaxTipSpeed = 5.0;

/// What the arm does at a machine position.
enum CornerArmState {
  /// The tip follows the path.
  tracking,

  /// The path is beyond reach: the arm is straight and the tip falls short.
  extended,

  /// The path is closer than the folded arm reaches: the arm is at its maximum angle.
  folded,
}

/// Corner arm data for [analyzeCornerArm]. All values in SI.
class CornerArmSpec {
  const CornerArmSpec({
    required this.center,
    required this.hingeRadiusM,
    required this.armLengthM,
    required this.guidePath,
    this.armOverhangM = 0,
    this.tipThrowM = 0,
    this.maxArmAngleDeg = 120,
    this.clockwise = false,
    this.startDeg = 0,
    this.sweepDeg = 360,
    this.stepDeg = 0.5,
    this.bankCount = 4,
    this.bankEdgesM = const [],
    this.grossDepthMm = 0,
    this.hoursPerRev = 0,
    this.mainFlow = 0,
    this.mainRadiusM = 0,
    this.switchThreshold = 0.5,
    this.referenceRadiusM = 0,
  });

  /// Pivot point.
  final Pt center;

  /// Distance from the pivot point to the hinge at the last regular tower (m).
  final double hingeRadiusM;

  /// Arm length from the hinge to the guided tip (m).
  final double armLengthM;

  /// Closed guidance path (world coordinates) around the pivot point.
  final List<Pt> guidePath;

  /// Pipe beyond the tip and throw of the last sprinkler (m).
  final double armOverhangM;
  final double tipThrowM;

  /// Largest arm angle when folded back (degrees from the machine line).
  final double maxArmAngleDeg;

  /// Direction of travel (false = counter-clockwise, the drawing's positive angles).
  final bool clockwise;

  /// First machine azimuth (degrees, counter-clockwise from +x), angle swept
  /// and step of the computation (degrees).
  final double startDeg;
  final double sweepDeg;
  final double stepDeg;

  /// Sprinkler banks along the arm: [bankCount] equal banks over the arm
  /// reach, or the bank boundaries (m from the hinge, increasing, the last at
  /// the reach) in [bankEdgesM].
  final int bankCount;
  final List<double> bankEdgesM;

  /// Gross depth per revolution (mm) and hours per revolution of the
  /// machine; when absent the rate comes from [mainFlow] over [mainRadiusM].
  final double grossDepthMm;
  final double hoursPerRev;

  /// Flow of the main machine (m³/s) and the radius it waters (m; 0 = the hinge radius).
  final double mainFlow;
  final double mainRadiusM;

  /// A bank switches on when its required flow reaches this fraction of its design flow.
  final double switchThreshold;

  /// Radius of the circle the machine would water without the arm (m),
  /// for the added area; 0 = hinge radius plus the tip throw.
  final double referenceRadiusM;

  /// Length of arm that waters: arm, overhang and throw (m).
  double get reachM => math.max(armLengthM, 0.0) + math.max(armOverhangM, 0.0) + math.max(tipThrowM, 0.0);

  /// Radius watered by the main machine (m).
  double get mainRadius => mainRadiusM > 0 ? mainRadiusM : hingeRadiusM;

  /// Gross application rate of the machine averaged over a revolution (m/s): depth / revolution time.
  double get applicationRate {
    if (grossDepthMm > 0 && hoursPerRev > 0) return grossDepthMm / 1000 / (hoursPerRev * 3600);
    final r = mainRadius;
    return mainFlow > 0 && r > 0 ? mainFlow / (math.pi * r * r) : 0;
  }

  /// Bank boundaries from the hinge (m), starting at 0 and ending at the reach.
  List<double> bankEdges() {
    final reach = reachM;
    if (bankEdgesM.isNotEmpty) {
      final inner = [for (final e in [...bankEdgesM]..sort()) if (e > 1e-9 && e < reach - 1e-9) e];
      return [0, ...inner, reach];
    }
    final n = math.max(1, bankCount);
    return [for (var i = 0; i <= n; i++) reach * i / n];
  }
}

/// The arm at one machine position.
class CornerArmStep {
  const CornerArmStep({required this.pivotDeg, required this.armDeg, required this.tipRadiusM, required this.tipAzimuthDeg, required this.banksOn, required this.armFlow, required this.pulsedFlow, required this.totalFlow, this.state = CornerArmState.tracking});

  /// Machine azimuth (degrees counter-clockwise from +x, within 0–360).
  final double pivotDeg;

  /// Arm angle φ (degrees; 0 = in line, positive = trailing).
  final double armDeg;

  /// Distance of the tip from the pivot point (m) and its azimuth (degrees, within 0–360).
  final double tipRadiusM;
  final double tipAzimuthDeg;

  /// Banks switched on (bit i = bank i, bank 0 at the hinge).
  final int banksOn;

  /// Flow of the arm with the banks on (m³/s), with pulsed banks (duty-weighted) and the machine total with on/off banks.
  final double armFlow;
  final double pulsedFlow;
  final double totalFlow;
  final CornerArmState state;

  int get banksOnCount {
    var n = 0;
    for (var b = banksOn; b != 0; b >>= 1) {
      n += b & 1;
    }
    return n;
  }

  Map<String, dynamic> toJson() => {'th': pivotDeg, 'phi': armDeg, 'rt': tipRadiusM, 'at': tipAzimuthDeg, 'on': banksOn, 'qa': armFlow, 'qp': pulsedFlow, 'qt': totalFlow, if (state != CornerArmState.tracking) 'st': state.name};
  static CornerArmStep fromJson(Map<String, dynamic> j) => CornerArmStep(
    pivotDeg: (j['th'] as num).toDouble(), armDeg: (j['phi'] as num).toDouble(), tipRadiusM: (j['rt'] as num).toDouble(), tipAzimuthDeg: (j['at'] as num).toDouble(), banksOn: (j['on'] as num).toInt(),
    armFlow: (j['qa'] as num).toDouble(), pulsedFlow: (j['qp'] as num).toDouble(), totalFlow: (j['qt'] as num).toDouble(), state: CornerArmState.values.byName(j['st'] as String? ?? 'tracking'),
  );
}

/// One sprinkler bank of the arm.
class CornerArmBank {
  const CornerArmBank({required this.index, required this.startM, required this.endM, required this.designFlow, required this.onFraction});

  /// 0-based bank index from the hinge, its span along the arm (m from the hinge).
  final int index;
  final double startM;
  final double endM;

  /// Flow of the bank sized for the straight arm (m³/s).
  final double designFlow;

  /// Fraction of the revolution the bank is on.
  final double onFraction;

  Map<String, dynamic> toJson() => {'i': index, 's0': startM, 's1': endM, 'q': designFlow, 'on': onFraction};
  static CornerArmBank fromJson(Map<String, dynamic> j) =>
      CornerArmBank(index: (j['i'] as num).toInt(), startM: (j['s0'] as num).toDouble(), endM: (j['s1'] as num).toDouble(), designFlow: (j['q'] as num).toDouble(), onFraction: (j['on'] as num).toDouble());
}

/// Kinematics, coverage and flows of a corner arm.
class CornerArmResult {
  CornerArmResult({
    required this.steps,
    required this.banks,
    required this.outline,
    required this.totalAreaM2,
    required this.armAreaM2,
    required this.addedAreaM2,
    required this.mainFlow,
    required this.peakFlow,
    required this.peakPulsedFlow,
    required this.minFlow,
    required this.maxTipSpeedRatio,
    required this.maxShortfallM,
    required this.maxOverrunM,
    required this.warnings,
  });

  final List<CornerArmStep> steps;
  final List<CornerArmBank> banks;

  /// Outer edge of the watered area (trajectory of the arm end, world coordinates).
  final List<Pt> outline;

  /// Area inside the outline, area watered by the arm (beyond the hinge
  /// circle) and area added over the reference circle (m²).
  final double totalAreaM2;
  final double armAreaM2;
  final double addedAreaM2;

  /// Main machine flow, peak and minimum total flow with on/off banks, and
  /// the peak with pulsed banks (m³/s): the peak sets the pump and mainline.
  final double mainFlow;
  final double peakFlow;
  final double peakPulsedFlow;
  final double minFlow;

  /// Largest ground speed of the tip over the speed of the hinge tower.
  final double maxTipSpeedRatio;

  /// Largest gap between the straight arm and an unreachable path, and the
  /// largest distance the folded tip runs off the path (m).
  final double maxShortfallM;
  final double maxOverrunM;

  /// Message codes (`corner_arm_*`, with `:<id>` when an id was given).
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'steps': steps.map((e) => e.toJson()).toList(), 'banks': banks.map((e) => e.toJson()).toList(), 'outline': outline.map((p) => p.toList()).toList(), 'at': totalAreaM2, 'aa': armAreaM2, 'ad': addedAreaM2,
    'qm': mainFlow, 'qpk': peakFlow, 'qpp': peakPulsedFlow, 'qmin': minFlow, 'vr': maxTipSpeedRatio, 'short': maxShortfallM, 'over': maxOverrunM, 'warn': warnings,
  };
  static CornerArmResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return CornerArmResult(
      steps: ((j['steps'] as List?) ?? const []).map((e) => CornerArmStep.fromJson(e as Map<String, dynamic>)).toList(),
      banks: ((j['banks'] as List?) ?? const []).map((e) => CornerArmBank.fromJson(e as Map<String, dynamic>)).toList(),
      outline: ((j['outline'] as List?) ?? const []).map((p) => Pt.fromList(p as List)).toList(), totalAreaM2: d('at'), armAreaM2: d('aa'), addedAreaM2: d('ad'), mainFlow: d('qm'), peakFlow: d('qpk'),
      peakPulsedFlow: d('qpp'), minFlow: d('qmin'), maxTipSpeedRatio: d('vr'), maxShortfallM: d('short'), maxOverrunM: d('over'), warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Points where the circle of centre [h] and radius [radius] crosses the closed polyline [path].
List<Pt> _circleCrossings(Pt h, double radius, List<Pt> path) {
  final out = <Pt>[];
  for (var i = 0; i < path.length; i++) {
    final a = path[i], b = path[(i + 1) % path.length];
    final d = b - a, f = a - h;
    final qa = d.dot(d), qb = 2 * f.dot(d), qc = f.dot(f) - radius * radius;
    final disc = qb * qb - 4 * qa * qc;
    if (qa < 1e-12 || disc < 0) continue;
    final sq = math.sqrt(disc);
    for (final t in [(-qb - sq) / (2 * qa), (-qb + sq) / (2 * qa)]) {
      if (t >= -1e-9 && t <= 1 + 1e-9) out.add(a + d * t);
    }
  }
  return out;
}

/// Angle (radians) in degrees within [0, 360).
double _deg360(double rad) {
  final d = radToDeg(rad) % 360;
  return d < 0 ? d + 360 : d;
}

double _distanceToPath(Pt p, List<Pt> path) {
  var best = double.infinity;
  for (var i = 0; i < path.length; i++) {
    best = math.min(best, distanceToSegment(p, path[i], path[(i + 1) % path.length]));
  }
  return best;
}

/// Arm angle, tip, coverage, bank sequence and flow versus machine angle of a corner arm.
CornerArmResult analyzeCornerArm(CornerArmSpec s, {String id = ''}) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  final path = [...s.guidePath];
  if (path.length > 1 && path.first.distanceTo(path.last) < 1e-9) path.removeLast();
  final r0 = s.hingeRadiusM, lc = s.armLengthM;
  final kappa = 2 * math.pi * s.applicationRate;
  final mainFlow = s.mainFlow > 0 ? s.mainFlow : s.applicationRate * math.pi * s.mainRadius * s.mainRadius;
  if (path.length < 3 || r0 <= 0 || lc <= 0 || !pointInPolygon(s.center, path)) {
    warn('corner_arm_no_path');
    return CornerArmResult(steps: const [], banks: const [], outline: const [], totalAreaM2: 0, armAreaM2: 0, addedAreaM2: 0, mainFlow: mainFlow, peakFlow: mainFlow, peakPulsedFlow: mainFlow, minFlow: mainFlow, maxTipSpeedRatio: 0, maxShortfallM: 0, maxOverrunM: 0, warnings: warnings);
  }
  if (kappa <= 0) warn('corner_arm_no_rate');
  final dir = s.clockwise ? -1.0 : 1.0;
  final sweep = degToRad(s.sweepDeg.clamp(1.0, 360.0));
  final full = sweep >= 2 * math.pi - 1e-9;
  final steps = math.max(4, (sweep / degToRad(s.stepDeg.clamp(0.05, 10.0))).ceil());
  final dTheta = sweep / steps;
  final phiMax = degToRad(s.maxArmAngleDeg.clamp(0.0, 179.0));
  final reach = s.reachM;

  // arm position at every step
  final hinges = <Pt>[], arms = <Pt>[], phis = <double>[], states = <CornerArmState>[];
  var maxShort = 0.0, maxOver = 0.0;
  double? prevPhi;
  for (var k = 0; k <= steps; k++) {
    final theta = degToRad(s.startDeg) + dir * k * dTheta;
    final u = Pt.polar(1, theta);
    final h = s.center + u * r0;
    double? phi;
    for (final t in _circleCrossings(h, lc, path)) {
      final w = (t - h) / lc;
      final f = -dir * math.atan2(u.cross(w), u.dot(w));
      if (f < -1e-9 || f > phiMax + 1e-9) continue;
      if (phi == null || (prevPhi == null ? f < phi : (f - prevPhi).abs() < (phi - prevPhi).abs())) phi = f;
    }
    var state = CornerArmState.tracking;
    if (phi == null) {
      final straight = h + u * lc;
      if (pointInPolygon(straight, path)) {
        phi = 0;
        state = CornerArmState.extended;
        maxShort = math.max(maxShort, _distanceToPath(straight, path));
      } else {
        phi = phiMax;
        state = CornerArmState.folded;
        maxOver = math.max(maxOver, _distanceToPath(h + u.rotate(-dir * phiMax) * lc, path));
      }
    }
    phi = math.max(0.0, phi);
    hinges.add(h);
    arms.add(u.rotate(-dir * phi));
    phis.add(phi);
    states.add(state);
    prevPhi = phi;
  }
  if (maxShort > 0.5) warn('corner_arm_short');
  if (maxOver > 0.5) warn('corner_arm_overrun');

  // banks: design flow for the straight arm; required flow from the area swept per step
  final edges = s.bankEdges();
  final nb = edges.length - 1;
  double ring2(double sArm) => (r0 + sArm) * (r0 + sArm);
  final design = [for (var b = 0; b < nb; b++) kappa * (ring2(edges[b + 1]) - ring2(edges[b])) / 2];
  const samples = 6;
  final onCount = List<int>.filled(nb, 0);
  final rows = <CornerArmStep>[];
  var peak = 0.0, peakPulsed = 0.0, minFlow = double.infinity, maxSpeed = 0.0;
  for (var k = 0; k <= steps; k++) {
    // the interval after the step (the last step reuses the one before)
    final a = k < steps ? k : k - 1, b = a + 1;
    final wMid = (arms[a] + arms[b]).normalized;
    final forward = dir > 0 ? wMid.perpendicular : -wMid.perpendicular;
    var mask = 0;
    var armFlow = 0.0, pulsed = 0.0;
    for (var bank = 0; bank < nb; bank++) {
      final s0 = edges[bank], s1 = edges[bank + 1], ds = (s1 - s0) / samples;
      var swept = 0.0;
      for (var m = 0; m < samples; m++) {
        final sm = s0 + (m + 0.5) * ds;
        final move = (hinges[b] + arms[b] * sm) - (hinges[a] + arms[a] * sm);
        swept += math.max(0.0, move.dot(forward)) * ds;
      }
      final required = kappa * swept / dTheta;
      final duty = design[bank] > 0 ? required / design[bank] : 0.0;
      pulsed += design[bank] * duty.clamp(0.0, 1.0);
      if (design[bank] > 0 && duty >= s.switchThreshold - 1e-9) {
        mask |= 1 << bank;
        armFlow += design[bank];
        onCount[bank]++;
      }
    }
    final tip = hinges[k] + arms[k] * lc;
    if (k < steps) maxSpeed = math.max(maxSpeed, (hinges[b] + arms[b] * lc).distanceTo(hinges[a] + arms[a] * lc) / (r0 * dTheta));
    final total = mainFlow + armFlow;
    peak = math.max(peak, total);
    peakPulsed = math.max(peakPulsed, mainFlow + pulsed);
    minFlow = math.min(minFlow, total);
    rows.add(CornerArmStep(
      pivotDeg: _deg360(degToRad(s.startDeg) + dir * k * dTheta), armDeg: radToDeg(phis[k]), tipRadiusM: tip.distanceTo(s.center), tipAzimuthDeg: _deg360((tip - s.center).angle), banksOn: mask,
      armFlow: armFlow, pulsedFlow: pulsed, totalFlow: total, state: states[k],
    ));
  }

  // coverage: trajectory of the arm end
  final outline = [for (var k = 0; k <= (full ? steps - 1 : steps); k++) hinges[k] + arms[k] * reach];
  final ring = full ? outline : [s.center, ...outline];
  final total = polygonArea(ring).abs();
  final frac = sweep / (2 * math.pi);
  final armArea = math.max(0.0, total - math.pi * r0 * r0 * frac);
  final ref = s.referenceRadiusM > 0 ? s.referenceRadiusM : r0 + math.max(s.tipThrowM, 0.0);
  final added = total - math.pi * ref * ref * frac;
  final banks = [for (var b = 0; b < nb; b++) CornerArmBank(index: b, startM: edges[b], endM: edges[b + 1], designFlow: design[b], onFraction: onCount[b] / (steps + 1))];
  // the tip runs far faster than the hinge tower: the arm jumped between
  // two branches of the guide (folded and extended) instead of following it
  if (maxSpeed > cornerArmMaxTipSpeed) warn('corner_arm_jump');
  return CornerArmResult(
    steps: rows, banks: banks, outline: outline, totalAreaM2: total, armAreaM2: armArea, addedAreaM2: added, mainFlow: mainFlow, peakFlow: peak, peakPulsedFlow: peakPulsed,
    minFlow: minFlow.isFinite ? minFlow : mainFlow, maxTipSpeedRatio: maxSpeed, maxShortfallM: maxShort, maxOverrunM: maxOver, warnings: warnings,
  );
}
