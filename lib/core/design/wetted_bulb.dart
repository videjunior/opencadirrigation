/// Wetted soil volume under a drip emitter and the percentage of the area
/// wetted by a lateral layout.
///
/// - Schwartzman, M.; Zur, B. (1986). Emitter spacing and geometry of
///   wetted soil volume. J. Irrig. Drain. Eng. 112(3):242–253: wetted
///   width (diameter) W = 1.82·V^0.22·(Ks/q)^−0.17 and depth
///   Z = 2.54·V^0.63·(Ks/q)^0.45, with W and Z in m, the applied volume V in
///   m³, the saturated conductivity Ks in m/s and the emitter flow q in m³/s
///   (as restated by Cruz-Bautista et al. 2016, Tecnología y Ciencias del
///   Agua 7(1):45–55). The fit comes from two soils (Ks ≈ 2.5·10⁻⁶ and
///   2.5·10⁻⁵ m/s) and two surface point sources (4.3 and 20 L/h): outside
///   that range it extrapolates and later studies found errors of tens of
///   percent; use field tests when they exist.
/// - Keller & Bliesner (1990), Sprinkle and Trickle Irrigation: estimated
///   wetted areas of a 4 L/h emitter by texture, soil depth and
///   stratification (equivalent area Se'×W with Se' = 0.8·W), as reproduced
///   by FAO (Savva & Frenken 2002, Irrigation Manual Module 9, Table 4); and
///   the percentage of wetted area Pw = 100·Np·Se·W/(Sp·Sr) (Module 9,
///   eq. 10), with the emitter spacing that counts limited to Se' = 0.8·W so
///   that separate wetted circles are not taken as a continuous strip.
library;

import 'dart:math' as math;

/// Wetted bulb dimensions (m).
class WettedBulb {
  const WettedBulb({required this.widthM, required this.depthM, required this.extrapolated});

  /// Wetted width (diameter at its widest).
  final double widthM;
  final double depthM;

  /// True outside the conductivities and flows of the original experiments.
  final bool extrapolated;

  /// Horizontal area wetted (m²), taken as the circle of the width.
  double get areaM2 => math.pi * widthM * widthM / 4;
}

/// Schwartzman & Zur (1986) wetted width and depth for an emitter of
/// [flowLph] applying [volumeL] litres in a soil of saturated conductivity
/// [ksatMmH] (mm/h).
WettedBulb schwartzmanZurBulb({required double flowLph, required double volumeL, required double ksatMmH}) {
  final q = math.max(flowLph, 1e-6) / 3.6e6; // m³/s
  final v = math.max(volumeL, 0.0) / 1000; // m³
  final ks = math.max(ksatMmH, 1e-6) / 3.6e6; // m/s
  if (v <= 0) return const WettedBulb(widthM: 0, depthM: 0, extrapolated: false);
  final r = ks / q;
  final w = 1.82 * math.pow(v, 0.22) * math.pow(r, -0.17);
  final z = 2.54 * math.pow(v, 0.63) * math.pow(r, 0.45);
  final extrapolated = ks < 2.0e-6 || ks > 3.0e-5 || flowLph < 4.3 * 0.9 || flowLph > 20 * 1.1;
  return WettedBulb(widthM: w.toDouble(), depthM: z.toDouble(), extrapolated: extrapolated);
}

/// Soil texture group of the Keller & Bliesner wetted-area table.
enum BulbTexture {
  /// Coarse to medium sands.
  coarse,

  /// Loamy sand to loam.
  medium,

  /// Sandy clay to clay (cracked clays behave as coarse to medium soils).
  fine,
}

/// Soil profile of the Keller & Bliesner table.
enum BulbProfile {
  homogeneous,

  /// Uniform texture with some particle orientation or compaction layering.
  stratified,

  /// Texture changes with depth, with orientation and moderate compaction.
  layered,
}

/// Keller & Bliesner (1990) wetted width W (m) of a 4 L/h emitter for a
/// soil or root depth of 0.75 or 1.5 m (values in between interpolated,
/// outside clamped); the equivalent wetted area is 0.8·W × W.
double kellerBliesnerWettedWidthM({required BulbTexture texture, BulbProfile profile = BulbProfile.homogeneous, double depthM = 0.75}) {
  // W (m) at depth 0.75 m and 1.50 m, for homogeneous / stratified / layered
  const shallow = {
    BulbTexture.coarse: [0.5, 0.8, 1.1],
    BulbTexture.medium: [0.9, 1.2, 1.5],
    BulbTexture.fine: [1.1, 1.5, 1.8],
  };
  const deep = {
    BulbTexture.coarse: [0.8, 1.4, 1.8],
    BulbTexture.medium: [1.2, 2.1, 2.7],
    BulbTexture.fine: [1.5, 2.0, 2.4],
  };
  final a = shallow[texture]![profile.index], b = deep[texture]![profile.index];
  final t = ((depthM - 0.75) / 0.75).clamp(0.0, 1.0);
  return a + t * (b - a);
}

/// Percentage of the area wetted Pw (%) by [emittersPerPlant] emitters
/// spaced [emitterSpacingM] apart that wet a strip or circles [wettedWidthM]
/// wide, for plants spaced [plantSpacingM] in rows [rowSpacingM] apart
/// (Keller & Bliesner 1990; FAO Module 9 eq. 10). With
/// [limitSpacingToWettedWidth] the spacing that counts is limited to
/// Se' = 0.8·W, so that emitters too far apart to form a strip are not
/// counted as one (FAO's second example applies eq. 10 without it); the
/// result is limited to 100 %.
double percentWettedArea({
  required double emittersPerPlant,
  required double emitterSpacingM,
  required double wettedWidthM,
  required double plantSpacingM,
  required double rowSpacingM,
  bool limitSpacingToWettedWidth = true,
}) {
  if (plantSpacingM <= 0 || rowSpacingM <= 0 || wettedWidthM <= 0) return 0;
  final s = math.max(emitterSpacingM, 0.0);
  final se = limitSpacingToWettedWidth ? math.min(s, 0.8 * wettedWidthM) : s;
  return math.min(100 * emittersPerPlant * se * wettedWidthM / (plantSpacingM * rowSpacingM), 100);
}

/// Percentage of the area wetted (%) by [lateralsPerRow] laterals per plant
/// row with emitters every [emitterSpacingM] (an in-line dripline along the
/// whole row): Pw from [percentWettedArea] with the emitters a plant gets.
double percentWettedAreaOfLaterals({required int lateralsPerRow, required double emitterSpacingM, required double wettedWidthM, required double rowSpacingM}) {
  if (emitterSpacingM <= 0) return 0;
  // per metre of row: lateralsPerRow / Se emitters
  return percentWettedArea(emittersPerPlant: lateralsPerRow / emitterSpacingM, emitterSpacingM: emitterSpacingM, wettedWidthM: wettedWidthM, plantSpacingM: 1, rowSpacingM: rowSpacingM);
}

/// Emitters per plant for a target Pw (%) with each emitter wetting
/// [wettedAreaM2] (FAO Module 9 eq. 8), rounded up.
int emittersPerPlantForWettedArea({required double targetPercent, required double plantSpacingM, required double rowSpacingM, required double wettedAreaM2}) {
  if (wettedAreaM2 <= 0) return 0;
  return (plantSpacingM * rowSpacingM * targetPercent / 100 / wettedAreaM2 - 1e-9).ceil();
}
