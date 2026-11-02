/// AI coverage of the functions added in 1.6.0 for model, catalogues, API and CLI (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageMod = <String, String>{
  // ---- islands of irrigated areas (AUT-29)
  'menu:area.subtract': 'op:subtract_from_area',
  'menu:area.holes.clear': 'op:set_area_holes',
  'panel:properties.areaIslands': 'op:set_area_holes',
  // ---- another project inserted into the open one
  'menu:file.insertProject': 'op:insert_project',
  // ---- what new projects start with (region, the user's choices)
  'dialog:dialogs.designParams.newProjectDefaults': 'op:new_project_defaults',
};
