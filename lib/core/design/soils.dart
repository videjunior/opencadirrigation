/// Soil water and intake properties of the 12 USDA texture classes.
///
/// Sources, per field:
/// - available water capacity AWC: USDA-NRCS National Engineering Handbook
///   Part 652 (Irrigation Guide, 1997), Chapter 2, Table 2-1 ("Available
///   water capacity by texture": range in in/in and the typical estimate in
///   in/ft, here in mm/m; 1 in/ft = 83.3 mm/m);
/// - field capacity (−33 kPa), wilting point (−1500 kPa), total porosity and
///   saturated hydraulic conductivity: Rawls, Brakensiek & Saxton (1982),
///   Estimation of soil water properties, Trans. ASAE 25(5):1316–1320, mean
///   values by texture class (silt, which that study does not tabulate,
///   takes the mid values of FAO-56 Table 19 and the conductivity of silt
///   loam);
/// - FAO-56 (Allen et al. 1998) Table 19: ranges of θFC, θWP, AWC and the
///   readily (REW) and total (TEW, Ze = 0.10 m) evaporable water, for the
///   nine classes it lists;
/// - basic intake rate and allowable surface accumulation by slope:
///   Irrigation Association, SWAT climatologically based controllers 8th
///   draft testing protocol (2008), Table 3, as adopted by the US EPA
///   WaterSense specification for weather-based irrigation controllers
///   (2011); its seven classes are extended to the others by the intake
///   groups of NEH Part 652 Table 2-6 (silt loam and silt with loam; sandy
///   clay loam, silty clay loam and sandy clay with clay loam);
/// - sprinkler intake range: NEH Part 652 Table 2-6;
/// - maximum sprinkler application rate by slope: USDA-SCS National
///   Engineering Handbook Section 15, Chapter 11 (Sprinkle Irrigation, 1983),
///   Table 11-4, with its adjustments (bare or poor soil −25 %, grasses and
///   alfalfa +25 %).
///
/// Keys are i18n keys (`soil.*`). Values are typical: local soil surveys and
/// field tests take precedence.
library;

import 'dart:math' as math;

/// The 12 USDA soil texture classes.
enum SoilTexture { sand, loamySand, sandyLoam, loam, siltLoam, silt, sandyClayLoam, clayLoam, siltyClayLoam, sandyClay, siltyClay, clay }

/// Rows of the SWAT/EPA intake table (Table 3).
enum _IntakeRow { clay, siltyClay, clayLoam, loam, sandyLoam, loamySand, sand }

/// Rows of NEH Section 15 Chapter 11 Table 11-4.
enum _SprinkleRow { coarseSandy, lightSandyLoam, siltLoam, heavyClay }

class SoilData {
  const SoilData({
    required this.texture,
    required this.awcTypicalInPerFt,
    required this.awcMinInPerIn,
    required this.awcMaxInPerIn,
    required this.fieldCapacity,
    required this.wiltingPoint,
    this.porosity,
    required this.ksatMmH,
    this.fao56FieldCapacity,
    this.fao56WiltingPoint,
    this.fao56Awc,
    this.fao56RewMm,
    this.fao56TewMm,
    required this.sprinkleIntakeInH,
    required this.estimatedFromNeighbours,
  });

  final SoilTexture texture;

  /// NEH 652 Table 2-1: typical AWC (in/ft) and its range (in/in).
  final double awcTypicalInPerFt;
  final double awcMinInPerIn;
  final double awcMaxInPerIn;

  /// Volumetric water content (m³/m³) at field capacity and wilting point
  /// (Rawls et al. 1982 means).
  final double fieldCapacity;
  final double wiltingPoint;

  /// Total porosity (m³/m³), Rawls et al. 1982 (null for silt).
  final double? porosity;

  /// Saturated hydraulic conductivity (mm/h), Rawls et al. 1982.
  final double ksatMmH;

  /// FAO-56 Table 19 ranges (null for the classes it does not list).
  final (double, double)? fao56FieldCapacity;
  final (double, double)? fao56WiltingPoint;
  final (double, double)? fao56Awc;
  final (double, double)? fao56RewMm;
  final (double, double)? fao56TewMm;

  /// NEH 652 Table 2-6 sprinkle intake range (in/h); the upper bound is
  /// infinite for the open "+" ranges.
  final (double, double) sprinkleIntakeInH;

  /// Fields that are not tabulated for this class and were taken from a
  /// neighbouring class (see the library notes).
  final Set<String> estimatedFromNeighbours;

  /// i18n key.
  String get key => 'soil.${texture.name}';

  /// Typical AWC (mm of water per m of soil), NEH 652 Table 2-1.
  double get awcMmPerM => awcTypicalInPerFt * 25.4 / 0.3048;

  /// AWC range (mm/m), NEH 652 Table 2-1.
  (double, double) get awcRangeMmPerM => (awcMinInPerIn * 1000, awcMaxInPerIn * 1000);

  /// θFC − θWP (m³/m³) from the Rawls et al. (1982) means.
  double get availableWaterFraction => fieldCapacity - wiltingPoint;

  /// Basic intake rate (mm/h) of the SWAT/EPA table.
  double get basicIntakeMmH => _intakeRowData[_intakeRowOf[texture]!]!.$1 * 25.4;

  /// Total available water in the root zone (mm), FAO-56 eq. 82, with the
  /// typical NEH AWC (or [awcMmPerM] when given).
  double totalAvailableWaterMm(double rootDepthM, {double? awcMmPerM}) => (awcMmPerM ?? this.awcMmPerM) * math.max(rootDepthM, 0.0);
}

/// Soil table keyed by `soil.<texture>`.
final Map<String, SoilData> soilTable = {for (final s in _soils) s.key: s};

/// Soil data of a texture class.
SoilData soilOf(SoilTexture t) => soilTable['soil.${t.name}']!;

const _soils = <SoilData>[
  SoilData(texture: SoilTexture.sand, awcTypicalInPerFt: 0.25, awcMinInPerIn: 0.01, awcMaxInPerIn: 0.03, fieldCapacity: 0.091, wiltingPoint: 0.033, porosity: 0.437, ksatMmH: 210, fao56FieldCapacity: (0.07, 0.17), fao56WiltingPoint: (0.02, 0.07), fao56Awc: (0.05, 0.11), fao56RewMm: (2, 7), fao56TewMm: (6, 12), sprinkleIntakeInH: (0.5, double.infinity), estimatedFromNeighbours: {}),
  SoilData(texture: SoilTexture.loamySand, awcTypicalInPerFt: 0.85, awcMinInPerIn: 0.06, awcMaxInPerIn: 0.08, fieldCapacity: 0.125, wiltingPoint: 0.055, porosity: 0.437, ksatMmH: 61.1, fao56FieldCapacity: (0.11, 0.19), fao56WiltingPoint: (0.03, 0.10), fao56Awc: (0.06, 0.12), fao56RewMm: (4, 8), fao56TewMm: (9, 14), sprinkleIntakeInH: (0.4, 1.5), estimatedFromNeighbours: {}),
  SoilData(texture: SoilTexture.sandyLoam, awcTypicalInPerFt: 1.45, awcMinInPerIn: 0.11, awcMaxInPerIn: 0.13, fieldCapacity: 0.207, wiltingPoint: 0.095, porosity: 0.453, ksatMmH: 25.9, fao56FieldCapacity: (0.18, 0.28), fao56WiltingPoint: (0.06, 0.16), fao56Awc: (0.11, 0.15), fao56RewMm: (6, 10), fao56TewMm: (15, 20), sprinkleIntakeInH: (0.3, 1.25), estimatedFromNeighbours: {}),
  SoilData(texture: SoilTexture.loam, awcTypicalInPerFt: 2.0, awcMinInPerIn: 0.16, awcMaxInPerIn: 0.18, fieldCapacity: 0.270, wiltingPoint: 0.117, porosity: 0.463, ksatMmH: 13.2, fao56FieldCapacity: (0.20, 0.30), fao56WiltingPoint: (0.07, 0.17), fao56Awc: (0.13, 0.18), fao56RewMm: (8, 10), fao56TewMm: (16, 22), sprinkleIntakeInH: (0.5, 0.7), estimatedFromNeighbours: {}),
  SoilData(texture: SoilTexture.siltLoam, awcTypicalInPerFt: 2.4, awcMinInPerIn: 0.19, awcMaxInPerIn: 0.21, fieldCapacity: 0.330, wiltingPoint: 0.133, porosity: 0.501, ksatMmH: 6.8, fao56FieldCapacity: (0.22, 0.36), fao56WiltingPoint: (0.09, 0.21), fao56Awc: (0.13, 0.19), fao56RewMm: (8, 11), fao56TewMm: (18, 25), sprinkleIntakeInH: (0.5, 0.7), estimatedFromNeighbours: {'intake'}),
  SoilData(texture: SoilTexture.silt, awcTypicalInPerFt: 2.0, awcMinInPerIn: 0.16, awcMaxInPerIn: 0.18, fieldCapacity: 0.32, wiltingPoint: 0.17, ksatMmH: 6.8, fao56FieldCapacity: (0.28, 0.36), fao56WiltingPoint: (0.12, 0.22), fao56Awc: (0.16, 0.20), fao56RewMm: (8, 11), fao56TewMm: (22, 26), sprinkleIntakeInH: (0.5, 0.7), estimatedFromNeighbours: {'retention', 'ksat', 'intake', 'sprinkleIntake'}),
  SoilData(texture: SoilTexture.sandyClayLoam, awcTypicalInPerFt: 1.8, awcMinInPerIn: 0.14, awcMaxInPerIn: 0.16, fieldCapacity: 0.255, wiltingPoint: 0.148, porosity: 0.398, ksatMmH: 4.3, sprinkleIntakeInH: (0.1, 0.5), estimatedFromNeighbours: {'intake'}),
  SoilData(texture: SoilTexture.clayLoam, awcTypicalInPerFt: 2.4, awcMinInPerIn: 0.19, awcMaxInPerIn: 0.21, fieldCapacity: 0.318, wiltingPoint: 0.197, porosity: 0.464, ksatMmH: 2.3, sprinkleIntakeInH: (0.1, 0.5), estimatedFromNeighbours: {}),
  SoilData(texture: SoilTexture.siltyClayLoam, awcTypicalInPerFt: 2.4, awcMinInPerIn: 0.19, awcMaxInPerIn: 0.21, fieldCapacity: 0.366, wiltingPoint: 0.208, porosity: 0.471, ksatMmH: 1.5, fao56FieldCapacity: (0.30, 0.37), fao56WiltingPoint: (0.17, 0.24), fao56Awc: (0.13, 0.18), fao56RewMm: (8, 11), fao56TewMm: (22, 27), sprinkleIntakeInH: (0.1, 0.4), estimatedFromNeighbours: {'intake'}),
  SoilData(texture: SoilTexture.sandyClay, awcTypicalInPerFt: 1.9, awcMinInPerIn: 0.15, awcMaxInPerIn: 0.17, fieldCapacity: 0.339, wiltingPoint: 0.239, porosity: 0.430, ksatMmH: 1.2, sprinkleIntakeInH: (0.1, 0.4), estimatedFromNeighbours: {'intake'}),
  SoilData(texture: SoilTexture.siltyClay, awcTypicalInPerFt: 1.9, awcMinInPerIn: 0.15, awcMaxInPerIn: 0.17, fieldCapacity: 0.387, wiltingPoint: 0.250, porosity: 0.479, ksatMmH: 0.9, fao56FieldCapacity: (0.30, 0.42), fao56WiltingPoint: (0.17, 0.29), fao56Awc: (0.13, 0.19), fao56RewMm: (8, 12), fao56TewMm: (22, 28), sprinkleIntakeInH: (0.1, 0.2), estimatedFromNeighbours: {}),
  SoilData(texture: SoilTexture.clay, awcTypicalInPerFt: 1.8, awcMinInPerIn: 0.14, awcMaxInPerIn: 0.16, fieldCapacity: 0.396, wiltingPoint: 0.272, porosity: 0.475, ksatMmH: 0.6, fao56FieldCapacity: (0.32, 0.40), fao56WiltingPoint: (0.20, 0.24), fao56Awc: (0.12, 0.20), fao56RewMm: (8, 12), fao56TewMm: (22, 29), sprinkleIntakeInH: (0.1, 0.2), estimatedFromNeighbours: {}),
];

const _intakeRowOf = <SoilTexture, _IntakeRow>{
  SoilTexture.sand: _IntakeRow.sand,
  SoilTexture.loamySand: _IntakeRow.loamySand,
  SoilTexture.sandyLoam: _IntakeRow.sandyLoam,
  SoilTexture.loam: _IntakeRow.loam,
  SoilTexture.siltLoam: _IntakeRow.loam,
  SoilTexture.silt: _IntakeRow.loam,
  SoilTexture.sandyClayLoam: _IntakeRow.clayLoam,
  SoilTexture.clayLoam: _IntakeRow.clayLoam,
  SoilTexture.siltyClayLoam: _IntakeRow.clayLoam,
  SoilTexture.sandyClay: _IntakeRow.clayLoam,
  SoilTexture.siltyClay: _IntakeRow.siltyClay,
  SoilTexture.clay: _IntakeRow.clay,
};

/// SWAT/EPA Table 3: basic intake rate (in/h) and allowable surface
/// accumulation (in) for slopes 0–3 %, 4–6 %, 7–12 % and 13 % or more.
const _intakeRowData = <_IntakeRow, (double, List<double>)>{
  _IntakeRow.clay: (0.10, [0.20, 0.15, 0.10, 0.10]),
  _IntakeRow.siltyClay: (0.15, [0.23, 0.19, 0.16, 0.13]),
  _IntakeRow.clayLoam: (0.20, [0.26, 0.22, 0.18, 0.15]),
  _IntakeRow.loam: (0.35, [0.30, 0.25, 0.21, 0.17]),
  _IntakeRow.sandyLoam: (0.40, [0.33, 0.29, 0.24, 0.20]),
  _IntakeRow.loamySand: (0.50, [0.36, 0.30, 0.26, 0.22]),
  _IntakeRow.sand: (0.60, [0.40, 0.35, 0.30, 0.25]),
};

/// Allowable surface accumulation (mm): free water held on the surface by
/// detention, canopy and thatch before it runs off, SWAT/EPA Table 3 by the
/// slope class (0–3 %, 4–6 %, 7–12 %, 13 % or more; slopes between the
/// classes take the next steeper class).
double allowableSurfaceAccumulationMm(SoilTexture texture, double slopePct) {
  final asa = _intakeRowData[_intakeRowOf[texture]!]!.$2;
  final s = slopePct.abs();
  final i = s <= 3 ? 0 : (s <= 6 ? 1 : (s <= 12 ? 2 : 3));
  return asa[i] * 25.4;
}

const _sprinkleRowOf = <SoilTexture, _SprinkleRow>{
  SoilTexture.sand: _SprinkleRow.coarseSandy,
  SoilTexture.loamySand: _SprinkleRow.coarseSandy,
  SoilTexture.sandyLoam: _SprinkleRow.lightSandyLoam,
  SoilTexture.loam: _SprinkleRow.siltLoam,
  SoilTexture.siltLoam: _SprinkleRow.siltLoam,
  SoilTexture.silt: _SprinkleRow.siltLoam,
  SoilTexture.sandyClayLoam: _SprinkleRow.heavyClay,
  SoilTexture.clayLoam: _SprinkleRow.heavyClay,
  SoilTexture.siltyClayLoam: _SprinkleRow.heavyClay,
  SoilTexture.sandyClay: _SprinkleRow.heavyClay,
  SoilTexture.siltyClay: _SprinkleRow.heavyClay,
  SoilTexture.clay: _SprinkleRow.heavyClay,
};

/// NEH 15-11 Table 11-4 (in/h) for slopes 0–5, 5–8, 8–12 and 12–16 %: the
/// soil to 6 ft, then the same soil over more compact soils.
const _sprinkleRows = <_SprinkleRow, (List<double>, List<double>)>{
  _SprinkleRow.coarseSandy: ([2.0, 1.5, 1.0, 0.50], [1.5, 1.0, 0.75, 0.40]),
  _SprinkleRow.lightSandyLoam: ([1.0, 0.80, 0.60, 0.40], [0.75, 0.50, 0.40, 0.30]),
  _SprinkleRow.siltLoam: ([0.50, 0.40, 0.30, 0.20], [0.30, 0.25, 0.15, 0.10]),
  _SprinkleRow.heavyClay: ([0.15, 0.10, 0.08, 0.06], [0.15, 0.10, 0.08, 0.06]),
};

/// Surface condition for [maxSprinklerApplicationRateMmH].
enum SoilCover {
  /// Average soil, slope and tilth for all crops but grasses and alfalfa
  /// (the table itself).
  average,

  /// Grasses and alfalfa: +25 %.
  grass,

  /// Bare ground and poor soil condition: −25 %.
  bare,
}

/// Suggested maximum sprinkler application rate (mm/h) for the soil, slope
/// (%) and cover, NEH Section 15 Chapter 11 Table 11-4 (slopes above 16 %
/// take the 12–16 % column). [compactSubsoil] picks the rows for soils over
/// more compact layers; [largeDrops] applies the −25 % the handbook gives
/// for gun and traveling sprinklers.
double maxSprinklerApplicationRateMmH(SoilTexture texture, double slopePct, {bool compactSubsoil = false, SoilCover cover = SoilCover.average, bool largeDrops = false}) {
  final rows = _sprinkleRows[_sprinkleRowOf[texture]!]!;
  final row = compactSubsoil ? rows.$2 : rows.$1;
  final s = slopePct.abs();
  final i = s <= 5 ? 0 : (s <= 8 ? 1 : (s <= 12 ? 2 : 3));
  var f = switch (cover) {
    SoilCover.average => 1.0,
    SoilCover.grass => 1.25,
    SoilCover.bare => 0.75,
  };
  if (largeDrops) f *= 0.75;
  return row[i] * f * 25.4;
}

/// USDA texture class from the sand and clay percentages (silt = the rest),
/// by the boundaries of the USDA soil texture triangle (USDA-NRCS Soil
/// Survey Manual, Handbook 18). Null when the fractions are impossible.
SoilTexture? usdaTextureClass(double sandPct, double clayPct) {
  final sand = sandPct, clay = clayPct, silt = 100 - sandPct - clayPct;
  if (sand < 0 || clay < 0 || silt < -1e-9 || !sand.isFinite || !clay.isFinite) return null;
  if (silt + 1.5 * clay < 15) return SoilTexture.sand;
  if (silt + 2 * clay < 30) return SoilTexture.loamySand;
  if ((clay >= 7 && clay < 20 && sand > 52) || (clay < 7 && silt < 50)) return SoilTexture.sandyLoam;
  if (clay >= 7 && clay < 27 && silt >= 28 && silt < 50 && sand <= 52) return SoilTexture.loam;
  if ((silt >= 50 && clay >= 12 && clay < 27) || (silt >= 50 && silt < 80 && clay < 12)) return SoilTexture.siltLoam;
  if (silt >= 80 && clay < 12) return SoilTexture.silt;
  if (clay >= 20 && clay < 35 && silt < 28 && sand > 45) return SoilTexture.sandyClayLoam;
  if (clay >= 27 && clay < 40 && sand > 20 && sand <= 45) return SoilTexture.clayLoam;
  if (clay >= 27 && clay < 40 && sand <= 20) return SoilTexture.siltyClayLoam;
  if (clay >= 35 && sand > 45) return SoilTexture.sandyClay;
  if (clay >= 40 && silt >= 40) return SoilTexture.siltyClay;
  if (clay >= 40) return SoilTexture.clay;
  return null;
}
