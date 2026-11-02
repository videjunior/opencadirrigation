/// AI coverage of the functions added in 1.6.0 for drawing board, editing and local storage (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const _gps = 'n/a:the device\'s GPS follows the user walking the site; the user starts it (View → Device GPS, Draw → GPS in the field; read_manual "interface" gives the assistant the menu paths)';

const coverageCad = <String, String>{
  // ---- File menu (desktop and phone)
  'menu:file.saveAs': 'tool:export_file',
  'menu:file.saveCopy': 'n/a:pending-ai — an operation "save_as_copy" that gives the project a uid of its own (a separate copy in the browser, its own versions and recent entry, the name with " (copy)") and then saves the project file',
  'menu:file.storage': 'n/a:pending-ai — an operation that reads what the browser keeps (projects, kind, time, size, versions, storage used of the quota, persistence) and one that downloads every kept project as a ZIP',
  'dialog:storage_dialog.storage': 'n/a:pending-ai — an operation that reads what the browser keeps (projects, kind, time, size, versions, storage used of the quota, persistence) and one that downloads every kept project as a ZIP',
  'dialog:storage_dialog.storage.persist': 'n/a:pending-ai — asking the browser to keep the storage of the site (navigator.storage.persist) is the user\'s choice; Firefox asks the user',
  'dialog:storage_dialog.storage.zip': 'n/a:pending-ai — an operation that downloads every project kept in the browser as a ZIP of their files',
  // ---- GPS walk
  'menu:gps.walkDiscard': _gps,
  // ---- base maps
  'menu:basemap.osm.menu': 'n/a:pending-ai — a setting "view.streets_tile_url" (the XYZ template of the street map server; empty for the OpenStreetMap Foundation\'s)',
  'dialog:basemap_dialogs.streetsServer': 'n/a:pending-ai — a setting "view.streets_tile_url" (the XYZ template of the street map server; empty for the OpenStreetMap Foundation\'s)',
  'menu:basemap.terms.menu': 'n/a:pending-ai — an operation that reads the terms of each base map source (credit, allowed use, links) for the assistant to explain them',
  'dialog:basemap_dialogs.baseMapTerms': 'n/a:pending-ai — an operation that reads the terms of each base map source (credit, allowed use, links) for the assistant to explain them',
  'dialog:basemap_dialogs.googleMapsKey.remember': 'n/a:the user\'s own Map Tiles API key and where the browser keeps it; the assistant never handles keys',
};
