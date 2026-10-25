/// Crops by growth stage: the FAO-56 single crop coefficient curve and a
/// crop table for the crops irrigation designers meet most.
///
/// Sources (Allen, Pereira, Raes & Smith 1998, FAO Irrigation and Drainage
/// Paper 56, unless noted):
/// - Table 11: lengths of the initial, development, mid-season and late
///   stages (one representative row per crop, cited per entry);
/// - Table 12: Kc ini, Kc mid, Kc end and maximum crop height h; blank Kc ini
///   cells take the value of the crop group;
/// - Table 17: basal coefficients Kcb ini, Kcb mid, Kcb end (dry soil
///   surface, for the dual approach and for localized irrigation);
/// - Table 22: maximum effective root depth Zr (range) and the depletion
///   fraction p for ETc ≈ 5 mm/day;
/// - salt tolerance: Ayers & Westcot (1985), FAO Irrigation and Drainage
///   Paper 29 Rev. 1, Table 4 (ECe at 100 % yield and the "maximum" ECe at
///   zero yield; after Maas & Hoffman 1977 and Maas 1984);
/// - eq. 66 (Kc in the development and late stages), eqs. 62 and 65 (Kc mid
///   and Kc end climatic adjustment), eqs. 59–61 and Annex 7 eqs. 7-1 to
///   7-10 (Kc ini from the wetting interval), eq. 98 (sparse cover), and the
///   p adjustment of Table 22, note 2;
/// - localized irrigation: Keller & Bliesner (1990), Sprinkle and Trickle
///   Irrigation, Td = Ud·0.1·√Pd, and the reduction factors of Keller &
///   Karmeli, Freeman & Garzoli and Decroix as tabulated by FAO (Savva &
///   Frenken 2002, Irrigation Manual Module 9, Table 1, after FAO 1984).
///
/// Ranges in the tables are stored as their mid value unless an entry says
/// otherwise. Keys are i18n keys (`crop.*`).
library;

import 'dart:math' as math;

/// The four FAO-56 growth stages (days).
class CropStages {
  const CropStages(this.initial, this.development, this.mid, this.late);
  final double initial;
  final double development;
  final double mid;
  final double late;
  double get total => initial + development + mid + late;
}

/// One crop of the table.
class CropData {
  const CropData({
    required this.key,
    required this.kcIni,
    required this.kcMid,
    required this.kcEnd,
    this.kcbIni,
    this.kcbMid,
    this.kcbEnd,
    this.maxHeightM,
    this.stages,
    this.plantingMonth,
    this.rootDepthMinM,
    this.rootDepthMaxM,
    this.depletionFraction,
    this.eceThreshold,
    this.eceMax,
    this.perennial = false,
    this.tabulated = true,
  });

  /// i18n key, `crop.<name>`.
  final String key;

  /// FAO-56 Table 12.
  final double kcIni;
  final double kcMid;
  final double kcEnd;

  /// FAO-56 Table 17 (null when the table has no row for the crop).
  final double? kcbIni;
  final double? kcbMid;
  final double? kcbEnd;

  /// Maximum crop height h (m), FAO-56 Table 12.
  final double? maxHeightM;

  /// Stage lengths of the FAO-56 Table 11 row taken (null: the table has
  /// none, the crop is then taken as evergreen with Kc mid all year).
  final CropStages? stages;

  /// Planting (or green-up) month of that Table 11 row.
  final int? plantingMonth;

  /// Maximum effective root depth range (m), FAO-56 Table 22: the smaller
  /// value suits irrigation scheduling, the larger soil water stress models.
  final double? rootDepthMinM;
  final double? rootDepthMaxM;

  /// Depletion fraction p for ETc ≈ 5 mm/day, FAO-56 Table 22.
  final double? depletionFraction;

  /// Soil salinity ECe (dS/m) at 100 % and at zero yield potential, FAO-29
  /// Table 4.
  final double? eceThreshold;
  final double? eceMax;

  /// Trees, vines, turf, pasture and other crops that repeat every year.
  final bool perennial;

  /// False when FAO-56 does not tabulate the crop (values to be confirmed
  /// with local data).
  final bool tabulated;

  /// Root depth for irrigation scheduling (the smaller Table 22 value).
  double? get schedulingRootDepthM => rootDepthMinM;

  /// Slope b of the yield decline (% per dS/m), FAO-29 eq. 10.
  double? get eceSlope {
    final t = eceThreshold, m = eceMax;
    if (t == null || m == null || m <= t) return null;
    return 100 / (m - t);
  }

  /// Kc curve of the Table 11 row (constant Kc mid when there is none).
  KcCurve get curve => stages == null ? KcCurve.constant(kcMid) : KcCurve(kcIni: kcIni, kcMid: kcMid, kcEnd: kcEnd, stages: stages!);

  /// Basal Kcb curve (null without Table 17 data).
  KcCurve? get basalCurve {
    if (kcbIni == null || kcbMid == null || kcbEnd == null) return null;
    return stages == null ? KcCurve.constant(kcbMid!) : KcCurve(kcIni: kcbIni!, kcMid: kcbMid!, kcEnd: kcbEnd!, stages: stages!);
  }
}

/// Crop table. Every entry cites the FAO-56 rows used.
const fao56Crops = <String, CropData>{
  // Citrus, no ground cover, 70 % canopy (T12, T17); Citrus, Jan,
  // Mediterranean (T11); Citrus 70 % canopy (T22); orange (FAO-29 T4).
  'crop.citrus': CropData(key: 'crop.citrus', kcIni: 0.70, kcMid: 0.65, kcEnd: 0.70, kcbIni: 0.65, kcbMid: 0.60, kcbEnd: 0.65, maxHeightM: 4, stages: CropStages(60, 90, 120, 95), plantingMonth: 1, rootDepthMinM: 1.2, rootDepthMaxM: 1.5, depletionFraction: 0.50, eceThreshold: 1.7, eceMax: 8.0, perennial: true),
  // Grapes, wine (T12, T17, T22); Grapes, April, mid latitudes (wine) (T11); grape (FAO-29 T4).
  'crop.grape': CropData(key: 'crop.grape', kcIni: 0.30, kcMid: 0.70, kcEnd: 0.45, kcbIni: 0.15, kcbMid: 0.65, kcbEnd: 0.40, maxHeightM: 1.75, stages: CropStages(30, 60, 40, 80), plantingMonth: 4, rootDepthMinM: 1.0, rootDepthMaxM: 2.0, depletionFraction: 0.45, eceThreshold: 1.5, eceMax: 12, perennial: true),
  // Grapes, table or raisin (T12, T17, T22); Grapes, April, low latitudes (T11).
  'crop.tableGrape': CropData(key: 'crop.tableGrape', kcIni: 0.30, kcMid: 0.85, kcEnd: 0.45, kcbIni: 0.15, kcbMid: 0.80, kcbEnd: 0.40, maxHeightM: 2, stages: CropStages(20, 40, 120, 60), plantingMonth: 4, rootDepthMinM: 1.0, rootDepthMaxM: 2.0, depletionFraction: 0.35, eceThreshold: 1.5, eceMax: 12, perennial: true),
  // Coffee, bare ground cover (T12, T17); Coffee (T22); not in T11.
  'crop.coffee': CropData(key: 'crop.coffee', kcIni: 0.90, kcMid: 0.95, kcEnd: 0.95, kcbIni: 0.80, kcbMid: 0.90, kcbEnd: 0.90, maxHeightM: 2.5, rootDepthMinM: 0.9, rootDepthMaxM: 1.5, depletionFraction: 0.40, perennial: true),
  // Banana, 1st year (T12, T17, T22); Banana 1st yr, March, Mediterranean (T11, 390 days).
  'crop.banana': CropData(key: 'crop.banana', kcIni: 0.50, kcMid: 1.10, kcEnd: 1.00, kcbIni: 0.15, kcbMid: 1.05, kcbEnd: 0.90, maxHeightM: 3, stages: CropStages(120, 90, 120, 60), plantingMonth: 3, rootDepthMinM: 0.5, rootDepthMaxM: 0.9, depletionFraction: 0.35),
  // Banana, 2nd year (T12, T17, T22); Banana 2nd yr, February, Mediterranean (T11).
  'crop.bananaYear2': CropData(key: 'crop.bananaYear2', kcIni: 1.00, kcMid: 1.20, kcEnd: 1.10, kcbIni: 0.60, kcbMid: 1.10, kcbEnd: 1.05, maxHeightM: 4, stages: CropStages(120, 60, 180, 5), plantingMonth: 2, rootDepthMinM: 0.5, rootDepthMaxM: 0.9, depletionFraction: 0.35, perennial: true),
  // Mango is not tabulated by FAO-56: the values the program offered before
  // (Kc 0.60 / 0.85 / 0.80), to be confirmed with local data.
  'crop.mango': CropData(key: 'crop.mango', kcIni: 0.60, kcMid: 0.85, kcEnd: 0.80, perennial: true, tabulated: false),
  // Apples, cherries, pears, no ground cover, killing frost (T12, T17);
  // Deciduous orchard, March, high latitudes (T11); Apples (T22).
  'crop.apple': CropData(key: 'crop.apple', kcIni: 0.45, kcMid: 0.95, kcEnd: 0.70, kcbIni: 0.35, kcbMid: 0.90, kcbEnd: 0.65, maxHeightM: 4, stages: CropStages(20, 70, 90, 30), plantingMonth: 3, rootDepthMinM: 1.0, rootDepthMaxM: 2.0, depletionFraction: 0.50, perennial: true),
  // Apricots, peaches, stone fruit, no ground cover, killing frost (T12,
  // T17); Deciduous orchard, March, low latitudes (T11); (T22); peach (FAO-29 T4).
  'crop.peach': CropData(key: 'crop.peach', kcIni: 0.45, kcMid: 0.90, kcEnd: 0.65, kcbIni: 0.35, kcbMid: 0.85, kcbEnd: 0.60, maxHeightM: 3, stages: CropStages(20, 70, 120, 60), plantingMonth: 3, rootDepthMinM: 1.0, rootDepthMaxM: 2.0, depletionFraction: 0.50, eceThreshold: 1.7, eceMax: 6.5, perennial: true),
  // Almonds, no ground cover (T12, T17, T22); Deciduous orchard, March, California (T11); almond (FAO-29 T4).
  'crop.almond': CropData(key: 'crop.almond', kcIni: 0.40, kcMid: 0.90, kcEnd: 0.65, kcbIni: 0.20, kcbMid: 0.85, kcbEnd: 0.60, maxHeightM: 5, stages: CropStages(30, 50, 130, 30), plantingMonth: 3, rootDepthMinM: 1.0, rootDepthMaxM: 2.0, depletionFraction: 0.40, eceThreshold: 1.5, eceMax: 6.8, perennial: true),
  // Avocado, no ground cover (T12, T17, T22); not in T11.
  'crop.avocado': CropData(key: 'crop.avocado', kcIni: 0.60, kcMid: 0.85, kcEnd: 0.75, kcbIni: 0.50, kcbMid: 0.80, kcbEnd: 0.70, maxHeightM: 3, rootDepthMinM: 0.5, rootDepthMaxM: 1.0, depletionFraction: 0.70, perennial: true),
  // Olives, 40–60 % ground cover (T12, T17, T22); Olives, March, Mediterranean (T11).
  'crop.olive': CropData(key: 'crop.olive', kcIni: 0.65, kcMid: 0.70, kcEnd: 0.70, kcbIni: 0.55, kcbMid: 0.65, kcbEnd: 0.65, maxHeightM: 4, stages: CropStages(30, 90, 60, 90), plantingMonth: 3, rootDepthMinM: 1.2, rootDepthMaxM: 1.7, depletionFraction: 0.65, perennial: true),
  // Palm trees (T12, T17, T22); not in T11.
  'crop.palm': CropData(key: 'crop.palm', kcIni: 0.95, kcMid: 1.00, kcEnd: 1.00, kcbIni: 0.85, kcbMid: 0.90, kcbEnd: 0.90, maxHeightM: 8, rootDepthMinM: 0.7, rootDepthMaxM: 1.1, depletionFraction: 0.65, perennial: true),
  // Date palms (T12, T17, T22); not in T11; date palm (FAO-29 T4).
  'crop.datePalm': CropData(key: 'crop.datePalm', kcIni: 0.90, kcMid: 0.95, kcEnd: 0.95, kcbIni: 0.80, kcbMid: 0.85, kcbEnd: 0.85, maxHeightM: 8, rootDepthMinM: 1.5, rootDepthMaxM: 2.5, depletionFraction: 0.50, eceThreshold: 4.0, eceMax: 32, perennial: true),
  // Tomato (T12: group Kc ini 0.6, Kc end 0.70–0.90; T17); Tomato,
  // April/May, Mediterranean (T11); (T22); tomato (FAO-29 T4).
  'crop.tomato': CropData(key: 'crop.tomato', kcIni: 0.60, kcMid: 1.15, kcEnd: 0.80, kcbIni: 0.15, kcbMid: 1.10, kcbEnd: 0.70, maxHeightM: 0.6, stages: CropStages(30, 40, 45, 30), plantingMonth: 4, rootDepthMinM: 0.7, rootDepthMaxM: 1.5, depletionFraction: 0.40, eceThreshold: 2.5, eceMax: 13),
  // Sweet peppers (bell) (T12, T17, T22); April/June, Europe and Mediterranean (T11); pepper (FAO-29 T4).
  'crop.pepper': CropData(key: 'crop.pepper', kcIni: 0.60, kcMid: 1.05, kcEnd: 0.90, kcbIni: 0.15, kcbMid: 1.00, kcbEnd: 0.80, maxHeightM: 0.7, stages: CropStages(25, 35, 40, 20), plantingMonth: 4, rootDepthMinM: 0.5, rootDepthMaxM: 1.0, depletionFraction: 0.30, eceThreshold: 1.5, eceMax: 8.6),
  // Onions, dry (T12: small-vegetable Kc ini 0.7; T17; T22); Onion (dry), April, Mediterranean (T11); onion (FAO-29 T4).
  'crop.onion': CropData(key: 'crop.onion', kcIni: 0.70, kcMid: 1.05, kcEnd: 0.75, kcbIni: 0.15, kcbMid: 0.95, kcbEnd: 0.65, maxHeightM: 0.4, stages: CropStages(15, 25, 70, 40), plantingMonth: 4, rootDepthMinM: 0.3, rootDepthMaxM: 0.6, depletionFraction: 0.30, eceThreshold: 1.2, eceMax: 7.4),
  // Lettuce (T12, T17, T22); Lettuce, April, Mediterranean (T11); lettuce (FAO-29 T4).
  'crop.lettuce': CropData(key: 'crop.lettuce', kcIni: 0.70, kcMid: 1.00, kcEnd: 0.95, kcbIni: 0.15, kcbMid: 0.90, kcbEnd: 0.90, maxHeightM: 0.3, stages: CropStages(20, 30, 15, 10), plantingMonth: 4, rootDepthMinM: 0.3, rootDepthMaxM: 0.5, depletionFraction: 0.30, eceThreshold: 1.3, eceMax: 9.0),
  // Small vegetables group (T12, T17: group row; h of broccoli); Crucifers,
  // April, Mediterranean (T11); Broccoli taken for root depth and p (T22).
  'crop.vegetables': CropData(key: 'crop.vegetables', kcIni: 0.70, kcMid: 1.05, kcEnd: 0.95, kcbIni: 0.15, kcbMid: 0.95, kcbEnd: 0.85, maxHeightM: 0.3, stages: CropStages(20, 30, 20, 10), plantingMonth: 4, rootDepthMinM: 0.4, rootDepthMaxM: 0.6, depletionFraction: 0.45),
  // Potato (T12: roots and tubers Kc ini 0.5; T17; T22); Potato, May, continental climate (T11); potato (FAO-29 T4).
  'crop.potato': CropData(key: 'crop.potato', kcIni: 0.50, kcMid: 1.15, kcEnd: 0.75, kcbIni: 0.15, kcbMid: 1.10, kcbEnd: 0.65, maxHeightM: 0.6, stages: CropStages(25, 30, 45, 30), plantingMonth: 5, rootDepthMinM: 0.4, rootDepthMaxM: 0.6, depletionFraction: 0.35, eceThreshold: 1.7, eceMax: 10),
  // Cassava, year 1 (T12, T17, T22); Cassava year 1, rainy season, tropical regions (T11).
  'crop.cassava': CropData(key: 'crop.cassava', kcIni: 0.30, kcMid: 0.80, kcEnd: 0.30, kcbIni: 0.15, kcbMid: 0.70, kcbEnd: 0.20, maxHeightM: 1.0, stages: CropStages(20, 40, 90, 60), plantingMonth: 10, rootDepthMinM: 0.5, rootDepthMaxM: 0.8, depletionFraction: 0.35),
  // Watermelon (T12, T17, T22); Water melons, April, Italy (T11).
  'crop.watermelon': CropData(key: 'crop.watermelon', kcIni: 0.40, kcMid: 1.00, kcEnd: 0.75, kcbIni: 0.15, kcbMid: 0.95, kcbEnd: 0.70, maxHeightM: 0.4, stages: CropStages(20, 30, 30, 30), plantingMonth: 4, rootDepthMinM: 0.8, rootDepthMaxM: 1.5, depletionFraction: 0.40),
  // Sweet melons (T12: cucurbit Kc ini 0.5; T17; T22); Sweet melons, May, Mediterranean (T11).
  'crop.melon': CropData(key: 'crop.melon', kcIni: 0.50, kcMid: 1.05, kcEnd: 0.75, kcbIni: 0.15, kcbMid: 1.00, kcbEnd: 0.70, maxHeightM: 0.4, stages: CropStages(25, 35, 40, 20), plantingMonth: 5, rootDepthMinM: 0.8, rootDepthMaxM: 1.5, depletionFraction: 0.40),
  // Maize, field (grain) (T12: cereals Kc ini 0.3, Kc end 0.60 for harvest at
  // high grain moisture, 0.35 after field drying; T17; T22); Maize (grain),
  // April, Spain and California (T11); corn (FAO-29 T4).
  'crop.maize': CropData(key: 'crop.maize', kcIni: 0.30, kcMid: 1.20, kcEnd: 0.60, kcbIni: 0.15, kcbMid: 1.15, kcbEnd: 0.50, maxHeightM: 2, stages: CropStages(30, 40, 50, 30), plantingMonth: 4, rootDepthMinM: 1.0, rootDepthMaxM: 1.7, depletionFraction: 0.55, eceThreshold: 1.7, eceMax: 10),
  // Sorghum, grain (T12: Kc mid 1.00–1.10; T17; T22); Sorghum, March/April, arid region (T11); sorghum (FAO-29 T4).
  'crop.sorghum': CropData(key: 'crop.sorghum', kcIni: 0.30, kcMid: 1.05, kcEnd: 0.55, kcbIni: 0.15, kcbMid: 1.00, kcbEnd: 0.35, maxHeightM: 1.5, stages: CropStages(20, 35, 45, 30), plantingMonth: 3, rootDepthMinM: 1.0, rootDepthMaxM: 2.0, depletionFraction: 0.55, eceThreshold: 6.8, eceMax: 13),
  // Spring wheat (T12: Kc end 0.25 machine-harvested, 0.4 by hand; T17; T22);
  // Barley/oats/wheat, March/April, 35–45° latitude (T11); wheat (FAO-29 T4).
  'crop.wheat': CropData(key: 'crop.wheat', kcIni: 0.30, kcMid: 1.15, kcEnd: 0.25, kcbIni: 0.15, kcbMid: 1.10, kcbEnd: 0.15, maxHeightM: 1, stages: CropStages(20, 25, 60, 30), plantingMonth: 3, rootDepthMinM: 1.0, rootDepthMaxM: 1.5, depletionFraction: 0.55, eceThreshold: 6.0, eceMax: 20),
  // Rice (T12: Kc end 0.90–0.60; T17; T22: p is a fraction of saturation);
  // Rice, Dec/May, tropics and Mediterranean (T11); rice, paddy (FAO-29 T4).
  'crop.rice': CropData(key: 'crop.rice', kcIni: 1.05, kcMid: 1.20, kcEnd: 0.75, kcbIni: 1.00, kcbMid: 1.15, kcbEnd: 0.575, maxHeightM: 1, stages: CropStages(30, 30, 60, 30), plantingMonth: 12, rootDepthMinM: 0.5, rootDepthMaxM: 1.0, depletionFraction: 0.20, eceThreshold: 3.0, eceMax: 11),
  // Soybeans (T12: legumes Kc ini 0.4; T17; T22); Soybeans, May, central USA (T11); soybean (FAO-29 T4).
  'crop.soybean': CropData(key: 'crop.soybean', kcIni: 0.40, kcMid: 1.15, kcEnd: 0.50, kcbIni: 0.15, kcbMid: 1.10, kcbEnd: 0.30, maxHeightM: 0.75, stages: CropStages(20, 35, 60, 25), plantingMonth: 5, rootDepthMinM: 0.6, rootDepthMaxM: 1.3, depletionFraction: 0.50, eceThreshold: 5.0, eceMax: 10),
  // Beans, dry and pulses (T12, T17, T22); Beans (dry), May/June, continental climates (T11); bean (FAO-29 T4).
  'crop.dryBean': CropData(key: 'crop.dryBean', kcIni: 0.40, kcMid: 1.15, kcEnd: 0.35, kcbIni: 0.15, kcbMid: 1.10, kcbEnd: 0.25, maxHeightM: 0.4, stages: CropStages(20, 30, 40, 20), plantingMonth: 5, rootDepthMinM: 0.6, rootDepthMaxM: 0.9, depletionFraction: 0.45, eceThreshold: 1.0, eceMax: 6.3),
  // Groundnut (peanut) (T12: legumes Kc ini 0.4; T17; T22); Groundnut, dry season, West Africa (T11); FAO-29 T4.
  'crop.peanut': CropData(key: 'crop.peanut', kcIni: 0.40, kcMid: 1.15, kcEnd: 0.60, kcbIni: 0.15, kcbMid: 1.10, kcbEnd: 0.50, maxHeightM: 0.4, stages: CropStages(25, 35, 45, 25), plantingMonth: 11, rootDepthMinM: 0.5, rootDepthMaxM: 1.0, depletionFraction: 0.50, eceThreshold: 3.2, eceMax: 6.6),
  // Cotton (T12: Kc mid 1.15–1.20, Kc end 0.70–0.50, h 1.2–1.5; T17; T22);
  // Cotton, March–May, Egypt, Pakistan, California (T11); cotton (FAO-29 T4).
  'crop.cotton': CropData(key: 'crop.cotton', kcIni: 0.35, kcMid: 1.175, kcEnd: 0.60, kcbIni: 0.15, kcbMid: 1.125, kcbEnd: 0.45, maxHeightM: 1.35, stages: CropStages(30, 50, 60, 55), plantingMonth: 3, rootDepthMinM: 1.0, rootDepthMaxM: 1.7, depletionFraction: 0.65, eceThreshold: 7.7, eceMax: 27),
  // Sunflower (T12: Kc mid 1.0–1.15, the higher value for irrigated dense
  // stands; T17; T22); Sunflower, April/May, Mediterranean and California (T11).
  'crop.sunflower': CropData(key: 'crop.sunflower', kcIni: 0.35, kcMid: 1.15, kcEnd: 0.35, kcbIni: 0.15, kcbMid: 1.10, kcbEnd: 0.25, maxHeightM: 2, stages: CropStages(25, 35, 45, 25), plantingMonth: 4, rootDepthMinM: 0.8, rootDepthMaxM: 1.5, depletionFraction: 0.45),
  // Sugar cane (T12, T17, T22); Sugarcane, ratoon, low latitudes (T11); sugarcane (FAO-29 T4).
  'crop.sugarcane': CropData(key: 'crop.sugarcane', kcIni: 0.40, kcMid: 1.25, kcEnd: 0.75, kcbIni: 0.15, kcbMid: 1.20, kcbEnd: 0.70, maxHeightM: 3, stages: CropStages(25, 70, 135, 50), plantingMonth: 4, rootDepthMinM: 1.2, rootDepthMaxM: 2.0, depletionFraction: 0.65, eceThreshold: 1.7, eceMax: 19),
  // Sugar cane planted (virgin) crop (T12, T17, T22); Sugarcane, virgin, low latitudes (T11, 405 days).
  'crop.sugarcanePlant': CropData(key: 'crop.sugarcanePlant', kcIni: 0.40, kcMid: 1.25, kcEnd: 0.75, kcbIni: 0.15, kcbMid: 1.20, kcbEnd: 0.70, maxHeightM: 3, stages: CropStages(35, 60, 190, 120), plantingMonth: 1, rootDepthMinM: 1.2, rootDepthMaxM: 2.0, depletionFraction: 0.65, eceThreshold: 1.7, eceMax: 19),
  // Sugar beet (T12: Kc end without irrigation in the last month; T17; T22); Sugarbeet, March, California (T11); FAO-29 T4.
  'crop.sugarbeet': CropData(key: 'crop.sugarbeet', kcIni: 0.35, kcMid: 1.20, kcEnd: 0.70, kcbIni: 0.15, kcbMid: 1.15, kcbEnd: 0.50, maxHeightM: 0.5, stages: CropStages(30, 45, 90, 15), plantingMonth: 3, rootDepthMinM: 0.7, rootDepthMaxM: 1.2, depletionFraction: 0.55, eceThreshold: 7.0, eceMax: 24),
  // Alfalfa hay, averaged cutting effects (T12; T17 has no averaged row);
  // Alfalfa for hay (T22); alfalfa (FAO-29 T4); season from frost to frost (T11 note 4).
  'crop.alfalfa': CropData(key: 'crop.alfalfa', kcIni: 0.40, kcMid: 0.95, kcEnd: 0.90, maxHeightM: 0.7, rootDepthMinM: 1.0, rootDepthMaxM: 2.0, depletionFraction: 0.55, eceThreshold: 2.0, eceMax: 16, perennial: true),
  // Grazing pasture, rotated grazing (T12: Kc mid 0.85–1.05, 0.90 kept from
  // the program's previous table; T17; T22); not staged in T11.
  'crop.pasture': CropData(key: 'crop.pasture', kcIni: 0.40, kcMid: 0.90, kcEnd: 0.85, kcbIni: 0.30, kcbMid: 0.85, kcbEnd: 0.80, maxHeightM: 0.225, rootDepthMinM: 0.5, rootDepthMaxM: 1.5, depletionFraction: 0.60, perennial: true),
  // Turf grass, warm season (bermuda, St. Augustine) (T12, T17, T22); bermuda grass (FAO-29 T4).
  'crop.turf': CropData(key: 'crop.turf', kcIni: 0.80, kcMid: 0.85, kcEnd: 0.85, kcbIni: 0.75, kcbMid: 0.80, kcbEnd: 0.80, maxHeightM: 0.10, rootDepthMinM: 0.5, rootDepthMaxM: 1.0, depletionFraction: 0.50, eceThreshold: 6.9, eceMax: 23, perennial: true),
  // Turf grass, cool season (bluegrass, ryegrass, fescue) (T12, T17, T22); tall fescue (FAO-29 T4).
  'crop.turfCool': CropData(key: 'crop.turfCool', kcIni: 0.90, kcMid: 0.95, kcEnd: 0.95, kcbIni: 0.85, kcbMid: 0.90, kcbEnd: 0.90, maxHeightM: 0.10, rootDepthMinM: 0.5, rootDepthMaxM: 1.0, depletionFraction: 0.40, eceThreshold: 3.9, eceMax: 20, perennial: true),
  // Pineapple, bare soil (T12, T17, T22); Pineapple, Hawaii (T11, 790 days).
  'crop.pineapple': CropData(key: 'crop.pineapple', kcIni: 0.50, kcMid: 0.30, kcEnd: 0.30, kcbIni: 0.15, kcbMid: 0.25, kcbEnd: 0.25, maxHeightM: 0.9, stages: CropStages(60, 120, 600, 10), rootDepthMinM: 0.3, rootDepthMaxM: 0.6, depletionFraction: 0.50),
  // Strawberries (T12, T17, T22); not staged in T11; strawberry (FAO-29 T4).
  'crop.strawberry': CropData(key: 'crop.strawberry', kcIni: 0.40, kcMid: 0.85, kcEnd: 0.75, kcbIni: 0.30, kcbMid: 0.80, kcbEnd: 0.70, maxHeightM: 0.2, rootDepthMinM: 0.2, rootDepthMaxM: 0.3, depletionFraction: 0.20, eceThreshold: 1.0, eceMax: 4.0),
};

/// FAO-56 single crop coefficient curve: Kc ini through the initial stage,
/// a straight line to Kc mid over the development stage, Kc mid through the
/// mid-season and a straight line to Kc end over the late season (eq. 66).
/// Time t is in days after planting (green-up for perennials), 0 at the
/// start of the planting day; outside the season the curve gives
/// [offSeasonKc] (0: no crop, no requirement).
class KcCurve {
  const KcCurve({required this.kcIni, required this.kcMid, required this.kcEnd, required this.stages, this.offSeasonKc = 0});

  /// Kc constant all year (evergreen crops without stage lengths).
  const KcCurve.constant(double kc) : kcIni = kc, kcMid = kc, kcEnd = kc, stages = const CropStages(0, 0, 365, 0), offSeasonKc = kc;

  final double kcIni;
  final double kcMid;
  final double kcEnd;
  final CropStages stages;
  final double offSeasonKc;

  double get seasonDays => stages.total;

  /// Kc at t days after planting (FAO-56 eq. 66 with i = t; Example 28).
  double at(double t) {
    if (t < 0 || t > seasonDays) return offSeasonKc;
    final s = stages;
    if (t <= s.initial) return kcIni;
    final devEnd = s.initial + s.development;
    if (t <= devEnd) return s.development <= 0 ? kcMid : kcIni + (t - s.initial) / s.development * (kcMid - kcIni);
    final midEnd = devEnd + s.mid;
    if (t <= midEnd) return kcMid;
    return s.late <= 0 ? kcEnd : kcMid + (t - midEnd) / s.late * (kcEnd - kcMid);
  }

  /// Mean Kc between t0 and t1 days after planting: the exact integral of
  /// the piecewise-linear curve (the "graphical" ten-day or monthly value of
  /// FAO-56 Figure 36), the off-season value counting where the interval
  /// leaves the season.
  double mean(double t0, double t1) {
    if (t1 <= t0) return at(t0);
    final s = stages;
    final knots = <double>[0, s.initial, s.initial + s.development, s.initial + s.development + s.mid, seasonDays];
    final pts = <double>{t0, t1, for (final k in knots) if (k > t0 && k < t1) k}.toList()..sort();
    var area = 0.0;
    for (var i = 0; i + 1 < pts.length; i++) {
      final a = pts[i], b = pts[i + 1];
      final m = (a + b) / 2;
      // inside a stage the curve is linear, so the midpoint rule is exact;
      // the off-season is constant
      area += at(m) * (b - a);
    }
    return area / (t1 - t0);
  }

  /// Copy with Kc mid and Kc end adjusted for climate (FAO-56 eqs. 62 and
  /// 65; Kc end only when its table value exceeds 0.45).
  KcCurve adjustedForClimate({required double windSpeed2mMs, required double rhMinPct, required double heightM, double? lateWindSpeed2mMs, double? lateRhMinPct}) => KcCurve(
    kcIni: kcIni,
    kcMid: adjustKcForClimate(kcMid, windSpeed2mMs: windSpeed2mMs, rhMinPct: rhMinPct, heightM: heightM),
    kcEnd: kcEnd > 0.45 ? adjustKcForClimate(kcEnd, windSpeed2mMs: lateWindSpeed2mMs ?? windSpeed2mMs, rhMinPct: lateRhMinPct ?? rhMinPct, heightM: heightM) : kcEnd,
    stages: stages,
    offSeasonKc: offSeasonKc,
  );

  /// Copy with every coefficient multiplied by [factor] (for example the
  /// localized irrigation reduction, or a stress coefficient).
  KcCurve scaled(double factor) => KcCurve(kcIni: kcIni * factor, kcMid: kcMid * factor, kcEnd: kcEnd * factor, stages: stages, offSeasonKc: offSeasonKc * factor);

  /// Copy with another Kc ini (for example from [kcIniFromWetting]).
  KcCurve withKcIni(double kc) => KcCurve(kcIni: kc, kcMid: kcMid, kcEnd: kcEnd, stages: stages, offSeasonKc: offSeasonKc);

  /// Copy with other stage lengths.
  KcCurve withStages(CropStages s) => KcCurve(kcIni: kcIni, kcMid: kcMid, kcEnd: kcEnd, stages: s, offSeasonKc: offSeasonKc);
}

/// Kc mid or Kc end adjusted for a climate other than RHmin = 45 % and
/// u2 = 2 m/s (FAO-56 eqs. 62 and 65): Kc + [0.04(u2 − 2) − 0.004(RHmin −
/// 45)](h/3)^0.3, with u2 limited to 1–6 m/s, RHmin to 20–80 % and h to
/// 0.1–10 m as FAO-56 requires.
double adjustKcForClimate(double kcTable, {required double windSpeed2mMs, required double rhMinPct, required double heightM}) {
  final u2 = windSpeed2mMs.clamp(1.0, 6.0), rh = rhMinPct.clamp(20.0, 80.0), h = heightM.clamp(0.1, 10.0);
  return kcTable + (0.04 * (u2 - 2) - 0.004 * (rh - 45)) * math.pow(h / 3, 0.3);
}

/// Depletion fraction p adjusted for the ETc rate (mm/day), FAO-56 Table 22
/// note 2: p = p(table) + 0.04·(5 − ETc), limited to 0.1–0.8.
double adjustDepletionFraction(double pTable, double etcMmDay) => (pTable + 0.04 * (5 - etcMmDay)).clamp(0.1, 0.8);

/// Wetting of the soil during the initial stage, for [kcIniFromWetting].
enum SoilWettingTexture {
  /// Sands and loamy sands (FAO-56 Figure 30a).
  coarse,

  /// Sandy loam to clay (Figure 30b).
  mediumFine,
}

/// Kc ini from the mean interval between wetting events [wettingIntervalDays]
/// (rain or irrigation), the mean ETo of the initial stage and the mean
/// infiltrated depth per event over the whole field [infiltrationDepthMm]:
/// FAO-56 Annex 7 eqs. 7-1 to 7-4 with the parameters that reproduce
/// Figure 29 (light wetting, ≤ 10 mm) and Figure 30a/b (heavy wetting,
/// ≥ 40 mm), eq. 59 between them, and eqs. 60–61 when only the fraction
/// [wettedFraction] of the surface is wetted (trickle, furrows).
double kcIniFromWetting({required double etoMmDay, required double wettingIntervalDays, double infiltrationDepthMm = 10, SoilWettingTexture texture = SoilWettingTexture.mediumFine, double wettedFraction = 1}) {
  final eto = math.max(etoMmDay, 0.1);
  final tw = math.max(wettingIntervalDays, 0.1);
  final fw = wettedFraction.clamp(0.01, 1.0);
  final iw = infiltrationDepthMm / fw; // eq. 61
  double kc(double tew, double rew) {
    final eso = 1.15 * eto; // eq. 7-1
    final t1 = rew / eso;
    if (tw <= t1) return 1.15; // eq. 7-4
    final v = (tew - (tew - rew) * math.exp(-(tw - t1) * eso * (1 + rew / (tew - rew)) / tew)) / (tw * eto); // eq. 7-3
    return math.min(v, 1.15);
  }

  final light = kc(10, math.min(math.max(2.5, 6 / math.sqrt(eto)), 7));
  final double heavy;
  if (texture == SoilWettingTexture.coarse) {
    final tew = math.min(15, 7 * math.sqrt(eto)).toDouble();
    heavy = kc(tew, math.min(6, tew - 0.01).toDouble());
  } else {
    final tew = math.min(28, 13 * math.sqrt(eto)).toDouble();
    heavy = kc(tew, math.min(9, tew - 0.01).toDouble());
  }
  final double v;
  if (iw <= 10) {
    v = light;
  } else if (iw >= 40) {
    v = heavy;
  } else {
    v = light + (iw - 10) / (40 - 10) * (heavy - light); // eq. 59
  }
  return fw * v; // eq. 60
}

/// Basal Kcb mid (or Kc mid) of sparse vegetation from the effective ground
/// cover, FAO-56 eq. 98: Kc min + (Kc full − Kc min)·min(1, 2·fc,
/// fc,eff^(1/(1+h))). [fcEffective] defaults to [groundCover].
double sparseCoverKc({required double kcFull, required double groundCover, double? fcEffective, required double heightM, double kcMin = 0.15}) {
  final fc = groundCover.clamp(0.0, 1.0), fe = (fcEffective ?? fc).clamp(0.0, 1.0);
  final kd = math.min(1.0, math.min(2 * fc, math.pow(fe, 1 / (1 + math.max(heightM, 0.0))).toDouble()));
  return kcMin + (kcFull - kcMin) * kd;
}

/// Reduction of ETc for localized irrigation (drip, micro-sprinklers) from
/// the fraction of the ground shaded by the canopy at noon.
enum LocalizedReductionMethod {
  /// Keller & Bliesner (1990): Kr = 0.1·√Pd, Pd = ground cover in %.
  kellerBliesner,

  /// Keller & Karmeli (1974): Kr = GC/0.85.
  kellerKarmeli,

  /// Freeman & Garzoli: Kr = GC + 0.5·(1 − GC) from 50 % cover, GC below it
  /// (as tabulated by FAO).
  freemanGarzoli,

  /// Decroix (CTGREF): Kr = 0.1 + GC.
  decroix,
}

/// Localized irrigation reduction factor Kr (≤ 1) for a ground cover
/// fraction [groundCover] (0–1). FAO (Savva & Frenken 2002, Module 9,
/// Table 1 and Example 1) lists the values of the last three methods and
/// applies the first as Td = Ud·[0.1·√Pd].
double localizedReductionFactor(double groundCover, {LocalizedReductionMethod method = LocalizedReductionMethod.kellerBliesner}) {
  final gc = groundCover.clamp(0.0, 1.0);
  final kr = switch (method) {
    LocalizedReductionMethod.kellerBliesner => 0.1 * math.sqrt(100 * gc),
    LocalizedReductionMethod.kellerKarmeli => gc / 0.85,
    LocalizedReductionMethod.freemanGarzoli => gc >= 0.5 ? gc + 0.5 * (1 - gc) : gc,
    LocalizedReductionMethod.decroix => 0.1 + gc,
  };
  return kr.clamp(0.0, 1.0);
}

/// Crop days and mean Kc of a calendar month for one crop cycle.
class MonthlyKc {
  const MonthlyKc({required this.year, required this.month, required this.cropDays, required this.monthDays, required this.kcDays});
  final int year;
  final int month;

  /// Days of the month with the crop in the field (Kc > 0).
  final int cropDays;
  final int monthDays;

  /// Σ Kc·day over the crop days (Kc-days); ETc = ETo·kcDays for a constant ETo.
  final double kcDays;

  /// Mean Kc over the crop days (0 without crop).
  double get meanKc => cropDays > 0 ? kcDays / cropDays : 0;

  /// Mean Kc over the whole month (off days counting zero).
  double get monthMeanKc => monthDays > 0 ? kcDays / monthDays : 0;
}

/// Days into the cycle at the start of [date] for a crop planted on
/// [planting] (null before planting or after the season). With
/// [repeatsYearly] the cycle restarts on every anniversary of the planting
/// date (perennials, or an annual crop planted every year on that day); a
/// cycle of a year or more then covers every day (the extra day of a leap
/// year takes the last day of the cycle), and a longer one is cut at the
/// anniversary.
double? daysIntoCycle(DateTime date, DateTime planting, double seasonDays, {bool repeatsYearly = false}) {
  final d = DateTime.utc(date.year, date.month, date.day);
  var start = DateTime.utc(planting.year, planting.month, planting.day);
  if (repeatsYearly) {
    start = DateTime.utc(d.year, planting.month, planting.day);
    if (start.isAfter(d)) start = DateTime.utc(d.year - 1, planting.month, planting.day);
  }
  final t = d.difference(start).inHours / 24;
  if (t < 0) return null;
  if (t >= seasonDays) return repeatsYearly && seasonDays >= 365 ? seasonDays - 1 : null;
  return t;
}

/// Kc of every month of [year] for a crop cycle planted on [planting] (see
/// [daysIntoCycle] for [repeatsYearly]); each day counts the exact mean of
/// the curve over that day.
List<MonthlyKc> monthlyKc(KcCurve curve, DateTime planting, int year, {bool repeatsYearly = true}) {
  final out = <MonthlyKc>[];
  for (var m = 1; m <= 12; m++) {
    final days = DateTime.utc(year, m + 1).difference(DateTime.utc(year, m)).inDays;
    var crop = 0;
    var sum = 0.0;
    for (var d = 1; d <= days; d++) {
      final t = daysIntoCycle(DateTime.utc(year, m, d), planting, curve.seasonDays, repeatsYearly: repeatsYearly);
      if (t == null) continue;
      final kc = curve.mean(t, math.min(t + 1, curve.seasonDays));
      if (kc <= 0) continue;
      crop++;
      sum += kc;
    }
    out.add(MonthlyKc(year: year, month: m, cropDays: crop, monthDays: days, kcDays: sum));
  }
  return out;
}

/// Mean Kc over [start]..[end] (inclusive dates) for a cycle planted on
/// [planting], and the number of crop days in that period.
(double meanKc, int cropDays) periodKc(KcCurve curve, DateTime planting, DateTime start, DateTime end, {bool repeatsYearly = false}) {
  var crop = 0;
  var sum = 0.0;
  for (var d = DateTime.utc(start.year, start.month, start.day); !d.isAfter(DateTime.utc(end.year, end.month, end.day)); d = d.add(const Duration(days: 1))) {
    final t = daysIntoCycle(d, planting, curve.seasonDays, repeatsYearly: repeatsYearly);
    if (t == null) continue;
    final kc = curve.mean(t, math.min(t + 1, curve.seasonDays));
    if (kc <= 0) continue;
    crop++;
    sum += kc;
  }
  return (crop > 0 ? sum / crop : 0, crop);
}
