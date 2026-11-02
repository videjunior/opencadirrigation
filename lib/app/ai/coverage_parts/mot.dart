/// AI coverage of the functions added in 1.6.0 for engine and hydraulic analyses (keys and values as
/// in lib/app/ai/ai_coverage.dart). The reservoir and air vessel entries are
/// in mot_reservoir.dart, the scenario entries in mot_scenarios.dart.
library;

import 'mot_reservoir.dart';
import 'mot_scenarios.dart';

const coverageMot = <String, String>{
  // the efficiency of the motor and drive of a pump (MOT-15), a key of the item
  'panel:properties.pump.motorEfficiency': 'tool:update_entities',
  // ---- 1.6.0 MOT+: pump stations (PRD-17)
  'dialog:pump_station_dialog.pumpStation': 'op:set_pump_station',
  'dialog:pump_station_dialog.pumpStation.duty': 'op:pump_stations',
  'panel:properties.pump.station': 'op:set_pump_station',
  'panel:reports.mainline.stations': 'tool:get_report_table',
  // ---- 1.6.0 MOT+: the real operation of the zones at the pressure the mainline gives them
  'dialog:dialogs.designParams.realZoneOperation': 'tool:set_parameters',
  'panel:reports.mainline.operation': 'op:real_zone_operation',
  // ---- 1.6.0 MOT+: pilot valves (reducing, sustaining), keys of the items
  'panel:properties.controlValve.pilot': 'tool:update_entities',
  'panel:properties.misc.pilot': 'tool:update_entities',
  ...coverageMotReservoir,
  ...coverageMotScenarios,
};
