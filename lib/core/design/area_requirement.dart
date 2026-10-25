/// Water requirement of the irrigated areas by month and growth stage: each
/// area with a crop of the FAO-56 table gets its requirement table from the
/// site climate (or, without one, from the ETo typed on the area), its
/// soil, method, salinity and the application rate of its emitters.
library;

import '../model/entities.dart';
import '../model/project.dart';
import 'crops.dart';
import 'designer.dart';
import 'effective_rain.dart';
import 'irrigation_requirement.dart';
import 'results.dart';
import 'soils.dart';

/// Planting date of [a] in the typical year (`MM-DD`, else the planting
/// month of the crop's FAO-56 row, else January).
DateTime plantingDateOf(AreaEntity a, {int year = 2001}) {
  final m = RegExp(r'^\s*(\d{1,2})\s*[-/.]\s*(\d{1,2})\s*$').firstMatch(a.plantingMonthDay);
  if (m != null) {
    final month = int.parse(m.group(1)!).clamp(1, 12);
    final day = int.parse(m.group(2)!).clamp(1, 31);
    final last = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, day > last ? last : day);
  }
  return DateTime.utc(year, fao56Crops[a.cropKey]?.plantingMonth ?? 1, 1);
}

/// The requirement input of area [a], or null when it has no crop of the
/// table.
RequirementInput? requirementInputOf(Project p, AreaEntity a, {double applicationRateMmH = 0}) {
  if (!fao56Crops.containsKey(a.cropKey)) return null;
  final localized = a.irrigationMethod == 'localized';
  final kr = localized ? localizedReductionFactor(a.groundCover) : 1.0;
  final climate = p.climate?.normals ?? ClimateNormals(etoMmDay: List.filled(12, a.etoMmDay), rainMm: List.filled(12, 0.0));
  final soil = soilTable[a.soilKey];
  return RequirementInput(
    areaId: a.id,
    areaM2: a.area,
    cycles: [CropCycle.fromTable(a.cropKey, planting: plantingDateOf(a), kr: kr)],
    climate: climate,
    rainMethod: EffectiveRainMethod.values.asNameMap()[a.rainMethod] ?? EffectiveRainMethod.usdaScs,
    useDependableRain: a.useDependableRain,
    efficiency: a.efficiency,
    applicationRateMmH: applicationRateMmH,
    wettedFraction: a.wettedFraction,
    awcMmPerM: soil?.awcMmPerM ?? a.awcMmPerM,
    rootDepthM: a.rootDepthM,
    depletionFraction: a.mad,
    ecwDsM: a.ecwDsM,
    leachingFormula: localized ? LeachingFormula.highFrequencyDrip : LeachingFormula.surfaceSprinkler,
  );
}

/// Requirement tables of every area with a crop of the table, keyed by
/// area id (application rates from [areaRequirements] with [results]).
Map<String, RequirementTable> areaRequirementTables(Project p, DesignResults? results) {
  final rates = {for (final q in areaRequirements(p, results)) q.areaId: q.precipitationMmH};
  return {
    for (final a in p.entities.whereType<AreaEntity>())
      if (requirementInputOf(p, a, applicationRateMmH: rates[a.id] ?? 0) case final input?) a.id: irrigationRequirement(input),
  };
}
