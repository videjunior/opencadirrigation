/// AI coverage of the functions added in 1.6.0 for site, PWA, translations and documentation (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageSit = <String, String>{
  // ---- Help → Terms of the data (PRD-06)
  'menu:terms.menu': 'op:read_data_terms',
  'dialog:data_terms_dialog.dataTerms': 'op:read_data_terms',
  // ---- View → Base map → Keep the map of the area for the field (PRD-09)
  'menu:fieldmap.menu': 'op:keep_field_map',
  'dialog:field_map_dialog.fieldMap': 'op:keep_field_map',
};
