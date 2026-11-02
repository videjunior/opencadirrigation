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
  // ---- UI-06 typed commands on touch screens (the ⌨ button and field)
  'menu:cmd.open': 'tool:run_command',
  'view:commandEntry': 'tool:run_command',
  'panel:properties.line.length': 'op:edit_vertices',
  'panel:properties.polyline.length': 'op:edit_vertices',
  'panel:properties.pipe.length': 'op:edit_vertices',
  // ---- UI-07 layout: the side panel of narrow windows folds into a drawer
  'view:sideDrawer': 'n/a:the user folds the side panel of a narrow window away to see more of the drawing; the panels\' contents have their own routes',
  // ---- UI-17 report tables: sort, filter, copy, CSV, locate the row's item
  'panel:reports.sort': 'tool:get_report_table',
  'panel:reports.filter': 'tool:get_report_table',
  'panel:reports.highlighted': 'tool:get_report_table',
  'panel:reports.copy': 'tool:get_report_table',
  'panel:reports.csv': 'tool:get_report_table',
  'panel:reports.locate': 'tool:zoom_to',
  // ---- UI-28 Help → Recent messages (desktop and phone) and the notices' button
  'menu:ui.messagesMenu': 'n/a:the notices the program showed the user lately, to read again; the assistant gets the outcome of each of its own actions from the tools',
  'view:messageLog': 'n/a:the notices the program showed the user lately, to read again; the assistant gets the outcome of each of its own actions from the tools',
  // ---- UI-26 the start-up screen: go on without a place
  'dialog:ai_start_dialog.aiStart.skipPlace': 'n/a:the user leaves the place out of the first screen; the assistant georeferences later with the tools',
};
