import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/fittings.dart';
import 'package:opencadirrigation/core/design/pump_selection.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/io/geoimage.dart';
import 'package:opencadirrigation/core/io/points_csv.dart';
import 'package:opencadirrigation/core/io/shp.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  final t = I18n('pt');

  group('LP sizing', () {
    test('LP design meets the pressure window and costs no more than greedy', () {
      double capital(SizingMethod m) {
        final p = buildExampleProject(t.call, lang: 'pt');
        p.params.sizingMethod = m;
        final r = Designer(p, label: (k) => t(k)).designAll();
        expect(r.method, m.name);
        for (final z in r.zones.values) {
          expect(z.converged, isTrue);
          expect(z.withinWindow, isTrue, reason: '${z.zoneName} ${z.warnings}');
        }
        for (final f in r.systemFlows) {
          expect(f.maxDeficit, lessThan(0.05));
        }
        return r.capitalCost;
      }

      final lp = capital(SizingMethod.lp);
      final greedy = capital(SizingMethod.greedy);
      expect(lp, lessThanOrEqualTo(greedy + 1e-6));
    });

    test('telescoped mainline is split into pieces with descending diameters', () {
      final p = Project();
      // long mainline with a single valve far away: LP has an incentive to telescope
      final valvePos = const Pt(400, 0);
      p.entities.add(PipeEntity(id: 'main', points: [Pt.zero, const Pt(200, 0), valvePos], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: 'w', position: Pt.zero, calculatePressure: false, designHeadM: 45));
      p.entities.add(ControlValveEntity(id: 'v', position: valvePos, zoneName: 'Z', valveSpecId: 'ev50'));
      p.entities.add(PipeEntity(id: 'sub', points: [valvePos, const Pt(400, 2)], scope: HydraulicScope.zone));
      for (var i = 0; i < 6; i++) {
        p.entities.add(SpraylineEntity(id: 's$i', points: [Pt(400, 2 + i * 4.0), Pt(440, 2 + i * 4.0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2));
      }
      p.entities.add(PipeEntity(id: 'sub2', points: [const Pt(400, 2), const Pt(400, 22)], scope: HydraulicScope.zone));
      p.params.maxMainlineSizes = 3;
      final r = Designer(p, label: (k) => t(k)).designAll();
      expect(r.systemFlows.single.maxDeficit, lessThan(0.05));
      final mains = p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.mainline).toList();
      // either a single size satisfied the LP, or the entity was split from
      // the supply with the larger diameter upstream
      if (mains.length > 1) {
        final cat = p.catalog;
        final byStart = mains..sort((a, b) => a.points.first.x.compareTo(b.points.first.x));
        var last = double.infinity;
        for (final m in byStart) {
          final d = cat.pipe(m.pipeSpecId)!.innerDiameterMm;
          expect(d, lessThanOrEqualTo(last + 1e-9));
          last = d;
        }
      }
    });
  });

  group('BOM, flushing, surge, agronomy', () {
    late Project p;
    late Designer d;
    setUpAll(() {
      p = buildExampleProject(t.call, lang: 'pt');
      d = Designer(p, label: (k) => t(k))..designAll();
    });

    test('fittings are selected and priced from the catalog', () {
      final r = d.results;
      final fit = r.bom.where((b) => b.category == 'bom.fittings').toList();
      expect(fit, isNotEmpty);
      expect(fit.any((b) => b.description.contains('Tê') || b.description.contains('Cotovelo')), isTrue);
      expect(r.bom.any((b) => b.category == 'bom.takeoffs'), isTrue);
      expect(r.bom.any((b) => b.category == 'bom.risers'), isTrue);
      expect(fit.every((b) => b.quantity == b.quantity.roundToDouble()), isTrue);
      final sel = selectFittings(p, d.model, d.specOf, t: (k) => t(k));
      expect(sel.missing, isEmpty, reason: sel.missing.map((m) => m.key).join(','));
      expect(sel.lines.fold(0.0, (s, l) => s + l.total), greaterThan(0));
    });

    test('flushing analysis reports the drip zone', () {
      final fl = d.results.flushing;
      expect(fl.length, 1);
      final f = fl.single;
      expect(f.tapeCount, greaterThan(10));
      expect(f.minEndHead, greaterThanOrEqualTo(p.params.flushingMinEndHeadM - 0.05));
      expect(f.flow, greaterThan(d.results.zones[f.valveId]!.totalFlow));
      expect(f.maxVelocity, greaterThan(0.2));
    });

    test('surge check covers every sized pipe and flags none in the example', () {
      final s = d.results.surge;
      expect(s.length, greaterThan(10));
      expect(s.every((x) => x.celerity > 200 && x.celerity < 1500), isTrue);
      expect(s.where((x) => x.exceeds), isEmpty);
    });

    test('overlap CU and emitters per plant reach the zone results', () {
      final zones = d.results.zones.values.toList();
      final micro = zones.firstWhere((z) => z.overlapCu > 0);
      expect(micro.overlapCu, greaterThan(80));
      final drip = zones.firstWhere((z) => z.overlapCu == 0);
      expect(drip.emittersPerPlant, 4);
      expect(micro.emittersPerPlant, 1);
    });

    test('crop water, schedule and controller programme', () {
      final crops = cropWaterRequirements(p, d.results);
      expect(crops.length, 2);
      for (final c in crops) {
        expect(c.etcMmDay, closeTo(5.5 * 0.7, 1e-9));
        expect(c.intervalDays, greaterThanOrEqualTo(1));
        expect(c.hoursPerEvent, greaterThan(0));
      }
      final prog = buildControllerProgram(p, d.results, startDate: DateTime(2026, 9, 16), days: 14);
      expect(prog.entries, isNotEmpty);
      expect(prog.perFlowHours.length, 2);
      expect(prog.maxDailyHours, greaterThan(0));
      expect(prog.warnings.any((w) => w.startsWith('schedule_over_24h')), prog.maxDailyHours > 24);
      // the micro-sprinkler block: ETc 3.85 mm/d, RAW 48 mm → 12-day interval, ≈14.8 h per event
      final micro = crops.firstWhere((c) => c.name.contains('A'));
      expect(micro.intervalDays, 12);
      expect(micro.hoursPerEvent, closeTo(14.8, 0.6));
      final csv = controllerProgramCsv(prog, t: (k) => t(k));
      expect(csv, contains('2026-09-16'));
      expect(csv.split('\n').length, greaterThan(prog.entries.length));
    });

    test('pump selection ranks a suitable pump for the worst duty', () {
      final s = p.entities.whereType<WaterSupplyEntity>().single;
      final duty = worstDuty(d.results, s.id)!;
      final flow = duty.flow;
      final head = duty.requiredHead.abs() + 30; // make a positive demanding duty
      final cands = rankPumps(p.catalog, flow: flow, head: head, staticHead: 20, hoursPerYear: 2000, costPerKwh: 0.7);
      expect(cands, isNotEmpty);
      expect(cands.first.suitable, isTrue);
      expect(cands.first.headAtDuty, greaterThanOrEqualTo(head));
      expect(cands.first.operatingFlow, greaterThan(0));
    });
  });

  group('catalog and importers', () {
    test('catalog CSV/JSON export and import round trip', () {
      final cat = Catalog.defaultCatalog(lang: 'pt');
      for (final g in CatalogGroup.values) {
        final csv = CatalogIo.exportCsv(cat, g);
        final r = CatalogIo.parseCsv(csv, group: g);
        expect(r.group, g);
        expect(r.count, greaterThan(0));
      }
      final json = CatalogIo.exportJson(cat);
      final r = CatalogIo.parse(json);
      expect(r.catalog.itemCount, cat.itemCount);
      final empty = Catalog();
      expect(empty.merge(r.catalog), cat.itemCount);
      // manufacturer style CSV with a header
      final r2 = CatalogIo.parse('id;name;nominalMm;idMm;material;c;ratingM;cost;usage;supplier;code\npvcX;PVC DN 60;60;56.4;pvc;150;80;9.5;zone,mainline;ACME;PVC-60\n');
      expect(r2.group, CatalogGroup.pipes);
      expect(r2.catalog.pipes.single.supplier, 'ACME');
      expect(r2.catalog.pipes.single.usage, {PipeUsage.zone, PipeUsage.mainline});
      expect(cat.findFitting(FittingKind.tee, 75, size2Mm: 50)!.size2Mm, 50);
      expect(cat.findFitting(FittingKind.elbow90, 63)!.sizeMm, greaterThanOrEqualTo(63));
    });

    test('survey points: header, PNEZD and geographic input', () {
      final a = PointsCsvReader.parse('x;y;z\n10,5;20,5;100,2\n11;21;101\n');
      expect(a.count, 2);
      expect(a.geographic, isFalse);
      expect(a.document.entities.first.elevation, closeTo(100.2, 1e-9));
      final b = PointsCsvReader.parse('1,200,100,50.5,EST\n2,210,110,51.5,EST\n');
      expect(b.count, 2);
      expect(b.document.entities.first.points.first.x, 100); // E column
      expect(b.document.entities.first.elevation, 50.5);
      final g = PointsCsvReader.parse('lat,lon,alt\n-22.9,-47.06,600\n-22.9001,-47.0601,601\n');
      expect(g.geographic, isTrue);
      expect(g.georef, isNotNull);
      expect(g.georef!.zone, 23);
      expect(g.document.entities.first.points.first.distanceTo(g.document.entities.last.points.first), closeTo(15, 3));
    });

    test('shapefile with dbf attributes inside a zip', () {
      // one PolyLineZ record: two points with z 100
      final pts = [const Pt(100.0, 200.0), const Pt(110.0, 200.0)];
      final content = BytesBuilder();
      final rec = ByteData(4 + 32 + 4 + 4 + 4 + 16 * 2 + 16 + 8 * 2);
      var o = 0;
      rec.setInt32(o, 13, Endian.little); // PolyLineZ
      o += 4;
      for (final v in [100.0, 200.0, 110.0, 200.0]) {
        rec.setFloat64(o, v, Endian.little);
        o += 8;
      }
      rec.setInt32(o, 1, Endian.little); // numParts
      o += 4;
      rec.setInt32(o, 2, Endian.little); // numPoints
      o += 4;
      rec.setInt32(o, 0, Endian.little); // part index
      o += 4;
      for (final p in pts) {
        rec.setFloat64(o, p.x, Endian.little);
        rec.setFloat64(o + 8, p.y, Endian.little);
        o += 16;
      }
      rec.setFloat64(o, 100, Endian.little); // zmin
      rec.setFloat64(o + 8, 100, Endian.little); // zmax
      o += 16;
      rec.setFloat64(o, 100, Endian.little);
      rec.setFloat64(o + 8, 100, Endian.little);
      final recBytes = rec.buffer.asUint8List();
      final header = ByteData(100);
      header.setInt32(0, 9994, Endian.big);
      header.setInt32(24, (100 + 8 + recBytes.length) ~/ 2, Endian.big);
      header.setInt32(28, 1000, Endian.little);
      header.setInt32(32, 13, Endian.little);
      final recHeader = ByteData(8);
      recHeader.setInt32(0, 1, Endian.big);
      recHeader.setInt32(4, recBytes.length ~/ 2, Endian.big);
      content.add(header.buffer.asUint8List());
      content.add(recHeader.buffer.asUint8List());
      content.add(recBytes);
      final shp = content.toBytes();
      // dbf with one field ELEV (N,10)
      final dbf = BytesBuilder();
      final dh = ByteData(32);
      dh.setUint8(0, 3);
      dh.setUint32(4, 1, Endian.little);
      dh.setUint16(8, 32 + 32 + 1, Endian.little);
      dh.setUint16(10, 1 + 10, Endian.little);
      dbf.add(dh.buffer.asUint8List());
      final field = Uint8List(32);
      field.setRange(0, 4, 'ELEV'.codeUnits);
      field[11] = 'N'.codeUnitAt(0);
      field[16] = 10;
      dbf.add(field);
      dbf.add([0x0D]);
      dbf.add(' '.codeUnits);
      dbf.add('     105.5'.codeUnits);
      final arc = Archive()
        ..addFile(ArchiveFile('curvas.shp', shp.length, shp))
        ..addFile(ArchiveFile('curvas.dbf', dbf.length, dbf.toBytes()))
        ..addFile(ArchiveFile('curvas.prj', 10, 'PROJCS["WGS 84 / UTM zone 23S"]'.codeUnits));
      final zip = Uint8List.fromList(ZipEncoder().encode(arc));
      final r = ShpReader.parseAny('curvas.zip', zip);
      expect(r.recordCount, 1);
      expect(r.document.entities.single.type, 'POLYLINE');
      expect(r.document.entities.single.elevation, 105.5); // attribute wins over Z
      expect(r.document.layers.single.name, 'curvas');
      expect(r.geographic, isFalse);
    });

    test('GeoTIFF tags: pixel scale, tiepoint and UTM zone key', () {
      // minimal little-endian TIFF with 4 entries (no image data needed for tags)
      final b = BytesBuilder();
      final hdr = ByteData(8);
      hdr.setUint8(0, 0x49);
      hdr.setUint8(1, 0x49);
      hdr.setUint16(2, 42, Endian.little);
      hdr.setUint32(4, 8, Endian.little);
      b.add(hdr.buffer.asUint8List());
      final n = 4;
      final ifd = ByteData(2 + n * 12 + 4);
      ifd.setUint16(0, n, Endian.little);
      var e = 2;
      final dataStart = 8 + 2 + n * 12 + 4;
      void entry(int tag, int type, int count, int valueOrOffset) {
        ifd.setUint16(e, tag, Endian.little);
        ifd.setUint16(e + 2, type, Endian.little);
        ifd.setUint32(e + 4, count, Endian.little);
        ifd.setUint32(e + 8, valueOrOffset, Endian.little);
        e += 12;
      }

      entry(256, 3, 1, 100);
      entry(33550, 12, 3, dataStart);
      entry(33922, 12, 6, dataStart + 24);
      entry(34735, 3, 8, dataStart + 24 + 48);
      b.add(ifd.buffer.asUint8List());
      final data = ByteData(24 + 48 + 16);
      var o = 0;
      for (final v in [0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 200000.0, 7500000.0, 0.0]) {
        data.setFloat64(o, v, Endian.little);
        o += 8;
      }
      for (final v in [1, 1, 0, 1, 3072, 0, 1, 32723]) {
        data.setUint16(o, v, Endian.little);
        o += 2;
      }
      b.add(data.buffer.asUint8List());
      final tags = GeoImageReader.readTiffTags(b.toBytes());
      expect(tags.doubles[33550]![0], 0.5);
      expect(tags.doubles[33922]![3], 200000.0);
      final keys = tags.shorts[34735]!;
      expect(keys[4], 3072);
      expect(keys[7], 32723);
      final g = GeoImage(bytes: Uint8List(0), mime: 'image/png', widthPx: 100, heightPx: 50, worldTopLeft: const Pt(200000, 7500000), pixelSizeX: 0.5, pixelSizeY: -0.5, utmZone: 23, utmNorth: false);
      final (bl, w, h, rot, ref) = placeGeoImage(g, null);
      expect(w, 50);
      expect(h, 25);
      expect(rot, 0);
      expect(ref!.zone, 23);
      expect(bl.y, closeTo(7500000 - 25 - ref.originNorthing, 1e-6));
      expect(GeoImageReader.parseWorldFile('0.5\n0\n0\n-0.5\n200000.25\n7499999.75\n')!.$5, 200000.25);
    });

    test('units and json helpers used by the new tables', () {
      expect(fmt(m3sPerLph * 3.6e6, 1), '1.0');
      expect(jsonDecode(jsonEncode({'a': 1})), {'a': 1});
    });
  });
}
