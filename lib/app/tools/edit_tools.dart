/// Editing tools added in 1.6.0: move and copy by base point, lasso and
/// fence selection. Their commands on the controller are in
/// edit_commands.dart.
library;

import 'dart:ui';

import '../../core/model/geometry.dart';
import '../canvas/camera.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'edit_commands.dart';
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

// ---------------------------------------------------------------- selection (CAD-25)

/// Lasso: drag around the items, or click the vertices of a polygon and
/// press Enter (or C); selects what lies inside it — also what it crosses
/// when the setting says so — adding to the selection with Shift. The tool
/// stays for the next lasso.
class LassoTool extends PolyTool {
  LassoTool(super.c, super.host);
  @override
  ToolId get id => ToolId.lasso;
  @override
  String get hintKey => 'hint.lasso';
  @override
  bool get closes => true;
  @override
  int get minPoints => 3;
  @override
  bool get keepsOnLeave => false;

  /// Drawn by hand: no snap.
  @override
  bool get usesSnap => false;

  bool _add = false;
  bool _dragged = false;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (pts.isEmpty) _add = false;
    _add = _add || shift;
    _dragged = false;
    super.onDown(p, shift: shift, ctrl: ctrl);
  }

  @override
  void onMove(Pt p, {bool dragging = false}) {
    super.onMove(p, dragging: dragging);
    if (!dragging || pts.isEmpty) return;
    // drawn by hand: a vertex every few pixels
    if (pts.last.distanceTo(p) * c.camera.scale >= 4) {
      pts.add(p);
      _dragged = true;
    }
  }

  /// A lasso dragged by hand ends with the button (or the finger).
  @override
  void onUp(Pt p) {
    if (_dragged) finish();
    _dragged = false;
  }

  @override
  void commit(List<Pt> points) {
    c.selectInPolygon(points, crossing: c.editSettings.lassoCrossing, add: _add);
    c.notify(c.t('mob.selection', {'n': '${c.selection.length}'}));
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final preview = [...pts, ?cursor];
    if (preview.length >= 3) {
      final path = Path()..moveTo(cam.toScreen(preview.first).dx, cam.toScreen(preview.first).dy);
      for (final p in preview.skip(1)) {
        final s = cam.toScreen(p);
        path.lineTo(s.dx, s.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = Cad.selection.withValues(alpha: 0.1));
    }
    super.paint(canvas, cam);
  }
}

/// Fence: click the points of a line and press Enter: selects everything
/// it crosses (point items within the pick distance), adding to the
/// selection with Shift.
class FenceTool extends PolyTool {
  FenceTool(super.c, super.host);
  @override
  ToolId get id => ToolId.fence;
  @override
  String get hintKey => 'hint.fence';
  @override
  bool get keepsOnLeave => false;
  @override
  bool get closable => false;

  bool _add = false;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (pts.isEmpty) _add = false;
    _add = _add || shift;
    super.onDown(p, shift: shift, ctrl: ctrl);
  }

  @override
  void commit(List<Pt> points) {
    c.selectByFence(points, add: _add);
    c.notify(c.t('mob.selection', {'n': '${c.selection.length}'}));
  }
}
