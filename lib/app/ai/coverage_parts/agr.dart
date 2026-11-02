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
  // ---- 1.6.0 wave 2: the Agronomy submenu of Design (desktop) and the Design section (phone)
  'menu:swb.menu': 'op:water_balance',
  'menu:prog.menu': 'op:irrigation_programme',
  'menu:ro.menu': 'op:runoff_potential',
  'menu:fst.menu': 'op:fertigation_by_stage',
  'menu:ft.menu': 'op:field_test_evaluation',
  'menu:uc.menu': 'op:list_user_crops',
  // ---- the Agronomy tab of the reports
  'menu:reports.agronomy': 'op:show_report_tab',
  'panel:reports.agronomy': 'tool:get_report_table',
  // ---- daily soil water balance (FAO-56 ch. 8, deficit irrigation)
  'dialog:water_balance_dialogs.waterBalance': 'op:water_balance',
  'dialog:water_balance_dialogs.waterBalance.trigger': 'op:water_balance',
  'dialog:water_balance_dialogs.waterBalance.deficit': 'op:water_balance',
  'dialog:water_balance_dialogs.waterBalance.weather': 'op:water_balance',
  'dialog:water_balance_dialogs.waterBalance.save': 'op:water_balance',
  'dialog:water_balance_dialogs.waterBalance.events': 'op:water_balance',
  // ---- potential runoff of the machines and the sprinkler areas
  'dialog:water_balance_dialogs.runoffPotential': 'op:runoff_potential',
  'dialog:water_balance_dialogs.runoffPotential.soil': 'op:runoff_potential',
  'dialog:water_balance_dialogs.runoffPotential.initialIrrigation': 'op:runoff_potential',
  // ---- the irrigation programme (window, cycle and soak, seasonal adjustment, stations by month)
  'dialog:water_balance_dialogs.irrigationProgramme': 'op:irrigation_programme',
  'dialog:water_balance_dialogs.irrigationProgramme.window': 'op:irrigation_programme',
  'dialog:water_balance_dialogs.irrigationProgramme.cycleSoak': 'op:irrigation_programme',
  'dialog:water_balance_dialogs.irrigationProgramme.seasonal': 'op:irrigation_programme',
  'dialog:water_balance_dialogs.irrigationProgramme.inReports': 'op:irrigation_programme',
  'dialog:water_balance_dialogs.irrigationProgramme.capacity': 'op:system_capacity',
  'dialog:water_balance_dialogs.irrigationProgramme.exportStations': 'op:export_irrigation_programme',
  'dialog:water_balance_dialogs.irrigationProgramme.exportRuns': 'op:export_irrigation_programme',
  // ---- user crops (PRD-15)
  'dialog:crop_plan_dialogs.userCrops': 'op:set_user_crop',
  'dialog:crop_plan_dialogs.userCrops.list': 'op:list_user_crops',
  'dialog:crop_plan_dialogs.userCrops.assign': 'op:set_user_crop',
  'dialog:crop_plan_dialogs.userCrops.delete': 'op:delete_user_crop',
  // ---- fertigation by crop stage
  'dialog:crop_plan_dialogs.fertigationStages': 'op:fertigation_by_stage',
  'dialog:crop_plan_dialogs.fertigationStages.products': 'op:fertigation_by_stage',
  'dialog:crop_plan_dialogs.fertigationStages.save': 'op:fertigation_by_stage',
  // ---- uniformity in the field: depth densogram, virtual catch cans, field evaluations (PRD-28)
  'dialog:crop_plan_dialogs.fieldUniformity': 'op:field_test_evaluation',
  'dialog:crop_plan_dialogs.fieldUniformity.depth': 'op:depth_densogram',
  'dialog:crop_plan_dialogs.fieldUniformity.showDepth': 'op:depth_densogram',
  'dialog:crop_plan_dialogs.fieldUniformity.virtualCans': 'op:virtual_catch_cans',
  'dialog:crop_plan_dialogs.fieldUniformity.test': 'op:set_field_test',
  'dialog:crop_plan_dialogs.fieldUniformity.delete': 'op:delete_field_test',
  // ---- site climate: the file of a weather station (INMET CSV or zip)
  'dialog:agronomy_dialogs.siteClimate.inmetImport': 'op:import_station_climate',
};
