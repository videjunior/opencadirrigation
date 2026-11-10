/// AI coverage of the functions added in 1.7.0 for the climate risk over the years (Design → Agronomy) (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageClr = <String, String>{
  // ---- Design → Agronomy (desktop menu and phone menu)
  'menu:clr.menu': 'op:climate_risk',
  // ---- the dialog of lib/app/widgets/dialogs/climate_risk_dialog.dart and its options
  'dialog:climate_risk_dialog.climateRisk': 'op:climate_risk',
  'dialog:climate_risk_dialog.climateRisk.source': 'op:climate_risk',
  'dialog:climate_risk_dialog.climateRisk.probability': 'op:climate_risk',
  'dialog:climate_risk_dialog.climateRisk.peakDays': 'op:climate_risk',
  'dialog:climate_risk_dialog.climateRisk.run': 'op:climate_risk',
  'dialog:climate_risk_dialog.climateRisk.view': 'op:climate_risk',
  'dialog:climate_risk_dialog.climateRisk.tables': 'tool:get_report_table',
};
