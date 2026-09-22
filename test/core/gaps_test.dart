import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/pivot.dart';
import 'package:opencadirrigation/core/design/pump_selection.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/io/dem_tiff.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/core/units.dart';

/// Minimal little-endian GeoTIFF: one strip of float32 heights with
/// ModelPixelScale / ModelTiepoint and a UTM 23S GeoKey directory.
Uint8List buildDemTiff(int w, int h, double Function(int col, int row) z, {double pixel = 10, double x0 = 500000, double y0 = 7000000, String? nodata}) {
  final pixels = ByteData(w * h * 4);
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      pixels.setFloat32((r * w + c) * 4, z(c, r), Endian.little);
    }
  }
  final scale = ByteData(24)
    ..setFloat64(0, pixel, Endian.little)
    ..setFloat64(8, pixel, Endian.little)
    ..setFloat64(16, 0, Endian.little);
  final tie = ByteData(48);
  for (var i = 0; i < 6; i++) {
    tie.setFloat64(i * 8, [0.0, 0.0, 0.0, x0, y0, 0.0][i], Endian.little);
  }
  final keys = <int>[1, 1, 0, 2, 1024, 0, 1, 1, 3072, 0, 1, 32723];
  final keyBytes = ByteData(keys.length * 2);
  for (var i = 0; i < keys.length; i++) {
    keyBytes.setUint16(i * 2, keys[i], Endian.little);
  }
  final ndBytes = nodata == null ? null : Uint8List.fromList([...ascii.encode(nodata), 0]);
  // layout: header(8) + IFD + values + pixels
  final entries = <(int, int, int, Object)>[
    (256, 4, 1, w),
    (257, 4, 1, h),
    (258, 3, 1, 32),
    (259, 3, 1, 1),
    (262, 3, 1, 1),
    (273, 4, 1, 'pixels'),
    (277, 3, 1, 1),
    (278, 4, 1, h),
    (279, 4, 1, w * h * 4),
    (284, 3, 1, 1),
    (339, 3, 1, 3),
    (33550, 12, 3, scale.buffer.asUint8List()),
    (33922, 12, 6, tie.buffer.asUint8List()),
    (34735, 3, keys.length, keyBytes.buffer.asUint8List()),
    if (ndBytes != null) (42113, 2, ndBytes.length, ndBytes),
  ];
  final ifdSize = 2 + entries.length * 12 + 4;
  var valueOffset = 8 + ifdSize;
  final values = <Uint8List>[];
  final offsets = <int>[];
  for (final e in entries) {
    final v = e.$4;
    if (v is Uint8List) {
      offsets.add(valueOffset);
      values.add(v);
      valueOffset += v.length + (v.length.isOdd ? 1 : 0);
    } else {
      offsets.add(-1);
    }
  }
  final pixelsOffset = valueOffset;
  final total = pixelsOffset + w * h * 4;
  final out = ByteData(total);
  out.setUint8(0, 0x49);
  out.setUint8(1, 0x49);
  out.setUint16(2, 42, Endian.little);
  out.setUint32(4, 8, Endian.little);
  out.setUint16(8, entries.length, Endian.little);
  for (var i = 0; i < entries.length; i++) {
    final (tag, type, count, v) = entries[i];
    final e = 10 + i * 12;
    out.setUint16(e, tag, Endian.little);
    out.setUint16(e + 2, type, Endian.little);
    out.setUint32(e + 4, count, Endian.little);
    if (v is Uint8List) {
      out.setUint32(e + 8, offsets[i], Endian.little);
    } else if (v == 'pixels') {
      out.setUint32(e + 8, pixelsOffset, Endian.little);
    } else if (type == 3) {
      out.setUint16(e + 8, v as int, Endian.little);
    } else {
      out.setUint32(e + 8, v as int, Endian.little);
    }
  }
  out.setUint32(10 + entries.length * 12, 0, Endian.little);
  final bytes = out.buffer.asUint8List();
  var vi = 0;
  for (var i = 0; i < entries.length; i++) {
    if (offsets[i] >= 0) {
      bytes.setRange(offsets[i], offsets[i] + values[vi].length, values[vi]);
      vi++;
    }
  }
  bytes.setRange(pixelsOffset, pixelsOffset + w * h * 4, pixels.buffer.asUint8List());
  return bytes;
}

void main() {
  group('GeoTIFF elevation raster', () {
    test('float32 DEM becomes georeferenced spot heights, nodata skipped', () {
      final tiff = buildDemTiff(6, 4, (c, r) => c == 0 && r == 0 ? -9999 : 600 + c * 1.0 + r * 2.0, nodata: '-9999');
      expect(GeoTiffDemReader.looksLikeDem(tiff), isTrue);
      final dem = GeoTiffDemReader.read(tiff)!;
      expect(dem.widthPx, 6);
      expect(dem.heightPx, 4);
      expect(dem.step, 1);
      expect(dem.samples.length, 6 * 4 - 1, reason: 'the nodata pixel is dropped');
      expect(dem.georef, isNotNull);
      expect(dem.georef!.zone, 23);
      expect(dem.georef!.north, isFalse);
      // pixel (5, 3) = bottom-right: highest elevation, near the raster's bottom-right corner
      final z = dem.range;
      expect(z.$1, closeTo(600 + 1, 1e-6));
      expect(z.$2, closeTo(600 + 5 + 6, 1e-6));
      final br = dem.samples.reduce((a, b) => a.z >= b.z ? a : b);
      // local coordinates: origin rounded to 100 m from the raster's bottom-left
      final expectedX = 500000 + 5.5 * 10 - dem.georef!.originEasting;
      final expectedY = 7000000 - 3.5 * 10 - dem.georef!.originNorthing;
      expect(br.p.x, closeTo(expectedX, 1e-6));
      expect(br.p.y, closeTo(expectedY, 1e-6));
      // an 8-bit picture is not a DEM
      expect(GeoTiffDemReader.looksLikeDem(Uint8List.fromList([0x49, 0x49, 42, 0, 8, 0, 0, 0, 0, 0])), isFalse);
      // large rasters are sampled down
      final big = buildDemTiff(120, 100, (c, r) => 100 + c * 0.1);
      final sampled = GeoTiffDemReader.read(big, maxPoints: 500)!;
      expect(sampled.samples.length, lessThanOrEqualTo(600));
      expect(sampled.step, greaterThan(1));
    });

    test('the terrain built from the DEM samples interpolates the plane', () {
      final tiff = buildDemTiff(10, 10, (c, r) => 500 + c * 1.0 - r * 0.5);
      final dem = GeoTiffDemReader.read(tiff)!;
      final p = Project();
      p.meta.georef = dem.georef;
      p.entities.addAll([for (final s in dem.samples) SpotHeightEntity(id: p.newId(), position: s.p, elevation: s.z)]);
      final terrain = p.buildTerrain();
      final a = dem.samples[11], b = dem.samples[55];
      final mid = Pt.lerp(a.p, b.p, 0.5);
      expect(terrain.elevationAt(mid), closeTo((a.z + b.z) / 2, 1e-6));
    });
  });

  group('pivot sprinkler chart and BOM', () {
    test('spans list sprinklers, flow each, pressure and the closest nozzle', () {
      const s = PivotSpec(kind: PivotKind.pivot, lengthM: 300, endThrowM: 0, spanLengthM: 50, sprinklerSpacingM: 2.5, grossDepthMm: 8, hoursPerCycle: 24, endPressureM: 14);
      final nozzles = [for (final (n, q) in [('#20', 500.0), ('#28', 1000.0), ('#36', 1700.0), ('#44', 2500.0)]) (n, EmitterCurve.fromNominal(flow: q * m3sPerLph, head: 14, x: 0.5))];
      final r = analyzePivot(s, id: 'p', name: 'P', nozzles: nozzles);
      expect(r.spans.length, 6);
      expect(r.sprinklerCount, 6 * 20);
      // flow grows with the radius: last span carries the most water per sprinkler
      expect(r.spans.last.flowPerSprinkler, greaterThan(r.spans.first.flowPerSprinkler * 5));
      final total = r.spans.fold<double>(0, (a, sp) => a + sp.flowPerSprinkler * sp.sprinklers);
      expect(total, closeTo(s.sprinklerFlow, 1e-9));
      // mid-span pressures: the last span sits just above the end pressure
      expect(r.spans.last.pressure, closeTo(14, 0.05));
      expect(r.spans.last.pressure, greaterThanOrEqualTo(14));
      expect(r.spans.first.pressure, greaterThan(14));
      expect(r.spans.map((sp) => sp.nozzle).toSet().length, greaterThan(1), reason: 'different nozzles along the machine');
      expect(r.spans.last.nozzle, isNotEmpty);
      final back = PivotResult.fromJson(r.toJson());
      expect(back.spans.length, 6);
      expect(back.spans[2].nozzle, r.spans[2].nozzle);
    });

    test('designer costs towers, sprinklers and regulators and reports the spans', () {
      final p = Project();
      final pivot = PivotEntity(id: p.newId(), center: const Pt(0, 0), radiusM: 200, endThrowM: 0, name: 'PV', machineCost: 100000, towerCost: 15000, sprinklerSpacingM: 2.5, sprinklerSpecId: 'impact34', regulatorSpecId: 'prv50');
      p.entities.add(pivot);
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-300, 0), const Pt(0, 0)], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-300, 0), calculatePressure: true));
      final r = Designer(p).designAll();
      final pr = r.pivots[pivot.id]!;
      expect(pr.spans.length, 4);
      expect(pr.sprinklerCount, 80);
      final towers = r.bom.firstWhere((b) => b.category == 'bom.pivots' && b.description.contains('pivot.towersItem'));
      expect(towers.quantity, 4);
      expect(towers.unitCost, 15000);
      final spr = r.bom.firstWhere((b) => b.category == 'bom.pivots' && b.specId == 'impact34');
      expect(spr.quantity, 80);
      final reg = r.bom.firstWhere((b) => b.category == 'bom.pivots' && b.specId == 'prv50');
      expect(reg.quantity, 80);
      final tables = buildReportTables(project: p, results: r, labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w));
      final spans = tables.firstWhere((tb) => tb.key == 'pivotSpans');
      expect(spans.rows.length, 4);
      expect(spans.rows.first[4], 20);
      final again = Project.fromJson(p.toJson()).entities.whereType<PivotEntity>().single;
      expect(again.sprinklerSpecId, 'impact34');
      expect(again.towerCost, 15000);
    });
  });

  group('sheet bill of materials', () {
    test('the sheet carries a materials table when there are results', () {
      final p = Project();
      final exporter = ProjectExporter(project: p, results: null, labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w));
      expect(exporter.sheetBuilder().sheetScale(const SheetOptions()), 1000, reason: 'empty project keeps the default');
      // a designed block
      final block = ControlValveEntity(id: p.newId(), position: const Pt(-2, 15), zoneName: 'Z');
      p.entities.add(block);
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-2, 15), const Pt(0, 15)], scope: HydraulicScope.zone));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(0, 30)], scope: HydraulicScope.zone));
      for (var y = 2.0; y < 30; y += 4) {
        p.entities.add(SpraylineEntity(id: p.newId(), points: [Pt(0, y), Pt(60, y)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2));
      }
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-30, 15), const Pt(-2, 15)], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-30, 15), calculatePressure: true));
      final r = Designer(p).designAll();
      expect(r.bom, isNotEmpty);
      final ex = ProjectExporter(project: p, results: r, labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w));
      final b = ex.sheetBuilder();
      final withBom = b.buildSheet(const SheetOptions(page: PageSize.a3));
      final without = b.buildSheet(const SheetOptions(page: PageSize.a3, bomOnSheet: false));
      expect(withBom.length, greaterThan(without.length + 200), reason: 'the table adds content to the page');
      // the side column widens for the table, so the drawing area shrinks
      final layWith = SheetLayout(const SheetOptions(), hasLegend: true, legendWidthMm: SheetLayout.legendWithBomMm);
      final layWithout = SheetLayout(const SheetOptions(), hasLegend: true);
      expect(layWith.areaW, lessThan(layWithout.areaW));
    });
  });

  group('misc gaps', () {
    test('standard motor covers the shaft power with the service factor', () {
      expect(standardMotor(0), isNull);
      expect(standardMotor(5.0), (7.5, 10));
      expect(standardMotor(6.4), (7.5, 10), reason: '6.4 × 1.15 = 7.36 ≤ 7.5');
      expect(standardMotor(6.6), (9.2, 12.5));
      expect(standardMotor(1000), standardMotorsKw.last);
    });

    test('very large surveys are decimated for the TIN but kept for IDW', () {
      final old = Terrain.maxTinPoints;
      Terrain.maxTinPoints = 500;
      try {
        final t = Terrain(densify: 1);
        for (var i = 0; i < 40; i++) {
          for (var j = 0; j < 40; j++) {
            t.addSpot(Pt(i * 5.0, j * 5.0), 100 + i * 0.1 + j * 0.2);
          }
        }
        expect(t.sampleCount, 1600);
        expect(t.tin.pointCount, lessThanOrEqualTo(534));
        expect(t.tin.pointCount, greaterThanOrEqualTo(400));
        expect(t.elevationAt(const Pt(100, 100)), closeTo(100 + 20 * 0.1 + 20 * 0.2, 0.05));
      } finally {
        Terrain.maxTinPoints = old;
      }
    });

    test('looped mainline sizing with LP adds the approximation note and still converges', () {
      final p = Project();
      // ring main with two valves and a supply
      final a = const Pt(0, 0), b = const Pt(100, 0), c = const Pt(100, 60), d = const Pt(0, 60);
      p.entities.add(PipeEntity(id: p.newId(), points: [a, b], scope: HydraulicScope.mainline));
      p.entities.add(PipeEntity(id: p.newId(), points: [b, c], scope: HydraulicScope.mainline));
      p.entities.add(PipeEntity(id: p.newId(), points: [c, d], scope: HydraulicScope.mainline));
      p.entities.add(PipeEntity(id: p.newId(), points: [d, a], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: a, calculatePressure: true));
      for (final (pos, name) in [(b, 'Z1'), (c, 'Z2')]) {
        final v = ControlValveEntity(id: p.newId(), position: pos, zoneName: name);
        p.entities.add(v);
        p.entities.add(PipeEntity(id: p.newId(), points: [pos, pos + const Pt(0, -5)], scope: HydraulicScope.zone));
        p.entities.add(SpraylineEntity(id: p.newId(), points: [pos + const Pt(0, -5), pos + const Pt(40, -5)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2));
      }
      final check = runDesignCheck(p);
      expect(check.issues.any((i) => i.code == 'looped_mainline'), isTrue);
      final r = Designer(p).designAll();
      expect(r.messages, contains('lp_loops_approx'));
      expect(r.systemFlows.single.converged, isTrue);
      expect(r.systemFlows.single.valves.every((v) => v.deficit < 0.05), isTrue);
    });
  });
}
