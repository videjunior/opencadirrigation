/// Editing tools added in 1.6.0: move and copy by base point. Their
/// commands on the controller are in edit_commands.dart.
library;

import '../../core/model/geometry.dart';
import '../state/controller.dart';
import 'tools.dart';

/// Displacement [d] for the status bar: components, length and direction.
String displacementText(ProjectController c, Pt d) {
  final u = c.units;
  String l(double v) => u.lengthFromSi(v).toStringAsFixed(2);
  final a = (radToDeg(d.angle) % 360 + 360) % 360;
  return 'Δx ${l(d.x)}  Δy ${l(d.y)}  d ${l(d.length)} ${u.lengthLabel}  ∠ ${a.toStringAsFixed(1)}°';
}

/// Move: the base point, then the destination — a click, or typed as in
/// the programs of CAD: `x,y`, `@dx,dy` and `@d<angle` from the base point,
/// or a bare distance along the cursor. The selection moves by the
/// difference (Ctrl = a copy); the tool stays for the next move, as Rotate
/// does.
class MoveTool extends TransformTool {
  MoveTool(super.c, super.host);
  @override
  ToolId get id => ToolId.move;
  @override
  String get hintKey => 'hint.move';
  @override
  int get clicks => 2;

  @override
  void apply(List<Pt> points, {required bool copy}) {
    final d = points[1] - points[0];
    if (d.length < 1e-12) return;
    // the "keep original" switch of rotate and scale does not turn a move
    // into a copy: Ctrl does (or the Copy tool)
    if (ctrlDown) {
      c.transformSelected(Affine.translation(d), copy: true);
    } else {
      c.moveSelected(d);
    }
  }

  @override
  Affine? preview() {
    if (pts.length != 1 || cursor == null) return null;
    final d = cursor! - pts.first;
    host.setStatus(displacementText(c, d));
    return Affine.translation(d);
  }
}

/// Copy: the base point, then one destination per copy (clicked or typed
/// as for [MoveTool]) until Esc or Enter. Every copy is made from the
/// originals, which stay selected.
class CopyTool extends TransformTool {
  CopyTool(super.c, super.host);
  @override
  ToolId get id => ToolId.copy;
  @override
  String get hintKey => 'hint.copy';
  @override
  int get clicks => 2;

  /// The originals, taken with the base point.
  Set<String> _sources = const {};

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (pts.isEmpty || c.selection.isEmpty) {
      // a pick (nothing selected) or the base point
      pts.clear();
      super.onDown(p, shift: shift, ctrl: ctrl);
      if (pts.isNotEmpty) _sources = Set.of(c.selection);
      return;
    }
    final d = p - pts.first;
    if (d.length < 1e-12) return;
    if (!_sameSelection(_sources)) c.select(_sources);
    if (c.transformSelected(Affine.translation(d), copy: true) > 0) c.track('copy');
    // the originals stay selected for the next copy
    c.select(_sources);
  }

  bool _sameSelection(Set<String> ids) => c.selection.length == ids.length && c.selection.containsAll(ids);

  /// Not used: [onDown] makes each copy.
  @override
  void apply(List<Pt> points, {required bool copy}) {}

  @override
  void onKey(String key) {
    if (key == 'Enter') {
      // Enter ends the copies, as in the programs of CAD
      cancel();
      c.setTool(ToolId.select);
      return;
    }
    super.onKey(key);
  }

  @override
  void cancel() {
    super.cancel();
    _sources = const {};
  }

  @override
  Affine? preview() {
    if (pts.length != 1 || cursor == null) return null;
    final d = cursor! - pts.first;
    host.setStatus(displacementText(c, d));
    return Affine.translation(d);
  }
}
