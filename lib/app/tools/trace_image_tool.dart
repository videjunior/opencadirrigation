/// 1.6.0 AUT (PRD-05): the outline of a field, a lawn or a pond traced on
/// the satellite image without the AI assistant — a "magic wand". A click
/// inside the region on the base map; the pixels of the map tiles around it
/// are rendered off screen (the user's view and base map stay as they are)
/// and the region grows from the click over the pixels of similar colour
/// and texture to where its area stops growing at its edge
/// (core/design/region_trace.dart, plain image processing: no service, no
/// trained model). The outline is shown as a preview with its area and how
/// sure the boundary is; typing a tolerance (or setting it in the panel)
/// traces it again from the same pixels; Enter makes it an irrigated area
/// or a closed polyline, one undo step; Esc drops it. "Every field of the
/// view" traces all the regions of the view at once and makes them areas.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import '../../core/design/region_trace.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import '../ai/vision_render.dart';
import '../ai/vision_tiles.dart';
import '../canvas/camera.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'tools.dart';
import 'typed_point.dart' show parseTypedValue;

/// What the traced outline becomes.
enum TraceOutput { area, polyline }

/// Why nothing could be traced: an i18n key (`wand.*`) and its arguments.
class ImageTraceError implements Exception {
  const ImageTraceError(this.key, [this.args = const {}]);
  final String key;
  final Map<String, String> args;
  @override
  String toString() => key;
}

/// Largest side of the area searched (m), and the pixels of a picture.
const traceMaxSpan = 3000.0;
const _tracePixels = 1000000;

/// The base maps to trace on: the one on screen when it is aerial imagery,
/// then the satellite services (Google with the user's key, Esri).
List<BaseMap> traceMaps(ProjectController c) {
  final key = (c.googleMapsKey ?? '').isNotEmpty;
  final shown = c.baseMap;
  return [
    if (isAerialMap(shown) && (!shown.isGoogle || key)) shown,
    if (key && shown != BaseMap.googleSatellite) BaseMap.googleSatellite,
    if (shown != BaseMap.satellite) BaseMap.satellite,
  ];
}

/// The pixels a trace grew on: the image and how it maps to the world.
class TracePixels {
  TracePixels(this.image, this.frame, this.grown);
  final SnapshotImage image;

  /// The area searched (m) and how often it grew while the region reached
  /// its edge.
  final Bounds frame;
  final int grown;
}

/// One traced outline and what it was traced from.
class ImageTrace {
  ImageTrace(this.seed, this.trace, this.pixels);
  final Pt seed;
  final RegionTrace trace;
  final TracePixels pixels;

  List<Pt> get outline => trace.outline;
  double get area => polygonArea(trace.outline).abs();
}

Bounds _around(Pt q, double side) => Bounds(q.x - side / 2, q.y - side / 2, q.x + side / 2, q.y + side / 2);

/// Renders the aerial imagery of [frame] for image analysis.
Future<SnapshotImage> renderTracePixels(ProjectController c, VisionRenderer renderer, Bounds frame, {TileCache? tiles}) async {
  final maps = traceMaps(c);
  final img = await renderer.render(
    c,
    VisionSpec(
      world: frame,
      maxSide: 1100,
      maxPixels: _tracePixels,
      maps: maps,
      drawing: false,
      grid: GridDensity.none,
      background: false,
      tiles: tiles,
      onScreenFallback: false,
      keepPixels: true,
    ),
  );
  if (img.map == null || img.rgba == null) throw const ImageTraceError('wand.noImagery');
  return img;
}

/// Traces the region of the aerial image around [seed] (see the library
/// comment): the search starts on [frame] (the view when it holds the seed
/// and is at most 800 m across, else 300 m around it) and grows while the
/// region reaches its edge, at most three times and [traceMaxSpan] across.
Future<ImageTrace> traceImageAt(ProjectController c, Pt seed, VisionRenderer renderer, {RegionTraceOptions options = const RegionTraceOptions(), Bounds? frame, TileCache? tiles}) async {
  if (c.project.meta.georef == null) throw const ImageTraceError('wand.noGeoref');
  var f = frame != null && frame.contains(seed) && math.max(frame.width, frame.height) <= 800 ? frame : _around(seed, 300);
  if (math.max(f.width, f.height) > traceMaxSpan) f = _around(seed, traceMaxSpan);
  var grown = 0;
  while (true) {
    final img = await renderTracePixels(c, renderer, f, tiles: tiles);
    final pf = img.frame;
    final (sx, sy) = pf.toPixel(seed);
    // the screen paints its progress before the work
    await Future<void>.delayed(Duration.zero);
    RegionTrace res;
    try {
      res = traceRegion(img.rgba!, img.width, img.height, seedX: sx, seedY: sy, pixelM: pf.mpp, toWorld: pf.toWorld, o: options);
    } on RegionTraceError {
      throw const ImageTraceError('wand.noData');
    }
    if (!res.touchesEdge || grown >= 3 || math.max(f.width, f.height) >= traceMaxSpan - 1) {
      if (res.outline.length < 3) throw const ImageTraceError('wand.tooSmall');
      return ImageTrace(seed, res, TracePixels(img, f, grown));
    }
    // the region reaches the edge of the area searched: a larger one round it
    final rb = res.outline.isEmpty ? Bounds.ofPoints([seed]) : Bounds.ofPoints(res.outline);
    final double side = math.min(traceMaxSpan, 2.0 * math.max(math.max(f.width, f.height), math.max(rb.width, rb.height)));
    f = _around(rb.center, side);
    if (!f.contains(seed)) f = _around(seed, side);
    grown++;
  }
}

/// [t] traced again from its own pixels with [options] (another tolerance,
/// blur or detail): no download.
ImageTrace retraceImage(ImageTrace t, RegionTraceOptions options) {
  final img = t.pixels.image, pf = img.frame;
  final (sx, sy) = pf.toPixel(t.seed);
  final res = traceRegion(img.rgba!, img.width, img.height, seedX: sx, seedY: sy, pixelM: pf.mpp, toWorld: pf.toWorld, o: options);
  if (res.outline.length < 3) throw const ImageTraceError('wand.tooSmall');
  return ImageTrace(t.seed, res, t.pixels);
}

/// Every field of [frame] (at most [traceMaxSpan] across), as the AI's
/// trace_fields finds them: regions of at least [minAreaM2] and
/// [minWidthM] wide, whole inside the area.
Future<List<FoundRegion>> traceFieldsIn(
  ProjectController c,
  Bounds frame,
  VisionRenderer renderer, {
  double minAreaM2 = 2000,
  double minWidthM = 10,
  double? simplifyM,
  TileCache? tiles,
  bool Function()? cancelled,
}) async {
  if (c.project.meta.georef == null) throw const ImageTraceError('wand.noGeoref');
  if (math.max(frame.width, frame.height) > traceMaxSpan) throw ImageTraceError('wand.viewTooLarge', {'m': fmt(traceMaxSpan, 0)});
  final img = await renderTracePixels(c, renderer, frame, tiles: tiles);
  final pf = img.frame;
  final found = await traceRegions(
    img.rgba!,
    img.width,
    img.height,
    pixelM: pf.mpp,
    toWorld: pf.toWorld,
    o: RegionsOptions(minAreaM2: minAreaM2, minWidthM: minWidthM, simplifyM: simplifyM),
    cancelled: cancelled,
  );
  return found.regions;
}

/// The settings of the tool and what it shows, one per project tab.
class TraceImageSession {
  TraceImageSession._();
  static final _of = Expando<TraceImageSession>('traceImage');

  /// The session of [c].
  static TraceImageSession of(ProjectController c) => _of[c] ??= TraceImageSession._();

  /// How the pictures are rendered (tests serve fake tiles).
  static VisionRenderer renderer = const CanvasSnapshots();

  /// Tiles downloaded by the tool (reused by the next traces).
  final TileCache tiles = TileCache(maxTiles: 200);

  TraceOutput output = TraceOutput.area;

  /// Colour tolerance in ΔE (null: automatic), box the colours are averaged
  /// over (m) and simplification of the outline (m; null: about a pixel).
  double? tolerance;
  double blurM = 1;
  double? detailM;

  RegionTraceOptions get options => RegionTraceOptions(tolerance: tolerance, blurM: blurM, simplifyM: detailM);

  /// The outline on show, or the fields of the view on show.
  ImageTrace? preview;
  List<FoundRegion> fields = const [];

  /// A trace is running.
  bool busy = false;

  bool get hasPreview => preview != null || fields.isNotEmpty;

  int _run = 0;

  /// Traces the region round [seed] (the view as the first area searched).
  Future<void> traceAt(ProjectController c, Pt seed) async {
    final run = ++_run;
    busy = true;
    fields = const [];
    c.notify(c.t('wand.tracing'));
    try {
      final t = await traceImageAt(c, seed, renderer, options: options, frame: c.camera.visible, tiles: tiles);
      if (run != _run) return;
      preview = t;
      c.notify(describe(c));
    } on ImageTraceError catch (e) {
      if (run != _run) return;
      preview = null;
      c.notify(c.t(e.key, e.args));
    } catch (e) {
      if (run != _run) return;
      preview = null;
      c.notify(c.t('wand.failed', {'m': '$e'}));
    } finally {
      if (run == _run) busy = false;
      c.refresh();
    }
  }

  /// Traces every field of the view.
  Future<void> traceView(ProjectController c) async {
    final run = ++_run;
    busy = true;
    preview = null;
    c.notify(c.t('wand.tracing'));
    try {
      final found = await traceFieldsIn(c, c.camera.visible, renderer, simplifyM: detailM, tiles: tiles, cancelled: () => run != _run);
      if (run != _run) return;
      fields = found;
      c.notify(found.isEmpty ? c.t('wand.noFields') : c.t('wand.fieldsFound', {'n': '${found.length}'}));
    } on ImageTraceError catch (e) {
      if (run != _run) return;
      fields = const [];
      c.notify(c.t(e.key, e.args));
    } catch (e) {
      if (run != _run) return;
      fields = const [];
      c.notify(c.t('wand.failed', {'m': '$e'}));
    } finally {
      if (run == _run) busy = false;
      c.refresh();
    }
  }

  /// The outline on show traced again with the settings of now.
  void retrace(ProjectController c) {
    final p = preview;
    if (p == null) return;
    try {
      preview = retraceImage(p, options);
      c.notify(describe(c));
    } on ImageTraceError catch (e) {
      c.notify(c.t(e.key, e.args));
    }
    c.refresh();
  }

  /// What the outline on show is: area, vertices, how sure the boundary is.
  String describe(ProjectController c) {
    final p = preview;
    if (p == null) return '';
    final u = c.units, r = p.trace;
    final notes = [
      if (!r.clearBoundary && r.automatic) c.t('wand.unclear'),
      if (r.touchesEdge) c.t('wand.edge'),
      if (r.touchesNoData) c.t('wand.gaps'),
      if (r.holeCount > 0) c.t('wand.holes', {'n': '${r.holeCount}'}),
      if (r.seedSpread > 6) c.t('wand.onEdge'),
    ];
    return [
      c.t('wand.traced', {'a': '${fmt(u.areaFromSi(p.area), 2)} ${u.areaLabel}', 'n': '${p.outline.length}', 't': fmt(r.tolerance, 1)}),
      ...notes,
      c.t('wand.next'),
    ].join(' ');
  }

  /// Makes the outline (or the fields) on show items of the project, one
  /// undo step; returns how many.
  int commit(ProjectController c) {
    final shapes = [
      if (preview != null) preview!.outline,
      for (final f in fields) f.outline,
    ];
    if (shapes.isEmpty || busy) return 0;
    // the fields of a view are areas; one outline what the output says
    final asArea = fields.isNotEmpty || output == TraceOutput.area;
    var k = c.project.entities.whereType<AreaEntity>().length;
    final made = <Entity>[
      for (final s in shapes)
        if (asArea) AreaEntity(id: c.project.newId(), points: List.of(s), name: '${c.t('name.area')} ${++k}') else PolylineEntity(id: c.project.newId(), points: List.of(s), closed: true),
    ];
    c.addEntities(made, label: 'hist.traceImage|${made.length}');
    c.select(made.map((e) => e.id));
    preview = null;
    fields = const [];
    c.notify(c.t('wand.created', {'n': '${made.length}'}));
    return made.length;
  }

  /// Drops what is on show (and a trace under way).
  void discard(ProjectController c) {
    _run++;
    busy = false;
    final had = hasPreview;
    preview = null;
    fields = const [];
    if (had) c.refresh();
  }
}

/// The tool (ToolId.traceImage): a click traces, Enter makes the item, Esc
/// drops it; a number typed is the tolerance (ΔE, 0 = automatic), "A" or
/// "P" the output, "V" every field of the view.
class TraceImageTool extends Tool {
  TraceImageTool(super.c, super.host);
  @override
  ToolId get id => ToolId.traceImage;
  @override
  String get hintKey => 'hint.traceImage';
  @override
  bool get usesSnap => false;

  TraceImageSession get s => TraceImageSession.of(c);

  /// The last Esc dropped an outline (the next one leaves the tool).
  bool _dropped = false;

  @override
  bool get idle => !s.hasPreview && !s.busy && !_dropped;

  @override
  void onDown(Pt p, {bool shift = false, bool ctrl = false}) {
    _dropped = false;
    unawaited(s.traceAt(c, p));
  }

  @override
  void onKey(String key) {
    switch (key) {
      case 'Enter':
        _dropped = false;
        s.commit(c);
      case 'Escape' || 'Cancel':
        _dropped = s.hasPreview || s.busy;
        s.discard(c);
    }
  }

  @override
  bool onInput(String text) {
    final w = text.trim().toUpperCase();
    if (w == 'A' || w == 'P') {
      s.output = w == 'A' ? TraceOutput.area : TraceOutput.polyline;
      c.notify(c.t('wand.output.${s.output.name}'));
      return true;
    }
    if (w == 'V') {
      unawaited(s.traceView(c));
      return true;
    }
    final v = parseTypedValue(text);
    if (v == null) return false;
    s.tolerance = v <= 0 ? null : v.clamp(1, 80).toDouble();
    s.retrace(c);
    return true;
  }

  @override
  void cancel() => s.discard(c);

  @override
  void paint(Canvas canvas, Camera cam) {
    final shapes = [
      if (s.preview != null) s.preview!.outline,
      for (final f in s.fields) f.outline,
    ];
    if (shapes.isEmpty) return;
    final fill = Paint()..color = Cad.preview.withValues(alpha: 0.18);
    final line = Paint()
      ..color = Cad.preview
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final pts in shapes) {
      if (pts.length < 3) continue;
      final path = Path()..addPolygon([for (final q in pts) cam.toScreen(q)], true);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, line);
    }
  }
}
