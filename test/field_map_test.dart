import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/basemap.dart';
import 'package:opencadirrigation/app/canvas/seen_tiles.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/field_map.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/io/data_credits.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// The map of the area kept for the field (PRD-09): only what the terms of the provider allow (the tiles already
/// shown for OpenStreetMap, OpenTopoMap, CARTO and Esri, the user's own server downloaded, nothing for Google), drawn
/// into one picture of the project that carries the credit of the map. No network: the tiles are made here.
void main() {
  final tile = Uint8List.fromList(img.encodePng(img.fill(img.Image(width: 256, height: 256), color: img.ColorRgb8(120, 160, 90))));

  test('what the terms of each base map allow for a map kept for the field', () {
    expect(fieldMapSource(BaseMap.streets), FieldMapSource.seen, reason: 'the OpenStreetMap Foundation forbids downloading areas for offline use');
    for (final m in [BaseMap.topo, BaseMap.carto, BaseMap.satellite, BaseMap.esriStreets, BaseMap.esriTopo]) {
      expect(fieldMapSource(m), FieldMapSource.seen, reason: m.name);
    }
    expect(fieldMapSource(BaseMap.custom), FieldMapSource.download, reason: "the user's own server");
    for (final m in [BaseMap.none, BaseMap.googleRoads, BaseMap.googleSatellite, BaseMap.googleHybrid, BaseMap.googleTerrain]) {
      expect(fieldMapSource(m), FieldMapSource.refused, reason: m.name);
    }
  });

  test('the tiles shown are kept by address, the least recently used dropped first', () {
    final s = SeenTiles(maxTiles: 3, maxBytes: 100);
    s.put('a', Uint8List(10));
    s.put('b', Uint8List(10));
    s.put('c', Uint8List(10));
    expect(s['a'], isNotNull, reason: 'a is now the most recently used');
    s.put('d', Uint8List(10));
    expect(s['b'], isNull, reason: 'the least recently used went');
    expect(s.length, 3);
    s.put('e', Uint8List(80));
    expect(s.bytes, lessThanOrEqualTo(100));
    s.put('huge', Uint8List(200));
    expect(s['huge'], isNull, reason: 'larger than the whole store');
    s.clear();
    expect((s.length, s.bytes), (0, 0));
  });

  group('keeping the map', () {
    late ProjectController c;
    setUp(() async {
      LocalProjectStore().clearAll();
      c = ProjectController()
        ..autosaveEnabled = false
        ..designRunner = InThreadDesignRunner();
      c.newProject();
      await c.setLanguage('en', persist: false);
      loadExampleAction(c, ExampleId.garden);
      c.project.meta.georef = GeoReference.fromLatLonOrigin(-20.3, -47.4);
      c.baseMap = BaseMap.streets;
    });

    /// The street map tiles over [area] at zooms 14 to 19, as a page that showed the area would have kept them.
    SeenTiles shown(Bounds area) {
      final seen = SeenTiles(maxTiles: 100000, maxBytes: 1 << 30);
      final g = c.project.meta.georef!;
      final (lat0, lon0) = g.toLatLon(area.minX, area.minY);
      final (lat1, lon1) = g.toLatLon(area.maxX, area.maxY);
      for (var z = 14; z <= 19; z++) {
        final n = math.pow(2, z).toDouble();
        int tx(double lon) => ((lon + 180) / 360 * n).floor();
        int ty(double lat) {
          final r = lat * math.pi / 180;
          return ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n).floor();
        }

        for (var x = tx(lon0); x <= tx(lon1); x++) {
          for (var y = ty(lat1); y <= ty(lat0); y++) {
            seen.put(BaseMapLayer.url(BaseMap.streets, z, x, y), tile);
          }
        }
      }
      return seen;
    }

    testWidgets('from the tiles already shown only, under the drawing, with the credit of the map, one undo step', (tester) async {
      final drawing = c.project.bounds;
      final seen = shown(drawing.inflate(400));
      final before = c.project.entities.length;
      late FieldMap r;
      await tester.runAsync(() async {
        r = await keepFieldMap(c, seen: seen);
      });
      expect(c.project.entities.length, before + 1);
      expect(identical(c.project.entities.first, r.image), isTrue, reason: 'under everything else');
      expect(r.image.layer, Layers.images);
      expect(r.image.mime, 'image/jpeg');
      expect(r.image.data, isNotNull);
      expect(img.decodeJpg(r.image.data!), isNotNull);
      expect(baseMapPictureCredit(r.image), BaseMapLayer.attribution(BaseMap.streets));
      expect(r.tiles, greaterThan(0));
      final b = r.image.bounds;
      expect(b.minX <= drawing.minX && b.minY <= drawing.minY && b.maxX >= drawing.maxX && b.maxY >= drawing.maxY, isTrue, reason: 'it covers the drawing');
      // the report and the sheets credit it
      expect(projectDataCredits(c.project).where((d) => d.kind == DataKind.baseMap), hasLength(1));
      c.undo();
      expect(c.project.entities.length, before, reason: 'one undo step');
    });

    testWidgets('nothing shown there yet, a Google map, no georeference: nothing kept, and why', (tester) async {
      Future<String?> keep({SeenTiles? seen}) async {
        String? key;
        await tester.runAsync(() async {
          try {
            await keepFieldMap(c, seen: seen ?? SeenTiles());
          } on FieldMapError catch (e) {
            key = e.key;
          }
        });
        return key;
      }

      final before = c.project.entities.length;
      expect(await keep(), 'fieldmap.err.notSeen', reason: 'no tile is downloaded from a shared server');
      c.baseMap = BaseMap.googleSatellite;
      expect(await keep(), 'fieldmap.err.google');
      c.baseMap = BaseMap.none;
      expect(await keep(), 'fieldmap.err.noMap');
      c.baseMap = BaseMap.streets;
      c.project.meta.georef = null;
      expect(await keep(), 'fieldmap.err.noGeo');
      expect(c.project.entities.length, before);
    });
  });
}
