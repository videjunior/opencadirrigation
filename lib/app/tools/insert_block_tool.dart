/// Insertion of user blocks (lib/core/model/blocks.dart): the commands on
/// the controller (insert, save, delete, each one undo step) and the tool
/// that shows the block under the cursor and places a copy at every click.
library;

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
class BlockInsertRequest {
  const BlockInsertRequest({required this.block, this.rotationDeg = 0, this.scale = 1, this.at});
  final BlockDefinition block;
  final double rotationDeg;
  final double scale;
  final Pt? at;
}

/// The block the insert tool of each controller places (set before the
/// tool is activated; the tool keeps placing it until Esc).
final pendingBlockInserts = Expando<BlockInsertRequest>('pendingBlockInsert');

extension BlockCommands on ProjectController {
  /// Adds a copy of [b] with its base point at [at], turned [rotationDeg]
  /// and scaled [scale] times; the copies become the selection. Returns
  /// their ids (none while a design runs and edits are refused).
  List<String> insertBlock(BlockDefinition b, Pt at, {double rotationDeg = 0, double scale = 1}) {
    final ids =
        mutate(() {
          final ents = b.instantiate(project, at: at, rotationDeg: rotationDeg, scale: scale);
          project.entities.addAll(ents);
          return [for (final e in ents) e.id];
        }, label: 'hist.insertBlock|${b.name}') ??
        const <String>[];
    if (ids.isNotEmpty) {
      select(ids);
      notify(t('blk.inserted', {'b': b.name, 'n': '${ids.length}'}));
    }
    return ids;
  }

  /// Keeps [b] in [library] (replacing the block of its name), one undo step.
  bool saveBlock(BlockLibrary library, BlockDefinition b) {
    if (mutate(() => library.put(b), invalidateResults: false, label: 'hist.saveBlock|${b.name}') == null) return false;
    notify(t('blk.saved', {'b': b.name, 'n': '${b.entities.length}'}));
    return true;
  }

  /// Removes block [name] from [library], one undo step.
  bool deleteBlock(BlockLibrary library, String name) {
    if (library.byName(name) == null) return false;
    if (mutate(() => library.remove(name), invalidateResults: false, label: 'hist.deleteBlock|$name') == null) return false;
    notify(t('blk.deleted', {'b': name}));
    return true;
  }
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
    c.insertBlock(r.block, p, rotationDeg: r.rotationDeg, scale: r.scale);
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final r = request, at = cursor;
    if (r == null || at == null) return;
    final t = BlockDefinition.placement(at, rotationDeg: r.rotationDeg, scale: r.scale);
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
