import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/pivot.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/io/dem_online.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_packs.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/core/model/tin.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  group('TIN terrain', () {
    test('Delaunay of a plane reproduces the plane exactly', () {
      final pts = <(double, double, double)>[];
      for (var i = 0; i <= 10; i++) {
        for (var j = 0; j <= 10; j++) {
          final x = i * 10.0 + (j.isOdd ? 3.0 : 0.0), y = j * 10.0;
          pts.add((x, y, 100 + 0.02 * x + 0.05 * y));
        }
      }
      final tin = Tin.build(pts);
      expect(tin.triangles.length, greaterThan(150));
      for (final (x, y) in [(15.5, 22.0), (60.0, 60.0), (91.0, 5.0)]) {
        expect(tin.elevationAt(Pt(x, y)), closeTo(100 + 0.02 * x + 0.05 * y, 1e-6));
      }
      expect(tin.elevationAt(const Pt(-50, -50)), isNull, reason: 'outside the hull');
      final slope = tin.slopeAt(const Pt(50, 50))!;
      expect(slope.$1, closeTo(0.0539, 1e-3));
    });

    test('terrain with TIN method interpolates linearly between contours and falls back outside', () {
      final t = Terrain(densify: 5, method: TerrainMethod.tin);
      t.addContour([const Pt(0, 0), const Pt(100, 0)], 100);
      t.addContour([const Pt(0, 40), const Pt(100, 40)], 104);
      expect(t.elevationAt(const Pt(50, 10)), closeTo(101, 1e-6));
      expect(t.elevationAt(const Pt(50, 30)), closeTo(103, 1e-6));
      // outside the hull: IDW fallback stays within the data range
      final z = t.elevationAt(const Pt(50, 80));
      expect(z, inInclusiveRange(100, 104));
      expect(t.slopeAt(const Pt(50, 20)), closeTo(0.1, 1e-6));
      // IDW method still works
      final idw = Terrain(densify: 5, method: TerrainMethod.idw)
        ..addContour([const Pt(0, 0), const Pt(100, 0)], 100)
        ..addContour([const Pt(0, 40), const Pt(100, 40)], 104);
      expect(idw.elevationAt(const Pt(50, 20)), closeTo(102, 0.5));
    });

    test('contour generation from a sloping plane gives straight level lines', () {
      final t = Terrain(densify: 5);
      for (var i = 0; i <= 4; i++) {
        t.addContour([Pt(0, i * 25.0), Pt(100, i * 25.0)], 100 + i * 2.5);
      }
      final lines = t.generateContours(1);
      expect(lines, isNotEmpty);
      final levels = lines.map((l) => l.$1).toSet();
      expect(levels, containsAll([101.0, 105.0, 109.0]));
      for (final (z, pts) in lines) {
        // every vertex sits at y = (z - 100) / 0.1
        for (final p in pts) {
          expect(p.y, closeTo((z - 100) * 10, 1e-6));
        }
      }
      // project-level: contours become entities via the project's terrain
      final p = Project();
      p.entities.addAll([for (var i = 0; i <= 4; i++) ContourEntity(id: p.newId(), points: [Pt(0, i * 25.0), Pt(100, i * 25.0)], elevation: 100 + i * 2.5)]);
      expect(p.params.terrainMethod, TerrainMethod.tin);
      expect(p.buildTerrain().generateContours(5).map((l) => l.$1).toSet(), containsAll([105.0]));
    });

    test('chainSegments joins unordered segments into polylines', () {
      final lines = chainSegments([(const Pt(0, 0), const Pt(1, 0)), (const Pt(2, 0), const Pt(3, 0)), (const Pt(1, 0), const Pt(2, 0)), (const Pt(10, 0), const Pt(10, 1))]);
      expect(lines.length, 2);
      expect(lines.firstWhere((l) => l.length == 4).map((p) => p.x).toList(), [0, 1, 2, 3]);
    });
  });

  group('geometry helpers', () {
    test('similarity from two point pairs maps both points and scales uniformly', () {
      final t = similarityFromPairs(const Pt(0, 0), const Pt(10, 0), const Pt(100, 100), const Pt(100, 120))!;
      expect(t.apply(const Pt(0, 0)).distanceTo(const Pt(100, 100)), lessThan(1e-9));
      expect(t.apply(const Pt(10, 0)).distanceTo(const Pt(100, 120)), lessThan(1e-9));
      expect(t.scale, closeTo(2, 1e-9));
      expect(t.apply(const Pt(0, 10)).distanceTo(const Pt(80, 100)), lessThan(1e-9), reason: 'rotated 90° CCW');
      final k = similarityFromPairs(const Pt(0, 0), const Pt(10, 0), const Pt(0, 0), const Pt(20, 0), keepScale: true)!;
      expect(k.scale, closeTo(1, 1e-9));
      expect(similarityFromPairs(const Pt(0, 0), const Pt(0, 0), const Pt(1, 1), const Pt(2, 2)), isNull);
    });

    test('clipPolylineToPolygon keeps the inside pieces', () {
      final poly = [const Pt(0, 0), const Pt(100, 0), const Pt(100, 50), const Pt(0, 50)];
      final pieces = clipPolylineToPolygon([const Pt(-10, 25), const Pt(110, 25)], poly);
      expect(pieces.length, 1);
      expect(pieces.first.first.x, closeTo(0, 1e-9));
      expect(pieces.first.last.x, closeTo(100, 1e-9));
      // a line leaving and re-entering an L-shaped polygon gives two pieces
      final l = [const Pt(0, 0), const Pt(100, 0), const Pt(100, 100), const Pt(60, 100), const Pt(60, 40), const Pt(40, 40), const Pt(40, 100), const Pt(0, 100)];
      final two = clipPolylineToPolygon([const Pt(-5, 70), const Pt(105, 70)], l);
      expect(two.length, 2);
      expect(clipPolylineToPolygon([const Pt(-5, 200), const Pt(105, 200)], poly), isEmpty);
    });

    test('guided block generator produces curved laterals clipped to the polygon', () {
      final p = Project();
      final poly = [const Pt(0, 0), const Pt(100, 0), const Pt(100, 60), const Pt(0, 60)];
      final r = generateBlock(p, BlockOptions(polygon: poly, direction: const Pt(1, 0), lateralSpacing: 10, outletSpecId: 'micro', nozzleId: 'm50', outletSpacing: 4, guide: [const Pt(-10, 5), const Pt(50, 15), const Pt(110, 5)], valveSpecId: 'ev50', zoneName: 'Curva'));
      expect(r.laterals.length, greaterThanOrEqualTo(4));
      for (final l in r.laterals) {
        final pts = (l as SpraylineEntity).points;
        expect(pts.length, greaterThanOrEqualTo(2));
        for (final pt in pts) {
          expect(pt.x, inInclusiveRange(-1e-6, 100 + 1e-6));
          expect(pt.y, inInclusiveRange(-1e-6, 60 + 1e-6));
        }
      }
      expect(r.submain, isNotNull);
      expect(r.valve, isNotNull);
      expect(r.submain!.points.length, r.laterals.length);
    });
  });

  group('pivot hydraulics', () {
    test('flow, friction and inlet pressure of a 400 m pivot', () {
      const s = PivotSpec(kind: PivotKind.pivot, lengthM: 400, endThrowM: 0, pipeInnerMm: 162, hazenC: 130, grossDepthMm: 8, hoursPerCycle: 24, endPressureM: 14, pipeHeightM: 3.5, machineLossM: 2);
      // Q = π·400²·0.008 / 24 h = 167.6 m³/h
      expect(s.sprinklerFlow / m3sPerM3h, closeTo(167.55, 0.1));
      expect(s.towerCount, 8);
      final r = analyzePivot(s, id: 'pv', name: 'P1');
      expect(r.flow / m3sPerM3h, closeTo(167.55, 0.1));
      // pivot factor ≈ 0.543 of the full-flow friction (Chu & Moe)
      final hfFull = hazenWilliamsLoss(flow: r.flow, diameter: 0.162, length: 400, c: 130);
      expect(r.frictionLoss / hfFull, closeTo(0.543, 0.02));
      expect(r.inletHead, closeTo(14 + r.frictionLoss + 3.5 + 2, 1e-9));
      expect(r.towers.length, 9);
      expect(r.towers.last.pressure, closeTo(14, 1e-6));
      expect(r.towers.first.flowPast, closeTo(r.flow, 1e-12));
      expect(r.appRateEndPeak, greaterThan(r.appRateEndAvg));
      expect(r.warnings, isEmpty);
      final json = PivotResult.fromJson(r.toJson());
      expect(json.inletHead, closeTo(r.inletHead, 1e-9));
    });

    test('sector pivot: same cycle time gives a proportionally lower application rate', () {
      const full = PivotSpec(kind: PivotKind.pivot, lengthM: 400, endThrowM: 0, grossDepthMm: 8, hoursPerCycle: 24);
      const half = PivotSpec(kind: PivotKind.pivot, lengthM: 400, endThrowM: 0, grossDepthMm: 8, hoursPerCycle: 24, sectorDeg: 180);
      final rf = analyzePivot(full, id: 'f', name: 'f');
      final rh = analyzePivot(half, id: 'h', name: 'h');
      // half the area in the same time: half the flow, and the outer sprinklers
      // (flow per metre 2·Q/R) apply water at half the rate
      expect(rh.flow, closeTo(rf.flow / 2, 1e-12));
      expect(rh.appRateEndAvg, closeTo(rf.appRateEndAvg / 2, 1e-9));
      expect(rf.appRateEndAvg, closeTo(1000 * 2 * (rf.flow * 3600) / (400 * full.wettedWidthM), 1e-9));
      expect(rf.appRateEndPeak / rf.appRateEndAvg, closeTo(4 / 3.141592653589793, 1e-12));
    });

    test('ground rise raises the inlet pressure and a linear uses uniform flow', () {
      const s = PivotSpec(kind: PivotKind.pivot, lengthM: 300, endThrowM: 0);
      final r = analyzePivot(s, id: 'p', name: 'p', groundRiseAt: (d) => d / 100); // 1 % slope up
      expect(r.elevationRise, closeTo(3, 1e-9));
      expect(r.inletHead - analyzePivot(s, id: 'p', name: 'p').inletHead, closeTo(3, 1e-9));
      const lin = PivotSpec(kind: PivotKind.linear, lengthM: 300, travelM: 800, endThrowM: 0, grossDepthMm: 6, hoursPerCycle: 12);
      expect(lin.area, closeTo(300 * 800, 1e-6));
      expect(flowBeyond(lin, 150), closeTo(lin.sprinklerFlow / 2, 1e-12));
    });

    test('pivot entity is a mainline demand with results and BOM line', () {
      final p = Project();
      final pivot = PivotEntity(id: p.newId(), center: const Pt(0, 0), radiusM: 200, endThrowM: 0, name: 'Pivô 1', machineCost: 150000);
      p.entities.add(pivot);
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-300, 0), const Pt(0, 0)], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-300, 0), calculatePressure: true));
      final check = runDesignCheck(p);
      expect(check.issues.where((i) => i.code == 'pivot_unconnected'), isEmpty);
      final d = Designer(p);
      final r = d.designAll();
      expect(r.pivots.containsKey(pivot.id), isTrue);
      final pr = r.pivots[pivot.id]!;
      expect(pr.flow / m3sPerM3h, closeTo(3.14159 * 200 * 200 * 0.008 / 24, 0.05));
      expect(r.systemFlows.length, 1);
      expect(r.systemFlows.first.valves.single.zoneName, 'Pivô 1');
      expect(r.systemFlows.first.supplies.single.requiredHead, greaterThan(pr.inletHead));
      expect(pr.availableHead, isNotNull);
      expect(pr.deficit, lessThan(0.05));
      expect(r.bom.any((b) => b.category == 'bom.pivots' && b.unitCost == 150000), isTrue);
      // round trip
      final again = Project.fromJson(p.toJson());
      final e = again.entities.whereType<PivotEntity>().single;
      expect(e.radiusM, 200);
      expect(e.machineCost, 150000);
      expect(e.grips.length, 2);
      final moved = e.transformed(Affine.scaling(2));
      expect(moved.radiusM, closeTo(400, 1e-9));
    });
  });

  group('design check', () {
    test('finds crossing pipes, dead ends, missing supply and duplicates', () {
      final p = Project();
      // two mainline pipes crossing with no junction, one dead end, no supply
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(100, 0)], scope: HydraulicScope.mainline));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(50, -20), const Pt(50, 20)], scope: HydraulicScope.mainline));
      final v1 = ControlValveEntity(id: p.newId(), position: const Pt(100, 0), zoneName: 'Z');
      final v2 = ControlValveEntity(id: p.newId(), position: const Pt(100, 0), zoneName: 'Z');
      p.entities.addAll([v1, v2]);
      final rep = runDesignCheck(p);
      final codes = rep.issues.map((i) => i.code).toSet();
      expect(codes, contains('no_supply'));
      expect(codes, contains('pipes_cross'));
      expect(codes, contains('duplicate_item'));
      expect(codes, contains('duplicate_zone_name'));
      expect(codes, contains('no_terrain'));
      expect(rep.ok, isFalse);
      final cross = rep.issues.firstWhere((i) => i.code == 'pipes_cross');
      expect(cross.at!.distanceTo(const Pt(50, 0)), lessThan(1e-6));
    });

    test('a connected block passes without errors', () {
      final p = Project();
      final poly = [const Pt(0, 0), const Pt(60, 0), const Pt(60, 30), const Pt(0, 30)];
      final b = generateBlock(p, BlockOptions(polygon: poly, direction: const Pt(1, 0), lateralSpacing: 5, outletSpecId: 'micro', nozzleId: 'm50', outletSpacing: 3, valveSpecId: 'ev50', zoneName: 'A'));
      p.entities.addAll(b.all);
      final v = b.valve!.position;
      p.entities.add(PipeEntity(id: p.newId(), points: [v + const Pt(-30, 0), v], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: v + const Pt(-30, 0)));
      p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt.zero, elevation: 100));
      final rep = runDesignCheck(p);
      expect(rep.errors, 0, reason: rep.issues.map((i) => '${i.code} ${i.entityIds}').join(', '));
    });
  });

  group('catalog Excel and packs', () {
    test('XLSX round trip of the catalogue keeps items and prices', () {
      final c = Catalog.defaultCatalog(lang: 'pt');
      c.pipes.first.costPerM = 12.34;
      final bytes = CatalogIo.exportXlsx(c);
      final sheets = XlsxReader.read(Uint8List.fromList(bytes));
      expect(sheets.map((s) => s.name), containsAll(['pipes', 'outlets', 'tapes', 'valves', 'pumps', 'fittings']));
      final back = CatalogIo.parseXlsx(Uint8List.fromList(bytes));
      expect(back.catalog.pipes.length, c.pipes.length);
      expect(back.catalog.pipes.first.costPerM, closeTo(12.34, 1e-9));
      expect(back.catalog.outlets.length, c.outlets.length);
      expect(back.catalog.tapes.length, c.tapes.length);
      expect(back.catalog.valves.length, c.valves.length);
      expect(back.catalog.pumps.length, c.pumps.length);
      expect(back.catalog.fittings.length, c.fittings.length);
    });

    test('XLSX reader handles shared and inline strings written by the writer', () {
      final bytes = XlsxWriter.write([XlsxSheet(name: 'S', headers: ['a', 'b'], rows: [[1.5, 'x'], [2, 'y z']])]);
      final s = XlsxReader.read(Uint8List.fromList(bytes)).single;
      expect(s.headers, ['a', 'b']);
      expect(s.rows[0][0], 1.5);
      expect(s.rows[1][1], 'y z');
    });

    test('manufacturer packs are JSON files under catalogs/ (see catalog_packs_test.dart)', () {
      final f = File('catalogs/netafim.oci.cat');
      expect(f.existsSync(), isTrue);
      final pack = CatalogPack.parse(f.readAsStringSync(), origin: f.path);
      expect(pack.brand, 'Netafim');
      final c = Catalog.defaultCatalog();
      expect(mergeCatalogPack(c, pack.catalog), pack.itemCount);
      expect(mergeCatalogPack(c, pack.catalog), 0, reason: 'already merged');
    });
  });

  group('online DEM', () {
    test('grid, URLs and response parsing', () {
      final geo = GeoReference.fromLatLonOrigin(-22.9, -47.1);
      final pts = demGrid(const Bounds(0, 0, 100, 50), 25, geo);
      expect(pts.length, 5 * 3);
      expect(pts.first.lat, closeTo(-22.9, 1e-3));
      final urls = demRequestUrls(DemSource.openMeteo, pts);
      expect(urls.length, 1);
      expect(urls.first, contains('api.open-meteo.com/v1/elevation?latitude='));
      final ot = demRequestUrls(DemSource.openTopoSrtm, pts);
      expect(ot.first, contains('opentopodata.org/v1/srtm30m?locations='));
      expect(demParseResponse(DemSource.openMeteo, '{"elevation":[600.5,null,610]}'), [600.5, null, 610]);
      expect(demParseResponse(DemSource.openTopoSrtm, '{"status":"OK","results":[{"elevation":601.2},{"elevation":null}]}'), [601.2, null]);
      expect(() => demParseResponse(DemSource.openMeteo, '{"error":true,"reason":"bad"}'), throwsFormatException);
      // capped grid
      expect(demGrid(const Bounds(0, 0, 10000, 10000), 10, geo, maxPoints: 500).length, lessThanOrEqualTo(600));
    });
  });
}
