/// The menu items of the drawing functions of 1.6.0 (CAD+), for the
/// desktop menu bar (built with its own item helper, so they look and act
/// like the others) and for the phone menu.
library;

import 'package:flutter/material.dart';

import '../shortcuts.dart' show aliasOf;
import '../state/controller.dart';
import '../tools/cad_plus_commands.dart';
import '../tools/insert_block_tool.dart';
import 'dialogs/cad_plus_dialogs.dart';
import 'menu_bar.dart' show AppMenuBar;

/// The item helper of the menu bar: label, action, icon, shortcut, key.
typedef MenuItemOf = MenuItemButton Function(String label, VoidCallback? onPressed, {IconData? icon, String? shortcut, Key? key});

void _opened() => AppMenuBar.openMenus.value++;
void _closed() => AppMenuBar.openMenus.value = AppMenuBar.openMenus.value > 0 ? AppMenuBar.openMenus.value - 1 : 0;

String _alias(ToolId id) => '${aliasOf(id)} ⏎';

/// File menu: compare with another copy, bring back the comments of one.
List<Widget> cadPlusFileItems(BuildContext context, ProjectController c, MenuItemOf item) => [
  const Divider(height: 1),
  item(c.t('cmp.menu'), () => showCompareDialog(context, c), icon: Icons.compare_outlined, key: const Key('menu_compare')),
  item(c.t('cmt.importMenu'), () => importReviewAction(context, c), icon: Icons.rate_review_outlined, key: const Key('menu_import_review')),
];

/// Edit menu: lengthen, the outline by a click inside, the drawing order,
/// the current layer, the blocks (edit in place, explode, the library).
List<Widget> cadPlusEditItems(BuildContext context, ProjectController c, MenuItemOf item) {
  final t = c.t;
  final editing = c.blockEdit;
  return [
    const Divider(height: 1),
    item(t('tool.lengthen'), () => c.setTool(ToolId.lengthen), icon: Icons.straighten, shortcut: _alias(ToolId.lengthen), key: const Key('menu_lengthen')),
    item(t('tool.boundary'), () => c.setTool(ToolId.boundary), icon: Icons.format_shapes_outlined, shortcut: _alias(ToolId.boundary), key: const Key('menu_boundary')),
    SubmenuButton(
      onOpen: _opened,
      onClose: _closed,
      key: const Key('menu_order'),
      leadingIcon: const Icon(Icons.flip_to_front, size: 16),
      menuChildren: [
        item(t('order.front'), c.selection.isEmpty ? null : () => c.reorder(), icon: Icons.flip_to_front, shortcut: 'TOFRONT ⏎', key: const Key('menu_order_front')),
        item(t('order.back'), c.selection.isEmpty ? null : () => c.reorder(back: true), icon: Icons.flip_to_back, shortcut: 'TOBACK ⏎', key: const Key('menu_order_back')),
      ],
      child: Text(t('order.menu')),
    ),
    item(t('layer.toCurrent'), c.selection.isEmpty ? null : c.moveSelectionToCurrentLayer, icon: Icons.move_down, shortcut: 'LAYCUR ⏎', key: const Key('menu_to_current_layer')),
    SubmenuButton(
      onOpen: _opened,
      onClose: _closed,
      key: const Key('menu_blocks'),
      leadingIcon: const Icon(Icons.widgets_outlined, size: 16),
      menuChildren: [
        if (editing == null)
          item(t('blkref.edit'), () => editBlockAction(c), icon: Icons.edit_note, shortcut: 'BEDIT ⏎', key: const Key('menu_block_edit'))
        else ...[
          item(t('blkref.saveEdit', {'b': editing.blockName}), c.saveBlockEdit, icon: Icons.save_outlined, key: const Key('menu_block_edit_save')),
          item(t('blkref.cancelEdit'), c.cancelBlockEdit, icon: Icons.close, key: const Key('menu_block_edit_cancel')),
        ],
        item(t('blkref.explode'), c.selection.isEmpty ? null : () => c.explodeBlockRefs(), icon: Icons.scatter_plot_outlined, key: const Key('menu_block_explode')),
        const Divider(height: 1),
        item(t('blk.libraryExport'), () => exportBlockLibraryAction(c), icon: Icons.file_download_outlined, key: const Key('menu_block_library_export')),
        item(t('blk.libraryImport'), () => importBlockLibraryAction(c), icon: Icons.file_upload_outlined, key: const Key('menu_block_library_import')),
      ],
      child: Text(t('blkref.menu')),
    ),
  ];
}

/// View menu: the object snaps, the layer states and isolation.
List<Widget> cadPlusViewItems(BuildContext context, ProjectController c, MenuItemOf item) {
  final t = c.t;
  return [
    const Divider(height: 1),
    item(t('snap.settings'), () => showSnapSettingsDialog(context, c), icon: Icons.my_location_outlined, key: const Key('menu_snap_settings')),
    SubmenuButton(
      onOpen: _opened,
      onClose: _closed,
      key: const Key('menu_layers'),
      leadingIcon: const Icon(Icons.layers_outlined, size: 16),
      menuChildren: [
        item(t('layer.isolate'), () => c.isolateLayers(), icon: Icons.filter_center_focus, shortcut: 'LAYISO ⏎', key: const Key('menu_layer_isolate')),
        item(t('layer.unisolate'), c.unisolateLayers, icon: Icons.layers_outlined, shortcut: 'LAYUNISO ⏎', key: const Key('menu_layer_unisolate')),
        item(t('layer.states'), () => showLayerStatesDialog(context, c), icon: Icons.bookmarks_outlined, key: const Key('menu_layer_states')),
      ],
      child: Text(t('layer.menu')),
    ),
  ];
}

/// Draw menu: the dimension style, the field photo.
List<Widget> cadPlusDrawItems(BuildContext context, ProjectController c, MenuItemOf item) => [
  const Divider(height: 1),
  item(c.t('dim.style'), () => showDimStyleDialog(context, c), icon: Icons.straighten_outlined, key: const Key('menu_dim_style')),
  item(c.t('photo.menu'), () => fieldPhotoAction(c), icon: Icons.add_a_photo_outlined, key: const Key('menu_field_photo')),
];

/// The same functions for the phone menu, as rows built with its helper
/// (label, action, icon, key).
List<Widget> cadPlusPhoneRows(BuildContext context, ProjectController c, Widget Function(String label, VoidCallback? onTap, {IconData? icon, Key? key}) row) {
  final t = c.t;
  final editing = c.blockEdit;
  return [
    row(t('tool.lengthen'), () => c.setTool(ToolId.lengthen), icon: Icons.straighten, key: const Key('mobile_menu_lengthen')),
    row(t('tool.boundary'), () => c.setTool(ToolId.boundary), icon: Icons.format_shapes_outlined, key: const Key('mobile_menu_boundary')),
    row(t('order.front'), c.selection.isEmpty ? null : () => c.reorder(), icon: Icons.flip_to_front, key: const Key('mobile_menu_order_front')),
    row(t('order.back'), c.selection.isEmpty ? null : () => c.reorder(back: true), icon: Icons.flip_to_back, key: const Key('mobile_menu_order_back')),
    row(t('layer.toCurrent'), c.selection.isEmpty ? null : c.moveSelectionToCurrentLayer, icon: Icons.move_down, key: const Key('mobile_menu_to_current_layer')),
    if (editing == null)
      row(t('blkref.edit'), () => editBlockAction(c), icon: Icons.edit_note, key: const Key('mobile_menu_block_edit'))
    else ...[
      row(t('blkref.saveEdit', {'b': editing.blockName}), c.saveBlockEdit, icon: Icons.save_outlined, key: const Key('mobile_menu_block_edit_save')),
      row(t('blkref.cancelEdit'), c.cancelBlockEdit, icon: Icons.close, key: const Key('mobile_menu_block_edit_cancel')),
    ],
    row(t('blkref.explode'), c.selection.isEmpty ? null : () => c.explodeBlockRefs(), icon: Icons.scatter_plot_outlined, key: const Key('mobile_menu_block_explode')),
    row(t('blk.libraryExport'), () => exportBlockLibraryAction(c), icon: Icons.file_download_outlined, key: const Key('mobile_menu_block_library_export')),
    row(t('blk.libraryImport'), () => importBlockLibraryAction(c), icon: Icons.file_upload_outlined, key: const Key('mobile_menu_block_library_import')),
    row(t('snap.settings'), () => showSnapSettingsDialog(context, c), icon: Icons.my_location_outlined, key: const Key('mobile_menu_snap_settings')),
    row(t('layer.isolate'), () => c.isolateLayers(), icon: Icons.filter_center_focus, key: const Key('mobile_menu_layer_isolate')),
    row(t('layer.unisolate'), c.unisolateLayers, icon: Icons.layers_outlined, key: const Key('mobile_menu_layer_unisolate')),
    row(t('layer.states'), () => showLayerStatesDialog(context, c), icon: Icons.bookmarks_outlined, key: const Key('mobile_menu_layer_states')),
    row(t('dim.style'), () => showDimStyleDialog(context, c), icon: Icons.straighten_outlined, key: const Key('mobile_menu_dim_style')),
    row(t('photo.menu'), () => fieldPhotoAction(c), icon: Icons.add_a_photo_outlined, key: const Key('mobile_menu_field_photo')),
    row(t('cmp.menu'), () => showCompareDialog(context, c), icon: Icons.compare_outlined, key: const Key('mobile_menu_compare')),
    row(t('cmt.importMenu'), () => importReviewAction(context, c), icon: Icons.rate_review_outlined, key: const Key('mobile_menu_import_review')),
  ];
}
