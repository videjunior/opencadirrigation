/// The drawing functions of 1.6.0 (CAD+) on the controller, as an
/// extension (the way the block and editing commands are kept): Lengthen,
/// the outline by a click inside, the named layer states and isolating
/// layers, the drawing order, text edited in place, the dimension style
/// and editing a mixed selection type by type. Each change of the project
/// is one undo step with its own label in the history; showing or locking
/// layers is not (as the eye and the lock of the layers panel are not).
library;

import 'dart:math' as math;

import '../../core/model/boundary.dart';
import '../../core/model/dim_style.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/layer_states.dart';
import '../../core/model/lengthen.dart';
import '../../core/model/split.dart' show CutEdge;
import '../state/controller.dart';

/// Settings of the CAD+ tools, one set per project tab (remembered between
/// visits with the other drawing settings, see drawing_prefs.dart).
class CadPlusSettings {
  /// How Lengthen reads its value, and the value: metres for a difference
  /// or a total, a percentage for [LengthenMode.percent].
  LengthenMode lengthenMode = LengthenMode.delta;
  double lengthenValue = 1;

  /// The outline by a click inside makes an irrigated area (else a closed
  /// polyline).
  bool boundaryAsArea = false;

  /// The length and angle of the segment beside the cursor, typed there.
  bool dynamicInput = true;

  /// A magnifier over the finger while drawing on a touch screen; the point
  /// goes where the finger is lifted.
  bool touchLoupe = true;
}

final _cadPlusSettings = Expando<CadPlusSettings>('cadPlusSettings');

/// The layers as they were before [CadPlusCommands.isolateLayers], per tab.
final _isolation = Expando<Map<String, (bool, bool)>>('layerIsolation');

/// The kinds of items whose text is edited in place.
bool hasEditableText(Entity e) => e is TextEntity || e is LeaderEntity || e is CommentEntity;

/// The text of [e] edited in place ('' for an item without one).
String editableTextOf(Entity e) => switch (e) {
  TextEntity x => x.text,
  LeaderEntity x => x.text,
  CommentEntity x => x.text,
  _ => '',
};

extension CadPlusCommands on ProjectController {
  /// The settings of the CAD+ tools of this tab.
  CadPlusSettings get cadPlus => _cadPlusSettings[this] ??= CadPlusSettings();

  // ---------------------------------------------------------------- lengthen

  /// Lengthens (or shortens) the item [id] at its end nearest to [near]
  /// (see [lengthenEntity]); the mode and value of [cadPlus] unless given.
  /// One undo step; false, telling why, when it cannot.
  bool lengthenAt(String id, Pt near, {LengthenMode? mode, double? value}) {
    track('lengthen');
    final e = project.byId(id);
    if (e == null || project.isLocked(e.layer)) return false;
    if (!canLengthen(e)) {
      notify(t('cadp.lengthenWhat'));
      return false;
    }
    final made = lengthenEntity(e, near, mode ?? cadPlus.lengthenMode, value ?? cadPlus.lengthenValue);
    if (made == null) {
      notify(t('cadp.lengthenFailed'));
      return false;
    }
    final done = mutate(
      () {
        final i = project.entities.indexOf(e);
        project.entities[i] = made;
        return true;
      },
      invalidateResults: affectsResults(e),
      label: 'hist.lengthen|${ProjectController.toolKeyOf(e)}',
    );
    return done == true;
  }

  // ---------------------------------------------------------------- outline by a click inside

  /// The smallest region around [p] that the visible lines close (see
  /// [boundaryAround]), searched in a window that grows until the outline
  /// found lies inside it. Null when no closed region holds [p].
  List<Pt>? boundaryOutline(Pt p) {
    final b = project.bounds;
    if (b.isEmpty || !b.inflate(1).contains(p)) return null;
    final tol = math.max(project.params.connectTolerance, 1e-6);
    final hidden = {
      for (final l in project.layers)
        if (!l.visible) l.name,
    };
    final whole = math.max(b.width, b.height) + p.distanceTo(b.center) + 1;
    var half = math.max(whole / 64, 20 / math.max(camera.scale, 1e-9));
    while (true) {
      final win = Bounds(p.x - half, p.y - half, p.x + half, p.y + half);
      final covers = win.minX <= b.minX && win.minY <= b.minY && win.maxX >= b.maxX && win.maxY >= b.maxY;
      final segs = <(Pt, Pt)>[];
      for (final e in entitiesIn(win)) {
        if (hidden.contains(e.layer) || e is TextEntity || e is ImageEntity) continue;
        // a block reference closes regions with the lines it draws
        for (final x in e is BlockRefEntity ? e.expanded() : [e]) {
          if (x is TextEntity || hidden.contains(x.layer)) continue;
          final edge = CutEdge.of(x);
          if (edge != null) segs.addAll(boundarySegments(edge));
        }
      }
      // a dense survey: too many lines to look at
      if (segs.length > 200000) return null;
      final ring = boundaryAround(p, segs, tol: tol);
      if (ring != null) {
        final rb = Bounds.ofPoints(ring);
        if (covers || (rb.minX > win.minX && rb.minY > win.minY && rb.maxX < win.maxX && rb.maxY < win.maxY)) return ring;
      } else if (covers) {
        return null;
      }
      half *= 2;
    }
  }

  /// Draws the outline of the region around [p] as a closed polyline on
  /// the current layer — or, with [asArea] (else [cadPlus]), an irrigated
  /// area. One undo step; the new item becomes the selection. Null, telling
  /// why, when the lines close no region there.
  Entity? boundaryAt(Pt p, {bool? asArea}) {
    track('boundary');
    final ring = boundaryOutline(p);
    if (ring == null) {
      notify(t('cadp.boundaryNone'));
      return null;
    }
    final area = asArea ?? cadPlus.boundaryAsArea;
    final made = mutate(
      () {
        final Entity e = area
            ? AreaEntity(id: project.newId(), name: '${t('name.area')} ${project.entities.whereType<AreaEntity>().length + 1}', points: ring)
            : PolylineEntity(id: project.newId(), layer: drawingLayer, points: ring, closed: true);
        project.entities.add(e);
        return e;
      },
      invalidateResults: area,
      label: 'hist.boundary|${area ? 'area' : 'polyline'}',
    );
    if (made == null) return null;
    select([made.id]);
    notify(t('cadp.boundaryMade', {'a': fmtArea(polygonArea(ring).abs())}));
    return made;
  }

  /// An area in square metres (and hectares when large) for messages.
  String fmtArea(double m2) => m2 >= 10000 ? '${(m2 / 10000).toStringAsFixed(4)} ha' : '${m2.toStringAsFixed(2)} m²';

  // ---------------------------------------------------------------- layer states

  /// Keeps the visibility and lock of every layer as the state [name]
  /// (replacing a state of that name). One undo step.
  bool saveLayerState(String name) {
    final n = name.trim();
    if (n.isEmpty) return false;
    final s = LayerState.of(n, project);
    final done = mutate(
      () {
        project.layerStates = [
          for (final x in project.layerStates)
            if (x.name != n) x,
          s,
        ];
        return true;
      },
      invalidateResults: false,
      label: 'hist.layerStateSave|$n',
    );
    if (done != true) return false;
    notify(t('cadp.layerStateSaved', {'s': n}));
    return true;
  }

  /// Puts the layers as the state [name] keeps them (layers made after it
  /// are left as they are). False when there is no such state.
  bool restoreLayerState(String name) {
    final s = project.layerStateNamed(name);
    if (s == null) return false;
    s.applyTo(project);
    _afterLayers();
    notify(t('cadp.layerStateRestored', {'s': s.name}));
    return true;
  }

  /// Removes the state [name]. One undo step.
  bool deleteLayerState(String name) {
    if (project.layerStateNamed(name) == null) return false;
    final done = mutate(
      () {
        project.layerStates = [
          for (final x in project.layerStates)
            if (x.name != name.trim()) x,
        ];
        return true;
      },
      invalidateResults: false,
      label: 'hist.layerStateDelete|$name',
    );
    return done == true;
  }

  /// Shows only [layers] (the others hidden; the current layer moves to
  /// one of them), remembering how every layer was for [unisolateLayers].
  /// With no layers given: those of the selection, else the current one.
  int isolateLayers([Iterable<String>? layers]) {
    final keep = {...?layers};
    if (keep.isEmpty) {
      for (final e in project.entities) {
        if (selection.contains(e.id)) keep.add(e.layer);
      }
    }
    if (keep.isEmpty) keep.add(project.currentLayer);
    _isolation[this] ??= {for (final l in project.layers) l.name: (l.visible, l.locked)};
    var shown = 0;
    for (final l in project.layers) {
      l.visible = keep.contains(l.name);
      if (l.visible) shown++;
    }
    if (!keep.contains(project.currentLayer)) project.currentLayer = keep.first;
    project.layerNamed(project.currentLayer).visible = true;
    _afterLayers();
    notify(t('cadp.isolated', {'n': '$shown'}));
    return shown;
  }

  /// Whether layers are isolated in this tab.
  bool get layersIsolated => _isolation[this] != null;

  /// Puts the layers back as they were before [isolateLayers]; when nothing
  /// was isolated in this tab, shows every layer.
  void unisolateLayers() {
    final before = _isolation[this];
    _isolation[this] = null;
    for (final l in project.layers) {
      final s = before?[l.name];
      l.visible = s?.$1 ?? true;
      if (s != null) l.locked = s.$2;
    }
    _afterLayers();
    notify(t('cadp.unisolated'));
  }

  void _afterLayers() {
    final hidden = {
      for (final l in project.layers)
        if (!l.visible || l.locked) l.name,
    };
    selection.removeWhere((id) => hidden.contains(entityById(id)?.layer));
    entitiesChanged();
    notifyListeners();
  }

  /// Moves the selected items to the current layer. One undo step; returns
  /// how many moved.
  int moveSelectionToCurrentLayer() {
    final target = project.currentLayer;
    final items = [
      for (final e in project.entities)
        if (selection.contains(e.id) && e.layer != target && !project.isLocked(e.layer)) e,
    ];
    if (items.isEmpty) {
      notify(t(selection.isEmpty ? 'msg.nothingSelected' : 'cadp.alreadyOnLayer'));
      return 0;
    }
    final done = mutate(
      () {
        for (final e in items) {
          e.layer = target;
        }
        return true;
      },
      invalidateResults: false,
      label: 'hist.toLayer|${items.length}',
    );
    if (done != true) return 0;
    notify(t('cadp.movedToLayer', {'n': '${items.length}', 'l': target}));
    return items.length;
  }

  // ---------------------------------------------------------------- drawing order

  /// Brings [ids] (or the selection) to the front of the drawing — drawn
  /// over the others of their kind (images over images, hatches and areas
  /// over theirs) — or, with [back], sends them behind. One undo step;
  /// returns how many moved.
  int reorder({Iterable<String>? ids, bool back = false}) {
    final want = ids == null ? Set.of(selection) : ids.toSet();
    final moving = [
      for (final e in project.entities)
        if (want.contains(e.id)) e,
    ];
    if (moving.isEmpty) {
      notify(t('msg.nothingSelected'));
      return 0;
    }
    final done = mutate(
      () {
        project.entities.removeWhere((e) => want.contains(e.id));
        if (back) {
          project.entities.insertAll(0, moving);
        } else {
          project.entities.addAll(moving);
        }
        return true;
      },
      // the order of the network items is the order the design reads them in
      invalidateResults: anyAffectsResults(moving),
      label: back ? 'hist.toBack|${moving.length}' : 'hist.toFront|${moving.length}',
    );
    return done == true ? moving.length : 0;
  }

  // ---------------------------------------------------------------- text in place

  /// Sets the text of the text, leader or comment [id]. One undo step;
  /// false when nothing changed (or it has no text).
  bool setEntityText(String id, String text) {
    final e = project.byId(id);
    if (e == null || !hasEditableText(e) || project.isLocked(e.layer) || editableTextOf(e) == text) return false;
    if (e is TextEntity && text.trim().isEmpty) {
      notify(t('cadp.textEmpty'));
      return false;
    }
    final done = mutate(
      () {
        switch (e) {
          case TextEntity x:
            x.text = text;
          case LeaderEntity x:
            x.text = text;
          case CommentEntity x:
            x.text = text;
          default:
            break;
        }
        return true;
      },
      invalidateResults: false,
      label: 'hist.textEdit',
    );
    return done == true;
  }

  // ---------------------------------------------------------------- dimension style

  /// Sets the dimension style of the project. One undo step; false when it
  /// is the one already set.
  bool setDimStyle(DimStyle s) {
    final before = project.dimStyle;
    if (before.toJson().toString() == s.toJson().toString()) return false;
    final done = mutate(
      () {
        project.dimStyle = s;
        return true;
      },
      invalidateResults: false,
      label: 'hist.dimStyle',
    );
    return done == true;
  }

  // ---------------------------------------------------------------- a mixed selection, type by type

  /// The kinds of the selected items (the tool keys of
  /// [ProjectController.toolKeyOf]) with how many of each, most first.
  List<(String, int)> selectionKinds() {
    final n = <String, int>{};
    for (final e in project.entities) {
      if (selection.contains(e.id)) n[ProjectController.toolKeyOf(e)] = (n[ProjectController.toolKeyOf(e)] ?? 0) + 1;
    }
    final out = [for (final e in n.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  /// Keeps only the selected items of [kind] selected; returns how many.
  int keepSelectedKind(String kind) {
    final keep = [
      for (final e in project.entities)
        if (selection.contains(e.id) && ProjectController.toolKeyOf(e) == kind) e.id,
    ];
    select(keep);
    return keep.length;
  }

  /// Applies [fn] to the selected items of [kind] that can be edited. One
  /// undo step; returns how many changed.
  int editSelectedKind(String kind, void Function(Entity e) fn, {bool? invalidate}) {
    final items = [
      for (final e in project.entities)
        if (selection.contains(e.id) && ProjectController.toolKeyOf(e) == kind && !project.isLocked(e.layer)) e,
    ];
    if (items.isEmpty) return 0;
    final done = mutate(
      () {
        items.forEach(fn);
        return true;
      },
      invalidateResults: invalidate ?? anyAffectsResults(items),
      label: 'hist.batch|$kind',
    );
    return done == true ? items.length : 0;
  }
}
