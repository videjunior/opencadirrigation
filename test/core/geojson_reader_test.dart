import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/geojson_reader.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

String tr(String key, [Map<String, String>? args]) => key;

void main() {
  test('our GeoJSON export reads back in place: pipes, heads, valves, contours', () {
    final p = buildExample(ExampleId.orchard, tr)..meta.georef = const GeoReference(zone: 22, north: false, originEasting: 612300, originNorthing: 7412800);
    final results = Designer(p).designAll();
    final text = ProjectExporter(
      project: p,
      results: results,
      labels: ReportLabels(t: tr, has: (_) => false, warning: (w) => w),
    ).geoJson();
    final r = GeoJsonReader.parse(text, georef: p.meta.georef);
    expect(r.georef, same(p.meta.georef));
    expect(r.warnings, isEmpty);
    expect(r.crs.kind, CrsKind.geographic);
    final polylines = r.document.entities.where((e) => e.type == 'POLYLINE').toList();
    final points = r.document.entities.where((e) => e.type == 'POINT').toList();
    // the export rounds degrees to 8 decimals: about a millimetre
    for (final e in p.entities.whereType<PipeEntity>()) {
      final match = polylines.where((d) => d.points.length == e.points.length && [for (var i = 0; i < e.points.length; i++) d.points[i].distanceTo(e.points[i])].every((x) => x < 2e-3));
      expect(match, isNotEmpty, reason: e.id);
      expect(match.first.layer, e.layer);
    }
    for (final e in p.entities.whereType<ControlValveEntity>()) {
      final d = points.firstWhere((d) => d.points.first.distanceTo(e.position) < 2e-3);
      expect(d.name, e.zoneName);
      expect(d.layer, Layers.controlValves);
    }
    expect(
      r.featureCount,
      ProjectExporter(
        project: p,
        results: results,
        labels: ReportLabels(t: tr, has: (_) => false, warning: (w) => w),
      ).geoFeatures().length,
    );
    // contour lines keep their elevation (third coordinate and ELEV)
    final contours = p.entities.whereType<ContourEntity>().toList();
    if (contours.isNotEmpty) {
      final c = contours.first;
      final d = polylines.firstWhere((d) => d.points.first.distanceTo(c.points.first) < 2e-3);
      expect(d.elevation, closeTo(c.elevation, 1e-3));
    }
  });

  test('a FeatureCollection in SIRGAS 2000 / UTM with the legacy crs member, every geometry type', () {
    const text = '''
{"type": "FeatureCollection",
 "crs": {"type": "name", "properties": {"name": "urn:ogc:def:crs:EPSG::31983"}},
 "features": [
  {"type": "Feature", "properties": {"nome": "Poço 1", "cota": "812,5"}, "geometry": {"type": "Point", "coordinates": [186100.0, 8253300.0]}},
  {"type": "Feature", "properties": {"name": "Linha"}, "geometry": {"type": "LineString", "coordinates": [[186000, 8253200, 805], [186050, 8253200, 805], [186100, 8253250, 805]]}},
  {"type": "Feature", "properties": {"id": 7, "layer": "Talhões"}, "geometry": {"type": "MultiPolygon", "coordinates": [
     [[[186000, 8253200], [186100, 8253200], [186100, 8253300], [186000, 8253300], [186000, 8253200]],
      [[186040, 8253240], [186060, 8253240], [186060, 8253260], [186040, 8253240]]],
     [[[186200, 8253200], [186300, 8253200], [186300, 8253300], [186200, 8253200]]]]}},
  {"type": "Feature", "properties": null, "geometry": {"type": "GeometryCollection", "geometries": [
     {"type": "MultiPoint", "coordinates": [[186010, 8253210, 806.25], [186020, 8253220, 807.5]]},
     {"type": "MultiLineString", "coordinates": [[[186000, 8253400], [186100, 8253400]], [[186000, 8253410], [186100, 8253410]]]}]}},
  {"type": "Feature", "properties": {"name": "sem geometria"}, "geometry": null}
 ]}''';
    final r = GeoJsonReader.parse(text);
    expect(r.crs.epsgCode, 31983);
    expect(r.georef!.zone, 23);
    expect(r.georef!.north, isFalse);
    expect(r.featureCount, 4);
    final d = r.document;
    Pt local(double e, double n) => Pt(e - r.georef!.originEasting, n - r.georef!.originNorthing);
    final well = d.entities.firstWhere((e) => e.type == 'POINT' && e.name == 'Poço 1');
    expect(well.elevation, 812.5);
    expect(well.points.first.distanceTo(local(186100, 8253300)), lessThan(1e-6));
    expect(d.entities.where((e) => e.type == 'TEXT' && e.text == 'Poço 1'), hasLength(1));
    final line = d.entities.firstWhere((e) => e.name == 'Linha');
    expect(line.elevation, 805); // constant third coordinate
    final rings = d.entities.where((e) => e.type == 'POLYLINE' && e.closed).toList();
    expect(rings, hasLength(3)); // outer, hole, second polygon
    expect(rings.every((e) => e.layer == 'Talhões' && e.name == '7'), isTrue);
    expect(rings.first.points, hasLength(4)); // closing vertex dropped
    final multi = d.entities.where((e) => e.type == 'POINT' && e.elevation != null && e.name.isEmpty).toList();
    expect(multi.map((e) => e.elevation), [806.25, 807.5]);
    expect(d.entities.where((e) => e.type == 'POLYLINE' && !e.closed && e.layer == 'GEOJSON'), hasLength(3));
    expect(d.layers.map((l) => l.name).toSet(), {'GEOJSON', 'Talhões'});
  });

  test('RFC 7946 longitude/latitude, a bare geometry, and data in SAD 69 shifted to SIRGAS 2000', () {
    final r = GeoJsonReader.parse(
      jsonEncode({
        'type': 'Point',
        'coordinates': [-47.93, -15.78, 1000.5],
      }),
    );
    expect(r.georef!.zone, 23);
    expect(r.document.entities.single.elevation, 1000.5);
    // the same position given in SAD 69 / UTM 23S (EPSG:29193) lands on it
    final sad = CrsInfo.utm(23, false, datum: GeodeticDatum.sad69);
    final (e, n) = sad.fromWgs84(-15.78, -47.93);
    final s = GeoJsonReader.parse(
      jsonEncode({
        'type': 'Feature',
        'crs': {
          'type': 'name',
          'properties': {'name': 'EPSG:29193'},
        },
        'properties': {},
        'geometry': {
          'type': 'Point',
          'coordinates': [e, n],
        },
      }),
      georef: r.georef,
    );
    expect(s.document.entities.single.points.single.distanceTo(r.document.entities.single.points.single), lessThan(0.01));
    expect(s.warnings, contains(startsWith('crs_datum_shift:sad69')));
  });

  test('an unrecognised crs is reported, not guessed', () {
    final r = GeoJsonReader.parse(
      jsonEncode({
        'type': 'FeatureCollection',
        'crs': {
          'type': 'name',
          // web Mercator (Brazil Polyconic, 5880, is known since 1.6.0)
          'properties': {'name': 'urn:ogc:def:crs:EPSG::3857'},
        },
        'features': [
          {
            'type': 'Feature',
            'properties': {},
            'geometry': {
              'type': 'Point',
              'coordinates': [5512345.5, 8123456.5],
            },
          },
        ],
      }),
    );
    expect(r.warnings, contains('crs_epsg_unknown'));
    expect(r.georef, isNull);
    expect(r.localOrigin, const Pt(5512300, 8123500));
    expect(() => GeoJsonReader.parse('[1, 2]'), throwsA(isA<FormatException>()));
    expect(() => GeoJsonReader.parse('{not json'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'geojson_invalid')));
  });
}
