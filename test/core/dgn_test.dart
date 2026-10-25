import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/dgn.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Fixtures (test/fixtures/formats/dgn7_*.dgn): design files written by an
/// independent DGN V7 writer (lines, line strings, a shape, a 150-vertex
/// chain stored as a complex chain, text, a point), the 2D one extended with
/// circles, ellipses, arcs, a cell, a complex shape and rotated text whose
/// decoding an independent reader confirmed.
Uint8List fixture(String name) => File('test/fixtures/formats/$name').readAsBytesSync();

void main() {
  test('a 2D design file: every element kind, levels as layers', () {
    final r = DgnReader.parse(fixture('dgn7_2d_elements.dgn'));
    expect(r.is3d, isFalse);
    expect(r.masterUnit, 'm');
    expect(r.document.unitScale, 1);
    expect(r.cellCount, 1);
    expect(r.warnings, isEmpty);
    final d = r.document;
    expect(d.layers.map((l) => l.name), containsAll(['LEVEL_1', 'LEVEL_2', 'LEVEL_3', 'LEVEL_4', 'LEVEL_5', 'LEVEL_6', 'LEVEL_7', 'LEVEL_8', 'LEVEL_9', 'LEVEL_10', 'LEVEL_11', 'LEVEL_12']));
    List<DxfEntity> on(int level) => d.entities.where((e) => e.layer == 'LEVEL_$level').toList();
    void near(Pt a, Pt b) => expect(a.distanceTo(b), lessThan(1e-6), reason: '$a vs $b');

    final l1 = on(1).single;
    expect(l1.type, 'POLYLINE');
    near(l1.points.first, const Pt(1000, 2000));
    near(l1.points.last, const Pt(1010, 2000));
    expect(on(2).single.points, hasLength(4));
    near(on(2).single.points[3], const Pt(1020, 2012.5));
    final shape = on(3).single;
    expect(shape.closed, isTrue);
    expect(shape.points, hasLength(4));
    // the complex chain is one polyline of all its components' vertices
    final chain = on(4).single;
    expect(chain.points, hasLength(150));
    near(chain.points[149], const Pt(1000 + 149 * 0.5, 2050 + 0.25));
    final text = on(5).single;
    expect(text.type, 'TEXT');
    expect(text.text, 'Bomba 1');
    near(text.points.single, const Pt(1050, 2050));
    final point = on(6).single;
    expect(point.type, 'POINT');
    near(point.points.single, const Pt(1060, 2060));

    // circle and rotated ellipse
    final circle = on(7).firstWhere((e) => e.type == 'CIRCLE');
    near(circle.center!, const Pt(1100, 2100));
    expect(circle.radius, closeTo(5, 1e-9));
    final ellipse = on(7).firstWhere((e) => e.type == 'POLYLINE');
    expect(ellipse.closed, isTrue);
    near(ellipse.points.first, Pt(1120 + 8 * math.cos(math.pi / 6), 2100 + 8 * math.sin(math.pi / 6)));
    // arcs: counter-clockwise from 10° over 120°, and a clockwise one
    final arcs = on(8).where((e) => e.type == 'ARC').toList()..sort((a, b) => a.center!.x.compareTo(b.center!.x));
    expect(arcs, hasLength(2));
    near(arcs[0].center!, const Pt(1100, 2130));
    expect(arcs[0].radius, closeTo(6, 1e-9));
    expect(arcs[0].startAngle, closeTo(10, 1e-6));
    expect(arcs[0].endAngle, closeTo(130, 1e-6));
    expect(arcs[1].radius, closeTo(3, 1e-9));
    expect(arcs[1].startAngle, closeTo(110, 1e-6));
    expect(arcs[1].endAngle, closeTo(200, 1e-6));
    // the cell's components carry its name
    final c1 = on(9).single, c2 = on(10).single;
    expect(c1.type, 'LINE');
    expect(c1.name, 'PUMP1');
    expect(c2.closed, isTrue);
    expect(c2.name, 'PUMP1');
    // the complex shape of two line strings is one closed ring
    final cs = on(11).single;
    expect(cs.closed, isTrue);
    expect(cs.points, hasLength(4));
    near(cs.points[2], const Pt(1210, 2110));
    final rotated = on(12).single;
    expect(rotated.text, 'VALVE A');
    expect(rotated.rotation, closeTo(45, 1e-6));
    expect(rotated.height, closeTo(2.5, 0.01));
  });

  test('a 3D design file: constant Z as the elevation', () {
    final r = DgnReader.parse(fixture('dgn7_3d.dgn'));
    expect(r.is3d, isTrue);
    List<DxfEntity> on(int level) => r.document.entities.where((e) => e.layer == 'LEVEL_$level').toList();
    expect(on(1).single.elevation, closeTo(10, 1e-6));
    expect(on(2).single.elevation, isNull); // a sloping line string
    expect(on(3).single.elevation, closeTo(5, 1e-6));
    expect(on(3).single.closed, isTrue);
    expect(on(4).single.points, hasLength(150));
    expect(on(4).single.elevation, closeTo(20, 1e-6));
    expect(on(5).single.text, 'Bomba 1');
    expect(on(6).single.type, 'POINT');
    expect(on(6).single.elevation, closeTo(8.5, 1e-6));
    expect(on(6).single.points.single.distanceTo(const Pt(1060, 2060)), lessThan(1e-6));
  });

  test('DGN V8 and other files are refused with codes', () {
    final ole = Uint8List(512)..setAll(0, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]);
    expect(() => DgnReader.parse(ole), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dgn_v8_unsupported')));
    expect(() => DgnReader.parse(Uint8List.fromList(List.filled(100, 7))), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'dgn_not_dgn')));
    // a file cut in the middle of an element keeps what came before
    final b = fixture('dgn7_2d_elements.dgn');
    final cut = DgnReader.parse(b.sublist(0, b.length - 40));
    expect(cut.warnings, contains('dgn_truncated'));
    expect(cut.document.entities, isNotEmpty);
  });
}
