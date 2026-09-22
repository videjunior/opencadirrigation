import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/canvas/basemap.dart';
import 'package:opencadirrigation/app/canvas/camera.dart';
import 'package:opencadirrigation/app/state/controller.dart' show BaseMap;
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// What the fake server answers: (status, body).
typedef Handler = (int, List<int>) Function(String method, Uri url, String body);

/// A dart:io HTTP client that never touches the network.
class FakeClient implements HttpClient {
  FakeClient(this.handler);
  final Handler handler;
  final requests = <String>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => FakeRequest(this, method, url);
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => FakeRequest(this, 'GET', url);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRequest implements HttpClientRequest {
  FakeRequest(this.client, this.method, this.uri);
  final FakeClient client;
  @override
  final String method;
  @override
  final Uri uri;
  final _body = StringBuffer();
  @override
  final HttpHeaders headers = FakeHeaders();
  @override
  void write(Object? object) => _body.write(object);
  @override
  Future<HttpClientResponse> close() async {
    client.requests.add('$method $uri');
    final (status, bytes) = client.handler(method, uri, _body.toString());
    return FakeResponse(status, bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHeaders implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) => values[name] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeResponse(this.statusCode, this.bytes);
  @override
  final int statusCode;
  final List<int> bytes;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOverrides extends HttpOverrides {
  FakeOverrides(this.client);
  final FakeClient client;
  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}

/// Background map tiles: download, cache and eviction, 404 → the nearest
/// ancestor tile, the ArcGIS tilemap, the Google Map Tiles API session and
/// errors — against a fake HTTP server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = img.encodePng(img.Image(width: 256, height: 256));
  final geo = GeoReference.fromLatLonOrigin(-15.78, -47.93);
  // 0.5 m per pixel over 512 px: a handful of tiles near zoom 18
  Camera camera({double size = 512}) => Camera(center: Pt.zero, scale: 2, size: Size(size, size));

  late FakeClient client;
  void serve(Handler h) {
    client = FakeClient(h);
    HttpOverrides.global = FakeOverrides(client);
  }

  tearDown(() => HttpOverrides.global = null);

  int paint(BaseMapLayer layer, BaseMapOptions o, {Camera? cam}) {
    final rec = ui.PictureRecorder();
    final n = layer.paint(ui.Canvas(rec), cam ?? camera(), geo, o);
    rec.endRecording().dispose();
    return n;
  }

  /// Lets the fake responses and the image decoding finish.
  Future<void> settle(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  int? zoomOf(String request) {
    final m = RegExp(r'/(\d+)/(\d+)/(\d+)').firstMatch(request);
    return m == null ? null : int.parse(m[1]!);
  }

  test('nothing to draw: no map, a Google map without key, a bad template, a view needing too many tiles', () {
    serve((m, u, b) => (200, png));
    final layer = BaseMapLayer();
    expect(paint(layer, const BaseMapOptions(BaseMap.none)), 0);
    expect(paint(layer, const BaseMapOptions(BaseMap.googleSatellite)), 0);
    expect(paint(layer, const BaseMapOptions(BaseMap.custom, customUrl: 'tiles/{z}')), 0);
    expect(paint(layer, const BaseMapOptions(BaseMap.streets), cam: camera(size: 40000)), 0);
    expect(client.requests, isEmpty);
    layer.dispose();
  });

  test('custom tiles are downloaded once, cached, drawn and evicted beyond the cache size', () async {
    serve((m, u, b) => (200, png));
    final layer = BaseMapLayer(maxTiles: 3);
    var notified = 0;
    layer.addListener(() => notified++);
    const o = BaseMapOptions(BaseMap.custom, customUrl: 'https://t.example/{z}/{x}/{y}.png');
    expect(paint(layer, o), 0, reason: 'nothing cached yet');
    await settle(() => client.requests.isNotEmpty);
    final asked = client.requests.length;
    expect(asked, inInclusiveRange(2, 16));
    expect(client.requests.every((r) => r.startsWith('GET https://t.example/')), isTrue);
    await settle(() => notified >= asked);
    expect(layer.tileCount, 3, reason: 'the cache keeps the last 3 tiles');
    final drawn = paint(layer, o);
    expect(drawn, greaterThan(0));
    // a second paint asks again only for the evicted tiles
    await settle(() => false);
    expect(client.requests.length, lessThanOrEqualTo(asked * 2));
    // a new template forgets the tiles of the old one
    paint(layer, const BaseMapOptions(BaseMap.custom, customUrl: 'https://other.example/{z}/{x}/{y}.png'));
    expect(layer.tileCount, 0);
    expect(layer.attributionText(BaseMap.custom), '');
    expect(layer.attributionText(BaseMap.streets), contains('OpenStreetMap'));
    layer.dispose();
  });

  test('a tile the server does not have is replaced by its nearest ancestor', () async {
    // the server has nothing above zoom 15
    serve((m, u, b) => (zoomOf(u.toString())! > 15 ? 404 : 200, zoomOf(u.toString())! > 15 ? utf8.encode('no') : png));
    final layer = BaseMapLayer();
    const o = BaseMapOptions(BaseMap.streets);
    var drawn = 0;
    for (var i = 0; i < 12 && drawn == 0; i++) {
      drawn = paint(layer, o);
      await settle(() => false);
    }
    expect(drawn, greaterThan(0), reason: 'the ancestor tiles are drawn scaled up');
    final zooms = client.requests.map(zoomOf).whereType<int>().toSet();
    expect(zooms.reduce((a, b) => a > b ? a : b), greaterThan(15));
    expect(zooms, contains(15));
    expect(layer.tileCount, greaterThan(0));
    // missing tiles are not asked again
    final n = client.requests.length;
    paint(layer, o);
    await settle(() => false);
    expect(client.requests.length, n);
    layer.dispose();
  });

  test('ArcGIS services are asked which tiles exist before the tiles', () async {
    serve((m, u, b) {
      if (u.path.contains('/tilemap/')) {
        // every tile exists except those of odd columns
        final parts = u.pathSegments;
        final top = int.parse(parts[parts.length - 4]), left = int.parse(parts[parts.length - 3]);
        final data = [for (var r = 0; r < 32; r++) for (var c = 0; c < 32; c++) (left + c).isEven ? 1 : 0];
        return (200, utf8.encode(jsonEncode({'data': data, 'location': {'top': top, 'left': left, 'width': 32, 'height': 32}})));
      }
      return (200, png);
    });
    final layer = BaseMapLayer();
    const o = BaseMapOptions(BaseMap.satellite);
    expect(paint(layer, o), 0);
    await settle(() => client.requests.isNotEmpty);
    expect(client.requests, isNotEmpty);
    expect(client.requests.every((r) => r.contains('/tilemap/')), isTrue, reason: 'first the tilemap block');
    await settle(() => false);
    paint(layer, o);
    await settle(() => false);
    final tiles = client.requests.where((r) => r.contains('/tile/')).toList();
    expect(tiles, isNotEmpty);
    final z = tiles.map(zoomOf).whereType<int>().reduce((a, b) => a > b ? a : b);
    final atZ = tiles.where((r) => zoomOf(r) == z).toList();
    for (final r in atZ) {
      // …/tile/z/y/x?blankTile=false
      final seg = Uri.parse(r.substring(4)).pathSegments;
      expect(int.parse(seg.last).isEven, isTrue, reason: 'odd columns are known to be missing: $r');
    }
    expect(client.requests.where((r) => r.contains('/tilemap/')).length, lessThanOrEqualTo(8), reason: 'one request per block');
    expect(paint(layer, o), greaterThan(0));
    layer.dispose();
  });

  test('a layer disposed with downloads in flight drops them quietly', () async {
    serve((m, u, b) => (200, png));
    final layer = BaseMapLayer();
    var notified = 0;
    layer.addListener(() => notified++);
    paint(layer, const BaseMapOptions(BaseMap.topo));
    paint(layer, const BaseMapOptions(BaseMap.satellite));
    layer.dispose();
    await settle(() => false);
    expect(notified, 0, reason: 'nothing is announced after dispose');
    expect(layer.tileCount, 0);
  });

  test('Google maps: a session per map type, the viewport copyright, and a rejected key', () async {
    final sessions = <Map<String, dynamic>>[];
    serve((m, u, b) {
      if (u.path.endsWith('/createSession')) {
        sessions.add(jsonDecode(b) as Map<String, dynamic>);
        expect(u.queryParameters['key'], 'AIzaTest');
        return (200, utf8.encode(jsonEncode({'session': 'tok-${sessions.length}', 'expiry': '${DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}'})));
      }
      if (u.path.contains('/viewport')) {
        return (200, utf8.encode(jsonEncode({'copyright': 'Map data ©2026 Google', 'maxZoomRects': [{'maxZoom': 22, 'north': 90, 'south': -90, 'east': 180, 'west': -180}]})));
      }
      return (200, png);
    });
    final layer = BaseMapLayer();
    const o = BaseMapOptions(BaseMap.googleHybrid, googleKey: 'AIzaTest', lang: 'pt');
    expect(paint(layer, o), 0, reason: 'waiting for the session');
    expect(paint(layer, o), 0, reason: 'one pending session request is enough');
    await settle(() => sessions.isNotEmpty);
    expect(sessions.single, {'mapType': 'satellite', 'layerTypes': ['layerRoadmap'], 'language': 'pt-BR', 'region': 'BR'});
    paint(layer, o);
    await settle(() => client.requests.any((r) => r.contains('/2dtiles/')));
    final tiles = client.requests.where((r) => r.contains('/2dtiles/')).toList();
    expect(tiles, isNotEmpty);
    expect(tiles.every((r) => r.contains('session=tok-1') && r.contains('key=AIzaTest')), isTrue);
    expect(layer.attributionText(BaseMap.googleHybrid), 'Google', reason: 'before the viewport answer');
    await settle(() => client.requests.any((r) => r.contains('/viewport')));
    await settle(() => layer.attributionText(BaseMap.googleHybrid) != 'Google');
    expect(layer.attributionText(BaseMap.googleHybrid), 'Map data ©2026 Google');
    expect(layer.googleError, isNull);
    // a new epoch (key saved again) starts a new session
    paint(layer, const BaseMapOptions(BaseMap.googleHybrid, googleKey: 'AIzaTest', lang: 'pt', epoch: 1));
    await settle(() => sessions.length == 2);
    expect(sessions.length, 2);
    layer.dispose();

    serve((m, u, b) => (403, utf8.encode('{"error": {"code": 403, "message": "API key not valid. Please pass a valid API key."}}')));
    final bad = BaseMapLayer();
    const ob = BaseMapOptions(BaseMap.googleSatellite, googleKey: 'wrong');
    paint(bad, ob);
    await settle(() => bad.googleError != null);
    expect(bad.googleError, 'API key not valid. Please pass a valid API key.');
    final n = client.requests.length;
    expect(paint(bad, ob), 0);
    await settle(() => false);
    expect(client.requests.length, n, reason: 'no retries after an error until the key changes');
    // selecting another map and coming back retries
    paint(bad, const BaseMapOptions(BaseMap.streets));
    paint(bad, ob);
    expect(bad.googleError, isNull);
    bad.dispose();
  });
}
