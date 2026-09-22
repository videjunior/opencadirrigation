import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import '../../core/design/pivot.dart' show PivotKind;

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../canvas/camera.dart';
import '../state/controller.dart';
import '../theme.dart';

/// Dialog requests raised by tools and fulfilled by the widget layer.
abstract class ToolHost {
  void showBlockDialog(List<Pt> polygon);
  void showAutoheadDialog(List<Pt> polygon);
  void showTextDialog(Pt position);
  void showLeaderDialog(List<Pt> points);
  void setStatus(String text);

  /// Asks the elevation of a contour / spot height that was just drawn.
  void promptElevation(Entity e);
}

abstract class Tool {
  Tool(this.c, this.host);
  final ProjectController c;
  final ToolHost host;
  ToolId get id;
  String get hintKey;
  Pt? cursor;
  bool get usesSnap => true;
  Pt? get referencePoint => null;

  /// Vector from the geometry being dragged to the pointer, measured when it
  /// was grabbed. When it is set the canvas snaps the dragged point itself
  /// instead of the cursor — the item lands on the pipe, not the mouse — and
  /// the point given to [onMove] / [onUp] is that snapped position.
  Pt? get snapOffset => null;

  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {}
  void onMove(Pt p, {bool dragging = false}) {
    cursor = p;
  }

  void onUp(Pt p) {}
  void onDoubleClick(Pt p) {}

  /// key: 'Escape', 'Enter', 'Backspace'
  void onKey(String key) {}
  void paint(Canvas canvas, Camera cam) {}
  void cancel() {}

  Paint get previewPaint => Paint()
    ..color = CadColors.preview
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  void drawPolyline(Canvas canvas, Camera cam, List<Pt> pts, Paint paint, {bool close = false}) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(cam.toScreen(pts.first).dx, cam.toScreen(pts.first).dy);
    for (final p in pts.skip(1)) {
      final s = cam.toScreen(p);
      path.lineTo(s.dx, s.dy);
    }
    if (close) path.close();
    canvas.drawPath(path, paint);
  }

  /// Ghost of the selected entities under the transform [t].
  void paintTransformed(Canvas canvas, Camera cam, Affine t) {
    final paint = Paint()
      ..color = CadColors.selection.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    var n = 0;
    for (final e in c.project.entities) {
      if (!c.selection.contains(e.id)) continue;
      if (++n > 400) break;
      final pts = e.linearPoints;
      if (pts != null && pts.length >= 2) {
        drawPolyline(canvas, cam, pts.map(t.apply).toList(), paint, close: e.isClosedShape);
      } else if (e is CircleEntity) {
        canvas.drawCircle(cam.toScreen(t.apply(e.center)), e.radius * t.scale * cam.scale, paint);
      } else if (e is PointEntity) {
        final o = cam.toScreen(t.apply(e.position));
        canvas.drawCircle(o, 4, paint);
      } else {
        final b = e.bounds;
        final corners = [Pt(b.minX, b.minY), Pt(b.maxX, b.minY), Pt(b.maxX, b.maxY), Pt(b.minX, b.maxY)].map(t.apply).toList();
        drawPolyline(canvas, cam, corners, paint, close: true);
      }
    }
  }

  String fmtLen(double v) => '${c.units.lengthFromSi(v).toStringAsFixed(2)} ${c.units.lengthLabel}';
}

// ---------------------------------------------------------------- select (with grips)

class GripHandle {
  const GripHandle(this.entityId, this.index, this.p, {this.midpoint = false});
  final String entityId;
  final int index;
  final Pt p;

  /// Midpoint handle: dragging it inserts a vertex at [index].
  final bool midpoint;
}

class SelectTool extends Tool {
  SelectTool(super.c, super.host);
  @override
  ToolId get id => ToolId.select;
  @override
  String get hintKey => 'hint.select';
  @override
  bool get usesSnap => _dragged && (_moving || _grip != null);

  @override
  Pt? get snapOffset => _dragged ? _grabOffset : null;

  Pt? _downRaw;
  Pt? _dragCurrent;
  bool _moving = false;
  bool _windowing = false;
  bool _shift = false;
  Pt? _moveStart;
  GripHandle? _grip;
  Pt? _gripPos;

  /// The pointer left the dead zone around the press (see the drag threshold
  /// in the canvas): until then a press only selects, it never edits.
  bool _dragged = false;

  /// A midpoint grip was pressed: the vertex is only inserted once the drag
  /// really starts, so clicking one does not change the polyline.
  bool _pendingInsert = false;

  /// Pointer minus the dragged point when it was grabbed, and the dragged
  /// point itself: the snap then follows the item / node instead of the
  /// cursor, so it lands exactly on the pipe it is dropped over.
  Pt? _grabOffset;
  Pt? _moveAnchor;

  static const maxGripEntities = 12;

  /// Grips of the current selection (world coordinates).
  List<GripHandle> grips() {
    if (!c.showGrips || c.selection.isEmpty || c.selection.length > maxGripEntities) return const [];
    final out = <GripHandle>[];
    for (final e in c.project.entities) {
      if (!c.selection.contains(e.id) || c.project.isLocked(e.layer)) continue;
      final g = e.grips;
      for (var i = 0; i < g.length; i++) {
        out.add(GripHandle(e.id, i, g[i]));
      }
      if (e is PolyEntity && e is! ImageEntity) {
        final pts = e.points;
        final n = pts.length + (e.isClosedShape ? 1 : 0);
        for (var i = 1; i < n; i++) {
          out.add(GripHandle(e.id, i, Pt.lerp(pts[i - 1], pts[i % pts.length], 0.5), midpoint: true));
        }
      }
    }
    return out;
  }

  GripHandle? _hitGrip(Pt p) {
    final tol = c.snap.tolerancePx / c.camera.scale;
    GripHandle? best;
    var bestD = double.infinity;
    for (final g in grips()) {
      final d = g.p.distanceTo(p);
      final dd = g.midpoint ? d * 1.5 : d;
      if (d <= tol && dd < bestD) {
        best = g;
        bestD = dd;
      }
    }
    return best;
  }

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    _shift = shift;
    _downRaw = p;
    _dragCurrent = p;
    _dragged = false;
    _pendingInsert = false;
    _grabOffset = null;
    _moveAnchor = null;
    final grip = _hitGrip(p);
    if (grip != null) {
      if (ctrl && !grip.midpoint) {
        c.removeVertex(grip.entityId, grip.index);
        _grip = null;
        return;
      }
      _grip = grip.midpoint ? GripHandle(grip.entityId, grip.index, grip.p) : grip;
      _pendingInsert = grip.midpoint;
      _gripPos = grip.p;
      _grabOffset = p - grip.p;
      _moving = false;
      _windowing = false;
      return;
    }
    final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
    if (hit != null) {
      if (shift) {
        c.toggleSelect(hit.id);
      } else if (!c.selection.contains(hit.id)) {
        c.select([hit.id]);
      }
      _moving = c.selection.contains(hit.id) && !shift;
      _moveStart = p;
      _windowing = false;
      // a lone item (a sprinkler, a valve): the snap follows the item, so a
      // move drops it on the pipe under it instead of beside it
      if (_moving && c.selection.length == 1 && hit is PointEntity) {
        _moveAnchor = hit.position;
        _grabOffset = p - hit.position;
      }
    } else {
      _moving = false;
      _windowing = true;
      if (!shift) c.select(const []);
    }
  }

  @override
  void onMove(Pt p, {bool dragging = false}) {
    cursor = p;
    if (!dragging) return;
    if (!_dragged) {
      _dragged = true;
      if (_pendingInsert && _grip != null) {
        final g = _grip!;
        _pendingInsert = false;
        // the inserted vertex is the one that is dragged from now on
        if (!c.insertVertex(g.entityId, g.index, g.p)) _grip = null;
      }
    }
    _dragCurrent = p;
    if (_grip != null) _gripPos = p;
  }

  @override
  void onUp(Pt p) {
    if (_grip != null) {
      final g = _grip!;
      if (_dragged && g.p.distanceTo(p) > 1e-9) {
        final e = c.project.byId(g.entityId);
        c.setGrip(g.entityId, g.index, p, keepConnections: c.toolSettings.keepConnections && (e is PolyEntity || e is LineEntity));
      }
      _grip = null;
      _gripPos = null;
    } else if (_dragged && _moving && _moveStart != null) {
      final d = p - (_moveAnchor ?? _moveStart!);
      if (d.length > 1e-9) c.moveSelected(d);
    } else if (_windowing && _downRaw != null) {
      final a = _downRaw!, b = p;
      if (a.distanceTo(b) > c.snap.tolerancePx / c.camera.scale) {
        final bounds = Bounds(math.min(a.x, b.x), math.min(a.y, b.y), math.max(a.x, b.x), math.max(a.y, b.y));
        final crossing = b.x < a.x; // right-to-left = crossing (AutoCAD convention)
        final ids = c.pickWindow(bounds, crossing: crossing).map((e) => e.id);
        c.select(ids, add: _shift);
      }
    }
    _moving = false;
    _windowing = false;
    _downRaw = null;
    _dragCurrent = null;
    _moveStart = null;
    _moveAnchor = null;
    _grabOffset = null;
    _pendingInsert = false;
    _dragged = false;
  }

  @override
  void onKey(String key) {
    if (key == 'Escape') c.select(const []);
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    if (_windowing && _downRaw != null && _dragCurrent != null) {
      final a = cam.toScreen(_downRaw!), b = cam.toScreen(_dragCurrent!);
      final r = Rect.fromPoints(a, b);
      final crossing = _dragCurrent!.x < _downRaw!.x;
      canvas.drawRect(r, Paint()..color = (crossing ? CadColors.ok : CadColors.selection).withValues(alpha: 0.12));
      canvas.drawRect(r, Paint()
        ..color = crossing ? CadColors.ok : CadColors.selection
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
    if (_dragged && _moving && _moveStart != null && _dragCurrent != null) {
      final d = _dragCurrent! - (_moveAnchor ?? _moveStart!);
      paintTransformed(canvas, cam, Affine.translation(d));
    }
    // grips
    final gs = grips();
    if (gs.isNotEmpty) {
      final fill = Paint()..color = CadColors.selection;
      final mid = Paint()
        ..color = CadColors.selection.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final g in gs) {
        final o = cam.toScreen(g.p);
        if (g.midpoint) {
          canvas.drawRect(Rect.fromCenter(center: o, width: 6, height: 6), mid);
        } else {
          canvas.drawRect(Rect.fromCenter(center: o, width: 8, height: 8), fill);
        }
      }
    }
    if (_grip != null && _gripPos != null) {
      final g = _grip!;
      final e = c.project.byId(g.entityId);
      final o = cam.toScreen(_gripPos!);
      final p = Paint()
        ..color = CadColors.hover
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      if (e is PolyEntity) {
        final pts = e.points;
        if (g.index > 0) canvas.drawLine(cam.toScreen(pts[g.index - 1]), o, p);
        if (g.index < pts.length - 1) canvas.drawLine(cam.toScreen(pts[g.index + 1]), o, p);
      } else if (e is LineEntity) {
        canvas.drawLine(cam.toScreen(g.index == 0 ? e.b : e.a), o, p);
      }
      canvas.drawRect(Rect.fromCenter(center: o, width: 9, height: 9), p);
      host.setStatus('X ${fmtLen(_gripPos!.x)}  Y ${fmtLen(_gripPos!.y)}');
    }
  }
}

class PanTool extends Tool {
  PanTool(super.c, super.host);
  @override
  ToolId get id => ToolId.pan;
  @override
  String get hintKey => 'hint.pan';
  @override
  bool get usesSnap => false;
}

// ---------------------------------------------------------------- polyline-based tools

abstract class PolyTool extends Tool {
  PolyTool(super.c, super.host);
  final List<Pt> pts = [];
  int get requiredPoints => 0; // 0 = until Enter
  bool get closes => false;

  @override
  Pt? get referencePoint => pts.isEmpty ? null : pts.last;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (pts.isNotEmpty && pts.last.distanceTo(p) < 1e-9) return;
    pts.add(p);
    if (requiredPoints > 0 && pts.length >= requiredPoints) finish();
  }

  @override
  void onDoubleClick(Pt p) {
    if (requiredPoints == 0) finish();
  }

  @override
  void onKey(String key) {
    if (key == 'Enter') finish();
    if (key == 'Escape') cancel();
    if (key == 'Backspace' && pts.isNotEmpty) pts.removeLast();
  }

  void finish() {
    if (pts.length >= minPoints) commit(List.of(pts));
    pts.clear();
  }

  int get minPoints => 2;
  void commit(List<Pt> points);

  @override
  void cancel() => pts.clear();

  @override
  void paint(Canvas canvas, Camera cam) {
    final preview = [...pts, ?cursor];
    drawPolyline(canvas, cam, preview, previewPaint, close: closes && preview.length > 2);
    if (pts.isNotEmpty && cursor != null) {
      final d = pts.last.distanceTo(cursor!);
      host.setStatus('d = ${c.units.lengthFromSi(d).toStringAsFixed(2)} ${c.units.lengthLabel}   L = ${c.units.lengthFromSi(polylineLength(preview)).toStringAsFixed(2)} ${c.units.lengthLabel}');
    }
  }
}

class LineTool extends PolyTool {
  LineTool(super.c, super.host);
  @override
  ToolId get id => ToolId.line;
  @override
  String get hintKey => 'hint.line';
  @override
  int get requiredPoints => 2;
  @override
  void commit(List<Pt> points) => c.addEntity(LineEntity(id: c.project.newId(), layer: c.drawingLayer, a: points[0], b: points[1]));
}

class PolylineTool extends PolyTool {
  PolylineTool(super.c, super.host);
  @override
  ToolId get id => ToolId.polyline;
  @override
  String get hintKey => 'hint.polyline';
  @override
  void commit(List<Pt> points) => c.addEntity(PolylineEntity(id: c.project.newId(), layer: c.drawingLayer, points: points));
}

class SplineTool extends PolyTool {
  SplineTool(super.c, super.host);
  @override
  ToolId get id => ToolId.spline;
  @override
  String get hintKey => 'hint.spline';
  @override
  void commit(List<Pt> points) => c.addEntity(SplineEntity(id: c.project.newId(), layer: c.drawingLayer, points: points, closed: c.toolSettings.splineClosed));
  @override
  void paint(Canvas canvas, Camera cam) {
    final preview = [...pts, ?cursor];
    if (preview.length >= 3) {
      drawPolyline(canvas, cam, catmullRom(preview, closed: c.toolSettings.splineClosed && preview.length > 2), previewPaint);
    } else {
      drawPolyline(canvas, cam, preview, previewPaint);
    }
  }
}

class HatchTool extends PolyTool {
  HatchTool(super.c, super.host);
  @override
  ToolId get id => ToolId.hatch;
  @override
  String get hintKey => 'hint.hatch';
  @override
  bool get closes => true;
  @override
  int get minPoints => 3;
  @override
  void commit(List<Pt> points) {
    final s = c.toolSettings;
    c.addEntity(HatchEntity(id: c.project.newId(), layer: c.drawingLayer == Layers.drawing ? Layers.hatches : c.drawingLayer, points: points, angleDeg: s.hatchAngle, spacing: s.hatchSpacing, solid: s.hatchSolid));
  }
}

class RectTool extends PolyTool {
  RectTool(super.c, super.host);
  @override
  ToolId get id => ToolId.rect;
  @override
  String get hintKey => 'hint.rect';
  @override
  int get requiredPoints => 2;
  List<Pt> _corners(Pt a, Pt b) => [a, Pt(b.x, a.y), b, Pt(a.x, b.y)];
  @override
  void commit(List<Pt> points) => c.addEntity(PolylineEntity(id: c.project.newId(), layer: c.drawingLayer, points: _corners(points[0], points[1]), closed: true));
  @override
  void paint(Canvas canvas, Camera cam) {
    if (pts.length == 1 && cursor != null) {
      drawPolyline(canvas, cam, _corners(pts[0], cursor!), previewPaint, close: true);
      final w = (cursor!.x - pts[0].x).abs(), h = (cursor!.y - pts[0].y).abs();
      host.setStatus('${c.units.lengthFromSi(w).toStringAsFixed(2)} × ${c.units.lengthFromSi(h).toStringAsFixed(2)} ${c.units.lengthLabel}');
    }
  }
}

class CircleTool extends PolyTool {
  CircleTool(super.c, super.host);
  @override
  ToolId get id => ToolId.circle;
  @override
  String get hintKey => 'hint.circle';
  @override
  int get requiredPoints => 2;
  @override
  void commit(List<Pt> points) => c.addEntity(CircleEntity(id: c.project.newId(), layer: c.drawingLayer, center: points[0], radius: points[0].distanceTo(points[1])));
  @override
  void paint(Canvas canvas, Camera cam) {
    if (pts.length == 1 && cursor != null) {
      final r = pts[0].distanceTo(cursor!);
      canvas.drawCircle(cam.toScreen(pts[0]), r * cam.scale, previewPaint);
      host.setStatus('R = ${c.units.lengthFromSi(r).toStringAsFixed(2)} ${c.units.lengthLabel}');
    }
  }
}

/// Arc through three points (start, a point on the arc, end).
class ArcTool extends PolyTool {
  ArcTool(super.c, super.host);
  @override
  ToolId get id => ToolId.arc;
  @override
  String get hintKey => 'hint.arc';
  @override
  int get requiredPoints => 3;
  @override
  int get minPoints => 3;
  @override
  void commit(List<Pt> points) {
    final a = arcThrough(points[0], points[1], points[2]);
    if (a == null) {
      c.addEntity(PolylineEntity(id: c.project.newId(), layer: c.drawingLayer, points: points));
      return;
    }
    c.addEntity(ArcEntity(id: c.project.newId(), layer: c.drawingLayer, center: a.$1, radius: a.$2, startRad: a.$3, sweepRad: a.$4));
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final preview = [...pts, ?cursor];
    if (preview.length == 3) {
      final a = arcThrough(preview[0], preview[1], preview[2]);
      if (a != null) {
        final arc = ArcEntity(id: '', center: a.$1, radius: a.$2, startRad: a.$3, sweepRad: a.$4);
        drawPolyline(canvas, cam, arc.polyline(64), previewPaint);
        host.setStatus('R = ${fmtLen(a.$2)}  L = ${fmtLen(arc.length)}');
        return;
      }
    }
    drawPolyline(canvas, cam, preview, previewPaint);
  }
}

class DimensionTool extends PolyTool {
  DimensionTool(super.c, super.host);
  @override
  ToolId get id => ToolId.dimension;
  @override
  String get hintKey => 'hint.dimension';
  @override
  int get requiredPoints => 3;
  @override
  int get minPoints => 3;
  @override
  void commit(List<Pt> points) {
    final n = (points[1] - points[0]).normalized.perpendicular;
    final off = (points[2] - points[0]).dot(n);
    c.addEntity(DimensionEntity(id: c.project.newId(), a: points[0], b: points[1], offset: off));
  }
}

/// Angular dimension: vertex, first ray point, second ray point, arc position.
class AngularDimensionTool extends PolyTool {
  AngularDimensionTool(super.c, super.host);
  @override
  ToolId get id => ToolId.dimAngular;
  @override
  String get hintKey => 'hint.dimAngular';
  @override
  int get requiredPoints => 4;
  @override
  int get minPoints => 4;
  @override
  void commit(List<Pt> points) => c.addEntity(orientedAngularDimension(c.project.newId(), points[0], points[1], points[2], points[3], math.max(0.1, points[0].distanceTo(points[3]))));

  /// Builds the dimension so that the arc passes through [side] (the fourth
  /// click): the sector is swapped when that point lies outside the
  /// counter-clockwise sweep from [a] to [b].
  static AngularDimensionEntity orientedAngularDimension(String id, Pt vertex, Pt a, Pt b, Pt side, double radius) {
    final d = AngularDimensionEntity(id: id, vertex: vertex, a: a, b: b, radius: radius);
    var t = ((side - vertex).angle - d.startRad) % (2 * math.pi);
    if (t < 0) t += 2 * math.pi;
    if (t > d.sweepRad) return AngularDimensionEntity(id: id, vertex: vertex, a: b, b: a, radius: radius);
    return d;
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    final preview = [...pts, ?cursor];
    if (preview.length >= 3) {
      final r = preview.length == 4 ? preview[0].distanceTo(preview[3]) : c.toolSettings.angularDimRadius;
      final d = preview.length == 4 ? orientedAngularDimension('', preview[0], preview[1], preview[2], preview[3], math.max(0.1, r)) : AngularDimensionEntity(id: '', vertex: preview[0], a: preview[1], b: preview[2], radius: math.max(0.1, r));
      drawPolyline(canvas, cam, [preview[1], preview[0], preview[2]], previewPaint);
      drawPolyline(canvas, cam, d.arcPoints(), previewPaint);
      host.setStatus('${d.angleDeg.toStringAsFixed(1)}°');
      return;
    }
    drawPolyline(canvas, cam, preview, previewPaint);
  }
}

/// Radius dimension: click a circle/arc (or its centre) then a point on it.
class RadialDimensionTool extends PolyTool {
  RadialDimensionTool(super.c, super.host);
  @override
  ToolId get id => ToolId.dimRadial;
  @override
  String get hintKey => 'hint.dimRadial';
  @override
  int get requiredPoints => 2;
  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (pts.isEmpty) {
      final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
      if (hit is CircleEntity) {
        pts.add(hit.center);
        return;
      }
      if (hit is ArcEntity) {
        pts.add(hit.center);
        return;
      }
    }
    super.onDown(p, shift: shift, ctrl: ctrl);
  }

  @override
  void commit(List<Pt> points) => c.addEntity(RadialDimensionEntity(id: c.project.newId(), center: points[0], point: points[1], diameter: c.toolSettings.radialDiameter));
  @override
  void paint(Canvas canvas, Camera cam) {
    if (c.toolSettings.radialDiameter && pts.length == 1 && cursor != null) {
      drawPolyline(canvas, cam, [pts[0] * 2 - cursor!, cursor!], previewPaint);
      host.setStatus('Ø = ${fmtLen(2 * pts[0].distanceTo(cursor!))}');
      return;
    }
    super.paint(canvas, cam);
    if (pts.length == 1 && cursor != null) host.setStatus('R = ${fmtLen(pts[0].distanceTo(cursor!))}');
  }
}

/// Ordinate dimension: click the feature point, then where the text goes.
/// A mostly vertical leader writes the X coordinate, a horizontal one the Y
/// (measured from the drawing origin).
class OrdinateDimensionTool extends PolyTool {
  OrdinateDimensionTool(super.c, super.host);
  @override
  ToolId get id => ToolId.dimOrdinate;
  @override
  String get hintKey => 'hint.dimOrdinate';
  @override
  int get requiredPoints => 2;

  static bool xAxisFor(Pt point, Pt end) => (end.y - point.y).abs() >= (end.x - point.x).abs();

  @override
  void commit(List<Pt> points) => c.addEntity(OrdinateDimensionEntity(id: c.project.newId(), point: points[0], leaderEnd: points[1], xAxis: xAxisFor(points[0], points[1])));
  @override
  void paint(Canvas canvas, Camera cam) {
    if (pts.length == 1 && cursor != null) {
      final d = OrdinateDimensionEntity(id: '', point: pts[0], leaderEnd: cursor!, xAxis: xAxisFor(pts[0], cursor!));
      drawPolyline(canvas, cam, d.leader, previewPaint);
      host.setStatus('${d.xAxis ? 'X' : 'Y'} = ${fmtLen(d.value)}');
      return;
    }
    super.paint(canvas, cam);
  }
}

/// Leader: arrow polyline, then a text dialog.
class LeaderTool extends PolyTool {
  LeaderTool(super.c, super.host);
  @override
  ToolId get id => ToolId.leader;
  @override
  String get hintKey => 'hint.leader';
  @override
  void commit(List<Pt> points) => host.showLeaderDialog(points);
}

class ContourTool extends PolyTool {
  ContourTool(super.c, super.host);
  @override
  ToolId get id => ToolId.contour;
  @override
  String get hintKey => 'hint.contour';
  @override
  void commit(List<Pt> points) {
    final s = c.toolSettings;
    final pts = s.contourSmooth && points.length >= 3 ? catmullRom(points, segments: 6) : points;
    final e = ContourEntity(id: c.project.newId(), points: pts, elevation: s.contourElevation);
    c.addEntity(e);
    if (s.askElevation) {
      host.promptElevation(e);
    } else if (s.contourAutoIncrement) {
      s.contourElevation += s.contourInterval;
    }
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    super.paint(canvas, cam);
    if (pts.isNotEmpty) {
      final o = cam.toScreen(pts.first);
      final tp = TextPainter(text: TextSpan(text: '${c.toolSettings.contourElevation.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 11, color: CadColors.preview)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o + const Offset(6, -16));
    }
  }
}

class AreaTool extends PolyTool {
  AreaTool(super.c, super.host);
  @override
  ToolId get id => ToolId.area;
  @override
  String get hintKey => 'hint.area';
  @override
  bool get closes => true;
  @override
  int get minPoints => 3;
  @override
  void commit(List<Pt> points) => c.addEntity(AreaEntity(id: c.project.newId(), points: points, name: '${c.t('name.area')} ${c.project.entities.whereType<AreaEntity>().length + 1}'));
}

class PipeTool extends PolyTool {
  PipeTool(super.c, super.host, this.scope);
  final HydraulicScope scope;
  @override
  ToolId get id => scope == HydraulicScope.zone ? ToolId.zonePipe : ToolId.mainPipe;
  @override
  String get hintKey => 'hint.pipe';
  @override
  void commit(List<Pt> points) {
    final spec = scope == HydraulicScope.zone ? c.toolSettings.zonePipeSpecId : c.toolSettings.mainPipeSpecId;
    c.addEntity(PipeEntity(id: c.project.newId(), points: points, scope: scope, pipeSpecId: spec, computerSized: spec == null));
  }
}

class SpraylineTool extends PolyTool {
  SpraylineTool(super.c, super.host);
  @override
  ToolId get id => ToolId.sprayline;
  @override
  String get hintKey => 'hint.pipe';
  @override
  void commit(List<Pt> points) {
    final s = c.toolSettings;
    c.addEntity(SpraylineEntity(id: c.project.newId(), points: points, pipeSpecId: s.lateralPipeSpecId, computerSized: s.lateralPipeSpecId == null, outletSpecId: s.outletSpecId, nozzleId: s.nozzleId, headM: s.headM, spacing: s.spacing, offset: s.outletOffsetHalf ? s.spacing / 2 : s.offset, arcDeg: s.arcDeg));
  }
}

class TapeTool extends PolyTool {
  TapeTool(super.c, super.host);
  @override
  ToolId get id => ToolId.tape;
  @override
  String get hintKey => 'hint.pipe';
  @override
  void commit(List<Pt> points) {
    final s = c.toolSettings;
    c.addEntity(TapeEntity(id: c.project.newId(), points: points, tapeSpecId: s.tapeSpecId, inletHeadM: s.tapeInletHeadM));
  }
}

class BlockTool extends PolyTool {
  BlockTool(super.c, super.host);
  @override
  ToolId get id => ToolId.block;
  @override
  String get hintKey => 'hint.block';
  @override
  bool get closes => true;
  @override
  int get minPoints => 3;
  @override
  void commit(List<Pt> points) => host.showBlockDialog(points);
}

class AutoheadTool extends PolyTool {
  AutoheadTool(super.c, super.host);
  @override
  ToolId get id => ToolId.autohead;
  @override
  String get hintKey => 'hint.block';
  @override
  bool get closes => true;
  @override
  int get minPoints => 3;
  @override
  void commit(List<Pt> points) => host.showAutoheadDialog(points);
}

class MeasureTool extends PolyTool {
  MeasureTool(super.c, super.host);
  @override
  ToolId get id => ToolId.measure;
  @override
  String get hintKey => 'hint.measure';
  @override
  int get requiredPoints => 2;
  @override
  void commit(List<Pt> points) {
    final d = points[0].distanceTo(points[1]);
    final dx = points[1].x - points[0].x, dy = points[1].y - points[0].y;
    host.setStatus('Δ = ${c.units.lengthFromSi(d).toStringAsFixed(3)} ${c.units.lengthLabel}  (Δx ${c.units.lengthFromSi(dx).toStringAsFixed(2)}, Δy ${c.units.lengthFromSi(dy).toStringAsFixed(2)}, ${radToDeg(math.atan2(dy, dx)).toStringAsFixed(1)}°)');
  }
}

/// Elevation profile along a clicked path (Reports → Profile).
class ProfileTool extends PolyTool {
  ProfileTool(super.c, super.host);
  @override
  ToolId get id => ToolId.profile;
  @override
  String get hintKey => 'hint.profile';
  @override
  void commit(List<Pt> points) => c.setProfilePath(points);

  /// Esc with no point started clears the profile shown on the drawing.
  @override
  void onKey(String key) {
    if (key == 'Escape' && pts.isEmpty && c.profilePath != null) {
      c.clearProfile();
      return;
    }
    super.onKey(key);
  }
}

// ---------------------------------------------------------------- editing tools

/// Base for tools that act on the current selection with a few clicks.
abstract class TransformTool extends Tool {
  TransformTool(super.c, super.host);
  final List<Pt> pts = [];
  bool _ctrl = false;
  @override
  Pt? get referencePoint => pts.isEmpty ? null : pts.first;

  int get clicks;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    _ctrl = ctrl;
    if (c.selection.isEmpty) {
      // nothing selected: pick like the select tool
      final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
      if (hit != null) c.select([hit.id]);
      return;
    }
    pts.add(p);
    if (pts.length >= clicks) {
      apply(List.of(pts), copy: _ctrl || c.toolSettings.copyOnTransform);
      pts.clear();
    }
  }

  void apply(List<Pt> points, {required bool copy});

  /// Transform previewed for the current points + cursor (null = none).
  Affine? preview();

  @override
  void onKey(String key) {
    if (key == 'Escape') cancel();
    if (key == 'Backspace' && pts.isNotEmpty) pts.removeLast();
  }

  @override
  void cancel() => pts.clear();

  @override
  void paint(Canvas canvas, Camera cam) {
    final t = preview();
    if (t != null) paintTransformed(canvas, cam, t);
    if (pts.isNotEmpty) {
      final o = cam.toScreen(pts.first);
      canvas.drawCircle(o, 4, previewPaint);
      if (cursor != null) canvas.drawLine(o, cam.toScreen(cursor!), previewPaint);
    }
  }
}

/// Rotate: base point, reference point, target point (angle between them).
class RotateTool extends TransformTool {
  RotateTool(super.c, super.host);
  @override
  ToolId get id => ToolId.rotate;
  @override
  String get hintKey => 'hint.rotate';
  @override
  int get clicks => 3;

  double _angle(List<Pt> p) => (p[2] - p[0]).angle - (p[1] - p[0]).angle;

  @override
  void apply(List<Pt> points, {required bool copy}) {
    final a = _angle(points);
    if (a.abs() < 1e-9) return;
    c.rotateSelected(points[0], a, copy: copy);
  }

  @override
  Affine? preview() {
    if (pts.length == 2 && cursor != null) {
      final a = _angle([pts[0], pts[1], cursor!]);
      host.setStatus('${radToDeg(a).toStringAsFixed(2)}°');
      return Affine.rotation(a, pts[0]);
    }
    return null;
  }
}

/// Scale: base point, reference point, target point (ratio of distances).
class ScaleTool extends TransformTool {
  ScaleTool(super.c, super.host);
  @override
  ToolId get id => ToolId.scale;
  @override
  String get hintKey => 'hint.scale';
  @override
  int get clicks => 3;

  double _factor(List<Pt> p) {
    final r = p[0].distanceTo(p[1]);
    return r < 1e-9 ? 1 : p[0].distanceTo(p[2]) / r;
  }

  @override
  void apply(List<Pt> points, {required bool copy}) {
    final f = _factor(points);
    if ((f - 1).abs() < 1e-9 || f <= 0) return;
    c.scaleSelected(points[0], f, copy: copy);
  }

  @override
  Affine? preview() {
    if (pts.length == 2 && cursor != null) {
      final f = _factor([pts[0], pts[1], cursor!]);
      host.setStatus('× ${f.toStringAsFixed(3)}');
      return Affine.scaling(f, pts[0]);
    }
    return null;
  }
}

/// Mirror about the line through two points; keeps the source by default.
class MirrorTool extends TransformTool {
  MirrorTool(super.c, super.host);
  @override
  ToolId get id => ToolId.mirror;
  @override
  String get hintKey => 'hint.mirror';
  @override
  int get clicks => 2;
  @override
  void apply(List<Pt> points, {required bool copy}) {
    if (points[0].distanceTo(points[1]) < 1e-9) return;
    c.mirrorSelected(points[0], points[1], keepSource: c.toolSettings.mirrorKeepSource);
  }

  @override
  Affine? preview() {
    if (pts.length == 1 && cursor != null && pts[0].distanceTo(cursor!) > 1e-9) return Affine.mirror(pts[0], cursor!);
    return null;
  }
}

/// Offset: pick an entity, then click the side; distance from the settings.
class OffsetTool extends Tool {
  OffsetTool(super.c, super.host);
  @override
  ToolId get id => ToolId.offset;
  @override
  String get hintKey => 'hint.offset';
  String? _target;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (_target == null) {
      final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
      if (hit != null && (hit.linearPoints != null || hit is CircleEntity)) {
        _target = hit.id;
        c.select([hit.id]);
      }
      return;
    }
    c.offsetEntityTo(_target!, c.toolSettings.offsetDistance, p);
    _target = null;
  }

  @override
  void onKey(String key) {
    if (key == 'Escape') cancel();
  }

  @override
  void cancel() => _target = null;

  @override
  void paint(Canvas canvas, Camera cam) {
    if (_target == null || cursor == null) return;
    final e = c.project.byId(_target!);
    if (e == null) return;
    final d = c.toolSettings.offsetDistance;
    Pt side = cursor!;
    Entity? ghost;
    if (e is CircleEntity) {
      ghost = CircleEntity(id: '', center: e.center, radius: math.max(1e-6, e.radius + (side.distanceTo(e.center) > e.radius ? d : -d)));
      canvas.drawCircle(cam.toScreen(e.center), (ghost as CircleEntity).radius * cam.scale, previewPaint);
      return;
    }
    final pts = e.linearPoints!;
    var best = double.infinity;
    var sign = 1.0;
    final n = pts.length + (e.isClosedShape ? 1 : 0);
    for (var i = 1; i < n; i++) {
      final a = pts[i - 1], b = pts[i % pts.length];
      final dist = distanceToSegment(side, a, b);
      if (dist < best) {
        best = dist;
        sign = (b - a).cross(side - a) >= 0 ? 1 : -1;
      }
    }
    final off = offsetPolyline(e.isClosedShape ? [pts.last, ...pts, pts.first] : pts, sign * d);
    drawPolyline(canvas, cam, e.isClosedShape ? off.sublist(1, off.length - 1) : off, previewPaint, close: e.isClosedShape);
    host.setStatus('${c.t('tool.offset')}: ${fmtLen(d)}');
  }
}

/// Trim: click the part of a line/polyline to remove (cut by the selected
/// edges, or by every crossing entity when nothing is selected).
class TrimTool extends Tool {
  TrimTool(super.c, super.host);
  @override
  ToolId get id => ToolId.trim;
  @override
  String get hintKey => 'hint.trim';
  @override
  bool get usesSnap => false;
  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
    if (hit == null || hit.linearPoints == null || hit.isClosedShape) return;
    if (shift) {
      c.toggleSelect(hit.id);
      return;
    }
    if (!c.trimAt(hit.id, p)) c.notify(c.t('msg.noIntersection'));
  }
}

/// Extend: click near the end of a line/polyline to extend it to the
/// selected edges (or to any crossing entity).
class ExtendTool extends Tool {
  ExtendTool(super.c, super.host);
  @override
  ToolId get id => ToolId.extend;
  @override
  String get hintKey => 'hint.extend';
  @override
  bool get usesSnap => false;
  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
    if (hit == null || hit.linearPoints == null || hit.isClosedShape) return;
    if (shift) {
      c.toggleSelect(hit.id);
      return;
    }
    if (!c.extendAt(hit.id, p)) c.notify(c.t('msg.noIntersection'));
  }
}

/// Cut pipe: splits a pipe, lateral or line at the clicked point.
class CutPipeTool extends Tool {
  CutPipeTool(super.c, super.host);
  @override
  ToolId get id => ToolId.cutPipe;
  @override
  String get hintKey => 'hint.cutPipe';
  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final hit = c.pick(p, c.snap.tolerancePx / c.camera.scale);
    if (hit == null || hit.linearPoints == null || hit.isClosedShape) return;
    if (c.cutAt(hit.id, p)) c.notify(c.t('msg.pipeCut'));
  }

  @override
  void paint(Canvas canvas, Camera cam) {
    if (cursor == null) return;
    final o = cam.toScreen(cursor!);
    canvas.drawLine(o + const Offset(-6, -6), o + const Offset(6, 6), previewPaint);
    canvas.drawLine(o + const Offset(-6, 6), o + const Offset(6, -6), previewPaint);
  }
}

// ---------------------------------------------------------------- point tools

abstract class PointTool extends Tool {
  PointTool(super.c, super.host);
  @override
  String get hintKey => 'hint.point';
  Entity create(Pt p);

  /// Scopes of the pipes split under the item (null = plain add).
  Iterable<HydraulicScope>? splitScopes(Entity e) => null;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final e = create(p);
    final scopes = splitScopes(e);
    if (scopes == null) {
      c.addEntity(e);
    } else {
      c.addPointItem(e, p, scopes: scopes);
    }
  }

  double get symbolRadius => 0.6;

  @override
  void paint(Canvas canvas, Camera cam) {
    if (cursor == null) return;
    canvas.drawCircle(cam.toScreen(cursor!), math.max(4, symbolRadius * cam.scale), previewPaint);
  }
}

class TextTool extends PointTool {
  TextTool(super.c, super.host);
  @override
  ToolId get id => ToolId.text;
  @override
  String get hintKey => 'hint.text';
  @override
  Entity create(Pt p) => TextEntity(id: c.project.newId(), position: p, text: c.toolSettings.text, height: c.toolSettings.textHeight);
  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) => host.showTextDialog(p);
}

class SymbolTool extends PointTool {
  SymbolTool(super.c, super.host);
  @override
  ToolId get id => ToolId.symbol;
  @override
  String get hintKey => 'hint.symbol';
  @override
  Entity create(Pt p) => SymbolEntity(id: c.project.newId(), layer: c.drawingLayer == Layers.drawing ? Layers.symbols : c.drawingLayer, position: p, kind: c.toolSettings.symbolKind, size: c.toolSettings.symbolSize);
  @override
  void paint(Canvas canvas, Camera cam) {
    if (cursor == null) return;
    final s = SymbolEntity(id: '', position: cursor!, kind: c.toolSettings.symbolKind, size: c.toolSettings.symbolSize);
    for (final stroke in s.strokes()) {
      drawPolyline(canvas, cam, stroke, previewPaint);
    }
  }
}

class SpotTool extends PointTool {
  SpotTool(super.c, super.host);
  @override
  ToolId get id => ToolId.spot;
  @override
  String get hintKey => 'hint.spot';
  @override
  Entity create(Pt p) => SpotHeightEntity(id: c.project.newId(), position: p, elevation: c.toolSettings.spotElevation);
  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    final e = create(p);
    c.addEntity(e);
    if (c.toolSettings.askElevation) host.promptElevation(e);
  }
}

class OutletTool extends PointTool {
  OutletTool(super.c, super.host);
  @override
  ToolId get id => ToolId.outlet;
  @override
  Entity create(Pt p) {
    final s = c.toolSettings;
    return OutletEntity(id: c.project.newId(), position: p, scope: s.pointScope, outletSpecId: s.outletSpecId, nozzleId: s.nozzleId, headM: s.headM, arcDeg: s.arcDeg);
  }
}

class ValveTool extends PointTool {
  ValveTool(super.c, super.host);
  @override
  ToolId get id => ToolId.valve;
  @override
  Entity create(Pt p) {
    final name = c.project.uniqueZoneName(c.t('name.zone'));
    return ControlValveEntity(id: c.project.newId(), name: name, position: p, valveSpecId: c.toolSettings.valveSpecId, zoneName: name);
  }

  @override
  Iterable<HydraulicScope>? splitScopes(Entity e) => HydraulicScope.values;
}

class SupplyTool extends PointTool {
  SupplyTool(super.c, super.host);
  @override
  ToolId get id => ToolId.supply;
  @override
  Entity create(Pt p) => WaterSupplyEntity(id: c.project.newId(), position: p, name: '${c.t('name.supply')} ${c.project.entities.whereType<WaterSupplyEntity>().length + 1}');
  @override
  double get symbolRadius => 1.2;
}

class PumpTool extends PointTool {
  PumpTool(super.c, super.host);
  @override
  ToolId get id => ToolId.pump;
  @override
  Entity create(Pt p) => PumpEntity(id: c.project.newId(), position: p, pumpSpecId: c.toolSettings.pumpSpecId, scope: c.toolSettings.pointScope == HydraulicScope.zone ? HydraulicScope.zone : HydraulicScope.mainline);
  @override
  Iterable<HydraulicScope>? splitScopes(Entity e) => [(e as PumpEntity).scope];
}

class MiscTool extends PointTool {
  MiscTool(super.c, super.host);
  @override
  ToolId get id => ToolId.misc;
  @override
  Entity create(Pt p) => MiscHydraulicEntity(id: c.project.newId(), position: p, valveSpecId: c.toolSettings.miscSpecId, scope: c.toolSettings.pointScope, settingM: c.toolSettings.miscSettingM);
  @override
  Iterable<HydraulicScope>? splitScopes(Entity e) => [(e as MiscHydraulicEntity).scope];
}

class JunctionTool extends PointTool {
  JunctionTool(super.c, super.host);
  @override
  ToolId get id => ToolId.junction;
  @override
  Entity create(Pt p) => JunctionEntity(id: c.project.newId(), position: p, scope: c.toolSettings.pointScope);
  @override
  Iterable<HydraulicScope>? splitScopes(Entity e) => [(e as JunctionEntity).scope];
}

/// Irrigation controller: one click places it (stations and output voltage
/// from the tool settings).
class ControllerTool extends PointTool {
  ControllerTool(super.c, super.host);
  @override
  ToolId get id => ToolId.controller;
  @override
  String get hintKey => 'hint.controller';
  @override
  Entity create(Pt p) {
    final n = c.project.entities.whereType<ControllerEntity>().length + 1;
    return ControllerEntity(id: c.project.newId(), position: p, name: '${c.t('name.controller')} $n', stations: c.toolSettings.controllerStations, outputVolts: c.toolSettings.controllerVolts);
  }

  @override
  double get symbolRadius => 1.0;
}

/// Wire route: a polyline from the controller through the valves (Enter or
/// a double click ends it); snaps to valves and controllers.
class WireTool extends PolyTool {
  WireTool(super.c, super.host);
  @override
  ToolId get id => ToolId.wire;
  @override
  String get hintKey => 'hint.wire';
  @override
  void commit(List<Pt> points) => c.addEntity(WireEntity(id: c.project.newId(), points: points));
}

/// Centre pivot / linear move: click the inlet (pivot point) then the end
/// of the span; the entity takes its defaults from the tool settings.
class PivotTool extends PolyTool {
  PivotTool(super.c, super.host);
  @override
  ToolId get id => ToolId.pivot;
  @override
  String get hintKey => 'hint.pivot';
  @override
  int get requiredPoints => 2;
  @override
  void commit(List<Pt> points) => c.addPivot(points[0], points[1]);

  @override
  void paint(Canvas canvas, Camera cam) {
    if (pts.isEmpty) {
      if (cursor != null) canvas.drawCircle(cam.toScreen(cursor!), 6, previewPaint);
      return;
    }
    final center = pts.first;
    final end = cursor ?? center;
    final r = center.distanceTo(end);
    canvas.drawLine(cam.toScreen(center), cam.toScreen(end), previewPaint);
    if (c.toolSettings.pivotKind == PivotKind.linear) {
      final along = end - center;
      final across = along.normalized.perpendicular * c.toolSettings.pivotTravelM;
      drawPolyline(canvas, cam, [center, end, end + across, center + across], previewPaint, close: true);
    } else if (r > 0) {
      canvas.drawCircle(cam.toScreen(center), r * cam.scale, previewPaint);
    }
    final n = c.toolSettings.pivotSpan > 0 ? (r / c.toolSettings.pivotSpan).floor() : 0;
    host.setStatus('R = ${fmtLen(r)}   ${c.t('rep.towers')} $n');
  }
}

/// Align the selection by two reference points (source A → target A,
/// source B → target B): similarity transform, optionally keeping the scale.
class AlignTool extends Tool {
  AlignTool(super.c, super.host);
  final List<Pt> pts = [];
  @override
  ToolId get id => ToolId.alignImage;
  @override
  String get hintKey => 'hint.alignImage';
  @override
  Pt? get referencePoint => pts.length.isOdd ? pts.last : null;

  static const _stepKeys = ['align.step1', 'align.step2', 'align.step3', 'align.step4'];

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    if (c.selection.isEmpty) {
      c.notify(c.t('msg.alignSelectFirst'));
      c.setTool(ToolId.select);
      return;
    }
    pts.add(p);
    if (pts.length < 4) {
      host.setStatus(c.t(_stepKeys[pts.length]));
      return;
    }
    final t = similarityFromPairs(pts[0], pts[2], pts[1], pts[3], keepScale: c.toolSettings.alignKeepScale);
    pts.clear();
    if (t == null) return;
    c.transformSelected(t, label: 'hist.align');
    c.track('align');
    c.notify(c.t('msg.alignDone', {'s': t.scale.toStringAsFixed(3), 'r': radToDeg(t.transformAngle(0)).toStringAsFixed(2)}));
    c.setTool(ToolId.select);
  }

  @override
  void onKey(String key) {
    if (key == 'Escape') cancel();
    if (key == 'Backspace' && pts.isNotEmpty) pts.removeLast();
  }

  @override
  void cancel() => pts.clear();

  @override
  void paint(Canvas canvas, Camera cam) {
    final p = previewPaint;
    for (var i = 0; i < pts.length; i++) {
      final o = cam.toScreen(pts[i]);
      canvas.drawCircle(o, 5, p);
      final tp = TextPainter(text: TextSpan(text: i.isEven ? (i == 0 ? 'A' : 'B') : (i == 1 ? "A'" : "B'"), style: const TextStyle(fontSize: 11, color: CadColors.preview)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o + const Offset(7, -14));
      if (i.isOdd) canvas.drawLine(cam.toScreen(pts[i - 1]), o, p);
    }
    if (pts.length.isOdd && cursor != null) canvas.drawLine(cam.toScreen(pts.last), cam.toScreen(cursor!), p);
    if (pts.isEmpty) host.setStatus(c.t(_stepKeys[0]));
  }
}

Tool createTool(ToolId id, ProjectController c, ToolHost host) => switch (id) {
  ToolId.select => SelectTool(c, host),
  ToolId.pan => PanTool(c, host),
  ToolId.line => LineTool(c, host),
  ToolId.polyline => PolylineTool(c, host),
  ToolId.rect => RectTool(c, host),
  ToolId.circle => CircleTool(c, host),
  ToolId.arc => ArcTool(c, host),
  ToolId.spline => SplineTool(c, host),
  ToolId.hatch => HatchTool(c, host),
  ToolId.symbol => SymbolTool(c, host),
  ToolId.text => TextTool(c, host),
  ToolId.dimension => DimensionTool(c, host),
  ToolId.dimAngular => AngularDimensionTool(c, host),
  ToolId.dimRadial => RadialDimensionTool(c, host),
  ToolId.leader => LeaderTool(c, host),
  ToolId.contour => ContourTool(c, host),
  ToolId.spot => SpotTool(c, host),
  ToolId.area => AreaTool(c, host),
  ToolId.zonePipe => PipeTool(c, host, HydraulicScope.zone),
  ToolId.mainPipe => PipeTool(c, host, HydraulicScope.mainline),
  ToolId.sprayline => SpraylineTool(c, host),
  ToolId.tape => TapeTool(c, host),
  ToolId.outlet => OutletTool(c, host),
  ToolId.valve => ValveTool(c, host),
  ToolId.supply => SupplyTool(c, host),
  ToolId.pump => PumpTool(c, host),
  ToolId.misc => MiscTool(c, host),
  ToolId.junction => JunctionTool(c, host),
  ToolId.block => BlockTool(c, host),
  ToolId.autohead => AutoheadTool(c, host),
  ToolId.measure => MeasureTool(c, host),
  ToolId.rotate => RotateTool(c, host),
  ToolId.mirror => MirrorTool(c, host),
  ToolId.scale => ScaleTool(c, host),
  ToolId.offset => OffsetTool(c, host),
  ToolId.trim => TrimTool(c, host),
  ToolId.extend => ExtendTool(c, host),
  ToolId.cutPipe => CutPipeTool(c, host),
  ToolId.profile => ProfileTool(c, host),
  ToolId.pivot => PivotTool(c, host),
  ToolId.alignImage => AlignTool(c, host),
  ToolId.controller => ControllerTool(c, host),
  ToolId.wire => WireTool(c, host),
  ToolId.dimOrdinate => OrdinateDimensionTool(c, host),
};

/// Hint key of a tool (status bar and properties panel).
String hintKeyOf(ToolId t) => switch (t) {
  ToolId.select => 'select',
  ToolId.pan => 'pan',
  ToolId.line => 'line',
  ToolId.polyline => 'polyline',
  ToolId.rect => 'rect',
  ToolId.circle => 'circle',
  ToolId.arc => 'arc',
  ToolId.spline => 'spline',
  ToolId.hatch => 'hatch',
  ToolId.symbol => 'symbol',
  ToolId.text => 'text',
  ToolId.dimension => 'dimension',
  ToolId.dimAngular => 'dimAngular',
  ToolId.dimRadial => 'dimRadial',
  ToolId.leader => 'leader',
  ToolId.contour => 'contour',
  ToolId.spot => 'spot',
  ToolId.area => 'area',
  ToolId.zonePipe || ToolId.mainPipe || ToolId.sprayline || ToolId.tape => 'pipe',
  ToolId.outlet || ToolId.valve || ToolId.supply || ToolId.pump || ToolId.misc || ToolId.junction => 'point',
  ToolId.block || ToolId.autohead => 'block',
  ToolId.measure => 'measure',
  ToolId.rotate => 'rotate',
  ToolId.mirror => 'mirror',
  ToolId.scale => 'scale',
  ToolId.offset => 'offset',
  ToolId.trim => 'trim',
  ToolId.extend => 'extend',
  ToolId.cutPipe => 'cutPipe',
  ToolId.profile => 'profile',
  ToolId.pivot => 'pivot',
  ToolId.alignImage => 'alignImage',
  ToolId.controller => 'controller',
  ToolId.wire => 'wire',
  ToolId.dimOrdinate => 'dimOrdinate',
};
