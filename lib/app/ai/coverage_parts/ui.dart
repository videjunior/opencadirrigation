/// AI coverage of the functions added in 1.6.0 for interface, phone layout and accessibility (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageUi = <String, String>{
  // ---- UI-04 catalogue: the factory catalogue, the user's default, forgetting it
  'dialog:more_dialogs.catalogEditor.factory': 'op:catalog_default',
  'dialog:more_dialogs.catalogEditor.loadDefault': 'n/a:pending-ai — catalog_default needs a "load" action that puts the catalogue saved as the default of new projects into the open project',
  'dialog:more_dialogs.catalogEditor.forgetDefault': 'op:catalog_default',
  // ---- UI-05 phone menu: tabs, recent projects and the toggles of the desktop menus
  'menu:mob.gridSnap': 'setting:snap.grid',
  'menu:mob.polar': 'setting:snap.polar_step_deg',
  // (the Tabs section lists the open tabs by their project names; an unnamed one reads "New project")
  'menu:name.newProject': 'op:switch_tab',
};
