/// "Keep the map of the area for the field" (View → Base map, 1.6.0, PRD-09): the base map under the project drawn
/// into one picture kept in the project (an image on the IMAGES layer, saved in the file and in this browser's copy),
/// so that the map is still there in the field without a network. Only what the terms of the provider allow
/// ([fieldMapSource]):
/// - the tiles this page has already shown ([seenTiles]): the OpenStreetMap Foundation, OpenTopoMap, CARTO and Esri
///   are not asked for one tile more (the OpenStreetMap Foundation's policy forbids downloading areas of its tiles
///   for offline use);
/// - the user's own tile server (View → Base map → Custom) is downloaded for the area, at most [fieldMapMaxTiles];
/// - the Google maps are not kept: their terms do not allow it.
/// The picture carries the credit of the map ([baseMapPictureMark]), which the sheets and the report print.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/io/data_credits.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../ai/vision_tiles.dart';
import '../canvas/seen_tiles.dart';
import '../state/controller.dart';
import 'http.dart';
import 'jpeg_encode.dart';

/// Where the tiles of a kept map may come from.
enum FieldMapSource {
  /// Only the tiles this page has shown.
  seen,

  /// Downloaded for the area (the user's own server).
  download,

  /// Not kept (no base map, or terms that forbid it).
  refused,
}

/// What the terms of [m] allow for a map kept for the field.
FieldMapSource fieldMapSource(BaseMap m) => switch (m) {
  BaseMap.none || BaseMap.googleRoads || BaseMap.googleSatellite || BaseMap.googleHybrid || BaseMap.googleTerrain => FieldMapSource.refused,
  BaseMap.custom => FieldMapSource.download,
  BaseMap.streets || BaseMap.topo || BaseMap.carto || BaseMap.satellite || BaseMap.esriStreets || BaseMap.esriTopo => FieldMapSource.seen,
};

/// Longest side of the kept picture (pixels) and the finest ground size of its pixel (m).
const fieldMapMaxSide = 2560.0;
const fieldMapFinestMpp = 0.1;

/// Most tiles downloaded from the user's own server for one picture.
const fieldMapMaxTiles = 400;

/// Why no map was kept: the message key ([key]) for the user.
class FieldMapError implements Exception {
  const FieldMapError(this.key);
  final String key;
  @override
  String toString() => key;
}

/// What [keepFieldMap] kept.
class FieldMap {
  const FieldMap(this.image, {required this.tiles, required this.missing, required this.zoom});
  final ImageEntity image;

  /// Tiles drawn, places of the area left white (never shown), zoom level of the tiles.
  final int tiles, missing, zoom;
}

/// A tile fetcher that serves only the tiles this page has shown: any other is "not there" (a 404), and the
/// picture then uses a coarser tile already shown, or stays white there.
class SeenTileFetcher extends TileFetcher {
  const SeenTileFetcher(this.tiles);
  final SeenTiles tiles;

  @override
  Future<Uint8List> bytes(String url) async {
    final b = tiles[url];
    if (b == null) throw HttpStatusException(404, 'not shown in this page');
    return b;
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw HttpStatusException(404, 'not shown in this page');
}

/// Draws the base map of [c] under its drawing (or the view, for an empty drawing) into a picture added to the
/// project as one undo step. [fetcher] replaces the tiles' source (tests). Throws [FieldMapError].
Future<FieldMap> keepFieldMap(ProjectController c, {TileFetcher? fetcher, SeenTiles? seen, double maxSide = fieldMapMaxSide}) async {
  final g = c.project.meta.georef;
  if (g == null) throw const FieldMapError('fieldmap.err.noGeo');
  final m = c.baseMap;
  final how = fieldMapSource(m);
  if (how == FieldMapSource.refused) throw FieldMapError(m == BaseMap.none ? 'fieldmap.err.noMap' : 'fieldmap.err.google');
  if (c.busy) throw const FieldMapError('fieldmap.err.busy');
  var area = c.project.bounds;
  if (area.isEmpty) area = c.camera.visible;
  if (area.isEmpty) throw const FieldMapError('fieldmap.err.noArea');
  area = area.inflate(math.max(20, 0.08 * math.max(area.width, area.height)));
  final mpp = math.max(fieldMapFinestMpp, math.max(area.width, area.height) / maxSide);
  final source = fetcher ?? (how == FieldMapSource.download ? const HttpTileFetcher() : SeenTileFetcher(seen ?? seenTiles));
  final TileMosaic mosaic;
  try {
    mosaic = await fetchMosaic(
      g: g,
      world: area,
      mpp: mpp,
      map: m,
      fetcher: source,
      customUrl: c.customTileUrl,
      lang: c.lang,
      maxTiles: how == FieldMapSource.download ? fieldMapMaxTiles : 4000,
    );
  } on MapUnavailable {
    throw FieldMapError(how == FieldMapSource.seen ? 'fieldmap.err.notSeen' : 'fieldmap.err.download');
  }
  try {
    if (mosaic.tiles.isEmpty) throw FieldMapError(how == FieldMapSource.seen ? 'fieldmap.err.notSeen' : 'fieldmap.err.download');
    // no finer than the tiles that came
    final (jpeg, covered) = await _compose(mosaic, area, math.max(mpp, mosaic.groundMpp));
    final credit = mosaic.attribution.isEmpty ? mapSourceName(m) : mosaic.attribution;
    final image = ImageEntity(
      id: c.project.newId(),
      name: c.t('fieldmap.name', {'m': mapSourceName(m)}),
      origin: Pt(covered.minX, covered.minY),
      width: covered.width,
      height: covered.height,
      mime: 'image/jpeg',
      data: jpeg,
      source: '$baseMapPictureMark $credit',
    );
    final added = c.mutate(() {
      // under everything else of the drawing, like an imported picture
      c.project.entities.insert(0, image);
      return true;
    }, invalidateResults: false, label: 'hist.fieldMap');
    if (added != true) throw const FieldMapError('fieldmap.err.busy');
    return FieldMap(image, tiles: mosaic.tiles.length, missing: mosaic.missing, zoom: mosaic.zoom);
  } finally {
    mosaic.dispose();
  }
}

/// The tiles of [m] over [world] at [mpp] metres per pixel on white, as a JPEG, and the world rectangle the picture
/// covers (whole pixels from the top-left corner of [world]).
Future<(Uint8List, Bounds)> _compose(TileMosaic m, Bounds world, double mpp) async {
  final w = math.max(1, (world.width / mpp).ceil()), h = math.max(1, (world.height / mpp).ceil());
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  m.paint(canvas, (p) => ui.Offset((p.x - world.minX) / mpp, (world.maxY - p.y) / mpp));
  final picture = rec.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw const FieldMapError('fieldmap.err.download');
    final jpeg = await encodeJpegRgba(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), w, h, quality: 82);
    return (jpeg, Bounds(world.minX, world.maxY - h * mpp, world.minX + w * mpp, world.maxY));
  } finally {
    image.dispose();
  }
}
