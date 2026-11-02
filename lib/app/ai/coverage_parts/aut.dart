/// AI coverage of the functions added in 1.6.0 for automatic design and the design assistant (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageAut = <String, String>{
  // ---- the outline traced on the satellite image (PRD-05)
  'tool:traceImage': 'op:outline_from_image',
  'menu:tool.traceImage': 'op:outline_from_image',
  'panel:tools.traceImage.output': 'op:outline_from_image',
  'panel:tools.traceImage.tolerance': 'op:outline_from_image',
  'panel:tools.traceImage.blur': 'op:outline_from_image',
  'panel:tools.traceImage.detail': 'op:outline_from_image',
  'panel:tools.traceImage.commit': 'op:outline_from_image',
  'panel:tools.traceImage.discard': 'n/a:the preview of the tool is the user\'s; outline_from_image adds the outline at once and undo takes it back',
  'panel:tools.traceImage.view': 'tool:trace_fields',
  // ---- the computed maximum lateral length (B, SUBDIV, LAYOUT)
  'dialog:dialogs.block.maxLateral': 'op:max_lateral_length',
  'dialog:dialogs.block.flowVariation': 'op:max_lateral_length',
  'dialog:auto_design_dialogs.fieldSubdivision.maxLateralComputed': 'op:max_lateral_length',
  'dialog:auto_design_dialogs.fieldSubdivision.maxLateralUse': 'op:max_lateral_length',
  'dialog:auto_design_dialogs.autoLayout.maxLateral': 'op:max_lateral_length',
  // ---- review item by item of "fix automatically" and "optimise"
  'panel:messages.autoFix.review': 'op:preview_auto_fix',
  'panel:messages.autoFix.keepChecked': 'op:auto_fix_selected',
  'panel:messages.autoFix.showOnDrawing': 'tool:zoom_to',
  'panel:messages.optimize.review': 'op:preview_optimize',
  'panel:messages.optimize.keepChecked': 'op:optimize_selected',
  // ---- default burial depths of the quote (AUT-25)
  'dialog:dialogs.proposal.mainlineDepth': 'op:set_trench_depths',
  'dialog:dialogs.proposal.zoneDepth': 'op:set_trench_depths',
};
