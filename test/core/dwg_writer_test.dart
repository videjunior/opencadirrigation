import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/dwg_writer.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

void main() {
  test('CRC-16 matches the checksum AutoCAD wrote in the file header', () {
    final b = File('test/fixtures/example_2000.dwg').readAsBytesSync();
    expect(dwgCrc16(b, 0, 79, 0xC0C1), 0x2347);
  });

  DxfDocument sample() => DxfDocument(layers: [DxfLayer('PIPES', color: 5), DxfLayer('TEXTO', color: 2)], entities: [
    DxfEntity(type: 'LINE', layer: 'PIPES', points: [const Pt(1, 2), const Pt(30.5, -4.25)]),
    DxfEntity(type: 'POLYLINE', layer: 'PIPES', points: [const Pt(0, 0), const Pt(10, 0), const Pt(10, 5), const Pt(0, 5)], closed: true, color: 1),
    DxfEntity(type: 'CIRCLE', layer: '0', center: const Pt(5, 5), radius: 2.5),
    DxfEntity(type: 'ARC', layer: '0', center: const Pt(-3, 1), radius: 4, startAngle: 30, endAngle: 120),
    DxfEntity(type: 'POINT', layer: 'PIPES', points: [const Pt(7, 8)], elevation: 12.5),
    DxfEntity(type: 'TEXT', layer: 'TEXTO', points: [const Pt(2, 3)], text: 'Zona 1 – açude', height: 0.8, rotation: 15),
    DxfEntity(type: 'POLYLINE', layer: 'PIPES', points: [const Pt(1, 1)]), // too short: dropped
  ]);

  List<String> errors(DwgResult r) => r.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof') || w.startsWith('handle_mismatch') || w.startsWith('decompress')).toList();

  test('round trip through DwgReader keeps geometry, layers, colours and text', () {
    final bytes = DwgWriter.write(sample(), now: DateTime.utc(2026, 9, 16, 12));
    expect(String.fromCharCodes(bytes.sublist(0, 6)), 'AC1015');
    final r = DwgReader.parse(bytes);
    expect(errors(r), isEmpty, reason: r.warnings.join(','));
    expect(r.typeCounts, {'LINE': 1, 'POLYLINE': 1, 'CIRCLE': 1, 'ARC': 1, 'POINT': 1, 'TEXT': 1});
    expect(r.document.layers.map((l) => l.name).toSet(), {'0', 'PIPES', 'TEXTO'});
    expect(r.document.layers.firstWhere((l) => l.name == 'PIPES').color, 5);
    expect(r.document.layers.firstWhere((l) => l.name == 'TEXTO').color, 2);
    final e = r.document.entities;
    final line = e.firstWhere((x) => x.type == 'LINE');
    expect(line.layer, 'PIPES');
    expect(line.points[0].x, closeTo(1, 1e-9));
    expect(line.points[1].x, closeTo(30.5, 1e-9));
    expect(line.points[1].y, closeTo(-4.25, 1e-9));
    final poly = e.firstWhere((x) => x.type == 'POLYLINE');
    expect(poly.closed, isTrue);
    expect(poly.points.length, 4);
    expect(poly.points[2].x, closeTo(10, 1e-9));
    expect(poly.points[2].y, closeTo(5, 1e-9));
    expect(poly.color, 1);
    final circle = e.firstWhere((x) => x.type == 'CIRCLE');
    expect(circle.center!.x, closeTo(5, 1e-9));
    expect(circle.radius, closeTo(2.5, 1e-9));
    expect(circle.layer, '0');
    final arc = e.firstWhere((x) => x.type == 'ARC');
    expect(arc.radius, closeTo(4, 1e-9));
    expect(arc.startAngle, closeTo(30, 1e-6));
    expect(arc.endAngle, closeTo(120, 1e-6));
    final point = e.firstWhere((x) => x.type == 'POINT');
    expect(point.points.first.y, closeTo(8, 1e-9));
    expect(point.elevation, closeTo(12.5, 1e-9));
    final text = e.firstWhere((x) => x.type == 'TEXT');
    expect(text.text, 'Zona 1 – açude');
    expect(text.height, closeTo(0.8, 1e-9));
    expect(text.rotation, closeTo(15, 1e-6));
    expect(text.layer, 'TEXTO');
  });

  test('the example project exports as a DWG that reads back', () {
    final c = ProjectController();
    loadExampleAction(c);
    final doc = c.exporter().dxfDocument();
    final bytes = c.exporter().exportDrawing(DrawingFormat.dwg) as Uint8List;
    final r = DwgReader.parse(bytes);
    expect(errors(r), isEmpty, reason: r.warnings.take(10).join(','));
    expect(r.document.entities.length, greaterThan(20));
    expect(r.document.entities.length, doc.entities.where((e) => e.type == 'TEXT' ? e.text.isNotEmpty : (e.type == 'CIRCLE' || e.type == 'ARC' ? e.radius > 0 : e.points.length >= (e.type == 'POINT' ? 1 : 2))).length);
    expect(r.document.layers.map((l) => l.name), containsAll(doc.layers.map((l) => l.name)));
  });

  test('LibreDWG accepts the file (skipped when dwgread is not installed)', () async {
    final which = await Process.run('which', ['dwgread']);
    if (which.exitCode != 0) {
      markTestSkipped('dwgread not installed');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('oci_dwg');
    final f = File('${dir.path}/sample.dwg')..writeAsBytesSync(DwgWriter.write(sample()));
    final read = await Process.run('dwgread', ['-v2', f.path]);
    expect(read.exitCode, 0, reason: read.stderr.toString());
    final log = '${read.stdout}${read.stderr}';
    expect(log.contains('ERROR'), isFalse, reason: log.split('\n').where((l) => l.contains('ERROR')).take(5).join('\n'));
    expect(log.contains('check_CRC mismatch'), isFalse);
    expect(log, contains('Add entity LWPOLYLINE'));
    expect(log, contains('Add entity TEXT'));
    final dxf = await Process.run('dwg2dxf', ['-o', '${dir.path}/sample.dxf', f.path]);
    expect(dxf.exitCode, 0, reason: dxf.stderr.toString());
    final out = File('${dir.path}/sample.dxf').readAsStringSync(encoding: latin1);
    for (final t in ['AcDbLine', 'AcDbPolyline', 'AcDbCircle', 'AcDbArc', 'AcDbPoint', 'AcDbText', 'PIPES', 'Zona 1']) {
      expect(out, contains(t));
    }
    // the whole example project (many layers and entities)
    final c = ProjectController();
    loadExampleAction(c);
    final big = File('${dir.path}/example.dwg')..writeAsBytesSync(c.exporter().dwg());
    final readBig = await Process.run('dwgread', ['-v2', big.path]);
    expect(readBig.exitCode, 0, reason: readBig.stderr.toString());
    final logBig = '${readBig.stdout}${readBig.stderr}';
    expect(logBig.contains('ERROR') || logBig.contains('Warning') || logBig.contains('mismatch'), isFalse, reason: logBig.split('\n').where((l) => l.contains('ERROR') || l.contains('Warning') || l.contains('mismatch')).take(5).join('\n'));
    dir.deleteSync(recursive: true);
  });
}
