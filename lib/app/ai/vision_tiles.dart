/// Base map tiles for the AI assistant's pictures, fetched off screen: the
/// tiles that cover a world rectangle at the scale of the picture, from the
/// same services and URL templates as the base map on screen
/// ([BaseMapLayer]), without moving the user's view or changing their base
/// map. The fetcher is injectable, so tests serve fake tiles.
///
/// The zoom follows the picture (a tile pixel about one picture pixel). The
/// tile under the centre is asked first, one level lower at a time while
/// the service has none there (aerial imagery ends at z17–18 over most
/// farmland); the other tiles then come at that level, each falling back to
/// its nearest ancestor where it is missing. The Google maps need a session
/// of the Map Tiles API with the user's key; their copyright and highest
/// zoom come from its viewport service.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/io/geo.dart';
import '../../core/model/geometry.dart';
import '../canvas/basemap.dart';
import '../io/http.dart';
import '../state/controller.dart';

/// How the pictures reach the tile services.
abstract class TileFetcher {
  const TileFetcher();

  /// The body of a GET of [url] (a tile); throws [HttpStatusException] for
  /// a status outside 2xx (404: no tile there) and anything else when the
  /// request fails.
  Future<Uint8List> bytes(String url);

  /// A request answered with text (the Google session and viewport).
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body});
}

/// The app's own HTTP (fetch on the web, HttpClient elsewhere), as the base
/// map on screen uses it.
class HttpTileFetcher extends TileFetcher {
  const HttpTileFetcher();

  @override
  Future<Uint8List> bytes(String url) async => Uint8List.fromList(await httpBytes(url));

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) => httpRequest(method, url, headers: headers, body: body);
}

/// A base map the picture cannot use, and why (written for the model).
class MapUnavailable implements Exception {
  MapUnavailable(this.message, {this.downloadFailed = false});
  final String message;

  /// No tile came (offline, blocked, a slow service), as opposed to a map
  /// that cannot work at all (no key, an invalid template, a refused key).
  final bool downloadFailed;
  @override
  String toString() => message;
}

/// Tiles downloaded in one conversation (encoded, least recently used
/// first) and the tiles the services said they do not have.
class TileCache {
  TileCache({this.maxTiles = 400});
  final int maxTiles;
  final Map<String, Uint8List> _bytes = {};
  final Set<String> _missing = {};

  Uint8List? operator [](String key) {
    final v = _bytes.remove(key);
    if (v != null) _bytes[key] = v;
    return v;
  }

  void put(String key, Uint8List bytes) {
    _bytes.remove(key);
    _bytes[key] = bytes;
    while (_bytes.length > maxTiles) {
      _bytes.remove(_bytes.keys.first);
    }
  }

  bool isMissing(String key) => _missing.contains(key);

  void markMissing(String key) {
    if (_missing.length > 4000) _missing.clear();
    _missing.add(key);
  }
}

/// Name of a base map source, for the model.
String mapSourceName(BaseMap m) => switch (m) {
  BaseMap.none => 'no base map',
  BaseMap.streets => 'OpenStreetMap',
  BaseMap.topo => 'OpenTopoMap',
  BaseMap.carto => 'CARTO Voyager',
  BaseMap.satellite => 'Esri World Imagery',
  BaseMap.esriStreets => 'Esri World Street Map',
  BaseMap.esriTopo => 'Esri World Topographic Map',
  BaseMap.googleRoads => 'Google roadmap',
  BaseMap.googleSatellite => 'Google satellite',
  BaseMap.googleHybrid => 'Google hybrid',
  BaseMap.googleTerrain => 'Google terrain',
  BaseMap.custom => 'the user\'s custom tile service',
};

/// Aerial imagery (photographs), as opposed to drawn maps.
bool isAerialMap(BaseMap m) => m == BaseMap.satellite || m == BaseMap.googleSatellite || m == BaseMap.googleHybrid;

/// A drawn street map.
bool isStreetMap(BaseMap m) => m == BaseMap.streets || m == BaseMap.carto || m == BaseMap.esriStreets || m == BaseMap.googleRoads;

/// One tile placed in the world: its image, or the part [src] of an
/// ancestor's, over the tile's world corners (top-left, top-right,
/// bottom-left).
class PlacedTile {
  PlacedTile(this.image, this.tl, this.tr, this.bl, [this.src]);
  final ui.Image image;
  final Pt tl, tr, bl;
  final ui.Rect? src;
}

/// The tiles of one picture, ready to draw.
class TileMosaic {
  TileMosaic._(this.map, this.zoom, this.wantedZoom, this.tiles, this._images, this.attribution, this.total, this.missing, this.groundMpp);

  final BaseMap map;

  /// Zoom of the tiles drawn, and the one the scale of the picture asked
  /// for (higher when the service has no tiles that close here).
  final int zoom, wantedZoom;
  final List<PlacedTile> tiles;
  final List<ui.Image> _images;

  /// The credit to show with the tiles.
  final String attribution;

  /// Tiles covering the picture, and those without an image at any level.
  final int total, missing;

  /// Metres per tile pixel at [zoom] here.
  final double groundMpp;

  String get name => mapSourceName(map);

  /// Draws the tiles through [toPx] (world → picture pixels) at [opacity].
  void paint(ui.Canvas canvas, ui.Offset Function(Pt) toPx, {double opacity = 1}) {
    if (tiles.isEmpty) return;
    final layered = opacity < 0.999;
    if (layered) canvas.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0.05, 1.0)));
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..isAntiAlias = false;
    for (final t in tiles) {
      final tl = toPx(t.tl), tr = toPx(t.tr), bl = toPx(t.bl);
      final w = t.image.width.toDouble(), h = t.image.height.toDouble();
      // affine: image (0, 0) → tl, (w, 0) → tr, (0, h) → bl
      final a = (tr.dx - tl.dx) / w, b = (tr.dy - tl.dy) / w, c = (bl.dx - tl.dx) / h, d = (bl.dy - tl.dy) / h;
      canvas.save();
      canvas.transform(Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tl.dx, tl.dy, 0, 1]));
      final s = t.src;
      if (s == null) {
        canvas.drawImage(t.image, ui.Offset.zero, paint);
      } else {
        canvas.drawImageRect(t.image, s, ui.Rect.fromLTWH(0, 0, w, h), paint);
      }
      canvas.restore();
    }
    if (layered) canvas.restore();
  }

  void dispose() {
    for (final i in _images) {
      i.dispose();
    }
    _images.clear();
    tiles.clear();
  }
}

/// Google Map Tiles API sessions per map type, key and language, with the
/// time they stop being valid.
final Map<String, (String, DateTime)> _googleSessions = {};

Future<String> _googleSession(TileFetcher f, BaseMap m, String key, String lang, Duration timeout) async {
  final k = '${m.name}|$key|$lang';
  final had = _googleSessions[k];
  if (had != null && DateTime.now().isBefore(had.$2)) return had.$1;
  final String text;
  try {
    text = await f
        .text(
          'POST',
          '${BaseMapLayer.googleTilesHost}/v1/createSession?key=${Uri.encodeQueryComponent(key)}',
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(BaseMapLayer.googleSessionRequest(m, lang)),
        )
        .timeout(timeout);
  } on HttpStatusException catch (e) {
    throw MapUnavailable('Google refused the map session (${e.message}): the user\'s key may be wrong or lack the Map Tiles API.');
  } catch (e) {
    throw MapUnavailable('The Google map session could not be opened ($e).');
  }
  final Object? j;
  try {
    j = jsonDecode(text);
  } catch (_) {
    throw MapUnavailable('Google answered the map session with something unreadable.');
  }
  final token = j is Map ? '${j['session'] ?? ''}' : '';
  if (token.isEmpty) throw MapUnavailable('Google gave no map session.');
  final expiry = j is Map ? int.tryParse('${j['expiry']}') : null;
  final until = expiry == null ? DateTime.now().add(const Duration(hours: 1)) : DateTime.fromMillisecondsSinceEpoch(expiry * 1000).subtract(const Duration(minutes: 5));
  _googleSessions[k] = (token, until);
  return token;
}

/// The copyright and the highest zoom the Map Tiles API reports for an
/// area; ('', null) when the service does not answer.
Future<(String, int?)> _googleViewport(TileFetcher f, String session, String key, int z, double north, double south, double east, double west, Duration timeout) async {
  try {
    final q = 'session=${Uri.encodeQueryComponent(session)}&key=${Uri.encodeQueryComponent(key)}&zoom=$z&north=$north&south=$south&east=$east&west=$west';
    final text = await f.text('GET', '${BaseMapLayer.googleTilesHost}/tile/v1/viewport?$q').timeout(timeout);
    final j = jsonDecode(text);
    return (j is Map ? '${j['copyright'] ?? ''}' : '', BaseMapLayer.maxZoomFromViewport(text, north, south, east, west));
  } catch (_) {
    return ('', null);
  }
}

(double, double) _tileXY(double lat, double lon, int z) {
  final n = math.pow(2, z).toDouble();
  final x = (lon + 180) / 360 * n;
  final latR = lat * math.pi / 180;
  final y = (1 - math.log(math.tan(latR) + 1 / math.cos(latR)) / math.pi) / 2 * n;
  return (x, y);
}

(double, double) _latLonOf(double x, double y, int z) {
  final n = math.pow(2, z).toDouble();
  final lon = x / n * 360 - 180;
  final v = math.pi * (1 - 2 * y / n);
  final latR = math.atan((math.exp(v) - math.exp(-v)) / 2);
  return (latR * 180 / math.pi, lon);
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// Runs [run] on every job, at most [width] at a time.
Future<void> _pool<T>(List<T> jobs, int width, Future<void> Function(T job) run) async {
  var next = 0;
  Future<void> worker() async {
    while (next < jobs.length) {
      await run(jobs[next++]);
    }
  }

  await Future.wait([for (var i = 0; i < math.min(width, jobs.length); i++) worker()]);
}

String _reason(Object? e) => switch (e) {
  null => 'no answer',
  HttpStatusException x => 'HTTP ${x.status}',
  TimeoutException _ => 'timed out',
  _ => 'offline or blocked',
};

/// The tiles of [map] over [world] (local metres of [g]) for a picture of
/// [mpp] metres per pixel, each request at most [timeout] and all of them
/// within about [budget]. Throws [MapUnavailable] when there is no map to
/// draw (no key, an invalid template, nothing downloaded).
Future<TileMosaic> fetchMosaic({
  required GeoReference g,
  required Bounds world,
  required double mpp,
  required BaseMap map,
  TileFetcher fetcher = const HttpTileFetcher(),
  String? googleKey,
  String customUrl = '',
  String lang = 'en',
  TileCache? cache,
  int maxTiles = 100,
  Duration timeout = const Duration(seconds: 15),
  Duration budget = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(budget);
  if (map == BaseMap.none) throw MapUnavailable('No base map was asked for.');
  var session = '', key = '';
  if (map.isGoogle) {
    key = googleKey ?? '';
    if (key.isEmpty) throw MapUnavailable('${mapSourceName(map)} needs the user\'s Google Maps key (View → Base map).');
    session = await _googleSession(fetcher, map, key, lang, timeout);
  } else if (map == BaseMap.custom && !BaseMapLayer.isValidTemplate(customUrl)) {
    throw MapUnavailable('The user\'s custom tile template is not valid (View → Base map).');
  }
  final corners = [
    for (final p in [Pt(world.minX, world.minY), Pt(world.maxX, world.minY), Pt(world.maxX, world.maxY), Pt(world.minX, world.maxY)]) g.toLatLon(p.x, p.y),
  ];
  final (latC, lonC) = g.toLatLon(world.center.x, world.center.y);
  if (!latC.isFinite || !lonC.isFinite || corners.any((c) => !c.$1.isFinite || !c.$2.isFinite) || latC.abs() > 85) {
    throw MapUnavailable('The georeference gives no usable latitude/longitude here.');
  }
  (int, int, int, int) range(int z) {
    var xMin = double.infinity, xMax = -double.infinity, yMin = double.infinity, yMax = -double.infinity;
    for (final (lat, lon) in corners) {
      final (tx, ty) = _tileXY(lat, lon, z);
      xMin = math.min(xMin, tx);
      xMax = math.max(xMax, tx);
      yMin = math.min(yMin, ty);
      yMax = math.max(yMax, ty);
    }
    final n = 1 << z;
    return (xMin.floor().clamp(0, n - 1), xMax.floor().clamp(0, n - 1), yMin.floor().clamp(0, n - 1), yMax.floor().clamp(0, n - 1));
  }

  int count(int z) {
    final (x0, x1, y0, y1) = range(z);
    return (x1 - x0 + 1) * (y1 - y0 + 1);
  }

  final wanted = BaseMapLayer.zoomFor(mpp, latC, maxZoom: BaseMapLayer.maxZoom(map));
  var z = wanted;
  while (count(z) > maxTiles && z > 1) {
    z--;
  }
  var attribution = BaseMapLayer.attribution(map);
  if (map.isGoogle) {
    final lats = [for (final c in corners) c.$1], lons = [for (final c in corners) c.$2];
    final (copyright, top) = await _googleViewport(fetcher, session, key, z, lats.reduce(math.max), lats.reduce(math.min), lons.reduce(math.max), lons.reduce(math.min), timeout);
    if (top != null && top < z) z = math.max(1, top);
    if (copyright.isNotEmpty) attribution = copyright;
  }
  final variant = map == BaseMap.custom ? '#${customUrl.hashCode}' : (map.isGoogle ? '#$lang' : '');
  final decoded = <ui.Image>[];
  final jobs = <String, Future<ui.Image?>>{};
  Object? lastError;
  Future<ui.Image?> tile(int tz, int tx, int ty) => jobs.putIfAbsent('$tz/$tx/$ty', () async {
    final k = '${map.name}$variant/$tz/$tx/$ty';
    if (cache?.isMissing(k) ?? false) return null;
    var bytes = cache?[k];
    if (bytes == null) {
      try {
        bytes = await fetcher.bytes(BaseMapLayer.url(map, tz, tx, ty, session: session, key: key, custom: customUrl)).timeout(timeout);
      } on HttpStatusException catch (e) {
        if (map.isGoogle && (e.status == 400 || e.status == 401 || e.status == 403)) {
          throw MapUnavailable('Google refused the map tiles (${e.message}): the user\'s key may lack the Map Tiles API.');
        }
        if (e.status == 404) cache?.markMissing(k);
        lastError = e;
        return null;
      } catch (e) {
        // offline, a timeout, or on the web a 404 whose page has no CORS header
        lastError = e;
        return null;
      }
      cache?.put(k, bytes);
    }
    try {
      final img = await _decode(bytes);
      decoded.add(img);
      return img;
    } catch (e) {
      lastError = e;
      cache?.markMissing(k);
      return null;
    }
  });

  try {
    // the level the service has under the centre
    final floor = math.max(1, z - 6);
    ui.Image? probe;
    while (true) {
      final (px, py) = _tileXY(latC, lonC, z);
      probe = await tile(z, px.floor(), py.floor());
      if (probe != null || z <= floor) break;
      z--;
    }
    if (probe == null) throw MapUnavailable('No ${mapSourceName(map)} tile could be downloaded here (${_reason(lastError)}).', downloadFailed: true);
    Pt local(double tx, double ty, int tz) {
      final (lat, lon) = _latLonOf(tx, ty, tz);
      final (x, y) = g.fromLatLon(lat, lon);
      return Pt(x, y);
    }

    final (x0, x1, y0, y1) = range(z);
    final cells = [
      for (var x = x0; x <= x1; x++)
        for (var y = y0; y <= y1; y++) (x, y),
    ];
    final placed = <PlacedTile>[];
    var missing = 0;
    await _pool(cells, 8, (cell) async {
      final (x, y) = cell;
      // past the time budget the rest stays dark rather than the picture waiting
      if (DateTime.now().isAfter(deadline)) {
        missing++;
        return;
      }
      final tl = local(x.toDouble(), y.toDouble(), z), tr = local(x + 1.0, y.toDouble(), z), bl = local(x.toDouble(), y + 1.0, z);
      final img = await tile(z, x, y);
      if (img != null) {
        placed.add(PlacedTile(img, tl, tr, bl));
        return;
      }
      for (var k = 1; k <= 4 && z - k >= 1; k++) {
        final a = await tile(z - k, x >> k, y >> k);
        if (a != null) {
          placed.add(PlacedTile(a, tl, tr, bl, BaseMapLayer.ancestorSource(x, y, k, a.width, a.height)));
          return;
        }
      }
      missing++;
    });
    final ground = 156543.03392 * math.cos(latC * math.pi / 180) / math.pow(2, z);
    return TileMosaic._(map, z, wanted, placed, decoded, attribution, cells.length, missing, ground);
  } catch (_) {
    for (final i in decoded) {
      i.dispose();
    }
    rethrow;
  }
}
