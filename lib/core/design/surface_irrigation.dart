/// Surface irrigation: furrows, borders and level basins, evaluated and
/// designed with the volume-balance model of Walker & Skogerboe (1987) as
/// set out in FAO Irrigation and Drainage Paper 45 (Walker 1989), with the
/// revised NRCS intake families of NEH 623 ch. 4 as default soils.
///
/// * Infiltration: Kostiakov-Lewis z = k·τ^a + f0·τ (FAO 45 eq. 15), z per
///   metre of length — per furrow for furrows (m³/m), per metre of width
///   for borders and basins (a depth, m). Furrow intake scales with the
///   wetted perimeter: K and F0 times WP/WP_ref (NEH 623 ch. 4, eqs. 4-76
///   to 4-78).
/// * Flow section: A·R^(2/3) = ρ1·A^ρ2 from the power laws A = σ1·y^σ2 and
///   WP = γ1·y^γ2, ρ2 = 5/3 − (2/3)·γ2/σ2 and ρ1 = σ1^(5/3−ρ2)/γ1^(2/3)
///   (FAO 45 eqs. 40–45); wide sheet flow (borders, basins) ρ1 = 1,
///   ρ2 = 5/3. Inlet flow area by Manning at normal depth,
///   A0 = (Q0·n/(ρ1·√S0))^(1/ρ2) (eq. 48), or on level fields with the
///   friction slope y0/x (eq. 60, generalised to the furrow power laws).
/// * Advance: volume balance Q0·t = σy·A0·x + σz·k·t^a·x + f0·t·x/(1+r)
///   (eq. 46) with σy = 0.77 and σz = (a + r(1−a) + 1)/((1+r)(1+a)) (eq. 47),
///   the power advance x = p·t^r fitted on the half and full length (the
///   two-point method of Elliott & Walker 1982; eqs. 61–63), Newton-Raphson
///   with bisection safeguard.
/// * Depletion and recession: furrows recede at cutoff (FAO 45 neglects both
///   phases for furrows); open-end borders deplete y0·L/(2·Q0) after cutoff
///   (eq. 99) and recede over the time of Strelkoff (1977) (eqs. 96–98),
///   linearly from head to tail; level basins recede vertically: the water
///   left on the surface at cutoff spreads evenly and infiltrates in place
///   (the basin assumptions of FAO 45 §5.6).
/// * Performance: infiltrated depth along the field from the opportunity
///   time τ(x) = t_rec(x) − t_adv(x) (eq. 55); application efficiency
///   Ea = stored/applied, requirement efficiency, low-quarter distribution
///   uniformity, deep percolation and tailwater ratios (FAO 45 §4.2).
/// * Design: cutoff for the required depth — furrows t_co = τ_req + t_L
///   (eq. 68), open-end borders from the Strelkoff depletion (eqs. 95–100),
///   basins t_co = (Z_req·L − σy·y0·L)/Q0 + t_L (eq. 113) — and the inflow
///   that maximises Ea between the minimum and the non-erosive maximum
///   (eqs. 67, 93 and 115).
library;

import 'dart:math' as math;

import '../units.dart';

/// Surface irrigation methods.
enum SurfaceSystem { furrow, border, basin }

/// Volume-balance surface storage shape factor (FAO 45, §4.3.4).
const defaultSigmaY = 0.77;

/// Subsurface shape factor σz of the volume balance (FAO 45 eq. 47).
double sigmaZ(double a, double r) => (a + r * (1 - a) + 1) / ((1 + r) * (1 + a));

/// Kostiakov-Lewis infiltration z = k·τ^a + f0·τ in SI: τ in seconds, z in
/// m³ per metre of length per unit width (m² per furrow; m depth for
/// borders and basins), k in z-units/s^a and f0 in z-units/s.
class KostiakovLewis {
  const KostiakovLewis({required this.k, required this.a, this.f0 = 0});

  /// From the per-minute units of FAO 45 (k in m³/m/min^a, f0 in m³/m/min).
  factory KostiakovLewis.perMinute({required double k, required double a, double f0 = 0}) => KostiakovLewis(k: k * math.pow(60, -a), a: a, f0: f0 / 60);

  final double k;
  final double a;
  final double f0;

  /// Infiltrated volume per metre (or depth) after an opportunity time [tauS].
  double z(double tauS) => tauS <= 0 ? 0 : k * math.pow(tauS, a) + f0 * tauS;

  /// Intake rate (per second) at an opportunity time [tauS].
  double rate(double tauS) => tauS <= 0 ? double.infinity : a * k * math.pow(tauS, a - 1) + f0;

  /// k and f0 in the per-minute units of FAO 45.
  double get kPerMinute => k * math.pow(60, a);
  double get f0PerMinute => f0 * 60;

  /// The law with k and f0 times [factor] (wetted-perimeter adjustment, NEH 623 ch. 4, eq. 4-78).
  KostiakovLewis scaled(double factor) => KostiakovLewis(k: k * factor, a: a, f0: f0 * factor);

  /// Opportunity time (s) that infiltrates [zTarget] (Newton-Raphson with a bisection safeguard, FAO 45 eq. 59).
  double timeFor(double zTarget) {
    if (zTarget <= 0) return 0;
    var lo = 0.0, hi = 60.0;
    for (var i = 0; i < 200 && z(hi) < zTarget; i++) {
      hi *= 2;
    }
    if (z(hi) < zTarget) return double.infinity;
    var t = hi / 2;
    for (var i = 0; i < 200; i++) {
      final g = z(t) - zTarget;
      if (g > 0) {
        hi = t;
      } else {
        lo = t;
      }
      final dg = rate(t);
      var next = dg.isFinite && dg > 0 ? t - g / dg : (lo + hi) / 2;
      if (!(next > lo && next < hi)) next = (lo + hi) / 2;
      if ((next - t).abs() < 1e-9 * math.max(1.0, t)) return next;
      t = next;
    }
    return t;
  }

  Map<String, dynamic> toJson() => {'k': k, 'a': a, 'f0': f0};
  static KostiakovLewis fromJson(Map<String, dynamic> j) => KostiakovLewis(k: (j['k'] as num).toDouble(), a: (j['a'] as num).toDouble(), f0: (j['f0'] as num?)?.toDouble() ?? 0);
}

/// One revised NRCS intake family in the handbook's US units (NEH 623
/// ch. 4: tables 4-4 and 4-5 for furrows, 4-8 and 4-9 for borders and
/// basins, continuous flow).
class NrcsIntakeFamily {
  const NrcsIntakeFamily(this.family, this.a, this.furrowK, this.furrowF0, this.refFlowGpm, this.refPerimeterFt, this.borderK, this.borderF0);

  /// Family number: average intake rate over the first 6 hours (in/h).
  final double family;
  final double a;

  /// Furrow K (ft³/ft/min^a) and F0 (ft³/ft/min), defined at the reference flow (gpm) and wetted perimeter (ft).
  final double furrowK;
  final double furrowF0;
  final double refFlowGpm;
  final double refPerimeterFt;

  /// Border and basin k (ft/min^a) and f0 (ft/min).
  final double borderK;
  final double borderF0;

  /// Furrow intake in SI (m³ per metre of furrow) at the reference wetted perimeter.
  KostiakovLewis get furrow => KostiakovLewis(k: furrowK * metersPerFoot * metersPerFoot * math.pow(60, -a), a: a, f0: furrowF0 * metersPerFoot * metersPerFoot / 60);

  /// Border and basin intake in SI (depth, m).
  KostiakovLewis get border => KostiakovLewis(k: borderK * metersPerFoot * math.pow(60, -a), a: a, f0: borderF0 * metersPerFoot / 60);

  /// Reference furrow flow (m³/s) and wetted perimeter (m).
  double get refFlow => refFlowGpm * m3sPerGpm;
  double get refPerimeterM => refPerimeterFt * metersPerFoot;
}

/// Revised NRCS intake families, initial irrigations (NEH 623 ch. 4, tables 4-4 and 4-8).
const nrcsIntakeFamiliesInitial = <NrcsIntakeFamily>[
  NrcsIntakeFamily(0.02, 0.192, 0.002620, 0.0001461, 7.411, 0.365, 0.001380, 0.0000770),
  NrcsIntakeFamily(0.05, 0.247, 0.004756, 0.0002340, 8.255, 0.399, 0.002446, 0.0001203),
  NrcsIntakeFamily(0.10, 0.303, 0.006783, 0.0003475, 9.648, 0.452, 0.003393, 0.0001740),
  NrcsIntakeFamily(0.15, 0.348, 0.008500, 0.0004621, 11.023, 0.500, 0.004160, 0.0002261),
  NrcsIntakeFamily(0.20, 0.385, 0.010086, 0.0005797, 12.381, 0.544, 0.004836, 0.0002778),
  NrcsIntakeFamily(0.25, 0.416, 0.011517, 0.0006961, 13.721, 0.586, 0.005427, 0.0003276),
  NrcsIntakeFamily(0.30, 0.442, 0.012870, 0.0008130, 15.042, 0.626, 0.005960, 0.0003763),
  NrcsIntakeFamily(0.35, 0.464, 0.014166, 0.0009285, 16.347, 0.663, 0.006456, 0.0004233),
  NrcsIntakeFamily(0.40, 0.483, 0.015383, 0.0010425, 17.633, 0.699, 0.006923, 0.0004687),
  NrcsIntakeFamily(0.45, 0.499, 0.016541, 0.0011534, 18.901, 0.733, 0.007341, 0.0005121),
  NrcsIntakeFamily(0.50, 0.514, 0.017660, 0.0012628, 20.152, 0.767, 0.007750, 0.0005541),
  NrcsIntakeFamily(0.60, 0.537, 0.019750, 0.0014715, 22.599, 0.830, 0.008490, 0.0006325),
  NrcsIntakeFamily(0.70, 0.556, 0.021701, 0.0016687, 24.976, 0.889, 0.009161, 0.0007044),
  NrcsIntakeFamily(0.80, 0.572, 0.023512, 0.0018535, 27.281, 0.945, 0.009772, 0.0007701),
  NrcsIntakeFamily(0.90, 0.585, 0.025224, 0.0020268, 29.514, 0.999, 0.010334, 0.0008303),
  NrcsIntakeFamily(1.00, 0.597, 0.026836, 0.0021894, 31.677, 1.050, 0.010856, 0.0008855),
  NrcsIntakeFamily(1.50, 0.638, 0.033830, 0.0028582, 41.420, 1.282, 0.013030, 0.0011006),
  NrcsIntakeFamily(2.00, 0.666, 0.039706, 0.0033515, 49.381, 1.483, 0.014766, 0.0012463),
  NrcsIntakeFamily(4.00, 0.751, 0.059331, 0.0044455, 63.401, 2.131, 0.020151, 0.0015097),
];

/// Revised NRCS intake families, later irrigations (NEH 623 ch. 4, tables 4-5 and 4-9).
const nrcsIntakeFamiliesLater = <NrcsIntakeFamily>[
  NrcsIntakeFamily(0.02, 0.153, 0.002230, 0.0001169, 7.411, 0.365, 0.001170, 0.0000616),
  NrcsIntakeFamily(0.05, 0.197, 0.004036, 0.0001872, 8.255, 0.399, 0.002076, 0.0000963),
  NrcsIntakeFamily(0.10, 0.242, 0.005763, 0.0002780, 9.648, 0.452, 0.002893, 0.0001392),
  NrcsIntakeFamily(0.15, 0.278, 0.007230, 0.0003697, 11.023, 0.500, 0.003540, 0.0001809),
  NrcsIntakeFamily(0.20, 0.308, 0.008566, 0.0004638, 12.381, 0.544, 0.004106, 0.0002223),
  NrcsIntakeFamily(0.25, 0.333, 0.009797, 0.0005569, 13.721, 0.586, 0.004617, 0.0002621),
  NrcsIntakeFamily(0.30, 0.354, 0.010940, 0.0006504, 15.042, 0.626, 0.005060, 0.0003010),
  NrcsIntakeFamily(0.35, 0.371, 0.012046, 0.0007428, 16.347, 0.663, 0.005496, 0.0003386),
  NrcsIntakeFamily(0.40, 0.386, 0.013083, 0.0008340, 17.633, 0.699, 0.005883, 0.0003750),
  NrcsIntakeFamily(0.45, 0.399, 0.014061, 0.0009227, 18.901, 0.733, 0.006241, 0.0004097),
  NrcsIntakeFamily(0.50, 0.411, 0.015010, 0.0010102, 20.152, 0.767, 0.006590, 0.0004433),
  NrcsIntakeFamily(0.60, 0.430, 0.016790, 0.0011772, 22.599, 0.830, 0.007220, 0.0005060),
  NrcsIntakeFamily(0.70, 0.445, 0.018441, 0.0013349, 24.976, 0.889, 0.007781, 0.0005635),
  NrcsIntakeFamily(0.80, 0.458, 0.019982, 0.0014828, 27.281, 0.945, 0.008302, 0.0006161),
  NrcsIntakeFamily(0.90, 0.468, 0.021444, 0.0016214, 29.514, 0.999, 0.008784, 0.0006642),
  NrcsIntakeFamily(1.00, 0.478, 0.022816, 0.0017515, 31.677, 1.050, 0.009236, 0.0007084),
  NrcsIntakeFamily(1.50, 0.510, 0.028760, 0.0022865, 41.420, 1.282, 0.011070, 0.0008805),
  NrcsIntakeFamily(2.00, 0.533, 0.033746, 0.0026812, 49.381, 1.483, 0.012556, 0.0009970),
  NrcsIntakeFamily(4.00, 0.601, 0.050431, 0.0035564, 63.401, 2.131, 0.017131, 0.0012078),
];

/// Intake family [family] (in/h): a tabulated family, or the parameters
/// interpolated linearly in the family number between its neighbours
/// (clamped to the table range).
NrcsIntakeFamily nrcsIntakeFamily(double family, {bool later = false}) {
  final t = later ? nrcsIntakeFamiliesLater : nrcsIntakeFamiliesInitial;
  if (family <= t.first.family) return t.first;
  if (family >= t.last.family) return t.last;
  for (var i = 1; i < t.length; i++) {
    final a = t[i - 1], b = t[i];
    if (family <= b.family + 1e-12) {
      final w = (family - a.family) / (b.family - a.family);
      double l(double x, double y) => x + (y - x) * w;
      return NrcsIntakeFamily(
        family,
        l(a.a, b.a),
        l(a.furrowK, b.furrowK),
        l(a.furrowF0, b.furrowF0),
        l(a.refFlowGpm, b.refFlowGpm),
        l(a.refPerimeterFt, b.refPerimeterFt),
        l(a.borderK, b.borderK),
        l(a.borderF0, b.borderF0),
      );
    }
  }
  return t.last;
}

/// Furrow intake (SI, per metre of furrow) of an NRCS family, adjusted to
/// the actual wetted perimeter [wettedPerimeterM] at the inlet (K and F0
/// times WP/WP_ref, NEH 623 ch. 4, eqs. 4-77 and 4-78); 0 = the reference perimeter.
KostiakovLewis nrcsFurrowIntake(double family, {bool later = false, double wettedPerimeterM = 0}) {
  final f = nrcsIntakeFamily(family, later: later);
  return wettedPerimeterM > 0 ? f.furrow.scaled(wettedPerimeterM / f.refPerimeterM) : f.furrow;
}

/// Border and basin intake (SI, depth) of an NRCS family.
KostiakovLewis nrcsBorderIntake(double family, {bool later = false}) => nrcsIntakeFamily(family, later: later).border;

/// Hydraulic section of the flow: A·R^(2/3) = ρ1·A^ρ2 (FAO 45 eqs. 42–45),
/// with the power laws A = σ1·y^σ2 and WP = γ1·y^γ2 (SI, depth y in m).
class FlowSection {
  const FlowSection({required this.rho1, required this.rho2, this.sigma1 = 1, this.sigma2 = 1, this.gamma1 = 1, this.gamma2 = 0});

  /// Section from the power laws of area and wetted perimeter against depth.
  factory FlowSection.fromPowerLaws({required double sigma1, required double sigma2, required double gamma1, required double gamma2}) {
    final rho2 = 5 / 3 - 2 / 3 * gamma2 / sigma2;
    return FlowSection(rho1: (math.pow(sigma1, 5 / 3 - rho2) / math.pow(gamma1, 2 / 3)).toDouble(), rho2: rho2, sigma1: sigma1, sigma2: sigma2, gamma1: gamma1, gamma2: gamma2);
  }

  /// Wide sheet flow per metre of width (borders and basins).
  static const sheet = FlowSection(rho1: 1, rho2: 5 / 3);

  /// The furrow of FAO 45 §4.3.3: A = 0.9696·y^1.732, WP = 2.4125·y^0.805 (y in m), ρ1 = 0.551, ρ2 = 1.357.
  static const faoFurrow = FlowSection(rho1: 0.55061, rho2: 1.35681, sigma1: 0.9696, sigma2: 1.732, gamma1: 2.4125, gamma2: 0.805);

  final double rho1;
  final double rho2;
  final double sigma1;
  final double sigma2;
  final double gamma1;
  final double gamma2;

  /// Flow depth (m) of a flow area (m²).
  double depthOf(double area) => area <= 0 || sigma1 <= 0 || sigma2 <= 0 ? 0 : math.pow(area / sigma1, 1 / sigma2).toDouble();

  /// Wetted perimeter (m) of a flow area (the unit width for sheet flow).
  double wettedPerimeterOf(double area) => gamma1 * math.pow(depthOf(area), gamma2);

  Map<String, dynamic> toJson() => {'r1': rho1, 'r2': rho2, 's1': sigma1, 's2': sigma2, 'g1': gamma1, 'g2': gamma2};
  static FlowSection fromJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return FlowSection(rho1: d('r1', 1), rho2: d('r2', 5 / 3), sigma1: d('s1', 1), sigma2: d('s2', 1), gamma1: d('g1', 1), gamma2: d('g2', 0));
  }
}

/// Field data for the surface irrigation model. All values in SI.
class SurfaceSpec {
  const SurfaceSpec({
    required this.system,
    required this.lengthM,
    required this.intake,
    this.slope = 0.001,
    this.manningN = 0.04,
    this.section = FlowSection.faoFurrow,
    this.furrowSpacingM = 1,
    this.sigmaY = defaultSigmaY,
    this.maxAdvanceHours = 48,
    this.segments = 100,
  });

  final SurfaceSystem system;

  /// Field (run) length (m), slope along the run (m/m) and Manning n.
  final double lengthM;
  final double slope;
  final double manningN;

  /// Infiltration per metre of length: per furrow (furrows) or per metre of width (borders, basins).
  final KostiakovLewis intake;

  /// Furrow section (borders and basins use sheet flow) and furrow spacing (m).
  final FlowSection section;
  final double furrowSpacingM;

  /// Surface storage shape factor σy.
  final double sigmaY;

  /// Advance that does not reach the end within this time is incomplete (h).
  final double maxAdvanceHours;

  /// Field divisions for the infiltrated profile and the performance measures.
  final int segments;

  /// Level field: basins, or slopes below 1e-5 (NEH 623 ch. 4).
  bool get level => system == SurfaceSystem.basin || slope < 1e-5;

  /// Section used: the furrow section, or sheet flow.
  FlowSection get flowSection => system == SurfaceSystem.furrow ? section : FlowSection.sheet;

  /// Unit width: the furrow spacing, or 1 m.
  double get unitWidthM => system == SurfaceSystem.furrow ? furrowSpacingM : 1;
}

/// Inlet flow area (m², or m depth for sheet flow) for [inflow] (m³/s per
/// furrow or per metre): Manning at normal depth on a slope (FAO 45 eq. 48),
/// or with the friction slope y0/x at the advance distance [x] on level
/// fields (eq. 60, generalised to the power laws of the section).
double inletFlowArea(SurfaceSpec s, double inflow, {double x = 0}) {
  final sec = s.flowSection;
  if (inflow <= 0) return 0;
  if (!s.level) return math.pow(inflow * s.manningN / (sec.rho1 * math.sqrt(s.slope)), 1 / sec.rho2).toDouble();
  final dist = x > 0 ? x : s.lengthM;
  final e = 1 / (2 * sec.sigma2);
  return math.pow(inflow * s.manningN * math.sqrt(dist) * math.pow(sec.sigma1, e) / sec.rho1, 1 / (sec.rho2 + e)).toDouble();
}

/// Largest non-erosive inflow (m³/s per furrow or per metre) for the
/// velocity [maxVelocity] (m/s; FAO 45 suggests 8–10 m/min on erosive silts
/// and 13–15 m/min on stable soils): Q = (V^ρ2·n/(ρ1·√S0))^(1/(ρ2−1)) (eq. 67).
double maxNonErosiveFlow({required FlowSection section, required double manningN, required double slope, required double maxVelocity}) {
  if (slope <= 0 || section.rho2 <= 1 || maxVelocity <= 0) return double.infinity;
  return math.pow(math.pow(maxVelocity, section.rho2) * manningN / (section.rho1 * math.sqrt(slope)), 1 / (section.rho2 - 1)).toDouble();
}

/// Largest basin inflow per metre (m³/s/m) for the velocity [maxVelocity]
/// (m/s) one ninth of the way down: Q = V^(13/7)·(n²·L/9)^(3/7) (FAO 45 eq. 115 in SI).
double basinMaxFlow({required double manningN, required double lengthM, required double maxVelocity}) =>
    maxVelocity <= 0 ? double.infinity : (math.pow(maxVelocity, 13 / 7) * math.pow(manningN * manningN * lengthM / 9, 3 / 7)).toDouble();

/// Largest inflow on a level field (m³/s per furrow or per metre) whose
/// velocity one ninth of the way down, Q/A(L/9), equals [maxVelocity]: FAO 45
/// eq. 115 solved for the section of the field (for sheet flow it is
/// [basinMaxFlow]).
double levelMaxFlow(SurfaceSpec s, double maxVelocity) {
  if (maxVelocity <= 0 || s.lengthM <= 0) return double.infinity;
  double v(double q) => q / inletFlowArea(s, q, x: s.lengthM / 9);
  var lo = 0.0, hi = 1e-3;
  for (var i = 0; i < 60 && v(hi) < maxVelocity; i++) {
    hi *= 2;
  }
  for (var i = 0; i < 100; i++) {
    final mid = (lo + hi) / 2;
    if (v(mid) < maxVelocity) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Smallest border inflow per metre (m³/s/m) that spreads over the border:
/// 0.000357·L·√S0/n m³/min/m (Hart et al. 1980; FAO 45 eq. 93).
double borderMinFlow({required double lengthM, required double slope, required double manningN}) => manningN > 0 ? 0.000357 / 60 * lengthM * math.sqrt(math.max(slope, 0.0)) / manningN : 0;

/// Basic intake rate from an inflow-outflow test: f0 = (Qin − Qout)/L (FAO 45 eq. 31; m³/s per metre).
double basicIntakeFromInflowOutflow({required double inflow, required double outflow, required double lengthM}) => lengthM > 0 ? (inflow - outflow) / lengthM : 0;

/// Recession time of an open-end border after depletion (min), Strelkoff
/// (1977) as given in FAO 45 eq. 98: 0.095·n^0.47565·Sy^0.20735·L^0.6829 /
/// (I^0.52435·S0^0.237825), with the mean intake rate I (m³/min/m) and the
/// relative water-surface slope Sy of eq. 97.
double strelkoffRecessionMinutes({required double manningN, required double surfaceSlope, required double lengthM, required double intakeRate, required double slope}) {
  if (surfaceSlope <= 0 || intakeRate <= 0 || slope <= 0) return 0;
  return 0.095 * math.pow(manningN, 0.47565) * math.pow(surfaceSlope, 0.20735) * math.pow(lengthM, 0.6829) / (math.pow(intakeRate, 0.52435) * math.pow(slope, 0.237825));
}

/// Relative water-surface slope of a border at depletion (FAO 45 eq. 97):
/// Sy = (1/L)·[(Q0 − I·L)·n/(60·√S0)]^0.6, with Q0 and I per minute.
double borderSurfaceSlope({required double inflowPerMin, required double intakeRatePerMin, required double lengthM, required double manningN, required double slope}) {
  final excess = inflowPerMin - intakeRatePerMin * lengthM;
  if (excess <= 0 || slope <= 0 || lengthM <= 0) return 0;
  return math.pow(excess * manningN / (60 * math.sqrt(slope)), 0.6) / lengthM;
}

/// Advance of the water front.
class SurfaceAdvance {
  const SurfaceAdvance({required this.advanceS, required this.halfS, required this.r, required this.p, required this.inletArea, required this.complete});

  /// Time to reach the end and the half length (s); infinite when the front does not get there.
  final double advanceS;
  final double halfS;

  /// Power advance x = p·t^r (x in m, t in s).
  final double r;
  final double p;

  /// Inlet flow area (m², or depth for sheet flow) — at the end of advance on level fields.
  final double inletArea;
  final bool complete;

  /// Time (s) the front reaches [x].
  double timeAt(double x) => x <= 0 || p <= 0 ? 0 : math.pow(x / p, 1 / r).toDouble();

  /// Distance (m) reached at time [t].
  double distanceAt(double t) => t <= 0 ? 0 : p * math.pow(t, r);
}

double _advanceTime(double x, double q0, double a0, KostiakovLewis inf, double r, double sigmaY, double tMax) {
  final sz = sigmaZ(inf.a, r);
  double f(double t) => q0 * t - sigmaY * a0 * x - sz * inf.k * math.pow(t, inf.a) * x - inf.f0 * t * x / (1 + r);
  double df(double t) => q0 - inf.a * sz * inf.k * math.pow(math.max(t, 1e-9), inf.a - 1) * x - inf.f0 * x / (1 + r);
  if (q0 <= 0 || x <= 0) return x <= 0 ? 0 : double.infinity;
  if (f(tMax) < 0) return double.infinity;
  var lo = 0.0, hi = tMax;
  var t = math.min(math.max(5 * a0 * x / q0, 1.0), tMax); // FAO 45 eq. 61
  for (var i = 0; i < 200; i++) {
    final v = f(t);
    if (v > 0) {
      hi = t;
    } else {
      lo = t;
    }
    final d = df(t);
    var next = d > 0 ? t - v / d : (lo + hi) / 2;
    if (!(next > lo && next < hi)) next = (lo + hi) / 2;
    if ((next - t).abs() < 1e-9 * math.max(1.0, t)) return next;
    t = next;
  }
  return t;
}

/// Advance by the volume balance with the two-point power law (FAO 45 §5.3.1).
SurfaceAdvance surfaceAdvance(SurfaceSpec s, double inflow) {
  final length = s.lengthM;
  final tMax = s.maxAdvanceHours * 3600;
  final aL = inletFlowArea(s, inflow, x: length);
  final aH = s.level ? inletFlowArea(s, inflow, x: length / 2) : aL;
  var r = 0.5;
  var tL = double.infinity, tH = double.infinity;
  for (var it = 0; it < 200; it++) {
    tL = _advanceTime(length, inflow, aL, s.intake, r, s.sigmaY, tMax);
    tH = _advanceTime(length / 2, inflow, aH, s.intake, r, s.sigmaY, tMax);
    if (!tL.isFinite || !tH.isFinite || tH <= 0 || tL <= tH) break;
    final next = (math.ln2 / math.log(tL / tH)).clamp(0.05, 1.0).toDouble();
    if ((next - r).abs() < 1e-8) {
      r = next;
      break;
    }
    r = next;
  }
  final complete = tL.isFinite && tL > 0;
  return SurfaceAdvance(advanceS: tL, halfS: tH, r: r, p: complete ? length / math.pow(tL, r) : 0, inletArea: aL, complete: complete);
}

/// Infiltrated depth at one point of the field.
class SurfacePoint {
  const SurfacePoint({required this.x, required this.advanceS, required this.recessionS, required this.opportunityS, required this.depthM});
  final double x;
  final double advanceS;
  final double recessionS;
  final double opportunityS;

  /// Infiltrated depth (m; volume per metre over the unit width).
  final double depthM;

  Map<String, dynamic> toJson() => {'x': x, 'ta': advanceS, 'tr': recessionS, 'tau': opportunityS, 'z': depthM};
  static SurfacePoint fromJson(Map<String, dynamic> j) => SurfacePoint(
    x: (j['x'] as num).toDouble(),
    advanceS: (j['ta'] as num).toDouble(),
    recessionS: (j['tr'] as num).toDouble(),
    opportunityS: (j['tau'] as num).toDouble(),
    depthM: (j['z'] as num).toDouble(),
  );
}

/// Performance of one irrigation (per furrow, or per metre of border or basin width).
class SurfaceEvaluation {
  const SurfaceEvaluation({
    required this.system,
    required this.inflow,
    required this.cutoffS,
    required this.advanceS,
    required this.r,
    required this.p,
    required this.inletArea,
    required this.inletDepthM,
    required this.depletionS,
    required this.recessionS,
    required this.requiredDepthM,
    required this.requiredTimeS,
    required this.appliedM3,
    required this.infiltratedM3,
    required this.storedM3,
    required this.deepPercolationM3,
    required this.runoffM3,
    required this.efficiency,
    required this.requirementEfficiency,
    required this.lowQuarterDu,
    required this.deepPercolationRatio,
    required this.tailwaterRatio,
    required this.meanDepthM,
    required this.minDepthM,
    required this.maxDepthM,
    required this.profile,
    required this.warnings,
  });

  final SurfaceSystem system;

  /// Inflow (m³/s per furrow or per metre) and cutoff time (s).
  final double inflow;
  final double cutoffS;

  /// Advance time to the end (s; infinite when incomplete) and the power advance x = p·t^r.
  final double advanceS;
  final double r;
  final double p;

  /// Inlet flow area (m², or m) and flow depth at the inlet (m).
  final double inletArea;
  final double inletDepthM;

  /// Time the surface water leaves the inlet (s) and recession time at the end (s).
  final double depletionS;
  final double recessionS;

  /// Required depth (m) and the opportunity time that infiltrates it (s).
  final double requiredDepthM;
  final double requiredTimeS;

  /// Volumes per furrow (m³) or per metre of width (m³/m): applied, infiltrated, stored in the root zone, deep percolation and runoff.
  final double appliedM3;
  final double infiltratedM3;
  final double storedM3;
  final double deepPercolationM3;
  final double runoffM3;

  /// Application and requirement efficiency, low-quarter uniformity, deep
  /// percolation and tailwater ratios (fractions; FAO 45 §4.2).
  final double efficiency;
  final double requirementEfficiency;
  final double lowQuarterDu;
  final double deepPercolationRatio;
  final double tailwaterRatio;

  /// Mean, smallest and largest infiltrated depth (m).
  final double meanDepthM;
  final double minDepthM;
  final double maxDepthM;
  final List<SurfacePoint> profile;

  /// Message codes (`surface_*`, with `:<id>` when an id was given).
  final List<String> warnings;

  bool get complete => advanceS.isFinite;

  Map<String, dynamic> toJson() => {
    'sys': system.name,
    'q': inflow,
    'tco': cutoffS,
    'tl': advanceS.isFinite ? advanceS : -1,
    'r': r,
    'p': p,
    'a0': inletArea,
    'y0': inletDepthM,
    'td': depletionS,
    'tr': recessionS,
    'zreq': requiredDepthM,
    'treq': requiredTimeS.isFinite ? requiredTimeS : -1,
    'vin': appliedM3,
    'vinf': infiltratedM3,
    'vst': storedM3,
    'vdp': deepPercolationM3,
    'vro': runoffM3,
    'ea': efficiency,
    'er': requirementEfficiency,
    'du': lowQuarterDu,
    'dpr': deepPercolationRatio,
    'twr': tailwaterRatio,
    'zm': meanDepthM,
    'zmin': minDepthM,
    'zmax': maxDepthM,
    'prof': profile.map((e) => e.toJson()).toList(),
    'warn': warnings,
  };
  static SurfaceEvaluation fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    double inf(String k) => d(k) < 0 ? double.infinity : d(k);
    return SurfaceEvaluation(
      system: SurfaceSystem.values.byName(j['sys'] as String? ?? 'furrow'),
      inflow: d('q'),
      cutoffS: d('tco'),
      advanceS: inf('tl'),
      r: d('r'),
      p: d('p'),
      inletArea: d('a0'),
      inletDepthM: d('y0'),
      depletionS: d('td'),
      recessionS: d('tr'),
      requiredDepthM: d('zreq'),
      requiredTimeS: inf('treq'),
      appliedM3: d('vin'),
      infiltratedM3: d('vinf'),
      storedM3: d('vst'),
      deepPercolationM3: d('vdp'),
      runoffM3: d('vro'),
      efficiency: d('ea'),
      requirementEfficiency: d('er'),
      lowQuarterDu: d('du'),
      deepPercolationRatio: d('dpr'),
      tailwaterRatio: d('twr'),
      meanDepthM: d('zm'),
      minDepthM: d('zmin'),
      maxDepthM: d('zmax'),
      profile: ((j['prof'] as List?) ?? const []).map((e) => SurfacePoint.fromJson(e as Map<String, dynamic>)).toList(),
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Border depletion: the mean intake rate at a time [t1] over the head and
/// tail (FAO 45 eq. 96), per second.
double _meanIntakeRate(KostiakovLewis inf, double t1, double advanceS) => inf.a * inf.k / 2 * (math.pow(math.max(t1, 1.0), inf.a - 1) + math.pow(math.max(t1 - advanceS, 1.0), inf.a - 1)) + inf.f0;

/// Recession duration (s) of an open-end border, with the mean intake rate
/// taken at [depletionS] (FAO 45 eqs. 96–98).
double _borderRecessionS(SurfaceSpec s, double inflow, double depletionS, double advanceS) {
  final rate = _meanIntakeRate(s.intake, depletionS, advanceS);
  final sy = borderSurfaceSlope(inflowPerMin: inflow * 60, intakeRatePerMin: rate * 60, lengthM: s.lengthM, manningN: s.manningN, slope: s.slope);
  return 60 * strelkoffRecessionMinutes(manningN: s.manningN, surfaceSlope: sy, lengthM: s.lengthM, intakeRate: rate * 60, slope: s.slope);
}

/// Performance of an irrigation with [inflow] (m³/s per furrow or per metre)
/// cut off at [cutoffS] (s); [requiredDepthM] is the depth the root zone needs (m).
SurfaceEvaluation evaluateSurface(SurfaceSpec s, {required double inflow, required double cutoffS, double requiredDepthM = 0, String id = ''}) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  final length = s.lengthM;
  final w = s.unitWidthM;
  final inf = s.intake;
  final adv = surfaceAdvance(s, inflow);
  final y0 = s.flowSection.depthOf(adv.inletArea);
  final zReq = math.max(requiredDepthM, 0.0) * w;
  final tauReq = zReq > 0 ? inf.timeFor(zReq) : 0.0;
  final tco = math.max(cutoffS, 0.0);
  if (!adv.complete) warn('surface_no_advance');
  if (adv.complete && tco < adv.advanceS - 1e-6) warn('surface_cutoff_before_advance');
  if (zReq <= 0) warn('surface_no_requirement');

  // depletion and recession (open-end border: FAO 45 eqs. 96–99, the intake
  // rates taken at the depletion time as in the design iteration)
  var depletion = tco, recession = tco;
  if (s.system == SurfaceSystem.border && adv.complete && inflow > 0) {
    depletion = tco + adv.inletArea * length / (2 * inflow);
    recession = depletion + _borderRecessionS(s, inflow, depletion, adv.advanceS);
  }
  double recessionAt(double x) => s.system == SurfaceSystem.border ? depletion + (recession - depletion) * x / length : tco;

  // infiltrated profile
  final nSeg = math.max(10, s.segments);
  final dx = length / nSeg;
  final reach = adv.complete ? (tco >= adv.advanceS ? length : adv.distanceAt(tco)) : 0.0;
  final xs = [for (var j = 0; j < nSeg; j++) (j + 0.5) * dx];
  final tAdv = [for (final x in xs) x <= reach + 1e-9 ? adv.timeAt(x) : double.infinity];
  final zs = List<double>.filled(nSeg, 0);
  final taus = List<double>.filled(nSeg, 0);
  final recs = List<double>.filled(nSeg, 0);
  final basin = s.system == SurfaceSystem.basin;
  final tEnd = basin ? math.min(tco, adv.complete ? adv.advanceS : tco) : 0.0;
  for (var j = 0; j < nSeg; j++) {
    recs[j] = basin ? tEnd : recessionAt(xs[j]);
    taus[j] = tAdv[j].isFinite ? math.max(0.0, recs[j] - tAdv[j]) : 0.0;
    zs[j] = inf.z(taus[j]);
  }
  final applied = inflow * tco;
  var infiltrated = zs.fold(0.0, (a, b) => a + b) * dx;
  if (basin && reach > 0) {
    // vertical recession: the water still on the surface spreads evenly
    final extra = math.max(0.0, applied - infiltrated) / length;
    for (var j = 0; j < nSeg; j++) {
      zs[j] += extra;
    }
    infiltrated = zs.fold(0.0, (a, b) => a + b) * dx;
  }
  final runoff = basin ? 0.0 : math.max(0.0, applied - infiltrated);
  final stored = zReq > 0 ? zs.fold(0.0, (a, z) => a + math.min(z, zReq)) * dx : 0.0;
  final sorted = [...zs]..sort();
  final quarter = math.max(1, (nSeg / 4).ceil());
  final mean = infiltrated / length;
  final lowQuarter = sorted.take(quarter).fold(0.0, (a, b) => a + b) / quarter;
  final profile = [for (var j = 0; j < nSeg; j++) SurfacePoint(x: xs[j], advanceS: tAdv[j].isFinite ? tAdv[j] : -1, recessionS: recs[j], opportunityS: taus[j], depthM: zs[j] / w)];
  return SurfaceEvaluation(
    system: s.system,
    inflow: inflow,
    cutoffS: tco,
    advanceS: adv.advanceS,
    r: adv.r,
    p: adv.p,
    inletArea: adv.inletArea,
    inletDepthM: y0,
    depletionS: depletion,
    recessionS: recession,
    requiredDepthM: math.max(requiredDepthM, 0.0),
    requiredTimeS: tauReq,
    appliedM3: applied,
    infiltratedM3: infiltrated,
    storedM3: stored,
    deepPercolationM3: infiltrated - stored,
    runoffM3: runoff,
    efficiency: applied > 0 ? stored / applied : 0,
    requirementEfficiency: zReq > 0 ? stored / (zReq * length) : 0,
    lowQuarterDu: mean > 0 ? lowQuarter / mean : 0,
    deepPercolationRatio: applied > 0 ? (infiltrated - stored) / applied : 0,
    tailwaterRatio: applied > 0 ? runoff / applied : 0,
    meanDepthM: mean / w,
    minDepthM: sorted.first / w,
    maxDepthM: sorted.last / w,
    profile: profile,
    warnings: warnings,
  );
}

/// Cutoff time (s) that infiltrates [requiredDepthM] where the field gets
/// least: furrows τ_req + t_L (FAO 45 eq. 68); open-end borders from the
/// Strelkoff depletion with the tail receding at τ_req + t_L (eqs. 95–100);
/// level basins (Z_req·L − σy·y0·L)/Q0 + t_L, at least t_L (eq. 113).
/// Infinite when the advance does not complete.
double designCutoffTime(SurfaceSpec s, {required double inflow, required double requiredDepthM, SurfaceAdvance? advance}) {
  final adv = advance ?? surfaceAdvance(s, inflow);
  if (!adv.complete || inflow <= 0) return double.infinity;
  final zReq = math.max(requiredDepthM, 0.0) * s.unitWidthM;
  final tauReq = s.intake.timeFor(zReq);
  final tL = adv.advanceS;
  switch (s.system) {
    case SurfaceSystem.furrow:
      return tauReq + tL;
    case SurfaceSystem.border:
      final tail = tauReq + tL;
      var t1 = tail;
      for (var i = 0; i < 100; i++) {
        final t2 = tail - _borderRecessionS(s, inflow, t1, tL);
        if ((t2 - t1).abs() < 0.5) {
          t1 = t2;
          break;
        }
        t1 = t2;
      }
      final storage = adv.inletArea * s.lengthM / (2 * inflow);
      return math.max(0.0, (t1 >= tauReq ? t1 : tauReq) - storage);
    case SurfaceSystem.basin:
      final y0 = s.flowSection.depthOf(adv.inletArea);
      return math.max(tL, (zReq * s.lengthM - s.sigmaY * y0 * s.lengthM) / inflow + tL);
  }
}

/// Evaluation of the irrigation cut off for the required depth.
SurfaceEvaluation designForDepth(SurfaceSpec s, {required double inflow, required double requiredDepthM, String id = ''}) {
  final adv = surfaceAdvance(s, inflow);
  final tco = designCutoffTime(s, inflow: inflow, requiredDepthM: requiredDepthM, advance: adv);
  return evaluateSurface(s, inflow: inflow, cutoffS: tco.isFinite ? tco : s.maxAdvanceHours * 3600, requiredDepthM: requiredDepthM, id: id);
}

/// One inflow tried by [designSurface].
class SurfaceDesignRow {
  const SurfaceDesignRow({
    required this.inflow,
    required this.advanceS,
    required this.cutoffS,
    required this.efficiency,
    required this.lowQuarterDu,
    required this.tailwaterRatio,
    required this.deepPercolationRatio,
    required this.requirementEfficiency,
  });
  final double inflow;
  final double advanceS;
  final double cutoffS;
  final double efficiency;
  final double lowQuarterDu;
  final double tailwaterRatio;
  final double deepPercolationRatio;
  final double requirementEfficiency;

  Map<String, dynamic> toJson() => {
    'q': inflow,
    'tl': advanceS.isFinite ? advanceS : -1,
    'tco': cutoffS.isFinite ? cutoffS : -1,
    'ea': efficiency,
    'du': lowQuarterDu,
    'twr': tailwaterRatio,
    'dpr': deepPercolationRatio,
    'er': requirementEfficiency,
  };
  static SurfaceDesignRow fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    double inf(String k) => d(k) < 0 ? double.infinity : d(k);
    return SurfaceDesignRow(
      inflow: d('q'),
      advanceS: inf('tl'),
      cutoffS: inf('tco'),
      efficiency: d('ea'),
      lowQuarterDu: d('du'),
      tailwaterRatio: d('twr'),
      deepPercolationRatio: d('dpr'),
      requirementEfficiency: d('er'),
    );
  }
}

/// Inflow and cutoff that maximise the application efficiency.
class SurfaceDesign {
  const SurfaceDesign({required this.best, required this.rows, required this.minInflow, required this.maxInflow, required this.warnings});

  /// The best evaluation (null when no inflow completes the advance).
  final SurfaceEvaluation? best;
  final List<SurfaceDesignRow> rows;

  /// Range of inflows tried (m³/s per furrow or per metre).
  final double minInflow;
  final double maxInflow;
  final List<String> warnings;

  Map<String, dynamic> toJson() => {if (best != null) 'best': best!.toJson(), 'rows': rows.map((e) => e.toJson()).toList(), 'qmin': minInflow, 'qmax': maxInflow, 'warn': warnings};
  static SurfaceDesign fromJson(Map<String, dynamic> j) => SurfaceDesign(
    best: j['best'] == null ? null : SurfaceEvaluation.fromJson(j['best'] as Map<String, dynamic>),
    rows: ((j['rows'] as List?) ?? const []).map((e) => SurfaceDesignRow.fromJson(e as Map<String, dynamic>)).toList(),
    minInflow: (j['qmin'] as num?)?.toDouble() ?? 0,
    maxInflow: (j['qmax'] as num?)?.toDouble() ?? 0,
    warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
  );
}

/// Inflow (and its cutoff for the required depth) with the highest
/// application efficiency, trying [steps] inflows spaced geometrically
/// between [minInflow] and [maxInflow]. Without limits the maximum is the
/// non-erosive inflow for [maxVelocity] (FAO 45 eq. 67; level fields eq. 115, see [levelMaxFlow]),
/// reduced so the inlet depth stays below [maxFlowDepthM] (dykes; 0 = no
/// limit), and the minimum is the border spreading flow (eq. 93) or 1/50 of
/// the maximum.
SurfaceDesign designSurface(
  SurfaceSpec s, {
  required double requiredDepthM,
  double minInflow = 0,
  double maxInflow = 0,
  double maxVelocity = 13 / 60,
  double maxFlowDepthM = 0,
  int steps = 24,
  String id = '',
}) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  var qMax = maxInflow;
  if (qMax <= 0) {
    qMax = s.level ? levelMaxFlow(s, maxVelocity) : maxNonErosiveFlow(section: s.flowSection, manningN: s.manningN, slope: s.slope, maxVelocity: maxVelocity);
    if (maxFlowDepthM > 0) {
      // largest flow whose inlet depth stays under the dykes (bisection on the depth)
      var lo = 0.0, hi = qMax.isFinite ? qMax : 1.0;
      if (s.flowSection.depthOf(inletFlowArea(s, hi)) > maxFlowDepthM) {
        for (var i = 0; i < 80; i++) {
          final mid = (lo + hi) / 2;
          if (s.flowSection.depthOf(inletFlowArea(s, mid)) > maxFlowDepthM) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        qMax = lo;
      }
    }
  }
  if (!qMax.isFinite) qMax = 0.01;
  var qMin = minInflow;
  if (qMin <= 0) qMin = s.system == SurfaceSystem.border ? math.min(borderMinFlow(lengthM: s.lengthM, slope: s.slope, manningN: s.manningN), qMax) : qMax / 50;
  if (qMin <= 0) qMin = qMax / 50;
  final n = math.max(2, steps);
  final rows = <SurfaceDesignRow>[];
  SurfaceEvaluation? best;
  for (var i = 0; i < n; i++) {
    final q = qMin * math.pow(qMax / qMin, i / (n - 1));
    final adv = surfaceAdvance(s, q);
    final tco = designCutoffTime(s, inflow: q, requiredDepthM: requiredDepthM, advance: adv);
    if (!tco.isFinite) {
      rows.add(SurfaceDesignRow(inflow: q, advanceS: adv.advanceS, cutoffS: double.infinity, efficiency: 0, lowQuarterDu: 0, tailwaterRatio: 0, deepPercolationRatio: 0, requirementEfficiency: 0));
      continue;
    }
    final e = evaluateSurface(s, inflow: q, cutoffS: tco, requiredDepthM: requiredDepthM, id: id);
    rows.add(
      SurfaceDesignRow(
        inflow: q,
        advanceS: e.advanceS,
        cutoffS: tco,
        efficiency: e.efficiency,
        lowQuarterDu: e.lowQuarterDu,
        tailwaterRatio: e.tailwaterRatio,
        deepPercolationRatio: e.deepPercolationRatio,
        requirementEfficiency: e.requirementEfficiency,
      ),
    );
    if (best == null || e.efficiency > best.efficiency + 1e-12) best = e;
  }
  if (best == null) warn('surface_no_advance');
  return SurfaceDesign(best: best, rows: rows, minInflow: qMin, maxInflow: qMax, warnings: [...warnings, ...?best?.warnings.where((w) => !warnings.contains(w))]);
}

/// Infiltration from the advance of a field evaluation (two-point method).
class TwoPointInfiltration {
  const TwoPointInfiltration({required this.intake, required this.r, required this.sigmaZ});
  final KostiakovLewis intake;
  final double r;
  final double sigmaZ;
}

/// Kostiakov-Lewis parameters from two advance points (x1, t1) and (x2, t2)
/// (m, s), the inflow (m³/s per furrow or metre), the basic intake rate f0
/// (from inflow-outflow, eq. 31) and the inlet flow area: r from the power
/// advance, then V = Q0·t/x − σy·A0 − f0·t/(1+r) at both points,
/// a = ln(V2/V1)/ln(t2/t1), σz from eq. 47 and k = V2/(σz·t2^a)
/// (Elliott & Walker 1982; FAO 45 eqs. 49–54).
TwoPointInfiltration twoPointInfiltration({
  required double inflow,
  required double basicIntake,
  required double x1,
  required double t1,
  required double x2,
  required double t2,
  required double inletArea,
  double sigmaY = defaultSigmaY,
}) {
  final r = math.log(x2 / x1) / math.log(t2 / t1);
  final v1 = inflow * t1 / x1 - sigmaY * inletArea - basicIntake * t1 / (1 + r);
  final v2 = inflow * t2 / x2 - sigmaY * inletArea - basicIntake * t2 / (1 + r);
  final a = math.log(v2 / v1) / math.log(t2 / t1);
  final sz = sigmaZ(a, r);
  return TwoPointInfiltration(
    intake: KostiakovLewis(k: v2 / (sz * math.pow(t2, a)), a: a, f0: basicIntake),
    r: r,
    sigmaZ: sz,
  );
}
