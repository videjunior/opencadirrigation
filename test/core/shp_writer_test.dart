import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/shp.dart';
import 'package:opencadirrigation/core/io/shp_writer.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

String tr(String key, [Map<String, String>? args]) => key;

/// Minimal independent dBASE reader for the checks: field name → values.
List<Map<String, String>> readDbf(Uint8List b) {
  final bd = ByteData.sublistView(b);
  final n = bd.getUint32(4, Endian.little), hl = bd.getUint16(8, Endian.little), rl = bd.getUint16(10, Endian.little);
  final fields = <(String, int)>[];
  for (var off = 32; b[off] != 0x0D; off += 32) {
    fields.add((latin1.decode(b.sublist(off, off + 11).takeWhile((c) => c != 0).toList()), b[off + 16]));
  }
  expect(hl, 32 + 32 * fields.length + 1);
  expect(rl, 1 + fields.fold<int>(0, (s, f) => s + f.$2));
  expect(b.last, 0x1A);
  return [
    for (var r = 0; r < n; r++)
      () {
        var p = hl + r * rl + 1;
        final m = <String, String>{};
        for (final (name, len) in fields) {
          m[name] = utf8.decode(b.sublist(p, p + len)).trim();
          p += len;
        }
        return m;
      }(),
  ];
}

const georef = GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);

void main() {
  final p = buildExample(ExampleId.sportsField, tr)..meta.georef = georef;
  final results = Designer(p).designAll();
  p.entities.add(PolylineEntity(id: 'poly1', points: const [Pt(0, 0), Pt(0, 10), Pt(10, 10), Pt(10, 0)], closed: true, name: 'Talhão São João'));
  p.entities.add(ContourEntity(id: 'c1', points: const [Pt(0, -5), Pt(50, -5), Pt(100, -5)], elevation: 99.75));

  test('one shapefile per layer and geometry type, with .shx, .dbf, .cpg and .prj', () {
    final w = ShapefileWriter(project: p, results: results);
    final files = w.shapefiles();
    final names = files.map((f) => f.name).toSet();
    expect(names, containsAll(['OUTLETS_points', 'ZONE_PIPES_lines', 'MAINLINE_PIPES_lines', 'CONTROL_VALVES_points', 'CONTOURS_lines', 'SPOT_HEIGHTS_points', 'DRAWING_polygons', 'AREAS_polygons']));
    expect(w.warnings, isEmpty);
    for (final f in files) {
      // the index points at every record header of the main file
      final shp = ByteData.sublistView(f.shp), shx = ByteData.sublistView(f.shx);
      expect(shp.getInt32(24, Endian.big) * 2, f.shp.length);
      expect(shx.getInt32(24, Endian.big) * 2, f.shx.length);
      expect((f.shx.length - 100) ~/ 8, f.recordCount);
      for (var i = 0; i < f.recordCount; i++) {
        final off = shx.getInt32(100 + 8 * i, Endian.big) * 2;
        expect(shp.getInt32(off, Endian.big), i + 1);
        expect(shp.getInt32(off + 4, Endian.big), shx.getInt32(104 + 8 * i, Endian.big));
        expect(shp.getInt32(off + 8, Endian.little), f.shapeType.code);
      }
      expect(readDbf(f.dbf).length, f.recordCount);
      final crs = parseCrs(f.prj!);
      expect(crs.datum, GeodeticDatum.sirgas2000);
      expect(crs.utmZone, 23);
      expect(crs.north, isFalse);
    }
    // Z where it means something: contours and spot heights, and the pipes and
    // heads over the terrain of the field
    ShapefileParts named(String n) => files.firstWhere((f) => f.name == n);
    expect(named('CONTOURS_lines').shapeType, ShpShapeType.polyLineZ);
    expect(named('SPOT_HEIGHTS_points').shapeType, ShpShapeType.pointZ);
    expect(named('ZONE_PIPES_lines').shapeType, ShpShapeType.polyLineZ);
    expect(named('DRAWING_polygons').shapeType, ShpShapeType.polygon);
  });

  test('re-read by our shapefile reader: positions, names, elevations and attributes', () {
    final files = ShapefileWriter(project: p, results: results).shapefiles();
    for (final f in files) {
      final r = ShpReader.parse(f.shp, dbf: f.dbf, prj: f.prj, cpg: f.cpg, georef: georef, layer: f.name);
      expect(r.recordCount, f.recordCount);
      expect(r.geographic, isFalse);
      final rows = readDbf(f.dbf);
      for (var i = 0; i < rows.length; i++) {
        final e = p.byId(rows[i]['ID']!)!;
        final pts = e is PointEntity ? [e.position] : (e is PolyEntity ? e.points : const <Pt>[]);
        if (pts.isEmpty) continue;
        final back = r.document.entities.where((d) => d.type == 'POINT' || d.type == 'POLYLINE').toList()[i];
        expect(back.points.length, pts.length, reason: e.id);
        // polygon rings are written clockwise: compare as sets
        for (final q in pts) {
          expect(back.points.any((b) => b.distanceTo(q) < 1e-6), isTrue, reason: '${e.id} $q');
        }
        expect(rows[i]['TYPE'], e.type.name);
        expect(rows[i]['LAYER'], e.layer);
      }
    }
    // UTF-8 names through the .cpg, elevations, flows and diameters
    final drawing = files.firstWhere((f) => f.name == 'DRAWING_polygons');
    expect(readDbf(drawing.dbf).map((r) => r['NAME']), contains('Talhão São João'));
    final contour = ShpReader.parse(files.firstWhere((f) => f.name == 'CONTOURS_lines').shp, dbf: files.firstWhere((f) => f.name == 'CONTOURS_lines').dbf, cpg: 'UTF-8', georef: georef);
    expect(contour.document.entities.single.elevation, 99.75);
    final pipes = readDbf(files.firstWhere((f) => f.name == 'ZONE_PIPES_lines').dbf);
    final pipeEntity = p.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.zone);
    final row = pipes.firstWhere((r) => r['ID'] == pipeEntity.id);
    final spec = p.catalog.pipe(pipeEntity.pipeSpecId)!;
    expect(double.parse(row['ID_MM']!), closeTo(spec.innerDiameterMm, 0.01));
    expect(double.parse(row['DN_MM']!), spec.nominalMm);
    final seg = results.pipesByEntity[pipeEntity.id]!.reduce((a, b) => a.flow.abs() > b.flow.abs() ? a : b);
    expect(double.parse(row['FLOW_LPH']!), closeTo(seg.flow.abs() * 3.6e6, 0.01));
    expect(double.parse(row['PMIN_MCA']!), lessThanOrEqualTo(double.parse(row['PMAX_MCA']!)));
    final valves = readDbf(files.firstWhere((f) => f.name == 'CONTROL_VALVES_points').dbf);
    final z = results.zones.values.first;
    expect(double.parse(valves.firstWhere((r) => r['ID'] == z.valveId)['PREQ_MCA']!), closeTo(z.requiredUpstreamHead, 0.001));
  });

  test('polygons are clockwise and closed', () {
    final f = ShapefileWriter(project: p, results: results).shapefiles().firstWhere((f) => f.name == 'DRAWING_polygons');
    final bd = ByteData.sublistView(f.shp);
    // first record: header 100 + record header 8
    const s = 108;
    final n = bd.getInt32(s + 40, Endian.little);
    final pts = [for (var i = 0; i < n; i++) (bd.getFloat64(s + 48 + 16 * i, Endian.little), bd.getFloat64(s + 56 + 16 * i, Endian.little))];
    expect(pts.first, pts.last);
    var a = 0.0;
    for (var i = 0; i + 1 < pts.length; i++) {
      a += pts[i].$1 * pts[i + 1].$2 - pts[i + 1].$1 * pts[i].$2;
    }
    expect(a, lessThan(0));
  });

  test('geographic coordinates with a WGS 84 .prj; local metres without a georeference', () {
    final geo = ShapefileWriter(project: p, results: results, geographic: true, datum: GeodeticDatum.wgs84).shapefiles();
    final f = geo.firstWhere((f) => f.name == 'OUTLETS_points');
    expect(parseCrs(f.prj!).kind, CrsKind.geographic);
    final r = ShpReader.parse(f.shp, dbf: f.dbf, prj: f.prj, cpg: f.cpg, georef: georef);
    expect(r.geographic, isTrue);
    final first = p.byId(readDbf(f.dbf).first['ID']!) as OutletEntity;
    expect(r.document.entities.first.points.first.distanceTo(first.position), lessThan(0.01));
    final local = Project.fromJson(p.toJson())..meta.georef = null;
    final w = ShapefileWriter(project: local);
    final lf = w.shapefiles();
    expect(w.warnings, ['shp_no_georef']);
    expect(lf.every((f) => f.prj == null), isTrue);
    final lr = ShpReader.parse(lf.firstWhere((f) => f.name == 'OUTLETS_points').shp);
    expect(lr.document.entities.first.points.first.distanceTo(first.position), lessThan(1e-9));
  });

  test('the zip holds every part and splits back', () {
    final zip = ShapefileWriter(project: p, results: results).zip();
    final parts = ShapefileParts.unzip(zip);
    expect(parts.map((s) => s.name).toSet(), ShapefileWriter(project: p, results: results).shapefiles().map((s) => s.name).toSet());
    expect(parts.every((s) => s.cpg == 'UTF-8' && s.prj != null && s.dbf.isNotEmpty && s.shx.isNotEmpty), isTrue);
    // the whole zip through the reader the app uses (first shapefile)
    final r = ShpReader.parseAny('project.zip', zip, georef: georef);
    expect(r.recordCount, greaterThan(0));
  });
}
