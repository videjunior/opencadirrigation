import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/design/densogram.dart';
import '../../core/model/slope_map.dart';
import '../../core/design/results.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/label_rules.dart';
import '../../core/model/project.dart' show Layer;
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import '../tools/ai_mark_tool.dart';
import '../tools/tools.dart';
import 'basemap.dart';
import 'camera.dart';
import 'scene_cache.dart';
import 'snapping.dart';

class CadPainter extends CustomPainter {
  CadPainter({required this.c, required this.tool, required this.snapResult, required this.repaint, this.basemap, this.tint, this.scene, this.devicePixelRatio = 1}) : super(repaint: repaint);
  final ProjectController c;

  /// The active tool and the last snap (the canvas updates both in place
  /// as the cursor moves).
  Tool? tool;
  SnapResult? snapResult;
  final Listenable repaint;
  final BaseMapLayer? basemap;

  /// A colour that replaces the layer colour of an item (null: its own),
  /// e.g. one per zone in the AI assistant's pictures.
  final Color? Function(Entity e)? tint;

  /// Keeps the drawing between frames (the canvas passes one); without it
  /// everything is drawn every time (pictures for exports and the AI).
  final SceneCache? scene;

  /// Device pixels per logical pixel of the canvas (the cached scene is
  /// rasterised at this resolution).
  double devicePixelRatio;

  Camera get cam => c.camera;

  /// Laid-out labels shared by every painter, dropped all at once when
  /// they grow past [_maxTexts] or when fonts arrive (a script whose font
  /// is fetched on demand is laid out again with it).
  static final _textCache = <String, TextPainter>{};
  static const _maxTexts = 6000;

  /// Bumped when the fonts change (the scene is then recorded again).
  static int fontEpoch = 0;
  static bool _watchingFonts = false;

  static void _watchFonts() {
    if (_watchingFonts) return;
    _watchingFonts = true;
    try {
      PaintingBinding.instance.systemFonts.addListener(() {
        fontEpoch++;
        for (final tp in _textCache.values) {
          tp.dispose();
        }
        _textCache.clear();
      });
    } catch (_) {
      // no binding (a plain Dart host): nothing to follow
    }
  }

  static TextPainter _cachedText(String key, TextPainter Function() make) {
    final hit = _textCache[key];
    if (hit != null) return hit;
    if (_textCache.length >= _maxTexts) {
      for (final tp in _textCache.values) {
        tp.dispose();
      }
      _textCache.clear();
    }
    return _textCache[key] = make();
  }

  TextPainter _text(String s, {double size = 11, Color? color, FontWeight weight = FontWeight.normal}) {
    final ink = color ?? Cad.canvasText;
    return _cachedText('$s|$size|${ink.toARGB32()}|$weight', () {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: ink, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      return tp;
    });
  }

  void _label(Canvas canvas, Offset at, String s, {double size = 11, Color? color, bool bg = true, Offset shift = const Offset(4, -14)}) {
    final b = _batch;
    if (b != null && !b.labelsInPlace) {
      b.over.add((cv) => _label(cv, at, s, size: size, color: color, bg: bg, shift: shift));
      return;
    }
    final tp = _text(s, size: size, color: color);
    final o = at + shift;
    if (bg) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - 2, o.dy - 1, tp.width + 4, tp.height + 2), const Radius.circular(2)), _fill(Cad.canvas.withValues(alpha: 0.7)));
    }
    tp.paint(canvas, o);
  }

  /// The project's layers by name, and their ink on the canvas, for the
  /// paint under way (looked up once per layer, not once per item).
  Map<String, Layer> _layers = {};
  final Map<String, Color> _inks = {};

  void _indexLayers() {
    _layers = {for (final l in c.project.layers) l.name: l};
    _inks.clear();
    _ruleCache.clear();
    _batch = null;
  }

  // an item on a layer the project does not list gets one, as before
  Layer _layer(String name) => _layers[name] ??= c.project.layerNamed(name);

  Color _inkOf(String layer) => _inks[layer] ??= Cad.ink(Color(_layer(layer).color));

  /// The point to walk to for staking out [e]: its position, the nearest
  /// vertex of a line, the centre of a circle or pivot.
  Pt? _stakeTarget(Entity e) => switch (e) {
    PointEntity p => p.position,
    CircleEntity ci => ci.center,
    PivotEntity pv => pv.center,
    _ => switch (e.linearPoints) {
      final pts? when pts.isNotEmpty => () {
        final g = c.gpsPoint!;
        var best = pts.first;
        for (final q in pts) {
          if (q.distanceTo(g) < best.distanceTo(g)) best = q;
        }
        return best;
      }(),
      _ => null,
    },
  };

  @override
  void paint(Canvas canvas, Size size) {
    cam.size = size;
    _watchFonts();
    final scene = this.scene;
    if (scene == null) {
      paintScene(canvas, size);
    } else {
      scene.paint(canvas, size, devicePixelRatio, _sceneKey(size), cam.center, cam.scale, Cad.canvas, paintScene);
    }
    paintOverlay(canvas, size);
  }

  /// Everything the drawing shows besides the view, the cursor and the
  /// tool: while it stays the same, the cached scene is drawn again as it
  /// is. The controller's notification counter stands for every change
  /// made through it (edits, selection, layers, results, settings, decoded
  /// images); the rest are read directly.
  Object _sceneKey(Size size) => (
    size,
    c.notifySeq,
    c.editSeq,
    identityHashCode(c.project),
    c.project.entities.length,
    c.selection.length,
    identityHashCode(c.results),
    c.overlay,
    (c.showGrid, c.showLabels, c.showWettedRadii, c.lang, Cad.isLight, fontEpoch),
    (c.baseMap, c.baseMapOpacity, c.baseMapEpoch, basemap?.revision),
    (identityHashCode(c.unconnected), c.unconnected.length, identityHashCode(c.feedEnvelope), c.feedEnvelope.length),
  );

  /// The drawing: background, base map, grid, the items with their
  /// results and labels, the scale bar and the overlay legends.
  void paintScene(Canvas canvas, Size size) {
    cam.size = size;
    _indexLayers();
    canvas.drawRect(Offset.zero & size, _fill(Cad.canvas));
    // base map under everything
    final g = c.project.meta.georef;
    if (c.baseMap != BaseMap.none && g != null && basemap != null) {
      final m = c.baseMap;
      basemap!.paint(canvas, cam, g, BaseMapOptions(m, opacity: c.baseMapOpacity, googleKey: c.googleMapsKey, customUrl: c.customTileUrl, lang: c.lang, epoch: c.baseMapEpoch));
      final err = basemap!.googleError;
      final (text, color) = m.isGoogle && c.googleMapsKey == null
          ? (c.t('basemap.googleKeyMissing'), Cad.attention)
          : m.isGoogle && err != null
          ? (c.t('basemap.googleError', {'e': err}), Cad.attention)
          : m == BaseMap.custom && !BaseMapLayer.isValidTemplate(c.customTileUrl)
          ? (c.t(BaseMapLayer.isPlainHttp(c.customTileUrl) ? 'basemap.httpBlocked' : 'basemap.customInvalid'), Cad.attention)
          : ('', Cad.fg70);
      // (the credit of the source is a link over the canvas, see CadCanvas)
      if (text.isNotEmpty) _label(canvas, Offset(8, size.height - 54), text, size: 10, shift: Offset.zero, color: color);
    }
    if (c.showGrid) _grid(canvas, size);
    final vis = cam.visible;
    final results = c.results;
    final outletRes = results?.outletsByEntity ?? const {};
    // Viewport culling through the spatial index: only the entities whose
    // (cached) bounds touch the visible area, widened by the largest margin
    // any pass uses, are considered; the indices come in drawing order.
    final index = c.index;
    final ents = index.entities;
    final vis2 = vis.inflate(2), vis3 = vis.inflate(3);
    final cand = index.query(vis3);
    bool shown(Entity e) => _layer(e.layer).visible;
    // pass 0: images and hatches (backgrounds)
    for (final i in cand) {
      final e = ents[i];
      if (e is ImageEntity && shown(e) && index.boundsAt(i).intersects(vis)) _image(canvas, e);
    }
    _batch = _Batch();
    for (final i in cand) {
      final e = ents[i];
      if (e is HatchEntity && shown(e) && index.boundsAt(i).intersects(vis)) _hatch(canvas, e);
    }
    _flush(canvas);
    // pass 1: areas
    for (final i in cand) {
      final e = ents[i];
      if (e is AreaEntity && shown(e) && index.boundsAt(i).intersects(vis)) _area(canvas, e);
    }
    // densogram (water applied by the sprinklers) over the areas
    if (c.overlay == OverlayMode.densogram) _densogram(canvas);
    // slope or aspect of the terrain
    if (c.overlay == OverlayMode.slope || c.overlay == OverlayMode.aspect) _slopeMap(canvas, aspect: c.overlay == OverlayMode.aspect);
    // a view packed with linework on a high-density screen draws its 1 px
    // lines as single device pixels (see [_thin])
    _dense = false;
    if (devicePixelRatio > 1) {
      var segments = 0;
      for (final i in cand) {
        final pts = ents[i].linearPoints;
        segments += pts == null ? 1 : pts.length;
      }
      _dense = segments > denseSegments;
    }
    // pass 2: drawing / terrain / linear hydraulics, gathered by paint;
    // the selection goes over them (and the item under the cursor over the
    // whole scene, see [paintOverlay])
    final chosen = <Entity>[];
    final anySelected = c.selection.isNotEmpty;
    _batch = _Batch();
    for (final i in cand) {
      final e = ents[i];
      if (!shown(e) || !index.boundsAt(i).intersects(vis2)) continue;
      if (anySelected && c.selection.contains(e.id)) {
        chosen.add(e);
        continue;
      }
      _drawLinear(canvas, e, _color(e, false, false), false);
    }
    _flush(canvas);
    for (final e in chosen) {
      _drawLinear(canvas, e, _color(e, true, false), true);
    }
    // pass 3: point hydraulic items; only the dots are gathered (drawn
    // over the pass): the labels of the outlets stay in place, under the
    // dots of the next ones, those of valves, pumps... go over the dots
    chosen.clear();
    final points = _batch = _Batch();
    for (final i in cand) {
      final e = ents[i];
      if (e is! PointEntity || !shown(e) || !index.boundsAt(i).intersects(vis3)) continue;
      if (anySelected && c.selection.contains(e.id)) {
        chosen.add(e);
        continue;
      }
      points.labelsInPlace = e is OutletEntity;
      _drawPoint(canvas, e, outletRes, _color(e, false, false), false, false);
    }
    _flush(canvas);
    for (final e in chosen) {
      _drawPoint(canvas, e, outletRes, _color(e, true, false), true, false);
    }
    // min/max pressure markers per zone
    if (c.overlay == OverlayMode.minMax && results != null) _minMax(canvas, results);
    // selected image frames
    for (final i in cand) {
      final e = ents[i];
      if (e is ImageEntity && c.selection.contains(e.id)) _poly(canvas, e.corners, _stroke(Cad.selection, 1.5), close: true);
    }
    // unconnected marks
    if (c.unconnected.isNotEmpty) {
      final paint = _stroke(Cad.unconnected, 2);
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
    _scaleBar(canvas, size);
    if (c.overlay == OverlayMode.densogram) _densogramLegend(canvas, size);
    if (c.overlay == OverlayMode.slope || c.overlay == OverlayMode.aspect) _slopeLegend(canvas, aspect: c.overlay == OverlayMode.aspect);
  }

  /// A drawing, terrain or linear hydraulic item (pass 2 of the scene).
  void _drawLinear(Canvas canvas, Entity e, Color color, bool selected) {
    switch (e) {
      case LineEntity l:
        _seg(canvas, cam.toScreen(l.a), cam.toScreen(l.b), _stroke(color, selected ? 2 : 1));
      case PolylineEntity p:
        _poly(canvas, p.points, _stroke(color, selected ? 2 : 1), close: p.closed);
      case SplineEntity s:
        _poly(canvas, s.curve(cam.scale > 5 ? 12 : 6), _stroke(color, selected ? 2 : 1), close: s.closed);
        if (selected) {
          final pp = _fill(color.withValues(alpha: 0.5));
          for (final p in s.points) {
            canvas.drawCircle(cam.toScreen(p), 2, pp);
          }
        }
      case CircleEntity ci:
        _ring(canvas, cam.toScreen(ci.center), ci.radius * cam.scale, _stroke(color, selected ? 2 : 1));
      case ArcEntity a:
        _poly(canvas, a.polyline(math.max(16, (a.radius * cam.scale / 4).clamp(16, 180).toInt())), _stroke(color, selected ? 2 : 1));
      case SymbolEntity s:
        final p = _stroke(color, selected ? 1.8 : 1.1);
        for (final stroke in s.strokes()) {
          _poly(canvas, stroke, p);
        }
        if (s.kind == SymbolKind.northArrow && cam.scale * s.size > 8) {
          _label(canvas, cam.toScreen(s.position + Pt.polar(s.size * 1.15, degToRad(s.rotationDeg) + math.pi / 2)), 'N', color: color, size: 11, bg: false, shift: const Offset(-4, -14));
        }
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
      case BreaklineEntity bl:
        // dashed, with the elevations typed at their vertices
        final st = _stroke(color, selected ? 2.4 : 1.4);
        for (var i = 1; i < bl.points.length; i++) {
          final a = cam.toScreen(bl.points[i - 1]), b = cam.toScreen(bl.points[i]);
          final d = b - a, len = d.distance;
          if (len < 1e-6) continue;
          for (var s0 = 0.0; s0 < len; s0 += 12) {
            _seg(canvas, a + d * (s0 / len), a + d * (math.min(s0 + 7, len) / len), st);
          }
        }
        if (c.showLabels) {
          for (var i = 0; i < bl.points.length; i++) {
            final z = bl.elevationOf(i);
            if (z.isFinite) _label(canvas, cam.toScreen(bl.points[i]), fmt(z, 2), color: color, size: 9.5, shift: const Offset(4, -12));
          }
        }
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
        // drawn in place: its fill, outline, span and centre in this order
        _unbatched(() => _pivot(canvas, pv, color, selected));
      case SpotHeightEntity s:
        final o = cam.toScreen(s.position);
        _seg(canvas, o + const Offset(-4, 0), o + const Offset(4, 0), _stroke(color, 1));
        _seg(canvas, o + const Offset(0, -4), o + const Offset(0, 4), _stroke(color, 1));
        if (c.showLabels && cam.scale > 1) _label(canvas, o, fmt(s.elevation, 1), color: color, size: 10, shift: const Offset(5, -6));
      case PipeEntity p:
        _pipe(canvas, p.points, e, c.results?.pipesByEntity[e.id], p.scope == HydraulicScope.mainline ? 3 : 2, color, selected);
      case SpraylineEntity s:
        _pipe(canvas, s.points, e, c.results?.pipesByEntity[e.id], 1.5, color, selected);
        _spraylineOutlets(canvas, s, c.results?.outletsByEntity[e.id], color);
        _feed(canvas, s.id, s.points);
      case TapeEntity t:
        final segs = c.results?.pipesByEntity[e.id];
        _pipe(canvas, t.points, e, segs, 1.5, color, selected);
        _emitters(canvas, t, segs, c.results?.outletsByEntity[e.id], color, selected);
        _feed(canvas, t.id, t.points);
      case RevisionCloudEntity rc:
        _unbatched(() => _revisionCloud(canvas, rc, color, selected));
      default:
        break;
    }
  }

  /// A point hydraulic item, controller or comment (pass 3 of the scene).
  void _drawPoint(Canvas canvas, Entity e, Map<String, List<OutletResult>> outletRes, Color color, bool selected, bool hovered) {
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
        _dot(canvas, cam.toScreen(j.position), 3, color);
      case ControllerEntity k:
        _controller(canvas, k, color, selected);
      case CommentEntity cm:
        _comment(canvas, cm, color, selected, hovered);
      default:
        break;
    }
  }

  /// What moves with the cursor, over the scene: the item under the
  /// cursor, the profile path, the device position, the marks for the AI,
  /// the tool preview, the snap marker and the crosshair.
  void paintOverlay(Canvas canvas, Size size) {
    _indexLayers();
    _dense = false;
    // the item under the cursor, again in the hover colour (areas, hatches
    // and images keep their look, as in the scene)
    final hid = c.hoverId;
    final hov = hid == null || c.selection.contains(hid) ? null : c.entityById(hid);
    if (hov != null && _layer(hov.layer).visible && hov is! AreaEntity && hov is! HatchEntity && hov is! ImageEntity) {
      final color = _color(hov, false, true);
      _drawLinear(canvas, hov, color, false);
      if (hov is PointEntity) _drawPoint(canvas, hov, c.results?.outletsByEntity ?? const {}, color, false, true);
    }
    // profile path (purple, with its vertices and a label; cleared from the
    // Profile tab or with Esc in the Profile tool)
    final pp = c.profilePath;
    if (pp != null && pp.length >= 2) {
      final purple = Cad.profilePath;
      _poly(canvas, pp, _stroke(purple, 1.8));
      for (final p in pp) {
        canvas.drawCircle(cam.toScreen(p), 3, _fill(purple));
      }
      _label(canvas, cam.toScreen(pp.first), '${c.t('prof.pathLabel')} ▸', color: purple, size: 10, shift: const Offset(6, -16));
    }
    // device position: the walk being recorded, the accuracy circle, the
    // dot, and a line to the single selected item for staking it out
    final gp = c.gpsPoint;
    if (c.gpsActive && gp != null) {
      final blue = Cad.gps;
      final walk = c.gpsTrack;
      if (walk != null && walk.isNotEmpty) _poly(canvas, [...walk, gp], _stroke(Cad.gpsTrack, 2));
      final o = cam.toScreen(gp);
      final acc = (c.gpsFix?.accuracyM ?? 0) * cam.scale;
      if (acc > 6) {
        canvas.drawCircle(o, acc, _fill(blue.withValues(alpha: 0.12)));
        canvas.drawCircle(o, acc, _stroke(blue.withValues(alpha: 0.5), 1));
      }
      canvas.drawCircle(o, 7, _fill(Colors.white));
      canvas.drawCircle(o, 5, _fill(blue));
      final sel = c.selection.length == 1 ? c.entityById(c.selection.first) : null;
      final target = sel == null ? null : _stakeTarget(sel);
      final to = target == null ? null : c.gpsTo(target);
      if (target != null && to != null) {
        final t = cam.toScreen(target);
        canvas.drawLine(o, t, _stroke(Cad.stakeOut, 1.6));
        _label(
          canvas,
          Offset.lerp(o, t, 0.5)!,
          '${fmt(c.project.params.units.lengthFromSi(to.$1), to.$1 < 10 ? 2 : 1)} ${c.project.params.units.lengthLabel} · ${to.$2.round().toString().padLeft(3, '0')}°',
          color: Cad.stakeOut,
          size: 11,
          bg: true,
        );
      }
    }
    // the user's marks for the AI assistant over everything drawn (its
    // pictures show them alike), and the mark being placed
    _aiMarks(canvas);
    // tool preview
    tool?.paint(canvas, cam);
    // snap marker
    final s = snapResult;
    if (s != null && s.isSnapped && tool != null && tool!.usesSnap) {
      final o = cam.toScreen(s.point);
      final p = _stroke(Cad.snap, 1.5);
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
        case 'intersection':
          final bold = _stroke(Cad.snap, 2.4);
          canvas.drawLine(o + const Offset(-6, -6), o + const Offset(6, 6), bold);
          canvas.drawLine(o + const Offset(-6, 6), o + const Offset(6, -6), bold);
        case 'perpendicular':
          canvas.drawLine(o + const Offset(-6, 6), o + const Offset(6, 6), p);
          canvas.drawLine(o + const Offset(-6, 6), o + const Offset(-6, -6), p);
          canvas.drawLine(o + const Offset(-6, 0), o + const Offset(0, 0), p);
          canvas.drawLine(o + const Offset(0, 0), o + const Offset(0, 6), p);
        case 'tangent':
          canvas.drawCircle(o, 5, p);
          canvas.drawLine(o + const Offset(-7, -5), o + const Offset(7, -5), p);
        case 'quadrant':
          canvas.drawPath(
            Path()
              ..moveTo(o.dx, o.dy - 6)
              ..lineTo(o.dx + 6, o.dy)
              ..lineTo(o.dx, o.dy + 6)
              ..lineTo(o.dx - 6, o.dy)
              ..close(),
            p,
          );
        case 'extension':
          canvas.drawLine(o + const Offset(-6, 0), o + const Offset(6, 0), p);
          canvas.drawLine(o + const Offset(0, -6), o + const Offset(0, 6), p);
          canvas.drawCircle(o, 2, p);
        case 'center':
          canvas.drawCircle(o, 5, p);
          canvas.drawLine(o + const Offset(-3, 0), o + const Offset(3, 0), p);
          canvas.drawLine(o + const Offset(0, -3), o + const Offset(0, 3), p);
        default:
          canvas.drawCircle(o, 4, p);
      }
    }
    // cursor crosshair
    final cur = tool?.cursor;
    if (cur != null && c.activeTool != ToolId.select && c.activeTool != ToolId.pan) {
      final o = cam.toScreen(cur);
      final p = Paint()
        ..color = Cad.crosshair
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), p);
      canvas.drawLine(Offset(o.dx, 0), Offset(o.dx, size.height), p);
    }
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

  /// The slope (or aspect) map of the terrain, one pixel per cell.
  void _slopeMap(Canvas canvas, {required bool aspect}) {
    final m = c.slopeMap;
    final img = c.slopeImage(aspect: aspect);
    if (m.isEmpty || img == null) return;
    final b = m.bounds;
    final tl = cam.toScreen(Pt(b.minX, b.maxY)), br = cam.toScreen(Pt(b.maxX, b.minY));
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromPoints(tl, br), Paint()..filterQuality = FilterQuality.none);
  }

  /// Colour key of the slope classes (with the mean and maximum slope) or
  /// of the eight aspect sectors, at the top left.
  void _slopeLegend(Canvas canvas, {required bool aspect}) {
    final m = c.slopeMap;
    final t = c.t;
    const o = Offset(14, 14);
    if (m.isEmpty) {
      _label(canvas, o, t('slope.none'), size: 10, shift: Offset.zero, color: Cad.attention);
      return;
    }
    const box = 14.0;
    if (aspect) {
      _label(canvas, o, t('aspect.legend'), size: 10, shift: Offset.zero);
      const sectors = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];
      for (var k = 0; k < sectors.length; k++) {
        final x = o.dx + k * 34.0;
        canvas.drawRect(Rect.fromLTWH(x, o.dy + 16, box, box), _fill(Color(aspectColor(k * 45.0, 10))));
        _label(canvas, Offset(x + box + 2, o.dy + 17), t('compass.${sectors[k]}'), size: 9, bg: false, shift: Offset.zero, color: Cad.fg70);
      }
      return;
    }
    final (mean, max) = m.meanMax;
    _label(canvas, o, t('slope.legend', {'mean': fmt(mean, 1), 'max': fmt(max, 1)}), size: 10, shift: Offset.zero);
    var lo = 0.0;
    for (var k = 0; k < slopeClasses.length; k++) {
      final (hi, color) = slopeClasses[k];
      final y = o.dy + 16 + k * (box + 2);
      canvas.drawRect(Rect.fromLTWH(o.dx, y, box, box), _fill(Color(color)));
      final range = hi.isInfinite ? '> ${fmt(lo, 0)} %' : '${fmt(lo, 0)}–${fmt(hi, 0)} %';
      _label(canvas, Offset(o.dx + box + 4, y + 1), range, size: 9, bg: false, shift: Offset.zero, color: Cad.fg70);
      lo = hi;
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
      _label(canvas, o, t('dens.none'), size: 10, shift: Offset.zero, color: Cad.attention);
      return;
    }
    final maxR = densogramStops.last.$1;
    for (var k = 0; k < 60; k++) {
      final r = maxR * k / 60;
      canvas.drawRect(Rect.fromLTWH(o.dx + w * k / 60, o.dy + 16, w / 60 + 0.5, h), _fill(Color(densogramColor(r, 1))));
    }
    canvas.drawRect(Rect.fromLTWH(o.dx, o.dy + 16, w, h), _stroke(Cad.fg54, 0.6));
    // with several areas the worst one tells how uniform the design is
    final worst = d.areas.isEmpty ? d.stats : d.areas.map((a) => a.stats).reduce((a, b) => a.cu <= b.cu ? a : b);
    _label(canvas, o, t('dens.legend', {'cu': fmt(worst.cu, 0), 'du': fmt(worst.du, 0)}), size: 10, shift: Offset.zero);
    for (final r in const [0.0, 1.0, 2.0]) {
      final x = o.dx + w * r / maxR;
      _label(canvas, Offset(x, o.dy + 28), r == 0 ? '0' : '×${r.round()}', size: 9, bg: false, shift: Offset(r == 0 ? 0 : (r == maxR ? -12 : -6), 0), color: Cad.fg70);
    }
  }

  /// Paints by colour and width, shared by every painter (callers never
  /// change them).
  static final _strokes = <(Color, double), Paint>{};
  static final _fills = <Color, Paint>{};

  /// The same colour object asks again for the same widths (the ink of a
  /// layer is one object per paint): looked up by identity first.
  static final _strokesSeen = HashMap<Color, Map<double, Paint>>.identity();

  Paint _stroke(Color color, double w) {
    final seen = _strokesSeen[color];
    final fast = seen?[w];
    if (fast != null) return fast;
    if (_strokesSeen.length > 2000) _strokesSeen.clear();
    return (_strokesSeen[color] ??= {})[w] = _strokeOf(color, w);
  }

  Paint _strokeOf(Color color, double w) {
    final key = (color, w);
    final hit = _strokes[key];
    if (hit != null) return hit;
    if (_strokes.length > 4000) _strokes.clear();
    return _strokes[key] = Paint()
      ..color = color
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Paint _fill(Color color) {
    final key = color;
    final hit = _fills[key];
    if (hit != null) return hit;
    if (_fills.length > 4000) _fills.clear();
    return _fills[key] = Paint()..color = color;
  }

  Color _color(Entity e, bool selected, bool hovered) {
    if (selected) return Cad.selection;
    if (hovered) return Cad.hover;
    final x = tint?.call(e);
    if (x != null) return x;
    return _inkOf(e.layer);
  }

  void _grid(Canvas canvas, Size size) {
    final step = cam.gridStep();
    final vis = cam.visible;
    final minor = Paint()
      ..color = Cad.gridMinor
      ..strokeWidth = 1;
    final major = Paint()
      ..color = Cad.gridMajor
      ..strokeWidth = 1;
    final x0 = (vis.minX / step).floor() * step;
    final y0 = (vis.minY / step).floor() * step;
    var count = 0;
    for (var x = x0; x <= vis.maxX && count < 400; x += step, count++) {
      final sx = cam.toScreen(Pt(x, 0)).dx;
      final isMajor = ((x / step).round() % 5) == 0;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), isMajor ? major : minor);
      if (isMajor) _label(canvas, Offset(sx, size.height - 14), fmt(x, 0), size: 9, bg: false, shift: const Offset(2, 0), color: Cad.gridLabel);
    }
    count = 0;
    for (var y = y0; y <= vis.maxY && count < 400; y += step, count++) {
      final sy = cam.toScreen(Pt(0, y)).dy;
      final isMajor = ((y / step).round() % 5) == 0;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), isMajor ? major : minor);
      if (isMajor) _label(canvas, Offset(2, sy), fmt(y, 0), size: 9, bg: false, shift: const Offset(0, -12), color: Cad.gridLabel);
    }
    // axes
    final ax = Paint()
      ..color = Cad.axis
      ..strokeWidth = 1.5;
    final ox = cam.toScreen(Pt.zero);
    canvas.drawLine(Offset(ox.dx, 0), Offset(ox.dx, size.height), ax);
    canvas.drawLine(Offset(0, ox.dy), Offset(size.width, ox.dy), ax);
  }

  void _scaleBar(Canvas canvas, Size size) {
    final step = cam.gridStep();
    final px = step * cam.scale;
    final o = Offset(size.width - px - 20, size.height - 22);
    canvas.drawLine(
      o,
      o + Offset(px, 0),
      Paint()
        ..color = Cad.fg70
        ..strokeWidth = 2,
    );
    canvas.drawLine(o, o + const Offset(0, -5), _fill(Cad.fg70));
    canvas.drawLine(o + Offset(px, 0), o + Offset(px, -5), _fill(Cad.fg70));
    _label(canvas, o, '${fmt(c.units.lengthFromSi(step), step < 1 ? 2 : 0)} ${c.units.lengthLabel}', size: 10, bg: false, shift: Offset(px / 2 - 12, -16), color: Cad.fg70);
  }

  /// A polyline. Strokes no wider than a device pixel are hairlines, which
  /// the GPU draws a whole path of at once; wider ones go segment by
  /// segment with square ends, which the GPU draws as quads (a wide stroked
  /// path is rasterised on the CPU over its whole bounds, pixel by pixel:
  /// on a high-density screen even 1 px lines are 2 device pixels wide).
  void _poly(Canvas canvas, List<Pt> pts, Paint paint, {bool close = false}) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _ring(canvas, cam.toScreen(pts.first), 2, paint);
      return;
    }
    final b = _batch;
    // vertices closer than a fraction of a pixel to the last one kept add
    // nothing to the picture (long lines seen from afar)
    final scr = _screen(pts, b == null ? 0 : _lodPx);
    if (_thin(paint)) {
      final hair = _hair(paint);
      if (b == null) {
        canvas.drawPath(Path()..addPolygon(scr, close), hair);
      } else {
        (b.paths[hair] ??= Path()).addPolygon(scr, close);
      }
      return;
    }
    final sq = _squared(paint);
    final out = b == null ? <double>[] : (b.lines[sq] ??= []);
    for (var i = 1; i < scr.length; i++) {
      out
        ..add(scr[i - 1].dx)
        ..add(scr[i - 1].dy)
        ..add(scr[i].dx)
        ..add(scr[i].dy);
    }
    if (close && scr.length > 2) {
      out
        ..add(scr.last.dx)
        ..add(scr.last.dy)
        ..add(scr.first.dx)
        ..add(scr.first.dy);
    }
    if (b == null) canvas.drawRawPoints(ui.PointMode.lines, Float32List.fromList(out), sq);
  }

  /// True when [paint] strokes no wider than one device pixel (a hairline),
  /// or no wider than a logical pixel in a view packed with linework: on a
  /// high-density screen those are 2 device pixels wide, a width the GPU
  /// has no fast way to draw, and the picture took seconds; seen from
  /// afar they are drawn one device pixel wide instead (a normal project
  /// never gets there and keeps its look).
  bool _thin(Paint paint) => paint.strokeWidth * devicePixelRatio <= 1 || (_dense && paint.strokeWidth <= 1);

  /// The view has more than [denseSegments] vertices of linework.
  bool _dense = false;

  /// Vertices of linework in view past which 1 px lines become hairlines
  /// on a high-density screen.
  static const denseSegments = 40000;

  static final _hairPaints = HashMap<Paint, Paint>.identity();

  /// [paint] as drawn when [_thin]: as it is, or a hairline when it is
  /// wider than a device pixel.
  Paint _hair(Paint paint) {
    if (paint.strokeWidth * devicePixelRatio <= 1) return paint;
    final hit = _hairPaints[paint];
    if (hit != null) return hit;
    if (_hairPaints.length > 4000) _hairPaints.clear();
    return _hairPaints[paint] = Paint()
      ..color = paint.color
      ..strokeWidth = 0
      ..style = PaintingStyle.stroke;
  }

  static final _squaredPaints = HashMap<Paint, Paint>.identity();

  /// [paint] for strokes drawn segment by segment: square ends, so the
  /// segments of a polyline close their corners as the round joins did
  /// (butt ends for translucent ink, so they do not overlap and darken).
  static Paint _squared(Paint paint) {
    final hit = _squaredPaints[paint];
    if (hit != null) return hit;
    if (_squaredPaints.length > 4000) _squaredPaints.clear();
    return _squaredPaints[paint] = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = paint.color.a < 1 ? StrokeCap.butt : StrokeCap.square;
  }

  /// Vertices within this distance (pixels) of the previous one drawn are
  /// left out of the gathered polylines.
  static const _lodPx = 0.6;

  /// [pts] on the screen, without the vertices that lie within [minPx]
  /// pixels of the previous one kept (the first and last always stay).
  List<Offset> _screen(List<Pt> pts, double minPx) {
    final out = <Offset>[];
    final k = cam.scale, cx = cam.center.x, cy = cam.center.y, w2 = cam.size.width / 2, h2 = cam.size.height / 2;
    final min2 = minPx * minPx;
    var lx = 0.0, ly = 0.0;
    final last = pts.length - 1;
    for (var i = 0; i <= last; i++) {
      final p = pts[i];
      final x = (p.x - cx) * k + w2, y = -(p.y - cy) * k + h2;
      if (i > 0 && i < last && min2 > 0) {
        final dx = x - lx, dy = y - ly;
        if (dx * dx + dy * dy < min2) continue;
      }
      out.add(Offset(x, y));
      lx = x;
      ly = y;
    }
    return out;
  }

  /// A straight segment (gathered by paint while a batch is open); a wide
  /// one with square ends (see [_poly]).
  void _seg(Canvas canvas, Offset a, Offset b, Paint paint) {
    final p = _thin(paint) ? _hair(paint) : _squared(paint);
    final batch = _batch;
    if (batch == null) {
      canvas.drawLine(a, b, p);
    } else {
      (batch.lines[p] ??= [])
        ..add(a.dx)
        ..add(a.dy)
        ..add(b.dx)
        ..add(b.dy);
    }
  }

  /// A circle outline: hairline circles gathered in one path, wider ones
  /// one by one (the GPU draws a single stroked circle itself).
  void _ring(Canvas canvas, Offset o, double r, Paint paint) {
    final batch = _batch;
    if (batch == null || paint.color.a < 1 || !_thin(paint)) {
      canvas.drawCircle(o, r, paint);
    } else {
      (batch.paths[_hair(paint)] ??= Path()).addOval(Rect.fromCircle(center: o, radius: r));
    }
  }

  /// A filled dot.
  void _dot(Canvas canvas, Offset o, double r, Color color) {
    final batch = _batch;
    if (batch == null || color.a < 1) {
      canvas.drawCircle(o, r, _fill(color));
    } else {
      (batch.dots[(color, r)] ??= [])
        ..add(o.dx)
        ..add(o.dy);
    }
  }

  /// The batch the current pass gathers into (null: draw at once).
  _Batch? _batch;

  /// Runs [draw] with nothing gathered (what it draws keeps its order).
  void _unbatched(void Function() draw) {
    final b = _batch;
    _batch = null;
    try {
      draw();
    } finally {
      _batch = b;
    }
  }

  /// Runs [draw] over what the pass gathers (at once when nothing is).
  void _over(Canvas canvas, void Function(Canvas canvas) draw) {
    final b = _batch;
    if (b == null) {
      draw(canvas);
    } else {
      b.over.add(draw);
    }
  }

  /// Draws what the batch gathered: outlines, segments and dots, one call
  /// per paint, then the texts over them.
  void _flush(Canvas canvas) {
    final b = _batch;
    _batch = null;
    if (b == null) return;
    for (final e in b.paths.entries) {
      canvas.drawPath(e.value, e.key);
    }
    for (final e in b.lines.entries) {
      canvas.drawRawPoints(ui.PointMode.lines, Float32List.fromList(e.value), e.key);
    }
    for (final e in b.dots.entries) {
      canvas.drawRawPoints(ui.PointMode.points, Float32List.fromList(e.value), _dotPaint(e.key.$1, e.key.$2));
    }
    for (final f in b.over) {
      f(canvas);
    }
  }

  static final _dotPaints = <(Color, double), Paint>{};

  /// Round points [r] in radius: a batch of dots is one call.
  static Paint _dotPaint(Color color, double r) {
    final key = (color, r);
    final hit = _dotPaints[key];
    if (hit != null) return hit;
    if (_dotPaints.length > 2000) _dotPaints.clear();
    return _dotPaints[key] = Paint()
      ..color = color
      ..strokeWidth = 2 * r
      ..strokeCap = StrokeCap.round;
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
    canvas.drawPath(path, _fill(color.withValues(alpha: selected ? 0.14 : 0.07)));
    _poly(canvas, outline, _stroke(color.withValues(alpha: 0.9), selected ? 1.5 : 1), close: true);
    _seg(canvas, cam.toScreen(p.center), cam.toScreen(p.endPoint), _stroke(color, selected ? 3.5 : 2.5));
    if (cam.scale * p.spanLengthM > 6) {
      final tower = _fill(color);
      for (final t in p.towerPositions()) {
        canvas.drawRect(Rect.fromCenter(center: cam.toScreen(t), width: 6, height: 6), tower);
      }
    }
    final o = cam.toScreen(p.center);
    canvas.drawCircle(o, 6, _fill(color));
    canvas.drawCircle(o, 6, _stroke(Colors.black, 1));
    if (c.showLabels) {
      var s = p.name;
      final r = c.results?.pivots[p.id];
      if (r != null) {
        final u = c.units;
        s += '  ${fmt(u.flowFromSi(r.flow), 1)} ${u.flowLabel} / ${fmt(u.pressureFromHead(r.inletHead), 1)} ${u.pressureLabel}';
      }
      _label(canvas, o, s, size: 11, color: r != null && r.deficit > 0.01 ? Cad.warning : color, shift: const Offset(9, -8));
    }
  }

  void _image(Canvas canvas, ImageEntity e) {
    final img = c.imageFor(e);
    final corners = e.corners;
    if (img == null) {
      _poly(canvas, corners, _stroke(Cad.fg24, 1), close: true);
      _label(canvas, cam.toScreen(corners[3]), e.name.isEmpty ? e.source : e.name, size: 10, shift: const Offset(4, 4), color: Cad.fg54);
      return;
    }
    // affine from image pixels to screen: (0,0) → top-left corner
    final tl = cam.toScreen(corners[3]), tr = cam.toScreen(corners[2]), bl = cam.toScreen(corners[0]);
    final w = img.width.toDouble(), h = img.height.toDouble();
    final a = (tr.dx - tl.dx) / w, b = (tr.dy - tl.dy) / w;
    final cc = (bl.dx - tl.dx) / h, d = (bl.dy - tl.dy) / h;
    canvas.save();
    canvas.transform(Float64List.fromList([a, b, 0, 0, cc, d, 0, 0, 0, 0, 1, 0, tl.dx, tl.dy, 0, 1]));
    canvas.drawImage(img, Offset.zero, _fill(Colors.white.withValues(alpha: e.opacity.clamp(0.05, 1.0))));
    canvas.restore();
  }

  void _hatch(Canvas canvas, HatchEntity h) {
    final selected = c.selection.contains(h.id);
    final color = selected ? Cad.selection : _inkOf(h.layer);
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
      canvas.drawPath(path, _fill(color.withValues(alpha: 0.45)));
    } else {
      final paint = _stroke(color.withValues(alpha: 0.8), 0.8);
      // avoid drawing thousands of lines when zoomed out
      final spacingPx = h.spacing * cam.scale;
      if (spacingPx >= 2.5) {
        for (final l in h.patternLines()) {
          _seg(canvas, cam.toScreen(l[0]), cam.toScreen(l[1]), paint);
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
        canvas.drawPath(path, _fill(color.withValues(alpha: 0.25)));
      }
    }
    _poly(canvas, h.points, _stroke(color, selected ? 1.5 : 0.8), close: true);
  }

  void _area(Canvas canvas, AreaEntity a) {
    final selected = c.selection.contains(a.id);
    final color = _inkOf(a.layer);
    // 1.6.0 MOD: the islands are cut out of the fill (even-odd rule)
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final ring in [a.points, ...a.holes]) {
      if (ring.isEmpty || (!identical(ring, a.points) && ring.length < 3)) continue;
      final f = cam.toScreen(ring.first);
      path.moveTo(f.dx, f.dy);
      for (final p in ring.skip(1)) {
        final s = cam.toScreen(p);
        path.lineTo(s.dx, s.dy);
      }
      path.close();
    }
    canvas.drawPath(path, _fill(color.withValues(alpha: selected ? 0.35 : 0.18)));
    final edge = _stroke(selected ? Cad.selection : color.withValues(alpha: 0.9), 1);
    _poly(canvas, a.points, edge, close: true);
    for (final h in a.holes) {
      if (h.length >= 3) _poly(canvas, h, edge, close: true);
    }
    if (c.showLabels) {
      final cen = cam.toScreen(polygonCentroid(a.points));
      _label(canvas, cen, '${a.name}  ${fmt(a.area / 10000, 2)} ha', size: 11, shift: const Offset(-20, -6));
    }
  }

  Color _velocityColor(double v, double vmax) {
    final t = _ramp((v / math.max(vmax, 1e-6)).clamp(0.0, 1.5));
    // on the light canvas the ramps take the darker inks (see Cad.ink)
    final blue = Cad.ink(const Color(0xFF42A5F5)), green = Cad.ink(const Color(0xFF66BB6A)), orange = Cad.ink(const Color(0xFFFFA726));
    if (t <= 0.5) return Color.lerp(blue, green, t / 0.5)!;
    if (t <= 1.0) return Color.lerp(green, orange, (t - 0.5) / 0.5)!;
    return Color.lerp(orange, const Color(0xFFE53935), (t - 1.0) / 0.5)!;
  }

  /// [t] on the colour ramps in steps of 1/64 (beyond what the eye tells
  /// apart), so the results take a few dozen paints.
  static double _ramp(double t) => (t * 64).roundToDouble() / 64;

  Color _pressureColor(double p, double lo, double hi) {
    final green = Cad.ink(const Color(0xFF66BB6A));
    if (hi <= lo) return green;
    if (p < lo) return const Color(0xFFE53935);
    if (p > hi) return const Color(0xFFAB47BC);
    final t = _ramp((p - lo) / (hi - lo));
    return Color.lerp(Cad.ink(const Color(0xFF29B6F6)), green, t)!;
  }

  void _pipe(Canvas canvas, List<Pt> pts, Entity e, List<PipeSegmentResult>? res, double width, Color color, bool selected) {
    if (pts.length < 2) return;
    final overlay = c.overlay;
    if (res != null && res.isNotEmpty && (overlay == OverlayMode.velocity || overlay == OverlayMode.pressure) && !selected) {
      final vmax = e is PipeEntity && e.scope == HydraulicScope.mainline ? c.project.params.maxMainlineVelocity : c.project.params.maxZoneVelocity;
      // consecutive segments of one colour go as one line
      Paint? runPaint;
      final run = <Pt>[];
      void endRun() {
        final p = runPaint;
        if (p != null && run.length >= 2) {
          if (run.length == 2) {
            _seg(canvas, cam.toScreen(run[0]), cam.toScreen(run[1]), p);
          } else {
            _poly(canvas, run, p);
          }
        }
        run.clear();
      }

      for (final r in res) {
        final col = overlay == OverlayMode.velocity ? _velocityColor(r.velocity, vmax) : _pressureColor((r.pressureStart + r.pressureEnd) / 2, 0, math.max(60, r.pressureRating));
        final paint = _stroke(col, width + 1);
        if (!identical(paint, runPaint) || run.isEmpty || run.last != r.a) {
          endRun();
          runPaint = paint;
          run.add(r.a);
        }
        run.add(r.b);
      }
      endRun();
    } else {
      _poly(canvas, pts, _stroke(color, selected ? width + 1.5 : width));
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
    } else if (c.showLabels && res != null && res.isNotEmpty && _rules('pipes').isNotEmpty) {
      final mid = cam.toScreen(pointAlongPolyline(pts, polylineLength(pts) / 2));
      _ruleLabels(canvas, mid, 'pipes', (f) => LabelRule.ofPipe(f, res));
    } else if (c.showLabels && res != null && res.isNotEmpty && cam.scale > 2 && e is PipeEntity) {
      final r = res.first;
      final mid = pointAlongPolyline(pts, polylineLength(pts) / 2);
      final u = c.units;
      _label(canvas, cam.toScreen(mid), '${fmt(u.flowFromSi(r.flow.abs()), 1)} ${u.flowLabel}  ${fmt(r.velocity, 2)} m/s', size: 9, shift: const Offset(4, -6));
    }
  }

  /// The enabled conditional label rules of [target] (once per paint).
  List<LabelRule> _rules(String target) => _ruleCache[target] ??= [
    for (final r in c.project.labelRules)
      if (r.enabled && r.target == target) r,
  ];
  final Map<String, List<LabelRule>> _ruleCache = {};

  /// The labels of the rules of [target] that hold for the values [valueOf]
  /// gives, stacked from [at].
  void _ruleLabels(Canvas canvas, Offset at, String target, double? Function(String field) valueOf) {
    final u = c.units;
    var dy = -6.0;
    for (final r in _rules(target)) {
      final v = valueOf(r.field);
      if (v == null || !v.isFinite || !r.holds(v)) continue;
      final (shown, unit) = LabelRule.display(r.field, v, u);
      _label(canvas, at, '${c.t('lbl.short.${r.field}')} ${fmt(shown, r.field == 'velocity' ? 2 : 1)} $unit', size: 9.5, color: Cad.ink(Color(r.color)), shift: Offset(4, dy), bg: true);
      dy -= 13;
    }
  }

  /// Allowable feed (submain) positions along a lateral: green where the
  /// window is met, red where not; the best position gets a marker.
  void _feed(Canvas canvas, String id, List<Pt> pts) {
    final res = c.feedEnvelope[id];
    if (res == null || res.isEmpty || pts.length < 2) return;
    final total = polylineLength(pts);
    final ok = _stroke(Cad.ok, 5);
    final bad = _stroke(Cad.unconnected.withValues(alpha: 0.6), 5);
    for (var i = 1; i < res.length; i++) {
      final a = pointAlongPolyline(pts, res[i - 1].fraction * total), b = pointAlongPolyline(pts, res[i].fraction * total);
      _seg(canvas, cam.toScreen(a), cam.toScreen(b), res[i - 1].ok && res[i].ok ? ok : bad);
    }
    var best = res.first;
    for (final r in res) {
      if (r.variation < best.variation) best = r;
    }
    final o = cam.toScreen(pointAlongPolyline(pts, best.fraction * total));
    // the marker over the envelope
    _over(canvas, (cv) {
      cv.drawCircle(o, 5, _fill(Cad.ok));
      cv.drawCircle(o, 5, _stroke(Colors.black, 1));
      if (cam.scale > 1.5) _label(cv, o, '${(best.fraction * 100).round()} %  Δ${fmt(c.units.pressureFromHead(best.variation), 1)}', size: 9, shift: const Offset(6, -16));
    });
  }

  /// The outlets of a sprayline, alike in every view: the pressure overlay
  /// only gives each one the colour of its pressure.
  void _spraylineOutlets(Canvas canvas, SpraylineEntity s, List<OutletResult>? res, Color color) {
    if (cam.scale < 0.6) return;
    final nozzle = c.project.catalog.outlet(s.outletSpecId)?.nozzle(s.nozzleId);
    final radius = nozzle?.curve.radius(s.headM) ?? 0;
    final positions = s.outletPositions();
    final ink = _inkOf(Layers.outlets);
    final pR = _stroke(_inkOf(Layers.wettedRadii), 0.7);
    final showR = c.showWettedRadii && radius > 0 && _layer(Layers.wettedRadii).visible && positions.length < 3000 && cam.scale > 1.2;
    final groups = c.overlay == OverlayMode.pressure && res != null && res.isNotEmpty ? _inOrder(res, (x) => x.index) : null;
    final r = math.max(2.0, math.min(0.25, 0.35 * s.spacing) * cam.scale);
    var g = 0, gFill = -1;
    var fill = ink;
    for (var i = 0; i < positions.length; i++) {
      final o = cam.toScreen(positions[i]);
      if (groups != null) {
        while (g < groups.length - 1 && groups[g].index + groups[g].count <= i) {
          g++;
        }
        if (g != gFill) fill = _pressureColor(groups[gFill = g].pressure, groups[g].allowedMin, groups[g].allowedMax);
      }
      _dot(canvas, o, r, fill);
      if (showR) _ring(canvas, o, radius * cam.scale, pR);
    }
  }

  /// The dots of the emitters of a drip line stand at least this far apart
  /// on the screen (pixels).
  static const _emitterGapPx = 8.0;

  /// [list] ordered by [key] (as it comes from the design, mostly). The
  /// outlet results of a line go by [OutletResult.index]: the design
  /// computes the outlets of a long line in groups, from that one on,
  /// [OutletResult.count] of them.
  static List<T> _inOrder<T>(List<T> list, int Function(T) key) {
    for (var i = 1; i < list.length; i++) {
      if (key(list[i]) < key(list[i - 1])) return [...list]..sort((a, b) => key(a).compareTo(key(b)));
    }
    return list;
  }

  /// The emitters of a drip line, where the design places them (every
  /// emitter spacing from its start), as dots a few pixels across on the
  /// line, alike in every view: in the colour of the line where they sit
  /// (by velocity, the layer's...) or, with the pressure overlay, in the
  /// colour of their pressure within the allowed range. Too close together
  /// on the screen, one in a few is drawn (counted from the start, so they
  /// stay put while the view moves).
  void _emitters(Canvas canvas, TapeEntity t, List<PipeSegmentResult>? segs, List<OutletResult>? res, Color color, bool selected) {
    final spacing = c.project.catalog.tape(t.tapeSpecId)?.emitterSpacingM ?? 0;
    if (!(spacing > 0) || cam.scale < 0.5) return;
    final n = (t.length / spacing).floor();
    final step = math.max(1, (_emitterGapPx / (spacing * cam.scale)).ceil());
    // dot k (from 1) is emitter k × step − 1 (from 0), k × every from the start
    final every = step * spacing, dots = n ~/ step;
    final groups = c.overlay == OverlayMode.pressure && res != null && res.isNotEmpty ? _inOrder(res, (x) => x.index) : null;
    // the result segments along the line, for the velocity colours
    final speeds = groups == null && !selected && c.overlay == OverlayMode.velocity && segs != null && segs.isNotEmpty ? _inOrder(segs, (x) => x.segmentIndex) : null;
    final vmax = c.project.params.maxZoneVelocity;
    final r = (0.25 * every * cam.scale).clamp(2.0, 4.0);
    final view = (Offset.zero & cam.size).inflate(r);
    // the dots go straight into the batch, by colour (a line has few)
    final batch = _batch;
    var fill = color;
    List<double>? into;
    var current = false; // [into] gathers the dots of [fill]
    void colour(Color col) {
      fill = col;
      current = false;
    }

    final pts = t.points;
    var k = 1, g = 0, s = 0, gFill = -1, sFill = -1;
    var acc = 0.0, segEnd = speeds?.first.length ?? 0.0;
    for (var i = 1; i < pts.length && k <= dots; i++) {
      final a = pts[i - 1], b = pts[i];
      final len = a.distanceTo(b);
      final end = acc + len;
      // only the stretch of this piece in view
      final sa = cam.toScreen(a), sb = cam.toScreen(b);
      final cut = len > 0 ? _clip(sa, sb, view) : null;
      if (cut != null) {
        k = math.max(k, ((acc + cut.$1 * len) / every).ceil());
        final last = math.min(dots, ((acc + cut.$2 * len) / every + 1e-9).floor());
        for (; k <= last; k++) {
          final d = k * every;
          if (groups != null) {
            final j = k * step - 1;
            while (g < groups.length - 1 && groups[g].index + groups[g].count <= j) {
              g++;
            }
            if (g != gFill) colour(_pressureColor(groups[gFill = g].pressure, groups[g].allowedMin, groups[g].allowedMax));
          } else if (speeds != null) {
            while (s < speeds.length - 1 && segEnd < d) {
              segEnd += speeds[++s].length;
            }
            if (s != sFill) colour(_velocityColor(speeds[sFill = s].velocity, vmax));
          }
          final f = ((d - acc) / len).clamp(0.0, 1.0);
          final x = sa.dx + (sb.dx - sa.dx) * f, y = sa.dy + (sb.dy - sa.dy) * f;
          if (!current) {
            into = batch == null || fill.a < 1 ? null : (batch.dots[(fill, r)] ??= []);
            current = true;
          }
          final list = into;
          if (list == null) {
            canvas.drawCircle(Offset(x, y), r, _fill(fill));
          } else {
            list
              ..add(x)
              ..add(y);
          }
        }
      }
      k = math.max(k, (end / every + 1e-9).floor() + 1);
      acc = end;
    }
  }

  /// The part of the segment [a]–[b] inside [rect], as the fractions of the
  /// segment where it starts and ends (null when it misses the rectangle).
  static (double, double)? _clip(Offset a, Offset b, Rect rect) {
    var t0 = 0.0, t1 = 1.0;
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    for (final (p, q) in [(-dx, a.dx - rect.left), (dx, rect.right - a.dx), (-dy, a.dy - rect.top), (dy, rect.bottom - a.dy)]) {
      if (p == 0) {
        if (q < 0) return null;
      } else {
        final t = q / p;
        if (p < 0) {
          if (t > t1) return null;
          if (t > t0) t0 = t;
        } else {
          if (t < t0) return null;
          if (t < t1) t1 = t;
        }
      }
    }
    return (t0, t1);
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
        canvas.drawPath(path, _fill(col));
        canvas.drawPath(path, _stroke(Colors.black, 1));
        _label(canvas, s, '${up ? '▲' : '▼'} ${fmt(u.pressureFromHead(o.pressure), 1)} ${u.pressureLabel}', size: 10, color: col, shift: Offset(9, up ? -20 : 4));
      }

      marker(mn, mn.inWindow ? Cad.ink(const Color(0xFF29B6F6)) : Cad.unconnected, false);
      marker(mx, mx.inWindow ? const Color(0xFFAB47BC) : Cad.warning, true);
    }
  }

  void _outlet(Canvas canvas, OutletEntity o, List<OutletResult>? res, Color color, bool selected) {
    final s = cam.toScreen(o.position);
    final nozzle = c.project.catalog.outlet(o.outletSpecId)?.nozzle(o.nozzleId);
    final r = math.max(3.0, 0.4 * cam.scale);
    final radius = nozzle?.curve.radius(o.headM) ?? 0;
    if (c.showWettedRadii && radius > 0 && _layer(Layers.wettedRadii).visible) {
      final wr = _inkOf(Layers.wettedRadii);
      final arc = nozzle!.effectiveArcDeg(o.arcDeg);
      final start = -degToRad(o.orientationDeg);
      final rect = Rect.fromCircle(center: s, radius: radius * cam.scale);
      if (arc >= 360) {
        canvas.drawCircle(s, radius * cam.scale, _fill(wr.withValues(alpha: 0.12)));
        _ring(canvas, s, radius * cam.scale, _stroke(wr, 0.8));
      } else {
        canvas.drawArc(rect, start - degToRad(arc), degToRad(arc), true, _fill(wr.withValues(alpha: 0.15)));
        canvas.drawArc(rect, start - degToRad(arc), degToRad(arc), true, _stroke(wr, 0.8));
      }
    }
    var fill = color;
    if (c.overlay == OverlayMode.pressure && res != null && res.isNotEmpty) fill = _pressureColor(res.first.pressure, res.first.allowedMin, res.first.allowedMax);
    _dot(canvas, s, r, fill);
    if (selected) canvas.drawCircle(s, r + 3, _stroke(Cad.selection, 1.5));
    if (c.showLabels && res != null && res.isNotEmpty && _rules('outlets').isNotEmpty) {
      _ruleLabels(canvas, s + Offset(r - 2, 0), 'outlets', (f) => LabelRule.ofOutlet(f, res));
    } else if (c.showLabels && res != null && res.isNotEmpty && cam.scale > 3) {
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
    canvas.drawPath(path, _fill(color.withValues(alpha: 0.9)));
    if (selected) canvas.drawCircle(s, r + 3, _stroke(Cad.selection, 1.5));
    if (c.showLabels && _rules('valves').isNotEmpty) _ruleLabels(canvas, s + Offset(r + 2, 14), 'valves', (f) => LabelRule.ofValve(f, c.results?.zones[v.id]));
    if (c.showLabels) {
      final z = c.results?.zones[v.id];
      var txt = v.zoneName;
      if (z != null) {
        final u = c.units;
        txt += '  ${fmt(u.flowFromSi(z.totalFlow), 1)} ${u.flowLabel} / ${fmt(u.pressureFromHead(z.requiredUpstreamHead), 1)} ${u.pressureLabel}';
      }
      _label(canvas, s, txt, size: 10, color: z != null && !z.withinWindow ? Cad.warning : color, shift: Offset(r + 3, -7));
      // wiring: station, station wire and solenoid voltage
      final run = c.results?.electrical?.runOf(v.id);
      if (run != null && cam.scale > 0.8) {
        final wire = c.project.catalog.wire(run.stationWireId);
        final w = wire == null ? '' : '  ${fmt(wire.sectionMm2, wire.sectionMm2 < 10 ? 1 : 0)} mm²';
        _label(
          canvas,
          s,
          '${run.station == 0 ? c.t('elec.masterTag') : c.t('elec.stationTag', {'n': '${run.station}'})}$w  ${fmt(run.volts, 1)} V',
          size: 9,
          color: run.ok ? Cad.wireOk : Cad.warning,
          shift: Offset(r + 3, 7),
        );
      }
    }
  }

  void _supply(Canvas canvas, WaterSupplyEntity w, Color color, bool selected) {
    final s = cam.toScreen(w.position);
    final r = math.max(8.0, 1.3 * cam.scale);
    canvas.drawRect(Rect.fromCenter(center: s, width: 2 * r, height: 2 * r), _fill(color.withValues(alpha: 0.9)));
    final tp = _text('W', size: math.max(9, r), color: Colors.black, weight: FontWeight.bold);
    tp.paint(canvas, s - Offset(tp.width / 2, tp.height / 2));
    if (selected) canvas.drawCircle(s, r + 4, _stroke(Cad.selection, 1.5));
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
    canvas.drawCircle(s, r, _fill(color.withValues(alpha: 0.9)));
    final tp = _text('P', size: math.max(9, r), color: Colors.black, weight: FontWeight.bold);
    tp.paint(canvas, s - Offset(tp.width / 2, tp.height / 2));
    if (selected) canvas.drawCircle(s, r + 4, _stroke(Cad.selection, 1.5));
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
    canvas.drawPath(path, _fill(color.withValues(alpha: 0.9)));
    if (selected) canvas.drawCircle(s, r + 4, _stroke(Cad.selection, 1.5));
    if (c.showLabels && cam.scale > 1.5) _label(canvas, s, c.project.catalog.valve(m.valveSpecId)?.name ?? '', size: 9, color: color, shift: Offset(r + 3, -22));
  }

  void _dimension(Canvas canvas, DimensionEntity d, Color color) {
    final n = d.normal * d.offset;
    final a = cam.toScreen(d.a), b = cam.toScreen(d.b), a2 = cam.toScreen(d.a + n), b2 = cam.toScreen(d.b + n);
    final p = _stroke(color, 1);
    _seg(canvas, a, a2, p);
    _seg(canvas, b, b2, p);
    _seg(canvas, a2, b2, p);
    final mid = Offset((a2.dx + b2.dx) / 2, (a2.dy + b2.dy) / 2);
    _label(canvas, mid, '${fmt(c.units.lengthFromSi(d.length))} ${c.units.lengthLabel}', size: 10, color: color, shift: const Offset(-14, -14));
  }

  void _angular(Canvas canvas, AngularDimensionEntity d, Color color) {
    final p = _stroke(color, 1);
    _seg(canvas, cam.toScreen(d.vertex), cam.toScreen(d.a), p);
    _seg(canvas, cam.toScreen(d.vertex), cam.toScreen(d.b), p);
    _poly(canvas, d.arcPoints(48), p);
    _label(canvas, cam.toScreen(d.textPoint), '${fmt(d.angleDeg, 1)}°', size: 10, color: color, shift: const Offset(-10, -7));
  }

  void _radial(Canvas canvas, RadialDimensionEntity d, Color color) {
    final p = _stroke(color, 1);
    final a = cam.toScreen(d.start), b = cam.toScreen(d.point);
    canvas.drawLine(a, b, p);
    _arrowHead(canvas, a, b, color);
    if (d.diameter) _arrowHead(canvas, b, a, color);
    canvas.drawCircle(cam.toScreen(d.center), 2, _fill(color));
    final m = cam.toScreen(d.diameter ? d.center : Pt.lerp(d.center, d.point, 0.5));
    _label(canvas, m, '${d.diameter ? 'Ø' : 'R'} ${fmt(c.units.lengthFromSi(d.value))} ${c.units.lengthLabel}', size: 10, color: color, shift: const Offset(4, -14));
  }

  void _ordinate(Canvas canvas, OrdinateDimensionEntity d, Color color) {
    _poly(canvas, d.leader, _stroke(color, 1));
    canvas.drawCircle(cam.toScreen(d.point), 2, _fill(color));
    final e = cam.toScreen(d.leaderEnd);
    _label(canvas, e, '${d.xAxis ? 'X' : 'Y'} ${fmt(c.units.lengthFromSi(d.value))}', size: 10, color: color, shift: d.xAxis ? const Offset(-12, -16) : const Offset(4, -7));
  }

  /// Wire route: a dashed line (the routes of the valve wiring).
  /// Revision cloud: the scalloped outline and its tag in a triangle at the
  /// top-left vertex.
  void _revisionCloud(Canvas canvas, RevisionCloudEntity rc, Color color, bool selected) {
    if (rc.points.length < 3) {
      _poly(canvas, rc.points, _stroke(color, 1));
      return;
    }
    _poly(canvas, rc.scallops(segmentsPerArc: cam.scale * rc.effectiveArc > 24 ? 8 : 4), _stroke(color, selected ? 2.2 : 1.4));
    if (rc.revision.isEmpty) return;
    final top = rc.points.reduce((a, b) => (b.y > a.y || (b.y == a.y && b.x < a.x)) ? b : a);
    final o = cam.toScreen(top) + const Offset(-10, -22);
    final tri = Path()
      ..moveTo(o.dx, o.dy - 9)
      ..lineTo(o.dx + 9, o.dy + 7)
      ..lineTo(o.dx - 9, o.dy + 7)
      ..close();
    canvas.drawPath(tri, _fill(Cad.canvas.withValues(alpha: 0.85)));
    canvas.drawPath(tri, _stroke(color, 1.4));
    _label(canvas, o, rc.revision, color: color, size: 9, bg: false, shift: const Offset(-3, -3));
  }

  /// Review comment: a numbered balloon pin; the text shows on hover and
  /// selection; resolved comments are dimmed.
  void _comment(Canvas canvas, CommentEntity cm, Color color, bool selected, bool hovered) {
    final o = cam.toScreen(cm.position);
    final c0 = cm.resolved ? color.withValues(alpha: 0.4) : color;
    final balloon = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + 4, o.dy - 6)
      ..lineTo(o.dx + 14, o.dy - 6)
      ..quadraticBezierTo(o.dx + 18, o.dy - 6, o.dx + 18, o.dy - 10)
      ..lineTo(o.dx + 18, o.dy - 20)
      ..quadraticBezierTo(o.dx + 18, o.dy - 24, o.dx + 14, o.dy - 24)
      ..lineTo(o.dx - 2, o.dy - 24)
      ..quadraticBezierTo(o.dx - 6, o.dy - 24, o.dx - 6, o.dy - 20)
      ..lineTo(o.dx - 6, o.dy - 10)
      ..quadraticBezierTo(o.dx - 6, o.dy - 6, o.dx - 2, o.dy - 6)
      ..close();
    canvas.drawPath(balloon, _fill(c0.withValues(alpha: cm.resolved ? 0.25 : 0.85)));
    canvas.drawPath(balloon, _stroke(selected ? Cad.selection : c0, selected ? 1.8 : 1));
    if (selected || hovered) {
      final head = cm.author.isEmpty ? '' : '${cm.author}${cm.date.isEmpty ? '' : ' · ${cm.date}'}\n';
      _label(canvas, o, '$head${cm.text}', size: 10, color: cm.resolved ? Cad.fg54 : Cad.commentText, shift: const Offset(22, -24));
    }
  }

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
        _seg(canvas, a + u * t, a + u * math.min(len, t + dash), paint);
      }
    }
  }

  /// Controller: a box with a clock face; after the design, the stations
  /// used over the stations it has.
  void _controller(Canvas canvas, ControllerEntity k, Color color, bool selected) {
    final s = cam.toScreen(k.position);
    final r = math.max(8.0, 1.0 * cam.scale);
    final rect = Rect.fromCenter(center: s, width: 2 * r, height: 2 * r);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.25)), _fill(color.withValues(alpha: 0.9)));
    canvas.drawCircle(s, r * 0.55, _stroke(Colors.black, 1.2));
    canvas.drawLine(s, s + Offset(0, -r * 0.4), _stroke(Colors.black, 1.2));
    canvas.drawLine(s, s + Offset(r * 0.3, 0), _stroke(Colors.black, 1.2));
    if (selected) canvas.drawRect(rect.inflate(4), _stroke(Cad.selection, 1.5));
    if (c.showLabels) {
      final duty = c.results?.electrical?.controllers.where((d) => d.controllerId == k.id).firstOrNull;
      final txt = duty == null ? k.name : '${k.name}  ${duty.used}/${k.stations}';
      _label(canvas, s, txt, size: 10, color: duty != null && duty.overloaded ? Cad.warning : color, shift: Offset(r + 3, -7));
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
    canvas.drawPath(path, _fill(color));
  }

  void _worldText(Canvas canvas, Pt pos, String text, double height, Color color, double rotationDeg) {
    final px = height * cam.scale;
    if (px < 3) {
      _dot(canvas, cam.toScreen(pos), 1.5, color);
      return;
    }
    final b = _batch;
    if (b != null) {
      // over the linework, with the labels
      b.over.add((cv) => _worldText(cv, pos, text, height, color, rotationDeg));
      return;
    }
    // laid out once at a reference size and scaled to the zoom
    final tp = _cachedText(
      'world|$text|${color.toARGB32()}',
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: _worldTextSize, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    final o = cam.toScreen(pos);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(-degToRad(rotationDeg));
    canvas.scale(px.clamp(3, 400) / _worldTextSize);
    tp.paint(canvas, Offset(0, -tp.height));
    canvas.restore();
  }

  /// Font size drawing texts are laid out at before scaling.
  static const _worldTextSize = 64.0;

  // ---------------------------------------------------------------- marks for the AI

  /// The dark edge and text of the marks for the AI; a pin's head rises
  /// [_pinRise] px above its tip, [_pinHead] px in radius.
  static const _markDark = Color(0xFF101010);
  static const _pinRise = 19.0, _pinHead = 7.5;

  /// The user's marks for the AI assistant (ai_marks.dart) in orange with a
  /// dark edge, so they read on the dark and the light canvas and over
  /// aerial imagery: a pin at a point, a thick line with its vertices, each
  /// with a tag of its label and note. Then the mark the mark tool is
  /// placing: the pin under the cursor, or the line so far.
  void _aiMarks(Canvas canvas) {
    for (final m in c.aiMarks.marks) {
      final pts = [for (final p in m.points) cam.toScreen(p)];
      if (m.isPoint) {
        _markPin(canvas, pts.first);
        _markTag(canvas, m.label, m.note, pts.first.translate(0, -_pinRise), _pinTagWays, gap: _pinHead + 3);
      } else {
        _markLine(canvas, pts);
        _markTag(canvas, m.label, m.note, pts.first, _lineTagWays(pts));
      }
    }
    final t = tool;
    if (t is! AiMarkTool) return;
    final next = c.aiMarks.nextLabel();
    final cur = t.cursor == null ? null : cam.toScreen(t.cursor!);
    if (!t.line) {
      // not over the pin just placed (a tap leaves the cursor on it)
      final last = c.aiMarks.marks.lastOrNull;
      if (cur == null || (last != null && last.isPoint && (cam.toScreen(last.points.first) - cur).distance < 4)) return;
      _markPin(canvas, cur, alpha: 0.55);
      _markTag(canvas, next, '', cur.translate(0, -_pinRise), _pinTagWays, gap: _pinHead + 3, alpha: 0.55);
      return;
    }
    final pts = [for (final p in t.pts) cam.toScreen(p)];
    if (pts.isEmpty) {
      if (cur != null) _markDot(canvas, cur, alpha: 0.55);
      return;
    }
    if (cur != null) _markBand(canvas, pts.last, cur);
    _markLine(canvas, pts, alpha: 0.85);
    _markTag(canvas, next, '', pts.first, _lineTagWays([...pts, ?cur]), alpha: 0.85);
  }

  /// A map pin with its tip at [p].
  void _markPin(Canvas canvas, Offset p, {double alpha = 1}) {
    final head = p.translate(0, -_pinRise);
    // the sides are tangent to the head
    final b = math.acos(_pinHead / _pinRise), a0 = math.pi / 2 + b;
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo(head.dx + _pinHead * math.cos(a0), head.dy + _pinHead * math.sin(a0))
      ..arcTo(Rect.fromCircle(center: head, radius: _pinHead), a0, 2 * math.pi - 2 * b, false)
      ..close();
    canvas.drawPath(path, _fill(aiMarkColor.withValues(alpha: alpha)));
    canvas.drawPath(path, _stroke(_markDark.withValues(alpha: alpha), 1.5));
    canvas.drawCircle(head, 2.6, _fill(_markDark.withValues(alpha: alpha)));
  }

  /// A line mark: orange over a dark casing, a dot at each vertex.
  void _markLine(Canvas canvas, List<Offset> pts, {double alpha = 1}) {
    if (pts.length >= 2) {
      final path = Path()..addPolygon(pts, false);
      canvas.drawPath(path, _stroke(_markDark.withValues(alpha: 0.85 * alpha), 7.5));
      canvas.drawPath(path, _stroke(aiMarkColor.withValues(alpha: alpha), 4));
    }
    for (final o in pts) {
      _markDot(canvas, o, alpha: alpha);
    }
  }

  void _markDot(Canvas canvas, Offset o, {double alpha = 1}) {
    canvas.drawCircle(o, 5, _fill(_markDark.withValues(alpha: alpha)));
    canvas.drawCircle(o, 3.4, _fill(aiMarkColor.withValues(alpha: alpha)));
  }

  /// The segment from the last vertex of the line being marked to the
  /// cursor, dashed.
  void _markBand(Canvas canvas, Offset a, Offset b) {
    final d = b - a, len = d.distance;
    if (len < 1) return;
    final edge = _stroke(_markDark.withValues(alpha: 0.5), 5.5), ink = _stroke(aiMarkColor.withValues(alpha: 0.8), 3);
    for (var s = 0.0; s < len; s += 12) {
      final p = a + d * (s / len), q = a + d * (math.min(s + 7, len) / len);
      canvas.drawLine(p, q, edge);
      canvas.drawLine(p, q, ink);
    }
  }

  /// Where the tag of a pin goes, by preference: right of its head, left,
  /// above.
  static const _pinTagWays = [Offset(1, 0), Offset(-1, 0), Offset(0, -1)];

  /// Where the tag of a line goes, by preference: out of the line at its
  /// first vertex, across it (above first), back along it.
  static List<Offset> _lineTagWays(List<Offset> pts) {
    var away = const Offset(0.7071, -0.7071);
    for (final o in pts.skip(1)) {
      final d = pts.first - o;
      if (d.distance > 1) {
        away = d / d.distance;
        break;
      }
    }
    final across = [Offset(away.dy, -away.dx), Offset(-away.dy, away.dx)]..sort((a, b) => a.dy.compareTo(b.dy));
    return [away, ...across, -away];
  }

  /// The tag of a mark, its label in bold and its note (shortened), dark on
  /// orange, [gap] px from [anchor] the first of [ways] that keeps it whole
  /// in the view (or the picture) when the mark is in it.
  void _markTag(Canvas canvas, String label, String note, Offset anchor, List<Offset> ways, {double gap = 7, double alpha = 1}) {
    final n = note.trim().characters;
    final short = n.length > 20 ? '${n.take(19)}…' : n.toString();
    final tp = _cachedText('mark|$label|$short|$alpha', () {
      final ink = _markDark.withValues(alpha: alpha);
      return TextPainter(
        text: TextSpan(
          style: TextStyle(fontSize: 11, color: ink),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            if (short.isNotEmpty) TextSpan(text: ' $short'),
          ],
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    });
    final w = tp.width + 8, h = tp.height + 2;
    Rect boxTowards(Offset dir) {
      // along the larger of the two directions, so the tag clears the anchor
      final k = math.max(dir.dx.abs(), dir.dy.abs());
      final d = k < 1e-9 ? const Offset(1, 0) : dir / k;
      return Rect.fromCenter(center: anchor + Offset(d.dx * (w / 2 + gap), d.dy * (h / 2 + gap)), width: w, height: h);
    }

    final view = Offset.zero & cam.size;
    bool whole(Rect b) => b.left >= view.left && b.top >= view.top && b.right <= view.right && b.bottom <= view.bottom;
    var box = boxTowards(ways.first);
    if (!whole(box) && view.contains(anchor)) box = ways.skip(1).map(boxTowards).where(whole).firstOrNull ?? box;
    final r = RRect.fromRectAndRadius(box, const Radius.circular(4));
    canvas.drawRRect(r, _fill(aiMarkColor.withValues(alpha: alpha)));
    canvas.drawRRect(r, _stroke(_markDark.withValues(alpha: alpha), 1.2));
    tp.paint(canvas, box.topLeft + const Offset(4, 1));
  }

  @override
  bool shouldRepaint(covariant CadPainter old) => true;
}

/// Drawing calls gathered by paint during a pass of the scene and issued
/// once per paint (see [CadPainter._flush]): a project with tens of
/// thousands of items draws them with a few hundred paints, and every call
/// into the renderer has a fixed cost (in the browser, a crossing into its
/// WebAssembly).
class _Batch {
  /// Polylines and circle outlines, one path per stroke paint.
  final paths = <Paint, Path>{};

  /// Opaque straight segments: x0, y0, x1, y1 each.
  final lines = <Paint, List<double>>{};

  /// Opaque filled dots by colour and radius: x, y each.
  final dots = <(Color, double), List<double>>{};

  /// Texts and labels, drawn over the rest of the pass.
  final over = <void Function(Canvas canvas)>[];

  /// Labels are drawn as they come instead of over the pass.
  bool labelsInPlace = false;
}

/// Small helper to draw a picture into an image (used by export preview).
Future<ui.Image> renderPreview(CadPainter painter, Size size) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  painter.paint(canvas, size);
  return rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
}
