import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/i18n/language_packs.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/io/dem_online.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/geo_export.dart';
import 'package:opencadirrigation/core/io/geoimage.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/points_csv.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/shp.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Importers and exporters on the inputs the other format tests do not
/// reach: catalogue lists and kind names, UTM zone exceptions, GeoTIFF
/// transforms, hand-written XLSX, KMZ/KML variants, DBF encodings, DXF
/// blocks and curves, PDF report pages, drawing entities in the plot, DXF
/// and GeoJSON exports, and the online DEM sources.
void main() {
  group('catalogue import', () {
    test('a JSON list is read as the group it is imported into', () {
      final cat = Catalog.defaultCatalog();
      final lists = <CatalogGroup, List<Map<String, dynamic>>>{
        CatalogGroup.pipes: [for (final e in cat.pipes.take(2)) e.toJson()],
        CatalogGroup.outlets: [for (final e in cat.outlets.take(2)) e.toJson()],
        CatalogGroup.tapes: [for (final e in cat.tapes.take(2)) e.toJson()],
        CatalogGroup.valves: [for (final e in cat.valves.take(2)) e.toJson()],
        CatalogGroup.pumps: [for (final e in cat.pumps.take(2)) e.toJson()],
        CatalogGroup.fittings: [for (final e in cat.fittings.take(2)) e.toJson()],
      };
      for (final MapEntry(key: g, value: list) in lists.entries) {
        final r = CatalogIo.parse(jsonEncode(list), group: g);
        expect(r.group, g);
        expect(r.count, 2, reason: g.name);
        expect(r.catalog.itemCount, 2, reason: g.name);
      }
      expect(CatalogIo.parse(jsonEncode(lists[CatalogGroup.pumps]), group: CatalogGroup.pumps).catalog.pumps.first.id, cat.pumps.first.id);
      expect(() => CatalogIo.parse('[{"id": "x"}]'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'catalog_json_unknown')), reason: 'a list needs the group');
      // a catalogue wrapped in {"catalog": …}
      expect(CatalogIo.parse(jsonEncode({'catalog': cat.toJson()})).count, cat.itemCount);
    });

    test('pump rows with a single flow/head column pair', () {
      final r = CatalogIo.parse('id;name;qm3h;hm;eff;kw\np1;Bomba 20 m³/h;20;35;0,68;4\np2;sem curva;0;0;0.7;1\n');
      expect(r.group, CatalogGroup.pumps);
      expect(r.catalog.pumps.map((p) => p.id), ['p1'], reason: 'a row without a duty point is skipped');
      final p = r.catalog.pumps.single;
      expect(p.curve.head(20 * m3sPerM3h), closeTo(35, 1e-6));
      expect(p.curve.head(0), closeTo(35 * 1.33, 1e-6), reason: 'EPANET three-point curve from one duty');
      expect(p.maxFlow, closeTo(24 * m3sPerM3h, 1e-12));
      expect(p.efficiency, closeTo(0.68, 1e-12));
      expect(p.powerKw, 4);
    });

    test('fitting kinds from free text (the words that start with a t are not tees)', () {
      final cases = {
        'tampão': FittingKind.endCap,
        'Tampão final 50': FittingKind.endCap,
        'end cap': FittingKind.endCap,
        'plug': FittingKind.endCap,
        'take-off': FittingKind.takeOff,
        'conector inicial': FittingKind.takeOff,
        'start connector': FittingKind.takeOff,
        'tape end': FittingKind.tapeEnd,
        'final de linha': FittingKind.tapeEnd,
        'T': FittingKind.tee,
        'T 50': FittingKind.tee,
        't50': FittingKind.tee,
        'Tê 50 mm': FittingKind.tee,
        'tee reducer': FittingKind.tee,
        'cotovelo 90': FittingKind.elbow90,
        'joelho 90': FittingKind.elbow90,
        'elbow 45': FittingKind.elbow45,
        'codo': FittingKind.elbow90,
        'cruzeta': FittingKind.cross,
        'cross': FittingKind.cross,
        'redução': FittingKind.reducer,
        'adaptador': FittingKind.adapter,
        'riser': FittingKind.riser,
        'haste': FittingKind.riser,
        'luva': FittingKind.coupler,
        'transição': FittingKind.coupler,
      };
      for (final e in cases.entries) {
        expect(CatalogIo.fittingKindFromText(e.key), e.value, reason: e.key);
      }
      final csv = CatalogIo.parseCsv('id;name;kind;sizemm;cost\nf1;Tampão 50;tampão;50;2\nf2;Início;take-off;16;0.5\nf3;Fim;tape end;16;0.3\nf4;Tê;tee;50;4\n', group: CatalogGroup.fittings);
      expect(csv.catalog.fittings.map((f) => f.kind), [FittingKind.endCap, FittingKind.takeOff, FittingKind.tapeEnd, FittingKind.tee]);
    });

    test('a pack title is its name, else the brand', () {
      expect(const CatalogPackMeta(id: 'a', brand: 'Acme').title, 'Acme');
      expect(const CatalogPackMeta(id: 'a', brand: 'Acme', name: 'Acme Drip 2026').title, 'Acme Drip 2026');
    });
  });

  group('UTM', () {
    test('Norway and Svalbard zone exceptions, clamping at 180°', () {
      expect(utmZoneFor(60, 2), 31);
      expect(utmZoneFor(60, 5), 32, reason: 'south-west Norway is in 32V');
      expect(utmZoneFor(78, 5), 31);
      expect(utmZoneFor(78, 15), 33);
      expect(utmZoneFor(78, 25), 35);
      expect(utmZoneFor(78, 38), 37);
      expect(utmZoneFor(78, 45), 38, reason: 'east of 42° the normal zones apply');
      expect(utmZoneFor(-15.78, -47.93), 23);
      expect(utmZoneFor(0, 180), 60);
      expect(latLonToUtm(78, 15).zone, 33);
    });

    test('a georeference converts local points to UTM and back to JSON', () {
      final g = GeoReference.fromLatLonOrigin(-15.78, -47.93);
      expect(g.toUtm(0, 0), (g.originEasting, g.originNorthing));
      final (e, n) = g.toUtm(10, -20);
      expect(e, closeTo(g.originEasting + 10, 1e-9));
      expect(n, closeTo(g.originNorthing - 20, 1e-9));
      expect(g.crsName, 'WGS84 / UTM 23S');
      final back = GeoReference.fromJson(g.toJson());
      expect((back.zone, back.north, back.originEasting, back.originNorthing), (g.zone, g.north, g.originEasting, g.originNorthing));
    });
  });

  group('georeferenced images', () {
    test('world size and georeferenced flag', () {
      final g = GeoImage(bytes: Uint8List(0), mime: 'image/png', widthPx: 100, heightPx: 50, worldTopLeft: const Pt(200000, 7500000), pixelSizeX: 0.5, pixelSizeY: -0.5);
      expect(g.georeferenced, isTrue);
      expect(g.worldWidth, 50);
      expect(g.worldHeight, 25);
      final plain = GeoImage(bytes: Uint8List(0), mime: 'image/png', widthPx: 100, heightPx: 50);
      expect(plain.georeferenced, isFalse);
      expect(plain.worldWidth, 100);
      expect(plain.worldHeight, 50);
    });

    test('ModelTransformation gives pixel size and rotation; GeoKeys give the CRS', () {
      const s = 2.0, th = math.pi / 6;
      final tags = TiffTags()
        ..doubles[34264] = [s * math.cos(th), s * math.sin(th), 0, 300000, s * math.sin(th), -s * math.cos(th), 0, 6000000, 0, 0, 0, 0, 0, 0, 0, 1]
        ..shorts[34735] = [1, 1, 0, 1, 3072, 0, 1, 32633];
      final g = GeoImageReader.tiffGeo(tags);
      expect(g.georeferenced, isTrue);
      expect(g.topLeft, const Pt(300000, 6000000));
      expect(g.sx, closeTo(2, 1e-12));
      expect(g.sy, closeTo(-2, 1e-12));
      expect(g.rot, closeTo(30, 1e-9));
      expect(g.zone, 33);
      expect(g.north, isTrue);
      // geographic rasters: model type 2 or GCS 4326
      final geo = GeoImageReader.tiffGeo(TiffTags()..shorts[34735] = [1, 1, 0, 1, 1024, 0, 1, 2]);
      expect(geo.geographic, isTrue);
      expect(geo.georeferenced, isFalse);
      expect(GeoImageReader.tiffGeo(TiffTags()..shorts[34735] = [1, 1, 0, 1, 2048, 0, 1, 4326]).geographic, isTrue);
      expect(GeoImageReader.tiffGeo(TiffTags()..shorts[34735] = [1, 1, 0, 1, 3072, 0, 1, 32723]).north, isFalse);
    });
  });

  group('XLSX', () {
    Uint8List zip(Map<String, String> files) {
      final a = Archive();
      for (final e in files.entries) {
        final b = utf8.encode(e.value);
        a.addFile(ArchiveFile(e.key, b.length, b));
      }
      return Uint8List.fromList(ZipEncoder().encode(a));
    }

    const sheetXml = '<worksheet><sheetData>'
        '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="AA1" t="inlineStr"><is><t>far</t></is></c></row>'
        '<row r="2"><c r="B2" t="str"><v>x</v></c><c r="A2"><v>3.5</v></c></row>'
        '<row r="3"><c t="s"><v>2</v></c><c><v>7</v></c><c t="b"><v>1</v></c></row>'
        '<row r="4"><c r="c4"><v>9</v></c><c r="D4" t="s"><v>99</v></c></row>'
        '</sheetData></worksheet>';

    test('shared strings, out-of-order cells, cells without references and far columns', () {
      final bytes = zip({
        'xl/workbook.xml': '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Preços" sheetId="1" r:id="rId1"/></sheets></workbook>',
        'xl/_rels/workbook.xml.rels': '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
        'xl/sharedStrings.xml': '<sst><si><t>id</t></si><si><t>nome</t></si><si><r><t>Tubo </t></r><r><t>PVC</t></r></si></sst>',
        'xl/worksheets/sheet1.xml': sheetXml,
      });
      final s = XlsxReader.read(bytes).single;
      expect(s.name, 'Preços');
      expect(s.headers.length, 27, reason: 'AA is the 27th column');
      expect(s.headers.first, 'id');
      expect(s.headers[1], 'nome');
      expect(s.headers.last, 'far');
      expect(s.rows[0], [3.5, 'x'], reason: 'B2 written before A2');
      expect(s.rows[1], ['Tubo PVC', 7.0, '1'], reason: 'cells without an r attribute follow each other');
      expect(s.rows[2], [null, null, 9.0, ''], reason: 'lower-case reference; an unknown shared string is empty');
    });

    test('without a workbook part every worksheet file is read', () {
      final s = XlsxReader.read(zip({'xl/worksheets/sheet1.xml': sheetXml})).single;
      expect(s.name, 'sheet1');
      expect(s.headers.last, 'far');
      expect(s.headers.first, '', reason: 'no shared strings part');
    });

    test('sheet names are cleaned, cut to 31 characters and made unique', () {
      final long = 'A' * 40;
      final bytes = XlsxWriter.write([
        XlsxSheet(name: 'Tubos', headers: ['a'], rows: [[1]]),
        XlsxSheet(name: 'Tubos', headers: ['a'], rows: [[2]]),
        XlsxSheet(name: long, headers: ['a'], rows: [[3]]),
        XlsxSheet(name: long, headers: ['a'], rows: [[4]]),
        XlsxSheet(name: 'a/b[c]', headers: ['a'], rows: [[5]]),
        XlsxSheet(name: '  ', headers: ['a'], rows: [[6]]),
      ]);
      final names = XlsxReader.read(Uint8List.fromList(bytes)).map((s) => s.name).toList();
      expect(names, ['Tubos', 'Tubos (2)', 'A' * 31, '${'A' * 27} (2)', 'a b c', 'Sheet6']);
      expect(names.every((n) => n.length <= 31), isTrue);
    });
  });

  group('KML / KMZ', () {
    const kml = '<kml><Document>'
        '<Placemark><name>Lote</name><MultiGeometry>'
        '<Polygon><outerBoundaryIs><LinearRing><coordinates>-47.93,-15.78,0 -47.92,-15.78,0 -47.92,-15.77,0 -47.93,-15.78,0</coordinates></LinearRing></outerBoundaryIs>'
        '<innerBoundaryIs><LinearRing><coordinates>-47.927,-15.777,0 -47.925,-15.777,0 -47.925,-15.776,0 -47.927,-15.777,0</coordinates></LinearRing></innerBoundaryIs></Polygon>'
        '<LineString><coordinates>-47.93,-15.78,0 -47.92,-15.79,0</coordinates></LineString>'
        '</MultiGeometry></Placemark>'
        '<Placemark><name>Anel</name><LinearRing><coordinates>-47.93,-15.78,0 -47.931,-15.78,0 -47.931,-15.781,0</coordinates></LinearRing></Placemark>'
        '<Placemark><name>Poço</name><ExtendedData><SchemaData><SimpleData name="COTA">512,5</SimpleData></SchemaData></ExtendedData><Point><coordinates>-47.925,-15.775,0</coordinates></Point></Placemark>'
        '</Document></kml>';

    test('multi-geometries, holes, bare rings and SimpleData elevations', () {
      final r = KmlReader.parse(kml);
      expect(r.placemarkCount, 3);
      final polys = r.document.entities.where((e) => e.type == 'POLYLINE').toList();
      expect(polys.where((e) => e.closed).length, 3, reason: 'outer ring, hole and the bare ring');
      expect(polys.where((e) => !e.closed).length, 1);
      final well = r.document.entities.firstWhere((e) => e.type == 'POINT');
      expect(well.elevation, closeTo(512.5, 1e-9));
    });

    test('a KMZ may name its KML anything; without one it is refused', () {
      final a = Archive()
        ..addFile(ArchiveFile('images/readme.txt', 2, utf8.encode('hi')))
        ..addFile(ArchiveFile('files/Area.KML', utf8.encode(kml).length, utf8.encode(kml)));
      expect(KmlReader.parseKmz(Uint8List.fromList(ZipEncoder().encode(a))).placemarkCount, 3);
      final empty = Archive()..addFile(ArchiveFile('x.txt', 1, [65]));
      expect(() => KmlReader.parseKmz(Uint8List.fromList(ZipEncoder().encode(empty))), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'kmz_no_kml')));
    });
  });

  group('shapefile', () {
    /// A .shp with one PolyLineZ whose vertices have different heights and
    /// one null shape.
    Uint8List shp() {
      final rec = ByteData(4 + 32 + 8 + 4 + 32 + 16 + 16);
      var o = 0;
      rec.setInt32(o, 13, Endian.little);
      o += 4 + 32; // bbox left at zero
      rec.setInt32(o, 1, Endian.little);
      rec.setInt32(o + 4, 2, Endian.little);
      o += 8;
      rec.setInt32(o, 0, Endian.little);
      o += 4;
      for (final v in [10.0, 20.0, 30.0, 20.0]) {
        rec.setFloat64(o, v, Endian.little);
        o += 8;
      }
      o += 16; // z range
      rec.setFloat64(o, 100, Endian.little);
      rec.setFloat64(o + 8, 101, Endian.little);
      final nullRec = ByteData(4)..setInt32(0, 0, Endian.little);
      final b = BytesBuilder();
      final header = ByteData(100)
        ..setInt32(0, 9994, Endian.big)
        ..setInt32(24, (100 + 8 + rec.lengthInBytes + 8 + 4) ~/ 2, Endian.big)
        ..setInt32(28, 1000, Endian.little)
        ..setInt32(32, 13, Endian.little);
      b.add(header.buffer.asUint8List());
      b.add((ByteData(8)
            ..setInt32(0, 1, Endian.big)
            ..setInt32(4, rec.lengthInBytes ~/ 2, Endian.big))
          .buffer
          .asUint8List());
      b.add(rec.buffer.asUint8List());
      b.add((ByteData(8)
            ..setInt32(0, 2, Endian.big)
            ..setInt32(4, 2, Endian.big))
          .buffer
          .asUint8List());
      b.add(nullRec.buffer.asUint8List());
      return b.toBytes();
    }

    /// dBase file with a NOME (C, 10) field holding [bytes] in two records.
    Uint8List dbf(List<int> bytes) {
      final b = BytesBuilder();
      final h = ByteData(32)
        ..setUint8(0, 3)
        ..setUint32(4, 2, Endian.little)
        ..setUint16(8, 32 + 32 + 1, Endian.little)
        ..setUint16(10, 1 + 10, Endian.little);
      b.add(h.buffer.asUint8List());
      final f = Uint8List(32)
        ..setRange(0, 4, 'NOME'.codeUnits)
        ..[11] = 'C'.codeUnitAt(0)
        ..[16] = 10;
      b.add(f);
      b.add([0x0D]);
      for (var r = 0; r < 2; r++) {
        b.add([0x20]);
        b.add([...bytes, ...List.filled(10 - bytes.length, 0x20)]);
      }
      return b.toBytes();
    }

    test('different heights along a line give no single elevation; null shapes are skipped', () {
      final r = ShpReader.parse(shp());
      expect(r.recordCount, 2);
      expect(r.document.entities.length, 1);
      final line = r.document.entities.single;
      expect(line.elevation, isNull);
      expect(line.points, [const Pt(10, 20), const Pt(30, 20)]);
    });

    test('the .cpg decides the text encoding of the attributes', () {
      final latin = latin1.encode('Açude');
      final utf = utf8.encode('Açude');
      String name(Uint8List d, String? cpg) => ShpReader.parse(shp(), dbf: d, cpg: cpg).document.entities.single.name;
      expect(name(dbf(latin), '1252'), 'Açude');
      expect(name(dbf(latin), 'ISO-8859-1'), 'Açude');
      expect(name(dbf(utf), 'UTF-8'), 'Açude');
      expect(name(dbf(utf), null), 'Açude', reason: 'valid UTF-8 without a .cpg');
      expect(name(dbf(latin), null), 'Açude', reason: 'invalid UTF-8 falls back to Latin-1');
      expect(name(dbf(utf), '1252'), 'AÃ§ude', reason: 'the .cpg is obeyed even when it is wrong');
    });
  });

  group('survey points', () {
    test('degrees without a header are recognised by their decimals', () {
      final r = PointsCsvReader.parse('-47.060110,-22.900120,600\n-47.060210,-22.900220,601\n-47.060310,-22.900320,602\n');
      expect(r.geographic, isTrue);
      expect(r.georef!.zone, 23);
      expect(r.count, 3);
      final metric = PointsCsvReader.parse('100.5,200.25,600\n110.5,210.25,601\n');
      expect(metric.geographic, isFalse, reason: 'millimetre coordinates are metres');
    });
  });

  group('DXF reader: blocks, curves and dimensions', () {
    String dxf(List<Object> codes) => '${codes.join('\n')}\n';
    final text = dxf([
      0, 'SECTION', 2, 'BLOCKS',
      0, 'BLOCK', 8, '0', 2, 'INNER', 10, 0, 20, 0,
      0, 'LINE', 8, '0', 10, 0, 20, 0, 11, 1, 21, 0,
      0, 'CIRCLE', 8, '0', 10, 0, 20, 0, 40, 1,
      0, 'ARC', 8, '0', 10, 0, 20, 0, 40, 1, 50, 0, 51, 90,
      0, 'ENDBLK',
      0, 'BLOCK', 8, '0', 2, 'OUTER', 10, 0, 20, 0,
      0, 'INSERT', 8, '0', 2, 'INNER', 10, 10, 20, 0,
      0, 'ENDBLK',
      0, 'BLOCK', 8, '0', 2, '*D1', 10, 0, 20, 0,
      0, 'LINE', 8, 'DIM', 10, 0, 20, 0, 11, 5, 21, 0,
      0, 'POINT', 8, 'DIM', 10, 0, 20, 0,
      0, 'ENDBLK',
      0, 'ENDSEC',
      0, 'SECTION', 2, 'ENTITIES',
      0, 'INSERT', 8, 'BLK', 2, 'OUTER', 10, 100, 20, 100, 41, 2, 42, 2,
      0, 'INSERT', 8, 'SQ', 2, 'INNER', 10, 0, 20, 50, 41, 2, 42, 1,
      0, 'DIMENSION', 8, 'DIM', 2, '*D1',
      0, 'ELLIPSE', 8, 'EF', 10, 0, 20, 0, 11, 4, 21, 0, 40, 0.5, 41, 0, 42, 2 * math.pi,
      0, 'ELLIPSE', 8, 'EH', 10, 0, 20, 0, 11, 4, 21, 0, 40, 0.5, 41, 0, 42, math.pi,
      0, 'SPLINE', 8, 'SF', 70, 0, 11, 0, 21, 0, 11, 5, 21, 5, 11, 10, 21, 0,
      0, 'SPLINE', 8, 'SC', 70, 1, 10, 0, 20, 0, 10, 5, 20, 5, 10, 10, 20, 0,
      0, 'LWPOLYLINE', 8, 'BU', 90, 2, 70, 0, 10, 0, 20, 0, 42, 1, 10, 10, 20, 0,
      0, 'ENDSEC', 0, 'EOF',
    ]);
    final doc = DxfReader.parse(text);
    List<DxfEntity> on(String layer) => doc.entities.where((e) => e.layer == layer).toList();

    test('nested references compose their transforms and take the outer layer', () {
      final blk = on('BLK');
      final line = blk.firstWhere((e) => e.type == 'LINE');
      expect(line.points[0].distanceTo(const Pt(120, 100)), lessThan(1e-9));
      expect(line.points[1].distanceTo(const Pt(122, 100)), lessThan(1e-9));
      final circle = blk.firstWhere((e) => e.type == 'CIRCLE');
      expect(circle.center!.distanceTo(const Pt(120, 100)), lessThan(1e-9));
      expect(circle.radius, closeTo(2, 1e-9));
      final arc = blk.firstWhere((e) => e.type == 'ARC');
      expect(arc.radius, closeTo(2, 1e-9));
      expect(arc.endAngle - arc.startAngle, closeTo(90, 1e-9));
    });

    test('a non-uniform scale turns circles and arcs into polylines', () {
      final sq = on('SQ');
      expect(sq.where((e) => e.type == 'CIRCLE' || e.type == 'ARC'), isEmpty);
      final ring = sq.firstWhere((e) => e.type == 'POLYLINE' && e.closed);
      expect(ring.points.length, 36);
      for (final p in ring.points) {
        // x stretched ×2: (x/2)² + (y−50)² = 1
        expect(math.pow(p.x / 2, 2) + math.pow(p.y - 50, 2), closeTo(1, 1e-9));
      }
      final arc = sq.firstWhere((e) => e.type == 'POLYLINE' && !e.closed);
      expect(arc.points.first.distanceTo(const Pt(2, 50)), lessThan(1e-9));
      expect(arc.points.last.distanceTo(const Pt(0, 51)), lessThan(1e-9));
    });

    test('dimensions draw their block without the definition points', () {
      final dim = on('DIM');
      expect(dim.map((e) => e.type), ['LINE']);
      expect(dim.single.points.last, const Pt(5, 0));
    });

    test('full and partial ellipses, splines by fit or control points, bulges', () {
      final full = on('EF').single;
      expect(full.closed, isTrue);
      expect(full.points.length, 36);
      for (final p in full.points) {
        expect(math.pow(p.x / 4, 2) + math.pow(p.y / 2, 2), closeTo(1, 1e-9));
      }
      final half = on('EH').single;
      expect(half.closed, isFalse);
      expect(half.points.first.distanceTo(const Pt(4, 0)), lessThan(1e-9));
      expect(half.points.last.distanceTo(const Pt(-4, 0)), lessThan(1e-9));
      expect(half.points.every((p) => p.y >= -1e-9), isTrue);
      // fit points: a smooth spline through them
      final fit = on('SF').single;
      expect(fit.type, 'SPLINE');
      expect(fit.points, [const Pt(0, 0), const Pt(5, 5), const Pt(10, 0)]);
      expect(fit.closed, isFalse);
      // control points only: the curve they define (here a quadratic Bézier
      // with its top at y = 2.5), not the control polygon through (5, 5)
      final ctrl = on('SC').single;
      expect(ctrl.type, 'POLYLINE');
      expect(ctrl.closed, isTrue);
      expect(ctrl.points.first, const Pt(0, 0));
      expect(ctrl.points.last.distanceTo(const Pt(10, 0)), lessThan(1e-12));
      expect(ctrl.points.map((p) => p.y).reduce(math.max), closeTo(2.5, 0.01));
      final bulge = on('BU').single;
      expect(bulge.points.first, const Pt(0, 0));
      expect(bulge.points.last, const Pt(10, 0));
      expect(bulge.points.length, greaterThan(4));
      for (final p in bulge.points.skip(1).take(bulge.points.length - 2)) {
        expect(p.distanceTo(const Pt(5, 0)), closeTo(5, 1e-9), reason: 'a bulge of 1 is a half circle');
        expect(p.y, lessThan(0), reason: 'counter-clockwise from (0,0) to (10,0) runs below the chord');
      }
    });

    test('Affine2.then applies the inner transform first', () {
      const scale = Affine2(2, 0, 0, 2, 0, 0);
      const shift = Affine2(1, 0, 0, 1, 10, 0);
      expect(scale.then(shift).apply(const Pt(1, 1)), const Pt(22, 2));
      expect(shift.then(scale).apply(const Pt(1, 1)), const Pt(12, 2));
    });
  });

  group('PDF', () {
    test('a single-point path is drawn as a dot; a no-break space has its own width', () {
      final doc = PdfDocument(title: 't');
      final page = doc.addPage(widthPt: 100, heightPt: 100);
      page.path([(10.0, 10.0)]);
      page.path(const []);
      final text = latin1.decode(doc.build(compress: false));
      expect(text, contains(' c '), reason: 'the dot is a Bézier circle');
      expect(PdfPage.textWidth(' ', 10), closeTo(2.78, 1e-9));
      expect(PdfPage.textWidth('°', 10), closeTo(3.33, 1e-9));
    });

    test('report pages: the no-results note, an empty table and a table wider than the page', () {
      final seen = <String>[];
      final ex = ProjectExporter(project: Project(), results: null, labels: ReportLabels(t: (k, [a]) {
        seen.add(k);
        return k;
      }, has: (_) => false, warning: (w) => w));
      final none = ex.sheetBuilder().buildReport(const []);
      expect(latin1.decode(none), startsWith('%PDF-1.4'));
      expect(seen, contains('pdf.noResults'));
      seen.clear();
      final wide = ReportTable(key: 'wide', title: 'Wide', headers: [for (var i = 0; i < 14; i++) 'Column header number $i'], rows: [
        for (var r = 0; r < 3; r++) [for (var i = 0; i < 14; i++) 'a rather long text cell $r/$i that must wrap'],
      ]);
      final empty = ReportTable(key: 'empty', title: 'Empty', headers: ['a', 'b'], rows: const []);
      final pdf = ex.sheetBuilder().buildReport([empty, wide]);
      expect(seen, isNot(contains('pdf.noResults')));
      final raw = latin1.decode(pdf);
      expect(raw.trimRight(), endsWith('%%EOF'));
      expect(int.parse(RegExp(r'/Count (\d+)').firstMatch(raw)!.group(1)!), greaterThanOrEqualTo(1));
    });

    test('sheet options copy', () {
      const o = SheetOptions(scale: 500, includeReports: true);
      expect(o.copyWith(clearScale: true).scale, isNull);
      expect(o.copyWith(page: PageSize.a1).scale, 500);
      expect(o.copyWith(landscape: false).widthMm, PageSize.a3.shortMm);
      expect(o.copyWith(bomOnSheet: false).includeReports, isTrue);
    });
  });

  group('drawing entities in the plot, DXF and GeoJSON', () {
    Project drawing() {
      final p = Project();
      p.meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
      p.entities.addAll([
        ArcEntity(id: 'arc', center: Pt.zero, radius: 5, startRad: 0, sweepRad: math.pi / 2),
        SplineEntity(id: 'spl', points: [const Pt(0, 0), const Pt(5, 5), const Pt(10, 0)], closed: true),
        HatchEntity(id: 'hs', points: [const Pt(0, 0), const Pt(4, 0), const Pt(4, 4)], solid: true),
        HatchEntity(id: 'hp', points: [const Pt(10, 0), const Pt(14, 0), const Pt(14, 4)], angleDeg: 45, spacing: 1),
        HatchEntity(id: 'hf', points: [const Pt(40, 0), const Pt(44, 0), const Pt(44, 4)], spacing: 0.2),
        AngularDimensionEntity(id: 'ang', vertex: Pt.zero, a: const Pt(10, 0), b: const Pt(0, 10), radius: 3),
        RadialDimensionEntity(id: 'rad', center: Pt.zero, point: const Pt(3, 4)),
        LeaderEntity(id: 'lea', points: [const Pt(0, 0), const Pt(5, 5), const Pt(9, 5)], text: 'Nota', height: 1),
        ImageEntity(id: 'img', origin: const Pt(20, 0), width: 10, height: 5, source: 'foto.png'),
        DimensionEntity(id: 'dim', a: const Pt(0, -5), b: const Pt(10, -5), offset: -2),
        JunctionEntity(id: 'jun', position: const Pt(30, 0)),
        PumpEntity(id: 'pmp', position: const Pt(60, 0), pumpSpecId: 'gone'),
      ]);
      return p;
    }

    ProjectExporter exporter(Project p) => ProjectExporter(project: p, results: null, labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w));

    test('the plot scene draws every entity type with its annotation', () {
      final scene = buildPlotScene(drawing(), unitsPerMm: 1, t: (k, [a]) => k);
      final texts = scene.items.whereType<PlotText>().map((t) => t.text).toList();
      expect(texts, containsAll(['90.0°', 'R 5.00 m', 'Nota', '10.00 m']));
      expect(texts, contains('tool.pump'), reason: 'a pump without a catalogue model is labelled by the tool name');
      final paths = scene.items.whereType<PlotPath>().toList();
      // solid hatch, a pattern too fine for paper (0.2 mm) drawn as a light fill, and the leader arrow head
      expect(paths.where((p) => p.fillColor != null).length, 3);
      // the 1 mm pattern is drawn as lines inside its outline
      final pattern = HatchEntity(id: 'x', points: [const Pt(10, 0), const Pt(14, 0), const Pt(14, 4)], angleDeg: 45, spacing: 1).patternLines();
      expect(pattern, isNotEmpty);
      expect(paths.where((p) => !p.closed && pattern.any((l) => l.first == p.points.first)).length, pattern.length);
      expect(paths.any((p) => p.closed && p.points.length == 4 && p.points.contains(const Pt(20, 0))), isTrue, reason: 'image frame');
      expect(scene.items.whereType<PlotCircle>().any((c) => c.center == const Pt(30, 0)), isTrue, reason: 'junction dot');
      expect(scene.layers.keys, containsAll([Layers.dimensions, Layers.hatches, Layers.images]));
    });

    test('DXF and GeoJSON carry the drawing entities too', () {
      final p = drawing();
      final ex = exporter(p);
      final doc = ex.dxfDocument();
      final texts = doc.entities.where((e) => e.type == 'TEXT').map((e) => e.text).toList();
      expect(texts, containsAll(['90.0°', 'R 5.00', 'Nota', '10.00']));
      expect(doc.entities.any((e) => e.type == 'ARC' && (e.radius - 5).abs() < 1e-9), isTrue);
      expect(doc.entities.any((e) => e.type == 'POINT' && e.points.single == const Pt(30, 0)), isTrue);
      expect(doc.entities.any((e) => e.type == 'POLYLINE' && e.closed && e.points.contains(const Pt(20, 0))), isTrue);
      final feats = ex.geoFeatures();
      final names = feats.map((f) => f.name).toList();
      expect(names, containsAll(['90.0°', 'R 5.00 m', 'Nota', 'foto.png', '10.00 m']));
      expect(feats.firstWhere((f) => f.name == 'foto.png').type, 'Polygon');
      expect(feats.where((f) => f.type == 'Point').length, 2, reason: 'the junction and the pump');
      final j = jsonDecode(ex.geoJson()) as Map<String, dynamic>;
      expect((j['features'] as List).length, feats.length);
    });

    test('print colours, scales beyond the table and feature defaults', () {
      expect(blendOverWhite(0xFF000000, 0.5), 0xFF808080);
      expect(blendOverWhite(0x80FF0000), 0xFFFF7F7F);
      expect(blendOverWhite(0x00123456), 0xFFFFFFFF, reason: 'fully transparent is white');
      expect(fitScale(const Bounds(0, 0, 1e6, 10), 400, 260), 2500000);
      expect(fitScale(Bounds.empty, 400, 260), 1000);
      expect(fitScale(const Bounds(0, 0, 10, 10), 0, 260), 1000);
      final f = GeoFeature(name: 'a', folder: 'f', type: 'Point', coords: const [(0, 0, 0)]);
      expect(f.data, isEmpty);
      f.data['k'] = 'v';
      expect(f.data['k'], 'v');
    });
  });

  group('online DEM sources', () {
    final geo = GeoReference.fromLatLonOrigin(-22.9, -47.1);

    test('credits, resolution, request counts and the ASTER service', () {
      for (final s in DemSource.values) {
        expect(s.attribution, isNotEmpty, reason: s.name);
      }
      expect(DemSource.openMeteo.attribution, contains('Copernicus'));
      expect(DemSource.openTopoAster.attribution, contains('ASTER'));
      expect(DemSource.openMeteo.resolutionM, 90);
      expect(DemSource.openTopoSrtm.resolutionM, 30);
      final pts = demGrid(const Bounds(0, 0, 1000, 600), 25, geo);
      expect(DemSource.openMeteo.requestCount(pts, 25), (pts.length / DemSource.openMeteo.batch).ceil());
      expect(DemSource.openTopoAster.requestCount(pts, 25), (pts.length / DemSource.openTopoAster.batch).ceil());
      expect(DemSource.openMeteo.requestCount(const [], 25), 0);
      final urls = demRequestUrls(DemSource.openTopoAster, pts.take(3).toList());
      expect(urls.single, contains('opentopodata.org/v1/aster30m?locations='));
      expect('|'.allMatches(urls.single).length, 2);
      expect(demParseResponse(DemSource.openTopoAster, '{"status":"OK","results":[{"elevation":700.5},{"elevation":"x"}]}'), [700.5, null]);
      expect(() => demParseResponse(DemSource.terrainTiles, '{}'), throwsFormatException);
    });

    test('the tile zoom drops until the area fits in the tile budget', () async {
      final pts = demGrid(const Bounds(0, 0, 20000, 20000), 500, geo);
      final zooms = <int>{};
      final zs = await demDownloadTiles(pts, 500, (url) async {
        zooms.add(int.parse(RegExp(r'/(\d+)/\d+/\d+\.png$').firstMatch(url)![1]!));
        return demEncodeTerrarium(Float32List(demTileSize * demTileSize)..fillRange(0, demTileSize * demTileSize, 640));
      }, zoom: 16, maxTiles: 4);
      expect(zooms.single, lessThan(16));
      expect(demTilesFor(pts, zooms.single).length, lessThanOrEqualTo(4));
      expect(demTilesFor(pts, zooms.single + 1).length, greaterThan(4), reason: 'the highest zoom that fits');
      expect(zs.every((z) => z != null && (z - 640).abs() < 0.01), isTrue);
    });
  });

  test('language packs serialise and know when they are empty', () {
    const pack = LanguagePack(strings: {'menu.file': 'Datei'}, tutorial: {'Start tutorial': 'Tutorial starten'});
    final back = LanguagePack.fromJson(pack.toJson());
    expect(back.strings, pack.strings);
    expect(back.tutorial, pack.tutorial);
    expect(back.catalog, isEmpty);
    expect(back.isEmpty, isFalse);
    expect(const LanguagePack().isEmpty, isTrue);
    expect(LanguagePack.fromJson({'strings': 'not a map', 'catalog': {'Coupler': 3}}).isEmpty, isTrue, reason: 'wrong types are dropped');
  });
}
