/// Water requirement of the irrigated areas by month and growth stage: each
/// area with a crop of the FAO-56 table gets its requirement table from the
/// site climate (or, without one, from the ETo typed on the area), its
/// soil, method, salinity and the application rate of its emitters (the
/// inputs come from area_water.dart, the rule every report shares).
library;

import '../model/entities.dart';
import '../model/project.dart';
import 'area_water.dart';
import 'designer.dart';
import 'irrigation_requirement.dart';
import 'results.dart';

export 'area_water.dart' show PlantingRead, plantingDateOf, readPlantingDate, requirementInputOf, siteIsSouthern;

/// Requirement tables of every area with a crop of the table, keyed by
/// area id (application rates from [areaRequirements] with [results]).
Map<String, RequirementTable> areaRequirementTables(Project p, DesignResults? results) {
  final rates = {for (final q in areaRequirements(p, results)) q.areaId: q.precipitationMmH};
  return {
    for (final a in p.entities.whereType<AreaEntity>())
      if (requirementInputOf(p, a, applicationRateMmH: rates[a.id] ?? 0) case final input?) a.id: irrigationRequirement(input),
  };
}
