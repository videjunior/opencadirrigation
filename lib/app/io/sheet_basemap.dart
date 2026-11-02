/// The base map under the drawing sheets (PDF and PNG of a plot): the
/// tiles over everything the sheets show ([PdfSheetBuilder.sheetViews]),
/// downloaded for the print resolution of the most detailed sheet
/// ([fetchMosaic]) and composed into one JPEG. A snapshot of the view on
/// screen covered only the part of the drawing the screen happened to show;
/// it stays as the fallback when the tiles cannot be downloaded (offline),
/// since the screen draws from the tiles it already has.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../core/io/pdf_sheet.dart';
import '../../core/io/plot.dart' show PlotRaster;
import '../../core/model/geometry.dart';
import '../ai/vision_tiles.dart';
import '../canvas/basemap.dart';
import '../state/controller.dart';
import 'jpeg_encode.dart';

/// Resolution of the base map on a PDF sheet (dots per inch on paper),
/// finer than the aerial imagery of most farmland at the usual scales.
const sheetMapDpi = 200.0;

/// Largest base map picture: pixels, and pixels on the longest side.
const sheetMapMaxPixels = 12e6;
const sheetMapMaxSide = 4096.0;

/// Most tiles downloaded for one base map.
const sheetMapMaxTiles = 160;

/// Most tiles of a server run by volunteers ([BaseMapLayer.sharedServer]:
/// the OpenStreetMap Foundation's, OpenTopoMap) for one base map: their
/// usage policies discourage bulk downloads, so a sheet takes a coarser
/// level of them.
const sheetMapMaxTilesShared = 24;

/// [o] with the base map of [c] under its drawing sheets, at [dpi] on the
/// sheet of the largest scale; [o] unchanged when the project has no
/// georeference or no base map is shown, or when neither the tiles nor the
/// view on screen give one.
Future<SheetOptions> withSheetBaseMap(ProjectController c, SheetOptions o, {double dpi = sheetMapDpi, TileFetcher fetcher = const HttpTileFetcher()}) async {
  final g = c.project.meta.georef;
  if (g == null || c.baseMap == BaseMap.none) return o;
  var world = Bounds.empty;
  var mpp = double.infinity; // metres per picture pixel
  for (final (view, scale) in c.exporter().sheetBuilder().sheetViews(o)) {
    world = world.union(view);
    mpp = math.min(mpp, scale / 1000 * 25.4 / dpi);
  }
  if (world.isEmpty || !mpp.isFinite) return o;
  mpp = math.max(mpp, math.max(world.width, world.height) / sheetMapMaxSide);
  mpp = math.max(mpp, math.sqrt(world.width * world.height / sheetMapMaxPixels));
  TileMosaic? mosaic;
  try {
    final limit = BaseMapLayer.sharedServer(c.baseMap) ? sheetMapMaxTilesShared : sheetMapMaxTiles;
    mosaic = await fetchMosaic(g: g, world: world, mpp: mpp, map: c.baseMap, fetcher: fetcher, googleKey: c.googleMapsKey, customUrl: c.customTileUrl, lang: c.lang, maxTiles: limit);
    // no finer than the tiles that came (coarser where the imagery stops)
    final (jpeg, covered) = await _compose(mosaic, world, math.max(mpp, mosaic.groundMpp));
    return o.copyWith(
      rasters: [PlotRaster.bounds(jpeg, covered, mime: 'image/jpeg', opacity: c.baseMapOpacity)],
      attribution: mosaic.attribution,
    );
  } on Object catch (e) {
    debugPrint('sheet base map: tiles not downloaded ($e), the view on screen instead');
    final snap = await c.baseMapSnapshot?.call();
    if (snap == null) return o;
    return o.copyWith(
      rasters: [PlotRaster(bytes: snap.$1, mime: 'image/png', corners: snap.$2, opacity: c.baseMapOpacity)],
      attribution: c.baseMapAttribution?.call() ?? '',
    );
  } finally {
    mosaic?.dispose();
  }
}

/// The tiles of [m] over [world] at [mpp] metres per pixel on white (where
/// a tile is missing the paper shows), as a JPEG, and the world rectangle
/// the picture covers (whole pixels from the top-left corner of [world]).
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
    if (data == null) throw StateError('the base map picture has no pixels');
    // the browser's own encoder where there is one (the Dart one held the window for seconds)
    final jpeg = await encodeJpegRgba(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), w, h, quality: 85);
    return (jpeg, Bounds(world.minX, world.maxY - h * mpp, world.minX + w * mpp, world.maxY));
  } finally {
    image.dispose();
  }
}
