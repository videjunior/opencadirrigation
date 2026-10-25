import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/epanet_inp.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/shp_writer.dart';
import 'package:opencadirrigation/core/model/entities.dart';

/// The exchange formats through the app: every new import lands in the
/// project (points without elevation as markers, not as zero spot heights),
/// zips with several shapefiles bring every layer, and every new export
/// format is produced from a designed example.
void main() {
  final fixtures = Directory('test/fixtures/formats');
  Uint8List fixture(String name) => File('${fixtures.path}/$name').readAsBytesSync();

  ProjectController fresh() {
    final c = ProjectController();
    c.setLanguage('pt');
    c.newProject();
    return c;
  }

  ProjectController designed(ExampleId id) {
    final c = fresh();
    loadExampleAction(c, id);
    c.results = Designer(c.project).designAll();
    return c;
  }

  test('GeoJSON: lines and polygons in WGS 84, points without height become markers', () {
    final c = fresh();
    final text = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {'type': 'Feature', 'properties': {'name': 'Poço'}, 'geometry': {'type': 'Point', 'coordinates': [-47.9301, -15.7801]}},
        {'type': 'Feature', 'properties': {'name': 'Cota'}, 'geometry': {'type': 'Point', 'coordinates': [-47.9302, -15.7802, 1051.5]}},
        {'type': 'Feature', 'properties': {}, 'geometry': {'type': 'LineString', 'coordinates': [[-47.9300, -15.7800], [-47.9290, -15.7800]]}},
        {'type': 'Feature', 'properties': {}, 'geometry': {'type': 'Polygon', 'coordinates': [[[-47.931, -15.781], [-47.930, -15.781], [-47.930, -15.780], [-47.931, -15.781]]]}},
      ],
    });
    final s = c.importFile('talhoes.geojson', Uint8List.fromList(utf8.encode(text)));
    expect(s, startsWith('GeoJSON: 4'));
    expect(c.project.meta.georef!.zone, 23);
    expect(c.project.entities.whereType<CircleEntity>().single.name, 'Poço');
    final spot = c.project.entities.whereType<SpotHeightEntity>().single;
    expect(spot.elevation, closeTo(1051.5, 1e-9));
    final line = c.project.entities.whereType<PolylineEntity>().firstWhere((p) => !p.closed);
    expect(line.length, closeTo(107.1, 1.0), reason: '0.001° of longitude at 15.78° S');
  });

  test('GPX waypoints with elevation are spot heights, tracks are polylines', () {
    final c = fresh();
    const xml = '<?xml version="1.0"?><gpx version="1.1" creator="t" xmlns="http://www.topografix.com/GPX/1/1">'
        '<wpt lat="-15.78" lon="-47.93"><ele>1050</ele><name>P1</name></wpt><wpt lat="-15.781" lon="-47.931"><name>Marco</name></wpt>'
        '<trk><name>Linha</name><trkseg><trkpt lat="-15.78" lon="-47.93"/><trkpt lat="-15.78" lon="-47.929"/></trkseg></trk></gpx>';
    final s = c.importFile('campo.gpx', Uint8List.fromList(utf8.encode(xml)));
    expect(s, contains('2'));
    expect(c.project.entities.whereType<SpotHeightEntity>().single.elevation, 1050);
    expect(c.project.entities.whereType<CircleEntity>().single.name, 'Marco');
    expect(c.project.entities.whereType<PolylineEntity>(), isNotEmpty);
  });

  test('LAS ground points become terrain; LAZ is refused with a clear message', () {
    final c = fresh();
    final s = c.importFile('nuvem.las', fixture('las14_f6.las'));
    expect(s, startsWith('Nuvem de pontos'));
    final spots = c.project.entities.whereType<SpotHeightEntity>().toList();
    expect(spots, isNotEmpty);
    expect(spots.every((p) => p.name == 'DEM nuvem.las'), isTrue);
    // importing it again replaces the grid instead of doubling it
    c.importFile('nuvem.las', fixture('las14_f6.las'));
    expect(c.project.entities.whereType<SpotHeightEntity>().length, spots.length);
    try {
      c.importFile('nuvem.laz', fixture('las14_f6.laz'));
      fail('LAZ should be refused');
    } on FormatException catch (e) {
      expect(c.describeError(e), contains('LAZ'));
    }
    expect(c.describeError(const FormatException('las_format_unsupported:7')), contains('7'));
  });

  test('DGN V7 drawings are imported with their units', () {
    final c = fresh();
    final s = c.importFile('planta.dgn', fixture('dgn7_2d_elements.dgn'));
    expect(s, startsWith('DGN:'));
    expect(c.project.entities, isNotEmpty);
  });

  test('an EPANET network round-trips into the drawing', () {
    final src = designed(ExampleId.sportsField);
    final inp = EpanetWriter.write(src.project, results: src.results).text;
    final c = fresh();
    final s = c.importFile('rede.inp', Uint8List.fromList(utf8.encode(inp)));
    expect(s, startsWith('EPANET:'));
    expect(c.project.entities.whereType<PolylineEntity>(), isNotEmpty);
  });

  test('a zip with several shapefiles brings every layer', () {
    final src = designed(ExampleId.orchard);
    src.project.meta.georef ??= const GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);
    final zip = ShapefileWriter(project: src.project, results: src.results).zip();
    expect(ShapefileParts.unzip(zip).length, greaterThan(1));
    final c = fresh();
    final s = c.importFile('projeto.zip', zip);
    expect(s, startsWith('SHP:'));
    final layers = {for (final e in c.project.entities) e.layer};
    expect(layers.length, greaterThan(1));
    expect(c.project.meta.georef!.zone, 23);
  });

  test('every new drawing format is exported from a designed example', () {
    final c = designed(ExampleId.orchard);
    c.project.meta.georef ??= const GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);
    for (final f in [DrawingFormat.shp, DrawingFormat.gpx, DrawingFormat.landxml, DrawingFormat.ifc, DrawingFormat.inp]) {
      final data = c.exporter().exportDrawing(f);
      expect(f.isBinary ? (data as Uint8List).length : (data as String).length, greaterThan(200), reason: f.name);
      expect(c.t.has('exp.${f.name}'), isTrue, reason: 'menu label of ${f.name}');
    }
    expect(DrawingFormat.gpx.needsGeoref, isTrue);
    expect((c.exporter().exportDrawing(DrawingFormat.ifc) as String), startsWith('ISO-10303-21;'));
    expect((c.exporter().exportDrawing(DrawingFormat.inp) as String), contains('[JUNCTIONS]'));
    for (final ext in ['.geojson', '.gpx', '.xml', '.las', '.dgn', '.inp']) {
      expect(importAccept.split(','), contains(ext));
    }
  });
}
