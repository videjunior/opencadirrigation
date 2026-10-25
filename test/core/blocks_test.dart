import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/insert_block_tool.dart';
import 'package:opencadirrigation/core/model/blocks.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// User blocks: made from a selection about a base point, inserted as
/// moved, turned and scaled copies with new ids, saved as JSON.
void main() {
  Project drawing() {
    final p = Project();
    p.layers.add(Layer(name: 'MANIFOLD', color: 0xFF123456));
    p.entities.addAll([
      LineEntity(id: 'e1', layer: 'MANIFOLD', a: const Pt(10, 10), b: const Pt(12, 10)),
      CircleEntity(id: 'e2', center: const Pt(11, 11), radius: 0.5),
      OutletEntity(id: 'e3', position: const Pt(12, 12), outletSpecId: 'x', arcDeg: 90, orientationDeg: 0),
      SpraylineEntity(id: 'e4', points: const [Pt(10, 12), Pt(20, 12)], outletSpecId: 'x', spacing: 2),
      TextEntity(id: 'e5', position: const Pt(10, 9), text: 'V1', height: 0.5),
    ]);
    return p;
  }

  test('a block keeps copies in block coordinates around its base point', () {
    final p = drawing();
    final b = BlockDefinition.fromEntities('Manifold', p.entities, const Pt(10, 10), description: 'two valves', project: p);
    expect(b.entities, hasLength(5));
    final line = b.entities.first as LineEntity;
    expect((line.a, line.b), (Pt.zero, const Pt(2, 0)));
    // the drawing is untouched
    expect((p.entities.first as LineEntity).a, const Pt(10, 10));
    expect(b.layers['MANIFOLD'], 0xFF123456);
    expect(b.layers.keys, containsAll([Layers.drawing, Layers.outlets, Layers.spraylines, Layers.text]));
    final bb = b.bounds;
    expect((bb.minX, bb.minY, bb.maxX, bb.maxY), (0.0, -1.0, 10.0, 2.0));
    expect(() => b.entities.add(line), throwsUnsupportedError, reason: 'a definition does not change behind the library');
  });

  test('inserted copies are moved, turned and scaled about the base point, with new ids and layers', () {
    final src = drawing();
    final b = BlockDefinition.fromEntities('Manifold', src.entities, const Pt(10, 10), project: src);
    final p = Project();
    for (var i = 0; i < 3; i++) {
      p.entities.add(LineEntity(id: p.newId(), a: Pt.zero, b: const Pt(1, 1)));
    }
    final existing = p.entities.map((e) => e.id).toSet();
    expect(p.findLayer('MANIFOLD'), isNull);
    final copies = b.instantiate(p, at: const Pt(100, 50), rotationDeg: 90, scale: 2);
    expect(copies, hasLength(5));
    expect(p.findLayer('MANIFOLD')?.color, 0xFF123456);
    // new ids of the target project, none of them taken
    final ids = copies.map((e) => e.id).toSet();
    expect(ids, hasLength(5));
    expect(ids.intersection(existing), isEmpty);
    final line = copies[0] as LineEntity;
    expect(line.a.distanceTo(const Pt(100, 50)), lessThan(1e-9));
    expect(line.b.distanceTo(const Pt(100, 54)), lessThan(1e-9), reason: '(2, 0) turned 90° and doubled');
    expect((copies[1] as CircleEntity).radius, closeTo(1, 1e-12));
    // a sector turns with the block; a lateral keeps its outlets on it (spacing scaled)
    expect((copies[2] as OutletEntity).orientationDeg, closeTo(90, 1e-9));
    expect((copies[3] as SpraylineEntity).spacing, closeTo(4, 1e-12));
    expect((copies[4] as TextEntity).height, closeTo(1, 1e-12));
    expect((copies[4] as TextEntity).rotationDeg, closeTo(90, 1e-9));
    // the next insertion gets other ids again
    final again = b.instantiate(p, at: Pt.zero);
    expect(again.map((e) => e.id).toSet().intersection(ids), isEmpty);
    expect(() => b.instantiate(p, at: Pt.zero, scale: 0), throwsArgumentError);
    expect(() => b.instantiate(p, at: Pt.zero, scale: double.nan), throwsArgumentError);
  });

  test('the library: names, replacement, renaming and JSON', () {
    final p = drawing();
    final lib = BlockLibrary();
    expect(lib.uniqueName('Bloco'), 'Bloco 1');
    final a = BlockDefinition.fromEntities('Bloco 1', p.entities.take(2), Pt.zero);
    expect(lib.put(a), isFalse);
    expect(lib.uniqueName('Bloco'), 'Bloco 2');
    final a2 = BlockDefinition.fromEntities('Bloco 1', p.entities.take(3), Pt.zero);
    expect(lib.put(a2), isTrue, reason: 'same name replaces');
    expect(lib.length, 1);
    expect(lib.byName(' Bloco 1 ')!.entities, hasLength(3));
    lib.put(BlockDefinition.fromEntities('Valve', [p.entities.first], Pt.zero, description: 'one'));
    expect(lib.rename('Valve', 'Bloco 1'), isFalse, reason: 'name taken');
    expect(lib.rename('Valve', ''), isFalse);
    expect(lib.rename('Valve', 'Válvula'), isTrue);
    expect(lib.byName('Válvula')!.description, 'one');
    // JSON round trip (as the project keeps it)
    final back = BlockLibrary.fromJson(jsonDecode(jsonEncode(lib.toJson())) as List);
    expect(back.blocks.map((b) => b.name), ['Bloco 1', 'Válvula']);
    expect(back.byName('Bloco 1')!.entities.map((e) => e.type), [EntityType.line, EntityType.circle, EntityType.outlet]);
    expect(back.byName('Bloco 1')!.layers, lib.byName('Bloco 1')!.layers);
    expect(back.byName('Válvula')!.created.toIso8601String(), lib.byName('Válvula')!.created.toIso8601String());
    // a damaged block or a duplicate name is skipped, not the whole library
    final damaged = BlockLibrary.fromJson([
      ...lib.toJson(),
      {
        'name': 'broken',
        'entities': [
          {'type': 'nope', 'id': 'x'},
        ],
      },
      {'name': 'Válvula', 'entities': const []},
    ]);
    expect(damaged.blocks.map((b) => b.name), ['Bloco 1', 'Válvula']);
    expect(BlockLibrary.fromJson(null).isEmpty, isTrue);
    expect(lib.remove('Bloco 1'), isTrue);
    expect(lib.remove('Bloco 1'), isFalse);
  });

  test('the project keeps its library in the file and in the undo history', () {
    final c = ProjectController()..autosaveEnabled = false;
    // through the file, so that the id counter is past the drawing's ids
    c.openProject(Project.fromJson(drawing().toJson()));
    final b = BlockDefinition.fromEntities('Manifold', c.project.entities, const Pt(10, 10), project: c.project);
    expect(c.saveBlock(c.project.blocks, b), isTrue);
    final back = Project.fromJson(jsonDecode(c.project.toJsonString()) as Map<String, dynamic>);
    expect(back.blocks.byName('Manifold')!.entities, hasLength(5));
    expect(Project().toJson().containsKey('blocks'), isFalse, reason: 'no key without blocks');
    final ids = c.insertBlock(c.project.blocks.byName('Manifold')!, const Pt(100, 0));
    expect(ids, hasLength(5));
    c.undo();
    expect(c.project.entities.where((e) => ids.contains(e.id)), isEmpty);
    c.undo();
    expect(c.project.blocks.isEmpty, isTrue, reason: 'saving the block is one undo step');
    c.redo();
    expect(c.project.blocks.byName('Manifold'), isNotNull);
  });
}
