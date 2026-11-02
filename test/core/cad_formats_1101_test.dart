import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/cad_drawing.dart';
import 'package:opencadirrigation/core/io/codepages.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/dwg_writer.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/dxf_r2000.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// The DXF and DWG readers against the cases of the 1 November 2026 sweep
/// (FMT-02, 05, 08, 10–12, 18–22, 24, 27, 30): files from other programs
/// (LibreDWG), our own writers and small hostile files written here.
final _fixtures = Directory('test/fixtures');
Uint8List _fixture(String name) => File('${_fixtures.path}/$name').readAsBytesSync();

String _pair(int c, Object v) => '$c\n$v\n';
String _entities(String body) => _pair(0, 'SECTION') + _pair(2, 'ENTITIES') + body + _pair(0, 'ENDSEC') + _pair(0, 'EOF');

/// Runs [f] and fails when it takes longer than [ms] milliseconds.
T _fast<T>(T Function() f, {int ms = 5000}) {
  final sw = Stopwatch()..start();
  final r = f();
  expect(sw.elapsedMilliseconds, lessThan(ms), reason: 'took ${sw.elapsedMilliseconds} ms');
  return r;
}

void main() {
  group('DWG units (FMT-02)', () {
    test('the drawing units come from \$INSUNITS in every version from R2000 to R2018', () {
      for (final v in ['2000', '2004', '2007', '2010', '2013', '2018']) {
        final r = DwgReader.parse(_fixture('example_$v.dwg'));
        // LibreDWG reads INSUNITS = 4 (millimetres) in all of them
        expect(r.insunits, 4, reason: v);
        expect(r.document.unitScale, 0.001, reason: v);
        expect(r.document.warnings, isNot(contains('dwg_units_unknown')), reason: v);
      }
      expect(DwgReader.parse(_fixture('formats/client_r2000.dwg')).document.unitScale, 1);
    });

    test('a DWG in millimetres converts like its DXF (written by LibreDWG from client_mm_r2010.dxf)', () {
      final dxf = DxfReader.parse(utf8.decode(_fixture('formats/client_mm_r2010.dxf')));
      final dwg = DwgReader.parse(_fixture('formats/client_mm_r2000.dwg')).document;
      expect(dxf.unitScale, 0.001);
      expect(dwg.unitScale, dxf.unitScale);
      expect(dwg.bounds.width * dwg.unitScale, closeTo(dxf.bounds.width * dxf.unitScale, 1e-6));
    });

    test('R14 has no units in its header: metres, with a note', () {
      final r = DwgReader.parse(_fixture('example_r14.dwg'));
      expect(r.insunits, isNull);
      expect(r.document.unitScale, 1);
      expect(r.document.warnings, contains('dwg_units_unknown'));
    });
  });

  group('DWG layers and annotations (FMT-10, 11, 21)', () {
    test('R2004–R2018 layers keep their colours as R2000 does', () {
      Map<String, int> colours(String f) => {for (final l in DwgReader.parse(_fixture(f)).document.layers) l.name.replaceFirst('*', ''): l.color};
      final r2000 = colours('example_2000.dwg');
      expect(r2000['Tavolo 2'], 2);
      expect(r2000['Tavolo 3'], 4);
      for (final v in ['2004', '2007', '2010', '2013', '2018']) {
        expect(colours('example_$v.dwg'), r2000, reason: v);
      }
    });

    test('a frozen layer comes in hidden', () {
      final layers = DwgReader.parse(_fixture('example_2000.dwg')).document.layers;
      // LibreDWG: flag 1017, frozen
      expect(layers.firstWhere((l) => l.name == 'ADSK_SYSTEM_LIGHTS').visible, isFalse);
      expect(layers.firstWhere((l) => l.name == 'Tavolo 2').visible, isTrue);
    });

    test('LEADER, a visible ATTRIB and the paragraphs of an MTEXT come back from our own DWG', () {
      final d = CadDrawing(
        layers: [const CadLayer('0'), const CadLayer('NOTAS')],
        dimStyles: [CadDimStyle.standard],
        entities: [
          const CadLeader('NOTAS', [Pt(0, 0), Pt(5, 5), Pt(10, 5)], style: 'Standard'),
          const CadMText('NOTAS', Pt(10, 5), 'Linha 1\nLinha 2', 1),
          CadInsert('NOTAS', 'B', const Pt(20, 20), attribs: const [CadAttrib('COTA', '512.35', Pt(21, 20), 1, invisible: false), CadAttrib('ID', 'oculto', Pt(21, 21), 1)]),
        ],
        blocks: [
          CadBlock(
            'B',
            [const CadCircle('0', Pt.zero, 1)],
            attdefs: const [
              CadAttrib('COTA', '0', Pt(1, 0), 1, invisible: false, prompt: 'Cota'),
              CadAttrib('ID', '', Pt(1, 1), 1, prompt: 'Id'),
            ],
          ),
        ],
      );
      final r = DwgReader.parse(DwgWriter.writeDrawing(d));
      final ents = r.document.entities;
      final leader = ents.where((e) => e.type == 'POLYLINE' && e.points.length == 3).single;
      expect(leader.points, const [Pt(0, 0), Pt(5, 5), Pt(10, 5)]);
      final texts = ents.where((e) => e.type == 'TEXT').map((e) => e.text).toList();
      expect(texts, containsAll(['Linha 1\nLinha 2', '512.35']));
      expect(texts, isNot(contains('oculto')), reason: 'invisible attributes are data');
    });

    test('a text longer than 4096 characters is read whole and the next objects stay in step', () {
      final long = List.filled(5000, 'a').join();
      final d = CadDrawing(layers: [const CadLayer('0')], entities: [CadMText('0', Pt.zero, long, 1), const CadLine('0', Pt(0, 0), Pt(1, 1))]);
      final r = DwgReader.parse(DwgWriter.writeDrawing(d));
      expect(r.document.entities.where((e) => e.type == 'TEXT').single.text.length, 5000);
      expect(r.document.entities.where((e) => e.type == 'LINE'), hasLength(1));
      expect(r.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof')), isEmpty);
    });
  });

  group('code pages (FMT-12, 27)', () {
    test('a DXF in ANSI_1251 and an ANSI_1252 one with the characters Latin-1 lacks', () {
      final cyr = DxfReader.parseBytes(_fixture('formats/cp1251_r2000.dxf'));
      expect(cyr.layers.single.name, 'Трубы');
      expect(cyr.entities.firstWhere((e) => e.type == 'TEXT').text, 'Задвижка №1');
      // 0x80 is € and 0x96 – in 1252 (C1 control characters in Latin-1)
      final head = _pair(0, 'SECTION') + _pair(2, 'HEADER') + _pair(9, r'$ACADVER') + _pair(1, 'AC1015') + _pair(9, r'$DWGCODEPAGE') + _pair(3, 'ANSI_1252') + _pair(0, 'ENDSEC');
      final body = '${head}0\nSECTION\n2\nENTITIES\n0\nTEXT\n8\n0\n10\n0\n20\n0\n40\n1\n1\nR\$ 10 \u20AC \u2013 ok\n0\nENDSEC\n0\nEOF\n';
      final bytes = encodeCp1252(body);
      expect(bytes.contains(0x80), isTrue);
      expect(DxfReader.parseBytes(bytes).entities.single.text, 'R\$ 10 € – ok');
    });

    test('an East Asian code page is read as 1252 and said', () {
      final head = _pair(0, 'SECTION') + _pair(2, 'HEADER') + _pair(9, r'$DWGCODEPAGE') + _pair(3, 'ANSI_936') + _pair(0, 'ENDSEC');
      final bytes = Uint8List.fromList([...latin1.encode('$head${_pair(0, 'SECTION')}${_pair(2, 'ENTITIES')}0\nTEXT\n8\n0\n10\n0\n20\n0\n1\n'), 0xC4, 0xE3, ...latin1.encode('\n0\nENDSEC\n0\nEOF\n')]);
      final doc = DxfReader.parseBytes(bytes);
      expect(doc.warnings, contains('dxf_codepage_unsupported:ANSI_936'));
      expect(doc.entities.single.type, 'TEXT');
    });

    test('a DWG R2000 in ANSI_1251 (written by LibreDWG) reads its Cyrillic names and texts', () {
      final r = DwgReader.parse(_fixture('formats/cp1251_r2000.dwg'));
      expect(r.document.layers.map((l) => l.name), contains('Трубы'));
      expect(r.document.entities.firstWhere((e) => e.type == 'TEXT').text, 'Задвижка №1');
    });

    test('layer names with \\U+XXXX come back with their accents (our own DXF round trip)', () {
      final d = CadDrawing(layers: [const CadLayer('0'), const CadLayer('Tubulação')], entities: [const CadLine('Tubulação', Pt(0, 0), Pt(10, 0))]);
      final doc = DxfReader.parse(DxfR2000Writer.write(d));
      expect(doc.layers.map((l) => l.name), contains('Tubulação'));
      expect(doc.entities.single.layer, 'Tubulação');
      final dwg = DwgReader.parse(DwgWriter.writeDrawing(d)).document;
      expect(dwg.layers.map((l) => l.name), contains('Tubulação'));
    });
  });

  group('hostile and damaged files (FMT-05, 18, 19)', () {
    String selfInserting(int n) {
      final b = StringBuffer(_pair(0, 'SECTION') + _pair(2, 'BLOCKS'));
      b.write(_pair(0, 'BLOCK') + _pair(2, 'A') + _pair(10, 0) + _pair(20, 0));
      b.write(_pair(0, 'LINE') + _pair(8, '0') + _pair(10, 0) + _pair(20, 0) + _pair(11, 1) + _pair(21, 1));
      for (var i = 0; i < n; i++) {
        b.write(_pair(0, 'INSERT') + _pair(8, '0') + _pair(2, 'A') + _pair(10, i) + _pair(20, 0));
      }
      b.write(_pair(0, 'ENDBLK') + _pair(0, 'ENDSEC'));
      b.write(_entities(_pair(0, 'INSERT') + _pair(8, '0') + _pair(2, 'A') + _pair(10, 0) + _pair(20, 0)));
      return b.toString();
    }

    test('a block that inserts itself is drawn once, with a note', () {
      final doc = _fast(() => DxfReader.parse(selfInserting(10)));
      expect(doc.entities, hasLength(1));
      expect(doc.warnings, contains('dxf_block_cycle:A'));
    });

    test('blocks nested to explode exponentially stop at the limit', () {
      // B inserts A ten times, C inserts B ten times… seven levels: 10^7 lines
      final b = StringBuffer(_pair(0, 'SECTION') + _pair(2, 'BLOCKS'));
      b.write(_pair(0, 'BLOCK') + _pair(2, 'L0') + _pair(0, 'LINE') + _pair(8, '0') + _pair(10, 0) + _pair(20, 0) + _pair(11, 1) + _pair(21, 1) + _pair(0, 'ENDBLK'));
      for (var level = 1; level <= 7; level++) {
        b.write(_pair(0, 'BLOCK') + _pair(2, 'L$level'));
        for (var i = 0; i < 10; i++) {
          b.write(_pair(0, 'INSERT') + _pair(8, '0') + _pair(2, 'L${level - 1}') + _pair(10, i) + _pair(20, 0));
        }
        b.write(_pair(0, 'ENDBLK'));
      }
      b.write(_pair(0, 'ENDSEC'));
      b.write(_entities(_pair(0, 'INSERT') + _pair(8, '0') + _pair(2, 'L7') + _pair(10, 0) + _pair(20, 0)));
      final doc = _fast(() => DxfReader.parse(b.toString()), ms: 20000);
      expect(doc.entities.length, lessThanOrEqualTo(DxfReader.maxEntities));
      expect(doc.warnings, contains('dxf_blocks_truncated'));
    });

    test('a MINSERT of 3000 × 3000 cells is capped', () {
      final s =
          _pair(0, 'SECTION') +
          _pair(2, 'BLOCKS') +
          _pair(0, 'BLOCK') +
          _pair(2, 'A') +
          _pair(0, 'LINE') +
          _pair(8, '0') +
          _pair(10, 0) +
          _pair(20, 0) +
          _pair(11, 1) +
          _pair(21, 1) +
          _pair(0, 'ENDBLK') +
          _pair(0, 'ENDSEC') +
          _entities(_pair(0, 'INSERT') + _pair(8, '0') + _pair(2, 'A') + _pair(10, 0) + _pair(20, 0) + _pair(70, 3000) + _pair(71, 3000) + _pair(44, 1) + _pair(45, 1));
      final doc = _fast(() => DxfReader.parse(s), ms: 20000);
      expect(doc.entities.length, allOf(lessThanOrEqualTo(DxfReader.maxCells), greaterThan(DxfReader.maxCells * 0.99)));
      expect(doc.warnings, contains('dxf_blocks_truncated'));
    });

    test('an ellipse, a hatch arc and an arc with absurd angles sweep one turn at most', () {
      final ellipse = DxfReader.parse(_entities(_pair(0, 'ELLIPSE') + _pair(8, '0') + _pair(10, 0) + _pair(20, 0) + _pair(11, 10) + _pair(21, 0) + _pair(40, 0.5) + _pair(41, 0) + _pair(42, 1e7)));
      expect(ellipse.entities.single.points.length, lessThan(80));
      final hatch = DxfReader.parse(
        _entities(
          _pair(0, 'HATCH') +
              _pair(8, '0') +
              _pair(70, 1) +
              _pair(91, 1) +
              _pair(92, 0) +
              _pair(93, 1) +
              _pair(72, 2) +
              _pair(10, 0) +
              _pair(20, 0) +
              _pair(40, 5) +
              _pair(50, 0) +
              _pair(51, 1e8) +
              _pair(73, 1),
        ),
      );
      expect(hatch.entities.single.points.length, lessThan(80));
      final arc = DxfReader.parse(_entities(_pair(0, 'ARC') + _pair(8, '0') + _pair(10, 0) + _pair(20, 0) + _pair(40, 1) + _pair(50, 10) + _pair(51, 1e9 + 20)));
      final a = arc.entities.single;
      expect(a.startAngle, inInclusiveRange(0, 360));
      expect(a.endAngle, inInclusiveRange(0, 360));
      // a spline whose degree says a billion
      final spline = _fast(() => DxfReader.parse(_entities('${_pair(0, 'SPLINE')}${_pair(8, '0')}${_pair(71, 1000000000)}${[for (var i = 0; i < 6; i++) _pair(10, i) + _pair(20, i * i)].join()}')));
      expect(spline.entities.single.points.length, lessThan(1000));
    });

    test('a text broken over two lines costs that line only, and is said', () {
      String line(double y) => _pair(0, 'LINE') + _pair(8, '0') + _pair(10, 0) + _pair(20, y) + _pair(11, 10) + _pair(21, y);
      final text = '0\nTEXT\n8\n0\n10\n0\n20\n50\n40\n1\n1\nNota da linha 1\nlinha 2\n';
      final doc = DxfReader.parse(_entities(line(0) + text + line(10) + line(20) + line(30)));
      expect(doc.entities.where((e) => e.type == 'LINE'), hasLength(4));
      expect(doc.entities.where((e) => e.type == 'TEXT').single.text, 'Nota da linha 1');
      expect(doc.warnings, contains('dxf_resync:1'));
    });
  });

  group('what the DXF holds besides the plan (FMT-08, 20)', () {
    test('paper space is left out', () {
      final b = StringBuffer(_pair(0, 'SECTION') + _pair(2, 'BLOCKS'));
      b.write(_pair(0, 'BLOCK') + _pair(8, '0') + _pair(2, '*Paper_Space0') + _pair(70, 0) + _pair(10, 0) + _pair(20, 0));
      b.write(_pair(0, 'LINE') + _pair(67, 1) + _pair(8, 'CARIMBO') + _pair(10, 0) + _pair(20, 0) + _pair(11, 841) + _pair(21, 0));
      b.write(_pair(0, 'ENDBLK') + _pair(0, 'ENDSEC'));
      b.write(
        _entities(
          _pair(0, 'LINE') +
              _pair(8, 'LOTE') +
              _pair(10, 700000) +
              _pair(20, 7500000) +
              _pair(11, 700100) +
              _pair(21, 7500100) +
              _pair(0, 'LINE') +
              _pair(67, 1) +
              _pair(8, 'CARIMBO') +
              _pair(10, 0) +
              _pair(20, 0) +
              _pair(11, 841) +
              _pair(21, 594) +
              _pair(0, 'TEXT') +
              _pair(67, 1) +
              _pair(8, 'CARIMBO') +
              _pair(10, 700) +
              _pair(20, 20) +
              _pair(40, 3) +
              _pair(1, 'PRANCHA 01/03') +
              _pair(0, 'VIEWPORT') +
              _pair(67, 1) +
              _pair(8, '0') +
              _pair(10, 420) +
              _pair(20, 297),
        ),
      );
      final doc = DxfReader.parse(b.toString());
      expect(doc.entities.map((e) => e.layer), ['LOTE']);
      expect(doc.bounds.minX, 700000);
      // the viewport is no drawing: two entities of the layout and the other layout's line
      expect(doc.warnings, contains('dxf_paper_space:3'));
    });

    test('a survey TIN of 3D faces gives its points once, as elevations; a flat face its outline', () {
      String face(List<(double, double, double)> c) =>
          _pair(0, '3DFACE') + _pair(8, 'TIN') + [for (var k = 0; k < 4; k++) _pair(10 + k, c[k % c.length].$1) + _pair(20 + k, c[k % c.length].$2) + _pair(30 + k, c[k % c.length].$3)].join();
      final doc = DxfReader.parse(
        _entities(
          face([(0, 0, 100), (10, 0, 101), (0, 10, 102), (0, 10, 102)]) + face([(10, 0, 101), (10, 10, 103), (0, 10, 102), (0, 10, 102)]) + face([(50, 50, 0), (60, 50, 0), (60, 60, 0), (50, 60, 0)]),
        ),
      );
      final pts = doc.entities.where((e) => e.type == 'POINT').toList();
      expect(pts.map((e) => e.elevation), unorderedEquals([100, 101, 102, 103]));
      expect(doc.entities.where((e) => e.type == 'POLYLINE' && e.closed).single.points, hasLength(4));
    });

    test('a MULTILEADER gives its text and leader line; MLINE its reference line; unknown types are listed', () {
      const ml =
          '0\nMULTILEADER\n8\nNOTAS\n300\nCONTEXT_DATA{\n40\n1.0\n10\n10\n20\n5\n30\n0\n41\n2.0\n290\n1\n304\nVálvula 3\n12\n10\n22\n5\n32\n0\n13\n1\n23\n0\n33\n0\n171\n7\n302\nLEADER{\n290\n1\n10\n9\n20\n5\n30\n0\n11\n1\n21\n0\n31\n0\n40\n1.0\n304\nLEADER_LINE{\n10\n0\n20\n0\n30\n0\n91\n0\n305\n}\n303\n}\n301\n}\n';
      const mline = '0\nMLINE\n8\nMUROS\n70\n0\n71\n1\n72\n3\n10\n0\n20\n0\n30\n0\n11\n0\n21\n0\n31\n0\n11\n10\n21\n0\n31\n0\n11\n10\n21\n10\n31\n0\n';
      const solid = '0\n3DSOLID\n8\n0\n0\nIMAGE\n8\n0\n0\nIMAGE\n8\n0\n';
      final doc = DxfReader.parse(_entities(ml + mline + solid));
      final text = doc.entities.where((e) => e.type == 'TEXT').single;
      expect(text.text, 'Válvula 3');
      // attachment 7 (bottom left): the text starts at its location
      expect(text.points.single, const Pt(10, 5));
      expect(text.height, 2);
      final leader = doc.entities.where((e) => e.type == 'POLYLINE' && e.layer == 'NOTAS').single;
      expect(leader.points, const [Pt(0, 0), Pt(9, 5), Pt(10, 5)]);
      expect(doc.entities.where((e) => e.layer == 'MUROS').single.points, const [Pt(0, 0), Pt(10, 0), Pt(10, 10)]);
      expect(doc.warnings, contains('dxf_unsupported:3DSOLID, IMAGE ×2'));
    });

    test('a reference to an external drawing is said', () {
      final s =
          '${_pair(0, 'SECTION')}${_pair(2, 'BLOCKS')}${_pair(0, 'BLOCK')}${_pair(2, 'LEVANTAMENTO')}${_pair(70, 4)}${_pair(1, r'C:\obra\levantamento.dwg')}${_pair(0, 'ENDBLK')}${_pair(0, 'ENDSEC')}${_entities(_pair(0, 'INSERT') + _pair(8, '0') + _pair(2, 'LEVANTAMENTO') + _pair(10, 0) + _pair(20, 0))}';
      expect(DxfReader.parse(s).warnings, contains('dxf_xref_missing:LEVANTAMENTO'));
    });

    test('points at Z = 0 of a flat layer have no elevation; a survey layer keeps its zeros', () {
      final doc = DxfReader.parse(
        _entities(
          _pair(0, 'POINT') +
              _pair(8, 'POCOS') +
              _pair(10, 1) +
              _pair(20, 1) +
              _pair(30, 0) +
              _pair(0, 'POINT') +
              _pair(8, 'COTAS') +
              _pair(10, 2) +
              _pair(20, 2) +
              _pair(30, 0) +
              _pair(0, 'POINT') +
              _pair(8, 'COTAS') +
              _pair(10, 3) +
              _pair(20, 3) +
              _pair(30, 1.5),
        ),
      );
      expect(doc.entities.firstWhere((e) => e.layer == 'POCOS').elevation, isNull);
      expect(doc.entities.where((e) => e.layer == 'COTAS').map((e) => e.elevation), [0, 1.5]);
    });
  });

  group('texts (FMT-21)', () {
    test('MTEXT paragraphs become line breaks', () {
      expect(DxfReader.plainMText(r'Linha 1\PLinha 2\P  {\fArial|b0;Linha 3}'), 'Linha 1\nLinha 2\nLinha 3');
    });

    test('a right-justified TEXT ends at its alignment point; an MTEXT hangs from a top attachment', () {
      final doc = DxfReader.parse(
        _entities(
          _pair(0, 'TEXT') +
              _pair(8, '0') +
              _pair(10, 0) +
              _pair(20, 0) +
              _pair(11, 100) +
              _pair(21, 50) +
              _pair(40, 2) +
              _pair(72, 2) +
              _pair(1, 'ABCDE') +
              _pair(0, 'MTEXT') +
              _pair(8, '0') +
              _pair(10, 10) +
              _pair(20, 20) +
              _pair(40, 1) +
              _pair(71, 1) +
              _pair(1, 'um\\Pdois'),
        ),
      );
      final right = doc.entities.firstWhere((e) => e.text == 'ABCDE');
      // 5 characters of 0.6 × 2: the text starts 6 units before its end
      expect(right.points.single.x, closeTo(100 - 6, 1e-9));
      expect(right.points.single.y, closeTo(50, 1e-9));
      final m = doc.entities.firstWhere((e) => e.text == 'um\ndois');
      // two lines of 1.2 below the top-left corner
      expect(m.points.single.y, closeTo(20 - 2.4, 1e-9));
    });
  });

  group('DXF R12 export (FMT-30)', () {
    test('code page 1252 with its header, R12 layer names, no \$INSUNITS', () {
      final doc = DxfDocument(
        layers: [DxfLayer('Válvulas 1/2', color: 1), DxfLayer('válvulas 1:2', color: 2)],
        entities: [
          DxfEntity(type: 'TEXT', layer: 'Válvulas 1/2', points: [Pt.zero], text: 'Válvula 3 – 45° ☺'),
          DxfEntity(type: 'LINE', layer: 'válvulas 1:2', points: [Pt.zero, const Pt(1, 1)]),
        ],
      );
      final bytes = DxfWriter.writeBytes(doc);
      final text = latin1.decode(bytes);
      expect(text, contains(r'$DWGCODEPAGE'));
      expect(text, contains('ANSI_1252'));
      expect(text, isNot(contains(r'$INSUNITS')));
      // "á" and "°" are single bytes of 1252; the smiley is not in the page
      expect(bytes, containsAllInOrder([0x56, 0xE1, 0x6C]));
      expect(text, contains('45\u00B0 ?'));
      final back = DxfReader.parseBytes(bytes);
      expect(back.layers.map((l) => l.name), ['VALVULAS_1_2', 'VALVULAS_1_2_2']);
      expect(back.entities.first.layer, 'VALVULAS_1_2');
      expect(back.entities.last.layer, 'VALVULAS_1_2_2');
      expect(back.entities.first.text, 'Válvula 3 – 45° ?');
    });
  });
}
