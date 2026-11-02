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
  'tool:stretch': 'n/a:pending-ai — stretch_entities {bbox, dx, dy}: move the vertices inside a crossing window, the others staying (update_entities rewrites one item at a time)',
  'tool:fillet': 'n/a:pending-ai — fillet {id, at, other_id, other_at, radius}: round the corner between two sides (of two lines, or at a vertex of one item) with an arc',
  'tool:chamfer': 'n/a:pending-ai — chamfer {id, at, other_id, other_at, d1, d2}: cut the corner between two sides with a straight segment',
  'tool:breakTwo': 'n/a:pending-ai — break_entity {id, from, to}: take out the part of an item between two of its points (split_entity cuts at one point only)',
  'action:join': 'n/a:pending-ai — join_entities {ids}: join lines, polylines and pipes of one kind whose ends meet into one item',
  'action:explode': 'n/a:pending-ai — explode_entities {ids}: break polylines, hatches, splines, leaders, pipes and laterals into their segments',
  'action:toArea': 'n/a:pending-ai — convert_to_area {ids}: turn closed polylines, circles, hatches and closed splines into irrigated areas with the same outline',
  'menu:tool.stretch': 'n/a:pending-ai — stretch_entities {bbox, dx, dy}: move the vertices inside a crossing window, the others staying (update_entities rewrites one item at a time)',
  'menu:tool.fillet': 'n/a:pending-ai — fillet {id, at, other_id, other_at, radius}: round the corner between two sides (of two lines, or at a vertex of one item) with an arc',
  'menu:tool.chamfer': 'n/a:pending-ai — chamfer {id, at, other_id, other_at, d1, d2}: cut the corner between two sides with a straight segment',
  'menu:tool.breakTwo': 'n/a:pending-ai — break_entity {id, from, to}: take out the part of an item between two of its points (split_entity cuts at one point only)',
  'menu:edt.join': 'n/a:pending-ai — join_entities {ids}: join lines, polylines and pipes of one kind whose ends meet into one item',
  'menu:edt.explode': 'n/a:pending-ai — explode_entities {ids}: break polylines, hatches, splines, leaders, pipes and laterals into their segments',
  'menu:edt.toArea': 'n/a:pending-ai — convert_to_area {ids}: turn closed polylines, circles, hatches and closed splines into irrigated areas with the same outline',
  'panel:tools.filletRadius': 'n/a:pending-ai — fillet {id, at, other_id, other_at, radius}: round the corner between two sides (of two lines, or at a vertex of one item) with an arc',
  'panel:tools.chamferDistances': 'n/a:pending-ai — chamfer {id, at, other_id, other_at, d1, d2}: cut the corner between two sides with a straight segment',
  // ---- the Measure tool (CAD-33)
  'panel:tools.measureMode': 'tool:measure',
  'panel:tools.measureResult': 'tool:measure',
  'panel:tools.measureCopy': 'tool:measure',
  // ---- the menu of the drawing: right button, pen side button, finger held (CAD-34)
  'panel:canvas.contextMenu': 'tool:run_command',
  'panel:canvas.contextMenu.zoomSelection': 'tool:zoom_to',
};
