/// AI coverage of the functions added in 1.6.0 for interface, phone layout and accessibility (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageUi = <String, String>{
  // ---- UI-04 catalogue: the factory catalogue, the user's default, forgetting it
  'dialog:more_dialogs.catalogEditor.factory': 'op:catalog_default',
  'dialog:more_dialogs.catalogEditor.loadDefault': 'n/a:pending-ai — catalog_default needs a "load" action that puts the catalogue saved as the default of new projects into the open project',
  'dialog:more_dialogs.catalogEditor.forgetDefault': 'op:catalog_default',
};
