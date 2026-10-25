/// Composite pictures of the project for the AI assistant (vision): what
/// the user sees, the drawing as the canvas draws it over the base map, in
/// one image with a labelled metre grid, its exact frame (vision_mapping.dart)
/// and optional item labels, a legend of the layer colours, layers under the
/// drawing (terrain) and over it (proposed geometry).
///
/// Everything is rendered off screen: the map tiles are fetched for the
/// picture (vision_tiles.dart) and the canvas painter draws the drawing
/// through a camera set for that one synchronous paint, with a see-through
/// background (vision_palette.dart) so the map shows under it. The user's
/// view and base map never change; only when a source cannot be fetched off
/// screen does the picture take the map on screen, moving the view there
/// and back.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import '../canvas/painter.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'vision_mapping.dart';
import 'vision_palette.dart';
import 'vision_tiles.dart';

class SnapshotImage {
  SnapshotImage({required this.png, required this.width, required this.height, required this.world, this.notes = const [], this.map, this.zoom, this.attribution = ''});
  final Uint8List png;
  final int width, height;

  /// World rectangle the image covers exactly (left = minX, top = maxY).
  final Bounds world;

  /// What the model should know about the picture: the map drawn and its
  /// tile zoom, what could not be drawn and why.
  final List<String> notes;

  /// The base map drawn under the drawing (null: none) and its tile zoom.
  final BaseMap? map;
  final int? zoom;

  /// Credit of the imagery drawn.
  final String attribution;

  PictureFrame get frame => PictureFrame(world, width, height);
}

/// Renders the pictures; the app uses [CanvasSnapshots], tests may fake it.
abstract class ViewSnapshots {
  /// The drawing over [world].
  Future<SnapshotImage> drawing(ProjectController c, Bounds world, int maxSide);

  /// The base map on screen around [world], without the drawing; null
  /// without a base map or a georeference.
  Future<SnapshotImage?> baseMap(ProjectController c, Bounds world, int maxSide);
}

enum GridDensity { none, normal, dense }

enum ItemLabels { none, ids, names }

/// Draws on a picture through its frame.
typedef PicturePainter = void Function(Canvas canvas, PictureFrame frame);

/// Prepares a [PicturePainter] for the frame of a picture (decoding images
/// first); null draws nothing.
typedef PictureLayer = Future<PicturePainter?> Function(PictureFrame frame);

/// What one composite picture shows.
class VisionSpec {
  const VisionSpec({
    required this.world,
    this.maxSide = defaultPictureSide,
    this.maxPixels = maxPicturePixels,
    this.maps = const [],
    this.drawing = true,
    this.grid = GridDensity.normal,
    this.labels = ItemLabels.none,
    this.legend = false,
    this.under = const [],
    this.over = const [],
    this.caption,
    this.tiles,
    this.background = true,
    this.mapOpacity,
    this.nameOf,
    this.onScreenFallback = true,
  });

  /// The area to show; the picture grows it to square pixels.
  final Bounds world;
  final int maxSide, maxPixels;

  /// Base maps to try in order: the first that loads is drawn (empty: none).
  final List<BaseMap> maps;

  /// The drawing over the map, as the canvas draws it.
  final bool drawing;
  final GridDensity grid;
  final ItemLabels labels;

  /// A legend of the layer colours, top right.
  final bool legend;

  /// Layers over the map and under the drawing (terrain), and over the
  /// drawing and the grid (proposed geometry, legends).
  final List<PictureLayer> under, over;

  /// Id of the picture, written in its bottom-left corner.
  final String? caption;

  /// Tiles downloaded earlier in the conversation.
  final TileCache? tiles;

  /// The dark canvas colour under everything (false: transparent where no
  /// map tile lies, for image analysis).
  final bool background;

  /// Opacity of the map (default: the user's base-map opacity under the
  /// drawing, full without it).
  final double? mapOpacity;

  /// Name written for an item with [ItemLabels.names].
  final String Function(Entity e)? nameOf;

  /// When no tile comes off screen, take the map the screen shows (the view
  /// moves there and back).
  final bool onScreenFallback;
}

/// Renders composite pictures ([CanvasSnapshots]).
abstract class VisionRenderer {
  Future<SnapshotImage> render(ProjectController c, VisionSpec spec);
}

/// The pictures as the canvas draws them, with the map tiles from [tiles].
class CanvasSnapshots implements ViewSnapshots, VisionRenderer {
  const CanvasSnapshots({this.tiles = const HttpTileFetcher()});

  /// How the map tiles are downloaded (tests serve fake ones).
  final TileFetcher tiles;

  @override
  Future<SnapshotImage> drawing(ProjectController c, Bounds world, int maxSide) => render(c, VisionSpec(world: world, maxSide: maxSide));

  @override
  Future<SnapshotImage?> baseMap(ProjectController c, Bounds world, int maxSide) async {
    if (c.baseMap == BaseMap.none || c.project.meta.georef == null) return null;
    final img = await render(c, VisionSpec(world: world, maxSide: maxSide, maps: [c.baseMap], drawing: false));
    return img.map == null ? null : img;
  }

  @override
  Future<SnapshotImage> render(ProjectController c, VisionSpec spec) async {
    final f = PictureFrame.fit(spec.world, spec.maxSide, maxPixels: spec.maxPixels);
    final size = Size(f.width.toDouble(), f.height.toDouble());
    final notes = <String>[];
    final g = c.project.meta.georef;
    TileMosaic? mosaic;
    ui.Image? screen;
    Bounds? screenWorld;
    BaseMap? used;
    var credit = '';
    try {
      if (spec.maps.isNotEmpty) {
        if (g == null) {
          notes.add('No base map: the project has no georeference (set_site with its latitude and longitude, or ask the user).');
        } else {
          // the map on screen whose tiles did not come off screen
          var screenFailed = false;
          for (final m in spec.maps) {
            try {
              mosaic = await fetchMosaic(g: g, world: f.world, mpp: f.mpp, map: m, fetcher: tiles, googleKey: c.googleMapsKey, customUrl: c.customTileUrl, lang: c.lang, cache: spec.tiles);
              used = m;
              credit = mosaic.attribution;
              notes.add(_mapNote(mosaic, f));
              break;
            } on MapUnavailable catch (e) {
              notes.add('${mapSourceName(m)} not drawn: ${e.message}');
              if (m == c.baseMap && e.downloadFailed) screenFailed = true;
            }
          }
          if (mosaic == null && screenFailed && spec.onScreenFallback && c.baseMapSnapshot != null) {
            final got = await screenBaseMap(c, f.world);
            if (got != null) {
              screen = await _decode(got.$1);
              screenWorld = Bounds.ofPoints(got.$2);
              used = c.baseMap;
              credit = c.baseMapAttribution?.call() ?? '';
              notes.add('Base map: ${mapSourceName(c.baseMap)} as the screen shows it (its tiles could not be fetched off screen, so the view moved there for a moment and is back as it was).');
            }
          }
          if (used == null) notes.add(spec.drawing ? 'The picture shows the drawing without a base map.' : 'No base map could be drawn.');
        }
      }
      if (spec.drawing) await _warm(c, f.world);
      final under = [for (final l in spec.under) await l(f)];
      final over = [for (final l in spec.over) await l(f)];

      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, Offset.zero & size);
      if (spec.background) canvas.drawRect(Offset.zero & size, Paint()..color = CadPalette.dark.canvas);
      final opacity = spec.mapOpacity ?? (spec.drawing ? c.baseMapOpacity : 1.0);
      mosaic?.paint(canvas, f.toPx, opacity: opacity);
      if (screen != null && screenWorld != null) {
        final dst = Rect.fromPoints(f.toPx(Pt(screenWorld.minX, screenWorld.maxY)), f.toPx(Pt(screenWorld.maxX, screenWorld.minY)));
        canvas.drawImageRect(
          screen,
          Rect.fromLTWH(0, 0, screen.width.toDouble(), screen.height.toDouble()),
          dst,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.05, 1.0)),
        );
      }
      for (final p in under) {
        p?.call(canvas, f);
      }
      if (spec.drawing) paintDrawing(c, canvas, f, hideGrid: spec.grid != GridDensity.none);
      final photo = used != null || spec.under.isNotEmpty;
      if (spec.grid != GridDensity.none) {
        final step = _grid(canvas, f, dense: spec.grid == GridDensity.dense, onPhoto: photo);
        notes.add('Grid: labelled lines every ${fmt(step, step >= 1 ? 0 : 2)} m (${photo ? 'yellow' : 'white'}).');
      }
      // proposed geometry and legends over everything but the labels
      for (final p in over) {
        p?.call(canvas, f);
      }
      final occupied = <Rect>[];
      Rect? legendBox;
      List<(String, Color, int)>? legendRows;
      if (spec.drawing && spec.legend) {
        final (rows, note) = _legendRows(c, f);
        notes.add(note);
        if (rows.isNotEmpty) {
          legendRows = rows;
          legendBox = _legendBox(rows, f);
          occupied.add(legendBox);
        }
      }
      if (spec.drawing && spec.labels != ItemLabels.none) notes.add(_itemLabels(c, canvas, f, spec.labels, spec.nameOf, occupied));
      if (legendRows != null && legendBox != null) _paintLegend(canvas, legendRows, legendBox);
      final corner = [?spec.caption, if (credit.isNotEmpty) credit].join(' · ');
      if (corner.isNotEmpty) _boxText(canvas, corner, Offset(4, f.height - 19), 10, Colors.white, const Color(0xB3000000));
      final png = await _png(rec.endRecording(), f.width, f.height);
      return SnapshotImage(png: png, width: f.width, height: f.height, world: f.world, notes: notes, map: used, zoom: mosaic?.zoom, attribution: credit);
    } finally {
      mosaic?.dispose();
      screen?.dispose();
    }
  }
}

/// Paints the drawing of [c] over [f] as the canvas does (selection,
/// result overlay, labels…), with a see-through background, through the
/// controller's camera set for this one synchronous paint and given back.
/// [hideGrid] leaves out the canvas grid (the picture draws its own).
void paintDrawing(ProjectController c, Canvas canvas, PictureFrame f, {bool hideGrid = true}) {
  final cam = c.camera;
  final saved = (cam.center, cam.scale, cam.size);
  final grid = c.showGrid;
  final size = Size(f.width.toDouble(), f.height.toDouble());
  try {
    cam
      ..size = size
      ..center = f.world.center
      ..scale = 1 / f.mpp;
    if (hideGrid) c.showGrid = false;
    // always the dark canvas: the picture is for the model (the colours the
    // results describe), whatever theme the user chose
    Cad.paintWith(seeThroughDark, () => CadPainter(c: c, tool: null, snapResult: null, repaint: c).paint(canvas, size));
  } finally {
    c.showGrid = grid;
    cam
      ..center = saved.$1
      ..scale = saved.$2
      ..size = saved.$3;
  }
}

/// Waits (a little) for the images the painter decodes on first use: the
/// image items in [world] and the slope or densogram overlay on screen.
Future<void> _warm(ProjectController c, Bounds world) async {
  bool ready() {
    var ok = true;
    for (final e in c.project.entities) {
      if (e is ImageEntity && e.data != null && e.bounds.intersects(world) && c.imageFor(e) == null) ok = false;
    }
    final ov = c.overlay;
    if ((ov == OverlayMode.slope || ov == OverlayMode.aspect) && !c.slopeMap.isEmpty && c.slopeImage(aspect: ov == OverlayMode.aspect) == null) ok = false;
    if (ov == OverlayMode.densogram && !c.densogram.isEmpty && c.densogramImage == null) ok = false;
    return ok;
  }

  for (var i = 0; i < 40 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

String _mapNote(TileMosaic m, PictureFrame f) {
  final b = StringBuffer('Base map: ${m.name}, tile zoom ${m.zoom} (${fmt(m.groundMpp, m.groundMpp < 1 ? 2 : 1)} m per tile pixel)');
  if (m.zoom < m.wantedZoom) b.write('; the service has nothing closer than zoom ${m.zoom} here, so the picture enlarges it ${fmt(m.groundMpp / f.mpp, 1)}× (no finer detail exists)');
  if (m.missing > 0) b.write('; ${m.missing} of ${m.total} tiles missing (dark)');
  b.write('. Imagery credit: ${m.attribution.isEmpty ? 'the tile provider set under View → Base map' : m.attribution}.');
  return b.toString();
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _png(ui.Picture pic, int w, int h) async {
  final img = await pic.toImage(w, h);
  pic.dispose();
  try {
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('png');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    img.dispose();
  }
}

/// The base map the screen shows over [world]: the view moves there while
/// the canvas fetches the tiles, and comes back afterwards. PNG bytes and
/// world corners (bottom-left first); null without a map on screen.
Future<(Uint8List, List<Pt>)?> screenBaseMap(ProjectController c, Bounds world) async {
  final snap = c.baseMapSnapshot;
  if (snap == null || c.baseMap == BaseMap.none || c.project.meta.georef == null || c.camera.size.isEmpty) return null;
  final cam = c.camera;
  final saved = (cam.center, cam.scale);
  try {
    cam.fit(world, padding: 8);
    c.refresh();
    (Uint8List, List<Pt>)? got;
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration(milliseconds: i == 0 ? 1500 : 800));
      got = await snap();
      if (got != null && i >= 1) break;
    }
    return got;
  } finally {
    cam
      ..center = saved.$1
      ..scale = saved.$2;
    c.refresh();
  }
}

/// The base map on screen (or [map]) over [world] (or the view) as a PNG
/// with the world corners of the image (bottom-left, bottom-right,
/// top-right, top-left), at the tiles' own resolution up to 2048 px,
/// transparent where no tile lies: for image analysis (vegetation). Fetched
/// off screen; the view moves only when that fails for the map on screen.
/// Null without a georeference or a map.
Future<(Uint8List, List<Pt>)?> fetchBaseMap(ProjectController c, Bounds? world, {BaseMap? map, TileFetcher tiles = const HttpTileFetcher()}) async {
  final source = map ?? c.baseMap;
  if (source == BaseMap.none || c.project.meta.georef == null) return null;
  final area = world ?? (c.camera.size.isEmpty ? null : c.camera.visible);
  if (area == null || area.isEmpty) return null;
  final img = await CanvasSnapshots(tiles: tiles).render(c, VisionSpec(world: area, maxSide: 2048, maxPixels: 4200000, maps: [source], drawing: false, grid: GridDensity.none, background: false));
  if (img.map == null) return null;
  final w = img.world;
  return (img.png, [Pt(w.minX, w.minY), Pt(w.maxX, w.minY), Pt(w.maxX, w.maxY), Pt(w.minX, w.maxY)]);
}

// ---------------------------------------------------------------- drawing helpers

TextPainter _tp(String s, double size, Color ink) => TextPainter(
  text: TextSpan(
    text: s,
    style: TextStyle(fontSize: size, color: ink, fontFamily: 'monospace', height: 1.15),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// Writes [s] in a box whose top-left corner is [at]; returns the box.
Rect _boxText(Canvas canvas, String s, Offset at, double size, Color ink, Color back) {
  final tp = _tp(s, size, ink);
  final r = Rect.fromLTWH(at.dx, at.dy, tp.width + 4, tp.height + 2);
  canvas.drawRect(r, Paint()..color = back);
  tp.paint(canvas, at + const Offset(2, 1));
  tp.dispose();
  return r;
}

/// A round step giving about [lines] grid lines over [span].
double pictureGridStep(double span, int lines) {
  final target = math.max(span, 1e-6) / lines;
  final e = (math.log(target) / math.ln10).floor();
  final base = math.pow(10.0, e).toDouble();
  for (final m in [1, 2, 5, 10]) {
    if (base * m >= target) return base * m;
  }
  return base * 10;
}

/// Grid lines every round step with their coordinates along the top and
/// left edges (and the bottom and right ones when [dense]); returns the
/// step in metres.
double _grid(Canvas canvas, PictureFrame f, {required bool dense, required bool onPhoto}) {
  final w = f.world;
  final step = pictureGridStep(math.max(w.width, w.height), dense ? 16 : 8);
  final line = Paint()
    ..color = onPhoto ? const Color(0xB3FFEB3B) : const Color(0x59FFFFFF)
    ..strokeWidth = dense ? 0.8 : 1;
  final ink = onPhoto ? Colors.black : Colors.white;
  final back = onPhoto ? const Color(0xD9FFEB3B) : const Color(0xB3000000);
  final size = dense ? 9.5 : 11.0;
  final d = step >= 1 ? 0 : (step >= 0.1 ? 1 : 2);
  final width = f.width.toDouble(), height = f.height.toDouble();
  for (var k = (w.minX / step).ceil(); k * step <= w.maxX + 1e-9; k++) {
    final x = k * step;
    final px = f.toPx(Pt(x, w.maxY)).dx;
    canvas.drawLine(Offset(px, 0), Offset(px, height), line);
    _boxText(canvas, 'x ${fmt(x, d)}', Offset(px + 2, 2), size, ink, back);
    if (dense) _boxText(canvas, 'x ${fmt(x, d)}', Offset(px + 2, height - size - 26), size, ink, back);
  }
  for (var k = (w.minY / step).ceil(); k * step <= w.maxY + 1e-9; k++) {
    final y = k * step;
    final py = f.toPx(Pt(w.minX, y)).dy;
    canvas.drawLine(Offset(0, py), Offset(width, py), line);
    final s = 'y ${fmt(y, d)}';
    _boxText(canvas, s, Offset(2, py + 2), size, ink, back);
    if (dense) {
      final tp = _tp(s, size, ink);
      final tw = tp.width;
      tp.dispose();
      _boxText(canvas, s, Offset(width - tw - 8, py + 2), size, ink, back);
    }
  }
  return step;
}

/// Order in which items get a label (null: never labelled).
int? _labelRank(Entity e) => switch (e) {
  WaterSupplyEntity() || PumpEntity() || MiscHydraulicEntity() || ControlValveEntity() || ControllerEntity() => 0,
  PipeEntity x when x.scope == HydraulicScope.mainline => 1,
  PipeEntity() || SpraylineEntity() || TapeEntity() || JunctionEntity() => 2,
  AreaEntity() || PivotEntity() => 3,
  OutletEntity() => 4,
  PolylineEntity() || LineEntity() || CircleEntity() || ArcEntity() || SplineEntity() || WireEntity() || BreaklineEntity() || SymbolEntity() => 5,
  _ => null,
};

/// A point of [pts] inside [frame], as near the middle of the line as can be.
Pt? _alongInside(List<Pt> pts, Bounds frame) {
  if (pts.isEmpty) return null;
  final len = polylineLength(pts);
  if (len <= 0) return frame.contains(pts.first) ? pts.first : null;
  for (final t in const [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8, 0.1, 0.9, 0.02, 0.98]) {
    final q = pointAlongPolyline(pts, len * t);
    if (frame.contains(q)) return q;
  }
  return null;
}

/// Where the label of [e] points.
Pt? _anchor(Entity e, Bounds frame) {
  Pt? at(Pt p) => frame.contains(p) ? p : null;
  return switch (e) {
    PointEntity x => at(x.position),
    PivotEntity x => at(x.center),
    CircleEntity x => at(x.center),
    AreaEntity x when x.points.length >= 3 => () {
      final cen = polygonCentroid(x.points);
      return frame.contains(cen) && pointInPolygon(cen, x.points) ? cen : _alongInside([...x.points, x.points.first], frame);
    }(),
    _ => e.linearPoints == null ? at(e.bounds.center) : _alongInside(e.linearPoints!, frame),
  };
}

/// Short labels (ids or names) next to the items in [f], the hydraulic
/// ones first, none over another or over [occupied]; returns the note.
String _itemLabels(ProjectController c, Canvas canvas, PictureFrame f, ItemLabels mode, String Function(Entity e)? nameOf, List<Rect> occupied) {
  final p = c.project;
  final hidden = {
    for (final l in p.layers)
      if (!l.visible) l.name,
  };
  final cands = <(int, int, Entity)>[];
  for (var i = 0; i < p.entities.length; i++) {
    final e = p.entities[i];
    if (hidden.contains(e.layer)) continue;
    final r = _labelRank(e);
    if (r != null && e.bounds.intersects(f.world)) cands.add((r, i, e));
  }
  cands.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  var shown = 0, left = 0;
  final dot = Paint()..color = Colors.white;
  final ring = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  for (final (_, _, e) in cands) {
    final at = shown < 300 ? _anchor(e, f.world) : null;
    if (at == null) {
      left++;
      continue;
    }
    final o = f.toPx(at);
    final raw = mode == ItemLabels.ids ? e.id : (nameOf?.call(e) ?? (e.name.isEmpty ? e.id : e.name));
    final text = raw.length > 22 ? '${raw.substring(0, 21)}…' : raw;
    final tp = _tp(text, 10, Colors.white);
    Rect? box;
    for (final s in [Offset(5, -tp.height - 4), Offset(5, 3), Offset(-tp.width - 9, -tp.height - 4), Offset(-tp.width - 9, 3)]) {
      final r = Rect.fromLTWH(o.dx + s.dx, o.dy + s.dy, tp.width + 4, tp.height + 2);
      if (r.left < 0 || r.top < 0 || r.right > f.width || r.bottom > f.height) continue;
      if (occupied.every((x) => !x.overlaps(r))) {
        box = r;
        break;
      }
    }
    if (box == null) {
      tp.dispose();
      left++;
      continue;
    }
    occupied.add(box);
    canvas.drawCircle(o, 2.5, dot);
    canvas.drawCircle(o, 2.5, ring);
    canvas.drawRect(box, Paint()..color = const Color(0xC0000000));
    tp.paint(canvas, box.topLeft + const Offset(2, 1));
    tp.dispose();
    shown++;
  }
  return 'Labels: $shown items by ${mode == ItemLabels.ids ? 'id' : 'name'}, each next to a white dot on the item${left > 0 ? '; $left more left out where they would overlap (list_entities with this bbox lists them all)' : ''}.';
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The layers with items in [f] (name, colour, count), most items first,
/// and the legend in words.
(List<(String, Color, int)>, String) _legendRows(ProjectController c, PictureFrame f) {
  final p = c.project;
  final counts = <String, int>{};
  for (final e in p.entities) {
    if (!(p.findLayer(e.layer)?.visible ?? true) || !e.bounds.intersects(f.world)) continue;
    counts[e.layer] = (counts[e.layer] ?? 0) + 1;
  }
  if (counts.isEmpty) return (const <(String, Color, int)>[], 'Legend: no items in this picture.');
  final all = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  Color colourOf(String layer) => Color(p.findLayer(layer)?.color ?? Layers.defaultColors[layer] ?? 0xFFB0BEC5).withValues(alpha: 1);
  // at most 14 rows, and no more than about 40 % of the picture's height
  final fit = math.max(3, math.min(14, (0.4 * f.height - 6) ~/ 15));
  final rows = [for (final e in all.take(fit)) (e.key, colourOf(e.key), e.value)];
  final ov = c.overlay;
  final colouredByResults = c.results != null && (ov == OverlayMode.velocity || ov == OverlayMode.pressure);
  final listed = [for (final e in all.take(24)) '${e.key} ${_hex(colourOf(e.key))} ×${e.value}'];
  final note = StringBuffer('Legend (layer colours of the items shown; the box at the top right lists the first ${rows.length}): ${listed.join(', ')}${all.length > listed.length ? ', …' : ''}.');
  if (colouredByResults) {
    note.write(
      ov == OverlayMode.velocity
          ? ' Pipes with design results are coloured by flow velocity instead (blue slow → green → orange at the limit → red over it).'
          : ' Pipes with design results are coloured by pressure instead (red below 0, blue → green, purple over the rating).',
    );
  }
  if (c.selection.isNotEmpty) note.write(' Selected items are drawn in yellow.');
  return (rows, note.toString());
}

Rect _legendBox(List<(String, Color, int)> rows, PictureFrame f) {
  var w = 0.0;
  for (final (n, _, k) in rows) {
    final tp = _tp('$n ×$k', 10, Colors.white);
    w = math.max(w, tp.width);
    tp.dispose();
  }
  final bw = w + 26, bh = rows.length * 15.0 + 6;
  return Rect.fromLTWH(math.max(0, f.width - bw - 6), 22, bw, bh);
}

void _paintLegend(Canvas canvas, List<(String, Color, int)> rows, Rect box) {
  canvas.drawRect(box, Paint()..color = const Color(0xD0000000));
  for (var i = 0; i < rows.length; i++) {
    final (n, col, k) = rows[i];
    final y = box.top + 4 + i * 15.0;
    canvas.drawRect(Rect.fromLTWH(box.left + 5, y + 2, 11, 11), Paint()..color = col);
    final tp = _tp('$n ×$k', 10, Colors.white);
    tp.paint(canvas, Offset(box.left + 21, y + 1));
    tp.dispose();
  }
}
