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
  // ---- selection by what the items are (CAD-25)
  'tool:lasso': 'tool:select_entities',
  'tool:fence': 'tool:select_entities',
  'action:selectSimilar': 'tool:select_entities',
  'action:quickSelect': 'tool:select_entities',
  'action:selectLayer': 'tool:select_entities',
  'menu:sel.similar': 'tool:select_entities',
  'menu:sel.quick': 'tool:select_entities',
  'menu:sel.layer': 'tool:select_entities',
  'menu:tool.lasso': 'tool:select_entities',
  'menu:tool.fence': 'tool:select_entities',
  'dialog:selection_dialogs.quickSelect': 'tool:select_entities',
  'dialog:selection_dialogs.quickSelect.kind': 'tool:list_entities',
  'dialog:selection_dialogs.quickSelect.layer': 'tool:list_entities',
  'dialog:selection_dialogs.quickSelect.spec': 'tool:list_entities',
  'dialog:selection_dialogs.quickSelect.zone': 'tool:list_entities',
  'dialog:selection_dialogs.quickSelect.range': 'tool:list_entities',
  'dialog:selection_dialogs.quickSelect.mode': 'tool:select_entities',
  'panel:layers.select': 'tool:select_entities',
  'panel:tools.lassoCrossing': 'tool:select_entities',
  'panel:tools.addToSelection': 'tool:select_entities',
  // ---- geometry edits (CAD-26)
  'tool:stretch': 'op:stretch_entities',
  'tool:fillet': 'op:fillet_corner',
  'tool:chamfer': 'op:chamfer_corner',
  'tool:breakTwo': 'op:break_entity',
  'action:join': 'op:join_entities',
  'action:explode': 'op:explode_entities',
  'action:toArea': 'op:convert_to_area',
  'menu:tool.stretch': 'op:stretch_entities',
  'menu:tool.fillet': 'op:fillet_corner',
  'menu:tool.chamfer': 'op:chamfer_corner',
  'menu:tool.breakTwo': 'op:break_entity',
  'menu:edt.join': 'op:join_entities',
  'menu:edt.explode': 'op:explode_entities',
  'menu:edt.toArea': 'op:convert_to_area',
  'panel:tools.filletRadius': 'op:fillet_corner',
  'panel:tools.chamferDistances': 'op:chamfer_corner',
  // ---- the Measure tool (CAD-33)
  'panel:tools.measureMode': 'tool:measure',
  'panel:tools.measureResult': 'tool:measure',
  'panel:tools.measureCopy': 'tool:measure',
  // ---- the menu of the drawing: right button, pen side button, finger held (CAD-34)
  'panel:canvas.contextMenu': 'tool:run_command',
  'panel:canvas.contextMenu.zoomSelection': 'tool:zoom_to',
};
