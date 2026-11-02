/// AI coverage of the functions added in 1.6.0 for engine and hydraulic analyses (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageMot = <String, String>{
  // the efficiency of the motor and drive of a pump (MOT-15), a key of the item
  'panel:properties.pump.motorEfficiency': 'tool:update_entities',
};
