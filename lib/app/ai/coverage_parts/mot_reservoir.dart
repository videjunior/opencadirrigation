/// AI coverage (1.6.0 MOT+) of the reservoirs, dams and air vessels drawn in
/// the project (PRD-16, PRD-31), joined to [coverageMot].
library;

const coverageMotReservoir = <String, String>{
  'dialog:reservoir_dialog.reservoir': 'op:set_reservoir',
  'dialog:reservoir_dialog.reservoir.study': 'op:reservoir_study',
  'panel:properties.waterSupply.reservoir': 'op:set_reservoir',
  // the air vessel of a junction of the mainline: keys of the item (vl, vg, vd, vc)
  'panel:properties.junction.vessel': 'tool:update_entities',
};
