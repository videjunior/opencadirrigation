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
  'dialog:agronomy_dialogs.siteClimate.rhMin': 'n/a:pending-ai — set_site_climate needs rh_min_pct (12 monthly minimum relative humidities, %) for the Kc adjustment',
  'dialog:agronomy_dialogs.siteClimate.wind': 'n/a:pending-ai — set_site_climate needs wind_2m_ms (12 monthly wind speeds at 2 m, m/s) for the Kc adjustment',
  'dialog:agronomy_dialogs.siteClimate.stationNormals': 'n/a:pending-ai — an operation that works out the monthly FAO-56 Penman-Monteith ETo from the normals of a station (Tmax, Tmin, mean RH, wind and its height, sunshine, rain, latitude, elevation) and stores it with RHmin and u2 in the site climate',
  'dialog:agronomy_dialogs.siteClimate.fillAreasEto': 'tool:update_entities',
  // ---- management: the month of the controller programme (AGR-05)
  'dialog:dialogs.management.scheduleMonth': 'n/a:pending-ai — controller_program needs month (1–12; omitted = the design month of every area)',
  // ---- machines: the corner arm's own throw (AGR-07)
  'dialog:mechanised_dialogs.pivotMachine.armThrow': 'n/a:pending-ai — set_pivot_machine needs corner_arm_throw_m (the throw of the arm\'s last sprinkler; null = the machine\'s end throw)',
  // ---- gated pipe with fixed holes (AGR-23)
  'dialog:field_calculators.gatedPipeCalculator.fixedHoles':
      'n/a:pending-ai — gated_pipe needs fixed_holes (solve with every hole fully open: delivered flows, inlet flow and the uniformity among the furrows)',
};
