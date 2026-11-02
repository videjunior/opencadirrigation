/// The water an irrigated area needs, by one rule shared by the water table,
/// the crop water table, the run times of the design and the controller
/// programme, so that the same field gives the same numbers in every report.
///
/// Localized irrigation (drip, micro-sprinklers) follows FAO-56 (Allen et
/// al. 1998, §9 and the note on localized irrigation of chapter 7) with the
/// reduction factor of Keller & Karmeli (1974) and Keller & Bliesner (1990,
/// Sprinkle and Trickle Irrigation, chapter 17): the crop transpires
/// ETc,loc = Kr·Kc·ETo over the whole area, Kr from the ground shaded by the
/// canopy (Kr = 0.1·√Pd, Pd in %, or typed); that depth sets the volumes and
/// the run times. The wetted fraction Pw only limits the water the soil
/// holds within the reach of the emitters: RAW = p·TAW·Pw (Keller &
/// Bliesner 1990 eq. 17.6), and the interval is RAW / ETc,loc. Sprinkler and
/// surface irrigation use Kr = Pw = 1.
///
/// Three sources, in order:
/// - a fixed net depth typed on the area (no water balance): the net
///   requirement over the whole area, every day;
/// - a crop of the FAO-56 table with the water balance: the requirement
///   table of the area (irrigation_requirement.dart), the month of largest
///   net requirement (the design month) or the month asked for;
/// - otherwise the water balance with the ETo and Kc typed on the area (or,
///   for a month asked for, the ETo of the site climate in that month).
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/project.dart';
import 'crops.dart';
import 'effective_rain.dart';
import 'irrigation_requirement.dart';
import 'soils.dart';

/// Whether area [a] is irrigated by localized irrigation: its method, or an
/// area left at the default sprinkler method whose wetted fraction is below
/// 1 (only localized irrigation wets part of the ground; areas drawn before
/// the method could be chosen keep their drip).
bool isLocalizedArea(AreaEntity a) => a.irrigationMethod == 'localized' || (a.irrigationMethod == 'sprinkler' && a.wettedFraction < 1 - 1e-9);

/// Irrigation method of area [a] for the requirement, the leaching formula
/// and the licensing category: `sprinkler`, `localized` or `surface`.
String areaIrrigationMethod(AreaEntity a) => isLocalizedArea(a) ? 'localized' : (a.irrigationMethod == 'surface' ? 'surface' : 'sprinkler');

/// Localized irrigation reduction factor Kr of area [a] (1 for sprinkler and
/// surface irrigation): typed on the area, else from its ground cover by
/// Keller & Bliesner (1990), Kr = 0.1·√(ground cover in %).
double areaKr(AreaEntity a) {
  if (!isLocalizedArea(a)) return 1;
  if (a.localizedKr > 0) return a.localizedKr.clamp(0.05, 1.0).toDouble();
  return localizedReductionFactor(a.groundCover);
}

/// Wetted fraction Pw of area [a] that limits its readily available water
/// (1 unless localized).
double areaPw(AreaEntity a) => isLocalizedArea(a) ? a.wettedFraction.clamp(0.05, 1.0).toDouble() : 1.0;

/// Sprinkle cover of area [a] for [maxSprinklerApplicationRateMmH]: grasses
/// and alfalfa take 25 % more.
SoilCover soilCoverOf(AreaEntity a) => const {'crop.turf', 'crop.turfCool', 'crop.pasture', 'crop.alfalfa'}.contains(a.cropKey) ? SoilCover.grass : SoilCover.average;

/// Largest sprinkler application rate (mm/h) the soil and slope of area [a]
/// take without runoff (USDA-SCS NEH Section 15 Chapter 11 Table 11-4);
/// null without a soil class.
double? soilRateLimitMmH(AreaEntity a) {
  final soil = soilTable[a.soilKey];
  return soil == null ? null : maxSprinklerApplicationRateMmH(soil.texture, a.slopePct, cover: soilCoverOf(a));
}

// ---------------------------------------------------------------- planting

/// How the planting date of an area was read.
enum PlantingRead {
  /// A date that has one reading.
  given,

  /// Day and month could be swapped (`05/09`): read day first, or month
  /// first when the language writes the month first.
  ambiguous,

  /// Not a date (`set-15` without a known month, `31/02`): the default used.
  invalid,

  /// No date: the planting month of the crop's FAO-56 row (six months later
  /// in the southern hemisphere), on the 1st.
  missing,
}

const _monthNames = <String, int>{
  'jan': 1, 'ene': 1, //
  'fev': 2, 'feb': 2,
  'mar': 3,
  'abr': 4, 'apr': 4,
  'mai': 5, 'may': 5,
  'jun': 6,
  'jul': 7,
  'ago': 8, 'aug': 8,
  'set': 9, 'sep': 9,
  'out': 10, 'oct': 10,
  'nov': 11,
  'dez': 12, 'dec': 12, 'dic': 12,
};

/// Whether the site of [p] is south of the equator (the site climate, else
/// the georeference); false when unknown.
bool siteIsSouthern(Project p) {
  final c = p.climate;
  if (c != null && c.latitudeDeg != 0) return c.latitudeDeg < 0;
  final g = p.meta.georef;
  return g != null && !g.north;
}

/// Planting (or green-up) date of area [a] in the typical [year] and how it
/// was read. The stored format is `MM-DD`; `DD/MM` and `DD.MM` (month second,
/// as most languages write it; [monthFirst] for languages that write the
/// month first), a month name or its first three letters in Portuguese,
/// English or Spanish (`15 set`, `sep-15`) are read too. A field above 12
/// can only be the day. Without a date, or with one that is not a date, the
/// planting month of the crop's FAO-56 row on the 1st (those rows are mostly
/// northern-hemisphere seasons: six months later when [southern]), else
/// January.
(DateTime, PlantingRead) readPlantingDate(AreaEntity a, {int year = 2001, bool southern = false, bool monthFirst = false}) {
  DateTime byDefault() {
    final crop = fao56Crops[a.cropKey];
    var m = crop?.plantingMonth ?? 1;
    if (southern && crop?.plantingMonth != null && crop?.stages != null) m = (m + 5) % 12 + 1;
    return DateTime.utc(year, m, 1);
  }

  final s = a.plantingMonthDay.trim().toLowerCase();
  if (s.isEmpty) return (byDefault(), PlantingRead.missing);
  DateTime? valid(int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    final last = DateTime.utc(year, month + 1, 0).day;
    return day > last ? null : DateTime.utc(year, month, day);
  }

  (DateTime, PlantingRead) result(DateTime? d, PlantingRead how) => d == null ? (byDefault(), PlantingRead.invalid) : (d, how);
  // a whole date: year first (ISO 8601) or last
  final iso = RegExp(r'^\d{4}\s*-\s*(\d{1,2})\s*-\s*(\d{1,2})$').firstMatch(s);
  if (iso != null) return result(valid(int.parse(iso.group(1)!), int.parse(iso.group(2)!)), PlantingRead.given);
  final withYear = RegExp(r'^(\d{1,2}\s*[-/.]\s*\d{1,2})\s*[-/.]\s*\d{2,4}$').firstMatch(s);
  final num = RegExp(r'^(\d{1,2})\s*([-/.])\s*(\d{1,2})$').firstMatch(withYear?.group(1) ?? s);
  if (num != null) {
    final f1 = int.parse(num.group(1)!), f2 = int.parse(num.group(3)!);
    final dash = num.group(2) == '-';
    // a field above 12 can only be the day
    if (f1 > 12 && f2 <= 12) return result(valid(f2, f1), PlantingRead.given);
    if (f2 > 12 && f1 <= 12) return result(valid(f1, f2), PlantingRead.given);
    if (dash) return result(valid(f1, f2), PlantingRead.given);
    final how = f1 == f2 ? PlantingRead.given : PlantingRead.ambiguous;
    return monthFirst ? result(valid(f1, f2), how) : result(valid(f2, f1), how);
  }
  int? monthOf(String w) => _monthNames[w.length >= 3 ? w.substring(0, 3) : w];
  final dayName = RegExp(r'^(\d{1,2})\s*(?:de\s+)?[-/. ]?\s*([a-zç]{3,})\.?$').firstMatch(s);
  if (dayName != null) {
    final m = monthOf(dayName.group(2)!);
    return result(m == null ? null : valid(m, int.parse(dayName.group(1)!)), PlantingRead.given);
  }
  final nameDay = RegExp(r'^([a-zç]{3,})\.?\s*[-/. ]?\s*(\d{1,2})$').firstMatch(s);
  if (nameDay != null) {
    final m = monthOf(nameDay.group(1)!);
    return result(m == null ? null : valid(m, int.parse(nameDay.group(2)!)), PlantingRead.given);
  }
  return (byDefault(), PlantingRead.invalid);
}

/// Planting date of [a] in the typical year (see [readPlantingDate]).
DateTime plantingDateOf(AreaEntity a, {int year = 2001, bool southern = false, bool monthFirst = false}) => readPlantingDate(a, year: year, southern: southern, monthFirst: monthFirst).$1;

// ---------------------------------------------------------------- crop table input

/// The requirement input of area [a] (null when it has no crop of the
/// FAO-56 table): the crop's curve with the root depth, depletion fraction
/// and available water typed on the area (the panel copies the table values
/// when the crop and the soil are chosen), Kr and Pw of [areaKr] and
/// [areaPw], the site climate (or the ETo typed on the area every month).
/// With [AreaEntity.climateKc] on, Kc mid and Kc end are adjusted to the
/// minimum humidity and wind of the climate when it has them (FAO-56 eqs. 62
/// and 65), and, for sprinkler and surface irrigation, Kc ini follows the
/// interval and depth of the irrigations of the initial stage ([wettingKcIni];
/// localized irrigation keeps the table's Kc ini: its partial wetting is
/// already in Kr and Pw). The depletion fraction is adjusted to the ETc of
/// each month (FAO-56 Table 22 note 2) only while it is the table's value.
RequirementInput? requirementInputOf(Project p, AreaEntity a, {double applicationRateMmH = 0}) {
  final crop = fao56Crops[a.cropKey];
  if (crop == null) return null;
  final localized = isLocalizedArea(a);
  final climate = p.climate;
  final normals = climate?.normals ?? ClimateNormals(etoMmDay: List.filled(12, a.etoMmDay), rainMm: List.filled(12, 0.0));
  final planting = plantingDateOf(a, southern: siteIsSouthern(p));
  final adjusted = (a.climateKc ? climateKcAdjustment(p, crop, planting) : null) ?? crop.curve;
  final tableP = crop.depletionFraction;
  RequirementInput inputWith(KcCurve curve) => RequirementInput(
    areaId: a.id,
    areaM2: a.area,
    cycles: [CropCycle.fromTable(a.cropKey, planting: planting, kr: areaKr(a), curve: curve, rootDepthM: a.rootDepthM, depletionFraction: a.mad)],
    climate: normals,
    rainMethod: EffectiveRainMethod.values.asNameMap()[a.rainMethod] ?? EffectiveRainMethod.usdaScs,
    useDependableRain: a.useDependableRain,
    efficiency: a.efficiency,
    applicationRateMmH: applicationRateMmH,
    wettedFraction: areaPw(a),
    awcMmPerM: a.awcMmPerM,
    rootDepthM: a.rootDepthM,
    depletionFraction: a.mad,
    adjustDepletionToEtc: tableP == null || (a.mad - tableP).abs() < 1e-6,
    ecwDsM: a.ecwDsM,
    leachingFormula: localized ? LeachingFormula.highFrequencyDrip : LeachingFormula.surfaceSprinkler,
    yieldPotentialPct: a.yieldPotentialPct.clamp(50.0, 100.0).toDouble(),
  );
  var input = inputWith(adjusted);
  if (a.climateKc && !localized && crop.stages != null && crop.stages!.initial > 0) {
    // the interval depends on Kc ini and Kc ini on the interval: a few passes
    final texture = soilTable[a.soilKey]?.texture;
    var kcIni = adjusted.kcIni;
    for (var pass = 0; pass < 4; pass++) {
      final next = wettingKcIni(input, planting, texture);
      if (next == null || (next - kcIni).abs() < 0.005) break;
      kcIni = next;
      input = inputWith(adjusted.withKcIni(kcIni));
    }
  }
  return input;
}

/// Kc ini of the crop of [input] from the irrigation of its initial stage:
/// the interval and the net depth per event of the row of the planting
/// month (the wetting interval and the infiltrated depth of FAO-56 eqs.
/// 59–61 and Annex 7, through [kcIniFromWetting]; coarse soils by Figure 30a,
/// the others by Figure 30b); null without that row.
double? wettingKcIni(RequirementInput input, DateTime planting, SoilTexture? texture) {
  final row = irrigationRequirement(input).monthly.where((r) => r.start.month == planting.month && r.cropDays > 0).firstOrNull;
  if (row == null || row.etoMmDay <= 0) return null;
  return kcIniFromWetting(
    etoMmDay: row.etoMmDay,
    wettingIntervalDays: row.intervalDays.toDouble(),
    infiltrationDepthMm: math.max(row.netPerEventMm, 1.0),
    texture: texture == SoilTexture.sand || texture == SoilTexture.loamySand ? SoilWettingTexture.coarse : SoilWettingTexture.mediumFine,
  );
}

/// The Kc curve of [crop] with Kc mid and Kc end adjusted to the minimum
/// relative humidity and the wind at 2 m of the site climate, averaged over
/// the days of the mid-season and of the late season of a cycle planted on
/// [planting] (FAO-56 eqs. 62 and 65, crop height of Table 12, the means of
/// the months those days fall in); null when the climate has no humidity or
/// wind, or the crop no height or no stages (evergreen rows keep Kc mid).
KcCurve? climateKcAdjustment(Project p, CropData crop, DateTime planting) {
  final c = p.climate;
  final rh = c?.rhMinPct, u2 = c?.windSpeed2mMs;
  final h = crop.maxHeightM, stages = crop.stages;
  if (c == null || rh == null || u2 == null || h == null || stages == null) return null;
  double meanOver(double from, double to, List<double> v) {
    var sum = 0.0;
    var n = 0;
    for (var t = from; t < to; t += 1) {
      sum += v[planting.add(Duration(days: t.floor())).month - 1];
      n++;
    }
    return n == 0 ? v[planting.add(Duration(days: from.floor())).month - 1] : sum / n;
  }

  final midStart = stages.initial + stages.development, midEnd = midStart + stages.mid, end = midEnd + stages.late;
  return crop.curve.adjustedForClimate(
    windSpeed2mMs: meanOver(midStart, midEnd, u2),
    rhMinPct: meanOver(midStart, midEnd, rh),
    heightM: h,
    lateWindSpeed2mMs: meanOver(midEnd, math.max(end, midEnd + 1), u2),
    lateRhMinPct: meanOver(midEnd, math.max(end, midEnd + 1), rh),
  );
}

// ---------------------------------------------------------------- the rule

/// Where the water need of an area comes from.
enum AreaWaterSource {
  /// The net depth per day typed on the area.
  fixedDepth,

  /// ETo and Kc typed on the area with its soil water balance.
  balance,

  /// The FAO-56 requirement table of the area's crop.
  cropTable,
}

/// The water need of one irrigated area in its design period.
class AreaWaterBasis {
  const AreaWaterBasis({
    required this.areaId,
    required this.source,
    required this.localized,
    required this.kr,
    required this.pw,
    this.month,
    required this.etoMmDay,
    required this.kc,
    required this.etcMmDay,
    required this.netMmDay,
    required this.grossMmDay,
    required this.rawMm,
    required this.intervalDays,
    this.warnings = const [],
  });
  final String areaId;
  final AreaWaterSource source;
  final bool localized;

  /// Localized reduction factor and wetted fraction (1 and 1 unless localized).
  final double kr;
  final double pw;

  /// Month (1–12) of the crop table row used: the design month (largest net
  /// requirement) or the one asked for; null for the other sources.
  final int? month;

  /// Mean ETo and Kc of the period (Kc 0 for a typed depth).
  final double etoMmDay;
  final double kc;

  /// Crop evapotranspiration over the whole area ETc,loc = Kr·Kc·ETo
  /// (mm/day), with the paddy water of rice: what one interval depletes.
  final double etcMmDay;

  /// Net requirement (ETc,loc less the effective rain) and gross
  /// requirement (net over the application efficiency, with the leaching
  /// requirement) per day over the whole area (mm/day).
  final double netMmDay;
  final double grossMmDay;

  /// Readily available water over the area, p·TAW·Pw (mm).
  final double rawMm;

  /// Days between irrigations: the whole days within RAW / ETc,loc (at least 1).
  final int intervalDays;

  /// Message codes of the crop table row (`req_*`).
  final List<String> warnings;

  /// Gross over net depth (efficiency and leaching).
  double get grossFactor => netMmDay > 0 ? grossMmDay / netMmDay : 1;

  /// Net and gross depth of one irrigation: the mean daily requirement of
  /// the period over the interval (the same volume as the daily figures).
  double get netPerEventMm => netMmDay * intervalDays;
  double get grossPerEventMm => grossMmDay * intervalDays;
}

/// The row of [table] for [month] (null: the design month, the largest net
/// requirement per day); null when the crop is not in the field that month.
RequirementRow? designRow(RequirementTable table, {int? month}) {
  if (month != null) return table.monthly.where((r) => r.start.month == month && r.cropDays > 0).firstOrNull;
  RequirementRow? best;
  for (final r in table.monthly) {
    if (r.cropDays == 0) continue;
    if (best == null || r.netMmDay > best.netMmDay + 1e-12) best = r;
  }
  return best;
}

/// The water need of area [a] of [p] by the rule of this library, for the
/// design period or for [month] (1–12).
AreaWaterBasis areaWaterBasis(Project p, AreaEntity a, {int? month}) {
  final localized = isLocalizedArea(a);
  final kr = areaKr(a), pw = areaPw(a);
  final eff = a.efficiency.clamp(0.05, 1.0).toDouble();
  if (!a.useWaterBalance) {
    final net = math.max(a.netDepthMmPerDay, 0.0);
    return AreaWaterBasis(
      areaId: a.id,
      source: AreaWaterSource.fixedDepth,
      localized: localized,
      kr: kr,
      pw: pw,
      etoMmDay: 0,
      kc: 0,
      etcMmDay: net,
      netMmDay: net,
      grossMmDay: net / eff,
      rawMm: net,
      intervalDays: 1,
    );
  }
  final input = requirementInputOf(p, a);
  if (input != null) {
    final table = irrigationRequirement(input);
    final row = designRow(table, month: month);
    if (row == null) {
      return AreaWaterBasis(
        areaId: a.id,
        source: AreaWaterSource.cropTable,
        localized: localized,
        kr: kr,
        pw: pw,
        month: month,
        etoMmDay: p.climate?.etoMmDay[(month ?? 1) - 1] ?? a.etoMmDay,
        kc: 0,
        etcMmDay: 0,
        netMmDay: 0,
        grossMmDay: 0,
        rawMm: 0,
        intervalDays: 1,
      );
    }
    final n = math.max(row.cropDays, 1);
    return AreaWaterBasis(
      areaId: a.id,
      source: AreaWaterSource.cropTable,
      localized: localized,
      kr: row.kr,
      pw: pw,
      month: row.start.month,
      etoMmDay: row.etoMmDay,
      kc: row.kc,
      etcMmDay: (row.etcLocMm + row.extraMm) / n,
      netMmDay: row.netMmDay,
      grossMmDay: row.grossMmDay,
      rawMm: row.rawMm,
      intervalDays: row.intervalDays,
      warnings: row.warnings,
    );
  }
  final c = p.climate;
  final eto = month != null && c != null ? c.etoMmDay[(month - 1).clamp(0, 11)] : a.etoMmDay;
  final etc = math.max(eto * a.kc * kr, 0.0);
  final raw = math.max(a.awcMmPerM, 0.0) * math.max(a.rootDepthM, 0.0) * a.mad.clamp(0.05, 0.95) * pw;
  final interval = etc > 0 ? math.max(1, (raw / etc).floor()) : 1;
  return AreaWaterBasis(
    areaId: a.id,
    source: AreaWaterSource.balance,
    localized: localized,
    kr: kr,
    pw: pw,
    month: month,
    etoMmDay: eto,
    kc: a.kc,
    etcMmDay: etc,
    netMmDay: etc,
    grossMmDay: etc / eff,
    rawMm: raw,
    intervalDays: interval,
  );
}
