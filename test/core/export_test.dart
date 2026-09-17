import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/kml.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

final i18n = I18n('pt');

ReportLabels labels(Project p) => ReportLabels(
  t: i18n.call,
  has: i18n.has,
  warning: (w) => i18n.warning(w),
  entityName: (id) {
    final n = p.byId(id)?.name ?? '';
    return n.isEmpty ? id : n;
  },
);

(Project, DesignResults) designedExample() {
  final p = buildExampleProject(i18n.call, lang: 'pt');
  final r = Designer(p, label: (k) => i18n(k)).designAll();
  return (p, r);
}

ProjectExporter exporterFor(Project p, DesignResults? r) => ProjectExporter(project: p, results: r, labels: labels(p), layerNames: {for (final l in p.layers) l.name: i18n.has('layer.${l.name}') ? i18n('layer.${l.name}') : l.name});

/// Parses the xref table of a PDF and checks every offset points at "n 0 obj".
int checkPdf(List<int> bytes) {
  final text = latin1.decode(bytes);
  expect(text, startsWith('%PDF-1.4'));
  expect(text.trimRight(), endsWith('%%EOF'));
  final startxref = int.parse(RegExp(r'startxref\n(\d+)\n%%EOF').firstMatch(text)!.group(1)!);
  expect(text.substring(startxref, startxref + 4), 'xref');
  final count = int.parse(RegExp(r'xref\n0 (\d+)\n').firstMatch(text.substring(startxref))!.group(1)!);
  final entries = RegExp(r'(\d{10}) (\d{5}) ([nf])').allMatches(text.substring(startxref)).toList();
  expect(entries.length, count);
  for (var i = 1; i < count; i++) {
    final off = int.parse(entries[i].group(1)!);
    expect(text.substring(off, off + '$i 0 obj'.length), '$i 0 obj', reason: 'object $i offset');
  }
  final pages = int.parse(RegExp(r'/Count (\d+)').firstMatch(text)!.group(1)!);
  return pages;
}

void main() {
  group('geo', () {
    test('UTM inverse round trip', () {
      // reference eastings/northings from the USGS (Snyder) series
      const ref = [
        (-15.78, -47.93, 23, 186056.581, 8253215.209),
        (38.72, -9.14, 29, 487829.517, 4285714.730),
        (-33.45, -70.66, 19, 345713.154, 6297592.028),
        (51.5, -0.12, 30, 699889.807, 5709362.293),
        (-3.1, -60.02, 20, 831266.906, 9656887.308),
        (0.5, 6.9, 32, 266278.736, 55302.427),
      ];
      for (final (lat, lon, zone, e, n) in ref) {
        final u = latLonToUtm(lat, lon);
        expect(u.zone, zone);
        expect(u.easting, closeTo(e, 0.005));
        expect(u.northing, closeTo(n, 0.005));
        final (lat2, lon2) = utmToLatLon(u.easting, u.northing, u.zone, u.north);
        expect(lat2, closeTo(lat, 1e-8)); // ≈ 1 mm
        expect(lon2, closeTo(lon, 1e-8));
      }
    });

    test('georeference from a lat/lon origin maps (0,0) back to it', () {
      final g = GeoReference.fromLatLonOrigin(-22.9, -47.06);
      final (lat, lon) = g.toLatLon(0, 0);
      expect(lat, closeTo(-22.9, 1e-8));
      expect(lon, closeTo(-47.06, 1e-8));
      expect(g.zone, 23);
      expect(g.north, isFalse);
      // 100 m east ≈ 0.00098° of longitude at 22.9° S
      final (_, lonE) = g.toLatLon(100, 0);
      expect((lonE - lon) * 111320 * 0.9212, closeTo(100, 1));
    });
  });

  group('drawing exporters', () {
    test('geographic formats need a georeference', () {
      final (p, r) = designedExample();
      final ex = exporterFor(p, r);
      expect(() => ex.kml(), throwsA(isA<GeoReferenceMissing>()));
      expect(() => ex.geoJson(), throwsA(isA<GeoReferenceMissing>()));
      expect(ex.dxf(), contains('ENTITIES'));
    });

    test('KML round trip through the reader keeps geometry, layers and elevations', () {
      final (p, r) = designedExample();
      p.meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
      final ex = exporterFor(p, r);
      final kml = ex.kml();
      expect(kml, contains('<Folder><name>Curvas de nível</name>'));
      expect(kml, contains('<Data name="ELEV">'));
      final back = KmlReader.parse(kml, georef: p.meta.georef);
      expect(back.placemarkCount, p.entities.length);
      // contours come back as polylines with their elevation and position (cm accuracy)
      final contours = p.entities.whereType<ContourEntity>().toList();
      final lines = back.document.entities.where((e) => e.type == 'POLYLINE' && e.elevation != null).toList();
      expect(lines.length, greaterThanOrEqualTo(contours.length));
      final c0 = contours.first;
      final match = lines.firstWhere((e) => (e.elevation! - c0.elevation).abs() < 1e-6);
      for (var i = 0; i < c0.points.length; i++) {
        expect(match.points[i].distanceTo(c0.points[i]), lessThan(0.02));
      }
      // areas are polygons, valves are points named after the zone
      final valve = p.entities.whereType<ControlValveEntity>().first;
      final pt = back.document.entities.firstWhere((e) => e.type == 'POINT' && e.name == valve.zoneName);
      expect(pt.points.first.distanceTo(valve.position), lessThan(0.02));
      expect(back.document.entities.where((e) => e.closed).length, greaterThanOrEqualTo(p.entities.whereType<AreaEntity>().length));
      // KMZ contains doc.kml
      final z = ZipDecoder().decodeBytes(ex.kmz());
      expect(z.files.map((f) => f.name), contains('doc.kml'));
      expect(KmlReader.parseKmz(ex.kmz(), georef: p.meta.georef).placemarkCount, p.entities.length);
    });

    test('GeoJSON is a FeatureCollection with closed polygon rings', () {
      final (p, r) = designedExample();
      p.meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
      final j = jsonDecode(exporterFor(p, r).geoJson()) as Map<String, dynamic>;
      expect(j['type'], 'FeatureCollection');
      final feats = (j['features'] as List).cast<Map<String, dynamic>>();
      expect(feats.length, p.entities.length);
      final polys = feats.where((f) => (f['geometry'] as Map)['type'] == 'Polygon').toList();
      expect(polys.map((f) => (f['properties'] as Map)['layer']), contains('Áreas irrigadas'));
      final poly = polys.first;
      final ring = ((poly['geometry'] as Map)['coordinates'] as List).first as List;
      expect(ring.first, ring.last);
      final lon = (ring.first as List)[0] as double;
      expect(lon, closeTo(-47.93, 0.01));
    });

    test('plot scene uses paper-space symbols and print colours', () {
      final (p, r) = designedExample();
      final scene = buildPlotScene(p, results: r, unitsPerMm: 1.0, t: i18n.call);
      expect(scene.items, isNotEmpty);
      expect(scene.layers.keys, contains(Layers.controlValves));
      expect(scene.bounds.isEmpty, isFalse);
      // valve label carries the design result
      final label = scene.items.whereType<PlotText>().firstWhere((t) => t.text.contains('L/h') && t.bold);
      expect(label.heightMm, closeTo(1.8, 1e-9));
      // near-white screen colours are darkened for paper
      expect(printColor(0xFFECEFF1) & 0xFF, lessThan(0x80));
      expect(fitScale(scene.bounds, 400, 260), 1500); // example spans ~410 m
      expect(fitScale(const Bounds(0, 0, 300, 200), 400, 260), 1000);
      expect(fitScale(const Bounds(0, 0, 30, 20), 400, 260), 100);
      expect(niceBarLength(1.0, 40), 50);
    });

    test('SVG has one group per layer and text', () {
      final (p, r) = designedExample();
      final ex = exporterFor(p, r);
      final svg = ex.svg();
      expect(svg, startsWith('<?xml'));
      expect(svg, contains('<svg xmlns="http://www.w3.org/2000/svg"'));
      final scene = ex.scene(const SheetOptions());
      expect('<g id='.allMatches(svg).length, scene.layers.length);
      expect(svg, contains('<text'));
      expect(svg, contains('data-layer="Válvulas de controle"'));
    });

    test('PDF writer: valid xref, WinAnsi text and compression', () {
      final doc = PdfDocument(title: 'Teste');
      final page = doc.addPage(widthPt: 200, heightPt: 100);
      page.text(10, 50, 'Olá – ³', size: 10);
      page.circle(50, 50, 10, fill: true);
      final raw = doc.build(compress: false);
      expect(checkPdf(raw), 1);
      final text = latin1.decode(raw);
      expect(text, contains('(Ol\\341 \\226 \\263) Tj'));
      expect(text, contains('/BaseFont /Helvetica'));
      final zipped = doc.build();
      expect(latin1.decode(zipped), contains('/FlateDecode'));
      expect(zipped.length, lessThan(raw.length + 200));
      expect(PdfPage.textWidth('Hello', 10), closeTo((722 + 556 + 222 + 222 + 556) / 100, 1e-9));
      expect(PdfPage.fit('abcdefghijklmnopqrstuvwxyz', 40, 10), endsWith('…'));
    });

    test('PDF sheet: one page, appended report pages, chosen scale', () {
      final (p, r) = designedExample();
      final ex = exporterFor(p, r);
      final sheet = ex.pdfSheet(const SheetOptions(page: PageSize.a3));
      expect(checkPdf(sheet), 1);
      final withReports = ex.pdfSheet(const SheetOptions(page: PageSize.a4, landscape: false, includeReports: true));
      expect(checkPdf(withReports), greaterThan(1));
      expect(ex.sheetBuilder().sheetScale(const SheetOptions(page: PageSize.a3)), 1500);
      // the materials table widens the side column, so A4 portrait needs the next scale
      expect(ex.sheetBuilder().sheetScale(const SheetOptions(page: PageSize.a4, landscape: false)), 5000);
      expect(ex.sheetBuilder().sheetScale(const SheetOptions(page: PageSize.a4, landscape: false, bomOnSheet: false)), 4000);
      expect(ex.sheetBuilder().sheetScale(const SheetOptions(page: PageSize.a1)), 750);
      expect(ex.sheetBuilder().sheetScale(const SheetOptions(scale: 500)), 500);
      final txt = latin1.decode(ex.pdfSheet(const SheetOptions(scale: 750)));
      expect(txt, contains('/Title (Exemplo pomar)'));
    });
  });

  group('report exporters', () {
    test('tables cover zones, pipes, outlets, mainline, bom and water', () {
      final (p, r) = designedExample();
      final tables = exporterFor(p, r).reportTables();
      expect(tables.map((t) => t.key), containsAll(['zones', 'pipes', 'outlets', 'mainline', 'bom', 'water']));
      final zones = tables.firstWhere((t) => t.key == 'zones');
      expect(zones.rows.length, r.zones.length);
      expect(zones.warn.length, zones.rows.length);
      final bom = tables.firstWhere((t) => t.key == 'bom');
      expect(bom.rows.length, r.bom.length + 4);
      expect(bom.headers.first, 'Categoria');
      // without results only the area-based tables remain (water, crop, schedule)
      final none = exporterFor(p, null).reportTables();
      expect(none.map((t) => t.key), containsAll(['water', 'crop', 'schedule']));
      expect(none.any((t) => t.key == 'zones'), isFalse);
    });

    test('CSV, TXT and XLSX carry the same tables', () {
      final (p, r) = designedExample();
      final ex = exporterFor(p, r);
      final csv = ex.reportCsv();
      expect(csv, startsWith('﻿'));
      expect(csv, contains('LISTA DE MATERIAIS'));
      expect(csv, contains('Categoria;Descrição;Código;Un.;Quantidade'));
      final txt = ex.reportTxt();
      expect(txt, contains('Relatório de dimensionamento hidráulico'));
      expect(txt, contains('RESUMO DAS ZONAS'));
      final xlsx = ex.reportXlsx();
      final z = ZipDecoder().decodeBytes(xlsx);
      final names = z.files.map((f) => f.name).toList();
      expect(names, containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/styles.xml', 'xl/worksheets/sheet1.xml']));
      final tables = ex.reportTables();
      expect(names.where((n) => n.startsWith('xl/worksheets/')).length, tables.length);
      final wb = utf8.decode(z.findFile('xl/workbook.xml')!.content as List<int>);
      expect(wb, contains('name="Resumo das zonas"'));
      final sheet1 = utf8.decode(z.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
      expect(sheet1, contains('<v>'));
      expect(sheet1, contains('<is><t>Zona</t></is>'));
    });

    test('report PDF paginates the tables', () {
      final (p, r) = designedExample();
      final pdf = exporterFor(p, r).reportPdf();
      expect(checkPdf(pdf), greaterThanOrEqualTo(2));
    });
  });

  group('controller', () {
    test('exports every format from the controller and caches tables', () async {
      final c = ProjectController();
      c.setLanguage('pt');
      loadExampleAction(c);
      await c.runDesign();
      expect(c.results, isNotNull);
      final t1 = c.reportTables();
      expect(identical(t1, c.reportTables()), isTrue);
      c.setLanguage('en');
      expect(identical(t1, c.reportTables()), isFalse);
      expect(c.reportTables().first.title, 'Zone summary');
      c.project.meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
      for (final f in DrawingFormat.values) {
        final out = c.exporter().exportDrawing(f);
        expect(f.isBinary ? out is List<int> : out is String, isTrue, reason: f.name);
        expect(f.isBinary ? (out as List<int>).length : (out as String).length, greaterThan(100), reason: f.name);
      }
      for (final f in ReportFormat.values) {
        final out = c.exporter().exportReport(f);
        expect(f.isBinary ? out is List<int> : out is String, isTrue, reason: f.name);
      }
      expect(c.describeError(const GeoReferenceMissing()), 'Project not georeferenced yet');
      expect(c.exportDxf(), contains('LAYER'));
    });
  });
}
