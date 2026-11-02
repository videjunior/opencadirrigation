/// AI coverage of the functions added in 1.6.0 for drawing board, editing and local storage (keys and values as
/// in lib/app/ai/ai_coverage.dart).
library;

const _gps = 'n/a:the device\'s GPS follows the user walking the site; the user starts it (View → Device GPS, Draw → GPS in the field; read_manual "interface" gives the assistant the menu paths)';

const coverageCad = <String, String>{
  // ---- File menu (desktop and phone)
  'menu:file.saveAs': 'tool:export_file',
  'menu:file.saveCopy': 'op:save_as_copy',
  'menu:file.storage': 'op:browser_storage',
  'dialog:storage_dialog.storage': 'op:browser_storage',
  'dialog:storage_dialog.storage.persist': 'op:persist_storage',
  'dialog:storage_dialog.storage.zip': 'op:download_stored_projects',
  // ---- GPS walk
  'menu:gps.walkDiscard': _gps,
  // ---- base maps
  'menu:basemap.osm.menu': 'setting:view.streets_tile_url',
  'dialog:basemap_dialogs.streetsServer': 'setting:view.streets_tile_url',
  'menu:basemap.terms.menu': 'op:base_map_terms',
  'dialog:basemap_dialogs.baseMapTerms': 'op:base_map_terms',
  'dialog:basemap_dialogs.googleMapsKey.remember': 'n/a:the user\'s own Map Tiles API key and where the browser keeps it; the assistant never handles keys',
};
