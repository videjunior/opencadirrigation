import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/gpx.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:xml/xml.dart';

String tr(String key, [Map<String, String>? args]) => key;

const georef = GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);

void main() {
  final p = buildExample(ExampleId.sportsField, tr)..meta.georef = georef;
  final results = Designer(p).designAll();

  test('the writer follows the GPX 1.1 element order and carries every point item', () {
    final gpx = GpxWriter.write(p, results: results, time: DateTime.utc(2026, 10, 25, 12));
    final doc = XmlDocument.parse(gpx);
    final root = doc.rootElement;
    expect(root.name.local, 'gpx');
    expect(root.getAttribute('version'), '1.1');
    expect(root.namespaceUri, 'http://www.topografix.com/GPX/1/1');
    final order = root.childElements.map((e) => e.name.local).toList();
    expect(order.first, 'metadata');
    // metadata, then every wpt, then every trk (the schema sequence)
    expect(order.lastIndexOf('wpt'), lessThan(order.indexOf('trk')));
    expect(root.getElement('metadata')!.getElement('time')!.innerText, '2026-10-25T12:00:00Z');
    final wpts = root.findElements('wpt').toList();
    final points = p.entities.where((e) => e is OutletEntity || e is ControlValveEntity || e is WaterSupplyEntity || e is PumpEntity || e is MiscHydraulicEntity || e is JunctionEntity || e is ControllerEntity).length;
    expect(wpts.length, points);
    const wptOrder = ['ele', 'time', 'magvar', 'geoidheight', 'name', 'cmt', 'desc', 'src', 'link', 'sym', 'type'];
    for (final w in wpts) {
      final names = w.childElements.map((e) => e.name.local).toList();
      final idx = names.map(wptOrder.indexOf).toList();
      expect(idx, orderedEquals([...idx]..sort()), reason: names.join(','));
      expect(w.getElement('ele'), isNotNull); // the field has a terrain
    }
    final valve = p.entities.whereType<ControlValveEntity>().first;
    final vw = wpts.firstWhere((w) => w.getElement('name')?.innerText == valve.zoneName);
    expect(vw.getElement('type')!.innerText, 'valve');
    expect(vw.getElement('cmt')!.innerText, isNotEmpty); // flow and pressure from the results
    expect(root.findElements('trk').length, greaterThan(5));
    // routes instead of tracks
    final rte = XmlDocument.parse(GpxWriter.write(p, lines: GpxLineKind.route)).rootElement;
    expect(rte.findElements('trk'), isEmpty);
    expect(rte.findElements('rte').length, root.findElements('trk').length);
  });

  test('written and read back: waypoints in place with their names and elevations', () {
    final gpx = GpxWriter.write(p, results: results);
    final r = GpxReader.parse(gpx, georef: georef);
    expect(r.waypointCount, greaterThan(40));
    final terrain = p.buildTerrain();
    for (final o in p.entities.whereType<OutletEntity>()) {
      final d = r.document.entities.firstWhere((d) => d.type == 'POINT' && d.points.first.distanceTo(o.position) < 2e-3, orElse: () => fail('outlet ${o.id} missing'));
      expect(d.elevation, closeTo(terrain.elevationAt(o.position), 0.006));
    }
    final pipe = p.entities.whereType<PipeEntity>().first;
    final line = r.document.entities.firstWhere((d) => d.type == 'POLYLINE' && d.points.length == pipe.points.length && d.points.first.distanceTo(pipe.points.first) < 2e-3);
    for (var i = 0; i < pipe.points.length; i++) {
      expect(line.points[i].distanceTo(pipe.points[i]), lessThan(2e-3));
    }
  });

  test('lateral outlets are staked out one by one', () {
    final q = buildExample(ExampleId.orchard, tr)..meta.georef = georef;
    final laterals = q.entities.whereType<SpraylineEntity>().toList();
    expect(laterals, isNotEmpty);
    final n = laterals.fold<int>(0, (s, l) => s + l.outletCount);
    final with_ = XmlDocument.parse(GpxWriter.write(q)).rootElement.findElements('wpt').length;
    final without = XmlDocument.parse(GpxWriter.write(q, lateralOutlets: false)).rootElement.findElements('wpt').length;
    expect(with_ - without, n);
  });

  test('a project without georeference cannot be written', () {
    expect(() => GpxWriter.write(Project()), throwsA(isA<GeoReferenceMissing>()));
  });

  test('GPX from a receiver: waypoints, a route and a track in two segments (GPX 1.0 too)', () {
    const gpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="receiver" xmlns="http://www.topografix.com/GPX/1/1">
  <wpt lat="-15.78000" lon="-47.93000"><ele>1001.5</ele><name>Poço</name><sym>Flag</sym></wpt>
  <wpt lat="-15.78100" lon="-47.93100"><ele>999.0</ele><name>Marco 2</name></wpt>
  <rte><name>Adutora</name><rtept lat="-15.78000" lon="-47.93000"/><rtept lat="-15.78050" lon="-47.92950"/><rtept lat="-15.78100" lon="-47.92900"/></rte>
  <trk><name>Divisa</name>
    <trkseg><trkpt lat="-15.7800" lon="-47.9300"><ele>1000</ele></trkpt><trkpt lat="-15.7810" lon="-47.9300"><ele>1002</ele></trkpt></trkseg>
    <trkseg><trkpt lat="-15.7810" lon="-47.9310"><ele>998</ele></trkpt><trkpt lat="-15.7800" lon="-47.9310"><ele>997</ele></trkpt></trkseg>
  </trk>
</gpx>''';
    final r = GpxReader.parse(gpx, pointsAsSpots: true);
    expect(r.waypointCount, 2);
    expect(r.routeCount, 1);
    expect(r.trackCount, 1);
    expect(r.georef!.zone, 23);
    final d = r.document;
    final well = d.entities.firstWhere((e) => e.type == 'POINT' && e.name == 'Poço');
    expect(well.elevation, 1001.5);
    expect(d.entities.where((e) => e.type == 'POLYLINE'), hasLength(3));
    expect(d.entities.firstWhere((e) => e.name == 'Adutora').points, hasLength(3));
    // walked track points with elevation become spot heights
    expect(d.entities.where((e) => e.type == 'POINT' && e.name.isEmpty).map((e) => e.elevation), [1000, 1002, 998, 997]);
    // the offset between the two waypoints is the one of their UTM coordinates
    final b = d.entities.firstWhere((e) => e.type == 'POINT' && e.name == 'Marco 2');
    final u1 = latLonToUtm(-15.78, -47.93, zone: 23), u2 = latLonToUtm(-15.781, -47.931, zone: 23);
    expect((well.points.first - b.points.first).x, closeTo(u1.easting - u2.easting, 1e-6));
    expect((well.points.first - b.points.first).y, closeTo(u1.northing - u2.northing, 1e-6));
    final v10 = GpxReader.parse(gpx.replaceFirst('version="1.1"', 'version="1.0"').replaceFirst('http://www.topografix.com/GPX/1/1', 'http://www.topografix.com/GPX/1/0'));
    expect(v10.waypointCount, 2);
    expect(() => GpxReader.parse('<kml/>'), throwsA(isA<FormatException>()));
  });
}
