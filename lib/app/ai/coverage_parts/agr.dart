/// AI coverage of the functions added in 1.6.0 for agronomy, machines and electrical design (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageAgr = <String, String>{
  // ---- area panel: localized irrigation, the crop table (AGR-01, 08, 09, 11)
  'panel:properties.area.localizedKr': 'tool:update_entities',
  'panel:properties.area.yieldPotential': 'tool:update_entities',
  'panel:properties.area.climateKc': 'tool:update_entities',
  // ---- controller panel: what one output and the controller deliver (AGR-12)
  'panel:properties.controller.stationMaxA': 'tool:update_entities',
  'panel:properties.controller.totalMaxA': 'tool:update_entities',
  // ---- site climate: humidity, wind, station normals, areas' ETo (AGR-05, 09, 13)
  'dialog:agronomy_dialogs.siteClimate.rhMin': 'op:set_site_climate',
  'dialog:agronomy_dialogs.siteClimate.wind': 'op:set_site_climate',
  'dialog:agronomy_dialogs.siteClimate.stationNormals': 'op:eto_from_station_normals',
  'dialog:agronomy_dialogs.siteClimate.fillAreasEto': 'tool:update_entities',
  // ---- management: the month of the controller programme (AGR-05)
  'dialog:dialogs.management.scheduleMonth': 'op:controller_program',
  // ---- machines: the corner arm's own throw (AGR-07)
  'dialog:mechanised_dialogs.pivotMachine.armThrow': 'op:set_pivot_machine',
  // ---- gated pipe with fixed holes (AGR-23)
  'dialog:field_calculators.gatedPipeCalculator.fixedHoles': 'op:gated_pipe',
};
