/// AI coverage of the functions added in 1.6.0 for file formats and online data (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageFmt = <String, String>{
  // the progress of File → Import (the assistant imports the same files with its own tool)
  'dialog:import_progress_dialog.importProgress': 'tool:import_attachment',
};
