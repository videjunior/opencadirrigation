import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/read_report.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/core/units.dart';

/// Reads [j] with a fresh report.
(Project, ProjectReadReport) read(Map<String, dynamic> j) {
  final r = ProjectReadReport();
  return (Project.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>, report: r), r);
}

void main() {
  group('a damaged item no longer stops the file from opening (MOD-02)', () {
    test('a NaN coordinate saved as null: the item is set aside and kept, the rest opens', () {
      final p = Project();
      p.entities.add(LineEntity(id: p.newId(), a: const Pt(double.nan, 0), b: const Pt(10, 0)));
      p.entities.add(LineEntity(id: p.newId(), a: Pt.zero, b: const Pt(10, 10)));
      final text = p.toJsonString();
      expect(text, contains('[null,0.0]'));
      final r = ProjectReadReport();
      final back = Project.fromJsonString(text, report: r);
      expect(back.entities.map((e) => e.id), ['e2']);
      expect(r.skipped['entities'], 1);
      expect(r.clean, isFalse);
      expect(r.notes.map((n) => n.code), contains('skipped'));
      // written back under `unreadable` and tried again on every read
      final again = Project.fromJsonString(back.toJsonString());
      expect(again.unreadable['entities'], hasLength(1));
      expect((again.unreadable['entities']!.single as Map)['id'], 'e1');
      expect(again.newId(), 'e3', reason: 'the id of the item set aside stays taken');
    });

    test('vertices without coordinates are dropped from lines and outlines', () {
      final j = Project().toJson();
      j['entities'] = [
        {
          'type': 'polyline',
          'id': 'e1',
          'pts': [
            [0, 0],
            [null, 1],
            [5, 0],
            'x',
            [10, 0],
          ],
        },
      ];
      final (p, r) = read(j);
      expect((p.entities.single as PolylineEntity).points, const [Pt(0, 0), Pt(5, 0), Pt(10, 0)]);
      expect(r.droppedVertices, 2);
    });

    test('an elevation that is not known is never 0 m', () {
      final p = Project();
      p.entities.add(ContourEntity(id: p.newId(), points: const [Pt(0, 0), Pt(10, 0)], elevation: double.nan));
      p.entities.add(SpotHeightEntity(id: p.newId(), position: const Pt(3, 3), elevation: double.nan));
      p.entities.add(SpotHeightEntity(id: p.newId(), position: const Pt(0, 0), elevation: 800));
      final r = ProjectReadReport();
      final back = Project.fromJsonString(p.toJsonString(), report: r);
      expect(back.entities.whereType<ContourEntity>(), isEmpty);
      expect(back.entities.whereType<SpotHeightEntity>().single.elevation, 800);
      expect(r.skipped['entities'], 2);
      expect(back.buildTerrain().elevationAt(const Pt(3, 3)), 800, reason: 'no pit at 0 m');
    });

    test('unknown entity types, missing scope, layer name or id', () {
      final base = Project()..entities.add(LineEntity(id: 'e1', a: Pt.zero, b: const Pt(1, 1)));
      final j = base.toJson();
      j['entities'] = <Object?>[
        ...(j['entities'] as List),
        {'type': 'futureThing', 'id': 'e99', 'layer': 'DRAWING', 'shape': 'hex'},
        {
          'type': 'pipe',
          'id': 'e2',
          'layer': 'MAINLINE_PIPES',
          'pts': [
            [0, 0],
            [1, 0],
          ],
        },
        {
          'type': 'pipe',
          'pts': [
            [0, 5],
            [1, 5],
          ],
        },
        {'type': 'circle', 'id': 'e3', 'p': 'not a point', 'r': 2},
        42,
      ];
      j['layers'] = [
        {'color': 1},
        {'name': 'MINE', 'color': 2},
      ];
      final (p, r) = read(j);
      expect(p.entities.map((e) => e.type), [EntityType.line, EntityType.pipe, EntityType.pipe]);
      final pipes = p.entities.whereType<PipeEntity>().toList();
      expect(pipes.first.scope, HydraulicScope.mainline, reason: 'from its layer');
      expect(pipes.last.scope, HydraulicScope.zone);
      expect(pipes.last.id, isNotEmpty, reason: 'a missing id gets a new one');
      expect(r.renumbered, 1);
      expect(p.layers.map((l) => l.name), ['MINE']);
      expect(r.skipped, {'entities': 3, 'layers': 1});
      // the unknown type comes back when saved and read again, the number is no item
      final again = Project.fromJsonString(p.toJsonString());
      expect([for (final x in again.unreadable['entities']!) (x as Map)['type']], ['futureThing', 'circle']);
      expect(jsonEncode(again.unreadable['entities']!.first), contains('hex'));
    });

    test('repeated ids are renumbered, the first one keeps its id', () {
      final j = Project().toJson();
      j['entities'] = [
        {
          'type': 'spotHeight',
          'id': 'e7',
          'p': [0, 0],
          'z': 10,
        },
        {
          'type': 'spotHeight',
          'id': 'e7',
          'p': [30, 0],
          'z': 11,
        },
        {
          'type': 'spotHeight',
          'id': 'e8',
          'p': [60, 0],
          'z': 12,
        },
      ];
      final (p, r) = read(j);
      expect(p.entities.map((e) => e.id), ['e7', 'e9', 'e8']);
      expect(r.renumbered, 1);
      expect(p.byId('e9'), isA<SpotHeightEntity>().having((s) => s.position, 'position', const Pt(30, 0)));
      expect(p.newId(), 'e10');
    });

    test('a catalogue item that cannot be read is set aside; the others stay', () {
      final j = Project().toJson();
      final pipes = (j['catalog'] as Map)['pipes'] as List;
      final n = pipes.length;
      pipes.add({'id': 'broken', 'name': 'no diameters'});
      final (p, r) = read(j);
      expect(p.catalog.pipes.length, n);
      expect(r.skipped['catalog'], 1);
      final again = Project.fromJsonString(p.toJsonString());
      expect(again.catalog.unreadable['pipes'], hasLength(1));
      expect(again.catalog.pipe('broken'), isNull);
    });

    test('texts that are no project give a translatable error', () {
      expect(() => Project.fromJsonString('{"format": "opencadirrigation", "entities": ['), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'project_json')));
      expect(() => Project.fromJsonString('[1, 2]'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'project_format')));
      expect(() => Project.fromJsonString('{"format": "something else"}'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'project_format')));
      expect(() => readProjectFile('not json'), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'project_json')));
      final f = readProjectFile(
        jsonEncode({
          ...Project().toJson(),
          'results': {'zones': []},
        }),
      );
      expect(f.results, isNotNull);
      expect(f.report.clean, isTrue);
      expect(f.project.extra, isNull, reason: 'the results are no field of the project');
    });
  });

  group('forward compatibility (MOD-08)', () {
    test('options of a newer version take their default and are reported', () {
      final j = Project().toJson();
      (j['params'] as Map)['method'] = 'colebrookWhite2';
      (j['params'] as Map)['units'] = {'length': 'yd', 'flow': 'lph', 'pressure': 'mH2O', 'diameter': 'mm'};
      ((j['catalog'] as Map)['pipes'] as List).first['material'] = 'pvcO';
      ((j['catalog'] as Map)['valves'] as List).first['kind'] = 'vacuumBreaker';
      ((j['catalog'] as Map)['pipes'] as List).first['usage'] = ['zone', 'sprinkle'];
      final (p, r) = read(j);
      expect(p.params.frictionMethod, FrictionMethod.hazenWilliams);
      expect(p.params.units.length, LengthUnit.m);
      expect(p.catalog.pipes.first.material, PipeMaterial.pvc);
      expect(p.catalog.pipes.first.usage, {PipeUsage.zone});
      expect(p.catalog.valves.first.kind, ValveKind.other);
      expect(r.unknownValues, containsAll(['method=colebrookWhite2', 'length=yd', 'material=pvcO', 'kind=vacuumBreaker', 'usage=sprinkle']));
    });

    test('fields of a newer version survive opening, editing and saving', () {
      final j = Project().toJson();
      j['futureSection'] = {'a': 1};
      (j['params'] as Map)['futureParam'] = 5;
      (j['meta'] as Map)['futureMeta'] = 'm';
      ((j['catalog'] as Map)['pipes'] as List).first['futureSpec'] = [1, 2];
      (j['catalog'] as Map)['futureList'] = [];
      (j['layers'] as List).first['futureLayer'] = true;
      j['systemFlows'] = [
        {'id': 'f1', 'name': 'A', 'valves': [], 'futureFlow': 3},
      ];
      j['entities'] = [
        {
          'type': 'pipe',
          'id': 'e1',
          'scope': 'zone',
          'pts': [
            [0, 0],
            [5, 0],
          ],
          'futureField': 'x',
        },
      ];
      final (p, r) = read(j);
      expect(r.clean, isTrue, reason: 'unknown fields are kept, nothing to repair');
      // editing makes new objects: the fields go with them
      final pipe = p.entities.single;
      p.entities[0] = pipe.translated(const Pt(1, 1)).transformed(Affine.rotation(0.3)).clone();
      final text = p.toJsonString();
      for (final k in ['futureSection', 'futureParam', 'futureMeta', 'futureSpec', 'futureList', 'futureLayer', 'futureFlow', 'futureField']) {
        expect(text, contains(k), reason: k);
      }
      // the undo state (everything but the entities, the entities cloned)
      final rest = p.toJson(includeEntities: false);
      final restored = Project.fromJson({...rest, 'entities': const []})..entities.addAll(p.entities.map((e) => e.clone()));
      expect(restored.toJsonString(), text);
      // a known field always wins over a kept one
      final again = Project.fromJsonString(text);
      expect(again.entities.single.toJson()['futureField'], 'x');
      expect((again.entities.single as PipeEntity).points.first, isNot(Pt.zero));
    });

    test('version: newer files are flagged; version 1 keeps its IDW terrain; a file without version gets new-project defaults', () {
      final newer = Project().toJson()..['version'] = 99;
      final (_, r) = read(newer);
      expect(r.newerVersion, isTrue);
      expect(r.notes.first.code, 'newer');
      expect(r.notes.first.args['v'], '99');
      final v1 = Project().toJson()..['version'] = 1;
      (v1['params'] as Map).remove('terrain');
      expect(read(v1).$1.params.terrainMethod, TerrainMethod.idw, reason: 'written before the TIN existed');
      final v2 = Project().toJson();
      expect(v2['version'], Project.formatVersion);
      (v2['params'] as Map).remove('terrain');
      expect(read(v2).$1.params.terrainMethod, TerrainMethod.tin);
      // a minimal hand-written file: the defaults of a new project, the
      // catalogue priced in the currency it declares
      final (mini, mr) = read({
        'format': 'opencadirrigation',
        'params': {'currencyCode': 'USD', 'currency': r'US$'},
        'entities': [
          {
            'type': 'spotHeight',
            'id': 'a',
            'p': [0, 0],
            'z': 5,
          },
        ],
      });
      expect(mr.clean, isTrue);
      expect(mini.params.terrainMethod, TerrainMethod.tin);
      final brl = Catalog.defaultCatalog().pipe('pvc50')!.costPerM;
      expect(mini.catalog.pipe('pvc50')!.costPerM, closeTo(brl * exchangeRate('BRL', 'USD')!, 1e-9));
      expect(mini.entities.single.id, 'a');
    });
  });
}
