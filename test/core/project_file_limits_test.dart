import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/read_report.dart';

/// Save and reopen with every kind of entity and the values a damaged file
/// or a failed calculation leaves: NaN saved as null, empty lists, fields of
/// a newer version (MOD-24). Nothing may stop the file from opening, and
/// what opens must open again the same way.
void main() {
  List<Entity> everyKind() => [
    LineEntity(id: 'e1', a: Pt.zero, b: const Pt(10, 0)),
    PolylineEntity(id: 'e2', points: const [Pt(0, 0), Pt(5, 5), Pt(10, 0)], closed: true),
    CircleEntity(id: 'e3', center: const Pt(3, 4), radius: 2.5),
    ArcEntity(id: 'e4', center: Pt.zero, radius: 5, startRad: 0, sweepRad: math.pi / 2),
    SplineEntity(id: 'e5', points: const [Pt(0, 0), Pt(5, 5), Pt(10, 0)]),
    HatchEntity(id: 'e6', points: const [Pt(0, 0), Pt(10, 0), Pt(10, 10)]),
    SymbolEntity(id: 'e7', position: const Pt(1, 1), kind: SymbolKind.northArrow, mirrored: true),
    TextEntity(id: 'e8', position: const Pt(2, 2), text: 'Olá', rotationDeg: 30),
    DimensionEntity(id: 'e9', a: Pt.zero, b: const Pt(10, 0), offset: 2),
    AngularDimensionEntity(id: 'e10', vertex: Pt.zero, a: const Pt(10, 0), b: const Pt(0, 10)),
    RadialDimensionEntity(id: 'e11', center: Pt.zero, point: const Pt(4, 3)),
    LeaderEntity(id: 'e12', points: const [Pt(0, 0), Pt(5, 5)], text: 'Nota'),
    ImageEntity(id: 'e13', origin: Pt.zero, width: 20, height: 10, data: Uint8List.fromList([1, 2, 3])),
    ContourEntity(id: 'e14', points: const [Pt(0, 0), Pt(10, 1)], elevation: 101.5),
    SpotHeightEntity(id: 'e15', position: const Pt(3, 3), elevation: 99.2),
    PipeEntity(id: 'e16', points: const [Pt(0, 0), Pt(50, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc50'),
    SpraylineEntity(id: 'e17', points: const [Pt(0, 0), Pt(0, 40)], outletSpecId: 'micro', nozzleId: 'm50'),
    TapeEntity(id: 'e18', points: const [Pt(0, 0), Pt(0, 40)], tapeSpecId: 'tape16_10_30'),
    OutletEntity(id: 'e19', position: const Pt(1, 2), outletSpecId: 'rotor', arcDeg: 180),
    ControlValveEntity(id: 'e20', position: const Pt(5, 5), valveSpecId: 'ev50', zoneName: 'Zona X'),
    WaterSupplyEntity(id: 'e21', position: Pt.zero, designHeadM: 30, designFlow: 0.01),
    PumpEntity(id: 'e22', position: const Pt(1, 0), pumpSpecId: 'pump_c5', hourMeter: true, hourMeterCost: 9),
    MiscHydraulicEntity(id: 'e23', position: const Pt(2, 0), valveSpecId: 'filter50'),
    JunctionEntity(id: 'e24', position: const Pt(3, 0), fixedElevation: 100),
    AreaEntity(id: 'e25', points: const [Pt(0, 0), Pt(20, 0), Pt(20, 20)], crop: 'citrus'),
    PivotEntity(id: 'e26', center: const Pt(500, 500), radiusM: 200)..machine.vriZones['e25'] = 6,
    ControllerEntity(id: 'e27', position: const Pt(9, 9), accessories: {'rain': 80}),
    WireEntity(id: 'e28', points: const [Pt(9, 9), Pt(5, 5)]),
    OrdinateDimensionEntity(id: 'e29', point: const Pt(1, 1), leaderEnd: const Pt(3, 3)),
    CommentEntity(id: 'e30', position: const Pt(4, 4), text: 'poço', photo: 'abc'),
    RevisionCloudEntity(id: 'e31', points: const [Pt(0, 0), Pt(5, 0), Pt(5, 5)], revision: 'A'),
    BreaklineEntity(id: 'e32', points: const [Pt(0, 0), Pt(10, 0)], elevations: const [5, double.nan]),
    // 1.6.0 CAD
    BlockRefEntity(id: 'e33', position: const Pt(2, 2), blockName: 'Caixa', rotationDeg: 30, scale: 2, mirrored: true, attributes: {'CODE': 'CX-01'}),
  ];

  test('the samples cover every kind of entity', () {
    expect(everyKind().map((e) => e.type).toSet(), EntityType.values.toSet());
  });

  test('every kind saves and reopens as it was, its unknown fields kept', () {
    final p = Project()..entities.addAll(everyKind());
    p.ensureNextId(Project.nextIdAfter(p.entities));
    for (final e in p.entities) {
      e.extra = {'futureField': e.id};
    }
    final r = ProjectReadReport();
    final back = Project.fromJsonString(p.toJsonString(), report: r);
    expect(r.clean, isTrue, reason: '$r');
    expect(back.toJsonString(), p.toJsonString());
    for (final e in back.entities) {
      expect(e.extra, {'futureField': e.id}, reason: e.type.name);
    }
  });

  test('every number of every entity left unknown (a failed calculation): the file still opens, twice the same', () {
    final p = Project()..entities.addAll(everyKind());
    final j = jsonDecode(p.toJsonString()) as Map<String, dynamic>;
    for (final e in (j['entities'] as List).cast<Map<String, dynamic>>()) {
      for (final k in e.keys.toList()) {
        if (e[k] is num) e[k] = null;
        if (e[k] is List && (e[k] as List).isNotEmpty && (e[k] as List).first is List) {
          // one vertex of every line lost too
          (e[k] as List).first = [null, 0];
        }
      }
    }
    final r = ProjectReadReport();
    final once = Project.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, report: r);
    expect(once.entities.length + r.skippedCount, everyKind().length, reason: 'read or set aside, never lost');
    expect(once.unreadable['entities']?.length ?? 0, r.skipped['entities'] ?? 0);
    expect(r.droppedVertices, greaterThan(0));
    // what was set aside: the items without position or elevation
    for (final raw in once.unreadable['entities'] ?? const []) {
      expect([
        'line',
        'circle',
        'arc',
        'symbol',
        'text',
        'dimension',
        'angularDimension',
        'radialDimension',
        'image',
        'contour',
        'spotHeight',
        'outlet',
        'controlValve',
        'waterSupply',
        'pump',
        'misc',
        'junction',
        'pivot',
        'controller',
        'ordinateDimension',
        'comment',
      ], contains((raw as Map)['type']));
    }
    final text = once.toJsonString();
    final twice = Project.fromJsonString(text);
    expect(twice.toJsonString(), text, reason: 'a second opening changes nothing');
    // and the design runs on what opened
    expect(() => Designer(twice).designAll(), returnsNormally);
  });

  test('empty lists and missing sections open as an empty project', () {
    final empty = Project.fromJson({'format': 'opencadirrigation', 'entities': [], 'layers': [], 'systemFlows': [], 'scenarios': [], 'labelRules': [], 'blocks': []});
    expect(empty.entities, isEmpty);
    expect(empty.layers, isNotEmpty, reason: 'the default layers');
    expect(empty.catalog.pipes, isNotEmpty, reason: 'the default catalogue');
    final odd = Project.fromJson({'format': 'opencadirrigation', 'entities': 'not a list', 'params': 7, 'meta': 'x', 'catalog': 'y'});
    expect(odd.entities, isEmpty);
    expect(odd.catalog.pipes, isNotEmpty);
  });
}
