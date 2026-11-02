/// AI coverage of the functions added in 1.6.0 for deliverables (sheets, documents, reports) (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coveragePrd = <String, String>{
  // ---- File menu (desktop and phone)
  'menu:prd.menu.titleBlock': 'op:set_title_block',
  'menu:prd.menu.package': 'op:export_document_package',
  // ---- the dialogs and their options
  'dialog:title_block_dialog.titleBlock': 'op:set_title_block',
  'dialog:title_block_dialog.titleBlock.logo': 'op:set_title_block',
  'dialog:title_block_dialog.titleBlock.revisions': 'op:set_title_block',
  'dialog:title_block_dialog.titleBlock.defaults': 'op:set_title_block',
  'dialog:document_package_dialog.documentPackage': 'op:export_document_package',
  'dialog:document_package_dialog.documentPackage.sections': 'op:list_document_packages',
  'dialog:export_dialogs.georeference.datum': 'op:set_datum',
  'dialog:export_dialogs.plot.grid': 'op:export_sheet_pdf',
  'dialog:export_dialogs.plot.themes': 'op:export_sheet_pdf',
};
