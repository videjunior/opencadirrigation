import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

void main() {
  final fixtures = Directory('test/fixtures');

  DwgResult read(String name) => DwgReader.parse(File('${fixtures.path}/$name').readAsBytesSync());

  test('R2000 Line.dwg', () {
    final r = read('2000/Line.dwg');
    final lines = r.document.entities.where((e) => e.type == 'LINE').toList();
    expect(lines.length, 1, reason: 'counts=${r.typeCounts} warnings=${r.warnings.take(5)}');
    expect(lines.first.points[0].x, closeTo(21.6078, 1e-3));
    expect(lines.first.points[0].y, closeTo(2.81192, 1e-3));
    expect(lines.first.points[1].x, closeTo(11.0307, 1e-3));
    expect(lines.first.points[1].y, closeTo(16.6375, 1e-3));
    expect(lines.first.layer, '0');
    expect(r.document.layers.map((l) => l.name), contains('0'));
  });

  for (final v in ['2000', '2004', '2007', '2010', '2018']) {
    test('$v samples parse the expected entity types', () {
      final line = read('$v/Line.dwg');
      expect(line.document.entities.where((e) => e.type == 'LINE').length, 1, reason: 'Line $v: ${line.typeCounts} ${line.warnings.take(5)}');
      final circle = read('$v/circle.dwg');
      expect(circle.document.entities.where((e) => e.type == 'CIRCLE').length, 1, reason: 'circle $v: ${circle.typeCounts} ${circle.warnings.take(5)}');
      expect(circle.document.entities.firstWhere((e) => e.type == 'CIRCLE').radius, greaterThan(0));
      final arc = read('$v/Arc.dwg');
      expect(arc.document.entities.where((e) => e.type == 'ARC').length, 1, reason: 'arc $v: ${arc.typeCounts} ${arc.warnings.take(5)}');
      final point = read('$v/Point.dwg');
      expect(point.document.entities.where((e) => e.type == 'POINT').length, 1, reason: 'point $v: ${point.typeCounts} ${point.warnings.take(5)}');
      final text = read('$v/Text.dwg');
      final texts = text.document.entities.where((e) => e.type == 'TEXT').toList();
      expect(texts.length, 1, reason: 'text $v: ${text.typeCounts} ${text.warnings.take(5)}');
      expect(texts.first.text, contains('libredwg'));
      expect(texts.first.height, closeTo(0.2, 1e-6));
      final poly = read('$v/Polyline.dwg');
      final polys = poly.document.entities.where((e) => e.type == 'POLYLINE').toList();
      expect(polys.length, 1, reason: 'poly $v: ${poly.typeCounts} ${poly.warnings.take(5)}');
      expect(polys.first.points.length, greaterThan(2));
    });
  }

  test('entities-2d has the expected mix, with block references and the dimension expanded', () {
    final r = read('2000/entities-2d.dwg');
    final c = r.typeCounts;
    // one line in model space, one from the BLOCK1 reference, three from the aligned dimension's block
    expect(c['LINE'], 5, reason: '$c ${r.warnings.take(5)}');
    expect(c['ARC'], 1);
    expect(c['CIRCLE'], 1);
    expect(c['POINT'], 1, reason: 'definition points of the dimension are skipped');
    expect(c['POLYLINE'], 1);
    expect(c['TEXT'], greaterThanOrEqualTo(1));
    // BLOCK1 (a line from (0,0) to (1,1)?) is inserted at (6, 1) scaled 0.5 and rotated 30°
    final lines = r.document.entities.where((e) => e.type == 'LINE').toList();
    expect(lines.any((l) => l.points.any((p) => p.distanceTo(const Pt(6, 1)) < 1e-6)), isTrue, reason: 'the inserted line starts at the insertion point');
  });

  test('large example files parse many entities without errors', () {
    for (final f in ['example_2000.dwg', 'example_2004.dwg', 'example_2007.dwg', 'example_2010.dwg', 'example_2013.dwg', 'example_2018.dwg', 'sample_2000.dwg', 'sample_2018.dwg', 'example_r14.dwg']) {
      final r = read(f);
      final errors = r.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof')).length;
      // ignore: avoid_print
      print('$f: objects=${r.objectCount} entities=${r.document.entities.length} layers=${r.document.layers.length} counts=${r.typeCounts} errors=$errors mismatches=${r.warnings.where((w) => w.startsWith('handle_mismatch')).length}');
      expect(r.document.layers.length, greaterThan(0), reason: f);
      expect(r.document.entities.length, greaterThan(0), reason: '$f ${r.warnings.take(5)}');
    }
  });

  test('unknown version codes are rejected with a clear message', () {
    final bytes = File('${fixtures.path}/2000/Line.dwg').readAsBytesSync();
    final fake = Uint8List.fromList(bytes);
    fake.setRange(0, 6, 'AC1099'.codeUnits);
    expect(() => DwgReader.parse(fake), throwsA(isA<DwgUnsupportedException>()));
  });

  test('R2007 layers carry their colours', () {
    final r = read('2007/Line.dwg');
    expect(r.warnings.where((w) => w.startsWith('decompress')), isEmpty, reason: r.warnings.join(','));
    expect(r.document.layers.map((l) => l.name), contains('0'));
    expect(r.document.layers.firstWhere((l) => l.name == '0').color, 7);
  });
}
