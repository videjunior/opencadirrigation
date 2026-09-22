import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/design/densogram.dart';
import '../../core/design/results.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import '../tools/tools.dart';
import 'basemap.dart';
import 'camera.dart';
import 'snapping.dart';

class CadPainter extends CustomPainter {
  CadPainter({required this.c, required this.tool, required this.snapResult, required this.repaint, this.basemap}) : super(repaint: repaint);
  final ProjectController c;
  final Tool? tool;
  final SnapResult? snapResult;
  final Listenable repaint;
  final BaseMapLayer? basemap;

  Camera get cam => c.camera;

  final _textCache = <String, TextPainter>{};

  TextPainter _text(String s, {double size = 11, Color color = const Color(0xFFCFD8DC), FontWeight weight = FontWeight.normal}) {
    final key = '$s|$size|${color.toARGB32()}|$weight';
    return _textCache.putIfAbsent(key, () {
      final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight)), textDirection: TextDirection.ltr);
      tp.layout();
      return tp;
    });
  }

  void _label(Canvas canvas, Offset at, String s, {double size = 11, Color color = const Color(0xFFCFD8DC), bool bg = true, Offset shift = const Offset(4, -14)}) {
    final tp = _text(s, size: size, color: color);
    final o = at + shift;
    if (bg) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - 2, o.dy - 1, tp.width + 4, tp.height + 2), const Radius.circular(2)), Paint()..color = CadColors.background.withValues(alpha: 0.7));
    }
    tp.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    cam.size = size;
    canvas.drawRect(Offset.zero & size, Paint()..color = CadColors.background);
    // base map under everything
    final g = c.project.meta.georef;
    if (c.baseMap != BaseMap.none && g != null && basemap != null) {
      final m = c.baseMap;
      basemap!.paint(canvas, cam, g, BaseMapOptions(m, opacity: c.baseMapOpacity, googleKey: c.googleMapsKey, customUrl: c.customTileUrl, lang: c.lang, epoch: c.baseMapEpoch));
      final err = basemap!.googleError;
      final (text, color) = m.isGoogle && c.googleMapsKey == null
          ? (c.t('basemap.googleKeyMissing'), Colors.orangeAccent)
          : m.isGoogle && err != null
              ? (c.t('basemap.googleError', {'e': err}), Colors.orangeAccent)
              : m == BaseMap.custom && !BaseMapLayer.isValidTemplate(c.customTileUrl)
                  ? (c.t('basemap.customInvalid'), Colors.orangeAccent)
                  : (basemap!.attributionText(m), Colors.white70);
      if (text.isNotEmpty) _label(canvas, Offset(8, size.height - 36), text, size: 9, shift: Offset.zero, color: color);
    }
    if (c.showGrid) _grid(canvas, size);
    final vis = cam.visible;
    final results = c.results;
    final pipeRes = results?.pipesByEntity ?? const {};
    final outletRes = results?.outletsByEntity ?? const {};
    final layersVisible = {for (final l in c.project.layers) l.name: l.visible};
    // Viewport culling through the spatial index: only the entities whose
    // (cached) bounds touch the visible area, widened by the largest margin
    // any pass uses, are considered; the indices come in drawing order.
    final index = c.index;
    final ents = index.entities;
    final vis2 = vis.inflate(2), vis3 = vis.inflate(3);
    final cand = index.query(vis3);
    // pass 0: images and hatches (backgrounds)
    for (final i in cand) {
      final e = ents[i];
      if (!(layersVisible[e.layer] ?? true)) continue;
      if (e is ImageEntity && index.boundsAt(i).intersects(vis)) _image(canvas, e);
    }
    for (final i in cand) {
      final e = ents[i];
      if (!(layersVisible[e.layer] ?? true)) continue;
      if (e is HatchEntity && index.boundsAt(i).intersects(vis)) _hatch(canvas, e);
    }
    // pass 1: areas
    for (final i in cand) {
      final e = ents[i];
      if (e is AreaEntity && (layersVisible[e.layer] ?? true) && index.boundsAt(i).intersects(vis)) _area(canvas, e);
    }
    // densogram (water applied by the sprinklers) over the areas
    if (c.overlay == OverlayMode.densogram) _densogram(canvas);
    // pass 2: drawing / terrain / linear hydraulics
    for (final i in cand) {
      final e = ents[i];
      if (!(layersVisible[e.layer] ?? true)) continue;
      if (!index.boundsAt(i).intersects(vis2)) continue;
      final selected = c.selection.contains(e.id);
      final hovered = c.hoverId == e.id;
      final color = _color(e, selected, hovered);
      switch (e) {
        case LineEntity l:
          canvas.drawLine(cam.toScreen(l.a), cam.toScreen(l.b), _stroke(color, selected ? 2 : 1));
        case PolylineEntity p:
          _poly(canvas, p.points, _stroke(color, selected ? 2 : 1), close: p.closed);
        case SplineEntity s:
          _poly(canvas, s.curve(cam.scale > 5 ? 12 : 6), _stroke(color, selected ? 2 : 1), close: s.closed);
          if (selected) {
            final pp = Paint()..color = color.withValues(alpha: 0.5);
            for (final p in s.points) {
              canvas.drawCircle(cam.toScreen(p), 2, pp);
            }
          }
        case CircleEntity ci:
          canvas.drawCircle(cam.toScreen(ci.center), ci.radius * cam.scale, _stroke(color, selected ? 2 : 1));
        case ArcEntity a:
          _poly(canvas, a.polyline(math.max(16, (a.radius * cam.scale / 4).clamp(16, 180).toInt())), _stroke(color, selected ? 2 : 1));
        case SymbolEntity s:
          final p = _stroke(color, selected ? 1.8 : 1.1);
          for (final stroke in s.strokes()) {
            _poly(canvas, stroke, p);
          }
          if (s.kind == SymbolKind.northArrow && cam.scale * s.size > 8) _label(canvas, cam.toScreen(s.position + Pt.polar(s.size * 1.15, degToRad(s.rotationDeg) + math.pi / 2)), 'N', color: color, size: 11, bg: false, shift: const Offset(-4, -14));
        case TextEntity t:
          _worldText(canvas, t.position, t.text, t.height, color, t.rotationDeg);
        case DimensionEntity d:
          _dimension(canvas, d, color);
        case AngularDimensionEntity d:
          _angular(canvas, d, color);
        case RadialDimensionEntity d:
          _radial(canvas, d, color);
        case OrdinateDimensionEntity d:
          _ordinate(canvas, d, color);
        case WireEntity w:
          _wire(canvas, w, color, selected);
        case LeaderEntity l:
          _leader(canvas, l, color);
        case ContourEntity ct:
          _poly(canvas, ct.points, ct.derived ? (_stroke(color.withValues(alpha: 0.7), selected ? 2 : 0.8)) : _stroke(color, selected ? 2 : 1));
          if (c.showLabels && ct.points.isNotEmpty) {
            final lenPx = ct.length * cam.scale;
            // generated contours all start on the model's edge, so their
            // labels sit along the line instead of piling up at the ends
            if (lenPx > 40) _label(canvas, cam.toScreen(ct.derived ? pointAlongPolyline(ct.points, ct.length * 0.3) : ct.points.first), fmt(ct.elevation, 1), color: color, size: 10);
            if (lenPx > 400) _label(canvas, cam.toScreen(pointAlongPolyline(ct.points, ct.length * (ct.derived ? 0.7 : 0.5))), fmt(ct.elevation, 1), color: color, size: 10);
          }
        case PivotEntity pv:
          _pivot(canvas, pv, color, selected);
        case SpotHeightEntity s:
          final o = cam.toScreen(s.position);
          canvas.drawLine(o + const Offset(-4, 0), o + const Offset(4, 0), _stroke(color, 1));
          canvas.drawLine(o + const Offset(0, -4), o + const Offset(0, 4), _stroke(color, 1));
          if (c.showLabels && cam.scale > 1) _label(canvas, o, fmt(s.elevation, 1), color: color, size: 10, shift: const Offset(5, -6));
        case PipeEntity p:
          _pipe(canvas, p.points, e, pipeRes[e.id], p.scope == HydraulicScope.mainline ? 3 : 2, color, selected);
        case SpraylineEntity s:
          _pipe(canvas, s.points, e, pipeRes[e.id], 1.5, color, selected);
          _spraylineOutlets(canvas, s, outletRes[e.id], color);
          _feed(canvas, s.id, s.points);
        case TapeEntity t:
          _pipe(canvas, t.points, e, pipeRes[e.id], 1.5, color, selected, dashed: true);
          _tapeResults(canvas, t, outletRes[e.id]);
          _feed(canvas, t.id, t.points);
        default:
          break;
      }
    }
    // pass 3: point hydraulic items
    for (final i in cand) {
      final e = ents[i];
      if (!(layersVisible[e.layer] ?? true)) continue;
      if (e is! PointEntity) continue;
      if (!index.boundsAt(i).intersects(vis3)) continue;
      final selected = c.selection.contains(e.id);
      final hovered = c.hoverId == e.id;
      final color = _color(e, selected, hovered);
      switch (e) {
        case OutletEntity o:
          _outlet(canvas, o, outletRes[e.id], color, selected);
        case ControlValveEntity v:
          _valve(canvas, v, color, selected);
        case WaterSupplyEntity s:
          _supply(canvas, s, color, selected);
        case PumpEntity p:
          _pump(canvas, p, color, selected);
        case MiscHydraulicEntity m:
          _misc(canvas, m, color, selected);
        case JunctionEntity j:
          canvas.drawCircle(cam.toScreen(j.position), 3, Paint()..color = color);
        case ControllerEntity k:
          _controller(canvas, k, color, selected);
        default:
          break;
      }
    }
    // min/max pressure markers per zone
    if (c.overlay == OverlayMode.minMax && results != null) _minMax(canvas, results);
    // selected image frames
    for (final i in cand) {
      final e = ents[i];
      if (e is ImageEntity && c.selection.contains(e.id)) _poly(canvas, e.corners, _stroke(CadColors.selection, 1.5), close: true);
    }
    // unconnected marks
    if (c.unconnected.isNotEmpty) {
      final paint = _stroke(CadColors.unconnected, 2);
      for (final i in cand) {
        final e = ents[i];
        if (!c.unconnected.contains(e.id)) continue;
        final b = index.boundsAt(i);
        final o = cam.toScreen(e is PointEntity ? e.position : b.center);
        canvas.drawCircle(o, 9, paint);
        canvas.drawLine(o + const Offset(-6, -6), o + const Offset(6, 6), paint);
        canvas.drawLine(o + const Offset(-6, 6), o + const Offset(6, -6), paint);
      }
    }
    // profile path (purple, with its vertices and a label; cleared from the
    // Profile tab or with Esc in the Profile tool)
    final pp = c.profilePath;
    if (pp != null && pp.length >= 2) {
      const purple = Color(0xFFCE93D8);
      _poly(canvas, pp, _stroke(purple, 1.8)..strokeCap = StrokeCap.round);
      for (final p in pp) {
        canvas.drawCircle(cam.toScreen(p), 3, Paint()..color = purple);
      }
      _label(canvas, cam.toScreen(pp.first), '${c.t('prof.pathLabel')} ▸', color: purple, size: 10, shift: const Offset(6, -16));
    }
    // tool preview
    tool?.paint(canvas, cam);
    // snap marker
    final s = snapResult;
    if (s != null && s.isSnapped && tool != null && tool!.usesSnap) {
      final o = cam.toScreen(s.point);
      final p = _stroke(CadColors.snap, 1.5);
      switch (s.kind) {
        case 'endpoint':
        case 'node':
          canvas.drawRect(Rect.fromCenter(center: o, width: 10, height: 10), p);
        case 'midpoint':
          final path = Path()
            ..moveTo(o.dx, o.dy - 6)
            ..lineTo(o.dx + 6, o.dy + 5)
            ..lineTo(o.dx - 6, o.dy + 5)
            ..close();
          canvas.drawPath(path, p);
        case 'on':
          canvas.drawLine(o + const Offset(-5, -5), o + const Offset(5, 5), p);
          canvas.drawLine(o + const Offset(-5, 5), o + const Offset(5, -5), p);
        default:
          canvas.drawCircle(o, 4, p);
      }
    }
    // cursor crosshair
    final cur = tool?.cursor;
    if (cur != null && c.activeTool != ToolId.select && c.activeTool != ToolId.pan) {
      final o = cam.toScreen(cur);
      final p = Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), p);
      canvas.drawLine(Offset(o.dx, 0), Offset(o.dx, size.height), p);
    }
    _scaleBar(canvas, size);
    if (c.overlay == OverlayMode.densogram) _densogramLegend(canvas, size);
  }

  /// The densogram grid, as a picture (one pixel per cell) or, while the
  /// picture is being decoded, as cells.
  void _densogram(Canvas canvas) {
    final d = c.densogram;
    if (d.isEmpty) return;
    final b = d.bounds;
    final tl = cam.toScreen(Pt(b.minX, b.maxY)), br = cam.toScreen(Pt(b.maxX, b.minY));
    final img = c.densogramImage;
    if (img != null) {
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromPoints(tl, br), Paint()..filterQuality = FilterQuality.none);
      return;
    }
    final px = d.cell * cam.scale;
    if (px < 1.5) return;
    final paint = Paint();
    for (var j = 0; j < d.ny; j++) {
      for (var i = 0; i < d.nx; i++) {
        final v = d.rate[j * d.nx + i];
        if (v <= 0) continue;
        paint.color = Color(densogramColor(v, d.meanAt(j * d.nx + i))).withValues(alpha: d.inside[j * d.nx + i] == 1 ? 0.72 : 0.3);
        final o = cam.toScreen(Pt(d.origin.x + i * d.cell, d.origin.y + (j + 1) * d.cell));
        canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, px, px), paint);
      }
    }
  }

  /// Colour key of the densogram (rate relative to the mean of the area)
  /// with its uniformity, at the top left (the zoom buttons are on the
  /// right).
  void _densogramLegend(Canvas canvas, Size size) {
    final d = c.densogram;
    final t = c.t;
    const w = 150.0, h = 10.0;
    const o = Offset(14, 14);
    if (d.isEmpty) {
      _label(canvas, o, t('dens.none'), size: 10, shift: Offset.zero, color: Colors.orangeAccent);
      return;
    }
    final maxR = densogramStops.last.$1;
    for (var k = 0; k < 60; k++) {
      final r = maxR * k / 60;
      canvas.drawRect(Rect.fromLTWH(o.dx + w * k / 60, o.dy + 16, w / 60 + 0.5, h), Paint()..color = Color(densogramColor(r, 1)));
    }
    canvas.drawRect(Rect.fromLTWH(o.dx, o.dy + 16, w, h), _stroke(Colors.white54, 0.6));
    // with several areas the worst one tells how uniform the design is
    final worst = d.areas.isEmpty ? d.stats : d.areas.map((a) => a.stats).reduce((a, b) => a.cu <= b.cu ? a : b);
    _label(canvas, o, t('dens.legend', {'cu': fmt(worst.cu, 0), 'du': fmt(worst.du, 0)}), size: 10, shift: Offset.zero);
    for (final r in const [0.0, 1.0, 2.0]) {
      final x = o.dx + w * r / maxR;
      _label(canvas, Offset(x, o.dy + 28), r == 0 ? '0' : '×${r.round()}', size: 9, bg: false, shift: Offset(r == 0 ? 0 : (r == maxR ? -12 : -6), 0), color: Colors.white70);
    }
  }

  Paint _stroke(Color color, double w) => Paint()
    ..color = color
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Color _color(Entity e, bool selected, bool hovered) {
    if (selected) return CadColors.selection;
    if (hovered) return CadColors.hover;
    return Color(c.project.layerNamed(e.layer).color);
  }

  void _grid(Canvas canvas, Size size) {
    final step = cam.gridStep();
    final vis = cam.visible;
    final minor = Paint()
      ..color = CadColors.gridMinor
      ..strokeWidth = 1;
    final major = Paint()
      ..color = CadColors.gridMajor
      ..strokeWidth = 1;
    final x0 = (vis.minX / step).floor() * step;
    final y0 = (vis.minY / step).floor() * step;
    var count = 0;
    for (var x = x0; x <= vis.maxX && count < 400; x += step, count++) {
      final sx = cam.toScreen(Pt(x, 0)).dx;
      final isMajor = ((x / step).round() % 5) == 0;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), isMajor ? major : minor);
      if (isMajor) _label(canvas, Offset(sx, size.height - 14), fmt(x, 0), size: 9, bg: false, shift: const Offset(2, 0), color: const Color(0xFF546E7A));
    }
    count = 0;
    for (var y = y0; y <= vis.maxY && count < 400; y += step, count++) {
      final sy = cam.toScreen(Pt(0, y)).dy;
      final isMajor = ((y / step).round() % 5) == 0;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), isMajor ? major : minor);
      if (isMajor) _label(canvas, Offset(2, sy), fmt(y, 0), size: 9, bg: false, shift: const Offset(0, -12), color: const Color(0xFF546E7A));
    }
    // axes
    final ax = Paint()
      ..color = CadColors.axis
      ..strokeWidth = 1.5;
    final ox = cam.toScreen(Pt.zero);
    canvas.drawLine(Offset(ox.dx, 0), Offset(ox.dx, size.height), ax);
    canvas.drawLine(Offset(0, ox.dy), Offset(size.width, ox.dy), ax);
  }

  void _scaleBar(Canvas canvas, Size size) {
    final step = cam.gridStep();
    final px = step * cam.scale;
    final o = Offset(size.width - px - 20, size.height - 22);
    canvas.drawLine(o, o + Offset(px, 0), Paint()
      ..color = Colors.white70
      ..strokeWidth = 2);
    canvas.drawLine(o, o + const Offset(0, -5), Paint()..color = Colors.white70);
    canvas.drawLine(o + Offset(px, 0), o + Offset(px, -5), Paint()..color = Colors.white70);
    _label(canvas, o, '${fmt(c.units.lengthFromSi(step), step < 1 ? 2 : 0)} ${c.units.lengthLabel}', size: 10, bg: false, shift: Offset(px / 2 - 12, -16), color: Colors.white70);
  }

  void _poly(Canvas canvas, List<Pt> pts, Paint paint, {bool close = false}) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      canvas.drawCircle(cam.toScreen(pts.first), 2, paint);
      return;
    }
    final path = Path();
    final f = cam.toScreen(pts.first);
    path.moveTo(f.dx, f.dy);
    for (final p in pts.skip(1)) {
      final s = cam.toScreen(p);
      path.lineTo(s.dx, s.dy);
    }
    if (close) path.close();
    canvas.drawPath(path, paint);
  }

  /// Centre pivot / linear move: irrigated outline, span pipe, towers and
  /// the pivot point, with flow / inlet pressure after the design.
  void _pivot(Canvas canvas, PivotEntity p, Color color, bool selected) {
    final outline = p.outline();
    final path = Path();
    final f = cam.toScreen(outline.first);
    path.moveTo(f.dx, f.dy);
    for (final q in outline.skip(1)) {
      final o = cam.toScreen(q);
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: selected ? 0.14 : 0.07));
    canvas.drawPath(path, _stroke(color.withValues(alpha: 0.9), selected ? 1.5 : 1));
    canvas.drawLine(cam.toScreen(p.center), cam.toScreen(p.endPoint), _stroke(color, selected ? 3.5 : 2.5));
    if (cam.scale * p.spanLengthM > 6) {
      final tower = Paint()..color = color;
      for (final t in p.towerPositions()) {
        canvas.drawRect(Rect.fromCenter(center: cam.toScreen(t), width: 6, height: 6), tower);
      }
    }
    final o = cam.toScreen(p.center);
    canvas.drawCircle(o, 6, Paint()..color = color);
    canvas.drawCircle(o, 6, _stroke(Colors.black, 1));
    if (c.showLabels) {
      var s = p.name;
      final r = c.results?.pivots[p.id];
      if (r != null) {
        final u = c.units;
        s += '  ${fmt(u.flowFromSi(r.flow), 1)} ${u.flowLabel} / ${fmt(u.pressureFromHead(r.inletHead), 1)} ${u.pressureLabel}';
      }
      _label(canvas, o, s, size: 11, color: r != null && r.deficit > 0.01 ? CadColors.warning : color, shift: const Offset(9, -8));
    }
  }

  void _image(Canvas canvas, ImageEntity e) {
    final img = c.imageFor(e);
    final corners = e.corners;
    if (img == null) {
      _poly(canvas, corners, _stroke(Colors.white24, 1), close: true);
      _label(canvas, cam.toScreen(corners[3]), e.name.isEmpty ? e.source : e.name, size: 10, shift: const Offset(4, 4), color: Colors.white54);
      return;
    }
    // affine from image pixels to screen: (0,0) → top-left corner
    final tl = cam.toScreen(corners[3]), tr = cam.toScreen(corners[2]), bl = cam.toScreen(corners[0]);
    final w = img.width.toDouble(), h = img.height.toDouble();
    final a = (tr.dx - tl.dx) / w, b = (tr.dy - tl.dy) / w;
    final cc = (bl.dx - tl.dx) / h, d = (bl.dy - tl.dy) / h;
    canvas.save();
    canvas.transform(Float64List.fromList([a, b, 0, 0, cc, d, 0, 0, 0, 0, 1, 0, tl.dx, tl.dy, 0, 1]));
    canvas.drawImage(img, Offset.zero, Paint()..color = Colors.white.withValues(alpha: e.opacity.clamp(0.05, 1.0)));
    canvas.restore();
  }

  void _hatch(Canvas canvas, HatchEntity h) {
    final selected = c.selection.contains(h.id);
    final color = selected ? CadColors.selection : Color(c.project.layerNamed(h.layer).color);
    if (h.points.length < 3) return;
    if (h.solid) {
      final path = Path();
      final f = cam.toScreen(h.points.first);
      path.moveTo(f.dx, f.dy);
      for (final p in h.points.skip(1)) {
        final s = cam.toScreen(p);
        path.lineTo(s.dx, s.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.45));
    } else {
      final paint = _stroke(color.withValues(alpha: 0.8), 0.8);
      // avoid drawing thousands of lines when zoomed out
      final spacingPx = h.spacing * cam.scale;
      if (spacingPx >= 2.5) {
        for (final l in h.patternLines()) {
          canvas.drawLine(cam.toScreen(l[0]), cam.toScreen(l[1]), paint);
        }
      } else {
        final path = Path();
        final f = cam.toScreen(h.points.first);
        path.moveTo(f.dx, f.dy);
        for (final p in h.points.skip(1)) {
          final s = cam.toScreen(p);
          path.lineTo(s.dx, s.dy);
        }
        path.close();
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.25));
      }
    }
    _poly(canvas, h.points, _stroke(color, selected ? 1.5 : 0.8), close: true);
  }

  void _area(Canvas canvas, AreaEntity a) {
    final selected = c.selection.contains(a.id);
    final color = Color(c.project.layerNamed(a.layer).color);
    final path = Path();
    final f = cam.toScreen(a.points.first);
    path.moveTo(f.dx, f.dy);
    for (final p in a.points.skip(1)) {
      final s = cam.toScreen(p);
      path.lineTo(s.dx, s.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: selected ? 0.35 : 0.18));
    canvas.drawPath(path, _stroke(selected ? CadColors.selection : color.withValues(alpha: 0.9), 1));
    if (c.showLabels) {
      final cen = cam.toScreen(polygonCentroid(a.points));
      _label(canvas, cen, '${a.name}  ${fmt(a.area / 10000, 2)} ha', size: 11, shift: const Offset(-20, -6));
    }
  }

  Color _velocityColor(double v, double vmax) {
    final t = (v / math.max(vmax, 1e-6)).clamp(0.0, 1.5);
    if (t <= 0.5) return Color.lerp(const Color(0xFF42A5F5), const Color(0xFF66BB6A), t / 0.5)!;
    if (t <= 1.0) return Color.lerp(const Color(0xFF66BB6A), const Color(0xFFFFA726), (t - 0.5) / 0.5)!;
    return Color.lerp(const Color(0xFFFFA726), const Color(0xFFE53935), (t - 1.0) / 0.5)!;
  }

  Color _pressureColor(double p, double lo, double hi) {
    if (hi <= lo) return const Color(0xFF66BB6A);
    if (p < lo) return const Color(0xFFE53935);
    if (p > hi) return const Color(0xFFAB47BC);
    final t = (p - lo) / (hi - lo);
    return Color.lerp(const Color(0xFF29B6F6), const Color(0xFF66BB6A), t)!;
  }

  void _pipe(Canvas canvas, List<Pt> pts, Entity e, List<PipeSegmentResult>? res, double width, Color color, bool selected, {bool dashed = false}) {
    if (pts.length < 2) return;
    final overlay = c.overlay;
    if (res != null && res.isNotEmpty && (overlay == OverlayMode.velocity || overlay == OverlayMode.pressure) && !selected) {
      final vmax = e is PipeEntity && e.scope == HydraulicScope.mainline ? c.project.params.maxMainlineVelocity : c.project.params.maxZoneVelocity;
      for (final r in res) {
        final col = overlay == OverlayMode.velocity ? _velocityColor(r.velocity, vmax) : _pressureColor((r.pressureStart + r.pressureEnd) / 2, 0, math.max(60, r.pressureRating));
        canvas.drawLine(cam.toScreen(r.a), cam.toScreen(r.b), _stroke(col, width + 1));
      }
    } else {
      _poly(canvas, pts, _stroke(color, selected ? width + 1.5 : width));
    }
    if (dashed && cam.scale > 0.5) {
      // tick marks to distinguish tapes
      final total = polylineLength(pts);
      final stepM = math.max(2.0, 20 / cam.scale);
      for (var d = stepM; d < total; d += stepM) {
        final p = cam.toScreen(pointAlongPolyline(pts, d));
        canvas.drawCircle(p, 1.2, Paint()..color = color);
      }
    }
    if (c.showLabels && c.overlay == OverlayMode.sizes && cam.scale > 0.8) {
      String? name;
      if (e is PipeEntity) name = c.project.catalog.pipe(e.pipeSpecId)?.name;
      if (e is SpraylineEntity) name = c.project.catalog.pipe(e.pipeSpecId)?.name;
      if (e is TapeEntity) name = c.project.catalog.tape(e.tapeSpecId)?.name;
      if (name != null) {
        final mid = pointAlongPolyline(pts, polylineLength(pts) / 2);
        _label(canvas, cam.toScreen(mid), name, size: 10, shift: const Offset(4, -6));
      }
    } else if (c.showLabels && res != null && res.isNotEmpty && cam.scale > 2 && e is PipeEntity) {
      final r = res.first;
      final mid = pointAlongPolyline(pts, polylineLength(pts) / 2);
      final u = c.units;
      _label(canvas, cam.toScreen(mid), '${fmt(u.flowFromSi(r.flow.abs()), 1)} ${u.flowLabel}  ${fmt(r.velocity, 2)} m/s', size: 9, shift: const Offset(4, -6));
    }
  }

  /// Allowable feed (submain) positions along a lateral: green where the
  /// window is met, red where not; the best position gets a marker.
  void _feed(Canvas canvas, String id, List<Pt> pts) {
    final res = c.feedEnvelope[id];
    if (res == null || res.isEmpty || pts.length < 2) return;
    final total = polylineLength(pts);
    final ok = _stroke(CadColors.ok, 5);
    final bad = _stroke(CadColors.unconnected.withValues(alpha: 0.6), 5);
    for (var i = 1; i < res.length; i++) {
      final a = pointAlongPolyline(pts, res[i - 1].fraction * total), b = pointAlongPolyline(pts, res[i].fraction * total);
      canvas.drawLine(cam.toScreen(a), cam.toScreen(b), res[i - 1].ok && res[i].ok ? ok : bad);
    }
    var best = res.first;
    for (final r in res) {
      if (r.variation < best.variation) best = r;
    }
    final o = cam.toScreen(pointAlongPolyline(pts, best.fraction * total));
    canvas.drawCircle(o, 5, Paint()..color = CadColors.ok);
    canvas.drawCircle(o, 5, _stroke(Colors.black, 1));
    if (cam.scale > 1.5) _label(canvas, o, '${(best.fraction * 100).round()} %  Δ${fmt(c.units.pressureFromHead(best.variation), 1)}', size: 9, shift: const Offset(6, -16));
  }

  void _spraylineOutlets(Canvas canvas, SpraylineEntity s, List<OutletResult>? res, Color color) {
    if (cam.scale < 0.6) return;
    final nozzle = c.project.catalog.outlet(s.outletSpecId)?.nozzle(s.nozzleId);
    final radius = nozzle?.curve.radius(s.headM) ?? 0;
    final positions = s.outletPositions();
    final pOut = Paint()..color = Color(c.project.layerNamed(Layers.outlets).color);
    final pR = _stroke(Color(c.project.layerNamed(Layers.wettedRadii).color), 0.7);
    final showR = c.showWettedRadii && radius > 0 && c.project.layerNamed(Layers.wettedRadii).visible && positions.length < 3000 && cam.scale > 1.2;
    for (final p in positions) {
      final o = cam.toScreen(p);
      canvas.drawCircle(o, math.max(1.5, 0.25 * cam.scale), pOut);
      if (showR) canvas.drawCircle(o, radius * cam.scale, pR);
    }
    if (c.overlay == OverlayMode.pressure && res != null && cam.scale > 0.6) {
      for (final r in res) {
        final o = cam.toScreen(r.p);
        canvas.drawCircle(o, math.max(2.5, 0.35 * cam.scale), Paint()..color = _pressureColor(r.pressure, r.allowedMin, r.allowedMax));
      }
    }
  }

  void _tapeResults(Canvas canvas, TapeEntity t, List<OutletResult>? res) {
    if (res == null || c.overlay != OverlayMode.pressure || cam.scale < 0.6) return;
    for (final r in res) {
      final o = cam.toScreen(r.p);
      canvas.drawCircle(o, math.max(2, 0.3 * cam.scale), Paint()..color = _pressureColor(r.pressure, r.allowedMin, r.allowedMax));
    }
  }

  void _minMax(Canvas canvas, DesignResults r) {
    final u = c.units;
    for (final z in r.zones.values) {
      final mn = z.minOutlet, mx = z.maxOutlet;
      if (mn == null || mx == null) continue;
      void marker(OutletResult o, Color col, bool up) {
        final s = cam.toScreen(o.p);
        final path = Path();
        if (up) {
          path
            ..moveTo(s.dx, s.dy - 12)
            ..lineTo(s.dx + 7, s.dy)
            ..lineTo(s.dx - 7, s.dy)
            ..close();
        } else {
          path
            ..moveTo(s.dx, s.dy + 12)
            ..lineTo(s.dx + 7, s.dy)
            ..lineTo(s.dx - 7, s.dy)
            ..close();
        }
        canvas.drawPath(path, Paint()..color = col);
        canvas.drawPath(path, _stroke(Colors.black, 1));
        _label(canvas, s, '${up ? '▲' : '▼'} ${fmt(u.pressureFromHead(o.pressure), 1)} ${u.pressureLabel}', size: 10, color: col, shift: Offset(9, up ? -20 : 4));
      }

      marker(mn, mn.inWindow ? const Color(0xFF29B6F6) : CadColors.unconnected, false);
      marker(mx, mx.inWindow ? const Color(0xFFAB47BC) : CadColors.warning, true);
    }
  }

  void _outlet(Canvas canvas, OutletEntity o, List<OutletResult>? res, Color color, bool selected) {
    final s = cam.toScreen(o.position);
    final nozzle = c.project.catalog.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
    final r = math.max(3.0, 0.4 * cam.scale);
    final radius = nozzle?.curve.radius(o.headM) ?? 0;
    if (c.showWettedRadii && radius > 0 && c.project.layerNamed(Layers.wettedRadii).visible) {
      final wr = Color(c.project.layerNamed(Layers.wettedRadii).color);
      final arc = nozzle!.effectiveArcDeg(o.arcDeg);
      final start = -degToRad(o.orientationDeg);
      final rect = Rect.fromCircle(center: s, radius: radius * cam.scale);
      if (arc >= 360) {
        canvas.drawCircle(s, radius * cam.scale, Paint()..color = wr.withValues(alpha: 0.12));
        canvas.drawCircle(s, radius * cam.scale, _stroke(wr, 0.8));
      } else {
        canvas.drawArc(rect, start - degToRad(arc), degToRad(arc), true, Paint()..color = wr.withValues(alpha: 0.15));
        canvas.drawArc(rect, start - degToRad(arc), degToRad(arc), true, _stroke(wr, 0.8));
      }
    }
    var fill = color;
    if (c.overlay == OverlayMode.pressure && res != null && res.isNotEmpty) fill = _pressureColor(res.first.pressure, res.first.allowedMin, res.first.allowedMax);
    canvas.drawCircle(s, r, Paint()..color = fill);
    if (selected) canvas.drawCircle(s, r + 3, _stroke(CadColors.selection, 1.5));
    if (c.showLabels && res != null && res.isNotEmpty && cam.scale > 3) {
      final u = c.units;
      _label(canvas, s, '${fmt(u.pressureFromHead(res.first.pressure), 1)} ${u.pressureLabel}', size: 9, shift: Offset(r + 2, -6));
    }
  }

  void _valve(Canvas canvas, ControlValveEntity v, Color color, bool selected) {
    final s = cam.toScreen(v.position);
    final r = math.max(6.0, 0.9 * cam.scale);
    final path = Path()
      ..moveTo(s.dx - r, s.dy - r * 0.7)
      ..lineTo(s.dx + r, s.dy + r * 0.7)
      ..lineTo(s.dx + r, s.dy - r * 0.7)
      ..lineTo(s.dx - r, s.dy + r * 0.7)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.9));
    if (selected) canvas.drawCircle(s, r + 3, _stroke(CadColors.selection, 1.5));
    if (c.showLabels) {
      final z = c.results?.zones[v.id];
      var txt = v.zoneName;
      if (z != null) {
        final u = c.units;
        txt += '  ${fmt(u.flowFromSi(z.totalFlow), 1)} ${u.flowLabel} / ${fmt(u.pressureFromHead(z.requiredUpstreamHead), 1)} ${u.pressureLabel}';
      }
      _label(canvas, s, txt, size: 10, color: z != null && !z.withinWindow ? CadColors.warning : color, shift: Offset(r + 3, -7));
      // wiring: station, station wire and solenoid voltage
      final run = c.results?.electrical?.runOf(v.id);
      if (run != null && cam.scale > 0.8) {
        final wire = c.project.catalog.wire(run.stationWireId);
        final w = wire == null ? '' : '  ${fmt(wire.sectionMm2, wire.sectionMm2 < 10 ? 1 : 0)} mm²';
        _label(canvas, s, '${c.t('elec.stationTag', {'n': '${run.station}'})}$w  ${fmt(run.volts, 1)} V', size: 9, color: run.ok ? const Color(0xFFFFEE58) : CadColors.warning, shift: Offset(r + 3, 7));
      }
    }
  }

  void _supply(Canvas canvas, WaterSupplyEntity w, Color color, bool selected) {
    final s = cam.toScreen(w.position);
    final r = math.max(8.0, 1.3 * cam.scale);
    canvas.drawRect(Rect.fromCenter(center: s, width: 2 * r, height: 2 * r), Paint()..color = color.withValues(alpha: 0.9));
    final tp = _text('W', size: math.max(9, r), color: Colors.black, weight: FontWeight.bold);
    tp.paint(canvas, s - Offset(tp.width / 2, tp.height / 2));
    if (selected) canvas.drawCircle(s, r + 4, _stroke(CadColors.selection, 1.5));
    if (c.showLabels) {
      var txt = w.name;
      final res = c.results;
      if (res != null && res.systemFlows.isNotEmpty) {
        SupplyDuty? worst;
        for (final f in res.systemFlows) {
          for (final d in f.supplies) {
            if (d.supplyId == w.id && (worst == null || d.requiredHead > worst.requiredHead)) worst = d;
          }
        }
        if (worst != null) {
          final u = c.units;
          txt += '  ${fmt(u.flowFromSi(worst.flow), 1)} ${u.flowLabel} @ ${fmt(u.pressureFromHead(math.max(0, worst.requiredHead)), 1)} ${u.pressureLabel}';
          if (worst.surplusHead > 0.05) txt += ' (${c.t('rep.surplus')} ${fmt(u.pressureFromHead(worst.surplusHead), 1)})';
        }
      }
      _label(canvas, s, txt, size: 10, color: color, shift: Offset(r + 3, -7));
    }
  }

  void _pump(Canvas canvas, PumpEntity p, Color color, bool selected) {
    final s = cam.toScreen(p.position);
    final r = math.max(7.0, 1.0 * cam.scale);
    canvas.drawCircle(s, r, Paint()..color = color.withValues(alpha: 0.9));
    final tp = _text('P', size: math.max(9, r), color: Colors.black, weight: FontWeight.bold);
    tp.paint(canvas, s - Offset(tp.width / 2, tp.height / 2));
    if (selected) canvas.drawCircle(s, r + 4, _stroke(CadColors.selection, 1.5));
    if (c.showLabels) _label(canvas, s, c.project.catalog.pump(p.pumpSpecId)?.name ?? 'Bomba', size: 10, color: color, shift: Offset(r + 3, 8));
  }

  void _misc(Canvas canvas, MiscHydraulicEntity m, Color color, bool selected) {
    final s = cam.toScreen(m.position);
    final r = math.max(5.0, 0.7 * cam.scale);
    final path = Path()
      ..moveTo(s.dx, s.dy - r)
      ..lineTo(s.dx + r, s.dy)
      ..lineTo(s.dx, s.dy + r)
      ..lineTo(s.dx - r, s.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.9));
    if (selected) canvas.drawCircle(s, r + 4, _stroke(CadColors.selection, 1.5));
    if (c.showLabels && cam.scale > 1.5) _label(canvas, s, c.project.catalog.valve(m.valveSpecId)?.name ?? '', size: 9, color: color, shift: Offset(r + 3, -22));
  }

  void _dimension(Canvas canvas, DimensionEntity d, Color color) {
    final n = d.normal * d.offset;
    final a = cam.toScreen(d.a), b = cam.toScreen(d.b), a2 = cam.toScreen(d.a + n), b2 = cam.toScreen(d.b + n);
    final p = _stroke(color, 1);
    canvas.drawLine(a, a2, p);
    canvas.drawLine(b, b2, p);
    canvas.drawLine(a2, b2, p);
    final mid = Offset((a2.dx + b2.dx) / 2, (a2.dy + b2.dy) / 2);
    _label(canvas, mid, '${fmt(c.units.lengthFromSi(d.length))} ${c.units.lengthLabel}', size: 10, color: color, shift: const Offset(-14, -14));
  }

  void _angular(Canvas canvas, AngularDimensionEntity d, Color color) {
    final p = _stroke(color, 1);
    canvas.drawLine(cam.toScreen(d.vertex), cam.toScreen(d.a), p);
    canvas.drawLine(cam.toScreen(d.vertex), cam.toScreen(d.b), p);
    _poly(canvas, d.arcPoints(48), p);
    _label(canvas, cam.toScreen(d.textPoint), '${fmt(d.angleDeg, 1)}°', size: 10, color: color, shift: const Offset(-10, -7));
  }

  void _radial(Canvas canvas, RadialDimensionEntity d, Color color) {
    final p = _stroke(color, 1);
    final a = cam.toScreen(d.start), b = cam.toScreen(d.point);
    canvas.drawLine(a, b, p);
    _arrowHead(canvas, a, b, color);
    if (d.diameter) _arrowHead(canvas, b, a, color);
    canvas.drawCircle(cam.toScreen(d.center), 2, Paint()..color = color);
    final m = cam.toScreen(d.diameter ? d.center : Pt.lerp(d.center, d.point, 0.5));
    _label(canvas, m, '${d.diameter ? 'Ø' : 'R'} ${fmt(c.units.lengthFromSi(d.value))} ${c.units.lengthLabel}', size: 10, color: color, shift: const Offset(4, -14));
  }

  void _ordinate(Canvas canvas, OrdinateDimensionEntity d, Color color) {
    _poly(canvas, d.leader, _stroke(color, 1));
    canvas.drawCircle(cam.toScreen(d.point), 2, Paint()..color = color);
    final e = cam.toScreen(d.leaderEnd);
    _label(canvas, e, '${d.xAxis ? 'X' : 'Y'} ${fmt(c.units.lengthFromSi(d.value))}', size: 10, color: color, shift: d.xAxis ? const Offset(-12, -16) : const Offset(4, -7));
  }

  /// Wire route: a dashed line (the routes of the valve wiring).
  void _wire(Canvas canvas, WireEntity w, Color color, bool selected) {
    if (w.points.length < 2) return;
    final paint = _stroke(color, selected ? 2.2 : 1.2);
    final dash = 6.0, gap = 4.0;
    for (var i = 1; i < w.points.length; i++) {
      final a = cam.toScreen(w.points[i - 1]), b = cam.toScreen(w.points[i]);
      final len = (b - a).distance;
      if (len < 1e-6) continue;
      final u = (b - a) / len;
      for (var t = 0.0; t < len; t += dash + gap) {
        canvas.drawLine(a + u * t, a + u * math.min(len, t + dash), paint);
      }
    }
  }

  /// Controller: a box with a clock face; after the design, the stations
  /// used over the stations it has.
  void _controller(Canvas canvas, ControllerEntity k, Color color, bool selected) {
    final s = cam.toScreen(k.position);
    final r = math.max(8.0, 1.0 * cam.scale);
    final rect = Rect.fromCenter(center: s, width: 2 * r, height: 2 * r);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.25)), Paint()..color = color.withValues(alpha: 0.9));
    canvas.drawCircle(s, r * 0.55, _stroke(Colors.black, 1.2));
    canvas.drawLine(s, s + Offset(0, -r * 0.4), _stroke(Colors.black, 1.2));
    canvas.drawLine(s, s + Offset(r * 0.3, 0), _stroke(Colors.black, 1.2));
    if (selected) canvas.drawRect(rect.inflate(4), _stroke(CadColors.selection, 1.5));
    if (c.showLabels) {
      final duty = c.results?.electrical?.controllers.where((d) => d.controllerId == k.id).firstOrNull;
      final txt = duty == null ? k.name : '${k.name}  ${duty.used}/${k.stations}';
      _label(canvas, s, txt, size: 10, color: duty != null && duty.overloaded ? CadColors.warning : color, shift: Offset(r + 3, -7));
    }
  }

  void _leader(Canvas canvas, LeaderEntity l, Color color) {
    if (l.points.length < 2) return;
    _poly(canvas, l.points, _stroke(color, 1));
    _arrowHead(canvas, cam.toScreen(l.points[1]), cam.toScreen(l.points[0]), color);
    _worldText(canvas, l.textPosition + Pt(0.3 * l.height, 0), l.text, l.height, color, 0);
  }

  void _arrowHead(Canvas canvas, Offset from, Offset tip, Color color) {
    final dir = (tip - from);
    if (dir.distance < 1e-6) return;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - u.dx * 9 + n.dx * 3.5, tip.dy - u.dy * 9 + n.dy * 3.5)
      ..lineTo(tip.dx - u.dx * 9 - n.dx * 3.5, tip.dy - u.dy * 9 - n.dy * 3.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _worldText(Canvas canvas, Pt pos, String text, double height, Color color, double rotationDeg) {
    final px = height * cam.scale;
    if (px < 3) {
      canvas.drawCircle(cam.toScreen(pos), 1.5, Paint()..color = color);
      return;
    }
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: px.clamp(3, 400), color: color)), textDirection: TextDirection.ltr)..layout();
    final o = cam.toScreen(pos);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(-degToRad(rotationDeg));
    tp.paint(canvas, Offset(0, -tp.height));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CadPainter old) => true;
}

/// Small helper to draw a picture into an image (used by export preview).
Future<ui.Image> renderPreview(CadPainter painter, Size size) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  painter.paint(canvas, size);
  return rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
}
