/// The menu of the drawing (CAD-34): the right button, the pen's side
/// button or a finger held still open it where they are. It offers what
/// the keyboard does — finish, take back a point, cancel, repeat the last
/// tool — and the commands of the selection.
library;

import 'package:flutter/material.dart';

import '../../core/model/geometry.dart';
import '../../core/model/entities.dart';
import '../canvas/snapping.dart' show snapModeKey;
import '../keys/canvas_keys.dart';
import '../shortcuts.dart';
import '../state/controller.dart';
import '../widgets/dialogs/cad_plus_dialogs.dart' show showBlockAttributesDialog;
import 'cad_plus_commands.dart';
import 'edit_commands.dart';

/// What the menu offers now (ids of [runCanvasMenu]): the stroke in
/// progress, the tool, the selection, the view.
List<String> canvasMenuChoices(ProjectController c, CanvasKeyTarget target) {
  final drawing = c.activeTool != ToolId.select && c.activeTool != ToolId.pan;
  // 1.6.0 CAD: the attributes of a lone block reference
  final lone = c.selection.length == 1 ? c.entityById(c.selection.first) : null;
  return [
    if (!target.toolIdle) ...['finish', 'undoPoint', 'cancel'] else if (drawing) 'leave',
    // 1.6.0 CAD: a snap for the next point only
    if (drawing) 'snapOnce',
    if (!drawing) 'repeat',
    if (c.selection.isNotEmpty) ...['move', 'copy', 'rotate', 'similar', 'zoomSelection', 'delete', 'deselect'],
    // 1.6.0 CAD
    if (lone is BlockRefEntity) 'attributes',
    if (c.selection.isNotEmpty) 'isolate',
    if (c.layersIsolated) 'unisolate',
    'addToSelection',
    'undo',
    'redo',
    'zoomAll',
  ];
}

/// Runs choice [id] of the menu.
void runCanvasMenu(ProjectController c, CanvasKeyTarget target, String id) {
  switch (id) {
    case 'finish':
      target.toolKey('Enter');
    case 'undoPoint':
      target.toolKey('Backspace');
    case 'cancel':
      target.toolKey('Cancel');
      if (c.activeTool != ToolId.select && target.toolIdle) c.setTool(ToolId.select);
    case 'leave':
      c.setTool(ToolId.select);
    case 'repeat':
      c.setTool(c.lastTool);
    case 'move':
      c.setTool(ToolId.move);
    case 'copy':
      c.setTool(ToolId.copy);
    case 'rotate':
      c.setTool(ToolId.rotate);
    case 'similar':
      c.selectSimilar();
    case 'zoomSelection':
      c.zoomToSelection();
    case 'delete':
      c.deleteSelected();
    case 'deselect':
      c.select(const []);
    case 'addToSelection':
      c.setAddToSelection(!c.editSettings.addToSelection);
    case 'undo':
      c.undo();
    case 'redo':
      c.redo();
    case 'zoomAll':
      c.zoomAll();
    // 1.6.0 CAD
    case 'isolate':
      c.isolateLayers();
    case 'unisolate':
      c.unisolateLayers();
  }
  target.redraw();
}

/// The label of choice [id].
String canvasMenuLabel(ProjectController c, String id) {
  final t = c.t;
  return switch (id) {
    'finish' => t('mob.done'),
    'undoPoint' => t('ctx.undoPoint'),
    'cancel' => t('mob.cancel'),
    'leave' => t('ctx.leaveTool'),
    'repeat' => t('ctx.repeat', {'tool': t('tool.${c.lastTool.name}')}),
    'move' => toolLabel(t, ToolId.move),
    'copy' => toolLabel(t, ToolId.copy),
    'rotate' => toolLabel(t, ToolId.rotate),
    'similar' => t('sel.similar'),
    'zoomSelection' => t('ctx.zoomSelection'),
    'delete' => t('edit.delete'),
    'deselect' => t('ctx.deselect'),
    'addToSelection' => t('sel.addMode'),
    'undo' => t('edit.undo'),
    'redo' => t('edit.redo'),
    // 1.6.0 CAD
    'snapOnce' => t('snap.onceMenu'),
    'attributes' => t('blkref.attributes'),
    'isolate' => t('layer.isolate'),
    'unisolate' => t('layer.unisolate'),
    _ => t('view.zoomAll'),
  };
}

IconData _icon(String id) => switch (id) {
  'finish' => Icons.check,
  'undoPoint' => Icons.backspace_outlined,
  'cancel' => Icons.close,
  'leave' => Icons.near_me_outlined,
  'repeat' => Icons.replay,
  'move' => Icons.open_with,
  'copy' => Icons.file_copy_outlined,
  'rotate' => Icons.rotate_right,
  'similar' => Icons.select_all,
  'zoomSelection' => Icons.center_focus_strong,
  'delete' => Icons.delete_outline,
  'deselect' => Icons.deselect,
  'addToSelection' => Icons.library_add_check_outlined,
  'undo' => Icons.undo,
  'redo' => Icons.redo,
  // 1.6.0 CAD
  'snapOnce' => Icons.my_location,
  'attributes' => Icons.list_alt,
  'isolate' => Icons.filter_center_focus,
  'unisolate' => Icons.layers_outlined,
  _ => Icons.fit_screen,
};

/// Opens the menu of the drawing at [global] (screen position).
Future<void> showCanvasContextMenu(BuildContext context, ProjectController c, CanvasKeyTarget target, Offset global) async {
  final ids = canvasMenuChoices(c, target);
  PopupMenuEntry<String> entry(String id) {
    final enabled = switch (id) {
      'undo' => c.canUndo,
      'redo' => c.canRedo,
      _ => true,
    };
    if (id == 'addToSelection') {
      return CheckedPopupMenuItem<String>(
        key: Key('ctx_$id'),
        value: id,
        checked: c.editSettings.addToSelection,
        child: Text(canvasMenuLabel(c, id), style: const TextStyle(fontSize: 13)),
      );
    }
    return PopupMenuItem<String>(
      key: Key('ctx_$id'),
      value: id,
      enabled: enabled,
      height: 36,
      child: Row(
        children: [
          Icon(_icon(id), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(canvasMenuLabel(c, id), style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  final items = <PopupMenuEntry<String>>[];
  for (var i = 0; i < ids.length; i++) {
    // a line between the groups: the stroke, the tool, the selection, the rest
    if (i > 0 && (ids[i] == 'repeat' || ids[i] == 'move' || ids[i] == 'addToSelection') && ids[i - 1] != 'repeat') items.add(const PopupMenuDivider(height: 8));
    items.add(entry(ids[i]));
  }
  final position = RelativeRect.fromLTRB(global.dx, global.dy, global.dx + 1, global.dy + 1);
  final choice = await showMenu<String>(context: context, position: position, items: items);
  if (choice == null) return;
  // 1.6.0 CAD: the snaps for the next point, and the attributes of a reference
  if (choice == 'snapOnce') {
    if (!context.mounted) return;
    final mode = await showMenu<String>(
      context: context,
      position: position,
      items: [
        // the default height (48 px): a finger chooses the snap too
        for (final m in snapModes)
          PopupMenuItem<String>(
            key: Key('ctx_snap_$m'),
            value: m,
            child: Text(c.t(snapModeKey(m)), style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
    if (mode == null) return;
    c.snap.once = mode;
    c.notify(c.t('cadp.snapOnce', {'k': c.t(snapModeKey(mode))}));
    target.redraw();
    return;
  }
  if (choice == 'attributes') {
    final r = c.selection.length == 1 ? c.entityById(c.selection.first) : null;
    if (r is! BlockRefEntity) return;
    if (!context.mounted) return;
    await showBlockAttributesDialog(context, c, r);
    return;
  }
  runCanvasMenu(c, target, choice);
}

extension ContextMenuCommands on ProjectController {
  /// Frames the selected items in the view.
  void zoomToSelection() {
    var b = Bounds.empty;
    for (final e in project.entities) {
      if (selection.contains(e.id)) b = b.union(e.bounds);
    }
    if (b.isEmpty) return;
    final pad = (b.width > b.height ? b.width : b.height) * 0.1 + 2;
    camera.fit(b.inflate(pad));
    refresh();
  }
}
