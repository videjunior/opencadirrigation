import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/cad_drawing.dart';
import 'package:opencadirrigation/core/io/dxf.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/typed_geo.dart';
import 'package:opencadirrigation/core/model/blocks.dart';
import 'package:opencadirrigation/core/model/dim_style.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/layer_states.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/project_compare.dart';
import 'package:opencadirrigation/core/units.dart';

/// The model of the drawing functions of 1.6.0 (CAD+): coordinates of the
/// field typed on the command line, kgf/cm², the dimension style and the
/// layer states kept in the project file, block references with
/// attributes (file, placement, bill of materials, DXF/DWG blocks, library
/// files), the comparison of two copies and the comments of a copy.
void main() {
  group('coordinates of the field (PRD-26)', () {
    const g = GeoReference(zone: 23, north: false, originEasting: 456000, originNorthing: 7654000);

    test('UTM with its zone, with spaces, commas or semicolons; in the project\'s zone', () {
      for (final s in ['23S 456789 7654321', '23S,456789,7654321', 'UTM 23S 456789 7654321', '23s;456789;7654321']) {
        final r = parseTypedGeoPoint(s, g);
        expect(r?.point, const Pt(789, 321), reason: s);
      }
      // decimal commas with spaces as separators
      final dec = parseTypedGeoPoint('23S 456789,5 7654321,25', g)!.point!;
      expect(dec.x, closeTo(789.5, 1e-9));
      expect(dec.y, closeTo(321.25, 1e-9));
      expect(parseTypedGeoPoint('UTM 456789,7654321', g)?.point, const Pt(789, 321));
    });

    test('UTM of another zone goes through latitude and longitude', () {
      final (lat, lon) = utmToLatLon(800000, 7650000, 22, false);
      final (x, y) = g.fromLatLon(lat, lon);
      final p = parseTypedGeoPoint('22S 800000 7650000', g)!.point!;
      expect(p.distanceTo(Pt(x, y)), lessThan(1e-6));
    });

    test('latitude and longitude: the LL prefix, degree marks, hemisphere letters', () {
      final (x, y) = g.fromLatLon(-22.5, -47.1);
      for (final s in ['LL -22.5,-47.1', 'GEO -22.5 -47.1', 'LATLON -22.5;-47.1', '-22.5°, -47.1°', '22.5S 47.1W', "22°30'S 47°06'W"]) {
        final p = parseTypedGeoPoint(s, g)?.point;
        expect(p, isNotNull, reason: s);
        expect(p!.distanceTo(Pt(x, y)), lessThan(1e-3), reason: s);
      }
    });

    test('a plain pair, a distance or an alias is no coordinate of the field; a georeference is needed; nonsense is said so', () {
      for (final s in ['10,20', '-22.5,-47.1', '@5,0', '@10<45', '50', 'L', 'E', 'LL']) {
        expect(parseTypedGeoPoint(s, g), isNull, reason: s);
      }
      expect(parseTypedGeoPoint('23S 456789 7654321', null)?.error, 'cmd.geoNoGeoref');
      expect(parseTypedGeoPoint('LL -22.5,-47.1', null)?.error, 'cmd.geoNoGeoref');
      expect(parseTypedGeoPoint('99S 456789 7654321', g)?.error, 'cmd.geoInvalid');
      expect(parseTypedGeoPoint('LL 123,456', g)?.error, 'cmd.geoInvalid');
    });

    test('a space belongs to the coordinate while it is typed', () {
      for (final s in ['23S', '23S 456789', 'UTM', 'LL', 'GEO -22']) {
        expect(typedGeoWantsSpace(s), isTrue, reason: s);
      }
      for (final s in ['', 'L', 'PL', '10', '@5', '23S 456789 7654321']) {
        expect(typedGeoWantsSpace(s), isFalse, reason: s);
      }
    });
  });

  test('kgf/cm²: 10 m of water, its label, kept in the file', () {
    const u = Units(pressure: PressureUnit.kgfcm2);
    expect(u.pressureFromHead(10), closeTo(1, 1e-12));
    expect(u.pressureToHead(2.5), closeTo(25, 1e-12));
    expect(u.pressureLabel, 'kgf/cm²');
    // 1 kgf/cm² = 98.0665 kPa
    expect(const Units(pressure: PressureUnit.kPa).pressureFromHead(u.pressureToHead(1)), closeTo(98.0665, 1e-9));
    expect(Units.fromJson(u.toJson()).pressure, PressureUnit.kgfcm2);
  });

  test('the dimension style: the default writes nothing, a style is kept in the file and read back', () {
    final p = Project();
    expect(p.dimStyle.isDefault, isTrue);
    expect(p.toJson().containsKey('dimStyle'), isFalse);
    const s = DimStyle(textHeightM: 0.4, arrow: DimArrow.tick, decimals: 1, unit: LengthUnit.cm, showUnit: false);
    p.dimStyle = s;
    final back = Project.fromJson(jsonDecode(p.toJsonString()) as Map<String, dynamic>);
    expect(back.dimStyle.toJson(), s.toJson());
    expect(back.dimStyle.length(12.346, Units.metric), '1234.6');
    expect(const DimStyle().length(12.346, Units.metric), '12.35 m', reason: 'as earlier versions wrote dimensions');
    back.dimStyle = DimStyle.standard;
    expect(back.toJson().containsKey('dimStyle'), isFalse);
    // a damaged value takes the default
    expect(DimStyle.fromJson({'arrow': 'banana', 'dec': 99, 'h': -1}).toJson(), {'dec': 6});
  });

  test('layer states: kept in the file, put back; a layer made later is left alone', () {
    final p = Project();
    final first = p.layers.first, second = p.layers[1];
    first.visible = false;
    second.locked = true;
    p.layerStates = [LayerState.of('sheet A', p)];
    final back = Project.fromJson(jsonDecode(p.toJsonString()) as Map<String, dynamic>);
    expect(back.layerStates.single.name, 'sheet A');
    for (final l in back.layers) {
      l
        ..visible = true
        ..locked = false;
    }
    back.layers.add(Layer(name: 'NEW', color: 0xFF000000));
    expect(back.layerStateNamed('sheet A')!.applyTo(back), 2);
    expect(back.layers.first.visible, isFalse);
    expect(back.layers[1].locked, isTrue);
    expect(back.layers.last.visible, isTrue, reason: 'unknown to the state');
    expect(Project().toJson().containsKey('layerStates'), isFalse);
  });

  group('block references with attributes', () {
    BlockDefinition valveBox() => BlockDefinition.fromEntities(
      'Valve box',
      [
        PolylineEntity(id: 'a', points: const [Pt(0, 0), Pt(2, 0), Pt(2, 1), Pt(0, 1)], closed: true),
        TextEntity(id: 'b', position: const Pt(0, 1.5), text: '{CODE=VB-00}', height: 0.4),
        TextEntity(id: 'c', position: const Pt(0, 2.2), text: '{ PRICE }', height: 0.3),
      ],
      Pt.zero,
      inBom: true,
    );

    test('texts {TAG} become attributes; the definition keeps them in the file', () {
      final d = valveBox();
      expect(d.entities, hasLength(1));
      expect([for (final a in d.attributes) (a.tag, a.defaultValue)], [('CODE', 'VB-00'), ('PRICE', '')]);
      expect(d.canBeReferenced, isTrue);
      final back = BlockDefinition.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(back.attributes.map((a) => a.tag), ['CODE', 'PRICE']);
      expect(back.attributes.first.position, const Pt(0, 1.5));
      expect(back.inBom, isTrue);
      // a block with a hydraulic item is inserted as copies
      expect(BlockDefinition(name: 'x', entities: [OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'm')]).canBeReferenced, isFalse);
    });

    test('a reference draws its block where it is placed, turned, scaled and mirrored, and follows a redefinition', () {
      final p = Project();
      p.blocks.put(valveBox());
      final r = BlockRefEntity(id: 'r', position: const Pt(10, 10), blockName: 'Valve box', rotationDeg: 90, scale: 2, attributes: {'CODE': 'VB-07'});
      p.entities.add(r);
      resolveBlockRefs(p);
      final outline = r.expanded().first as PolylineEntity;
      expect(outline.points[1].distanceTo(const Pt(10, 14)), lessThan(1e-9), reason: '(2, 0) turned 90° and doubled');
      final code = r.expanded().whereType<TextEntity>().single;
      expect(code.text, 'VB-07');
      expect(r.attribute('PRICE'), '');
      expect(r.bounds.contains(const Pt(9, 13)), isTrue);
      expect(r.distanceTo(const Pt(10, 12)), lessThan(1e-9));
      // a mirror reflects the block itself
      final m = r.transformed(Affine.mirror(const Pt(0, 0), const Pt(0, 1)));
      expect(m.mirrored, isTrue);
      expect(m.position, const Pt(-10, 10));
      final mo = m.expanded().first as PolylineEntity;
      final want = [for (final q in outline.points) Pt(-q.x, q.y)];
      for (final q in want) {
        expect(mo.points.any((x) => x.distanceTo(q) < 1e-9), isTrue, reason: '$q');
      }
      // redefined: the reference draws the new block
      p.blocks.put(BlockDefinition(name: 'Valve box', entities: [LineEntity(id: 'l', a: Pt.zero, b: const Pt(5, 0))]));
      resolveBlockRefs(p);
      expect((r.expanded().single as LineEntity).b.distanceTo(const Pt(10, 20)), lessThan(1e-9));
      // a missing block: a small marker, nothing drawn
      p.blocks.remove('Valve box');
      resolveBlockRefs(p);
      expect(r.expanded(), isEmpty);
      expect(r.bounds.width, closeTo(1, 1e-9));
    });

    test('a reference saves and reopens as it was; the samples keep their keys', () {
      final r = BlockRefEntity(id: 'r', position: const Pt(1, 2), blockName: 'B', rotationDeg: 30, scale: 2, mirrored: true, attributes: {'CODE': 'X'});
      final back = Entity.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>) as BlockRefEntity;
      expect(back.toJson(), r.toJson());
      expect(Entity.fromJson({'type': 'blockRef', 'id': 'q', 'p': [0, 0]}).toJson(), {'type': 'blockRef', 'id': 'q', 'layer': Layers.drawing, 'p': [0.0, 0.0], 'block': ''});
      expect(Entity.fromJson({'type': 'blockRef', 'id': 'q', 'p': [0, 0], 'sc': -3}) as BlockRefEntity, isA<BlockRefEntity>().having((x) => x.scale, 'scale', 1));
    });

    test('the bill of materials counts the references of a block marked for it, by code and price', () {
      final p = Project();
      p.blocks.put(valveBox());
      p.blocks.put(BlockDefinition(name: 'North', entities: [LineEntity(id: 'n', a: Pt.zero, b: const Pt(0, 1))]));
      p.entities.addAll([
        BlockRefEntity(id: 'r1', position: Pt.zero, blockName: 'Valve box', attributes: {'CODE': 'VB-01', 'PRICE': '120.5'}),
        BlockRefEntity(id: 'r2', position: const Pt(5, 0), blockName: 'Valve box', attributes: {'CODE': 'VB-01', 'PRICE': '120.5'}),
        BlockRefEntity(id: 'r3', position: const Pt(9, 0), blockName: 'Valve box'),
        BlockRefEntity(id: 'r4', position: const Pt(9, 9), blockName: 'North'),
      ]);
      final lines = blockBomLines(p);
      expect(lines, hasLength(2));
      expect((lines.first.code, lines.first.quantity, lines.first.unitCost), ('VB-01', 2.0, 120.5));
      expect((lines.last.code, lines.last.quantity, lines.last.unitCost), ('VB-00', 1.0, 0.0));
      expect(lines.every((l) => l.category == 'block'), isTrue);
    });

    test('the DXF/DWG keeps the block with its attribute definitions and each reference as an INSERT with its values', () {
      final p = Project();
      p.blocks.put(valveBox());
      p.entities.add(BlockRefEntity(id: 'r', position: const Pt(10, 0), blockName: 'Valve box', attributes: {'CODE': 'VB-09'}));
      final ex = ProjectExporter(project: p, labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w));
      final d = ex.cadDrawing();
      final ins = d.entities.whereType<CadInsert>().single;
      expect(ins.block, 'Valve box');
      expect(ins.position, const Pt(10, 0));
      expect({for (final a in ins.attribs) a.tag: a.value}, {'CODE': 'VB-09', 'PRICE': ''});
      expect(d.block('Valve box')!.attdefs.map((a) => a.tag), ['CODE', 'PRICE']);
      final dxf = ex.dxf();
      expect(dxf, contains('ATTRIB'));
      expect(dxf, contains('VB-09'));
      // read back, the reference draws its outline
      expect(DxfReader.parse(dxf).entities.where((e) => e.type == 'POLYLINE' || e.type == 'LWPOLYLINE'), isNotEmpty);
      // a mirrored reference goes in as what it draws
      final q = Project();
      q.blocks.put(valveBox());
      q.entities.add(BlockRefEntity(id: 'm', position: Pt.zero, blockName: 'Valve box', mirrored: true));
      final mq = ProjectExporter(project: q, labels: ReportLabels(t: (k, [a]) => k, has: (_) => false, warning: (w) => w)).cadDrawing();
      expect(mq.entities.whereType<CadInsert>(), isEmpty);
      expect(mq.entities.whereType<CadPolyline>(), isNotEmpty);
    });

    test('a library file keeps the blocks; a project file gives its library; anything else is refused', () {
      final file = jsonDecode(jsonEncode(blockLibraryToJson([valveBox()])));
      final blocks = blockLibraryFromJson(file);
      expect(blocks.single.name, 'Valve box');
      expect(blocks.single.attributes, hasLength(2));
      final p = Project()..blocks.put(valveBox());
      expect(blockLibraryFromJson(jsonDecode(p.toJsonString())).single.name, 'Valve box');
      expect(() => blockLibraryFromJson({'format': 'other'}), throwsFormatException);
      expect(() => blockLibraryFromJson([1, 2]), throwsFormatException);
    });

    test('formats without blocks get what the references draw', () {
      final p = Project()..blocks.put(valveBox());
      p.entities.addAll([BlockRefEntity(id: 'r', position: Pt.zero, blockName: 'Valve box'), LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 1))]);
      final flat = flattenBlockRefs(p);
      expect(flat.whereType<BlockRefEntity>(), isEmpty);
      expect(flat.whereType<PolylineEntity>(), hasLength(1));
      expect(flat.whereType<TextEntity>().single.text, 'VB-00');
      expect(flat.last.id, 'l');
    });
  });

  group('review without a server (PRD-11)', () {
    Project base() {
      final p = Project();
      p.entities.addAll([
        LineEntity(id: 'e1', a: Pt.zero, b: const Pt(10, 0)),
        PipeEntity(id: 'e2', points: const [Pt(0, 5), Pt(50, 5)], scope: HydraulicScope.zone),
        CommentEntity(id: 'e3', position: const Pt(1, 1), text: 'check the slope'),
      ]);
      p.ensureNextId(4);
      return p;
    }

    test('the items added, removed and changed, the settings and the figures', () {
      final a = base();
      final b = Project.fromJson(a.toJson());
      (b.byId('e1')! as LineEntity).b = const Pt(20, 0);
      b.entities.removeWhere((e) => e.id == 'e2');
      b.entities.add(OutletEntity(id: 'e9', position: const Pt(3, 3), outletSpecId: 'micro'));
      b.params.maxZoneVelocity = 1.2;
      final cmp = compareProjects(a, b);
      expect(cmp.count(ChangeKind.added), 1);
      expect(cmp.count(ChangeKind.removed), 1);
      expect(cmp.count(ChangeKind.changed), 1);
      expect(cmp.of('e1')!.keys, ['b']);
      expect(cmp.of('e2')!.kind, ChangeKind.removed);
      expect(cmp.settings, ['params']);
      final pipes = cmp.figures.firstWhere((f) => f.key == 'pipeLength');
      expect((pipes.before, pipes.after, pipes.differs), (50.0, 0.0, true));
      expect(cmp.figures.firstWhere((f) => f.key == 'outlets').after, 1);
      expect(compareProjects(a, Project.fromJson(a.toJson())).isEmpty, isTrue);
    });

    test('the comments of a returned copy: updated by id, new ones added, the same ones not twice', () {
      final mine = base();
      final copy = Project.fromJson(mine.toJson());
      (copy.byId('e3')! as CommentEntity).resolved = true;
      copy.entities.add(CommentEntity(id: 'e7', position: const Pt(30, 30), text: 'move the valve', author: 'Ana'));
      copy.entities.add(RevisionCloudEntity(id: 'e8', points: const [Pt(0, 0), Pt(5, 0), Pt(5, 5)], revision: 'B'));
      // the original went on meanwhile: e7 is another item here
      mine.entities.add(LineEntity(id: 'e7', a: Pt.zero, b: const Pt(1, 0)));
      final r = mergeReview(mine, copy);
      expect((r.added, r.updated), (2, 1));
      expect((mine.byId('e3')! as CommentEntity).resolved, isTrue);
      expect(mine.entities.whereType<CommentEntity>().where((x) => x.text == 'move the valve'), hasLength(1));
      expect(mine.byId('e7'), isA<LineEntity>(), reason: 'the item of the original keeps its id');
      expect(mine.entities.whereType<RevisionCloudEntity>().single.revision, 'B');
      final again = mergeReview(mine, copy);
      expect(again.isEmpty, isTrue, reason: 'brought once');
      expect(again.unchanged, greaterThan(0));
    });
  });

  test('a degree is a degree: sanity of the bearings helpers used by typed angles', () {
    expect(math.cos(degToRad(60)), closeTo(0.5, 1e-12));
  });
}
