import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/dem_online.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Online DEM download: grid coverage, batch validation, concurrent download
/// with retries and the datum check of the user's own elevation data.
void main() {
  final geo = GeoReference.fromLatLonOrigin(-22.9, -47.1);

  /// Elevation a fake server answers for a coordinate (unique per point).
  double zOf(double lat, double lon) => 800 + ((lat + 22.9) * 1e5).roundToDouble() / 10 + ((lon + 47.1) * 1e5).roundToDouble() / 1000;

  List<(double, double)> coordsOf(String url) {
    final u = Uri.parse(url);
    if (u.host.contains('open-meteo')) {
      final lats = u.queryParameters['latitude']!.split(',').map(double.parse).toList();
      final lons = u.queryParameters['longitude']!.split(',').map(double.parse).toList();
      return [for (var i = 0; i < lats.length; i++) (lats[i], lons[i])];
    }
    return [for (final s in u.queryParameters['locations']!.split('|')) (double.parse(s.split(',')[0]), double.parse(s.split(',')[1]))];
  }

  String answer(DemSource source, String url) {
    final zs = [for (final (lat, lon) in coordsOf(url)) zOf(lat, lon)];
    return source == DemSource.openMeteo ? jsonEncode({'elevation': zs}) : jsonEncode({'status': 'OK', 'results': [for (final z in zs) {'elevation': z}]});
  }

  group('grid', () {
    test('covers the whole area: last column and row on or beyond the far corner', () {
      final pts = demGrid(const Bounds(0, 0, 105, 52), 25, geo);
      final xs = pts.map((p) => p.local.x).toSet(), ys = pts.map((p) => p.local.y).toSet();
      expect(xs.reduce(math.max), greaterThanOrEqualTo(105));
      expect(ys.reduce(math.max), greaterThanOrEqualTo(52));
      expect(xs.reduce(math.min), 0);
      expect(pts.length, 6 * 4);
      // exact multiples keep the corner itself
      expect(demGrid(const Bounds(0, 0, 100, 50), 25, geo).length, 5 * 3);
    });

    test('caps the number of points by widening the spacing, still covering the area', () {
      final b = const Bounds(0, 0, 10000, 10000);
      final pts = demGrid(b, 10, geo, maxPoints: 500);
      expect(pts.length, lessThanOrEqualTo(500));
      expect(pts.length, greaterThan(300));
      expect(pts.map((p) => p.local.x).reduce(math.max), greaterThanOrEqualTo(10000));
      expect(pts.map((p) => p.local.y).reduce(math.max), greaterThanOrEqualTo(10000));
    });

    test('empty, degenerate and invalid inputs give no points', () {
      expect(demGrid(Bounds.empty, 25, geo), isEmpty);
      expect(demGrid(const Bounds(0, 0, 100, 50), 0, geo), isEmpty);
      expect(demGrid(const Bounds(0, 0, 100, 50), double.nan, geo), isEmpty);
      // a single point (zero-size bounds) still samples that point
      expect(demGrid(const Bounds(10, 10, 10, 10), 25, geo).length, 1);
    });
  });

  group('responses', () {
    test('parses both sources and treats missing values as null', () {
      expect(demParseResponse(DemSource.openMeteo, '{"elevation":[600.5,null,610]}'), [600.5, null, 610]);
      expect(demParseResponse(DemSource.openTopoSrtm, '{"status":"OK","results":[{"elevation":601.2},{"elevation":null},{}]}'), [601.2, null, null]);
    });

    test('rejects errors, junk and answers with the wrong number of values', () {
      expect(() => demParseResponse(DemSource.openMeteo, '{"error":true,"reason":"bad"}'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'bad')));
      expect(() => demParseResponse(DemSource.openTopoSrtm, '{"status":"INVALID_REQUEST","error":"nope"}'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'nope')));
      expect(() => demParseResponse(DemSource.openMeteo, '<html>502 Bad Gateway</html>'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dem_bad_response')));
      expect(() => demParseResponse(DemSource.openMeteo, '[1,2]'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dem_bad_response')));
      expect(() => demParseResponse(DemSource.openMeteo, '{"elevation":[1,2]}', expected: 3), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dem_count_mismatch')));
      expect(demParseResponse(DemSource.openMeteo, '{"elevation":[1,2]}', expected: 2), [1, 2]);
    });
  });

  group('download', () {
    test('keeps the point order with concurrent batches of different latency', () async {
      final pts = demGrid(const Bounds(0, 0, 1000, 600), 25, geo); // 41 × 25 = 1025 points → 11 batches
      expect(pts.length, greaterThan(1000));
      final rnd = math.Random(3);
      var inFlight = 0, maxInFlight = 0, calls = 0;
      final progress = <(int, int)>[];
      final zs = await demDownload(DemSource.openMeteo, pts, (url) async {
        calls++;
        inFlight++;
        maxInFlight = math.max(maxInFlight, inFlight);
        await Future<void>.delayed(Duration(milliseconds: rnd.nextInt(20)));
        inFlight--;
        return answer(DemSource.openMeteo, url);
      }, onProgress: (d, t) => progress.add((d, t)), pointsPerMinute: 0);
      expect(calls, 11);
      expect(maxInFlight, greaterThan(1), reason: 'Open-Meteo batches run in parallel');
      expect(maxInFlight, lessThanOrEqualTo(DemSource.openMeteo.concurrency));
      expect(zs.length, pts.length);
      for (var i = 0; i < pts.length; i++) {
        expect(zs[i], closeTo(zOf(double.parse(pts[i].lat.toStringAsFixed(6)), double.parse(pts[i].lon.toStringAsFixed(6))), 1e-6), reason: 'point $i');
      }
      expect(progress.first, (0, 11));
      expect(progress.last, (11, 11));
      expect(progress.map((p) => p.$1).toList(), List.generate(12, (i) => i));
    });

    test('OpenTopoData batches run one at a time with a pause between them', () async {
      final pts = demGrid(const Bounds(0, 0, 500, 300), 25, geo); // 21 × 13 = 273 → 3 batches
      final starts = <DateTime>[];
      var inFlight = 0, maxInFlight = 0;
      final zs = await demDownload(DemSource.openTopoSrtm, pts, (url) async {
        starts.add(DateTime.now());
        inFlight++;
        maxInFlight = math.max(maxInFlight, inFlight);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return answer(DemSource.openTopoSrtm, url);
      }, minInterval: const Duration(milliseconds: 40));
      expect(maxInFlight, 1);
      expect(starts.length, 3);
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i].difference(starts[i - 1]).inMilliseconds, greaterThanOrEqualTo(38));
      }
      expect(zs.where((z) => z == null), isEmpty);
    });

    test('retries transient failures with backoff and keeps the right values', () async {
      final pts = demGrid(const Bounds(0, 0, 500, 300), 25, geo);
      final failures = <String, int>{};
      var calls = 0;
      final zs = await demDownload(DemSource.openMeteo, pts, (url) async {
        calls++;
        final f = failures[url] ?? 0;
        if (f < 2) {
          failures[url] = f + 1;
          throw StateError('network down');
        }
        return answer(DemSource.openMeteo, url);
      }, retryDelay: const Duration(milliseconds: 2), pointsPerMinute: 0);
      expect(calls, 3 * 3, reason: 'every batch fails twice, then succeeds');
      for (var i = 0; i < pts.length; i++) {
        expect(zs[i], closeTo(zOf(double.parse(pts[i].lat.toStringAsFixed(6)), double.parse(pts[i].lon.toStringAsFixed(6))), 1e-6));
      }
    });

    test('gives up after the retries and reports the error', () async {
      final pts = demGrid(const Bounds(0, 0, 100, 100), 25, geo);
      var calls = 0;
      await expectLater(
        demDownload(DemSource.openMeteo, pts, (url) async {
          calls++;
          throw StateError('down');
        }, retries: 2, retryDelay: const Duration(milliseconds: 1)),
        throwsA(isA<StateError>()),
      );
      expect(calls, 3);
    });

    test('a bad answer or a rejected request is not retried', () async {
      final pts = demGrid(const Bounds(0, 0, 100, 100), 25, geo);
      var calls = 0;
      await expectLater(
        demDownload(DemSource.openMeteo, pts, (url) async {
          calls++;
          return '{"elevation":[1]}';
        }, retryDelay: const Duration(milliseconds: 1)),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dem_count_mismatch')),
      );
      expect(calls, 1);
      calls = 0;
      await expectLater(
        demDownload(DemSource.openMeteo, pts, (url) async {
          calls++;
          throw StateError('HTTP 400');
        }, retryable: (e) => false, retryDelay: const Duration(milliseconds: 1)),
        throwsA(isA<StateError>()),
      );
      expect(calls, 1);
    });

    test('a failing batch stops the other workers', () async {
      final pts = demGrid(const Bounds(0, 0, 1000, 1000), 25, geo); // 1681 → 17 batches
      var calls = 0;
      await expectLater(
        demDownload(DemSource.openMeteo, pts, (url) async {
          final n = ++calls;
          await Future<void>.delayed(const Duration(milliseconds: 2));
          if (n == 2) throw const FormatException('dem_bad_response');
          return answer(DemSource.openMeteo, url);
        }, pointsPerMinute: 0),
        throwsA(isA<FormatException>()),
      );
      expect(calls, lessThan(17));
    });

    test('paces the points per sliding minute (Open-Meteo counts coordinates as calls)', () async {
      final pts = demGrid(const Bounds(0, 0, 1000, 600), 25, geo); // 1025 points, 11 batches
      final starts = <DateTime>[];
      final waits = <Duration>[];
      final zs = await demDownload(DemSource.openMeteo, pts, (url) async {
        starts.add(DateTime.now());
        return answer(DemSource.openMeteo, url);
      }, pointsPerMinute: 550, budgetWindow: const Duration(milliseconds: 300), onWait: waits.add);
      expect(zs.where((z) => z == null), isEmpty);
      expect(starts.length, 11);
      // 5 batches (500 points) fit the budget at once; the rest wait for the window
      final first = starts.first;
      final immediate = starts.where((t) => t.difference(first).inMilliseconds < 150).length;
      expect(immediate, 5);
      expect(waits, isNotEmpty);
      expect(starts.last.difference(first).inMilliseconds, greaterThanOrEqualTo(300));
      // never more than the budget inside any window
      for (final t in starts) {
        final inWindow = starts.where((u) => u.difference(t).inMilliseconds >= 0 && u.difference(t).inMilliseconds < 300).length;
        expect(inWindow * 100, lessThanOrEqualTo(600));
      }
    });

    test('a rate-limited answer waits for the server instead of failing', () async {
      final pts = demGrid(const Bounds(0, 0, 100, 100), 25, geo);
      var calls = 0;
      final waits = <Duration>[];
      final zs = await demDownload(DemSource.openMeteo, pts, (url) async {
        calls++;
        if (calls <= 2) throw StateError('429');
        return answer(DemSource.openMeteo, url);
      }, rateLimited: (e) => e is StateError && e.message == '429', retryable: (e) => false, rateLimitDelay: const Duration(milliseconds: 20), onWait: waits.add);
      expect(calls, 3);
      expect(waits.map((w) => w.inMilliseconds).toList(), [20, 40], reason: 'growing pauses');
      expect(zs.where((z) => z == null), isEmpty);
    });

    test('cancelling stops the workers between requests', () async {
      final pts = demGrid(const Bounds(0, 0, 1000, 1000), 25, geo); // 17 batches
      var calls = 0;
      var cancel = false;
      await expectLater(
        demDownload(DemSource.openMeteo, pts, (url) async {
          final n = ++calls;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          if (n == 3) cancel = true;
          return answer(DemSource.openMeteo, url);
        }, cancelled: () => cancel, pointsPerMinute: 0),
        throwsA(isA<DemCancelled>()),
      );
      expect(calls, lessThan(12));
    });

    test('estimates the download time from the pacing rules', () {
      expect(DemSource.openMeteo.estimateDuration(0), Duration.zero);
      expect(DemSource.openMeteo.estimateDuration(400).inSeconds, lessThan(5));
      expect(DemSource.openMeteo.estimateDuration(5000).inSeconds, inInclusiveRange(8 * 60, 10 * 60), reason: '~4450 points beyond the first minute at 550/min');
      expect(DemSource.openTopoSrtm.estimateDuration(5000).inSeconds, inInclusiveRange(50, 80), reason: '50 requests at 1/s');
    });

    test('no points → no requests', () async {
      var calls = 0;
      final zs = await demDownload(DemSource.openMeteo, const [], (url) async {
        calls++;
        return '';
      });
      expect(zs, isEmpty);
      expect(calls, 0);
    });
  });

  group('terrain tiles', () {
    /// WGS84 position whose global pixel at zoom [z] is ([px], [py]).
    DemGridPoint at(double px, double py, int z) {
      final n = (1 << z) * demTileSize;
      final lon = px / n * 360 - 180;
      final lat = math.atan(_sinh(math.pi * (1 - 2 * py / n))) * 180 / math.pi;
      return DemGridPoint(Pt(px, py), lat, lon);
    }

    test('web mercator pixel maths and zoom choice', () {
      expect(demGlobalPixel(0, 0, 0), (128.0, 128.0));
      expect(demGlobalPixel(0, 180, 0).$1, closeTo(256, 1e-9));
      expect(demGlobalPixel(85.05, 0, 0).$2, closeTo(0, 0.1));
      final (px, py) = demGlobalPixel(-22.9, -47.1, 13);
      final back = at(px, py, 13);
      expect(back.lat, closeTo(-22.9, 1e-9));
      expect(back.lon, closeTo(-47.1, 1e-9));
      expect(demPixelSizeM(13, -22), closeTo(17.7, 0.1));
      expect(demTileZoom(25, -22), 13);
      expect(demTileZoom(10, -22), 14);
      expect(demTileZoom(100, -22), 11);
      expect(demTileZoom(5, -22), 14, reason: 'capped');
      expect(demTileZoom(1000, -22), 8, reason: 'floor');
      expect(demTileUrl(13, 3057, 4630), 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/13/3057/4630.png');
    });

    test('terrarium encoding round-trips within 1/256 m', () {
      final rnd = math.Random(7);
      final z = Float32List(demTileSize * demTileSize);
      for (var i = 0; i < z.length; i++) {
        z[i] = -500 + rnd.nextDouble() * 9000;
      }
      final png = demEncodeTerrarium(z);
      expect(png.length, greaterThan(1000));
      final tile = demDecodeTerrarium(png);
      for (var i = 0; i < z.length; i += 97) {
        expect(tile.z[i], closeTo(z[i], 1 / 256 + 1e-3));
      }
      expect(() => demDecodeTerrarium([1, 2, 3]), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dem_bad_tile')));
    });

    test('bilinear sampling across tile borders', () {
      // zoom 1: four tiles; elevation = gx + 2·gy in global pixels
      Float32List plane(int tx, int ty) {
        final z = Float32List(demTileSize * demTileSize);
        for (var y = 0; y < demTileSize; y++) {
          for (var x = 0; x < demTileSize; x++) {
            z[y * demTileSize + x] = (tx * demTileSize + x) + 2.0 * (ty * demTileSize + y);
          }
        }
        return z;
      }

      final tiles = {for (var tx = 0; tx < 2; tx++) for (var ty = 0; ty < 2; ty++) (tx, ty): DemTile(plane(tx, ty))};
      final pts = [at(10.5, 20.5, 1), at(11.0, 20.5, 1), at(255.5, 300.5, 1), at(256.0, 256.0, 1), at(300.25, 100.75, 1)];
      final zs = demSampleTiles(pts, 1, tiles);
      expect(zs[0], closeTo(10 + 40, 1e-6), reason: 'pixel centre');
      expect(zs[1], closeTo(10.5 + 40, 1e-6), reason: 'halfway between two pixels');
      expect(zs[2], closeTo(255 + 600, 1e-6), reason: 'last pixel of the first tile');
      expect(zs[3], closeTo(255.5 + 2 * 255.5, 1e-6), reason: 'corner shared by four tiles');
      expect(zs[4], closeTo(299.75 + 2 * 100.25, 1e-6));
      // a missing tile: the nearest available pixel is used, none → null
      final one = {(0, 0): tiles[(0, 0)]!};
      final partial = demSampleTiles([at(255.9, 100.5, 1), at(400, 400, 1)], 1, one);
      expect(partial[0], closeTo(255 + 200, 1e-6));
      expect(partial[1], isNull);
      // the tiles needed for the points include the neighbours at borders
      expect(demTilesFor([at(255.9, 100.5, 1)], 1), {(0, 0), (1, 0)});
      expect(demTilesFor([at(10.5, 20.5, 1)], 1), {(0, 0)});
      expect(demTilesFor([at(256.0, 256.0, 1)], 1).length, 4);
    });

    test('downloads only the needed tiles and samples the grid exactly on a plane', () async {
      final pts = demGrid(const Bounds(0, 0, 1200, 900), 25, geo); // 49 × 37 = 1813 points
      final z = demTileZoom(25, pts.first.lat);
      expect(z, 13);
      final needed = demTilesFor(pts, z);
      expect(needed.length, inInclusiveRange(1, 4));
      double plane(double gx, double gy) => 500 + 0.01 * (gx - 700000) + 0.02 * (gy - 1200000);
      final fetched = <String>[];
      final progress = <(int, int)>[];
      final zs = await demDownloadTiles(pts, 25, (url) async {
        fetched.add(url);
        final m = RegExp(r'/(\d+)/(\d+)/(\d+)\.png$').firstMatch(url)!;
        final tz = int.parse(m[1]!), tx = int.parse(m[2]!), ty = int.parse(m[3]!);
        expect(tz, z);
        final t = Float32List(demTileSize * demTileSize);
        for (var y = 0; y < demTileSize; y++) {
          for (var x = 0; x < demTileSize; x++) {
            t[y * demTileSize + x] = plane(tx * demTileSize + x + 0.5, ty * demTileSize + y + 0.5);
          }
        }
        return demEncodeTerrarium(t);
      }, onProgress: (d, t) => progress.add((d, t)));
      expect(fetched.length, needed.length);
      expect(fetched.toSet().length, fetched.length, reason: 'each tile once');
      expect(progress.first, (0, needed.length));
      expect(progress.last, (needed.length, needed.length));
      for (var i = 0; i < pts.length; i++) {
        final (px, py) = demGlobalPixel(pts[i].lat, pts[i].lon, z);
        expect(zs[i], closeTo(plane(px, py), 0.02), reason: 'point $i');
      }
      expect(DemSource.terrainTiles.requestCount(pts, 25), needed.length);
      expect(DemSource.terrainTiles.estimateDuration(pts.length, requests: needed.length).inSeconds, lessThan(5));
    });

    test('tile errors: retried when transient, reported otherwise, cancellable', () async {
      final pts = demGrid(const Bounds(0, 0, 100, 100), 25, geo);
      var calls = 0;
      await expectLater(
        demDownloadTiles(pts, 25, (url) async {
          calls++;
          throw StateError('down');
        }, retries: 2, retryDelay: const Duration(milliseconds: 1)),
        throwsA(isA<StateError>()),
      );
      expect(calls, 3);
      calls = 0;
      await expectLater(
        demDownloadTiles(pts, 25, (url) async {
          calls++;
          return [1, 2, 3];
        }, retryDelay: const Duration(milliseconds: 1)),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dem_bad_tile')),
      );
      expect(calls, 1, reason: 'a bad tile is not retried');
      var cancel = false;
      await expectLater(
        demDownloadTiles(pts, 25, (url) async {
          cancel = true;
          return demEncodeTerrarium(Float32List(demTileSize * demTileSize));
        }, cancelled: () => cancel),
        throwsA(isA<DemCancelled>()),
      );
    });

    test('point sources refuse tile calls and the tile source refuses point calls', () {
      expect(() => demRequestUrls(DemSource.terrainTiles, const []), throwsArgumentError);
      expect(() => demParseResponse(DemSource.terrainTiles, '{}'), throwsFormatException);
      expect(DemSource.terrainTiles.browserOk, isTrue);
      expect(DemSource.openMeteo.browserOk, isTrue);
      expect(DemSource.openTopoSrtm.browserOk, isFalse, reason: 'no CORS header on the public API');
      expect(DemSource.values.first, DemSource.terrainTiles, reason: 'default source');
    });
  });

  group('datum check', () {
    test('example data at 100 m against a real DEM at 800 m is a mismatch', () {
      expect(demDatumMismatch((99.5, 103.5), (795, 822)), isTrue);
      expect(demDatumMismatch((1500, 1510), (795, 822)), isTrue);
    });

    test('overlapping or nearby ranges are fine', () {
      expect(demDatumMismatch((800, 830), (795, 822)), isFalse);
      expect(demDatumMismatch((825, 830), (795, 822)), isFalse, reason: 'a ridge the 90 m model does not resolve');
      expect(demDatumMismatch((780, 790), (795, 822)), isFalse);
      expect(demDatumMismatch((100, 100), (100, 100)), isFalse);
    });

    test('the tolerance grows with the relief of the model', () {
      expect(demDatumMismatch((700, 720), (800, 1000)), isFalse, reason: 'gap 80 m < half of the 200 m relief');
      expect(demDatumMismatch((650, 680), (800, 1000)), isTrue, reason: 'gap 120 m > 100 m');
      expect(demDatumMismatch((770, 790), (800, 1000)), isFalse);
      expect(demDatumMismatch((785, 790), (800, 810)), isFalse, reason: 'gap 10 m is within the 10 m floor');
      expect(demDatumMismatch((785, 789), (800, 810)), isTrue, reason: 'gap 11 m > max(10, 5)');
      expect(demDatumMismatch((785, 789), (800, 810), minGapM: 20), isFalse);
      expect(demDatumMismatch((double.nan, 1), (0, 1)), isFalse);
    });
  });
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
