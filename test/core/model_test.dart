import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/terrain.dart';

void main() {
  group('geometry', () {
    test('polyline helpers', () {
      final pts = [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10)];
      expect(polylineLength(pts), 20);
      expect(pointAlongPolyline(pts, 15), const Pt(10, 5));
      final pieces = splitPolylineAt(pts, [5, 15]);
      expect(pieces.length, 3);
      expect(polylineLength(pieces[1]), 10);
      expect(polygonArea([const Pt(0, 0), const Pt(4, 0), const Pt(4, 3), const Pt(0, 3)]), 12);
      expect(pointInPolygon(const Pt(1, 1), [const Pt(0, 0), const Pt(4, 0), const Pt(4, 3), const Pt(0, 3)]), isTrue);
      expect(segmentIntersection(const Pt(0, 0), const Pt(2, 2), const Pt(0, 2), const Pt(2, 0)), const Pt(1, 1));
    });
  });

  group('terrain', () {
    test('interpolates between contours', () {
      final t = Terrain(densify: 1);
      t.addContour([const Pt(0, 0), const Pt(100, 0)], 100);
      t.addContour([const Pt(0, 10), const Pt(100, 10)], 110);
      expect(t.elevationAt(const Pt(50, 0)), closeTo(100, 1e-6));
      final mid = t.elevationAt(const Pt(50, 5));
      expect(mid, closeTo(105, 1.0));
      expect(t.elevationAt(const Pt(50, 2)), lessThan(mid));
    });
  });

  group('project', () {
    test('json round trip keeps entities', () {
      final p = Project();
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(50, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc75'));
      p.entities.add(OutletEntity(id: p.newId(), position: const Pt(10, 5), outletSpecId: 'micro', nozzleId: 'm50', headM: 15));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(50, 0), valveSpecId: 'ev50', zoneName: 'Zona 1'));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(0, 0), name: 'Poço'));
      p.entities.add(SpraylineEntity(id: p.newId(), points: [const Pt(0, 10), const Pt(100, 10)], outletSpecId: 'micro', nozzleId: 'm50', spacing: 4, headM: 15));
      p.entities.add(TapeEntity(id: p.newId(), points: [const Pt(0, 20), const Pt(100, 20)], tapeSpecId: 'tape16_10_30'));
      p.entities.add(ContourEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(100, 0)], elevation: 500));
      p.entities.add(TextEntity(id: p.newId(), position: const Pt(1, 1), text: 'Olá'));
      p.entities.add(AreaEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(100, 0), const Pt(100, 50)]));
      p.systemFlows.add(SystemFlow(id: 'sf1', name: 'Turno 1', valveIds: {'e3'}));
      final s = p.toJsonString();
      final q = Project.fromJsonString(s);
      expect(q.entities.length, p.entities.length);
      expect(q.entities.map((e) => e.type).toList(), p.entities.map((e) => e.type).toList());
      expect((q.byId('e5') as SpraylineEntity).outletCount, 25);
      expect(q.systemFlows.single.valveIds, {'e3'});
      expect(q.catalog.pipes.length, p.catalog.pipes.length);
      expect(q.toJsonString(), s);
    });
    test('default catalog is consistent', () {
      final c = Catalog.defaultCatalog();
      expect(c.pipesFor(PipeUsage.lateral).first.innerDiameterMm, 13.6);
      for (final o in c.outlets) {
        expect(o.nozzles, isNotEmpty);
        for (final n in o.nozzles) {
          expect(n.curve.flow(n.defaultHeadM), greaterThan(0));
        }
      }
      for (final p in c.pumps) {
        expect(p.curve.shutoffHead, greaterThan(0));
      }
    });
  });

  group('dxf', () {
    test('round trip', () {
      final doc = DxfDocument(layers: [DxfLayer('A', color: 1)], entities: [
        DxfEntity(type: 'LINE', layer: 'A', points: [const Pt(0, 0), const Pt(10, 5)]),
        DxfEntity(type: 'POLYLINE', layer: 'A', points: [const Pt(0, 0), const Pt(1, 1), const Pt(2, 0)], closed: true),
        DxfEntity(type: 'CIRCLE', layer: 'A', center: const Pt(3, 3), radius: 2),
        DxfEntity(type: 'ARC', layer: 'A', center: const Pt(3, 3), radius: 2, startAngle: 0, endAngle: 90),
        DxfEntity(type: 'TEXT', layer: 'A', points: [const Pt(1, 2)], text: 'Hello', height: 2.5),
        DxfEntity(type: 'POINT', layer: 'A', points: [const Pt(7, 7)]),
      ]);
      final s = DxfWriter.write(doc);
      final r = DxfReader.parse(s);
      expect(r.layers.single.name, 'A');
      expect(r.entities.length, 6);
      expect(r.entities[1].points.length, 3);
      expect(r.entities[1].closed, isTrue);
      expect(r.entities[2].radius, 2);
      expect(r.entities[4].text, 'Hello');
      expect(r.unitScale, 1);
    });
    test('parses LWPOLYLINE and mm units', () {
      const dxf = '0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n4\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nLWPOLYLINE\n8\nL1\n90\n2\n70\n0\n10\n0\n20\n0\n10\n1000\n20\n0\n0\nENDSEC\n0\nEOF\n';
      final r = DxfReader.parse(dxf);
      expect(r.entities.single.points.length, 2);
      expect(r.unitScale, 0.001);
    });
  });
}
