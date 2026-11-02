/// Islands of irrigated areas (1.6.0 MOD, AUT-29): the holes of an area are
/// left out of its surface, of the water it needs, of the layout and of the
/// pictures, and the exports carry them (DXF/DWG hatch islands, inner rings
/// of SHP, GeoJSON and KML); "Subtract from area" makes them.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/cad_drawing.dart';
import 'package:opencadirrigation/core/io/cad_export.dart';
import 'package:opencadirrigation/core/io/dxf_r2000.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/sheet_canvas.dart';
import 'package:opencadirrigation/core/io/shp_writer.dart';
import 'package:opencadirrigation/core/model/area_holes.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/read_report.dart';
import 'package:opencadirrigation/core/model/split.dart' show offsetEntity;

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// A 40 × 30 m lawn.
AreaEntity _lawn({String id = 'a1'}) => AreaEntity(id: id, name: 'Lawn', points: _rect(0, 0, 40, 30));

double _ring(List<List<double>> r) {
  var a = 0.0;
  for (var i = 0; i + 1 < r.length; i++) {
    a += r[i][0] * r[i + 1][1] - r[i + 1][0] * r[i][1];
  }
  return a / 2;
}

ProjectExporter _exporter(Project p) {
  final en = I18n('en');
  return ProjectExporter(
    project: p,
    labels: ReportLabels(t: en.call, has: en.has, warning: (w) => en.warning(w)),
    layerNames: {for (final l in p.layers) l.name: l.name},
  );
}

void main() {
  group('the model', () {
    test('an island is left out of the surface, of the area and of a click', () {
      final a = _lawn()..holes = [_rect(10, 10, 20, 20)];
      expect(a.grossArea, closeTo(1200, 1e-9));
      expect(a.area, closeTo(1100, 1e-9));
      expect(a.contains(const Pt(5, 5)), isTrue);
      expect(a.contains(const Pt(15, 15)), isFalse);
      expect(a.inHole(const Pt(15, 15)), isTrue);
      // the heads round an island stand on its outline: in the area
      expect(a.inHole(const Pt(10, 15)), isFalse);
      expect(a.distanceTo(const Pt(5, 5)), 0);
      expect(a.distanceTo(const Pt(15, 15)), closeTo(5, 1e-9));
      expect(_lawn().area, closeTo(1200, 1e-9));
    });

    test('written only when there are islands, read back, moved and copied with the area', () {
      expect(_lawn().toJson().containsKey('holes'), isFalse);
      final a = _lawn()..holes = [_rect(10, 10, 20, 20)];
      final j = a.toJson();
      expect(j['holes'], [
        [
          [10.0, 10.0],
          [20.0, 10.0],
          [20.0, 20.0],
          [10.0, 20.0],
        ],
      ]);
      final back = Entity.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>) as AreaEntity;
      expect(back.holes.single, _rect(10, 10, 20, 20));
      expect(back.area, closeTo(1100, 1e-9));
      expect(back.extra, isNull, reason: 'a field this version knows, not one kept as unknown');
      // a ring too short is dropped, a vertex without coordinates too
      final report = ProjectReadReport();
      final damaged = Entity.fromJson({
        'type': 'area',
        'id': 'a2',
        'pts': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
        'holes': [
          [
            [1, 1],
            [2, 1],
          ],
          [
            [6, 2],
            [8, 2],
            [null, 3],
            [8, 4],
          ],
        ],
      }, report: report) as AreaEntity;
      expect(damaged.holes.length, 1);
      expect(damaged.holes.single.length, 3);
      expect(report.droppedVertices, 1);
      // moving, transforming and copying keep the islands with the outline
      expect(a.translated(const Pt(5, 0)).holes.single.first, const Pt(15, 10));
      expect(a.transformed(Affine.translation(const Pt(0, 2))).holes.single.first, const Pt(10, 12));
      final copy = a.clone(newId: 'a9');
      copy.holes.single[0] = const Pt(11, 11);
      expect(a.holes.single[0], const Pt(10, 10), reason: 'a deep copy');
    });

    test('an offset copy moves its islands the other way: they shrink as the outline grows', () {
      final a = _lawn()..holes = [_rect(10, 10, 20, 20)];
      // the outline runs counter-clockwise: to its right (a negative offset) it grows
      final grown = offsetEntity(a, -1, 'a3') as AreaEntity;
      expect(grown.grossArea, closeTo(42 * 32, 1e-6));
      expect(polygonArea(grown.holes.single).abs(), closeTo(8 * 8, 1e-6));
      // a hole thinner than twice the offset closes up
      final tiny = _lawn()..holes = [_rect(10, 10, 11, 11)];
      expect((offsetEntity(tiny, -1, 'a4') as AreaEntity).holes, isEmpty);
    });
  });

  group('Subtract from area', () {
    test('a shape inside becomes an island, the outline as it was', () {
      final a = _lawn();
      final r = subtractFromArea(a, _rect(10, 10, 20, 20), () => 'n1')!;
      expect(r.single.id, 'a1');
      expect(r.single.points, a.points);
      expect(r.single.holes.single, _rect(10, 10, 20, 20));
      expect(r.single.area, closeTo(1100, 1e-9));
      expect(a.holes, isEmpty, reason: 'the area itself is not changed');
    });

    test('across the outline a notch, across the area two pieces, the whole area nothing', () {
      final notch = subtractFromArea(_lawn(), _rect(30, 10, 50, 20), () => 'n1')!;
      expect(notch.single.holes, isEmpty);
      expect(notch.single.area, closeTo(1100, 1e-6));
      expect(notch.single.points.length, 8);
      var k = 0;
      final split = subtractFromArea(_lawn(), _rect(18, -5, 22, 35), () => 'n${++k}')!;
      expect(split.length, 2);
      expect(split.first.id, 'a1');
      expect(split.last.id, 'n1');
      expect(split.last.name, 'Lawn (2)');
      for (final piece in split) {
        expect(piece.area, closeTo(540, 1e-6));
      }
      expect(subtractFromArea(_lawn(), _rect(-5, -5, 45, 35), () => 'n1'), isEmpty);
    });

    test('islands that overlap merge; a cut inside an island or outside the area changes nothing', () {
      final a = _lawn()..holes = [_rect(10, 10, 20, 20)];
      final merged = subtractFromArea(a, _rect(15, 15, 25, 25), () => 'n1')!.single;
      expect(merged.holes.length, 1);
      expect(merged.area, closeTo(1200 - 175, 1e-6));
      expect(subtractFromArea(a, _rect(12, 12, 18, 18), () => 'n1'), isNull);
      expect(subtractFromArea(a, _rect(50, 50, 60, 60), () => 'n1'), isNull);
    });

    test('in a project: the pieces take the place of the area', () {
      final p = Project();
      final a = AreaEntity(id: p.newId(), name: 'Lawn', points: _rect(0, 0, 40, 30));
      final line = LineEntity(id: p.newId(), a: const Pt(-10, -10), b: const Pt(-5, -5));
      p.entities
        ..add(a)
        ..add(line);
      final r = subtractFromAreas(p, [a], [_rect(18, -5, 22, 35)]);
      expect(r.changed.length, 2);
      expect(r.changed.first, a.id);
      expect(r.removed, isEmpty);
      expect(p.entities.whereType<AreaEntity>().length, 2);
      expect(p.entities.last.id, line.id);
      // the outline of a closed polyline, a circle or another area cuts
      expect(cutOutlineOf(PolylineEntity(id: 'x', points: _rect(0, 0, 1, 1), closed: true)), isNotNull);
      expect(cutOutlineOf(CircleEntity(id: 'c', center: Pt.zero, radius: 2))!.length, greaterThan(16));
      expect(cutOutlineOf(LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 0))), isNull);
      expect(holesOf(a), isEmpty);
      expect(holesOf(line), isEmpty);
    });
  });

  group('the islands everywhere', () {
    test('the water an area needs follows its irrigated surface', () {
      final p = Project()..entities.add(_lawn());
      final full = cropWaterRequirements(p, null).single.volumePerEventM3;
      (p.entities.single as AreaEntity).holes = [_rect(10, 10, 20, 20)];
      final net = cropWaterRequirements(p, null).single.volumePerEventM3;
      expect(full, greaterThan(0));
      expect(net / full, closeTo(1100 / 1200, 1e-9));
    });

    test('the automatic layout keeps the heads out of the pond', () {
      final cat = Catalog.defaultCatalog();
      final a = _lawn()..holes = [_rect(12, 8, 28, 22)];
      final wet = layoutLandscape(outline: a.points, exclusions: holesOf(a), family: cat.outlet('rotor')!);
      expect(wet.heads, isNotEmpty);
      expect(wet.heads.where((h) => a.inHole(h.position)), isEmpty);
      expect(wet.region.area, closeTo(1200 - 16 * 14, 1e-6));
      final dry = layoutLandscape(outline: a.points, family: cat.outlet('rotor')!);
      expect(dry.heads.where((h) => a.inHole(h.position)), isNotEmpty, reason: 'without the island a head stands in the pond');
    });

    test('DXF/DWG: a hatch with the island under everything, and the outlines', () {
      final p = Project()..entities.add(_lawn()..holes = [_rect(10, 10, 20, 20)]);
      final d = CadExport(p).build();
      final hatch = d.entities.first as CadHatch;
      expect(hatch.solid, isTrue);
      expect(hatch.loops.length, 2);
      expect(d.entities.whereType<CadPolyline>().length, 2);
      final dxf = DxfR2000Writer.write(d);
      expect(dxf, contains('HATCH'));
      // an area without islands is written as before: its outline only
      expect(CadExport(Project()..entities.add(_lawn())).build().entities.whereType<CadHatch>(), isEmpty);
    });

    test('GeoJSON and KML: the island is an inner ring', () {
      final p = Project()..entities.add(_lawn()..holes = [_rect(10, 10, 20, 20)]);
      p.meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
      final ex = _exporter(p);
      final j = jsonDecode(ex.geoJson()) as Map<String, dynamic>;
      final f = (j['features'] as List).cast<Map<String, dynamic>>().single;
      final rings = [
        for (final r in f['geometry']['coordinates'] as List) [for (final c in r as List) (c as List).cast<num>().map((x) => x.toDouble()).toList()],
      ];
      expect(rings.length, 2);
      // RFC 7946: the outline counter-clockwise, the hole clockwise
      expect(_ring(rings[0]), greaterThan(0));
      expect(_ring(rings[1]), lessThan(0));
      expect(ex.kml(), contains('<innerBoundaryIs>'));
    });

    test('SHP: the outline clockwise, the island counter-clockwise, one record', () {
      final outer = [for (final q in _rect(0, 0, 40, 30)) ((q.x, q.y), 0.0)];
      final inner = [for (final q in _rect(10, 10, 20, 20).reversed) ((q.x, q.y), 0.0)];
      final (shp, _) = ShapefileWriter.writeShapes(ShpShapeType.polygon, [
        [outer, inner],
      ]);
      final b = ByteData.sublistView(shp);
      // main header 100 bytes, record header 8, shape type 4, box 32
      expect(b.getInt32(108, Endian.little), 5);
      final parts = b.getInt32(144, Endian.little), count = b.getInt32(148, Endian.little);
      expect(parts, 2);
      expect(count, 10);
      final start = [b.getInt32(152, Endian.little), b.getInt32(156, Endian.little)];
      final pts = [
        for (var i = 0; i < count; i++) [b.getFloat64(160 + 16 * i, Endian.little), b.getFloat64(168 + 16 * i, Endian.little)],
      ];
      expect(_ring(pts.sublist(start[0], start[1])), lessThan(0));
      expect(_ring(pts.sublist(start[1])), greaterThan(0));
    });

    test('the sheet: one path filled by the even-odd rule (SVG, PDF and picture)', () {
      final p = Project()..entities.add(_lawn()..holes = [_rect(10, 10, 20, 20)]);
      final ex = _exporter(p);
      final scene = ex.scene(const SheetOptions());
      expect(scene.items.whereType<PlotPath>().where((x) => x.holes.isNotEmpty).length, 1);
      expect(ex.svg(), contains('fill-rule="evenodd"'));
      final rec = SheetRecorder(1190, 842);
      ex.sheetBuilder().drawScene(rec, scene, (q) => (q.x, q.y), 1);
      final op = rec.sheet.ops.whereType<SheetRingsOp>().first;
      expect(op.rings.length, 2);
    });
  });
}
