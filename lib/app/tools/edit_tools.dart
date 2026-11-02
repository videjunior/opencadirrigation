/// Editing tools added in 1.6.0: move and copy by base point, lasso and
/// fence selection, stretch, fillet and chamfer, break at two points. Their
/// commands on the controller are in edit_commands.dart.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../../core/model/edit_ops.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../canvas/camera.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'edit_commands.dart';
import 'tools.dart';
import 'typed_point.dart';

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

// ---------------------------------------------------------------- geometry (CAD-26)

/// Stretch: a crossing window (two corners, or a drag) over the vertices
/// to move, then the base point and the destination (typed as for
/// [MoveTool]): the vertices inside move and the others stay, so the
/// joints inside the window keep together; a selection limits it to its
/// items.
class StretchTool extends Tool {
  StretchTool(super.c, super.host);
  @override
  ToolId get id => ToolId.stretch;
  @override
  String get hintKey => 'hint.stretch';

  Pt? _corner;
  Bounds? _window;
  Pt? _base;
  bool _dragged = false;
  List<Entity> _items = const [];

  /// The window corners are free; the base point and the destination snap.
  @override
  bool get usesSnap => _window != null;
  @override
  Pt? get referencePoint => _base ?? (_window == null ? _corner : null);
  @override
  bool get idle => _corner == null && _window == null;

  void _setWindow(Pt a, Pt b) {
    final w = Bounds(math.min(a.x, b.x), math.min(a.y, b.y), math.max(a.x, b.x), math.max(a.y, b.y));
    _corner = null;
    if (w.width < 1e-9 || w.height < 1e-9) return;
    _window = w;
    final limit = c.selection.isEmpty ? null : c.selection;
    _items = [
      for (final e in c.entitiesIn(w))
        if (!c.project.isLocked(e.layer) && (limit == null || limit.contains(e.id)) && stretchEntity(e, w, const Pt(1, 0)) != null) e,
    ];
  }

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    _dragged = false;
    if (_window == null) {
      if (_corner == null) {
        _corner = p;
      } else {
        _setWindow(_corner!, p);
      }
      return;
    }
    if (_base == null) {
      _base = p;
      return;
    }
    if (c.stretchWindow(_window!, p - _base!) > 0) c.notify(c.t('edt.stretched', {'n': '${_items.length}'}));
    cancel();
  }

  @override
  void onMove(Pt p, {bool dragging = false}) {
    cursor = p;
    if (dragging && _window == null && _corner != null) _dragged = true;
  }

  /// A window dragged out ends with the button.
  @override
  void onUp(Pt p) {
    if (_dragged && _window == null && _corner != null && _corner!.distanceTo(p) * c.camera.scale > 4) _setWindow(_corner!, p);
    _dragged = false;
  }

  @override
  void onKey(String key) {
    if (key == 'Escape') cancel();
    if (key == 'Backspace') {
      if (_base != null) {
        _base = null;
      } else {
        cancel();
      }
    }
  }

  @override
  void cancel() {
    _corner = null;
    _window = null;
    _base = null;
    _items = const [];
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final w = _window;
    final frame = Paint()
      ..color = Cad.ok
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (w == null) {
      if (_corner != null && cursor != null) {
        final r = Rect.fromPoints(cam.toScreen(_corner!), cam.toScreen(cursor!));
        canvas.drawRect(r, Paint()..color = Cad.ok.withValues(alpha: 0.12));
        canvas.drawRect(r, frame);
      }
      return;
    }
    canvas.drawRect(Rect.fromPoints(cam.toScreen(Pt(w.minX, w.minY)), cam.toScreen(Pt(w.maxX, w.maxY))), frame);
    // the vertices that move
    final mark = Paint()..color = Cad.selection;
    var vertices = 0;
    for (final e in _items) {
      for (final g in e.grips) {
        if (!w.contains(g)) continue;
        vertices++;
        canvas.drawRect(Rect.fromCenter(center: cam.toScreen(g), width: 6, height: 6), mark);
      }
    }
    final base = _base;
    if (base == null || cursor == null) {
      host.setStatus(c.t('edt.stretchBase', {'n': '$vertices'}));
      return;
    }
    final d = cursor! - base;
    final ghost = Paint()
      ..color = Cad.selection.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    var n = 0;
    for (final e in _items) {
      if (++n > 400) break;
      final s = stretchEntity(e, w, d);
      final pts = s?.linearPoints;
      if (pts != null && pts.length >= 2) {
        drawPolyline(canvas, cam, pts, ghost, close: s!.isClosedShape);
      } else if (s is PointEntity) {
        canvas.drawCircle(cam.toScreen(s.position), 4, ghost);
      }
    }
    canvas.drawLine(cam.toScreen(base), cam.toScreen(cursor!), previewPaint);
    host.setStatus(displacementText(c, d));
  }
}

/// Fillet ([chamfer] false) or chamfer: click two sides — two lines, the
/// end sides of two open items, or two sides of one polyline-like item
/// that meet at a vertex. A number typed is the radius (0: a sharp
/// corner), or the distance of the chamfer on both sides.
class CornerTool extends Tool {
  CornerTool(super.c, super.host, {required this.chamfer});
  final bool chamfer;
  @override
  ToolId get id => chamfer ? ToolId.chamfer : ToolId.fillet;
  @override
  String get hintKey => chamfer ? 'hint.chamfer' : 'hint.fillet';
  @override
  bool get usesSnap => false;

  String? _first;
  Pt? _firstAt;

  @override
  bool get idle => _first == null;

  /// An item with straight sides (not a spline, an arc, a circle or a point item).
  static bool _hasSides(Entity e) => e is LineEntity || (e is PolyEntity && e is! SplineEntity && e.points.length >= 2);

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
    if (hit == null || !_hasSides(hit)) return;
    if (_first == null) {
      _first = hit.id;
      _firstAt = p;
      c.select([hit.id]);
      return;
    }
    c.cornerAt(_first!, _firstAt!, hit.id, p, chamfer: chamfer);
    cancel();
  }

  @override
  bool onInput(String text) {
    final v = parseTypedValue(text);
    if (v == null) return false;
    final s = c.editSettings;
    final si = c.units.lengthToSi(v);
    if (v < 0 || (chamfer && v == 0)) {
      c.notify(c.t('edt.badValue'));
      return true;
    }
    if (chamfer) {
      s
        ..chamferDistance1 = si
        ..chamferDistance2 = si;
      c.notify(c.t('edt.chamferSet', {'d': fmtLen(si)}));
    } else {
      s.filletRadius = si;
      c.notify(c.t('edt.radiusSet', {'d': fmtLen(si)}));
    }
    return true;
  }

  @override
  void onKey(String key) {
    if (key == 'Escape') cancel();
  }

  @override
  void cancel() {
    _first = null;
    _firstAt = null;
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final s = c.editSettings;
    final value = chamfer ? '${fmtLen(s.chamferDistance1)} / ${fmtLen(s.chamferDistance2)}' : 'R ${fmtLen(s.filletRadius)}';
    host.setStatus('${c.t(hintKey.replaceFirst('hint.', 'tool.'))}: $value · ${c.t(_first == null ? 'edt.pickFirst' : 'edt.pickSecond')}');
    final e = _first == null ? null : c.project.byId(_first!);
    final at = _firstAt;
    if (e == null || at == null) return;
    // the side picked first
    final pts = e is LineEntity ? [e.a, e.b] : (e as PolyEntity).points;
    final n = pts.length + (e.isClosedShape ? 1 : 0);
    var best = 1;
    var bestD = double.infinity;
    for (var i = 1; i < n; i++) {
      final d = distanceToSegment(at, pts[i - 1], pts[i % pts.length]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    canvas.drawLine(
      cam.toScreen(pts[best - 1]),
      cam.toScreen(pts[best % pts.length]),
      Paint()
        ..color = Cad.hover
        ..strokeWidth = 3,
    );
  }
}

/// Break at two points: click the item at the first point of the gap (the
/// click lies on it), then the second point; the part between goes (see
/// GeometryCommands.breakBetween).
class BreakTool extends Tool {
  BreakTool(super.c, super.host);
  @override
  ToolId get id => ToolId.breakTwo;
  @override
  String get hintKey => 'hint.breakTwo';

  String? _target;
  Pt? _first;

  @override
  Pt? get referencePoint => _first;
  @override
  bool get idle => _target == null;

  /// The point of [e] nearest to [p].
  static Pt? nearestOn(Entity e, Pt p) {
    if (e is CircleEntity) return e.center + (p - e.center).normalized * e.radius;
    final pts = e.linearPoints;
    if (pts == null || pts.length < 2) return null;
    if (e.isClosedShape) return polylineStationOf([...pts, pts.first], p).$2;
    return polylineStationOf(pts, p).$2;
  }

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (_target == null) {
      final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
      if (hit == null || hit is AreaEntity || hit is HatchEntity || hit is RevisionCloudEntity) return;
      final at = nearestOn(hit, p);
      if (at == null) return;
      _target = hit.id;
      _first = at;
      c.select([hit.id]);
      return;
    }
    final e = c.project.byId(_target!);
    final second = e == null ? null : nearestOn(e, p);
    if (second != null && c.breakBetween(_target!, _first!, second)) c.notify(c.t('edt.broken'));
    cancel();
  }

  @override
  void onKey(String key) {
    if (key == 'Escape') cancel();
  }

  @override
  void cancel() {
    _target = null;
    _first = null;
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final e = _target == null ? null : c.project.byId(_target!);
    final first = _first;
    if (e == null || first == null) return;
    final mark = Paint()
      ..color = Cad.hover
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(cam.toScreen(first), 5, mark);
    final second = cursor == null ? null : nearestOn(e, cursor!);
    if (second != null) {
      canvas.drawCircle(cam.toScreen(second), 5, mark);
      canvas.drawLine(cam.toScreen(first), cam.toScreen(second), previewPaint);
    }
    host.setStatus(c.t('edt.breakSecond'));
  }
}
