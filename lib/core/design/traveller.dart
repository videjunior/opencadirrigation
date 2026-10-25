/// Travelling gun (hose reel / hose-fed traveller): lane (towpath) spacing,
/// gross depth and travel speed, time per lane and per cycle, area per lane,
/// hose friction, inlet pressure and power.
///
/// * Lane spacing as a percentage of the wetted diameter by wind class
///   (NRCS NEH 623 ch. 11, table 11-31): no wind 80 %; wind up to 5 mph
///   (2.2 m/s) 70 % with ring nozzles and 75 % with tapered nozzles; up to
///   10 mph (4.5 m/s) 60–65 %; stronger winds 50–55 %. With a field width the
///   number of lanes is rounded up and the spacing evened out, never wider
///   than the table (NEH 623 ch. 11, sample calculation 11-17).
/// * Gross depth d = q/(S·v) and the speed for a target depth v = q/(S·d)
///   (NEH 623 ch. 11, eq. 11-40; Keller & Bliesner 1990, ch. 8).
/// * Application rate under the gun I = q/(π·(0.9·R)²·θ/360), the wetted
///   area taken on 90 % of the radius (NEH 623 ch. 11, eq. 11-39).
/// * Hose friction along the whole hose (the water also runs through the
///   coils left on the drum), Hazen-Williams or Darcy-Weisbach for PE; the
///   turbine/drive and drum losses are the maker's value (NEH 623 ch. 11
///   notes they usually exceed 10 psi with turbine drives).
/// * Inlet pressure at the hydrant = gun pressure + hose friction + drive
///   loss + gun height + ground rise; power P = ρ·g·q·H/η.
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../hydraulics/pump.dart';
import '../model/catalog.dart';

/// Wind classes of NEH 623 ch. 11, table 11-31.
enum WindClass {
  /// No wind (calm, below 0.3 m/s, Beaufort 0).
  none,

  /// Up to 5 mph (2.24 m/s).
  light,

  /// Up to 10 mph (4.47 m/s).
  moderate,

  /// Over 10 mph.
  strong,
}

/// Wind class of an average wind speed (m/s).
WindClass windClassOf(double windMs) => windMs < 0.3 ? WindClass.none : (windMs <= 2.2352 ? WindClass.light : (windMs <= 4.4704 ? WindClass.moderate : WindClass.strong));

/// Lane spacing as a percentage of the wetted diameter (NEH 623 ch. 11,
/// table 11-31): the higher value for tapered nozzles, the lower for ring nozzles.
double laneSpacingPercent(WindClass wind, {bool taperedNozzle = true}) => switch (wind) {
  WindClass.none => 80,
  WindClass.light => taperedNozzle ? 75 : 70,
  WindClass.moderate => taperedNozzle ? 65 : 60,
  WindClass.strong => taperedNozzle ? 55 : 50,
};

/// Flow (m³/s) and wetted diameter (m) of a catalogue gun nozzle at [pressureM].
(double, double) gunPerformance(NozzleSpec nozzle, double pressureM) => (nozzle.curve.flow(pressureM), 2 * nozzle.curve.radius(pressureM));

/// Travelling gun data for [analyzeTraveller]. All values in SI.
class TravellerSpec {
  const TravellerSpec({
    required this.gunFlow,
    required this.gunPressureM,
    required this.wettedDiameterM,
    this.sectorDeg = 360,
    this.hoseLengthM = 300,
    this.hoseInnerMm = 100,
    this.hoseHazenC = 150,
    this.method = FrictionMethod.hazenWilliams,
    this.hoseRoughnessMm = 0.007,
    this.kinematicViscosity = 1.004e-6,
    this.driveLossM = 7,
    this.gunHeightM = 0,
    this.groundRiseM = 0,
    this.wind = WindClass.light,
    this.taperedNozzle = true,
    this.laneSpacingM = 0,
    this.laneLengthM = 0,
    this.fieldWidthM = 0,
    this.targetDepthMm = 0,
    this.speedMPerMin = 0,
    this.setupHours = 0.5,
    this.hoursPerDay = 22,
    this.pumpEfficiency = 0.7,
    this.soilIntakeMmH = 0,
    this.minSpeedMPerMin = 0,
    this.maxSpeedMPerMin = 0,
  });

  /// Gun flow (m³/s), pressure at the gun (m) and wetted diameter (m).
  final double gunFlow;
  final double gunPressureM;
  final double wettedDiameterM;

  /// Part of the circle the gun waters (degrees; a dry wedge over the lane makes it less than 360).
  final double sectorDeg;

  /// Hose length (m), inner diameter (mm) and friction data (PE).
  final double hoseLengthM;
  final double hoseInnerMm;
  final double hoseHazenC;
  final FrictionMethod method;
  final double hoseRoughnessMm;
  final double kinematicViscosity;

  /// Loss of the turbine or drive and of the drum (m), maker's value.
  final double driveLossM;

  /// Height of the gun above the hydrant (m) and ground rise from the hydrant to the farthest gun position (m).
  final double gunHeightM;
  final double groundRiseM;

  final WindClass wind;
  final bool taperedNozzle;

  /// Lane spacing given (m); 0 = from the wind table.
  final double laneSpacingM;

  /// Run length of the gun along a lane (m); 0 = the hose length.
  final double laneLengthM;

  /// Field width across the lanes (m); 0 = a single lane.
  final double fieldWidthM;

  /// Target gross depth (mm), which sets the speed; otherwise the given speed (m/min).
  final double targetDepthMm;
  final double speedMPerMin;

  /// Time to move and set up between lanes (h) and operating hours per day.
  final double setupHours;
  final double hoursPerDay;

  final double pumpEfficiency;

  /// Soil intake limit (mm/h; 0 = no check) and the machine's speed range (m/min; 0 = no limit).
  final double soilIntakeMmH;
  final double minSpeedMPerMin;
  final double maxSpeedMPerMin;
}

/// Lane, depth, time, friction and power of a travelling gun.
class TravellerResult {
  const TravellerResult({
    required this.laneSpacingM,
    required this.laneSpacingPct,
    required this.recommendedPct,
    required this.lanes,
    required this.laneLengthM,
    required this.speedMPerMin,
    required this.grossDepthMm,
    required this.travelHours,
    required this.laneHours,
    required this.cycleHours,
    required this.cycleDays,
    required this.areaPerLaneM2,
    required this.volumePerLaneM3,
    required this.applicationRateMmH,
    required this.hoseFrictionM,
    required this.hoseVelocity,
    required this.inletHeadM,
    required this.hydraulicPowerKw,
    required this.shaftPowerKw,
    required this.warnings,
  });

  /// Lane spacing (m), as a percentage of the wetted diameter, and the table value.
  final double laneSpacingM;
  final double laneSpacingPct;
  final double recommendedPct;

  /// Lanes across the field (1 without a field width) and run length (m).
  final int lanes;
  final double laneLengthM;

  /// Travel speed (m/min) and gross depth (mm).
  final double speedMPerMin;
  final double grossDepthMm;

  /// Hours to travel a lane, per lane with the set-up, per cycle over every lane, and days per cycle.
  final double travelHours;
  final double laneHours;
  final double cycleHours;
  final double cycleDays;

  /// Area (m²) and water (m³) per lane.
  final double areaPerLaneM2;
  final double volumePerLaneM3;

  /// Application rate under the gun (mm/h).
  final double applicationRateMmH;

  /// Friction along the hose (m) and mean velocity in it (m/s).
  final double hoseFrictionM;
  final double hoseVelocity;

  /// Pressure head needed at the hydrant (m), hydraulic and shaft power (kW).
  final double inletHeadM;
  final double hydraulicPowerKw;
  final double shaftPowerKw;

  /// Message codes (`traveller_*`, with `:<id>` when an id was given).
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
    'sl': laneSpacingM, 'pct': laneSpacingPct, 'rpct': recommendedPct, 'n': lanes, 'll': laneLengthM, 'v': speedMPerMin, 'd': grossDepthMm, 'th': travelHours, 'lh': laneHours, 'ch': cycleHours, 'cd': cycleDays,
    'a': areaPerLaneM2, 'vol': volumePerLaneM3, 'i': applicationRateMmH, 'hf': hoseFrictionM, 'vh': hoseVelocity, 'hin': inletHeadM, 'ph': hydraulicPowerKw, 'ps': shaftPowerKw, 'warn': warnings,
  };
  static TravellerResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return TravellerResult(
      laneSpacingM: d('sl'), laneSpacingPct: d('pct'), recommendedPct: d('rpct'), lanes: (j['n'] as num?)?.toInt() ?? 1, laneLengthM: d('ll'), speedMPerMin: d('v'), grossDepthMm: d('d'), travelHours: d('th'),
      laneHours: d('lh'), cycleHours: d('ch'), cycleDays: d('cd'), areaPerLaneM2: d('a'), volumePerLaneM3: d('vol'), applicationRateMmH: d('i'), hoseFrictionM: d('hf'), hoseVelocity: d('vh'), inletHeadM: d('hin'),
      hydraulicPowerKw: d('ph'), shaftPowerKw: d('ps'), warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Application rate (mm/h) under a gun of [flow] (m³/s) and [wettedRadiusM]
/// watering [sectorDeg]: q over π·(0.9·R)²·θ/360 (NEH 623 ch. 11, eq. 11-39).
double gunApplicationRate({required double flow, required double wettedRadiusM, double sectorDeg = 360}) {
  final area = math.pi * math.pow(0.9 * wettedRadiusM, 2) * sectorDeg.clamp(1.0, 360.0) / 360;
  return area > 0 && flow > 0 ? flow / area * 1000 * 3600 : 0;
}

/// Lane spacing, speed, depth, times, hose friction, inlet pressure and power of a travelling gun.
TravellerResult analyzeTraveller(TravellerSpec s, {String id = ''}) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  final q = s.gunFlow;
  if (q <= 0) warn('traveller_no_flow');
  final dw = s.wettedDiameterM;
  final pct = laneSpacingPercent(s.wind, taperedNozzle: s.taperedNozzle);
  final maxSpacing = dw * pct / 100;
  var spacing = s.laneSpacingM > 0 ? s.laneSpacingM : maxSpacing;
  if (s.laneSpacingM > 0 && dw > 0 && s.laneSpacingM > maxSpacing + 1e-6) warn('traveller_lane_wide');
  var lanes = 1;
  if (s.fieldWidthM > 0 && spacing > 0) {
    lanes = math.max(1, (s.fieldWidthM / spacing - 1e-9).ceil());
    if (s.laneSpacingM <= 0) spacing = s.fieldWidthM / lanes;
  }
  final runLength = s.laneLengthM > 0 ? s.laneLengthM : s.hoseLengthM;

  // speed from the target depth (d = q/(S·v)) or given
  var v = 0.0; // m/s
  if (s.targetDepthMm > 0 && spacing > 0 && q > 0) {
    v = q / (spacing * s.targetDepthMm / 1000);
  } else if (s.speedMPerMin > 0) {
    v = s.speedMPerMin / 60;
  }
  if (v <= 0) warn('traveller_no_speed');
  final vMin = v * 60;
  if (v > 0 && ((s.minSpeedMPerMin > 0 && vMin < s.minSpeedMPerMin - 1e-9) || (s.maxSpeedMPerMin > 0 && vMin > s.maxSpeedMPerMin + 1e-9))) warn('traveller_speed_range');
  final depthMm = v > 0 && spacing > 0 ? q / (spacing * v) * 1000 : 0.0;
  final travelHours = v > 0 ? runLength / v / 3600 : 0.0;
  final laneHours = travelHours + math.max(s.setupHours, 0.0);
  final cycleHours = laneHours * lanes;
  final rate = gunApplicationRate(flow: q, wettedRadiusM: dw / 2, sectorDeg: s.sectorDeg);
  if (s.soilIntakeMmH > 0 && rate > s.soilIntakeMmH + 1e-9) warn('traveller_app_rate');

  // hose friction along its whole length, inlet pressure and power
  final d = s.hoseInnerMm / 1000;
  final hf = d > 0 && q > 0
      ? switch (s.method) {
          FrictionMethod.hazenWilliams => hazenWilliamsLoss(flow: q, diameter: d, length: s.hoseLengthM, c: s.hoseHazenC),
          FrictionMethod.darcyWeisbach => darcyWeisbachLoss(flow: q, diameter: d, length: s.hoseLengthM, roughness: s.hoseRoughnessMm / 1000, kinematicViscosity: s.kinematicViscosity),
          // polyethylene hose
          FrictionMethod.scobey => scobeyLoss(flow: q, diameter: d, length: s.hoseLengthM, ks: 0.32),
          FrictionMethod.manning => manningLoss(flow: q, diameter: d, length: s.hoseLengthM, n: 0.009),
        }
      : 0.0;
  final inlet = s.gunPressureM + hf + s.driveLossM + s.gunHeightM + s.groundRiseM;
  return TravellerResult(
    laneSpacingM: spacing, laneSpacingPct: dw > 0 ? spacing / dw * 100 : 0, recommendedPct: pct, lanes: lanes, laneLengthM: runLength, speedMPerMin: vMin, grossDepthMm: depthMm,
    travelHours: travelHours, laneHours: laneHours, cycleHours: cycleHours, cycleDays: s.hoursPerDay > 0 ? cycleHours / s.hoursPerDay : 0, areaPerLaneM2: spacing * runLength,
    volumePerLaneM3: q * travelHours * 3600, applicationRateMmH: rate, hoseFrictionM: hf, hoseVelocity: d > 0 ? velocity(flow: q, diameter: d) : 0, inletHeadM: inlet,
    hydraulicPowerKw: hydraulicPower(flow: q, head: inlet) / 1000, shaftPowerKw: shaftPower(flow: q, head: inlet, efficiency: s.pumpEfficiency) / 1000, warnings: warnings,
  );
}
