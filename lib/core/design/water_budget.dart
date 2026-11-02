/// Landscape water budget and cycle-and-soak scheduling.
///
/// Water budget: California Model Water Efficient Landscape Ordinance
/// (MWELO, California Code of Regulations, Title 23, §§ 490–495, 2015
/// revision, Appendix B):
/// - MAWA = ETo·0.62·[(ETAF·LA) + ((1 − ETAF)·SLA)] (US gallons per year
///   with ETo in inches per year and areas in ft²; 0.62 converts acre-inches
///   per acre to gallons per ft²), ETAF 0.55 for residential and 0.45 for
///   non-residential areas, LA the whole landscape area including SLA;
/// - ETWU = ETo·0.62·Σ(ETAF·HA) over the hydrozones, ETAF = PF/IE for regular
///   areas and 1.0 for special landscape areas (SLA: edible plants,
///   recreational areas, recycled water), IE = 0.75 for overhead spray and
///   0.81 for drip;
/// - plant factor ranges (§ 491): very low 0–0.1, low 0.1–0.3, moderate
///   0.4–0.6, high 0.7–1.0 (from "Water Use Classification of Landscape
///   Species", University of California Cooperative Extension);
/// - the metric equivalent: ETo in mm and areas in m² give litres
///   (1 mm on 1 m² = 1 L), no conversion factor.
///
/// Cycle and soak: maximum run time before runoff Rt = 60·ASA/(PR − IR)
/// minutes and a minimum time from the start of one cycle to the next of
/// Da/IR (Da = depth applied per cycle), Irrigation Association SWAT 8th
/// draft testing protocol for climatologically based controllers (2008),
/// section 4.3, as adopted by the US EPA WaterSense specification for
/// weather-based irrigation controllers; the intake rate IR and the
/// allowable surface accumulation ASA by soil and slope come from its
/// Table 3 (soils.dart).
library;

import 'dart:math' as math;

import 'soils.dart';

/// Gallons per ft² per inch of water, MWELO conversion factor.
const double mweloConversionFactor = 0.62;

/// MWELO irrigation efficiencies (§ 492.13).
const double mweloEfficiencySpray = 0.75;
const double mweloEfficiencyDrip = 0.81;

/// MWELO evapotranspiration adjustment factors (§ 491).
const double mweloEtafResidential = 0.55;
const double mweloEtafNonResidential = 0.45;

/// Plant water use categories of MWELO § 491 (WUCOLS ranges).
enum PlantWaterUse { veryLow, low, moderate, high }

/// Plant factor range of a water use category.
(double, double) plantFactorRange(PlantWaterUse use) => switch (use) {
  PlantWaterUse.veryLow => (0.0, 0.1),
  PlantWaterUse.low => (0.1, 0.3),
  PlantWaterUse.moderate => (0.4, 0.6),
  PlantWaterUse.high => (0.7, 1.0),
};

/// Category of a plant factor (values between the MWELO ranges, 0.3–0.4 and
/// 0.6–0.7, go to the nearer range).
PlantWaterUse plantWaterUseOf(double plantFactor) {
  final pf = plantFactor.clamp(0.0, 1.0);
  if (pf <= 0.1) return PlantWaterUse.veryLow;
  if (pf <= 0.35) return PlantWaterUse.low;
  if (pf < 0.65) return PlantWaterUse.moderate;
  return PlantWaterUse.high;
}

/// One hydrozone of the landscape.
class Hydrozone {
  const Hydrozone({required this.id, required this.area, required this.plantFactor, this.irrigationEfficiency = mweloEfficiencySpray, this.specialLandscapeArea = false});
  final String id;

  /// m² for metric budgets, ft² for US budgets.
  final double area;
  final double plantFactor;
  final double irrigationEfficiency;

  /// Special landscape area (ETAF 1.0).
  final bool specialLandscapeArea;

  /// ETAF = PF/IE (1.0 for SLA).
  double get etaf => specialLandscapeArea ? 1.0 : plantFactor / math.max(irrigationEfficiency, 0.01);
}

/// Units of a water budget.
enum BudgetUnits {
  /// ETo in mm/year, areas in m², water in litres.
  metric,

  /// ETo in inches/year, areas in ft², water in US gallons.
  us,
}

/// MWELO water budget of a landscape.
class WaterBudget {
  const WaterBudget({
    required this.units,
    required this.mawa,
    required this.etwu,
    required this.landscapeArea,
    required this.specialArea,
    required this.averageEtaf,
    required this.etafLimit,
    required this.perHydrozone,
  });
  final BudgetUnits units;

  /// Maximum applied water allowance and estimated total water use per year
  /// (litres or US gallons).
  final double mawa;
  final double etwu;

  /// Total landscape area LA (with SLA) and special landscape area SLA.
  final double landscapeArea;
  final double specialArea;

  /// Area-weighted ETAF of the regular areas, and the ordinance limit.
  final double averageEtaf;
  final double etafLimit;

  /// Estimated water use per hydrozone id.
  final Map<String, double> perHydrozone;

  /// ETWU within MAWA and the average ETAF within the limit.
  bool get complies => etwu <= mawa * (1 + 1e-9) && averageEtaf <= etafLimit + 1e-9;
}

/// MAWA (litres per year in metric, US gallons in US units).
double maximumAppliedWaterAllowance({required double etoPerYear, required double landscapeArea, double specialArea = 0, double etaf = mweloEtafResidential, BudgetUnits units = BudgetUnits.metric}) {
  final k = units == BudgetUnits.us ? mweloConversionFactor : 1.0;
  return etoPerYear * k * (etaf * landscapeArea + (1 - etaf) * specialArea);
}

/// MWELO budget of [hydrozones] for an annual ETo ([etoPerYear], mm or in).
WaterBudget mweloWaterBudget({required double etoPerYear, required List<Hydrozone> hydrozones, bool residential = true, BudgetUnits units = BudgetUnits.metric}) {
  final k = units == BudgetUnits.us ? mweloConversionFactor : 1.0;
  var la = 0.0, sla = 0.0, regularArea = 0.0, regularEtafArea = 0.0, etwu = 0.0;
  final per = <String, double>{};
  for (final h in hydrozones) {
    final a = math.max(h.area, 0.0);
    la += a;
    if (h.specialLandscapeArea) {
      sla += a;
    } else {
      regularArea += a;
      regularEtafArea += h.etaf * a;
    }
    final w = etoPerYear * k * h.etaf * a;
    per[h.id] = (per[h.id] ?? 0) + w;
    etwu += w;
  }
  final limit = residential ? mweloEtafResidential : mweloEtafNonResidential;
  return WaterBudget(
    units: units,
    mawa: maximumAppliedWaterAllowance(etoPerYear: etoPerYear, landscapeArea: la, specialArea: sla, etaf: limit, units: units),
    etwu: etwu,
    landscapeArea: la,
    specialArea: sla,
    averageEtaf: regularArea > 0 ? regularEtafArea / regularArea : 0,
    etafLimit: limit,
    perHydrozone: per,
  );
}

/// Cycle-and-soak schedule of one station.
class CycleSoak {
  const CycleSoak({
    required this.totalRunMinutes,
    required this.maxCycleMinutes,
    required this.cycles,
    required this.runMinutesPerCycle,
    required this.depthPerCycleMm,
    required this.soakMinutes,
    required this.windowMinutes,
    required this.runoffFree,
  });

  /// Run time needed for the whole depth at the precipitation rate.
  final double totalRunMinutes;

  /// Longest run before runoff (infinite when the soil takes the rate).
  final double maxCycleMinutes;
  final int cycles;
  final double runMinutesPerCycle;
  final double depthPerCycleMm;

  /// Minimum pause between the end of one cycle and the start of the next.
  final double soakMinutes;

  /// From the start of the first cycle to the end of the last.
  final double windowMinutes;

  /// False when the cycles had to be longer than [maxCycleMinutes] (the
  /// shortest practical cycle or the most cycles allowed), so some water runs
  /// off.
  final bool runoffFree;

  bool get needsCycling => cycles > 1;
}

/// Cycles and soak time to apply [depthMm] at [precipitationRateMmH] on a
/// soil of basic intake rate [intakeRateMmH] holding [allowableSurfaceMm] of
/// free water before runoff (SWAT protocol: Rt = 60·ASA/(PR − IR); the
/// next cycle starts no earlier than Da/IR after the previous one started).
/// [minCycleMinutes] and [maxCycles] keep the schedule practical for a
/// controller (cycles are merged to respect them, which may cause runoff:
/// see [CycleSoak.runoffFree]).
CycleSoak cycleAndSoak({
  required double precipitationRateMmH,
  required double depthMm,
  required double intakeRateMmH,
  required double allowableSurfaceMm,
  double minCycleMinutes = 0,
  int maxCycles = 24,
}) {
  final pr = math.max(precipitationRateMmH, 1e-9);
  final ir = math.max(intakeRateMmH, 1e-9);
  final depth = math.max(depthMm, 0.0);
  final total = 60 * depth / pr;
  final maxCycle = pr > ir ? 60 * math.max(allowableSurfaceMm, 0.0) / (pr - ir) : double.infinity;
  var cycles = 0;
  if (total > 0) {
    final needed = maxCycle.isFinite ? total / math.max(maxCycle, 1e-9) : 1.0;
    cycles = needed > maxCycles ? maxCycles : math.max(1, (needed - 1e-9).ceil());
    if (minCycleMinutes > 0 && cycles > 1) cycles = math.min(cycles, math.max(1, (total / minCycleMinutes).floor()));
    cycles = cycles.clamp(1, math.max(maxCycles, 1));
  }
  final run = cycles > 0 ? total / cycles : 0.0;
  final perCycle = cycles > 0 ? depth / cycles : 0.0;
  // start-to-start interval Da/IR, minus the run time already elapsed
  final soak = cycles > 1 ? math.max(60 * perCycle / ir - run, 0.0) : 0.0;
  return CycleSoak(
    totalRunMinutes: total,
    maxCycleMinutes: maxCycle,
    cycles: cycles,
    runMinutesPerCycle: run,
    depthPerCycleMm: perCycle,
    soakMinutes: soak,
    windowMinutes: cycles > 0 ? cycles * run + (cycles - 1) * soak : 0,
    runoffFree: !maxCycle.isFinite || run <= maxCycle * (1 + 1e-9),
  );
}

/// [cycleAndSoak] with the intake rate and allowable surface accumulation
/// of a USDA texture class and slope (%) from the SWAT/EPA table.
CycleSoak cycleAndSoakForSoil({
  required double precipitationRateMmH,
  required double depthMm,
  required SoilTexture texture,
  required double slopePct,
  double minCycleMinutes = 0,
  int maxCycles = 24,
}) => cycleAndSoak(
  precipitationRateMmH: precipitationRateMmH,
  depthMm: depthMm,
  intakeRateMmH: soilOf(texture).basicIntakeMmH,
  allowableSurfaceMm: allowableSurfaceAccumulationMm(texture, slopePct),
  minCycleMinutes: minCycleMinutes,
  maxCycles: maxCycles,
);
