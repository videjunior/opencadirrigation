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
  // ---- 1.6.0 CAD+: the object snaps one by one, the dynamic input, the touch magnifier
  'menu:snap.settings': 'setting:snap.mode_endpoint',
  'dialog:cad_plus_dialogs.snapSettings': 'setting:snap.mode_endpoint',
  'dialog:cad_plus_dialogs.snapSettings.modes': 'setting:snap.mode_intersection',
  'dialog:cad_plus_dialogs.snapSettings.dynamicInput': 'setting:snap.dynamic_input',
  'dialog:cad_plus_dialogs.snapSettings.touchLoupe': 'setting:snap.touch_loupe',
  'dialog:cad_plus_dialogs.snapSettings.editDuringDesign': 'setting:app.edit_during_design',
  'status:snapSettings': 'setting:snap.mode_endpoint',
  'panel:canvas.contextMenu.snapOnce': 'n/a:a snap for the next point the user clicks (END, MID…): the assistant gives points as coordinates',
  'panel:canvas.dynamicInput': 'n/a:the length and angle typed beside the user\'s cursor: the assistant gives points as coordinates (setting snap.dynamic_input turns it on or off)',
  'panel:canvas.touchLoupe': 'n/a:the magnifier over the user\'s finger on a touch screen (setting snap.touch_loupe turns it on or off)',
  // ---- layer states and isolation
  'action:isolateLayer': 'op:isolate_layers',
  'action:unisolateLayers': 'op:unisolate_layers',
  'menu:layer.isolate': 'op:isolate_layers',
  'menu:layer.unisolate': 'op:unisolate_layers',
  'menu:layer.states': 'op:layer_states',
  'dialog:cad_plus_dialogs.layerStates': 'op:layer_states',
  'dialog:cad_plus_dialogs.layerStates.save': 'op:save_layer_state',
  'dialog:cad_plus_dialogs.layerStates.restore': 'op:restore_layer_state',
  'dialog:cad_plus_dialogs.layerStates.delete': 'op:delete_layer_state',
  'panel:layers.isolate': 'op:isolate_layers',
  'panel:layers.states': 'op:layer_states',
  'panel:canvas.contextMenu.isolate': 'op:isolate_layers',
  'panel:canvas.contextMenu.unisolate': 'op:unisolate_layers',
  // ---- dimension style
  'menu:dim.style': 'op:dim_style',
  'dialog:cad_plus_dialogs.dimStyle': 'op:dim_style',
  // ---- block references with attributes
  'action:editBlock': 'op:edit_block_in_place',
  'menu:blkref.edit': 'op:edit_block_in_place',
  'menu:blkref.saveEdit': 'op:edit_block_in_place',
  'menu:blkref.cancelEdit': 'op:edit_block_in_place',
  'menu:blkref.explode': 'op:explode_block_refs',
  'menu:blk.libraryExport': 'op:export_block_library',
  'menu:blk.libraryImport': 'op:import_block_library',
  'dialog:cad_plus_dialogs.blockAttributes': 'op:set_block_attributes',
  'dialog:blocks_dialogs.saveBlock.attributes': 'op:define_block_attributes',
  'dialog:blocks_dialogs.saveBlock.inBom': 'op:define_block_attributes',
  'dialog:blocks_dialogs.saveBlock.replace': 'op:save_block',
  'dialog:blocks_dialogs.insertBlock.asReference': 'op:insert_block',
  'dialog:blocks_dialogs.insertBlock.attributes': 'op:insert_block',
  'dialog:blocks_dialogs.insertBlock.library': 'op:import_block_library',
  'panel:properties.blockRef': 'op:set_block_attributes',
  'panel:properties.blockRef.edit': 'op:edit_block_in_place',
  'panel:properties.blockRef.explode': 'op:explode_block_refs',
  'panel:canvas.contextMenu.attributes': 'op:set_block_attributes',
  // ---- review without a server: compare, the comments of a copy, versions in a tab (PRD-11)
  'menu:cmp.menu': 'op:compare_project',
  'menu:cmt.importMenu': 'op:import_review_comments',
  'dialog:cad_plus_dialogs.compare': 'op:compare_project',
  'dialog:cad_plus_dialogs.comparison': 'op:compare_project',
  'dialog:cad_plus_dialogs.comparison.show': 'op:compare_project',
  'dialog:more_dialogs.versions.compare': 'op:compare_project',
  'dialog:more_dialogs.versions.openTab': 'op:open_version_in_tab',
  // ---- the field photo of a comment, no AI needed (PRD-08)
  'tool:fieldPhoto': 'tool:add_photo_comment',
  'menu:photo.menu': 'tool:add_photo_comment',
  'panel:properties.commentPhoto': 'op:set_comment_photo',
  'panel:properties.commentPhotoGps': 'op:set_comment_photo',
  // ---- coordinates of the field on the command line (PRD-26) and kgf/cm²
  'panel:command.fieldCoordinates': 'n/a:UTM and geographic coordinates typed by the user on the command line: the assistant converts them itself (get_site, set_site) and gives points in metres',
  'dialog:dialogs.units.kgfcm2': 'setting:units.pressure',
};
