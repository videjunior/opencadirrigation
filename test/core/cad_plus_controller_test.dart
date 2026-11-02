import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/canvas/compare_overlay.dart';
import 'package:opencadirrigation/app/canvas/snapping.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/state/drawing_prefs.dart';
import 'package:opencadirrigation/app/tools/cad_plus_commands.dart';
import 'package:opencadirrigation/app/tools/cad_plus_tools.dart';
import 'package:opencadirrigation/app/tools/edit_commands.dart';
import 'package:opencadirrigation/app/tools/insert_block_tool.dart';
import 'package:opencadirrigation/app/tools/typed_point.dart';
import 'package:opencadirrigation/app/widgets/dialogs/cad_plus_dialogs.dart' show BlockLibraryCommands, ReviewCommands;
import 'package:opencadirrigation/core/ai/agent_loop.dart' show ToolInputError;
import 'package:opencadirrigation/core/model/blocks.dart';
import 'package:opencadirrigation/core/model/dim_style.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/layer_states.dart';
import 'package:opencadirrigation/core/model/lengthen.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/project_compare.dart';

/// The drawing functions of 1.6.0 (CAD+) on the controller: an analysis is
/// no undo step, trim with the cuts at the ends only, Lengthen, the outline
/// by a click inside, layer states and isolation, the drawing order, text
/// edited in place, the dimension style, block references (insert,
/// redefine, attributes, explode, edit in place, the library), the review
/// of a copy, the snaps one by one and for one point, the settings
/// remembered, typed angles, and the AI operations behind them.
void main() {
  late ProjectController c;
  setUp(() {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
  });

  test('an analysis that changes no item is no undo step; a design that sizes is one', () async {
    c.openProject(buildExample(ExampleId.garden, c.t.call));
    final start = c.historyIndex;
    await c.runDesign();
    expect(c.results, isNotNull);
    expect(c.historyIndex, start + 1, reason: 'the sizing is one step');
    expect(c.historyEntries.last.label, 'hist.design');
    final before = c.historyIndex;
    final results = c.results;
    await c.runDesign(sizeZones: false, sizeMain: false);
    expect(c.results!.method, 'analysis');
    expect(identical(c.results, results), isFalse, reason: 'new results');
    expect(c.historyIndex, before, reason: 'the analysis records no step');
    // the step before still undoes the sizing
    c.undo();
    expect(c.historyIndex, before - 1);
  });

  test('with "edit during the design" on, an edit while a design runs is kept and the results, out of date, are discarded', () async {
    c.openProject(buildExample(ExampleId.garden, c.t.call));
    final run = c.runDesign();
    expect(c.busy, isTrue);
    expect(c.mutate(() => 1), isNull, reason: 'off: refused as before');
    c.editDuringDesign = true;
    final line = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0));
    c.addEntity(line);
    expect(c.project.byId(line.id), isNotNull, reason: 'the edit went through');
    final steps = c.historyIndex;
    await run;
    expect(c.lastMessage, c.t('msg.designStale'));
    expect(c.results, isNull);
    expect(c.historyIndex, steps, reason: 'the discarded design records no step');
    expect(c.project.byId(line.id), isNotNull, reason: 'the drawing was not overwritten');
  });

  test('trim: a boundary that only touches the end of a line leaves the line whole', () {
    final line = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0));
    final edge = LineEntity(id: c.project.newId(), a: const Pt(10, -5), b: const Pt(10, 5));
    c.addEntities([line, edge]);
    expect(c.trimAt(line.id, const Pt(5, 0)), isFalse);
    expect(c.project.byId(line.id), isNotNull);
    expect((c.project.byId(line.id)! as LineEntity).b, const Pt(10, 0));
  });

  test('lengthen: the mode and value of the panel, one undo step', () {
    final l = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0));
    c.addEntity(l);
    c.cadPlus
      ..lengthenMode = LengthenMode.total
      ..lengthenValue = 25;
    expect(c.lengthenAt(l.id, const Pt(9, 0)), isTrue);
    expect((c.project.byId(l.id)! as LineEntity).b.x, closeTo(25, 1e-9));
    expect(c.historyEntries.last.label, 'hist.lengthen|line');
    c.undo();
    expect((c.project.byId(l.id)! as LineEntity).b.x, closeTo(10, 1e-9));
    // a text cannot be lengthened: the user is told
    final t = TextEntity(id: c.project.newId(), position: Pt.zero, text: 'x');
    c.addEntity(t);
    expect(c.lengthenAt(t.id, Pt.zero), isFalse);
    expect(c.lastMessage, c.t('cadp.lengthenWhat'));
  });

  test('the outline by a click inside: a closed polyline or an area, one undo step; a gap says so', () {
    c.addEntities([
      LineEntity(id: c.project.newId(), a: const Pt(-1, 0), b: const Pt(11, 0)),
      LineEntity(id: c.project.newId(), a: const Pt(10, -1), b: const Pt(10, 11)),
      LineEntity(id: c.project.newId(), a: const Pt(11, 10), b: const Pt(-1, 10)),
      LineEntity(id: c.project.newId(), a: const Pt(0, 11), b: const Pt(0, -1)),
    ]);
    final made = c.boundaryAt(const Pt(5, 5));
    expect(made, isA<PolylineEntity>().having((p) => p.closed, 'closed', isTrue));
    expect(polygonArea((made! as PolylineEntity).points).abs(), closeTo(100, 1e-6));
    expect(c.selection, {made.id});
    final area = c.boundaryAt(const Pt(5, 5), asArea: true);
    expect(area, isA<AreaEntity>());
    c.undo();
    expect(c.project.entities.whereType<AreaEntity>(), isEmpty);
    expect(c.boundaryAt(const Pt(50, 50)), isNull);
    expect(c.lastMessage, c.t('cadp.boundaryNone'));
  });

  test('layer states: saved in the project (an undo step), put back; isolate and show again', () {
    final names = [for (final l in c.project.layers) l.name];
    c.toggleLayer(names[1]);
    c.setLayerLocked(names[2], true);
    expect(c.saveLayerState('Sheet A'), isTrue);
    expect(c.historyEntries.last.label, 'hist.layerStateSave|Sheet A');
    c.toggleLayer(names[1]);
    c.setLayerLocked(names[2], false);
    expect(c.restoreLayerState('Sheet A'), isTrue);
    expect(c.project.layerNamed(names[1]).visible, isFalse);
    expect(c.project.layerNamed(names[2]).locked, isTrue);
    expect(c.restoreLayerState('nope'), isFalse);
    // isolate the layer of the selection
    final line = LineEntity(id: c.project.newId(), layer: names[3], a: Pt.zero, b: const Pt(1, 0));
    c.addEntity(line);
    c.select([line.id]);
    c.isolateLayers();
    expect(
      [
        for (final l in c.project.layers)
          if (l.visible) l.name,
      ],
      [names[3]],
    );
    expect(c.project.currentLayer, names[3]);
    expect(c.layersIsolated, isTrue);
    c.unisolateLayers();
    expect(c.layersIsolated, isFalse);
    expect(c.project.layerNamed(names[1]).visible, isFalse, reason: 'back as it was before isolating');
    expect(c.project.layerNamed(names[0]).visible, isTrue);
    expect(c.deleteLayerState('Sheet A'), isTrue);
    expect(c.project.layerStates, isEmpty);
  });

  test('move to the current layer, the drawing order, text edited in place, the dimension style', () {
    final a = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0));
    final b = LineEntity(id: c.project.newId(), layer: Layers.text, a: Pt.zero, b: const Pt(0, 1));
    c.addEntities([a, b]);
    c.select([b.id]);
    expect(c.moveSelectionToCurrentLayer(), 1);
    expect(c.project.byId(b.id)!.layer, c.project.currentLayer);
    c.select([a.id]);
    expect(c.reorder(), 1);
    expect(c.project.entities.last.id, a.id);
    expect(c.reorder(back: true), 1);
    expect(c.project.entities.first.id, a.id);
    final t = TextEntity(id: c.project.newId(), position: Pt.zero, text: 'Valve 1');
    c.addEntity(t);
    expect(c.setEntityText(t.id, 'Valve 2'), isTrue);
    expect((c.project.byId(t.id)! as TextEntity).text, 'Valve 2');
    expect(c.setEntityText(t.id, '   '), isFalse, reason: 'a text is never empty');
    expect(c.setEntityText(a.id, 'x'), isFalse, reason: 'a line has no text');
    expect(c.setDimStyle(const DimStyle(decimals: 3, arrow: DimArrow.arrow)), isTrue);
    expect(c.project.dimStyle.decimals, 3);
    expect(c.setDimStyle(const DimStyle(decimals: 3, arrow: DimArrow.arrow)), isFalse, reason: 'the same style');
    c.undo();
    expect(c.project.dimStyle.isDefault, isTrue);
  });

  test('a mixed selection: its kinds, one kind kept, one kind edited', () {
    final circles = [for (var i = 0; i < 3; i++) CircleEntity(id: c.project.newId(), center: Pt(i * 5.0, 0), radius: 1)];
    final line = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 1));
    c.addEntities([...circles, line]);
    c.select([...circles.map((e) => e.id), line.id]);
    expect(c.selectionKinds(), [('circle', 3), ('line', 1)]);
    expect(c.editSelectedKind('circle', (e) => (e as CircleEntity).radius = 2), 3);
    expect(c.project.entities.whereType<CircleEntity>().every((e) => e.radius == 2), isTrue);
    expect(c.keepSelectedKind('line'), 1);
    expect(c.selection, {line.id});
  });

  group('block references', () {
    BlockDefinition box() => BlockDefinition.fromEntities(
      'Box',
      [LineEntity(id: 'a', a: Pt.zero, b: const Pt(2, 0)), TextEntity(id: 'b', position: const Pt(0, 1), text: '{CODE=B-00}', height: 0.5)],
      Pt.zero,
      inBom: true,
    );

    test('a drawing block goes in as one reference with its values; redefining it changes every reference', () {
      expect(c.saveBlock(c.project.blocks, box()), isTrue);
      final ids = c.insertBlock(c.project.blocks.byName('Box')!, const Pt(10, 10), values: {'CODE': 'B-01'});
      expect(ids, hasLength(1));
      final r = c.project.byId(ids.single)! as BlockRefEntity;
      expect(r.attributes, {'CODE': 'B-01'});
      expect(c.affectsResults(r), isTrue, reason: 'a block of the bill of materials');
      expect(c.pick(const Pt(11, 10), 0.2)?.id, r.id);
      final other = c.insertBlock(c.project.blocks.byName('Box')!, const Pt(0, 50)).single;
      // redefined: both references draw the longer line
      c.saveBlock(
        c.project.blocks,
        BlockDefinition(
          name: 'Box',
          entities: [LineEntity(id: 'x', a: Pt.zero, b: const Pt(5, 0))],
          attributes: box().attributes,
          inBom: true,
        ),
      );
      expect(c.lastMessage, c.t('blkref.redefined', {'b': 'Box', 'n': '2'}));
      for (final (id, end) in [(r.id, const Pt(15, 10)), (other, const Pt(5, 50))]) {
        final ref = c.project.byId(id)! as BlockRefEntity;
        expect((ref.expanded().first as LineEntity).b.distanceTo(end), lessThan(1e-9), reason: id);
      }
      // attributes, then explode into copies (one undo step)
      expect(c.setBlockAttributes(r.id, {'CODE': 'B-02'}), isTrue);
      expect((c.project.byId(r.id)! as BlockRefEntity).attribute('CODE'), 'B-02');
      expect(c.setBlockAttributes(r.id, {'CODE': 'B-00'}), isTrue);
      expect((c.project.byId(r.id)! as BlockRefEntity).attributes, isEmpty, reason: 'the default is not kept');
      expect(c.explodeBlockRefs([r.id]), 1);
      expect(c.project.byId(r.id), isNull);
      expect(c.project.entities.whereType<TextEntity>().where((t) => t.text == 'B-00'), hasLength(1));
      c.undo();
      expect(c.project.byId(r.id), isA<BlockRefEntity>());
    });

    test('a block with hydraulic items goes in as copies; deleting a block keeps its references as copies', () {
      final valves = BlockDefinition(
        name: 'Valves',
        entities: [ControlValveEntity(id: 'v', position: Pt.zero)],
      );
      c.saveBlock(c.project.blocks, valves);
      expect(c.project.entities.length, 0);
      final copies = c.insertBlock(valves, const Pt(3, 3));
      expect(c.project.byId(copies.single), isA<ControlValveEntity>());
      c.saveBlock(c.project.blocks, box());
      final ref = c.insertBlock(c.project.blocks.byName('Box')!, Pt.zero).single;
      expect(c.deleteBlock(c.project.blocks, 'Box'), isTrue);
      expect(c.project.byId(ref), isNull);
      expect(c.project.entities.whereType<LineEntity>(), hasLength(1), reason: 'the reference became its copies');
    });

    test('the selection becomes a reference to the block saved from it', () {
      final line = LineEntity(id: c.project.newId(), a: const Pt(5, 5), b: const Pt(8, 5));
      c.addEntity(line);
      final def = BlockDefinition.fromEntities('Bar', [line], const Pt(5, 5), project: c.project);
      expect(c.saveBlock(c.project.blocks, def, replace: [line], at: const Pt(5, 5)), isTrue);
      expect(c.project.byId(line.id), isNull);
      final r = c.project.entities.whereType<BlockRefEntity>().single;
      expect(r.position, const Pt(5, 5));
      expect(c.selection, {r.id});
    });

    test('edit a block in place: the reference becomes copies, saved back as the block for every reference', () {
      c.saveBlock(c.project.blocks, box());
      final r1 = c.insertBlock(c.project.blocks.byName('Box')!, const Pt(10, 10), rotationDeg: 90).single;
      final r2 = c.insertBlock(c.project.blocks.byName('Box')!, const Pt(0, 50)).single;
      expect(c.startBlockEdit(r1), isTrue);
      expect(c.blockEdit?.blockName, 'Box');
      final copy = c.project.byId(c.selection.single)! as LineEntity;
      expect(copy.b.distanceTo(const Pt(10, 12)), lessThan(1e-9), reason: 'where the reference drew it');
      c.mutate(() => copy.b = const Pt(10, 16));
      expect(c.saveBlockEdit(), isTrue);
      expect(c.blockEdit, isNull);
      final def = c.project.blocks.byName('Box')!;
      expect((def.entities.single as LineEntity).b.distanceTo(const Pt(6, 0)), lessThan(1e-9), reason: 'back in block coordinates');
      expect(def.attributes.single.tag, 'CODE', reason: 'the attributes stay');
      final two = c.project.byId(r2)! as BlockRefEntity;
      expect((two.expanded().first as LineEntity).b.distanceTo(const Pt(6, 50)), lessThan(1e-9));
      // a cancelled edit leaves the block as it was
      final again = c.project.entities.whereType<BlockRefEntity>().firstWhere((x) => x.id != r2);
      expect(c.startBlockEdit(again.id), isTrue);
      c.cancelBlockEdit();
      expect(c.blockEdit, isNull);
      expect(c.project.entities.whereType<BlockRefEntity>(), hasLength(2));
    });

    test('a library imported redefines blocks of the same name', () {
      c.saveBlock(c.project.blocks, box());
      final ref = c.insertBlock(c.project.blocks.byName('Box')!, Pt.zero).single;
      final lib = [
        BlockDefinition(
          name: 'Box',
          entities: [LineEntity(id: 'x', a: Pt.zero, b: const Pt(0, 9))],
        ),
        BlockDefinition(
          name: 'New',
          entities: [LineEntity(id: 'y', a: Pt.zero, b: const Pt(1, 0))],
        ),
      ];
      expect(c.importBlockLibrary(lib), 2);
      expect(c.project.blocks.length, 2);
      resolveBlockRefs(c.project);
      expect(((c.project.byId(ref)! as BlockRefEntity).expanded().first as LineEntity).b.distanceTo(const Pt(0, 9)), lessThan(1e-9));
    });
  });

  test('the comments of a copy come back in one undo step', () {
    final cm = CommentEntity(id: c.project.newId(), position: Pt.zero, text: 'slope?');
    c.addEntity(cm);
    final copy = Project.fromJson(c.project.toJson());
    (copy.byId(cm.id)! as CommentEntity).resolved = true;
    copy.entities.add(CommentEntity(id: 'e900', position: const Pt(9, 9), text: 'new'));
    final r = c.importReview(copy)!;
    expect((r.added, r.updated), (1, 1));
    expect(c.historyEntries.last.label, 'hist.importReview|2');
    expect(c.importReview(copy), isNull, reason: 'nothing new the second time');
    c.undo();
    expect(c.project.entities.whereType<CommentEntity>(), hasLength(1));
  });

  test('a comparison shows on the drawing until the next edit', () {
    final other = Project.fromJson(c.project.toJson());
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0)));
    final cmp = compareProjects(other, c.project);
    c.showComparison(cmp);
    expect(c.shownComparison, same(cmp));
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(2, 0)));
    expect(c.shownComparison, isNull);
  });

  group('snaps', () {
    setUp(() {
      c.camera
        ..scale = 10
        ..center = Pt.zero;
      c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    });

    test('each snap turns on and off; one chosen for the next point works alone, even with the snap off', () {
      final s = Snapper(c);
      expect(s.snap(const Pt(0.3, 0.2)).kind, 'endpoint');
      c.snap.modes.remove('endpoint');
      expect(s.snap(const Pt(0.3, 0.2)).kind, isNot('endpoint'));
      c.snap.modes.add('endpoint');
      c.snap.enabled = false;
      expect(s.snap(const Pt(5.2, 0.2)).isSnapped, isFalse);
      c.snap.once = 'midpoint';
      final m = s.snap(const Pt(5.2, 0.2));
      expect(m.kind, 'midpoint');
      expect(m.point, const Pt(5, 0));
      // only that one: the endpoint is not taken
      expect(s.snap(const Pt(0.1, 0.1)).kind, isNot('endpoint'));
      expect(snapOnceAliases['END'], 'endpoint');
      expect(snapOnceAliases['NON'], 'none');
    });

    test('a block reference snaps on the items it draws', () {
      c.project.blocks.put(
        BlockDefinition(
          name: 'B',
          entities: [LineEntity(id: 'q', a: Pt.zero, b: const Pt(0, 4))],
        ),
      );
      c.addEntity(BlockRefEntity(id: c.project.newId(), position: const Pt(20, 0), blockName: 'B'));
      final r = Snapper(c).snap(const Pt(20.2, 3.9));
      expect(r.kind, 'endpoint');
      expect(r.point, const Pt(20, 4));
    });
  });

  test('typed angles: azimuths and the bearings of field surveys', () {
    Pt at(String a) => parseTypedPoint('@10<$a', reference: Pt.zero)!;
    void near(Pt p, Pt q, String why) => expect(p.distanceTo(q), lessThan(1e-9), reason: why);
    near(at('N90E'), const Pt(10, 0), 'N90E is east');
    near(at('N0E'), const Pt(0, 10), 'north');
    near(at('A180'), const Pt(0, -10), 'azimuth 180 is south');
    near(at('AZ90'), const Pt(10, 0), 'azimuth 90 is east');
    near(at('45NE'), Pt.polar(10, degToRad(45)), 'north-east');
    near(at('N45L'), Pt.polar(10, degToRad(45)), 'L is east in Portuguese');
    near(at('S45W'), Pt.polar(10, degToRad(-135)), 'south-west');
    near(at('S30O'), Pt.polar(10, degToRad(-120)), 'O is west');
    near(at('30'), Pt.polar(10, degToRad(30)), 'a plain angle as before');
    expect(parseTypedAngle('N95E'), isNull);
    expect(parseTypedAngle('A400'), isNull);
    expect(parseTypedAngle('X'), isNull);
  });

  test('the drawing and snap settings are remembered for the next tabs and visits', () {
    rememberDrawingSettings = true;
    addTearDown(() {
      rememberDrawingSettings = false;
      removePref(drawingPrefsKey);
    });
    final a = ProjectController()..autosaveEnabled = false;
    a.snap
      ..ortho = true
      ..polarStepDeg = 30
      ..tolerancePx = 14;
    a.snap.modes.remove('tangent');
    a.toolSettings
      ..offsetDistance = 7
      ..commentAuthor = 'Ana'
      ..outletSpecId = 'nope';
    a.editSettings.filletRadius = 3;
    a.cadPlus.lengthenMode = LengthenMode.percent;
    a.refresh();
    expect(getPref(drawingPrefsKey), isNotNull);
    final b = ProjectController()..autosaveEnabled = false;
    expect(b.snap.ortho, isTrue);
    expect(b.snap.polarStepDeg, 30);
    expect(b.snap.tolerancePx, 14);
    expect(b.snap.modes.contains('tangent'), isFalse);
    expect(b.toolSettings.offsetDistance, 7);
    expect(b.toolSettings.commentAuthor, 'Ana');
    expect(b.toolSettings.outletSpecId, isNot('nope'), reason: 'a catalogue item the catalogue lacks is left out');
    expect(b.editSettings.filletRadius, 3);
    expect(b.cadPlus.lengthenMode, LengthenMode.percent);
    a.dispose();
    b.dispose();
  });

  group('AI operations', () {
    late AgentToolbox box;
    setUp(() => box = AgentToolbox(c));
    Future<String> run(String name, Map<String, dynamic> input) async => (await box.operations.firstWhere((o) => o.name == name).run(input)).text;

    test('lengthen, outline, drawing order and dimension style', () async {
      final l = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0));
      c.addEntity(l);
      expect(
        await run('lengthen_entity', {
          'id': l.id,
          'at': [10, 0],
          'mode': 'delta',
          'value': 5,
        }),
        contains('15.00 m'),
      );
      c.addEntities([
        LineEntity(id: c.project.newId(), a: const Pt(-1, 20), b: const Pt(11, 20)),
        LineEntity(id: c.project.newId(), a: const Pt(10, 19), b: const Pt(10, 31)),
        LineEntity(id: c.project.newId(), a: const Pt(11, 30), b: const Pt(-1, 30)),
        LineEntity(id: c.project.newId(), a: const Pt(0, 31), b: const Pt(0, 19)),
      ]);
      expect(
        await run('boundary_at', {
          'at': [5, 25],
          'as': 'area',
        }),
        contains('100.00 m²'),
      );
      expect(
        await run('draw_order', {
          'ids': [l.id],
          'to': 'back',
        }),
        contains('back'),
      );
      expect(c.project.entities.first.id, l.id);
      expect(await run('dim_style', {}), contains('2 decimals'));
      expect(await run('dim_style', {'decimals': 1, 'unit': 'cm', 'arrow': 'tick'}), contains('1 decimals'));
      expect(c.project.dimStyle.arrow, DimArrow.tick);
    });

    test('layer states, isolation, block attributes, comparison with a tab-less project', () async {
      expect(await run('save_layer_state', {'name': 'Elec'}), contains('Elec'));
      expect(await run('layer_states', {}), contains('"Elec"'));
      expect(
        await run('isolate_layers', {
          'layers': [Layers.drawing],
        }),
        contains(Layers.drawing),
      );
      expect(await run('unisolate_layers', {}), contains('shown'));
      c.saveBlock(
        c.project.blocks,
        BlockDefinition(
          name: 'T',
          entities: [LineEntity(id: 'z', a: Pt.zero, b: const Pt(1, 0))],
          attributes: const [BlockAttributeDef(tag: 'CODE')],
        ),
      );
      final ref = c.insertBlock(c.project.blocks.byName('T')!, Pt.zero).single;
      expect(
        await run('set_block_attributes', {
          'id': ref,
          'values': {'code': 'K-1'},
        }),
        contains('CODE=K-1'),
      );
      expect(
        await run('define_block_attributes', {
          'name': 'T',
          'attributes': [
            {'tag': 'flow'},
          ],
          'in_bom': true,
        }),
        contains('FLOW'),
      );
      expect(c.project.blocks.byName('T')!.inBom, isTrue);
      expect(
        await run('explode_block_refs', {
          'ids': [ref],
        }),
        contains('Exploded 1'),
      );
      await expectLater(run('compare_project', {}), throwsA(isA<ToolInputError>()));
    });
  });

  test('the field photo: what is not a picture is said so', () {
    expect(c.addFieldPhoto(Uint8List.fromList([1, 2, 3]), 'x.jpg'), isNull);
    expect(c.lastMessage, c.t('photo.notPicture', {'n': 'x.jpg'}));
    expect(c.activeTool, ToolId.select, reason: 'nothing waits for a click');
  });
}
