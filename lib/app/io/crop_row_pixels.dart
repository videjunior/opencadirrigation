/// 1.7.0 ROW: the field and the pixels the crop row reading takes
/// (core/design/crop_rows.dart): the selected irrigated area or closed
/// outline, and the aerial imagery over it rendered off screen through the
/// same path as the AI assistant's pictures and the image tracing tool
/// (vision_render.dart, vision_tiles.dart; the user's view and base map do
/// not change) — or a placed aerial photo, drawn into the same frame. A
/// small picture of the middle of the field first tells the zoom the
/// imagery has there, so the frame is asked at the imagery's own pixel and
/// no larger than the pixel budget. Tests serve fake tiles through
/// [CropRowSession.renderer].
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/design/auto_layout.dart' show LayoutRegion, maximumInscribedCircle;
import '../../core/design/crop_rows.dart';
import '../../core/model/area_holes.dart' show cutOutlineOf, holesOf;
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../ai/vision_mapping.dart' show PictureFrame;
import '../ai/vision_render.dart';
import '../ai/vision_tiles.dart';
import '../state/controller.dart';
import '../tools/trace_image_tool.dart' show traceMaps;

/// Why no pixels could be read: an i18n key and its arguments.
class CropRowSourceError implements Exception {
  const CropRowSourceError(this.key, [this.args = const {}]);
  final String key;
  final Map<String, String> args;
  @override
  String toString() => key;
}

/// The field read: the largest closed shape selected (an irrigated area
/// with its islands), the other closed shapes selected inside it as holes.
class CropRowField {
  CropRowField(this.entity, this.outline, this.holes);
  final Entity entity;
  final List<Pt> outline;
  final List<List<Pt>> holes;

  AreaEntity? get area => entity is AreaEntity ? entity as AreaEntity : null;
}

/// The field of [entity], or of the selection of [c] (the only irrigated
/// area of the project when nothing closed is selected); null when there is
/// none.
CropRowField? cropRowField(ProjectController c, {Entity? entity}) {
  final p = c.project;
  final shapes = <(Entity, List<Pt>)>[];
  void take(Entity e) {
    final o = cutOutlineOf(e);
    if (o != null && o.length >= 3 && polygonArea(o).abs() > 1e-6) shapes.add((e, o));
  }

  if (entity != null) {
    take(entity);
  } else {
    for (final e in p.entities) {
      if (c.selection.contains(e.id)) take(e);
    }
    if (shapes.isEmpty) {
      final areas = p.entities.whereType<AreaEntity>().toList();
      if (areas.length == 1) take(areas.single);
    }
  }
  if (shapes.isEmpty) return null;
  shapes.sort((a, b) => polygonArea(b.$2).abs().compareTo(polygonArea(a.$2).abs()));
  final (e, outline) = shapes.first;
  final holes = <List<Pt>>[
    ...holesOf(e),
    for (final s in shapes.skip(1))
      if (pointInPolygon(polygonCentroid(s.$2), outline)) s.$2,
  ];
  return CropRowField(e, outline, holes);
}

/// The aerial photos placed in the drawing over [f] (with their pixels),
/// the selected first.
List<ImageEntity> cropRowPhotos(ProjectController c, CropRowField f) {
  final b = Bounds.ofPoints(f.outline);
  final out = [
    for (final e in c.project.entities.whereType<ImageEntity>())
      if (e.data != null && e.bounds.intersects(b)) e,
  ];
  out.sort((a, b) => (c.selection.contains(a.id) ? 0 : 1).compareTo(c.selection.contains(b.id) ? 0 : 1));
  return out;
}

/// Ground size of a tile pixel at [zoom] and latitude [lat] (Web Mercator).
double tileGroundM(int zoom, double lat) => 156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);

/// The pixels read and how: the raster, the frame asked for and the credit
/// of the imagery.
class CropRowPixels {
  CropRowPixels(this.raster, this.frame, this.credit);
  final CropRowRaster raster;
  final CropRowFrame frame;
  final String credit;
}

/// Renders the pixels of [f] for [o]: the aerial base map (the map on
/// screen when it is imagery, else Google satellite with the user's key,
/// else Esri World Imagery), or the placed aerial photo [photo].
Future<CropRowPixels> cropRowPixels(ProjectController c, CropRowField f, CropRowOptions o, {VisionRenderer? renderer, TileCache? tiles, ImageEntity? photo}) async {
  final r = renderer ?? CropRowSession.renderer;
  if (photo != null) return _photoPixels(c, f, o, r, photo);
  final g = c.project.meta.georef;
  if (g == null) throw const CropRowSourceError('wand.noGeoref');
  // a small picture round the widest inner point: the zoom the imagery has
  final (centre, _) = maximumInscribedCircle(LayoutRegion(f.outline, exclusions: f.holes));
  final want = math.max(o.sane.minSpacingM / 6, 0.05);
  const probeSide = 48.0;
  final probe = await r.render(
    c,
    VisionSpec(
      world: Bounds(centre.x - probeSide / 2, centre.y - probeSide / 2, centre.x + probeSide / 2, centre.y + probeSide / 2),
      maxSide: math.max(64, (probeSide / want).round()),
      maps: traceMaps(c),
      drawing: false,
      grid: GridDensity.none,
      background: false,
      tiles: tiles,
      onScreenFallback: false,
    ),
  );
  final map = probe.map, zoom = probe.zoom;
  if (map == null || zoom == null) throw const CropRowSourceError('row.noImagery');
  final (lat, _) = g.toLatLon(centre.x, centre.y);
  final ground = tileGroundM(zoom, lat);
  final frame = cropRowFrame(f.outline, o, holes: f.holes, imageryPixelM: ground);
  final img = await r.render(
    c,
    VisionSpec(
      world: frame.world,
      maxSide: math.max(frame.width, frame.height),
      maxPixels: frame.width * frame.height + 4 * (frame.width + frame.height) + 64,
      maps: [map],
      drawing: false,
      grid: GridDensity.none,
      background: false,
      tiles: tiles,
      onScreenFallback: false,
      keepPixels: true,
    ),
  );
  final rgba = img.rgba;
  if (img.map == null || rgba == null) throw const CropRowSourceError('row.noImagery');
  final used = img.zoom == null ? ground : tileGroundM(img.zoom!, lat);
  return CropRowPixels(CropRowRaster(rgba, img.width, img.height, img.world, imageryPixelM: used), frame, img.attribution);
}

/// The photo [e] drawn into the frame of [f] at its own pixel size.
Future<CropRowPixels> _photoPixels(ProjectController c, CropRowField f, CropRowOptions o, VisionRenderer r, ImageEntity e) async {
  final data = e.data;
  if (data == null) throw const CropRowSourceError('veg.noPhoto');
  final ui.Image image;
  try {
    final codec = await ui.instantiateImageCodec(data);
    image = (await codec.getNextFrame()).image;
    codec.dispose();
  } catch (_) {
    throw const CropRowSourceError('veg.noPhoto');
  }
  try {
    final own = image.width > 0 ? e.width / image.width : null;
    final frame = cropRowFrame(f.outline, o, holes: f.holes, imageryPixelM: own);
    Future<PicturePainter?> layer(PictureFrame pf) async => (canvas, frame) {
      final corners = e.corners;
      final tl = frame.toPx(corners[3]), tr = frame.toPx(corners[2]), bl = frame.toPx(corners[0]);
      final w = image.width.toDouble(), h = image.height.toDouble();
      canvas.save();
      canvas.transform(Float64List.fromList([(tr.dx - tl.dx) / w, (tr.dy - tl.dy) / w, 0, 0, (bl.dx - tl.dx) / h, (bl.dy - tl.dy) / h, 0, 0, 0, 0, 1, 0, tl.dx, tl.dy, 0, 1]));
      canvas.drawImage(image, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.medium);
      canvas.restore();
    };
    final img = await r.render(
      c,
      VisionSpec(
        world: frame.world,
        maxSide: math.max(frame.width, frame.height),
        maxPixels: frame.width * frame.height + 4 * (frame.width + frame.height) + 64,
        drawing: false,
        grid: GridDensity.none,
        background: false,
        under: [layer],
        onScreenFallback: false,
        keepPixels: true,
      ),
    );
    final rgba = img.rgba;
    if (rgba == null) throw const CropRowSourceError('veg.noPhoto');
    return CropRowPixels(CropRowRaster(rgba, img.width, img.height, img.world, imageryPixelM: own), frame, '');
  } finally {
    image.dispose();
  }
}

/// What the tool keeps per project tab: the tiles downloaded, the last
/// reading (for the assistant's apply) and the rows shown on the drawing
/// while the dialog is open.
class CropRowSession {
  CropRowSession._();
  static final _of = Expando<CropRowSession>('cropRows');

  /// The session of [c].
  static CropRowSession of(ProjectController c) => _of[c] ??= CropRowSession._();

  /// How the pictures are rendered (tests serve fake tiles).
  static VisionRenderer renderer = const CanvasSnapshots();

  final TileCache tiles = TileCache(maxTiles: 300);

  /// The last reading and the item it was read for.
  CropRowResult? last;
  String? lastId;

  /// Row lines drawn over the canvas (world metres); empty: none.
  List<List<Pt>> preview = const [];
}
