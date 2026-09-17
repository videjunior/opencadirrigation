import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/model/entities.dart';

const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document><name>Fazenda</name>
 <Folder><name>Curvas</name>
  <Placemark><name>500</name><LineString><coordinates>
   -47.9300,-15.7800,500 -47.9290,-15.7800,500 -47.9280,-15.7801,500
  </coordinates></LineString></Placemark>
  <Placemark><name>505</name><ExtendedData><Data name="ELEV"><value>505</value></Data></ExtendedData>
   <LineString><coordinates>-47.9300,-15.7790,0 -47.9280,-15.7790,0</coordinates></LineString></Placemark>
 </Folder>
 <Folder><name>Divisa</name>
  <Placemark><name>Talhão 1</name><Polygon><outerBoundaryIs><LinearRing><coordinates>
   -47.9300,-15.7800,0 -47.9280,-15.7800,0 -47.9280,-15.7790,0 -47.9300,-15.7790,0 -47.9300,-15.7800,0
  </coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>
 </Folder>
 <Placemark><name>Poço</name><Point><coordinates>-47.9295,-15.7795,498.5</coordinates></Point></Placemark>
</Document></kml>''';

void main() {
  test('UTM projection of a known point', () {
    final u = latLonToUtm(-15.78, -47.93); // Brasília, zone 23S
    expect(u.zone, 23);
    expect(u.north, isFalse);
    // reference values from the USGS (Snyder) transverse Mercator series
    expect(u.easting, closeTo(186056.581, 0.01));
    expect(u.northing, closeTo(8253215.209, 0.01));
  });

  test('KML parses folders, geometries and elevations into metres', () {
    final r = KmlReader.parse(kml);
    expect(r.placemarkCount, 4);
    final d = r.document;
    expect(d.layers.map((l) => l.name).toSet(), {'Curvas', 'Divisa', 'KML'});
    final polys = d.entities.where((e) => e.type == 'POLYLINE').toList();
    expect(polys.length, 3);
    final c500 = polys.firstWhere((e) => e.name == '500');
    expect(c500.elevation, 500);
    expect(c500.points.length, 3);
    // ~107 m between the first two vertices (0.001° of longitude at 15.8° S)
    expect(c500.points[0].distanceTo(c500.points[1]), closeTo(107, 3));
    final c505 = polys.firstWhere((e) => e.name == '505');
    expect(c505.elevation, 505);
    final talhao = polys.firstWhere((e) => e.closed);
    expect(talhao.points.length, 4);
    final well = d.entities.firstWhere((e) => e.type == 'POINT');
    expect(well.elevation, closeTo(498.5, 1e-9));
    expect(r.georef.zone, 23);
    // coordinates are near the local origin
    for (final p in c500.points) {
      expect(p.x.abs(), lessThan(1000));
      expect(p.y.abs(), lessThan(1000));
    }
  });

  test('KMZ unzips and parses', () {
    final archive = Archive()..addFile(ArchiveFile('doc.kml', utf8.encode(kml).length, utf8.encode(kml)));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final r = KmlReader.parseKmz(bytes);
    expect(r.placemarkCount, 4);
  });

  test('controller imports KML as contours, spot heights and polygons; DWG as drawing', () {
    final c = ProjectController();
    c.newProject();
    final summary = c.importFile('area.kml', Uint8List.fromList(utf8.encode(kml)));
    expect(summary, contains('KML'));
    expect(c.project.entities.whereType<ContourEntity>().length, 2);
    expect(c.project.entities.whereType<SpotHeightEntity>().single.elevation, closeTo(498.5, 1e-9));
    expect(c.project.entities.whereType<PolylineEntity>().where((p) => p.closed).length, 1);
    expect(c.project.meta.georef, isNotNull);
    expect(c.project.layers.any((l) => l.name == 'Curvas'), isTrue);
    // terrain built from the imported contours interpolates between them
    final t = c.project.buildTerrain();
    final c500 = c.project.entities.whereType<ContourEntity>().firstWhere((e) => e.elevation == 500);
    expect(t.elevationAt(c500.points.first), closeTo(500, 1e-6));
    // JSON round trip keeps the georeference
    final json = c.saveJson();
    c.loadJson(json);
    expect(c.project.meta.georef!.zone, 23);

    final dwg = File('test/fixtures/sample_2018.dwg').readAsBytesSync();
    final before = c.project.entities.length;
    final s2 = c.importFile('sample_2018.dwg', dwg);
    expect(s2, contains('DWG'));
    expect(c.project.entities.length, before + 6);
    expect(c.project.entities.whereType<TextEntity>().isNotEmpty, isTrue);
  });
}
