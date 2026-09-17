/// Online digital elevation models (the "elevation from the internet" of
/// Google Earth workflows): builds the request URLs for a grid of points
/// over the project, parses the answers and drives the download (batches,
/// limited concurrency, retries). Pure Dart; the HTTP call is injected by
/// the app layer.
///
/// Sources (all free and keyless):
/// - Terrain Tiles on AWS Open Data (Mapzen "terrarium" PNG tiles: SRTM
///   30 m, GMTED, ETOPO1…), CORS-enabled, no rate limit: the default.
/// - Open-Meteo Elevation API (Copernicus GLO-90), up to 100 points/call,
///   CORS-enabled, every coordinate counts as one call (600/min).
/// - OpenTopoData (SRTM 30 m, ASTER 30 m…), up to 100 points/call,
///   1 call/s, no CORS header: desktop builds only.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/geometry.dart';
import 'geo.dart';

/// How a source is queried: point batches or raster tiles.
enum DemKind { points, tiles }

enum DemSource {
  /// Terrarium tiles: elevation = R·256 + G + B/256 − 32768 per pixel.
  terrainTiles('Terrain Tiles 30 m (SRTM · AWS)', 0, kind: DemKind.tiles, concurrency: 4, minInterval: Duration.zero),
  /// Open-Meteo counts every coordinate as one API call (600 per minute,
  /// 5000 per hour on the free tier), so big grids are paced by points.
  openMeteo('Open-Meteo (Copernicus DEM 90 m)', 100, concurrency: 4, minInterval: Duration.zero, pointsPerMinute: 550),
  /// OpenTopoData: one request per second, 100 locations each. Its public
  /// API sends no CORS header, so browsers cannot use it.
  openTopoSrtm('OpenTopoData SRTM 30 m', 100, concurrency: 1, minInterval: Duration(milliseconds: 1100), browserOk: false),
  openTopoAster('OpenTopoData ASTER 30 m', 100, concurrency: 1, minInterval: Duration(milliseconds: 1100), browserOk: false);

  const DemSource(this.label, this.batch, {this.kind = DemKind.points, required this.concurrency, required this.minInterval, this.pointsPerMinute, this.browserOk = true});
  final String label;
  final DemKind kind;

  /// Usable from a web page (the server answers cross-origin requests).
  final bool browserOk;

  /// Points per request (point sources).
  final int batch;

  /// Requests in flight at the same time.
  final int concurrency;

  /// Pause between consecutive requests (public rate limits).
  final Duration minInterval;

  /// Budget of points per sliding minute (null: no such limit).
  final int? pointsPerMinute;

  /// Number of requests a download of [points] needs ([spacing] picks the
  /// tile zoom of raster sources).
  int requestCount(List<DemGridPoint> points, double spacing) {
    if (points.isEmpty) return 0;
    if (kind == DemKind.tiles) return demTilesFor(points, demTileZoom(spacing, points.first.lat)).length;
    return (points.length / batch).ceil();
  }

  /// Rough duration of a download of [n] points in [requests] requests,
  /// from the pacing above.
  Duration estimateDuration(int n, {int? requests}) {
    if (n <= 0) return Duration.zero;
    final batches = requests ?? (kind == DemKind.tiles ? 1 : (n / batch).ceil());
    var seconds = batches * (kind == DemKind.tiles ? 0.6 : 0.4) / concurrency + batches * minInterval.inMilliseconds / 1000;
    final ppm = pointsPerMinute;
    if (ppm != null && n > ppm) seconds += (n - ppm) / ppm * 60;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  String get attribution => switch (this) {
    DemSource.terrainTiles => 'Terrain Tiles (AWS Open Data): SRTM / NASA, GMTED, ETOPO1',
    DemSource.openMeteo => 'Open-Meteo.com / Copernicus DEM GLO-90',
    DemSource.openTopoSrtm => 'OpenTopoData / NASA SRTM',
    DemSource.openTopoAster => 'OpenTopoData / ASTER GDEM',
  };

  /// Nominal resolution of the model (m).
  double get resolutionM => this == DemSource.openMeteo ? 90 : 30;
}

class DemGridPoint {
  const DemGridPoint(this.local, this.lat, this.lon);
  final Pt local;
  final double lat;
  final double lon;
}

/// Regular grid of sample points over [bounds] every [spacing] metres,
/// converted to WGS84 with the project georeference. The grid starts at the
/// lower-left corner and its last column / row lies on or beyond the
/// upper-right corner, so the triangulated model covers the whole area.
List<DemGridPoint> demGrid(Bounds bounds, double spacing, GeoReference geo, {int maxPoints = 2500}) {
  if (bounds.isEmpty || spacing <= 0 || !spacing.isFinite) return const [];
  var s = spacing;
  int cols(double s) => (bounds.width / s - 1e-9).ceil() + 1;
  int rows(double s) => (bounds.height / s - 1e-9).ceil() + 1;
  // cap the number of points: widen the spacing when the area is large
  final n = cols(s) * rows(s);
  if (n > maxPoints) {
    s = spacing * math.sqrt(n / maxPoints);
    while (cols(s) * rows(s) > maxPoints) {
      s *= 1.02;
    }
  }
  final nx = cols(s), ny = rows(s);
  final out = <DemGridPoint>[];
  for (var j = 0; j < ny; j++) {
    final y = bounds.minY + j * s;
    for (var i = 0; i < nx; i++) {
      final x = bounds.minX + i * s;
      final (lat, lon) = geo.toLatLon(x, y);
      out.add(DemGridPoint(Pt(x, y), lat, lon));
    }
  }
  return out;
}

/// Spacing (m) of a grid made by [demGrid] (the requested spacing may have
/// been widened by the point cap); [fallback] for fewer than two points.
double demGridStep(List<DemGridPoint> points, double fallback) {
  if (points.length < 2) return fallback;
  final d = points[1].local.distanceTo(points[0].local);
  return d > 0 ? d : fallback;
}

/// Request URLs, one per batch of points, in the same order as [points]
/// (point sources only).
List<String> demRequestUrls(DemSource source, List<DemGridPoint> points) {
  final urls = <String>[];
  String f(double v) => v.toStringAsFixed(6);
  if (source.kind != DemKind.points) throw ArgumentError('tile source');
  for (var i = 0; i < points.length; i += source.batch) {
    final chunk = points.sublist(i, math.min(i + source.batch, points.length));
    switch (source) {
      case DemSource.terrainTiles:
        break;
      case DemSource.openMeteo:
        urls.add('https://api.open-meteo.com/v1/elevation?latitude=${chunk.map((p) => f(p.lat)).join(',')}&longitude=${chunk.map((p) => f(p.lon)).join(',')}');
      case DemSource.openTopoSrtm:
      case DemSource.openTopoAster:
        final ds = source == DemSource.openTopoSrtm ? 'srtm30m' : 'aster30m';
        urls.add('https://api.opentopodata.org/v1/$ds?locations=${chunk.map((p) => '${f(p.lat)},${f(p.lon)}').join('|')}');
    }
  }
  return urls;
}

/// Elevations (metres) of one batch answer; null where the source has no
/// data. With [expected] the answer must hold exactly that many values,
/// otherwise the points after a short answer would get the wrong heights.
List<double?> demParseResponse(DemSource source, String body, {int? expected}) {
  final Object? j;
  try {
    j = jsonDecode(body);
  } on FormatException {
    throw const FormatException('dem_bad_response');
  }
  if (j is! Map<String, dynamic>) throw const FormatException('dem_bad_response');
  final List<double?> out;
  switch (source) {
    case DemSource.terrainTiles:
      throw const FormatException('dem_bad_response');
    case DemSource.openMeteo:
      final list = j['elevation'];
      if (list is! List) throw FormatException(j['reason'] as String? ?? 'dem_bad_response');
      out = [for (final v in list) v is num && v.isFinite ? v.toDouble() : null];
    case DemSource.openTopoSrtm:
    case DemSource.openTopoAster:
      if (j['status'] != 'OK') throw FormatException(j['error'] as String? ?? 'dem_bad_response');
      final list = j['results'];
      if (list is! List) throw const FormatException('dem_bad_response');
      out = [
        for (final r in list)
          r is Map && r['elevation'] is num && (r['elevation'] as num).isFinite ? (r['elevation'] as num).toDouble() : null,
      ];
  }
  if (expected != null && out.length != expected) throw const FormatException('dem_count_mismatch');
  return out;
}

/// Thrown by [demDownload] when [cancelled] asked to stop.
class DemCancelled implements Exception {
  const DemCancelled();
  @override
  String toString() => 'dem_cancelled';
}

/// Downloads the elevations of [points] with [fetch] (GET url → body):
/// batches of [DemSource.batch] points, [DemSource.concurrency] requests in
/// flight, a pause of [DemSource.minInterval] between requests, at most
/// [pointsPerMinute] points per sliding minute, and up to [retries] extra
/// attempts per batch when [retryable] accepts the error (network hiccups,
/// 5xx answers) — a [rateLimited] error (HTTP 429) waits [rateLimitDelay]
/// × attempt instead. The result keeps the order of [points]; null marks
/// points without data. [onProgress] gets (finished batches, total
/// batches), [onWait] the length of every pause imposed by a limit, and
/// [cancelled] is polled between requests (a true answer throws
/// [DemCancelled]). [pointsPerMinute] overrides the source's budget (0
/// disables it).
Future<List<double?>> demDownload(
  DemSource source,
  List<DemGridPoint> points,
  Future<String> Function(String url) fetch, {
  void Function(int done, int total)? onProgress,
  void Function(Duration wait)? onWait,
  bool Function()? cancelled,
  int retries = 3,
  bool Function(Object error)? retryable,
  bool Function(Object error)? rateLimited,
  Duration retryDelay = const Duration(seconds: 1),
  Duration rateLimitDelay = const Duration(seconds: 20),
  int? concurrency,
  Duration? minInterval,
  int? pointsPerMinute,
  Duration budgetWindow = const Duration(seconds: 62),
}) async {
  final urls = demRequestUrls(source, points);
  final zs = List<double?>.filled(points.length, null);
  if (urls.isEmpty) return zs;
  final total = urls.length;
  final workers = math.max(1, concurrency ?? source.concurrency);
  final gap = minInterval ?? source.minInterval;
  final budgetRaw = pointsPerMinute ?? source.pointsPerMinute;
  final budget = budgetRaw != null && budgetRaw > 0 ? budgetRaw : null; // 0 disables the pacing
  final canRetry = retryable ?? (e) => e is! FormatException;
  final isRateLimit = rateLimited ?? (e) => false;
  var next = 0, done = 0;
  Object? failure;
  StackTrace? failureTrace;
  var lastStart = DateTime.fromMillisecondsSinceEpoch(0);
  // points sent in the current budget window: (start time, points)
  final sent = <(DateTime, int)>[];
  onProgress?.call(0, total);

  Future<void> pause(Duration d) async {
    if (d <= Duration.zero) return;
    onWait?.call(d);
    await Future<void>.delayed(d);
  }

  void checkCancel() {
    if (cancelled?.call() ?? false) throw const DemCancelled();
  }

  Future<void> worker() async {
    while (failure == null) {
      checkCancel();
      final i = next++;
      if (i >= total) return;
      final offset = i * source.batch;
      final expected = math.min(source.batch, points.length - offset);
      for (var attempt = 0; ; attempt++) {
        // points-per-minute budget: wait for the oldest batch to leave the window
        if (budget != null) {
          while (true) {
            final now = DateTime.now();
            sent.removeWhere((s) => now.difference(s.$1) >= budgetWindow);
            final used = sent.fold(0, (a, s) => a + s.$2);
            if (used + expected <= budget || sent.isEmpty) break;
            await pause(budgetWindow - now.difference(sent.first.$1) + const Duration(milliseconds: 200));
            checkCancel();
          }
          sent.add((DateTime.now(), expected));
        }
        if (gap > Duration.zero) {
          final wait = lastStart.add(gap).difference(DateTime.now());
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        lastStart = DateTime.now();
        try {
          final body = await fetch(urls[i]);
          checkCancel();
          final batch = demParseResponse(source, body, expected: expected);
          zs.setRange(offset, offset + expected, batch);
          break;
        } on DemCancelled {
          rethrow;
        } catch (e, st) {
          final limited = isRateLimit(e);
          if (attempt >= retries || !(limited || canRetry(e))) {
            failure ??= e;
            failureTrace ??= st;
            return;
          }
          if (limited) {
            // the server's minute is full: give it time to roll over
            await pause(rateLimitDelay * (attempt + 1));
            checkCancel();
          } else {
            await Future<void>.delayed(retryDelay * (1 << attempt));
          }
        }
      }
      done++;
      onProgress?.call(done, total);
    }
  }

  try {
    await Future.wait([for (var w = 0; w < workers; w++) worker()], eagerError: true);
  } on DemCancelled {
    rethrow;
  }
  if (failure != null) Error.throwWithStackTrace(failure!, failureTrace ?? StackTrace.current);
  return zs;
}

// ---------------------------------------------------------------- raster tiles

/// Tile edge in pixels of the terrarium tiles.
const demTileSize = 256;
const _earthCircumferenceM = 40075016.686;

/// URL of a terrarium tile on the AWS Open Data bucket.
String demTileUrl(int z, int x, int y) => 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/$z/$x/$y.png';

/// Global pixel coordinates (Web Mercator, [demTileSize] px tiles) of a
/// WGS84 position at zoom [z]; pixel centres sit at .5.
(double, double) demGlobalPixel(double lat, double lon, int z) {
  final n = (1 << z) * demTileSize;
  final x = (lon + 180) / 360 * n;
  final latR = lat.clamp(-85.05, 85.05) * math.pi / 180;
  final y = (1 - math.log(math.tan(latR) + 1 / math.cos(latR)) / math.pi) / 2 * n;
  return (x, y);
}

/// Ground size (m) of one pixel at zoom [z] and latitude [lat].
double demPixelSizeM(int z, double lat) => _earthCircumferenceM * math.cos(lat * math.pi / 180) / ((1 << z) * demTileSize);

/// Smallest zoom whose pixels are not larger than the grid [spacing]
/// (between [minZoom] and [maxZoom]; the terrarium data is ~30 m, so more
/// than zoom 14 only interpolates).
int demTileZoom(double spacing, double lat, {int minZoom = 8, int maxZoom = 14}) {
  for (var z = minZoom; z <= maxZoom; z++) {
    if (demPixelSizeM(z, lat) <= spacing) return z;
  }
  return maxZoom;
}

/// Tiles (x, y) needed to sample [points] bilinearly at zoom [z].
Set<(int, int)> demTilesFor(List<DemGridPoint> points, int z) {
  final out = <(int, int)>{};
  final n = 1 << z;
  for (final p in points) {
    final (px, py) = demGlobalPixel(p.lat, p.lon, z);
    final x0 = (px - 0.5).floor(), y0 = (py - 0.5).floor();
    for (final gx in [x0, x0 + 1]) {
      for (final gy in [y0, y0 + 1]) {
        final tx = ((gx / demTileSize).floor() % n + n) % n;
        final ty = (gy / demTileSize).floor().clamp(0, n - 1);
        out.add((tx, ty));
      }
    }
  }
  return out;
}

/// Elevations of one decoded tile (row-major, [demTileSize]²).
class DemTile {
  DemTile(this.z);
  final Float32List z;
  double at(int px, int py) => z[py * demTileSize + px];
}

/// Decodes a terrarium PNG tile (elevation = R·256 + G + B/256 − 32768).
DemTile demDecodeTerrarium(List<int> png) {
  final im = img.decodePng(png is Uint8List ? png : Uint8List.fromList(png));
  if (im == null || im.width != demTileSize || im.height != demTileSize) throw const FormatException('dem_bad_tile');
  final z = Float32List(demTileSize * demTileSize);
  for (var y = 0; y < demTileSize; y++) {
    for (var x = 0; x < demTileSize; x++) {
      final p = im.getPixel(x, y);
      z[y * demTileSize + x] = (p.r * 256 + p.g + p.b / 256) - 32768;
    }
  }
  return DemTile(z);
}

/// Encodes elevations as a terrarium PNG (the inverse of
/// [demDecodeTerrarium]; used by tests and tools).
Uint8List demEncodeTerrarium(Float32List z) {
  final im = img.Image(width: demTileSize, height: demTileSize);
  for (var y = 0; y < demTileSize; y++) {
    for (var x = 0; x < demTileSize; x++) {
      final v = ((z[y * demTileSize + x] + 32768) * 256).round().clamp(0, 256 * 256 * 256 - 1);
      im.setPixelRgb(x, y, (v >> 16) & 255, (v >> 8) & 255, v & 255);
    }
  }
  return img.encodePng(im);
}

/// Bilinear sample of [points] from the decoded [tiles] at zoom [z]; null
/// where no tile covers the point.
List<double?> demSampleTiles(List<DemGridPoint> points, int z, Map<(int, int), DemTile> tiles) {
  final n = 1 << z;
  final span = n * demTileSize;
  double? at(int gx, int gy) {
    if (gy < 0 || gy >= span) return null;
    final wx = ((gx % span) + span) % span;
    final t = tiles[((wx / demTileSize).floor(), (gy / demTileSize).floor())];
    if (t == null) return null;
    return t.at(wx % demTileSize, gy % demTileSize);
  }

  final out = List<double?>.filled(points.length, null);
  for (var i = 0; i < points.length; i++) {
    final (px, py) = demGlobalPixel(points[i].lat, points[i].lon, z);
    final fx = px - 0.5, fy = py - 0.5;
    final x0 = fx.floor(), y0 = fy.floor();
    final tx = fx - x0, ty = fy - y0;
    final z00 = at(x0, y0), z10 = at(x0 + 1, y0), z01 = at(x0, y0 + 1), z11 = at(x0 + 1, y0 + 1);
    if (z00 != null && z10 != null && z01 != null && z11 != null) {
      out[i] = (z00 * (1 - tx) + z10 * tx) * (1 - ty) + (z01 * (1 - tx) + z11 * tx) * ty;
    } else {
      // partial coverage (edge of the tiled area): nearest available pixel
      out[i] = [z00, z10, z01, z11].whereType<double>().firstOrNull;
    }
  }
  return out;
}

/// Downloads the terrarium tiles covering [points] with [fetchBytes] and
/// samples the elevations (see [demDownload] for the retry and
/// cancellation arguments). [spacing] picks the zoom unless [zoom] is given;
/// the zoom drops until at most [maxTiles] tiles are needed.
Future<List<double?>> demDownloadTiles(
  List<DemGridPoint> points,
  double spacing,
  Future<List<int>> Function(String url) fetchBytes, {
  int? zoom,
  void Function(int done, int total)? onProgress,
  bool Function()? cancelled,
  int retries = 3,
  bool Function(Object error)? retryable,
  Duration retryDelay = const Duration(seconds: 1),
  int concurrency = 4,
  int maxTiles = 64,
}) async {
  if (points.isEmpty) return const [];
  var z = zoom ?? demTileZoom(spacing, points.first.lat);
  var tiles = demTilesFor(points, z).toList();
  while (tiles.length > maxTiles && z > 1) {
    z--;
    tiles = demTilesFor(points, z).toList();
  }
  final total = tiles.length;
  final canRetry = retryable ?? (e) => e is! FormatException;
  final decoded = <(int, int), DemTile>{};
  var next = 0, done = 0;
  Object? failure;
  StackTrace? failureTrace;
  onProgress?.call(0, total);

  void checkCancel() {
    if (cancelled?.call() ?? false) throw const DemCancelled();
  }

  Future<void> worker() async {
    while (failure == null) {
      checkCancel();
      final i = next++;
      if (i >= total) return;
      final (x, y) = tiles[i];
      for (var attempt = 0; ; attempt++) {
        try {
          final bytes = await fetchBytes(demTileUrl(z, x, y));
          checkCancel();
          decoded[(x, y)] = demDecodeTerrarium(bytes);
          break;
        } on DemCancelled {
          rethrow;
        } catch (e, st) {
          if (attempt >= retries || !canRetry(e)) {
            failure ??= e;
            failureTrace ??= st;
            return;
          }
          await Future<void>.delayed(retryDelay * (1 << attempt));
        }
      }
      done++;
      onProgress?.call(done, total);
    }
  }

  await Future.wait([for (var w = 0; w < math.max(1, concurrency); w++) worker()], eagerError: true);
  if (failure != null) Error.throwWithStackTrace(failure!, failureTrace ?? StackTrace.current);
  checkCancel();
  return demSampleTiles(points, z, decoded);
}

/// True when the elevations already in the project (survey contours, spot
/// heights typed by hand, example data) cannot belong to the same datum as
/// the downloaded model: the two ranges do not overlap and the gap between
/// them exceeds half the model's own relief (at least [minGapM]). Mixing
/// such data gives a terrain full of spikes.
bool demDatumMismatch((double, double) own, (double, double) dem, {double minGapM = 10}) {
  final (ownLo, ownHi) = own;
  final (demLo, demHi) = dem;
  if (!(ownLo.isFinite && ownHi.isFinite && demLo.isFinite && demHi.isFinite)) return false;
  final gap = math.max(ownLo - demHi, demLo - ownHi);
  if (gap <= 0) return false;
  return gap > math.max(minGapM, 0.5 * (demHi - demLo));
}
