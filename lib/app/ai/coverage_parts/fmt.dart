/// AI coverage of the functions added in 1.6.0 for file formats and online data (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageFmt = <String, String>{
  // the progress of File → Import (the assistant imports the same files with its own tool)
  'dialog:import_progress_dialog.importProgress': 'tool:import_attachment',
  // ---- the import wizard of points files (FMT-15, function 6)
  'dialog:points_import_dialog.pointsImport': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.encoding': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.separator': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.decimal': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.header': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.skip': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.columns': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.crs': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.swap': 'op:import_points_attachment',
  'dialog:points_import_dialog.pointsImport.preview': 'op:preview_points_attachment',
  'dialog:points_import_dialog.pointsImport.map': 'op:preview_points_attachment',
  // ---- stake-out points for the field (function 8)
  'menu:exp.stakeout': 'op:export_stakeout_points',
  'menu:file.exportDrawing+exp.stakeout': 'op:export_stakeout_points',
  'dialog:stakeout_dialog.stakeout': 'op:export_stakeout_points',
  'dialog:stakeout_dialog.stakeout.order': 'op:export_stakeout_points',
  'dialog:stakeout_dialog.stakeout.kinds': 'op:export_stakeout_points',
  'dialog:stakeout_dialog.stakeout.firstNumber': 'op:export_stakeout_points',
  'dialog:stakeout_dialog.stakeout.decimals': 'op:export_stakeout_points',
  // ---- the downloads kept on the device (function 10)
  'menu:cache.menu': 'op:data_cache_info',
  'dialog:data_cache_dialog.dataCache': 'op:data_cache_info',
  'dialog:data_cache_dialog.dataCache.use': 'op:set_data_cache',
  'dialog:data_cache_dialog.dataCache.clear': 'op:clear_data_cache',
  'dialog:data_cache_dialog.dataCache.clearAll': 'op:clear_data_cache',
  // ---- the sheet of custom size, layers of the PDF, PDF/A (functions 1, 2, 9)
  'dialog:export_dialogs.plot.customSize': 'op:export_sheet_pdf',
  'dialog:export_dialogs.plot.pdfLayers': 'op:export_sheet_pdf',
  'dialog:export_dialogs.plot.pdfA': 'op:export_sheet_pdf',
  // ---- a large project from a shared link (FMT-09)
  'dialog:share_confirm_dialog.largeLink':
      'n/a:the question asked before a large project of a link the user opened in the browser opens (the assistant opens attached projects with open_attached_project, the user\'s own decision)',
};
