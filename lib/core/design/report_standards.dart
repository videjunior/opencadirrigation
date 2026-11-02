/// The standards behind the criteria of the reports (1.6.0 PRD): each report
/// table names, under its title, the criteria it shows and the standards
/// (ABNT NBR, ISO, EN/UNE-EN, ASABE, AWWA, IEC) or references (FAO, NRCS,
/// CONAMA) each one follows, so the reader of a memorial or of a permit
/// application sees where every limit comes from. The criteria and the
/// references are listed once here ([reportCriteria]); [reportTableCriteria]
/// says which apply to which table.
///
/// The references, by subject:
/// - sprinklers and solid-set systems: ISO 15886-3 (distribution uniformity
///   of sprinklers: CU and DU), UNE-EN 13742-1 (selection, design, planning
///   and installation of solid-set sprinkler systems), UNE-EN 14049 (water
///   application intensity: calculation and measurement);
/// - micro-irrigation: ASABE EP405.1 (design and installation; the design
///   emission uniformity EU of Keller and Karmeli), UNE-EN 15097 (hydraulic
///   evaluation of localised irrigation), ISO 9261 and ABNT NBR ISO 9261
///   (emitters and emitting pipe: flow, manufacturing variation), ABNT NBR
///   15084 (micro-sprinklers);
/// - pipelines: ASAE S376.2 (buried thermoplastic irrigation pipelines:
///   velocity, cover), ISO 1452-2 (PVC-U) and ISO 4427-2 (PE) pipes and
///   their derating with temperature, ABNT NBR 14312 (PVC irrigation pipe),
///   AWWA M23 and M55 (surge allowance of PVC and PE pipe), NRCS conservation
///   practice standard 441 (flushing velocity of micro-irrigation laterals);
/// - pumps and valves: ISO 9906 (pump acceptance tolerances), IEC 60534
///   (valve flow coefficients);
/// - centre pivots: ISO 11545 and ABNT NBR ISO 11545 (uniformity of machines
///   with sprayers or sprinklers), ABNT NBR 14244 (uniformity of pivots and
///   lateral moves), ASABE S436.1 (uniformity test), NRCS NEH 623 (sprinkle
///   irrigation design);
/// - electricity: IEC 60364-5-52 and ABNT NBR 5410 (voltage drop and cable
///   sizing), IEC 60228 (conductors);
/// - water requirement: FAO Irrigation and Drainage Paper 56 (ETo, Kc) and
///   29 (salinity, leaching);
/// - Brazil's environmental licensing of irrigation: CONAMA Resolution 284/2001;
/// - terrain: slope classes after the USDA Soil Survey Manual.
library;

import '../translate.dart';
import 'report_tables.dart';

/// A criterion of the reports and the standards it follows ([key] is its
/// i18n key `prd.std.<key>`).
class ReportCriterion {
  const ReportCriterion(this.key, this.refs);
  final String key;
  final List<String> refs;
}

/// Every criterion the reports name, by key.
const reportCriteria = <String, List<String>>{
  'sprinklerUniformity': ['ISO 15886-3', 'UNE-EN 13742-1'],
  'emissionUniformity': ['ASABE EP405.1', 'UNE-EN 15097'],
  'emitters': ['ISO 9261', 'ABNT NBR ISO 9261', 'ABNT NBR 15084'],
  'pressureVariation': ['ASABE EP405.1', 'UNE-EN 13742-1', 'UNE-EN 15097'],
  'applicationRate': ['UNE-EN 14049'],
  'velocity': ['ASAE S376.2'],
  'pipeClass': ['ISO 1452-2', 'ISO 4427-2', 'ABNT NBR 14312'],
  'cover': ['ASAE S376.2'],
  'surge': ['AWWA M23', 'AWWA M55'],
  'flushing': ['ASABE EP405.1', 'NRCS CPS 441'],
  'pumpTolerance': ['ISO 9906'],
  'valveFlow': ['IEC 60534'],
  'pivotUniformity': ['ISO 11545', 'ABNT NBR ISO 11545', 'ABNT NBR 14244', 'ASABE S436.1'],
  'pivotDesign': ['NRCS NEH 623'],
  'voltageDrop': ['IEC 60364-5-52', 'ABNT NBR 5410', 'IEC 60228'],
  'cropWater': ['FAO 56'],
  'salinity': ['FAO 29'],
  'licensing': ['CONAMA 284/2001'],
  'slopeClasses': ['USDA Soil Survey Manual'],
};

/// The criteria of each report table (by its key), in the order they are named.
const reportTableCriteria = <String, List<String>>{
  'zones': ['sprinklerUniformity', 'emissionUniformity', 'emitters', 'pressureVariation'],
  'pipes': ['velocity', 'pipeClass'],
  'outlets': ['emitters'],
  'mainline': ['velocity', 'pipeClass'],
  'devices': ['pumpTolerance', 'valveFlow'],
  'trench': ['cover'],
  'pivots': ['pivotUniformity', 'pivotDesign'],
  'pivotPackage': ['pivotDesign'],
  'pivotPackageSummary': ['pivotDesign'],
  'pivotTimer': ['pivotDesign'],
  'electrical': ['voltageDrop'],
  'pivotElectrical': ['voltageDrop'],
  'flushing': ['flushing'],
  'surge': ['surge', 'pipeClass'],
  'crop': ['cropWater'],
  'schedule': ['cropWater'],
  'requirement': ['cropWater', 'salinity'],
  'requirementTotals': ['cropWater'],
  'water': ['cropWater', 'applicationRate'],
  'licensing': ['licensing'],
  'slopeClasses': ['slopeClasses'],
};

/// The criteria of the table [key] with their standards (empty when it
/// follows none).
List<ReportCriterion> criteriaOf(String key) => [
  for (final c in reportTableCriteria[key] ?? const <String>[])
    if (reportCriteria[c] != null) ReportCriterion(c, reportCriteria[c]!),
];

/// The note printed under the title of table [key]: "Criteria and standards:
/// sprinkler uniformity (CU, DU) — ISO 15886-3, UNE-EN 13742-1; …"; empty
/// when the table follows none.
String standardsNote(String key, Translate t) {
  final cs = criteriaOf(key);
  if (cs.isEmpty) return '';
  return t('prd.std.note', {'list': [for (final c in cs) '${t('prd.std.${c.key}')} — ${c.refs.join(', ')}'].join('; ')});
}

/// Writes the standards note of every table of [tables] into its
/// [ReportTable.standards] (the report writers print it).
void attachStandards(List<ReportTable> tables, Translate t) {
  for (final tb in tables) {
    tb.standards = standardsNote(tb.key, t);
  }
}
