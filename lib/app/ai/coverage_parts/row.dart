/// AI coverage of the crop rows read from the aerial image, added in 1.7.0
/// (keys and values as in lib/app/ai/ai_coverage.dart).
library;

const coverageRow = <String, String>{
  // ---- Design → Automatic design (desktop menu and phone menu)
  'menu:row.menu': 'op:detect_crop_rows',
  // ---- the dialog of lib/app/widgets/dialogs/crop_rows_dialog.dart and its options
  'dialog:crop_rows_dialog.cropRows': 'op:detect_crop_rows',
  'dialog:crop_rows_dialog.cropRows.source': 'op:detect_crop_rows',
  'dialog:crop_rows_dialog.cropRows.spacings': 'op:detect_crop_rows',
  'dialog:crop_rows_dialog.cropRows.otherBand': 'op:detect_crop_rows',
  'dialog:crop_rows_dialog.cropRows.apply': 'op:apply_crop_rows',
};
