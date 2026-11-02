/// Sprinkler package (nozzle chart) of a centre pivot or linear move, and
/// its timer chart.
///
/// * Outlets: positions along the machine from the pivot point (or the
///   inlet of a linear), span by span at each span's own spacing, the
///   overhang included, or an explicit list.
/// * Flow per outlet for a uniform depth (Heermann & Hein 1968; NRCS NEH 623
///   ch. 11, eq. 11-44): each outlet serves the ring between the points
///   half-way to its neighbours, q_i = Q·(b_i² − b_{i−1}²)/R², which is the
///   classic q = 2·r·S·Q/R² for even spacing and adds up to Q exactly; a
///   linear move gets q_i = Q·(b_i − b_{i−1})/L. R is the effective radius:
///   pipe length plus the throw of the last sprinkler, or L + 0.9·R_gun with
///   an end gun running all the way round, whose share is
///   Q·(1 − L²/R²) (NEH 623 ch. 11, eq. 11-46).
/// * Pressure at every outlet: friction outlet by outlet with the flow left
///   in the pipe (continuous outflow; Hazen-Williams or Darcy-Weisbach with
///   the pipe of each span), ground rise in the design (sizing) and worst
///   positions, pipe height (with the span arch) and machine losses. A drop
///   gains its length in static head and loses the hose friction plus the
///   gooseneck and fittings, K·V²/2g (Keller & Bliesner 1990, ch. 16).
/// * Regulators: the nominal rating nearest the target nozzle pressure, from
///   the catalogue regulators or the standard 6–50 psi series; a regulator
///   needs its inlet 5 psi above the rating to regulate (Kansas State Univ.
///   MF3608, Interpreting and Using Center Pivot Sprinkler Designs, 2022);
///   below that its outlet is taken as inlet − margin.
/// * Nozzles: the catalogue nozzle whose flow at the nozzle pressure is the
///   closest to the requirement, or a numbered series of orifice diameters
///   (default 1/128-inch steps, the numbering of pivot spray nozzles) sized
///   with the orifice equation q = Cd·(π/4)·d²·√(2gh) and Cd = 0.97, the
///   coefficient implied by the nozzle discharge coefficients Kd of NEH 623
///   ch. 11, table 11-13. Outlets that would need less than half the
///   smallest nozzle are plugged and their ring passes to the next outlet
///   (the combination spacing of NEH 623 ch. 11).
/// * Timer chart: speed of the last regular tower at 100 % from the drive
///   train (motor rpm / gearbox ratios × rolling circumference of the tyre)
///   or a given speed; time per revolution 2π·r_last/v; gross depth Q·T/A;
///   at a timer setting p the tower runs p % of the time, so the time grows
///   and the depth grows by 100/p (Kansas State Univ. MF3608; Keller &
///   Bliesner 1990, ch. 16).
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/pump.dart';
import '../model/catalog.dart';
import '../units.dart';
import 'pivot.dart';

/// Nominal ratings (psi) of the pressure regulators usually fitted to pivot
/// drops, used when the catalogue offers no regulator.
const standardRegulatorRatingsPsi = <double>[6, 10, 15, 20, 25, 30, 35, 40, 50];

/// Percent-timer settings of the default timer chart.
const defaultTimerSettings = <double>[100, 90, 80, 70, 60, 50, 40, 30, 20, 10];

/// How the end gun is used.
enum EndGunUse {
  /// No end gun: the last sprinkler throws [PivotPackageSpec.endThrowM] beyond the pipe end.
  none,

  /// The gun runs all the way round and waters the ring from the pipe end to
  /// R = L + 0.9·R_gun (NEH 623 ch. 11, eq. 11-46).
  fullCircle,

  /// The gun only runs in the corners: the sprinklers are sized for
  /// R = L + throw and the gun flow is added while it runs.
  corners,
}

/// Orifice diameter (m) that passes [flow] (m³/s) at [head] (m):
/// q = Cd·(π/4)·d²·√(2gh).
double orificeDiameter({required double flow, required double head, double cd = 0.97}) {
  if (flow <= 0 || head <= 0 || cd <= 0) return 0;
  return math.sqrt(4 * flow / (math.pi * cd * math.sqrt(2 * gravity * head)));
}

/// Flow (m³/s) of an orifice of [diameter] (m) at [head] (m).
double orificeFlow({required double diameter, required double head, double cd = 0.97}) => diameter <= 0 || head <= 0 ? 0 : cd * math.pi / 4 * diameter * diameter * math.sqrt(2 * gravity * head);

/// Drive train of the last regular tower, for its speed at 100 % timer.
class TowerDrive {
  const TowerDrive({this.motorRpm = 0, this.centerGearRatio = 0, this.wheelGearRatio = 0, this.tyreRollingDiameterM = 0, this.speedMPerMin = 0});

  /// Motor speed (rpm), e.g. 1740 at 60 Hz or 1450 at 50 Hz.
  final double motorRpm;

  /// Reductions of the centre-drive gearbox (40 for 40:1) and of the wheel gearbox (52 for 52:1).
  final double centerGearRatio;
  final double wheelGearRatio;

  /// Rolling diameter of the tyre under load (m).
  final double tyreRollingDiameterM;

  /// Speed at 100 % given directly (m/min); overrides the drive train when positive.
  final double speedMPerMin;

  /// Speed of the tower with its motor running all the time (m/min): wheel
  /// revolutions per minute (rpm / (centre ratio × wheel ratio)) × π·D.
  double get speedAt100MPerMin {
    if (speedMPerMin > 0) return speedMPerMin;
    if (motorRpm <= 0 || centerGearRatio <= 0 || wheelGearRatio <= 0 || tyreRollingDiameterM <= 0) return 0;
    return motorRpm / (centerGearRatio * wheelGearRatio) * math.pi * tyreRollingDiameterM;
  }

  /// Rolling diameter (m) of a farm tyre given by its section-width × rim
  /// designation in inches (11.2-38): rim plus twice the section height
  /// ([aspectRatio] × width), times the loaded-to-free radius ratio
  /// [rollingFactor]. Both factors are typical of bias farm tyres; use the
  /// tyre maker's rolling circumference when known.
  static double tyreRollingDiameter({required double sectionWidthInch, required double rimDiameterInch, double aspectRatio = 0.95, double rollingFactor = 0.95}) =>
      (rimDiameterInch + 2 * aspectRatio * sectionWidthInch) * metersPerInch * rollingFactor;

  Map<String, dynamic> toJson() => {'rpm': motorRpm, 'g1': centerGearRatio, 'g2': wheelGearRatio, 'tyre': tyreRollingDiameterM, 'v': speedMPerMin};
  static TowerDrive fromJson(Map<String, dynamic> j) => TowerDrive(
    motorRpm: (j['rpm'] as num?)?.toDouble() ?? 0,
    centerGearRatio: (j['g1'] as num?)?.toDouble() ?? 0,
    wheelGearRatio: (j['g2'] as num?)?.toDouble() ?? 0,
    tyreRollingDiameterM: (j['tyre'] as num?)?.toDouble() ?? 0,
    speedMPerMin: (j['v'] as num?)?.toDouble() ?? 0,
  );
}

/// One span of the machine, or the overhang, as the package sees it.
class PivotSpanDef {
  const PivotSpanDef({
    required this.lengthM,
    this.pipeInnerMm = 162,
    this.hazenC = 130,
    this.roughnessMm = 0.15,
    this.outletSpacingM = 2.5,
    this.firstOutletM = -1,
    this.overhang = false,
    this.archM = 0,
  });

  /// Span length (m).
  final double lengthM;

  /// Span pipe: inner diameter (mm), Hazen-Williams C and roughness (mm).
  final double pipeInnerMm;
  final double hazenC;
  final double roughnessMm;

  /// Spacing of the outlets along this span (m).
  final double outletSpacingM;

  /// Distance of the first outlet from the start of the span (m); negative = half the spacing.
  final double firstOutletM;

  /// The overhang beyond the last tower (no tower at its end).
  final bool overhang;

  /// Rise of the pipe at mid-span above its ends (truss arch, m): the pipe
  /// height follows a parabola and the drops are longer in mid-span.
  final double archM;
}

/// Machine and package data for [designPivotPackage]. All values in SI.
class PivotPackageSpec {
  const PivotPackageSpec({
    required this.spans,
    this.kind = PivotKind.pivot,
    this.outletPositionsM = const [],
    this.endThrowM = 5,
    this.endGun = EndGunUse.none,
    this.endGunRadiusM = 0,
    this.endGunThrowFactor = 0.9,
    this.endGunFlow = 0,
    this.endGunPressureM = 0,
    this.endGunBooster = false,
    this.boosterEfficiency = 0.65,
    this.grossDepthMm = 8,
    this.hoursPerCycle = 24,
    this.systemFlow = 0,
    this.sectorDeg = 360,
    this.travelM = 0,
    this.method = FrictionMethod.hazenWilliams,
    this.kinematicViscosity = 1.004e-6,
    this.pipeHeightM = 3.5,
    this.machineLossM = 2,
    this.nozzlePressureM = 14,
    this.regulated = true,
    this.regulatorMarginM = 5 / psiPerMeterHead,
    this.nozzleHeightM = 0,
    this.dropInnerMm = 19,
    this.dropHazenC = 140,
    this.dropMinorK = 1.5,
    this.dischargeCoefficient = 0.97,
    this.nozzleStepM = metersPerInch / 128,
    this.minNozzleNumber = 2,
    this.maxNozzleNumber = 64,
    this.flowTolerance = 0.05,
    this.allowPlugging = true,
    this.availableInletHeadM = 0,
    this.drive = const TowerDrive(),
    this.timerSettings = defaultTimerSettings,
  });

  /// Package for a [PivotSpec] (the hydraulic data of a pivot entity): its
  /// regular spans and overhang with the span pipe and sprinkler spacing,
  /// the last-sprinkler throw, the depth per cycle and the end pressure as
  /// the nozzle pressure. An end gun with a given flow is a corner gun, as in
  /// [analyzePivot].
  factory PivotPackageSpec.fromPivot(PivotSpec p, {bool regulated = true, double nozzleHeightM = 0, TowerDrive drive = const TowerDrive(), double endGunRadiusM = 0, bool endGunBooster = false}) {
    final n = p.towerCount;
    PivotSpanDef span(double len, {bool overhang = false}) =>
        PivotSpanDef(lengthM: len, pipeInnerMm: p.pipeInnerMm, hazenC: p.hazenC, roughnessMm: p.roughnessMm, outletSpacingM: p.sprinklerSpacingM, overhang: overhang);
    final spans = n == 0 ? [span(p.lengthM)] : [for (var i = 0; i < n; i++) span(p.spanLengthM), if (p.overhangM > 1e-6) span(p.overhangM, overhang: true)];
    return PivotPackageSpec(
      spans: spans,
      kind: p.kind,
      endThrowM: p.endThrowM,
      endGun: p.endGunFlow > 0 ? EndGunUse.corners : EndGunUse.none,
      endGunFlow: p.endGunFlow,
      endGunPressureM: p.endGunPressureM,
      endGunRadiusM: endGunRadiusM,
      endGunBooster: endGunBooster,
      grossDepthMm: p.grossDepthMm,
      hoursPerCycle: p.hoursPerCycle,
      sectorDeg: p.sectorDeg,
      travelM: p.travelM,
      method: p.method,
      kinematicViscosity: p.kinematicViscosity,
      pipeHeightM: p.pipeHeightM,
      machineLossM: p.machineLossM,
      nozzlePressureM: p.endPressureM,
      regulated: regulated,
      nozzleHeightM: nozzleHeightM,
      drive: drive,
    );
  }

  /// Spans in order from the pivot point, the overhang last.
  final List<PivotSpanDef> spans;
  final PivotKind kind;

  /// Explicit outlet positions (m from the pivot point); empty = from the spans.
  final List<double> outletPositionsM;

  /// Throw of the last sprinkler beyond the pipe end (m).
  final double endThrowM;

  final EndGunUse endGun;

  /// Wetted radius of the end gun (m); 0 = from the catalogue gun nozzle.
  final double endGunRadiusM;

  /// Fraction of the gun radius that counts as irrigated (0.9, NEH 623 ch. 11).
  final double endGunThrowFactor;

  /// End gun flow (m³/s); 0 = its share of the area.
  final double endGunFlow;

  /// Pressure the gun needs at its base (m).
  final double endGunPressureM;

  /// A booster pump at the end raises the pressure for the gun, which then
  /// does not set the inlet pressure.
  final bool endGunBooster;
  final double boosterEfficiency;

  /// Gross depth (mm) per cycle of [hoursPerCycle] hours, for the system flow.
  final double grossDepthMm;
  final double hoursPerCycle;

  /// System flow (m³/s) given directly; overrides the depth and cycle when positive.
  final double systemFlow;

  /// Angle irrigated (pivot, degrees) and length of travel (linear, m).
  final double sectorDeg;
  final double travelM;

  final FrictionMethod method;
  final double kinematicViscosity;

  /// Height of the span pipe above the ground at the towers (m).
  final double pipeHeightM;

  /// Pivot elbow, swivel and tower joints (m).
  final double machineLossM;

  /// Regulated package: the target nozzle pressure, which picks the
  /// regulator rating; unregulated: the minimum pressure at every nozzle (m).
  final double nozzlePressureM;
  final bool regulated;

  /// Inlet pressure a regulator needs above its rating (m; 5 psi).
  final double regulatorMarginM;

  /// Height of the nozzles above the ground (m); 0 = on top of the pipe, no drops.
  final double nozzleHeightM;

  /// Drop hose inner diameter (mm), its Hazen-Williams C and the K of the gooseneck and fittings.
  final double dropInnerMm;
  final double dropHazenC;
  final double dropMinorK;

  /// Numbered nozzle series (used without catalogue nozzles): discharge
  /// coefficient, diameter step (m) and the range of numbers.
  final double dischargeCoefficient;
  final double nozzleStepM;
  final int minNozzleNumber;
  final int maxNozzleNumber;

  /// Allowed deviation of the delivered from the required flow (fraction),
  /// weighted by flow over the whole package.
  final double flowTolerance;

  /// Plug outlets that need less than half the smallest nozzle.
  final bool allowPlugging;

  /// Pressure available at the pivot point (m, ground level, from the
  /// mainline analysis); 0 = the required pressure.
  final double availableInletHeadM;

  final TowerDrive drive;

  /// Timer settings (%) of the timer chart.
  final List<double> timerSettings;

  /// Pipe length from the pivot point to the end of the overhang (m).
  double get pipeLengthM => spans.fold(0.0, (s, e) => s + math.max(e.lengthM, 0.0));

  /// Distance from the pivot point to the last regular tower (m).
  double get lastTowerRadiusM {
    final r = spans.where((e) => !e.overhang).fold(0.0, (s, e) => s + math.max(e.lengthM, 0.0));
    return r > 0 ? r : pipeLengthM;
  }

  /// Outlet positions (m), sorted: [outletPositionsM] when given, otherwise
  /// every span from its first outlet at its own spacing.
  List<double> outletPositions() {
    final length = pipeLengthM;
    if (outletPositionsM.isNotEmpty) {
      return [
        for (final r in [...outletPositionsM]..sort())
          if (r > 0 && r <= length + 1e-9) r,
      ];
    }
    final out = <double>[];
    var start = 0.0;
    for (final sp in spans) {
      final len = math.max(sp.lengthM, 0.0);
      final step = sp.outletSpacingM;
      if (len > 0 && step > 0) {
        final first = sp.firstOutletM >= 0 ? sp.firstOutletM : step / 2;
        for (var k = 0; ; k++) {
          final r = start + first + k * step;
          if (r > start + len + 1e-9) break;
          // an outlet on a tower joint belongs to one span only
          if (r > 1e-9 && (out.isEmpty || r > out.last + 1e-6)) out.add(r);
        }
      }
      start += len;
    }
    return out;
  }
}

/// One outlet of the sprinkler chart.
class PivotOutletRow {
  const PivotOutletRow({
    required this.number,
    required this.span,
    required this.distanceM,
    required this.spacingM,
    required this.servedWidthM,
    required this.requiredFlow,
    required this.deliveredFlow,
    required this.pipePressureM,
    required this.nozzlePressureM,
    this.regulatorM = 0,
    this.nozzle = '',
    this.nozzleNumber = 0,
    this.nozzleDiameterMm = 0,
    this.dropLengthM = 0,
    this.plugged = false,
  });

  /// Outlet number from the pivot point (1, 2, …) and its span (1-based; the overhang is the last).
  final int number;
  final int span;

  /// Distance from the pivot point (m), distance from the previous sprinkler
  /// (or from the pivot point; m) and width of the ring it waters (m).
  final double distanceM;
  final double spacingM;
  final double servedWidthM;

  /// Flow the outlet must deliver and the flow of the chosen nozzle at its pressure (m³/s).
  final double requiredFlow;
  final double deliveredFlow;

  /// Pressure in the span pipe and at the nozzle, design position (m).
  final double pipePressureM;
  final double nozzlePressureM;

  /// Regulator rating (m; 0 = none).
  final double regulatorM;

  /// Catalogue nozzle id, or the number of the series (d = number × step) with its diameter.
  final String nozzle;
  final int nozzleNumber;
  final double nozzleDiameterMm;
  final double dropLengthM;

  /// No sprinkler on this outlet: its ring is watered by the next one.
  final bool plugged;

  Map<String, dynamic> toJson() => {
    'n': number,
    'sp': span,
    'r': distanceM,
    's': spacingM,
    'w': servedWidthM,
    'q': requiredFlow,
    'qd': deliveredFlow,
    'hp': pipePressureM,
    'hn': nozzlePressureM,
    if (regulatorM > 0) 'reg': regulatorM,
    if (nozzle.isNotEmpty) 'noz': nozzle,
    if (nozzleNumber > 0) 'num': nozzleNumber,
    if (nozzleDiameterMm > 0) 'dmm': nozzleDiameterMm,
    if (dropLengthM > 0) 'drop': dropLengthM,
    if (plugged) 'plug': true,
  };
  static PivotOutletRow fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PivotOutletRow(
      number: (j['n'] as num?)?.toInt() ?? 0,
      span: (j['sp'] as num?)?.toInt() ?? 0,
      distanceM: d('r'),
      spacingM: d('s'),
      servedWidthM: d('w'),
      requiredFlow: d('q'),
      deliveredFlow: d('qd'),
      pipePressureM: d('hp'),
      nozzlePressureM: d('hn'),
      regulatorM: d('reg'),
      nozzle: j['noz'] as String? ?? '',
      nozzleNumber: (j['num'] as num?)?.toInt() ?? 0,
      nozzleDiameterMm: d('dmm'),
      dropLengthM: d('drop'),
      plugged: j['plug'] as bool? ?? false,
    );
  }
}

/// Summary of one span of the package.
class PivotPackageSpanRow {
  const PivotPackageSpanRow({
    required this.index,
    required this.startM,
    required this.endM,
    required this.outlets,
    required this.requiredFlow,
    required this.deliveredFlow,
    required this.pipeInnerMm,
    required this.pressureStartM,
    required this.pressureEndM,
    required this.frictionLossM,
    this.overhang = false,
  });

  /// 1-based span index; the overhang is the last.
  final int index;
  final double startM;
  final double endM;

  /// Sprinklers on the span (plugged outlets left out).
  final int outlets;

  /// Required and delivered flow of the span's sprinklers (m³/s).
  final double requiredFlow;
  final double deliveredFlow;
  final double pipeInnerMm;

  /// Pipe pressure at the start and end of the span, design position (m).
  final double pressureStartM;
  final double pressureEndM;
  final double frictionLossM;
  final bool overhang;

  Map<String, dynamic> toJson() => {
    'i': index,
    'r0': startM,
    'r1': endM,
    'n': outlets,
    'q': requiredFlow,
    'qd': deliveredFlow,
    'dmm': pipeInnerMm,
    'h0': pressureStartM,
    'h1': pressureEndM,
    'hf': frictionLossM,
    if (overhang) 'oh': true,
  };
  static PivotPackageSpanRow fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return PivotPackageSpanRow(
      index: (j['i'] as num?)?.toInt() ?? 0,
      startM: d('r0'),
      endM: d('r1'),
      outlets: (j['n'] as num?)?.toInt() ?? 0,
      requiredFlow: d('q'),
      deliveredFlow: d('qd'),
      pipeInnerMm: d('dmm'),
      pressureStartM: d('h0'),
      pressureEndM: d('h1'),
      frictionLossM: d('hf'),
      overhang: j['oh'] as bool? ?? false,
    );
  }
}

/// One line of the timer chart.
class PivotTimerRow {
  const PivotTimerRow({required this.timerPct, required this.hours, required this.depthMm, required this.speedMPerMin});

  /// Percent-timer setting, hours per revolution (or per pass), gross depth (mm) and average speed of the last tower (m/min).
  final double timerPct;
  final double hours;
  final double depthMm;
  final double speedMPerMin;

  Map<String, dynamic> toJson() => {'p': timerPct, 'h': hours, 'd': depthMm, 'v': speedMPerMin};
  static PivotTimerRow fromJson(Map<String, dynamic> j) =>
      PivotTimerRow(timerPct: (j['p'] as num).toDouble(), hours: (j['h'] as num).toDouble(), depthMm: (j['d'] as num).toDouble(), speedMPerMin: (j['v'] as num?)?.toDouble() ?? 0);
}

/// Sprinkler chart, span summary and timer chart of a machine.
class PivotPackageResult {
  PivotPackageResult({
    required this.pivotId,
    required this.kind,
    required this.systemFlow,
    required this.designFlow,
    required this.deliveredFlow,
    required this.endGunFlow,
    required this.effectiveRadiusM,
    required this.inletHeadM,
    required this.requiredInletHeadM,
    required this.frictionLossM,
    required this.endPressureM,
    required this.lastTowerRadiusM,
    required this.outlets,
    required this.spans,
    required this.timer,
    required this.warnings,
    this.gunNozzle = '',
    this.gunRadiusM = 0,
    this.regulatorM = 0,
    this.regulatorId = '',
    this.boosterHeadM = 0,
    this.boosterPowerKw = 0,
    this.speedAt100MPerMin = 0,
    this.hoursAt100 = 0,
    this.depthAt100Mm = 0,
  });

  final String pivotId;
  final PivotKind kind;

  /// Flow of the area the package waters (m³/s): depth × area / cycle time,
  /// or the given system flow; includes a full-circle end gun.
  final double systemFlow;

  /// Inlet flow with every outlet at its required flow and the gun on (m³/s).
  final double designFlow;

  /// Inlet flow with the chosen nozzles at their pressures, gun included (m³/s).
  final double deliveredFlow;
  final double endGunFlow;
  final String gunNozzle;
  final double gunRadiusM;

  /// Effective irrigated radius (pivot) or length (linear), m.
  final double effectiveRadiusM;

  /// Pressure head at the pivot point at ground level (m): the available one
  /// when given, otherwise the required one.
  final double inletHeadM;
  final double requiredInletHeadM;

  /// Friction from the pivot point to the pipe end (m).
  final double frictionLossM;

  /// Pipe pressure at the pipe end in the design position (m).
  final double endPressureM;

  /// Regulator rating (m; 0 = unregulated) and catalogue regulator id.
  final double regulatorM;
  final String regulatorId;

  /// Head and shaft power of the end-gun booster pump (m, kW).
  final double boosterHeadM;
  final double boosterPowerKw;

  final double lastTowerRadiusM;

  /// Last-tower speed (m/min), hours per revolution (or pass) and gross depth (mm) at 100 % timer.
  final double speedAt100MPerMin;
  final double hoursAt100;
  final double depthAt100Mm;

  final List<PivotOutletRow> outlets;
  final List<PivotPackageSpanRow> spans;
  final List<PivotTimerRow> timer;

  /// Message codes (`pivot_pkg_*`, with `:<id>` when an id was given).
  final List<String> warnings;

  /// Sprinklers on the machine (plugged outlets left out).
  int get sprinklerCount => outlets.where((o) => !o.plugged).length;

  /// Gross depth (mm) at a timer setting (%).
  double depthAtTimer(double pct) => pct > 0 ? depthAt100Mm * 100 / pct : 0;

  /// Timer setting (%) that applies [depthMm]: 100·d100/d, at most 100.
  double timerForDepth(double depthMm) => depthMm > 0 && depthAt100Mm > 0 ? math.min(100.0, 100 * depthAt100Mm / depthMm) : 0;

  Map<String, dynamic> toJson() => {
    'id': pivotId,
    'kind': kind.name,
    'qs': systemFlow,
    'qd': designFlow,
    'qdel': deliveredFlow,
    'qg': endGunFlow,
    if (gunNozzle.isNotEmpty) 'gnoz': gunNozzle,
    'rg': gunRadiusM,
    're': effectiveRadiusM,
    'hin': inletHeadM,
    'hreq': requiredInletHeadM,
    'hf': frictionLossM,
    'hend': endPressureM,
    'reg': regulatorM,
    if (regulatorId.isNotEmpty) 'regid': regulatorId,
    'hb': boosterHeadM,
    'pb': boosterPowerKw,
    'rlast': lastTowerRadiusM,
    'v100': speedAt100MPerMin,
    't100': hoursAt100,
    'd100': depthAt100Mm,
    'outlets': outlets.map((o) => o.toJson()).toList(),
    'spans': spans.map((o) => o.toJson()).toList(),
    'timer': timer.map((o) => o.toJson()).toList(),
    'warn': warnings,
  };
  static PivotPackageResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => ((j[k] as List?) ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();
    return PivotPackageResult(
      pivotId: j['id'] as String? ?? '',
      kind: PivotKind.values.byName(j['kind'] as String? ?? 'pivot'),
      systemFlow: d('qs'),
      designFlow: d('qd'),
      deliveredFlow: d('qdel'),
      endGunFlow: d('qg'),
      gunNozzle: j['gnoz'] as String? ?? '',
      gunRadiusM: d('rg'),
      effectiveRadiusM: d('re'),
      inletHeadM: d('hin'),
      requiredInletHeadM: d('hreq'),
      frictionLossM: d('hf'),
      endPressureM: d('hend'),
      regulatorM: d('reg'),
      regulatorId: j['regid'] as String? ?? '',
      boosterHeadM: d('hb'),
      boosterPowerKw: d('pb'),
      lastTowerRadiusM: d('rlast'),
      speedAt100MPerMin: d('v100'),
      hoursAt100: d('t100'),
      depthAt100Mm: d('d100'),
      outlets: list('outlets', PivotOutletRow.fromJson),
      spans: list('spans', PivotPackageSpanRow.fromJson),
      timer: list('timer', PivotTimerRow.fromJson),
      warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

NozzleSpec? _closestNozzle(List<NozzleSpec> list, double head, double flow) {
  NozzleSpec? best;
  var bestDiff = double.infinity;
  for (final nz in list) {
    final diff = (nz.curve.flow(math.max(head, 1e-6)) - flow).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = nz;
    }
  }
  return best;
}

/// Sprinkler package of a machine: flow, pressure, regulator, drop and
/// nozzle of every outlet, the span summary and the timer chart.
///
/// [nozzles] are the nozzles of the catalogue sprinkler (empty: the numbered
/// orifice series); [regulators] the catalogue pressure regulators
/// (PRV items, the rating being their setting; empty: the standard list);
/// [gunNozzles] the nozzles of the catalogue end gun. [designRiseAt] gives
/// the ground rise (m) at a distance from the pivot point in the position the
/// nozzles are sized for (default level); [worstRiseAt] the rise in the
/// highest position, which sets the inlet pressure (default the design one).
PivotPackageResult designPivotPackage(
  PivotPackageSpec s, {
  String id = '',
  List<NozzleSpec> nozzles = const [],
  List<ValveSpec> regulators = const [],
  List<NozzleSpec> gunNozzles = const [],
  double Function(double distance)? designRiseAt,
  double Function(double distance)? worstRiseAt,
}) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  final pivot = s.kind == PivotKind.pivot;
  final designRise = designRiseAt ?? (double _) => 0.0;
  final worstRise = worstRiseAt ?? designRise;
  final length = s.pipeLengthM;
  final sector = s.sectorDeg.clamp(1.0, 360.0) / 360;
  final spanStart = <double>[];
  var acc = 0.0;
  for (final sp in s.spans) {
    spanStart.add(acc);
    acc += math.max(sp.lengthM, 0.0);
  }
  int spanAt(double r) {
    for (var j = s.spans.length - 1; j > 0; j--) {
      if (r > spanStart[j] + 1e-9) return j;
    }
    return 0;
  }

  double pipeHeightAt(double r) {
    if (s.spans.isEmpty) return s.pipeHeightM;
    final j = spanAt(r);
    final len = s.spans[j].lengthM;
    if (len <= 0) return s.pipeHeightM;
    final t = ((r - spanStart[j]) / len).clamp(0.0, 1.0);
    return s.pipeHeightM + s.spans[j].archM * 4 * t * (1 - t);
  }

  double gradient(double flow, PivotSpanDef sp) {
    final d = sp.pipeInnerMm / 1000;
    if (flow <= 0 || d <= 0) return 0;
    return switch (s.method) {
      FrictionMethod.hazenWilliams => hazenWilliamsLoss(flow: flow, diameter: d, length: 1, c: sp.hazenC),
      FrictionMethod.darcyWeisbach => darcyWeisbachLoss(flow: flow, diameter: d, length: 1, roughness: sp.roughnessMm / 1000, kinematicViscosity: s.kinematicViscosity),
      // galvanised steel span pipe
      FrictionMethod.scobey => scobeyLoss(flow: flow, diameter: d, length: 1, ks: 0.42),
      FrictionMethod.manning => manningLoss(flow: flow, diameter: d, length: 1, n: 0.012),
    };
  }

  // friction between two distances with a constant flow, span pipe by span pipe
  double pipeLoss(double a, double b, double flow) {
    if (b <= a || flow <= 0) return 0;
    var hf = 0.0;
    for (var j = 0; j < s.spans.length; j++) {
      final lo = math.max(a, spanStart[j]), hi = math.min(b, spanStart[j] + math.max(s.spans[j].lengthM, 0.0));
      if (hi > lo) hf += gradient(flow, s.spans[j]) * (hi - lo);
    }
    return hf;
  }

  final positions = s.outletPositions();
  final n = positions.length;
  if (n == 0) warn('pivot_pkg_no_outlets');

  // effective radius, system flow and end gun (the gun radius may come from
  // its catalogue nozzle, whose choice depends on the gun flow)
  final gunOn = s.endGun != EndGunUse.none;
  var gunRadius = s.endGunRadiusM;
  NozzleSpec? gunNozzle;
  double effRadius() => s.endGun == EndGunUse.fullCircle && gunRadius > 0 ? length + s.endGunThrowFactor * gunRadius : length + math.max(s.endThrowM, 0.0);
  double areaOf(double re) => pivot ? math.pi * re * re * sector : re * math.max(s.travelM, 0.0);
  var re = effRadius();
  double sysFlow() => s.systemFlow > 0 ? s.systemFlow : (s.hoursPerCycle > 0 ? areaOf(re) * s.grossDepthMm / 1000 / (s.hoursPerCycle * 3600) : 0.0);
  var qs = sysFlow();
  double share(double lo, double hi) => re <= 0 || hi <= lo ? 0.0 : (pivot ? (hi * hi - lo * lo) / (re * re) : (hi - lo) / re);
  double gunFlowFor() {
    if (!gunOn) return 0;
    if (s.endGunFlow > 0) return s.endGunFlow;
    if (s.endGun == EndGunUse.fullCircle) return gunRadius > 0 ? qs * share(length, re) : 0;
    final outer = length + s.endGunThrowFactor * gunRadius;
    return gunRadius > 0 ? qs * share(re, outer) : 0;
  }

  var qGun = gunFlowFor();
  if (gunOn && gunNozzles.isNotEmpty) {
    for (var it = 0; it < 8; it++) {
      final pick = _closestNozzle(gunNozzles, s.endGunPressureM, qGun);
      final changed = pick?.id != gunNozzle?.id;
      gunNozzle = pick;
      if (s.endGunRadiusM <= 0 && pick != null) gunRadius = pick.curve.radius(s.endGunPressureM);
      re = effRadius();
      qs = sysFlow();
      qGun = gunFlowFor();
      if (!changed) break;
    }
  }
  if (gunOn && qGun <= 0) warn('pivot_pkg_gun_undefined');
  if (qs <= 0) warn('pivot_pkg_no_flow');
  final coverEnd = s.endGun == EndGunUse.fullCircle && gunRadius > 0 ? length : re;

  // regulator rating nearest the target nozzle pressure
  var rating = 0.0;
  var regulatorId = '';
  if (s.regulated) {
    final cat = [
      for (final v in regulators)
        if (v.enabled && v.kind == ValveKind.prv && v.defaultSettingM > 0) v,
    ];
    if (cat.isNotEmpty) {
      final v = cat.reduce((a, b) => (a.defaultSettingM - s.nozzlePressureM).abs() <= (b.defaultSettingM - s.nozzlePressureM).abs() ? a : b);
      rating = v.defaultSettingM;
      regulatorId = v.id;
    } else {
      rating = standardRegulatorRatingsPsi.map((p) => p / psiPerMeterHead).reduce((a, b) => (a - s.nozzlePressureM).abs() <= (b - s.nozzlePressureM).abs() ? a : b);
    }
  }

  double dropLengthAt(double r) => s.nozzleHeightM > 0 ? math.max(0.0, pipeHeightAt(r) - s.nozzleHeightM) : 0.0;
  double dropLoss(double q, double drop) {
    final d = s.dropInnerMm / 1000;
    if (q <= 0 || d <= 0) return 0;
    return hazenWilliamsLoss(flow: q, diameter: d, length: drop, c: s.dropHazenC) + minorLoss(k: s.dropMinorK, flow: q, diameter: d);
  }

  final useCatalogue = nozzles.isNotEmpty;
  final cd = s.dischargeCoefficient;
  final minNum = math.max(1, s.minNozzleNumber), maxNum = math.max(minNum, s.maxNozzleNumber);
  double smallestFlow(double head) => useCatalogue ? nozzles.map((nz) => nz.curve.flow(math.max(head, 1e-6))).reduce(math.min) : orificeFlow(diameter: minNum * s.nozzleStepM, head: head, cd: cd);
  final drops = [for (final r in positions) dropLengthAt(r)];
  final req = List<double>.filled(n, 0);
  final plugged = List<bool>.filled(n, false);
  final hf = List<double>.filled(n, 0);
  final upper = [for (var i = 0; i < n; i++) i == n - 1 ? math.max(coverEnd, positions[i]) : (positions[i] + positions[i + 1]) / 2];
  var hfEnd = 0.0, inletNeed = 0.0, inlet = 0.0;
  final need = s.regulated ? rating + s.regulatorMarginM : s.nozzlePressureM;

  void hydraulics() {
    var flow = req.fold(0.0, (a, b) => a + b) + qGun;
    var x = 0.0, h = 0.0;
    for (var i = 0; i < n; i++) {
      h += pipeLoss(x, positions[i], flow);
      hf[i] = h;
      flow -= req[i];
      x = positions[i];
    }
    hfEnd = h + pipeLoss(x, length, math.max(flow, 0.0));
    inletNeed = 0;
    for (var i = 0; i < n; i++) {
      if (plugged[i]) continue;
      final atPipe = need - drops[i] + dropLoss(req[i], drops[i]);
      inletNeed = math.max(inletNeed, atPipe + pipeHeightAt(positions[i]) + hf[i] + worstRise(positions[i]));
    }
    if (gunOn && qGun > 0 && !s.endGunBooster) inletNeed = math.max(inletNeed, s.endGunPressureM + pipeHeightAt(length) + hfEnd + worstRise(length));
    inletNeed += s.machineLossM;
    inlet = s.availableInletHeadM > 0 ? s.availableInletHeadM : inletNeed;
  }

  double nozzleInlet(int i, double rise) => inlet - s.machineLossM - pipeHeightAt(positions[i]) - hf[i] - rise + drops[i] - dropLoss(req[i], drops[i]);
  double nozzleHead(double atInlet) => s.regulated ? math.min(rating, atInlet - s.regulatorMarginM) : atInlet;

  // required flows: a sweep from the pivot point that plugs the outlets
  // needing less than half the smallest nozzle at their pressure
  void sweep(bool plug) {
    var lo = 0.0;
    for (var i = 0; i < n; i++) {
      final q = qs * share(lo, upper[i]);
      final head = nozzleHead(nozzleInlet(i, designRise(positions[i])));
      plugged[i] = plug && s.allowPlugging && i < n - 1 && q < 0.5 * smallestFlow(head);
      req[i] = plugged[i] ? 0 : q;
      if (!plugged[i]) lo = upper[i];
    }
  }

  sweep(false);
  hydraulics();
  for (var pass = 0; pass < 3; pass++) {
    final before = List.of(plugged);
    sweep(true);
    hydraulics();
    var same = true;
    for (var i = 0; i < n; i++) {
      if (before[i] != plugged[i]) same = false;
    }
    if (same) break;
  }
  if (s.availableInletHeadM > 0 && s.availableInletHeadM < inletNeed - 1e-6) warn('pivot_pkg_pressure_deficit');

  // nozzle of every outlet
  final rows = <PivotOutletRow>[];
  var lastActive = 0.0, lo = 0.0;
  var delivered = 0.0;
  // flow-weighted deviation of the nozzles from their requirement: the
  // outlets near the pivot point serve little area, and rounding their
  // small nozzles up (or to the smallest of the series) is accepted practice
  var devSum = 0.0, reqSum = 0.0;
  for (var i = 0; i < n; i++) {
    final r = positions[i];
    final pipeHead = inlet - s.machineLossM - pipeHeightAt(r) - hf[i] - designRise(r);
    final atInlet = nozzleInlet(i, designRise(r));
    final worstInlet = nozzleInlet(i, worstRise(r));
    if (plugged[i]) {
      rows.add(
        PivotOutletRow(
          number: i + 1,
          span: spanAt(r) + 1,
          distanceM: r,
          spacingM: 0,
          servedWidthM: 0,
          requiredFlow: 0,
          deliveredFlow: 0,
          pipePressureM: pipeHead,
          nozzlePressureM: 0,
          dropLengthM: drops[i],
          plugged: true,
        ),
      );
      continue;
    }
    final head = nozzleHead(atInlet);
    if (s.regulated && worstInlet < rating + s.regulatorMarginM - 1e-6) warn('pivot_pkg_regulator_starved');
    if (!s.regulated && worstInlet < s.nozzlePressureM - 1e-6) warn('pivot_pkg_low_pressure');
    var nozzleId = '';
    var number = 0;
    var diameterMm = 0.0;
    var q = 0.0;
    if (head <= 0) {
      warn('pivot_pkg_no_pressure');
    } else if (useCatalogue) {
      final nz = _closestNozzle(nozzles, head, req[i])!;
      nozzleId = nz.id;
      q = nz.curve.flow(head);
      if (head < nz.minHeadM - 1e-6 || head > nz.maxHeadM + 1e-6) warn('pivot_pkg_nozzle_range');
      final largest = nozzles.map((e) => e.curve.flow(head)).reduce(math.max);
      if (req[i] > largest * (1 + s.flowTolerance)) warn('pivot_pkg_nozzle_max');
    } else {
      final dReq = orificeDiameter(flow: req[i], head: head, cd: cd);
      final raw = (dReq / s.nozzleStepM).round();
      if (raw > maxNum) warn('pivot_pkg_nozzle_max');
      number = raw.clamp(minNum, maxNum).toInt();
      diameterMm = number * s.nozzleStepM * 1000;
      q = orificeFlow(diameter: number * s.nozzleStepM, head: head, cd: cd);
    }
    if (req[i] > 0) {
      devSum += (q - req[i]).abs();
      reqSum += req[i];
    }
    delivered += q;
    rows.add(
      PivotOutletRow(
        number: i + 1,
        span: spanAt(r) + 1,
        distanceM: r,
        spacingM: r - lastActive,
        servedWidthM: upper[i] - lo,
        requiredFlow: req[i],
        deliveredFlow: q,
        pipePressureM: pipeHead,
        nozzlePressureM: math.max(head, 0.0),
        regulatorM: rating,
        nozzle: nozzleId,
        nozzleNumber: number,
        nozzleDiameterMm: diameterMm,
        dropLengthM: drops[i],
      ),
    );
    lastActive = r;
    lo = upper[i];
  }
  if (reqSum > 0 && devSum / reqSum > s.flowTolerance) warn('pivot_pkg_flow_dev');

  // end gun: pressure at the pipe end, booster and the gun nozzle
  final endPressure = inlet - s.machineLossM - pipeHeightAt(length) - hfEnd - designRise(length);
  final endWorst = inlet - s.machineLossM - pipeHeightAt(length) - hfEnd - worstRise(length);
  var boosterHead = 0.0, boosterKw = 0.0, gunDelivered = qGun;
  if (gunOn && qGun > 0) {
    if (s.endGunBooster) {
      boosterHead = math.max(0.0, s.endGunPressureM - endWorst);
      boosterKw = shaftPower(flow: qGun, head: boosterHead, efficiency: s.boosterEfficiency) / 1000;
    }
    if (gunNozzle != null) gunDelivered = gunNozzle.curve.flow(s.endGunBooster ? s.endGunPressureM : math.max(endPressure, 0.0));
  }
  final designFlow = req.fold(0.0, (a, b) => a + b) + qGun;

  // span summary
  double hfAt(double r) {
    var flow = designFlow, x = 0.0, h = 0.0;
    for (var i = 0; i < n && positions[i] < r; i++) {
      h += pipeLoss(x, positions[i], flow);
      flow -= req[i];
      x = positions[i];
    }
    return h + pipeLoss(x, r, math.max(flow, 0.0));
  }

  double pressureAt(double r) => inlet - s.machineLossM - pipeHeightAt(r) - hfAt(r) - designRise(r);
  final spanRows = <PivotPackageSpanRow>[];
  for (var j = 0; j < s.spans.length; j++) {
    final a = spanStart[j], b = a + math.max(s.spans[j].lengthM, 0.0);
    final inSpan = rows.where((o) => !o.plugged && o.span == j + 1);
    final hfa = hfAt(a), hfb = hfAt(b);
    spanRows.add(
      PivotPackageSpanRow(
        index: j + 1,
        startM: a,
        endM: b,
        outlets: inSpan.length,
        requiredFlow: inSpan.fold(0.0, (t, o) => t + o.requiredFlow),
        deliveredFlow: inSpan.fold(0.0, (t, o) => t + o.deliveredFlow),
        pipeInnerMm: s.spans[j].pipeInnerMm,
        pressureStartM: pressureAt(a),
        pressureEndM: pressureAt(b),
        frictionLossM: hfb - hfa,
        overhang: s.spans[j].overhang,
      ),
    );
  }

  // timer chart
  final v100 = s.drive.speedAt100MPerMin;
  final rLast = s.lastTowerRadiusM;
  final timer = <PivotTimerRow>[];
  var hours100 = 0.0, depth100 = 0.0;
  if (v100 > 0 && qs > 0) {
    final path = pivot ? 2 * math.pi * rLast * sector : math.max(s.travelM, 0.0);
    hours100 = path / v100 / 60;
    final area = areaOf(re);
    depth100 = area > 0 ? qs * hours100 * 3600 / area * 1000 : 0.0;
    for (final p in s.timerSettings) {
      if (p > 0 && p <= 100) timer.add(PivotTimerRow(timerPct: p, hours: hours100 * 100 / p, depthMm: depth100 * 100 / p, speedMPerMin: v100 * p / 100));
    }
  } else if (v100 <= 0) {
    warn('pivot_pkg_no_drive');
  }

  return PivotPackageResult(
    pivotId: id,
    kind: s.kind,
    systemFlow: qs,
    designFlow: designFlow,
    deliveredFlow: delivered + gunDelivered,
    endGunFlow: qGun,
    gunNozzle: gunNozzle?.id ?? '',
    gunRadiusM: gunRadius,
    effectiveRadiusM: re,
    inletHeadM: inlet,
    requiredInletHeadM: inletNeed,
    frictionLossM: hfEnd,
    endPressureM: endPressure,
    regulatorM: rating,
    regulatorId: regulatorId,
    boosterHeadM: boosterHead,
    boosterPowerKw: boosterKw,
    lastTowerRadiusM: rLast,
    speedAt100MPerMin: v100,
    hoursAt100: hours100,
    depthAt100Mm: depth100,
    outlets: rows,
    spans: spanRows,
    timer: timer,
    warnings: warnings,
  );
}
