import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/cad_drawing.dart';
import 'package:opencadirrigation/core/io/cad_export.dart';
import 'package:opencadirrigation/core/io/dwg.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/blocks.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

import '../support/external_tools.dart';

/// The AutoCAD 2000 exports with native entities (DXF and DWG, see
/// `cad_export.dart`, `dxf_r2000.dart`, `dwg_writer.dart`): the file
/// structure, every entity type, the round trip through our readers, the
/// gallery examples, the R12 option, and LibreDWG when it is installed. The
/// files go to build/cad_export for checks with other programs (ezdxf).

/// A drawing with every entity type the exports know.
Project everything() {
  final p = Project();
  p.entities.addAll([
    LineEntity(id: 'l', a: const Pt(1, 2), b: const Pt(30.5, -4.25)),
    PolylineEntity(id: 'pl', points: const [Pt(0, 0), Pt(10, 0), Pt(10, 5)], closed: true),
    CircleEntity(id: 'c', center: const Pt(5, 5), radius: 2.5),
    ArcEntity(id: 'arc', center: Pt.zero, radius: 5, startRad: 0, sweepRad: math.pi / 2),
    ArcEntity(id: 'cw', center: const Pt(20, 0), radius: 3, startRad: math.pi / 2, sweepRad: -math.pi / 2),
    SplineEntity(id: 'spl', points: const [Pt(0, 0), Pt(5, 5), Pt(10, 0), Pt(15, 4)]),
    SplineEntity(id: 'spc', points: const [Pt(30, 0), Pt(35, 5), Pt(40, 0)], closed: true),
    HatchEntity(id: 'hs', points: const [Pt(0, 0), Pt(4, 0), Pt(4, 4)], solid: true),
    HatchEntity(id: 'hp', points: const [Pt(10, 0), Pt(14, 0), Pt(14, 4)], angleDeg: 30, spacing: 0.5),
    SymbolEntity(id: 'sy', position: const Pt(50, 50), kind: SymbolKind.tree, size: 3, rotationDeg: 20),
    SymbolEntity(id: 'na', position: const Pt(60, 50), kind: SymbolKind.northArrow),
    TextEntity(id: 'tx', position: const Pt(2, 3), text: 'Zona 1 – açude {x} 50% Ж', height: 0.8, rotationDeg: 15),
    TextEntity(id: 'tm', position: const Pt(2, 8), text: 'linha 1\nlinha 2', height: 0.5),
    DimensionEntity(id: 'dim', a: const Pt(0, -5), b: const Pt(10, -5), offset: -2),
    AngularDimensionEntity(id: 'ang', vertex: Pt.zero, a: const Pt(10, 0), b: const Pt(0, 10), radius: 3),
    RadialDimensionEntity(id: 'rad', center: const Pt(30, 30), point: const Pt(33, 34)),
    RadialDimensionEntity(id: 'dia', center: const Pt(40, 30), point: const Pt(42, 30), diameter: true),
    OrdinateDimensionEntity(id: 'od', point: const Pt(10, 5), leaderEnd: const Pt(10, 15)),
    OrdinateDimensionEntity(id: 'oy', point: const Pt(10, 5), leaderEnd: const Pt(20, 5), xAxis: false),
    LeaderEntity(id: 'lea', points: const [Pt(0, 0), Pt(5, 5), Pt(9, 5)], text: 'Nota', height: 1),
    ImageEntity(id: 'img', origin: const Pt(20, 0), width: 10, height: 5, source: 'foto.png'),
    ContourEntity(id: 'ct', points: const [Pt(0, 20), Pt(10, 22), Pt(20, 21)], elevation: 101.5),
    BreaklineEntity(id: 'bl', points: const [Pt(0, 30), Pt(30, 40)], elevations: const [12, double.nan]),
    SpotHeightEntity(id: 'sh', position: const Pt(3, 25), elevation: 100.25),
    CommentEntity(id: 'cm', position: const Pt(5, 5), text: 'conferir cota', author: 'MJ'),
    RevisionCloudEntity(id: 'rc', points: const [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)], revision: 'B', description: 'novo setor'),
    PipeEntity(id: 'pp', points: const [Pt(0, 60), Pt(40, 60)], scope: HydraulicScope.mainline),
    SpraylineEntity(id: 'sl', points: const [Pt(0, 70), Pt(20, 70)], outletSpecId: 'rotor', spacing: 5),
    TapeEntity(id: 'tp', points: const [Pt(0, 80), Pt(30, 80)], tapeSpecId: 'tape'),
    OutletEntity(id: 'o', position: const Pt(5, 90), outletSpecId: 'rotor'),
    ControlValveEntity(id: 'v', position: const Pt(10, 90), zoneName: 'Setor 1'),
    WaterSupplyEntity(id: 'ws', position: const Pt(15, 90), name: 'Poço'),
    PumpEntity(id: 'pu', position: const Pt(20, 90)),
    MiscHydraulicEntity(id: 'mi', position: const Pt(25, 90)),
    JunctionEntity(id: 'j', position: const Pt(30, 90)),
    AreaEntity(id: 'ar', points: const [Pt(0, 100), Pt(20, 100), Pt(20, 120)]),
    PivotEntity(id: 'pv', center: const Pt(200, 200), radiusM: 100, spanLengthM: 40, name: 'Pivô 1'),
    PivotEntity(id: 'ps', center: const Pt(500, 200), radiusM: 100, sectorDeg: 270, spanLengthM: 40),
    ControllerEntity(id: 'k', position: const Pt(40, 90), name: 'K'),
    WireEntity(id: 'w', points: const [Pt(40, 90), Pt(10, 90)]),
  ]);
  return p;
}

ProjectExporter exporterOf(Project p) => ProjectExporter(
  project: p,
  labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w),
);

/// The group code pairs of a DXF text.
List<(int, String)> pairsOf(String dxf) {
  final lines = dxf.split(RegExp(r'\r?\n'));
  return [for (var i = 0; i + 1 < lines.length; i += 2) (int.parse(lines[i].trim()), lines[i + 1])];
}

/// Objects (type and their codes) of one section of a DXF text.
List<(String, Map<int, List<String>>)> objectsOf(String dxf, String section) {
  final pairs = pairsOf(dxf);
  final out = <(String, Map<int, List<String>>)>[];
  var inSection = false;
  for (var i = 0; i < pairs.length; i++) {
    final (c, v) = pairs[i];
    if (c == 0 && v == 'SECTION') {
      inSection = pairs[i + 1].$2 == section;
      continue;
    }
    if (!inSection) continue;
    if (c == 0) {
      if (v == 'ENDSEC') break;
      out.add((v, <int, List<String>>{}));
    } else if (out.isNotEmpty) {
      out.last.$2.putIfAbsent(c, () => []).add(v);
    }
  }
  return out;
}

Map<String, int> countTypes(Iterable<String> types) {
  final m = <String, int>{};
  for (final t in types) {
    m[t] = (m[t] ?? 0) + 1;
  }
  return m;
}

/// What our DWG reader gives for a drawing our DXF reader reads as [dxf]:
/// splines come as their curve (the DWG keeps the control points only) and
/// leaders are not read from DWG.
Map<String, int> dwgCountsFor(Map<String, int> dxf, CadDrawing d) {
  final m = Map.of(dxf);
  final splines = d.entities.whereType<CadSpline>().length + d.blocks.expand((b) => b.entities).whereType<CadSpline>().length;
  final leaders = d.entities.whereType<CadLeader>().length;
  if (splines > 0) {
    m['SPLINE'] = m['SPLINE']! - splines;
    m['POLYLINE'] = (m['POLYLINE'] ?? 0) + splines;
  }
  if (leaders > 0) m['POLYLINE'] = m['POLYLINE']! - leaders;
  m.removeWhere((_, v) => v == 0);
  return m;
}

List<String> readErrors(DwgResult r) => r.warnings.where((w) => w.startsWith('object_error') || w.startsWith('eof') || w.startsWith('handle_mismatch') || w.startsWith('decompress')).toList();

/// dwgread's complaints, without the one LibreDWG 0.14 prints for every
/// R2000 hatch (AutoCAD's own files included).
List<String> libreDwgProblems(String log) =>
    log.split('\n').where((l) => (l.contains('ERROR') || l.contains('Warning') || l.contains('mismatch')) && !l.contains('Skip HATCH common handles')).toList();

void main() {
  final out = Directory('build/cad_export')..createSync(recursive: true);

  group('splines', () {
    for (final closed in [false, true]) {
      test('the Bézier spans reproduce the app\'s curve (${closed ? 'closed' : 'open'})', () {
        const pts = [Pt(0, 0), Pt(5, 5), Pt(10, 0), Pt(15, 4), Pt(18, -3)];
        final s = catmullRomSpline(pts, closed: closed)!;
        final spans = closed ? pts.length : pts.length - 1;
        expect(s.control.length, 3 * spans + 1);
        expect(s.knots.length, s.control.length + 4);
        expect(s.fit, pts);
        expect(s.closed, closed);
        if (closed) expect(s.control.last, s.control.first);
        final app = catmullRom(pts, closed: closed, segments: 8);
        for (var i = 0; i < spans; i++) {
          final b = s.control.sublist(3 * i, 3 * i + 4);
          for (var k = 0; k < 8; k++) {
            final t = k / 8, u = 1 - t;
            final p = b[0] * (u * u * u) + b[1] * (3 * u * u * t) + b[2] * (3 * u * t * t) + b[3] * (t * t * t);
            expect(p.distanceTo(app[i * 8 + k]), lessThan(1e-9), reason: 'span $i at $t');
          }
        }
        // the knots (multiplicity 3 at the joints) make the same curve
        final dense = catmullRom(pts, closed: closed, segments: 64);
        for (final p in nurbsCurve(3, s.control, knots: s.knots, samples: 200)) {
          final d = [for (var i = 1; i < dense.length; i++) distanceToSegment(p, dense[i - 1], dense[i])].reduce(math.min);
          expect(d, lessThan(5e-3), reason: 'chord of the 64 samples per span');
        }
      });
    }

    test('two points make a straight span, repeated points are dropped', () {
      final s = catmullRomSpline(const [Pt(0, 0), Pt(0, 0), Pt(9, 0)])!;
      expect(s.control, [Pt.zero, const Pt(3, 0), const Pt(6, 0), const Pt(9, 0)]);
      expect(s.knots, [0, 0, 0, 0, 9, 9, 9, 9]);
      expect(catmullRomSpline(const [Pt(1, 1)]), isNull);
    });
  });

  group('AutoCAD 2000 DXF', () {
    final p = everything();
    final ex = exporterOf(p);
    final text = ex.dxf();
    File('${out.path}/everything.dxf').writeAsStringSync(text);
    final ents = objectsOf(text, 'ENTITIES');
    final tables = objectsOf(text, 'TABLES');
    final blocks = objectsOf(text, 'BLOCKS');

    test('is an AC1015 file in metres, ASCII, with handles and owners', () {
      final header = pairsOf(text).takeWhile((x) => x != (0, 'ENDSEC')).toList();
      String headerVar(String name) => header[header.indexWhere((x) => x == (9, name)) + 1].$2;
      expect(headerVar(r'$ACADVER'), 'AC1015');
      expect(headerVar(r'$INSUNITS'), '6');
      expect(headerVar(r'$DWGCODEPAGE'), 'ANSI_1252');
      expect(text.codeUnits.every((c) => c < 128), isTrue, reason: 'characters outside ASCII are written as \\U+XXXX');
      for (final section in ['CLASSES', 'TABLES', 'BLOCKS', 'ENTITIES', 'OBJECTS']) {
        expect(text, contains('SECTION\n  2\n$section\n'));
      }
      // every entity has a handle (unique in the file) and an owner
      final handles = [
        for (final s in ['TABLES', 'BLOCKS', 'ENTITIES', 'OBJECTS'])
          for (final (type, codes) in objectsOf(text, s))
            if (type != 'TABLE' && type != 'ENDTAB') ...?(codes[5] ?? codes[105]),
      ];
      expect(handles.toSet().length, handles.length);
      expect(ents.every((e) => e.$2.containsKey(5) && e.$2.containsKey(330)), isTrue);
      expect(int.parse(headerVar(r'$HANDSEED'), radix: 16), greaterThan(handles.map((h) => int.parse(h, radix: 16)).reduce(math.max)));
    });

    test('writes every entity natively', () {
      expect(countTypes(ents.map((e) => e.$1)), {
        'LINE': 3, // line, the two pivot spans
        'LWPOLYLINE': 14, // polyline, rays of the angle, hatch outlines ×2, image, contour, breakline, cloud, pipe, sprayline, tape, area, sector pivot, wire
        'CIRCLE': 3, // circle, comment, full pivot
        'ARC': 2,
        'SPLINE': 2,
        'HATCH': 2,
        'INSERT': 19, // 2 symbols, 4 sprayline outlets, outlet, valve, supply, pump, misc, junction, 2 pivots, 4 towers, controller
        'TEXT': 8,
        'MTEXT': 3,
        'DIMENSION': 6,
        'LEADER': 1,
        'POINT': 2,
        'ATTRIB': 30, // NAME ITEM NOZZLE of 5 outlets, NAME ZONE ITEM of the valve, NAME of supply and junction, NAME ITEM of pump and misc, NAME ZONE of 2 pivots, NAME STATIONS
        'SEQEND': 13, // after the attributes of each reference that has them (not the towers or the symbols)
      });
      Map<int, List<String>> one(String type, bool Function(Map<int, List<String>>) where) => ents.firstWhere((e) => e.$1 == type && where(e.$2)).$2;
      // arcs counter-clockwise: the clockwise one from its end
      final cw = one('ARC', (c) => c[10]!.first == '20.0');
      expect([cw[50]!.first, cw[51]!.first], ['0.0', '90.0']);
      // revision cloud and sector pivot: arcs as bulges
      final cloud = one('LWPOLYLINE', (c) => c[8]!.first == Layers.revisions);
      expect(cloud[42]!.toSet(), {'0.7'}, reason: 'outward arcs on a counter-clockwise ring');
      expect(cloud[70]!.first, '129');
      final sector = one('LWPOLYLINE', (c) => c[8]!.first == Layers.pivots);
      expect(double.parse(sector[42]!.single), closeTo(math.tan(degToRad(270) / 4), 1e-8), reason: 'only the arc has a bulge');
      // contours at their elevation, spot heights and breakline vertices as 3D points
      expect(one('LWPOLYLINE', (c) => c[8]!.first == Layers.contours)[38], ['101.5']);
      expect(ents.where((e) => e.$1 == 'POINT').map((e) => e.$2[30]!.single), unorderedEquals(['100.25', '12.0']));
      // spline by its control points (exact) and fit points
      final spl = one('SPLINE', (c) => c[70]!.first == '8');
      expect(spl[71], ['3']);
      expect(spl[74], ['4']);
      expect(spl[73], ['10']);
      expect(one('SPLINE', (c) => c[70]!.first == '9')[74], ['3'], reason: 'closed: flag 1 and the fit points once');
      // hatches: solid, and ANSI31 turned to 30° and scaled to 0.5 m
      final pattern = one('HATCH', (c) => c[70]!.first == '0');
      expect(pattern[2], ['ANSI31']);
      expect(pattern[52], ['345.0']);
      expect(double.parse(pattern[41]!.single), closeTo(0.5 / 3.175, 1e-8));
      expect(pattern[53], ['30.0']);
      expect(one('HATCH', (c) => c[70]!.first == '1')[2], ['SOLID']);
      // the valve: a reference to its block with the zone and catalogue item, plus a label
      final valve = one('INSERT', (c) => c[2]!.first == CadExport.valveBlock);
      expect(valve[8], [Layers.controlValves]);
      expect(valve[66], ['1']);
      final i = ents.indexWhere((e) => identical(e.$2, valve));
      final attribs = ents.skip(i + 1).takeWhile((e) => e.$1 == 'ATTRIB').toList();
      expect({for (final a in attribs) a.$2[2]!.single: a.$2[1]!.single}, {'NAME': '', 'ZONE': 'Setor 1', 'ITEM': ''});
      expect(attribs.every((a) => a.$2[70]!.single == '1' && a.$2[330]!.single == valve[5]!.single), isTrue, reason: 'invisible, owned by the reference');
      expect(ents[i + 1 + attribs.length].$1, 'SEQEND');
      // symbols: references to one block per kind, scaled and turned
      final tree = one('INSERT', (c) => c[2]!.first == CadExport.symbolBlock(SymbolKind.tree));
      expect(
        [tree[41], tree[50]],
        [
          ['3.0'],
          ['20.0'],
        ],
      );
      // text: accents and symbols in the \U+ notation, multiline text escaped
      expect(one('TEXT', (c) => c[8]!.first == Layers.text)[1], [r'Zona 1 \U+2013 a\U+00E7ude {x} 50% \U+0416']);
      expect(one('MTEXT', (c) => c[8]!.first == Layers.text)[1], [r'linha 1\Plinha 2']);
      // leader with its arrow, note apart
      final leader = one('LEADER', (_) => true);
      expect(leader[76], ['3']);
      expect(leader[71], ['1']);
      expect(one('MTEXT', (c) => c[1]!.first == 'Nota')[71], ['7']);
    });

    test('dimensions are DIMENSION entities with their blocks, measured in the display unit', () {
      final dims = ents.where((e) => e.$1 == 'DIMENSION').map((e) => e.$2).toList();
      expect(dims.map((d) => int.parse(d[70]!.single) & 15), [1, 5, 4, 3, 6, 6]);
      expect(dims.map((d) => d[2]!.single), ['*D1', '*D2', '*D3', '*D4', '*D5', '*D6']);
      expect(dims.first[42], ['10.0']);
      expect(dims.first[13], ['0.0']);
      expect(dims.first[14], ['10.0']);
      expect(dims.first[3], [CadExport.dimStyle]);
      expect(dims[4][1], ['X <>']);
      expect(int.parse(dims[4][70]!.single) & 64, 64, reason: 'X ordinate');
      expect(int.parse(dims[5][70]!.single) & 64, 0);
      // the anonymous blocks: lines, arrowheads, the text, definition points
      final d1 = blocks.skipWhile((b) => !(b.$1 == 'BLOCK' && b.$2[2]!.single == '*D1')).takeWhile((b) => b.$1 != 'ENDBLK').toList();
      expect(d1.first.$2[70], ['1'], reason: 'anonymous');
      expect(countTypes(d1.skip(1).map((e) => e.$1)), {'LINE': 3, 'SOLID': 2, 'MTEXT': 1, 'POINT': 3});
      expect(d1.firstWhere((e) => e.$1 == 'MTEXT').$2[1], ['10.00']);
      expect(d1.where((e) => e.$1 == 'POINT').every((e) => e.$2[8]!.single == 'Defpoints'), isTrue);
      expect(tables.any((t) => t.$1 == 'DIMSTYLE' && t.$2[2]!.single == CadExport.dimStyleHorizontal && t.$2[73]!.single == '1'), isTrue);
      // in feet when the project shows feet
      final us = Project(params: DesignParameters(units: Units.us))..entities.add(DimensionEntity(id: 'd', a: Pt.zero, b: const Pt(10, 0)));
      final usText = exporterOf(us).dxf();
      final style = objectsOf(usText, 'TABLES').firstWhere((t) => t.$1 == 'DIMSTYLE' && t.$2[2]!.single == CadExport.dimStyle).$2;
      expect(double.parse(style[144]!.single), closeTo(1 / 0.3048, 1e-6));
      expect(style[3], ['<> ft']);
      expect(objectsOf(usText, 'BLOCKS').firstWhere((b) => b.$1 == 'MTEXT').$2[1], ['32.81 ft']);
    });

    test('layers keep colour index, true colour, linetype and state; blocks carry attribute definitions', () {
      Map<int, List<String>> layer(String name) => tables.firstWhere((t) => t.$1 == 'LAYER' && t.$2[2]!.single == name).$2;
      final pipes = layer(Layers.zonePipes);
      expect(pipes[420], ['${Layers.defaultColors[Layers.zonePipes]! & 0xFFFFFF}']);
      expect(pipes[62]!.single, isNot('7'));
      expect(layer(Layers.tapes)[6], ['DASHED']);
      expect(layer(Layers.wires)[6], ['DASHED']);
      expect(layer(Layers.zonePipes)[6], ['Continuous']);
      expect(layer('Defpoints')[290], ['0'], reason: 'definition points are not plotted');
      expect(tables.any((t) => t.$1 == 'LTYPE' && t.$2[2]!.single == 'DASHED' && t.$2[49]!.length == 2), isTrue);
      // hidden and locked layers
      final q = everything();
      q.layers.firstWhere((l) => l.name == Layers.areas).visible = false;
      q.layers.firstWhere((l) => l.name == Layers.pivots).locked = true;
      final qt = objectsOf(exporterOf(q).dxf(), 'TABLES');
      final areas = qt.firstWhere((t) => t.$1 == 'LAYER' && t.$2[2]!.single == Layers.areas).$2;
      expect(int.parse(areas[62]!.single), lessThan(0));
      expect(qt.firstWhere((t) => t.$1 == 'LAYER' && t.$2[2]!.single == Layers.pivots).$2[70], ['4']);
      // block definitions: hydraulic blocks with their attribute definitions, symbol glyphs
      final valve = blocks.skipWhile((b) => !(b.$1 == 'BLOCK' && b.$2[2]!.single == CadExport.valveBlock)).takeWhile((b) => b.$1 != 'ENDBLK').toList();
      expect(valve.first.$2[70], ['2'], reason: 'has attribute definitions');
      expect(valve.where((e) => e.$1 == 'ATTDEF').map((e) => e.$2[2]!.single), ['NAME', 'ZONE', 'ITEM']);
      expect(valve.skip(1).where((e) => e.$1 != 'ATTDEF').every((e) => e.$2[8]!.single == '0'), isTrue, reason: 'drawn on layer 0: they take the layer of the reference');
      final tree = blocks.skipWhile((b) => !(b.$1 == 'BLOCK' && b.$2[2]!.single == CadExport.symbolBlock(SymbolKind.tree))).takeWhile((b) => b.$1 != 'ENDBLK').toList();
      expect(countTypes(tree.skip(1).map((e) => e.$1)), {'CIRCLE': 2, 'LWPOLYLINE': 3});
    });

    test('reads back with our reader, and imports as the same drawing entities', () {
      final doc = DxfReader.parse(text);
      expect(doc.unitScale, 1);
      expect(doc.layers.map((l) => l.name), containsAll(p.layers.map((l) => l.name)));
      final types = countTypes(doc.entities.map((e) => e.type));
      // LINE: 3 + 5 of the dimension blocks; POLYLINE: 14 + leader + 16 of blocks (valve, supply, misc, controller, 4 towers, 6 symbol
      // strokes, 2 ordinate leaders); CIRCLE: 3 + 11 of blocks; HATCH: 2 + 7 arrowheads + 15 fills of blocks; TEXT: 12 + 6 dimension
      // values + 3 letters of blocks (invisible attributes are not drawn)
      expect(types, {'LINE': 8, 'POLYLINE': 31, 'CIRCLE': 14, 'ARC': 3, 'SPLINE': 2, 'HATCH': 24, 'TEXT': 20, 'POINT': 2});
      List<DxfEntity> on(String layer) => doc.entities.where((e) => e.layer == layer).toList();
      // the block of an outlet lands on the outlet, on its layer
      final outlet = on(Layers.outlets).firstWhere((e) => e.type == 'CIRCLE' && e.center!.distanceTo(const Pt(5, 90)) < 1e-9);
      expect(outlet.radius, closeTo(0.5, 1e-9));
      expect(on(Layers.outlets).where((e) => e.type == 'CIRCLE' && (e.radius - 0.3).abs() < 1e-9).length, 4, reason: 'sprayline outlets');
      // invisible attributes are not drawn; labels and notes are
      final texts = doc.entities.where((e) => e.type == 'TEXT').map((e) => e.text).toList();
      expect(
        texts,
        containsAll([
          'Zona 1 – açude {x} 50% Ж',
          'linha 1 linha 2',
          'Setor 1',
          'Poço',
          'Nota',
          'MJ: conferir cota',
          'B — novo setor',
          '10.00',
          '90.0°',
          'R5.00',
          'Ø4.00',
          'X 10.00',
          'Y 5.00',
          'P',
          'W',
          'C',
        ]),
      );
      expect(texts, isNot(contains('rotor')));
      final leader = on(Layers.dimensions).firstWhere((e) => e.type == 'POLYLINE' && e.points.length == 3 && e.points.last == const Pt(9, 5));
      expect(leader.points.first, Pt.zero);
      final spline = doc.entities.firstWhere((e) => e.type == 'SPLINE' && !e.closed);
      expect(spline.points, const [Pt(0, 0), Pt(5, 5), Pt(10, 0), Pt(15, 4)]);
      expect(doc.entities.firstWhere((e) => e.type == 'SPLINE' && e.closed).points.length, 3);
      final hatch = on(Layers.hatches).firstWhere((e) => e.type == 'HATCH' && !e.solid);
      expect(hatch.rotation, closeTo(30, 1e-9));
      expect(hatch.height, closeTo(0.5, 1e-7));
      expect(on(Layers.contours).firstWhere((e) => e.type == 'POLYLINE').elevation, 101.5);
      expect(doc.entities.where((e) => e.type == 'POINT').map((e) => e.elevation), unorderedEquals([100.25, 12]));
      // imported into a project, splines, hatches and contours come back as they were
      final c = ProjectController()..newProject();
      c.importDrawing(doc);
      final sp = c.project.entities.whereType<SplineEntity>().toList();
      expect(sp.map((s) => s.points.length), unorderedEquals([4, 3]));
      expect(sp.firstWhere((s) => s.closed).points, const [Pt(30, 0), Pt(35, 5), Pt(40, 0)]);
      final h = c.project.entities.whereType<HatchEntity>().firstWhere((h) => !h.solid);
      expect([h.angleDeg, h.spacing], [closeTo(30, 1e-9), closeTo(0.5, 1e-7)]);
      expect(c.project.entities.whereType<ContourEntity>().single.elevation, 101.5);
      expect(c.project.entities.whereType<BreaklineEntity>().single.points.length, 2);
    });

    test('user blocks of the project become block definitions', () {
      final q = Project();
      q.blocks.put(
        BlockDefinition(
          name: 'Cavalete 1"',
          entities: [
            CircleEntity(id: 'a', center: Pt.zero, radius: 1),
            ControlValveEntity(id: 'b', position: const Pt(2, 0)),
          ],
        ),
      );
      q.entities.add(LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 1)));
      final d = exporterOf(q).cadDrawing();
      final blk = d.block('Cavalete 1_')!;
      expect(blk.entities.map((e) => e.runtimeType), [CadCircle, CadInsert]);
      expect(d.block(CadExport.valveBlock), isNotNull, reason: 'the block it references');
      expect(DxfReader.parse(exporterOf(q).dxf()).entities.length, 1, reason: 'a definition alone draws nothing');
    });
  });

  group('AutoCAD 2000 DWG', () {
    final p = everything();
    final ex = exporterOf(p);
    final bytes = ex.dwg();
    File('${out.path}/everything.dwg').writeAsBytesSync(bytes);

    test('reads back with our reader as the DXF does', () {
      expect(String.fromCharCodes(bytes.sublist(0, 6)), 'AC1015');
      final r = DwgReader.parse(bytes);
      expect(readErrors(r), isEmpty, reason: r.warnings.take(5).join(','));
      final dxf = DxfReader.parse(ex.dxf());
      expect(r.typeCounts, dwgCountsFor(countTypes(dxf.entities.map((e) => e.type)), ex.cadDrawing()));
      expect(r.document.layers.map((l) => l.name).toSet(), dxf.layers.map((l) => l.name).toSet());
      // same geometry (the readers draw arcs of bulges with different steps:
      // hatches are compared by their first point; our DWG reader keeps \U+XXXX)
      String xy(Pt q) => '${q.x.toStringAsFixed(3)},${q.y.toStringAsFixed(3)}';
      Set<String> keys(Iterable<DxfEntity> es) => {
        for (final e in es)
          if (e.type != 'SPLINE' && e.type != 'POLYLINE')
            '${e.type} ${e.layer} ${[...(e.type == 'HATCH' ? e.points.take(1) : e.points), ?e.center].map(xy).join(' ')} ${DxfReader.plainText(e.text)} ${e.radius.toStringAsFixed(3)}',
      };
      expect(keys(r.document.entities), keys(dxf.entities));
      final valve = r.document.entities.where((e) => e.layer == Layers.controlValves && e.type == 'POLYLINE').single;
      expect(valve.points.first, const Pt(9, 89.3));
    });

    test('LibreDWG reads it and converts it to DXF (skipped when it is not installed)', () async {
      if (!await hasTool('dwgread')) return;
      final dir = Directory.systemTemp.createTempSync('oci_cad');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/everything.dwg')..writeAsBytesSync(bytes);
      final read = await Process.run('dwgread', ['-v3', f.path], stdoutEncoding: latin1, stderrEncoding: latin1);
      final log = '${read.stdout}${read.stderr}';
      expect(read.exitCode, 0);
      expect(libreDwgProblems(log), isEmpty);
      for (final type in [
        'LWPOLYLINE',
        'SPLINE',
        'HATCH',
        'INSERT',
        'ATTRIB',
        'ATTDEF',
        'SEQEND',
        'MTEXT',
        'LEADER',
        'DIMENSION_ALIGNED',
        'DIMENSION_ANG3PT',
        'DIMENSION_RADIUS',
        'DIMENSION_DIAMETER',
        'DIMENSION_ORDINATE',
        'SOLID',
      ]) {
        expect(log, contains('Add entity $type'), reason: type);
      }
      expect('Add table record BLOCK_HEADER'.allMatches(log).length, ex.cadDrawing().blocks.length + 2, reason: 'model and paper space and every block');
      final conv = await Process.run('dwg2dxf', ['-y', '-o', '${dir.path}/back.dxf', f.path], stdoutEncoding: latin1, stderrEncoding: latin1);
      expect(conv.exitCode, 0, reason: conv.stderr.toString());
      final back = File('${dir.path}/back.dxf').readAsStringSync(encoding: latin1);
      final types = countTypes(objectsOf(back, 'ENTITIES').map((e) => e.$1));
      final ours = countTypes(objectsOf(ex.dxf(), 'ENTITIES').map((e) => e.$1));
      for (final t in ['LINE', 'LWPOLYLINE', 'CIRCLE', 'ARC', 'SPLINE', 'HATCH', 'INSERT', 'TEXT', 'MTEXT', 'DIMENSION', 'LEADER', 'POINT', 'ATTRIB']) {
        expect(types[t], ours[t], reason: t);
      }
      expect(back, contains('Setor 1'));
      expect(back, contains('OCI_VALVE'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('gallery examples', () {
    for (final id in ExampleId.values) {
      test('${id.name}: native DXF and DWG with one reference per item, reading back alike', () {
        final c = ProjectController();
        loadExampleAction(c, id);
        final ex = c.exporter();
        final p = c.project;
        final text = ex.dxf();
        final bytes = ex.dwg();
        File('${out.path}/${id.name}.dxf').writeAsStringSync(text);
        File('${out.path}/${id.name}.dwg').writeAsBytesSync(bytes);
        final ents = objectsOf(text, 'ENTITIES');
        int inserts(String block) => ents.where((e) => e.$1 == 'INSERT' && e.$2[2]!.single == block).length;
        int count<T>() => p.entities.whereType<T>().length;
        expect(inserts(CadExport.outletBlock), count<OutletEntity>() + p.entities.whereType<SpraylineEntity>().fold(0, (n, s) => n + s.outletCount));
        expect(inserts(CadExport.valveBlock), count<ControlValveEntity>());
        expect(inserts(CadExport.supplyBlock), count<WaterSupplyEntity>());
        expect(inserts(CadExport.pumpBlock), count<PumpEntity>());
        expect(inserts(CadExport.miscBlock), count<MiscHydraulicEntity>());
        expect(inserts(CadExport.junctionBlock), count<JunctionEntity>());
        expect(inserts(CadExport.controllerBlock), count<ControllerEntity>());
        expect(inserts(CadExport.pivotBlock), count<PivotEntity>());
        expect(inserts(CadExport.towerBlock), p.entities.whereType<PivotEntity>().fold(0, (n, v) => n + v.towerPositions().length));
        for (final k in SymbolKind.values) {
          expect(inserts(CadExport.symbolBlock(k)), p.entities.whereType<SymbolEntity>().where((s) => s.kind == k).length, reason: k.name);
        }
        int polylines(String layer) => ents.where((e) => e.$1 == 'LWPOLYLINE' && e.$2[8]!.single == layer).length;
        final pipes = p.entities.whereType<PipeEntity>().where((e) => e.points.length >= 2);
        expect(polylines(Layers.zonePipes) + polylines(Layers.mainlinePipes), pipes.length);
        expect(polylines(Layers.tapes), count<TapeEntity>());
        expect(polylines(Layers.areas), count<AreaEntity>());
        expect(ents.where((e) => e.$1 == 'HATCH').length, count<HatchEntity>());
        expect(ents.where((e) => e.$1 == 'DIMENSION').length, count<DimensionEntity>() + count<AngularDimensionEntity>() + count<RadialDimensionEntity>() + count<OrdinateDimensionEntity>());
        expect(ents.where((e) => e.$1 == 'POINT').length, count<SpotHeightEntity>() + p.entities.whereType<BreaklineEntity>().fold(0, (n, b) => n + b.elevations.where((z) => z.isFinite).length));
        // both readers give the same drawing; the DWG with no errors
        final dxf = DxfReader.parse(text);
        final dwg = DwgReader.parse(bytes);
        expect(readErrors(dwg), isEmpty, reason: dwg.warnings.take(5).join(','));
        expect(dxf.entities, isNotEmpty);
        expect(dwg.typeCounts, dwgCountsFor(countTypes(dxf.entities.map((e) => e.type)), ex.cadDrawing()));
        expect(dwg.document.layers.map((l) => l.name), containsAll(p.layers.map((l) => l.name)));
        // the R12 option still writes the primitives
        final r12 = ex.dxfR12();
        expect(r12, contains('AC1009'));
        expect(r12, isNot(contains('LWPOLYLINE')));
        expect(DxfReader.parse(r12).entities.length, ex.dxfDocument().entities.length);
      });
    }

    test('LibreDWG reads every example DWG (skipped when it is not installed)', () async {
      if (!await hasTool('dwgread')) return;
      final dir = Directory.systemTemp.createTempSync('oci_cad_ex');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (final id in ExampleId.values) {
        final c = ProjectController();
        loadExampleAction(c, id);
        final f = File('${dir.path}/${id.name}.dwg')..writeAsBytesSync(c.exporter().dwg());
        final read = await Process.run('dwgread', ['-v2', f.path], stdoutEncoding: latin1, stderrEncoding: latin1);
        expect(read.exitCode, 0, reason: id.name);
        expect(libreDwgProblems('${read.stdout}${read.stderr}'), isEmpty, reason: id.name);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('R12 option', () {
    test('keeps the primitives of the old export, one text per line and points with their elevation', () {
      final ex = exporterOf(everything());
      final text = ex.dxfR12();
      File('${out.path}/everything_r12.dxf').writeAsStringSync(text);
      expect(text, contains('AC1009'));
      final types = countTypes(objectsOf(text, 'ENTITIES').map((e) => e.$1).where((t) => t != 'VERTEX' && t != 'SEQEND'));
      expect(types.keys.toSet(), {'LINE', 'POLYLINE', 'CIRCLE', 'ARC', 'TEXT', 'POINT'});
      final doc = DxfReader.parse(text);
      final flat = ex.dxfDocument();
      expect(doc.entities.length, flat.entities.length);
      for (var i = 0; i < flat.entities.length; i++) {
        expect(doc.entities[i].type, flat.entities[i].type);
        expect(doc.entities[i].points.length, flat.entities[i].points.length);
      }
      expect(doc.entities.firstWhere((e) => e.type == 'TEXT' && e.text.startsWith('linha')).text, 'linha 1 linha 2');
      expect(doc.entities.where((e) => e.type == 'POINT').map((e) => e.elevation), containsAll([100.25, 12.0]));
      // the clockwise arc, counter-clockwise from its end
      final arc = doc.entities.firstWhere((e) => e.type == 'ARC' && e.center == const Pt(20, 0));
      expect([arc.startAngle, arc.endAngle], [0, 90]);
    });
  });
}
