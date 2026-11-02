/// Editing commands added in 1.6.0 on the controller, as an extension (the
/// way the block commands are kept in insert_block_tool.dart), and the
/// settings of the new tools. Each change is one undo step with its own
/// label in the history.
library;

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../state/controller.dart';
import 'selection_filters.dart';

/// Settings of the editing and selection tools of 1.6.0, one set per
/// project tab (see [EditCommands.editSettings]).
class EditSettings {
  /// Taps and clicks add to the selection (or take a selected item out of
  /// it) as Shift does: the touch screen has no Shift key.
  bool addToSelection = false;

  /// The lasso also takes what it crosses (else only what lies inside).
  bool lassoCrossing = false;
}

final _editSettings = Expando<EditSettings>('editSettings');

/// The tools whose clicks Shift (or [EditSettings.addToSelection]) turns
/// into "add to the selection".
bool usesAddToSelection(ToolId t) => t == ToolId.select || t == ToolId.trim || t == ToolId.extend || t == ToolId.lasso || t == ToolId.fence;

extension EditCommands on ProjectController {
  /// The settings of the 1.6.0 editing tools of this tab.
  EditSettings get editSettings => _editSettings[this] ??= EditSettings();

  /// Turns "add to the selection" on or off and says what taps do now.
  void setAddToSelection(bool on) {
    editSettings.addToSelection = on;
    notify(t(on ? 'sel.addModeOn' : 'sel.addModeOff'));
  }

  // ---------------------------------------------------------------- selection (CAD-25)

  /// The items a selection may take: on visible layers that are not locked.
  List<Entity> selectableEntities() {
    final layers = {for (final l in project.layers) l.name: l};
    return [
      for (final e in project.entities)
        if ((layers[e.layer]?.visible ?? true) && !(layers[e.layer]?.locked ?? false)) e,
    ];
  }

  /// Selects every item like the selected ones: the same kind and catalogue
  /// item, or the same kind on the same layer for the drawing (see
  /// [similarityKey]). Returns the size of the new selection.
  int selectSimilar() {
    track('selectSimilar');
    if (selection.isEmpty) {
      notify(t('msg.nothingSelected'));
      return 0;
    }
    final keys = {
      for (final e in project.entities)
        if (selection.contains(e.id)) similarityKey(e),
    };
    final ids = [
      for (final e in selectableEntities())
        if (keys.contains(similarityKey(e))) e.id,
    ];
    select(ids);
    notify(t('sel.similarDone', {'n': '${ids.length}'}));
    return ids.length;
  }

  /// The selectable items that meet [q].
  List<Entity> queryMatches(SelectionQuery q) {
    final members = q.zone == null ? null : zoneMembers(project, results, q.zone!);
    final cat = project.catalog;
    return [
      for (final e in selectableEntities())
        if (matchesQuery(e, q, cat, members: members)) e,
    ];
  }

  /// Changes the selection by the items that meet [q] ([mode]: replace it,
  /// add to it, take them out of it, or keep only them). Returns the size of
  /// the new selection.
  int selectByQuery(SelectionQuery q, {SelectionMode mode = SelectionMode.replace}) {
    track('quickSelect');
    final ids = {for (final e in queryMatches(q)) e.id};
    switch (mode) {
      case SelectionMode.replace:
        select(ids);
      case SelectionMode.add:
        select(ids, add: true);
      case SelectionMode.remove:
        selection.removeAll(ids);
        refresh();
      case SelectionMode.within:
        selection.retainAll(ids);
        refresh();
    }
    return selection.length;
  }

  /// Selects what lies inside the polygon [poly] (a lasso), or also what it
  /// crosses with [crossing]; [add] adds to the selection. Returns how many
  /// items it took.
  int selectInPolygon(List<Pt> poly, {bool crossing = false, bool add = false}) {
    track('lasso');
    if (poly.length < 3) return 0;
    final ids = [
      for (final e in entitiesIn(Bounds.ofPoints(poly)))
        if (!project.isLocked(e.layer) && inPolygon(e, poly, crossing: crossing)) e.id,
    ];
    select(ids, add: add);
    return ids.length;
  }

  /// Selects what the fence [fence] crosses; [add] adds to the selection.
  /// Returns how many items it took.
  int selectByFence(List<Pt> fence, {bool add = false}) {
    track('fence');
    if (fence.length < 2) return 0;
    final tol = snap.tolerancePx / camera.scale;
    final ids = [
      for (final e in entitiesIn(Bounds.ofPoints(fence).inflate(tol)))
        if (!project.isLocked(e.layer) && crossedByFence(e, fence, tol)) e.id,
    ];
    select(ids, add: add);
    return ids.length;
  }

  /// Selects every item of [layer] (the current layer when null); a hidden
  /// or locked layer selects nothing and says why. Returns how many.
  int selectOnLayer([String? layer, bool add = false]) {
    track('selectLayer');
    final name = layer ?? project.currentLayer;
    final l = project.findLayer(name);
    if (l != null && (l.locked || !l.visible)) {
      notify(t(l.locked ? 'msg.layerLocked' : 'sel.layerHidden'));
      return 0;
    }
    final ids = [
      for (final e in project.entities)
        if (e.layer == name) e.id,
    ];
    select(ids, add: add);
    notify(t('mob.selection', {'n': '${ids.length}'}));
    return ids.length;
  }
}
