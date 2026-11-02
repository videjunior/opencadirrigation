/// Insertion of user blocks (lib/core/model/blocks.dart): the commands on
/// the controller (insert, save, delete, each one undo step) and the tool
/// that shows the block under the cursor and places a copy at every click.
///
/// 1.6.0 CAD: a block of drawing items goes in as a reference
/// ([BlockRefEntity]) with the values of its attributes; saving a block of
/// the same name redefines it and every reference follows; references
/// explode into copies; a block is edited in place (a reference becomes
/// copies, then "save the block" puts the new definition back); the
/// library saves to and reads from a file of its own.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../../core/model/blocks.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../canvas/camera.dart';
import '../state/controller.dart';
import 'tools.dart';

/// What the insert dialog asked: the block, its turn and scale, and the
/// point to put its base point on (null: picked on the drawing).
/// 1.6.0 CAD: the values of its attributes, whether it goes in as a
/// reference (else as copies) and reflected.
class BlockInsertRequest {
  const BlockInsertRequest({required this.block, this.rotationDeg = 0, this.scale = 1, this.at, this.values = const {}, this.asReference = true, this.mirrored = false});
  final BlockDefinition block;
  final double rotationDeg;
  final double scale;
  final Pt? at;
  final Map<String, String> values;
  final bool asReference;
  final bool mirrored;
}

/// The block the insert tool of each controller places (set before the
/// tool is activated; the tool keeps placing it until Esc).
final pendingBlockInserts = Expando<BlockInsertRequest>('pendingBlockInsert');

/// 1.6.0 CAD: a block being edited in place: its name, where its reference
/// was (the edited items go back into block coordinates from there) and
/// the ids of the copies made of it.
class BlockEditSession {
  BlockEditSession(this.blockName, this.placement, this.rotationDeg, this.scale, this.mirrored, this.position, this.layer, this.attributes, this.ids);
  final String blockName;
  final Affine placement;
  final double rotationDeg, scale;
  final bool mirrored;
  final Pt position;
  final String layer;
  final Map<String, String> attributes;
  final Set<String> ids;
}

final _blockEdits = Expando<BlockEditSession>('blockEdit');

/// 1.6.0 CAD: the inverse of the similarity [t] (block → world gives
/// world → block).
Affine inverseAffine(Affine t) {
  final det = t.determinant;
  if (det.abs() < 1e-18) return Affine.identity;
  final a = t.d / det, b = -t.b / det, c = -t.c / det, d = t.a / det;
  return Affine(a, b, c, d, -(a * t.e + c * t.f), -(b * t.e + d * t.f));
}

extension BlockCommands on ProjectController {
  /// Adds [b] with its base point at [at], turned [rotationDeg] and scaled
  /// [scale] times; what it made becomes the selection. Returns the ids
  /// (none while a design runs and edits are refused).
  ///
  /// 1.6.0 CAD: a block of drawing items goes in as one reference with
  /// the attribute [values] (unless [asReference] is false); a block with
  /// hydraulic or terrain items as copies, its visible attributes as texts.
  List<String> insertBlock(BlockDefinition b, Pt at, {double rotationDeg = 0, double scale = 1, Map<String, String> values = const {}, bool asReference = true, bool mirrored = false}) {
    final reference = asReference && b.canBeReferenced;
    final ids =
        mutate(
          () {
            if (reference) {
              b.addLayersTo(project);
              final r = BlockRefEntity(
                id: project.newId(),
                layer: project.currentLayer,
                position: at,
                blockName: b.name,
                rotationDeg: rotationDeg,
                scale: scale,
                mirrored: mirrored,
                attributes: {
                  for (final a in b.attributes)
                    if (values[a.tag] != null && values[a.tag] != a.defaultValue) a.tag: values[a.tag]!,
                },
              )..definition = b;
              project.entities.add(r);
              return [r.id];
            }
            final ents = b.instantiate(project, at: at, rotationDeg: rotationDeg, scale: scale, values: values, mirrored: mirrored);
            project.entities.addAll(ents);
            return [for (final e in ents) e.id];
          },
          invalidateResults: !reference || b.inBom,
          label: 'hist.insertBlock|${b.name}',
        ) ??
        const <String>[];
    if (ids.isNotEmpty) {
      select(ids);
      notify(reference ? t('blkref.inserted', {'b': b.name}) : t('blk.inserted', {'b': b.name, 'n': '${ids.length}'}));
    }
    return ids;
  }

  /// The references of block [name] in the drawing.
  List<BlockRefEntity> blockRefsOf(String name) => [
    for (final e in project.entities)
      if (e is BlockRefEntity && e.blockName == name) e,
  ];

  /// Keeps [b] in [library] (replacing the block of its name), one undo step.
  /// 1.6.0 CAD: a block of the same name is redefined: its references draw
  /// the new one. With [replace] the items it was made of make way for a
  /// reference to it at [at] (as when a selection becomes a block in CAD
  /// programs).
  bool saveBlock(BlockLibrary library, BlockDefinition b, {List<Entity> replace = const [], Pt? at}) {
    final refs = blockRefsOf(b.name).length;
    final asRef = replace.isNotEmpty && at != null && b.canBeReferenced;
    final made = mutate(
      () {
        library.put(b);
        if (asRef) {
          final gone = {for (final e in replace) e.id};
          final idx = project.entities.indexWhere((e) => gone.contains(e.id));
          project.entities.removeWhere((e) => gone.contains(e.id));
          final r = BlockRefEntity(id: project.newId(), layer: project.currentLayer, position: at, blockName: b.name)..definition = b;
          project.entities.insert(idx < 0 ? project.entities.length : idx, r);
          return r.id;
        }
        return '';
      },
      // a reference of a block in the bill of materials, or items taken out of the design
      invalidateResults: b.inBom || replace.any(affectsResults),
      label: 'hist.saveBlock|${b.name}',
    );
    if (made == null) return false;
    resolveBlockRefs(project);
    entitiesChanged();
    if (made.isNotEmpty) select([made]);
    notify(refs > 0 ? t('blkref.redefined', {'b': b.name, 'n': '$refs'}) : t('blk.saved', {'b': b.name, 'n': '${b.entities.length}'}));
    return true;
  }

  /// Removes block [name] from [library], one undo step.
  /// 1.6.0 CAD: its references become copies first (the drawing stays).
  bool deleteBlock(BlockLibrary library, String name) {
    final b = library.byName(name);
    if (b == null) return false;
    final refs = blockRefsOf(name);
    final done = mutate(
      () {
        _explodeRefs(refs);
        library.remove(name);
        return true;
      },
      invalidateResults: b.inBom && refs.isNotEmpty,
      label: 'hist.deleteBlock|$name',
    );
    if (done == null) return false;
    notify(t('blk.deleted', {'b': name}));
    return true;
  }

  /// 1.6.0 CAD: renames block [from] of [library] to [to], its references
  /// with it; false when [to] is empty or taken.
  bool renameBlock(BlockLibrary library, String from, String to) {
    final n = to.trim();
    if (library.byName(from) == null || n.isEmpty || (n != from && library.byName(n) != null)) return false;
    final done = mutate(
      () {
        library.rename(from, n);
        for (final r in blockRefsOf(from)) {
          r.blockName = n;
        }
        resolveBlockRefs(project);
        return true;
      },
      invalidateResults: false,
      label: 'hist.renameBlock|$n',
    );
    return done == true;
  }

  /// Replaces each of [refs] (in place) by copies of what it draws, with new
  /// ids; the layers the block uses come with them. Inside a mutation.
  List<Entity> _explodeRefs(List<BlockRefEntity> refs) {
    final made = <Entity>[];
    for (final r in refs) {
      final idx = project.entities.indexOf(r);
      if (idx < 0) continue;
      r.definition ??= project.blocks.byName(r.blockName);
      r.definition?.addLayersTo(project);
      final copies = [for (final x in r.expanded()) x.clone(newId: project.newId())];
      project.entities
        ..removeAt(idx)
        ..insertAll(idx, copies);
      made.addAll(copies);
    }
    return made;
  }

  /// 1.6.0 CAD: turns the references [ids] (or the selected ones) into
  /// copies of what they draw, one undo step; the copies become the
  /// selection. Returns how many references were exploded.
  int explodeBlockRefs([Iterable<String>? ids]) {
    final want = ids == null ? selection : ids.toSet();
    final refs = [
      for (final e in project.entities)
        if (e is BlockRefEntity && want.contains(e.id) && !project.isLocked(e.layer)) e,
    ];
    if (refs.isEmpty) return 0;
    final made = mutate(() => _explodeRefs(refs), invalidateResults: refs.any((r) => r.definition?.inBom ?? false), label: 'hist.explode|${refs.length}');
    if (made == null) return 0;
    select(made.map((e) => e.id));
    return refs.length;
  }

  /// 1.6.0 CAD: sets attribute values of the reference [id] (a value equal
  /// to the block's default is not kept; an empty one clears it). One undo
  /// step; false when nothing changed.
  bool setBlockAttributes(String id, Map<String, String> values) {
    final r = project.byId(id);
    if (r is! BlockRefEntity || project.isLocked(r.layer)) return false;
    final d = r.definition ?? project.blocks.byName(r.blockName);
    final next = Map.of(r.attributes);
    values.forEach((tag, v) {
      final def = d?.attributeOf(tag)?.defaultValue ?? '';
      if (v == def) {
        next.remove(tag);
      } else {
        next[tag] = v;
      }
    });
    if (jsonEncode(next) == jsonEncode(r.attributes)) return false;
    final done = mutate(
      () {
        r.attributes
          ..clear()
          ..addAll(next);
        return true;
      },
      invalidateResults: d?.inBom ?? false,
      label: 'hist.blockAttributes',
    );
    return done == true;
  }

  /// 1.6.0 CAD: the block being edited in place, if any.
  BlockEditSession? get blockEdit => _blockEdits[this];

  /// 1.6.0 CAD: edits block of the reference [id] in place: the reference
  /// becomes copies of what it draws (selected), to be changed with every
  /// tool; [saveBlockEdit] makes them the block again (every reference
  /// follows), [cancelBlockEdit] puts the reference back.
  bool startBlockEdit(String id) {
    final r = project.byId(id);
    if (r is! BlockRefEntity) return false;
    final d = r.definition ?? project.blocks.byName(r.blockName);
    if (d == null || project.isLocked(r.layer)) return false;
    // the attribute texts are left out: the definition keeps its attributes
    final copies = mutate(
      () {
        final idx = project.entities.indexOf(r);
        d.addLayersTo(project);
        final place = r.placement;
        final out = [for (final e in d.entities) e.transformed(place).clone(newId: project.newId())];
        project.entities
          ..removeAt(idx)
          ..insertAll(idx, out);
        return out;
      },
      invalidateResults: d.inBom,
      label: 'hist.blockEdit|${d.name}',
    );
    if (copies == null) return false;
    _blockEdits[this] = BlockEditSession(d.name, r.placement, r.rotationDeg, r.scale, r.mirrored, r.position, r.layer, Map.of(r.attributes), {for (final e in copies) e.id});
    select(copies.map((e) => e.id));
    notify(t('blkref.editing', {'b': d.name}));
    return true;
  }

  /// 1.6.0 CAD: ends the edit in place: the selected items (or, with
  /// nothing selected, those the edit began with) become the block's new
  /// definition, back in block coordinates, and a reference takes their
  /// place. One undo step.
  bool saveBlockEdit() {
    final s = blockEdit;
    if (s == null) return false;
    final old = project.blocks.byName(s.blockName);
    final pick = selection.isNotEmpty ? Set.of(selection) : s.ids;
    final items = [
      for (final e in project.entities)
        if (pick.contains(e.id)) e,
    ];
    if (old == null || items.isEmpty) return false;
    final back = inverseAffine(s.placement);
    final local = [for (final e in items) e.transformed(back)];
    final def = BlockDefinition(
      name: old.name,
      description: old.description,
      entities: local,
      layers: {...old.layers, for (final e in local) e.layer: project.findLayer(e.layer)?.color ?? Layers.defaultColors[e.layer] ?? 0xFFB0BEC5},
      created: old.created,
      attributes: old.attributes,
      inBom: old.inBom,
    );
    if (!def.canBeReferenced) {
      notify(t('blkref.notDrawing'));
      return false;
    }
    final refs = blockRefsOf(old.name).length;
    final done = mutate(
      () {
        project.blocks.put(def);
        final gone = {for (final e in items) e.id};
        final idx = project.entities.indexWhere((e) => gone.contains(e.id));
        project.entities.removeWhere((e) => gone.contains(e.id));
        final r = BlockRefEntity(
          id: project.newId(),
          layer: s.layer,
          position: s.position,
          blockName: def.name,
          rotationDeg: s.rotationDeg,
          scale: s.scale,
          mirrored: s.mirrored,
          attributes: s.attributes,
        )..definition = def;
        project.entities.insert(idx < 0 ? project.entities.length : idx, r);
        resolveBlockRefs(project);
        return r.id;
      },
      invalidateResults: def.inBom,
      label: 'hist.saveBlock|${def.name}',
    );
    if (done == null) return false;
    _blockEdits[this] = null;
    select([done]);
    notify(t('blkref.redefined', {'b': def.name, 'n': '${refs + 1}'}));
    return true;
  }

  /// 1.6.0 CAD: leaves the edit in place without changing the block: the
  /// steps since it began are undone.
  void cancelBlockEdit() {
    if (blockEdit == null) return;
    _blockEdits[this] = null;
    // back to before the edit began (its own undo step and what followed)
    final i = historyEntries.lastIndexWhere((h) => !h.future && h.label.startsWith('hist.blockEdit|'));
    if (i > 0) jumpToHistory(i - 1);
    notify(t('blkref.editCancelled'));
  }
}

/// 1.6.0 CAD: Edit → Blocks → Edit block in place (BEDIT): starts editing
/// the selected reference or, while a block is edited, saves it.
void editBlockAction(ProjectController c) {
  if (c.blockEdit != null) {
    c.saveBlockEdit();
    return;
  }
  final refs = [
    for (final e in c.project.entities)
      if (c.selection.contains(e.id) && e is BlockRefEntity) e,
  ];
  if (refs.length != 1) {
    c.notify(c.t('blkref.selectRef'));
    return;
  }
  c.startBlockEdit(refs.single.id);
}

/// Places the pending block ([pendingBlockInserts]) at every click (or
/// typed point); the ghost of the block follows the cursor.
class InsertBlockTool extends Tool {
  /// [id] is the tool id the canvas created it for (ToolId.insertBlock).
  InsertBlockTool(super.c, super.host, this.id);
  @override
  final ToolId id;
  @override
  String get hintKey => 'hint.insertBlock';

  BlockInsertRequest? get request => pendingBlockInserts[c];

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final r = request;
    if (r == null) {
      c.setTool(ToolId.select);
      return;
    }
    c.insertBlock(r.block, p, rotationDeg: r.rotationDeg, scale: r.scale, values: r.values, asReference: r.asReference, mirrored: r.mirrored);
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final r = request, at = cursor;
    if (r == null || at == null) return;
    final t = BlockDefinition.placement(at, rotationDeg: r.rotationDeg, scale: r.scale, mirrored: r.mirrored);
    final paint = previewPaint;
    var n = 0;
    for (final e in r.block.entities) {
      if (++n > 400) break;
      final pts = e.linearPoints;
      if (pts != null && pts.length >= 2) {
        drawPolyline(canvas, cam, pts.map(t.apply).toList(), paint, close: e.isClosedShape);
      } else if (e is CircleEntity) {
        canvas.drawCircle(cam.toScreen(t.apply(e.center)), math.max(2, e.radius * t.scale * cam.scale), paint);
      } else if (e is PointEntity) {
        canvas.drawCircle(cam.toScreen(t.apply(e.position)), 4, paint);
      } else {
        final b = e.bounds;
        drawPolyline(canvas, cam, [Pt(b.minX, b.minY), Pt(b.maxX, b.minY), Pt(b.maxX, b.maxY), Pt(b.minX, b.maxY)].map(t.apply).toList(), paint, close: true);
      }
    }
    // the base point
    final o = cam.toScreen(at);
    canvas.drawLine(o + const Offset(-7, 0), o + const Offset(7, 0), paint);
    canvas.drawLine(o + const Offset(0, -7), o + const Offset(0, 7), paint);
    host.setStatus(r.block.name);
  }
}
