/// AI coverage of the functions added in 1.6.0 for interface, phone layout and accessibility (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const coverageUi = <String, String>{
  // ---- UI-04 catalogue: the factory catalogue, the user's default, forgetting it
  'dialog:more_dialogs.catalogEditor.factory': 'op:catalog_default',
  'dialog:more_dialogs.catalogEditor.loadDefault': 'op:catalog_default',
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
  // ---- UI-19 stopping the transient simulations
  'dialog:transient_dialogs.transient.cancel': 'n/a:the user stops a long simulation they started; the assistant runs its own analyses through the tools',
  // ==== 1.6.0 wave 2
  // ---- the command palette (Ctrl+K, Help → Search commands; the search of the phone menu)
  'menu:pal.menu': 'n/a:the user\'s search over the menus and commands; the assistant finds the functions with find_operations',
  'dialog:command_palette.commandPalette': 'n/a:the user\'s search over the menus and commands; the assistant finds the functions with find_operations',
  'view:phoneMenuSearch': 'n/a:the user\'s search over the rows of the phone menu; the assistant finds the functions with find_operations',
  // ---- Help → Manual and the "?" of the dialogs and panels
  'menu:help.manual': 'op:manual_topic',
  'dialog:help_dialog.help': 'op:manual_topic',
  'view:helpButton': 'op:manual_topic',
  // ---- Help → What's new (also once after an update)
  'menu:new.menu': 'op:whats_new',
  'dialog:whats_new_dialog.whatsNew': 'op:whats_new',
  // ---- Help → Report a problem or suggest a feature (PRD-25)
  'menu:fb.menu': 'op:prepare_feedback',
  'dialog:feedback_dialog.feedback': 'op:prepare_feedback',
  // ---- View → Interface: size, high contrast, focus mode, the side panel folded or widened
  'menu:uiv.scaleItem': 'op:interface_settings',
  'menu:uiv.larger': 'op:interface_settings',
  'menu:uiv.smaller': 'op:interface_settings',
  'menu:uiv.contrast': 'op:interface_settings',
  'menu:uiv.focus': 'op:interface_settings',
  'menu:uiv.side': 'op:interface_settings',
  'view:focusMode': 'op:interface_settings',
  'view:sideDock': 'op:interface_settings',
  // ---- the preview of the sheet in the export dialog
  'dialog:export_dialogs.plot.preview': 'op:preview_sheet',
  // ---- FMT-09: a large project of a link opens once the user agrees
  'view:sharedLinkConfirm': 'n/a:the user agrees to open a large project shared with them by link; the assistant opens projects with its own tools',
  // ---- the tutorial: chapters, tracks, where the user stopped, the AI chapter
  'view:tutorialChapters': 'n/a:the tutorial teaches the user the program by their own hands (its AI chapter only writes an example request, never sends it)',
};
