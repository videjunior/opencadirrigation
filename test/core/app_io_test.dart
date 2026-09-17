import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/basemap.dart';
import 'package:opencadirrigation/app/canvas/camera.dart';
import 'package:opencadirrigation/app/canvas/snapping.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

/// App-level I/O and canvas helpers: HTTP transport against a local server,
/// the browser project store, base map maths, camera and snapping.
void main() {
  group('http transport', () {
    late HttpServer server;
    final saved = <String, String>{};
    final log = <String>[];

    setUpAll(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final path = req.uri.path;
        log.add('${req.method} ${req.uri}');
        final auth = req.headers.value('authorization') ?? '';
        req.response.headers.contentType = ContentType.json;
        if (req.method == 'GET' && path == '/api/projects') {
          req.response.write(jsonEncode([
            {'uid': 'p1', 'name': 'Projeto 1', 'at': '2026-09-16T10:00:00Z', 'v': 3, 'bytes': 1234},
            {'uid': 'p2', 'name': 'Projeto 2'},
          ]));
        } else if (req.method == 'GET' && path == '/api/projects/p1/versions') {
          req.response.write(jsonEncode([
            {'v': 3, 'at': '2026-09-16T10:00:00Z', 'label': 'final'},
            {'v': 2, 'at': '2026-09-15T10:00:00Z'},
          ]));
        } else if (req.method == 'GET' && path == '/api/projects/p1/versions/2') {
          req.response.write('{"format":"opencadirrigation","v":2}');
        } else if (req.method == 'GET' && path == '/api/projects/p1') {
          req.response.write('{"format":"opencadirrigation","auth":"$auth"}');
        } else if (req.method == 'PUT' && path.startsWith('/api/projects/')) {
          saved[path + (req.uri.query.isEmpty ? '' : '?${req.uri.query}')] = await utf8.decoder.bind(req).join();
          req.response.write('{}');
        } else if (req.method == 'DELETE' && path == '/api/projects/p1') {
          req.response.write('{}');
        } else if (path == '/bytes') {
          req.response.headers.contentType = ContentType.binary;
          req.response.add([1, 2, 3, 250, 255]);
        } else {
          req.response.statusCode = 404;
          req.response.write('nope');
        }
        await req.response.close();
      });
    });
    tearDownAll(() => server.close(force: true));

    String base() => 'http://127.0.0.1:${server.port}/api';

    test('httpRequest returns bodies and throws on non-2xx; httpBytes downloads binary', () async {
      expect(await httpRequest('GET', '${base()}/projects/p1'), contains('opencadirrigation'));
      await expectLater(httpRequest('GET', '${base()}/missing'), throwsA(isA<Exception>()));
      expect(await httpBytes('http://127.0.0.1:${server.port}/bytes'), [1, 2, 3, 250, 255]);
      await expectLater(httpBytes('http://127.0.0.1:${server.port}/missing'), throwsA(isA<Exception>()));
    });

  });

  group('LocalProjectStore', () {
    setUp(() => LocalProjectStore().clearAll());

    test('save, list, versions, rename, recover and remove', () {
      final store = LocalProjectStore();
      store.save('u1', 'Um', '{"a":1}');
      store.save('u1', 'Um', '{"a":2}');
      store.save('u2', 'Dois', '{"b":1}', kind: 'autosave');
      expect(store.list().map((p) => p.uid).toSet(), {'u1', 'u2'});
      expect(store.load('u1'), '{"a":2}');
      final v = store.versions('u1');
      expect(v.length, greaterThanOrEqualTo(1));
      expect(store.load('u1', version: v.first.version), isNotNull);
      expect(store.recoverable().map((p) => p.uid), ['u2']);
      store.acknowledge('u2');
      expect(store.recoverable(), isEmpty);
      store.rename('u1', 'Um renomeado');
      expect(store.list().firstWhere((p) => p.uid == 'u1').name, 'Um renomeado');
      store.remove('u1');
      expect(store.list().map((p) => p.uid), isNot(contains('u1')));
      expect(store.load('u1'), isNull);
      store.clearAll();
      expect(store.list(), isEmpty);
    });

    test('version history is capped and the index survives a JSON round trip', () {
      final store = LocalProjectStore();
      for (var i = 0; i < 15; i++) {
        store.save('cap', 'Cap', '{"i":$i}');
      }
      expect(store.versions('cap').length, lessThanOrEqualTo(store.maxVersions));
      final p = store.list().first;
      final back = StoredProject.fromJson(p.toJson());
      expect(back.uid, p.uid);
      expect(back.name, p.name);
      expect(back.version, p.version);
    });
  });

  group('base map maths', () {
    test('tile urls, attribution and zoom levels', () {
      expect(BaseMapLayer.url(BaseMap.streets, 12, 1, 2), contains('/12/1/2.png'));
      expect(BaseMapLayer.url(BaseMap.satellite, 12, 1, 2), contains('/12/2/1'));
      // Esri answers 404 instead of a "no data" placeholder tile
      expect(BaseMapLayer.url(BaseMap.satellite, 12, 1, 2), contains('blankTile=false'));
      expect(BaseMapLayer.url(BaseMap.esriTopo, 12, 1, 2), contains('World_Topo_Map/MapServer/tile/12/2/1'));
      expect(BaseMapLayer.url(BaseMap.topo, 12, 1, 2), contains('opentopomap.org/12/1/2.png'));
      expect(BaseMapLayer.url(BaseMap.carto, 12, 1, 2), contains('cartocdn.com/rastertiles/voyager/12/1/2.png'));
      expect(BaseMapLayer.attribution(BaseMap.streets), contains('OpenStreetMap'));
      expect(BaseMapLayer.attribution(BaseMap.satellite), contains('Esri'));
      for (final m in BaseMap.values) {
        if (m != BaseMap.none && m != BaseMap.custom) expect(BaseMapLayer.attribution(m), isNotEmpty, reason: m.name);
      }
      final coarse = BaseMapLayer.zoomFor(50, -15.8);
      final fine = BaseMapLayer.zoomFor(0.5, -15.8);
      expect(fine, greaterThan(coarse));
      expect(fine, lessThanOrEqualTo(19));
      expect(coarse, greaterThanOrEqualTo(0));
      expect(BaseMapLayer.zoomFor(0.01, -15.8, maxZoom: BaseMapLayer.maxZoom(BaseMap.topo)), 17);
      expect(BaseMapLayer.zoomFor(0.01, -15.8, maxZoom: BaseMapLayer.maxZoom(BaseMap.googleSatellite)), 21);
    });

    test('google map tiles api: urls, session requests and errors', () {
      final u = BaseMapLayer.url(BaseMap.googleSatellite, 15, 100, 200, session: 'tok/en', key: 'AIza&x');
      expect(u, startsWith('https://tile.googleapis.com/v1/2dtiles/15/100/200?'));
      expect(u, contains('session=tok%2Fen'));
      expect(u, contains('key=AIza%26x'));
      expect(BaseMap.googleHybrid.isGoogle, isTrue);
      expect(BaseMap.satellite.isGoogle, isFalse);
      expect(BaseMapLayer.googleSessionRequest(BaseMap.googleRoads, 'en'), {'mapType': 'roadmap', 'language': 'en-US'});
      expect(BaseMapLayer.googleSessionRequest(BaseMap.googleHybrid, 'pt'), {'mapType': 'satellite', 'layerTypes': ['layerRoadmap'], 'language': 'pt-BR', 'region': 'BR'});
      expect(BaseMapLayer.googleSessionRequest(BaseMap.googleTerrain, 'es')['layerTypes'], ['layerRoadmap']);
      expect(BaseMapLayer.googleSessionRequest(BaseMap.googleSatellite, 'es'), {'mapType': 'satellite', 'language': 'es-419'});
      expect(HttpStatusException(400, '{"error": {"code": 400, "message": "API key not valid. Please pass a valid API key."}}').message, 'API key not valid. Please pass a valid API key.');
      expect(HttpStatusException(403).message, 'HTTP 403');
      expect(HttpStatusException(404).toString(), 'HTTP 404');
    });

    test('custom xyz templates', () {
      expect(BaseMapLayer.customUrl('https://t.example/{z}/{x}/{y}.png', 5, 3, 7), 'https://t.example/5/3/7.png');
      expect(BaseMapLayer.customUrl('https://{s}.t.example/{z}/{x}/{-y}.png?key=k', 5, 3, 7), 'https://b.t.example/5/3/24.png?key=k');
      expect(BaseMapLayer.customUrl('https://{s:xyz}.t.example/{z}/{x}/{y}', 5, 4, 7), 'https://z.t.example/5/4/7');
      expect(BaseMapLayer.isValidTemplate('https://t.example/{z}/{x}/{y}.png'), isTrue);
      expect(BaseMapLayer.isValidTemplate('http://t.example/{z}/{x}/{-y}.png'), isTrue);
      expect(BaseMapLayer.isValidTemplate('https://t.example/{z}/{x}.png'), isFalse);
      expect(BaseMapLayer.isValidTemplate('t.example/{z}/{x}/{y}.png'), isFalse);
      expect(BaseMapLayer.isValidTemplate(''), isFalse);
    });

    test('arcgis tilemap blocks say which tiles exist', () {
      expect(BaseMapLayer.esriTilemapUrl(BaseMap.satellite, 19, 192672, 285136), 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tilemap/19/192672/285136/32/32');
      expect(BaseMapLayer.esriTilemapUrl(BaseMap.esriTopo, 5, 0, 0), contains('World_Topo_Map/MapServer/tilemap/5/0/0/32/32'));
      // a full block without location: as asked, row-major
      final full = TileBlock.parse('{"data":[${List.filled(1024, 0).join(',')}]}', 100, 200);
      expect(full.contains(200, 100), isTrue);
      expect(full.contains(231, 131), isTrue);
      expect(full.contains(232, 100), isFalse);
      expect(full.has(210, 110), isFalse);
      // a block clipped by the server to 16 columns, tiles present
      final data = List.filled(16 * 32, 1);
      data[3 * 16 + 5] = 0; // row 3, column 5 missing
      final clipped = TileBlock.parse('{"adjusted":true,"location":{"height":32,"left":71280,"top":48160,"width":16},"valid":true,"data":[${data.join(',')}]}', 48160, 71280);
      expect(clipped.width, 16);
      expect(clipped.contains(71296, 48160), isFalse, reason: 'past the clipped edge: another block must be asked');
      expect(clipped.has(71280, 48160), isTrue);
      expect(clipped.has(71285, 48163), isFalse);
      expect(clipped.has(71286, 48163), isTrue);
      // errors mean no tiles
      final err = TileBlock.parse('{"error":{"code":422,"message":"Tiles not present"}}', 0, 0);
      expect(err.has(0, 0), isFalse);
      expect(TileBlock(0, 0, 32, 32, null).pending, isTrue);
      expect(TileBlock(0, 0, 32, 32, null).has(3, 3), isTrue, reason: 'unknown yet counts as present');
    });

    test('google viewport answers give the copyright and the maximum zoom', () {
      const text = '{"copyright":"Map data ©2026 Google","maxZoomRects":[{"maxZoom":19,"north":-15.5,"south":-15.7,"east":-47.6,"west":-47.8},{"maxZoom":22,"north":-15.0,"south":-15.2,"east":-47.0,"west":-47.2}]}';
      expect(BaseMapLayer.maxZoomFromViewport(text, -15.55, -15.65, -47.65, -47.75), 19);
      expect(BaseMapLayer.maxZoomFromViewport(text, -15.05, -15.15, -47.05, -47.15), 22);
      expect(BaseMapLayer.maxZoomFromViewport(text, -15.05, -15.65, -47.05, -47.75), 19, reason: 'both touched: the lowest wins');
      expect(BaseMapLayer.maxZoomFromViewport(text, 10, 9, 10, 9), isNull);
      expect(BaseMapLayer.maxZoomFromViewport('{"copyright":"x"}', 1, 0, 1, 0), isNull);
    });

    test('ancestor tile fallback picks the right quadrant', () {
      // tile (5, 7) at z+1 is the bottom-right quarter of (2, 3) at z
      expect(BaseMapLayer.ancestorSource(5, 7, 1, 256, 256), const Rect.fromLTWH(128, 128, 128, 128));
      // three levels up: 1/8 of the tile
      expect(BaseMapLayer.ancestorSource(9, 16, 3, 256, 256), const Rect.fromLTWH(32, 0, 32, 32));
      expect(BaseMapLayer.ancestorSource(0, 0, 2, 512, 512), const Rect.fromLTWH(0, 0, 128, 128));
    });

    test('google key and custom template are remembered per browser', () {
      removePref('basemap.googleKey');
      removePref('basemap.customUrl');
      final c = ProjectController();
      expect(c.googleMapsKey, isNull);
      c.setGoogleMapsKey('  AIzaTest ');
      expect(c.googleMapsKey, 'AIzaTest');
      expect(ProjectController().googleMapsKey, 'AIzaTest');
      final epoch = c.baseMapEpoch;
      c.setGoogleMapsKey('');
      expect(c.googleMapsKey, isNull);
      expect(c.baseMapEpoch, greaterThan(epoch));
      expect(getPref('basemap.googleKey'), isNull);
      c.setCustomTileUrl('https://t.example/{z}/{x}/{y}.png');
      expect(ProjectController().customTileUrl, 'https://t.example/{z}/{x}/{y}.png');
      c.setCustomTileUrl('');
      expect(getPref('basemap.customUrl'), isNull);
    });
  });

  group('camera', () {
    test('screen/world round trip, zoom, pan, fit and grid step', () {
      final cam = Camera(center: const Pt(10, 20), scale: 4, size: const Size(800, 600));
      final s = cam.toScreen(const Pt(15, 25));
      expect(s.dx, closeTo(420, 1e-9));
      expect(s.dy, closeTo(280, 1e-9));
      final w = cam.toWorld(s);
      expect(w.x, closeTo(15, 1e-9));
      expect(w.y, closeTo(25, 1e-9));
      cam.zoomAt(const Offset(400, 300), 2);
      expect(cam.scale, 8);
      final centreBefore = cam.center;
      cam.panPixels(const Offset(80, 0));
      expect(cam.center.x, lessThan(centreBefore.x));
      cam.fit(const Bounds(0, 0, 100, 50));
      expect(cam.center.x, closeTo(50, 1e-9));
      expect(cam.visible.width, greaterThanOrEqualTo(100));
      expect(cam.gridStep(), greaterThan(0));
      expect(cam.metersPerPixel, 1 / cam.scale);
    });
  });

  group('snapping', () {
    test('snaps to endpoints, midpoints, grid and ortho', () {
      final c = ProjectController();
      c.newProject();
      c.camera.scale = 10;
      c.camera.size = const Size(800, 600);
      c.camera.center = const Pt(5, 0);
      final line = LineEntity(id: 'l1', a: const Pt(0, 0), b: const Pt(10, 0));
      c.addEntity(line);
      final snapper = Snapper(c);
      c.snap.enabled = true;
      c.snap.tolerancePx = 10;
      expect(snapper.snap(const Pt(9.8, 0.3)).kind, 'endpoint');
      expect(snapper.snap(const Pt(5.1, 0.2)).kind, 'midpoint');
      expect(snapper.snap(const Pt(3, 0.3)).kind, 'none', reason: 'plain lines only snap at ends and middle');
      c.addEntity(PipeEntity(id: 'p1', points: [const Pt(0, -5), const Pt(10, -5)], scope: HydraulicScope.zone, pipeSpecId: 'x'));
      final on = snapper.snap(const Pt(3, -4.7));
      expect(on.kind, 'on');
      expect(on.point.y, closeTo(-5, 1e-9));
      expect(on.entityId, 'p1');
      c.addEntity(CircleEntity(id: 'c1', center: const Pt(20, 0), radius: 2));
      expect(snapper.snap(const Pt(20.2, 0.1)).kind, 'node');
      expect(snapper.snap(const Pt(22.3, 0)).kind, 'on');
      expect(snapper.snap(const Pt(50, 50)).kind, 'none');
      c.snap.ortho = true;
      final o = snapper.snap(const Pt(50, 51), reference: const Pt(40, 50));
      expect(o.kind, 'ortho');
      expect(o.point.y, closeTo(50, 1e-9));
      c.snap.ortho = false;
      c.snap.grid = true;
      c.snap.gridSize = 5;
      final g = snapper.snap(const Pt(50.4, 49.7));
      expect(g.kind, 'grid');
      expect(g.point.x, closeTo(50, 1e-9));
      expect(g.point.y, closeTo(50, 1e-9));
      c.snap.enabled = false;
      expect(snapper.snap(const Pt(9.8, 0.3)).isSnapped, isFalse);
    });
  });

  group('units', () {
    test('every unit converts to SI and back', () {
      for (final l in LengthUnit.values) {
        for (final f in FlowUnit.values) {
          for (final p in PressureUnit.values) {
            for (final d in DiameterUnit.values) {
              final u = Units(length: l, flow: f, pressure: p, diameter: d);
              expect(u.lengthFromSi(u.lengthToSi(12.5)), closeTo(12.5, 1e-9));
              expect(u.flowFromSi(u.flowToSi(7.25)), closeTo(7.25, 1e-9));
              expect(u.pressureFromHead(u.pressureToHead(3.3)), closeTo(3.3, 1e-9));
              expect(u.diameterFromSi(u.diameterToSi(50)), closeTo(50, 1e-9));
              expect(u.velocityToSi(u.velocityFromSi(1.5)), closeTo(1.5, 1e-9));
              expect(u.lengthLabel, isNotEmpty);
              expect(u.flowLabel, isNotEmpty);
              expect(u.pressureLabel, isNotEmpty);
              expect(u.diameterLabel, isNotEmpty);
              final back = Units.fromJson(u.toJson());
              expect(back.length, l);
              expect(back.flow, f);
              expect(back.pressure, p);
              expect(back.diameter, d);
            }
          }
        }
      }
      expect(Units.us.lengthLabel, 'ft');
      expect(Units.us.velocityLabel, 'ft/s');
      expect(Units.metric.lengthToSi(1), 1);
      expect(Units.fromJson(null).length, LengthUnit.m);
      expect(const Units(pressure: PressureUnit.psi).pressureToHead(14.2233), closeTo(10, 1e-2));
      expect(const Units(flow: FlowUnit.m3h).flowToSi(1), closeTo(1 / 3600, 1e-12));
    });
  });
}
