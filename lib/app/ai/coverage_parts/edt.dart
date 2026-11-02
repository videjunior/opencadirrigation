/// AI coverage of the drawing and editing tools added in 1.6.0 (keys and
/// values as in lib/app/ai/ai_coverage.dart).
library;

const coverageEdt = <String, String>{
  // ---- move and copy by base point (CAD-06)
  'tool:move': 'tool:transform_entities',
  'tool:copy': 'tool:transform_entities',
  'menu:tool.move': 'tool:transform_entities',
  'menu:tool.copy': 'tool:transform_entities',
  'panel:properties.coordinates': 'op:edit_vertices',
  // ---- several items on a touch screen (CAD-17)
  'menu:sel.addMode': 'tool:select_entities',
  'panel:canvas.holdWindow': 'tool:select_entities',
};
