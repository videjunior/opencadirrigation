import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/agent_tools_ops.dart';
import 'package:opencadirrigation/app/ai/ops_cad_commands.dart' show commandsListing;
import 'package:opencadirrigation/app/ai/ops_cad_view.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/io/project_export.dart' show DrawingFormat;
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

import 'support/aerial_scene.dart';
import 'support/fake_claude.dart';

/// The assistant's way to the drawing side of the program, through the
/// scripted model and the real agent loop: run_operation over every
/// operation group (edits, zone tools, annotation and blocks, view and
/// history, tabs and files, terrain and site, imports), its permissions in
/// ask, read-only and plan modes, run_command (aliases that act, dialogs
/// run headless, drawing tools answered with what to call) and the typed
/// settings round trip.
class _Host implements AgentHost {
  @override
  AgentPermission permission = AgentPermission.auto;
  @override
  bool stopped = false;
  @override
  String notes = '';
  @override
  final Map<String, Uint8List> files = {};
  final opened = <Project>[];
  @override
  String get instructions => '';
  @override
  void setTodos(List<AiTodo> items) {}
  @override
  Future<List<String>?> ask(List<AiQuestion> questions) async => [for (final _ in questions) ''];
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => const PlanDecision.approved(AgentPermission.auto);
  @override
  void setNotes(String text) => notes = text;
  @override
  bool openTab(Project p) {
    opened.add(p);
    return true;
  }
}

/// A host with the workspace's tabs (three projects, the assistant's first).
class _WorkspaceHost extends _Host implements AiWorkspaceHost {
  final names = ['Mine', 'Farm B', 'Garden C'];
  var active = 0;
  var created = 0;
  @override
  List<AiTab> get tabs => [for (var i = 0; i < names.length; i++) AiTab(name: names[i], dirty: i == 2, active: i == active, own: i == 0)];
  @override
  bool selectTab(int index) {
    if (index < 0 || index >= names.length) return false;
    active = index;
    return true;
  }

  @override
  bool closeTab(int index) {
    if (index <= 0 || index >= names.length) return false;
    names.removeAt(index);
    return true;
  }

  @override
  bool newTab() {
    created++;
    names.add('New project');
    return true;
  }

  @override
  Future<int> copySelection({bool cut = false}) async => 0;
  @override
  Future<int> paste() async => 0;
}

void main() {
  late ProjectController c;
  late _Host host;
  late AgentToolbox box;

  Future<void> start({_Host? withHost}) async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    host = withHost ?? _Host();
    box = AgentToolbox(c, host: host);
  }

  setUp(() => start());

  /// One turn of the scripted model: [script] answers the requests in
  /// order (each may build its calls from the project as it is then).
  Future<(FakeClaude, AgentTurn)> turn(
    WidgetTester tester,
    List<FakeReply Function(Map<String, dynamic>)> script, {
    AgentPermission permission = AgentPermission.auto,
    Approval Function(AgentToolCall call)? approve,
  }) async {
    final fake = FakeClaude([...script, (_) => FakeReply.text('done')]);
    AgentTurn? out;
    await tester.runAsync(() async {
      out =
          await AgentLoop(
            api: AnthropicClient(apiKey: 'sk-ant-test', transport: fake.call, sleep: (_) async {}),
            tools: box.tools,
          ).run(
            model: AiModel.opus55,
            system: 's',
            history: const [],
            user: AnthropicFormat.user([AiTextPart('go')]),
            permission: permission,
            cancel: AiCancel(),
            events: AgentEvents(approve: approve == null ? null : (call) async => approve(call)),
          );
    });
    return (fake, out!);
  }

  /// A reply calling run_operation for each (name, input).
  FakeReply Function(Map<String, dynamic>) ops(List<(String, Map<String, dynamic>)> calls) =>
      (_) => FakeReply.tools([
        for (final (n, i) in calls) ('run_operation', {'name': n, 'input': i}),
      ]);

  T add<T extends Entity>(T e) {
    c.project.entities.add(e);
    c.entitiesChanged();
    return e;
  }

  String id() => c.project.newId();

  testWidgets('edit: offset, trim, extend, split, array, vertices, alignment, extra properties', (tester) async {
    final l1 = add(LineEntity(id: id(), a: Pt.zero, b: const Pt(10, 0)));
    final l2 = add(LineEntity(id: id(), a: const Pt(0, 20), b: const Pt(10, 20)));
    final v1 = add(LineEntity(id: id(), a: const Pt(5, 15), b: const Pt(5, 25)));
    final l3 = add(LineEntity(id: id(), a: const Pt(0, 40), b: const Pt(10, 40)));
    final v2 = add(LineEntity(id: id(), a: const Pt(15, 35), b: const Pt(15, 45)));
    final pipe = add(PipeEntity(id: id(), points: [const Pt(0, 60), const Pt(20, 60)], scope: HydraulicScope.zone));
    final poly = add(PolylineEntity(id: id(), points: [const Pt(30, 0), const Pt(40, 0), const Pt(40, 10)]));
    final dim = add(DimensionEntity(id: id(), a: const Pt(0, -5), b: const Pt(10, -5), offset: 1));
    final ring = add(CircleEntity(id: id(), center: const Pt(80, 80), radius: 3));
    final (fake, t) = await turn(tester, [
      ops([
        (
          'offset_entities',
          {
            'ids': [l1.id],
            'distance_m': 2,
            'side': 'left',
            'copies': 2,
          },
        ),
        (
          'trim_entity',
          {
            'id': l2.id,
            'at': [8, 20],
            'boundaries': [v1.id],
          },
        ),
        (
          'extend_entity',
          {
            'id': l3.id,
            'at': [9.5, 40],
            'boundaries': [v2.id],
          },
        ),
        (
          'split_entity',
          {
            'id': pipe.id,
            'points': [
              [5, 60],
              [12, 60],
            ],
          },
        ),
        (
          'array_entities',
          {
            'ids': [poly.id],
            'rows': 1,
            'cols': 3,
            'col_spacing_m': 20,
          },
        ),
        (
          'edit_vertices',
          {
            'id': poly.id,
            'action': 'move',
            'index': 2,
            'point': [40, 20],
          },
        ),
        (
          'align_entities',
          {
            'ids': [l1.id],
            'from_a': [0, 0],
            'to_a': [100, 100],
            'from_b': [10, 0],
            'to_b': [100, 110],
          },
        ),
        (
          'update_extra_properties',
          {
            'updates': [
              {
                'id': dim.id,
                'set': {'off': 3},
              },
            ],
          },
        ),
        (
          'offset_entities',
          {
            'ids': [ring.id],
            'distance_m': 1,
          },
        ),
      ]),
      ops([
        (
          'clipboard',
          {
            'action': 'copy',
            'ids': [v2.id],
          },
        ),
        ('clipboard', {'action': 'paste'}),
      ]),
    ]);
    expect(t.calls.every((x) => x.state == ToolCallState.done), isTrue, reason: '${fake.lastUserText(1)}\n${fake.lastUserText(2)}');
    final lines = c.project.entities.whereType<LineEntity>().toList();
    expect(lines.where((l) => (l.a.y - 2).abs() < 1e-9 && (l.b.y - 2).abs() < 1e-9), hasLength(1), reason: 'offset to the left, once…');
    expect(lines.where((l) => (l.a.y - 4).abs() < 1e-9), hasLength(1), reason: '…and twice');
    final trimmed = c.project.byId(l2.id) as LineEntity;
    expect(trimmed.b.x, closeTo(5, 1e-9), reason: 'the part past the boundary is gone');
    expect((c.project.byId(l3.id) as LineEntity).b.x, closeTo(15, 1e-9));
    final pipes = c.project.entities.whereType<PipeEntity>().toList();
    expect(pipes, hasLength(3));
    expect(fake.lastUserText(1), contains('2 cuts'));
    expect(c.project.entities.whereType<PolylineEntity>(), hasLength(3), reason: 'two copies');
    expect((c.project.byId(poly.id) as PolylineEntity).points[2], const Pt(40, 20));
    final aligned = c.project.byId(l1.id) as LineEntity;
    expect(aligned.a.distanceTo(const Pt(100, 100)), lessThan(1e-6));
    expect(aligned.b.distanceTo(const Pt(100, 110)), lessThan(1e-6));
    expect((c.project.byId(dim.id) as DimensionEntity).offset, 3);
    expect(c.project.entities.whereType<CircleEntity>().map((x) => x.radius), containsAll([3.0, 4.0]), reason: 'a circle offsets outwards by default');
    expect(fake.lastUserText(2), contains('Pasted 1 items'));
    expect(c.project.entities.whereType<LineEntity>().where((l) => (l.a.x - 17).abs() < 1e-9), hasLength(1), reason: 'pasted 2 m east of the copied boundary');
    expect(c.canUndo, isTrue, reason: 'every edit is an undo step');
  });

  testWidgets('zone: plain pipe, devices on laterals, feed envelope, the block and sprinkler-grid dialogs, the selection BOM', (tester) async {
    final spray = add(SpraylineEntity(id: id(), points: [Pt.zero, const Pt(30, 0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4));
    final tape = add(TapeEntity(id: id(), points: [const Pt(0, 10), const Pt(60, 10)], tapeSpecId: 'drip16_16_50', inletHeadM: 10));
    final tape2 = add(TapeEntity(id: id(), points: [const Pt(0, 12), const Pt(80, 12)], tapeSpecId: 'drip16_16_50', inletHeadM: 10));
    final (fake, t) = await turn(tester, [
      ops([
        (
          'convert_to_pipe',
          {
            'ids': [spray.id],
          },
        ),
        (
          'insert_device_on_laterals',
          {
            'ids': [tape.id],
            'device': 'prv50',
            'distance_m': 0.5,
          },
        ),
        (
          'feed_envelope',
          {
            'ids': [tape2.id],
          },
        ),
        (
          'fill_block',
          {
            'pts': [
              [100, 0],
              [160, 0],
              [160, 40],
              [100, 40],
            ],
            'lateral': 'tape',
            'lateral_spacing_m': 1.5,
            'tape': 'drip16_16_50',
            'valve': 'ev50',
          },
        ),
        (
          'sprinkler_grid',
          {
            'pts': [
              [200, 0],
              [240, 0],
              [240, 30],
              [200, 30],
            ],
            'outlet': 'rotor',
            'pattern': 'triangular',
          },
        ),
        (
          'selection_bom',
          {
            'ids': [tape.id, tape2.id],
          },
        ),
      ]),
    ]);
    expect(t.calls.every((x) => x.state == ToolCallState.done), isTrue, reason: fake.lastUserText(1));
    expect(c.project.entities.whereType<SpraylineEntity>(), isEmpty);
    expect(c.project.entities.whereType<PipeEntity>().where((p) => p.points.last == const Pt(30, 0)), hasLength(1));
    final dev = c.project.entities.whereType<MiscHydraulicEntity>().single;
    expect(dev.valveSpecId, 'prv50');
    expect(dev.position.distanceTo(const Pt(0.5, 10)), lessThan(1e-6));
    final out = fake.lastUserText(1);
    expect(out, contains('best feed at'));
    expect(c.project.entities.whereType<TapeEntity>().where((x) => x.points.first.x >= 100), isNotEmpty, reason: 'the block laterals');
    expect(c.project.entities.whereType<ControlValveEntity>(), hasLength(1));
    expect(c.project.entities.whereType<OutletEntity>().where((o) => o.outletSpecId == 'rotor'), isNotEmpty);
    expect(out, contains('overlap CU'));
    expect(out, contains('2 items'), reason: 'the materials of the two tapes');
  });

  testWidgets('annotate, blocks and layers: four kinds of dimensions, a revision cloud, the block library', (tester) async {
    final circle = add(CircleEntity(id: id(), center: const Pt(50, 50), radius: 4));
    final poly = add(PolylineEntity(id: id(), points: [Pt.zero, const Pt(10, 0), const Pt(10, 5)]));
    final (fake, t) = await turn(tester, [
      ops([
        (
          'add_dimension',
          {
            'kind': 'linear',
            'a': [0, 0],
            'b': [10, 0],
            'offset_m': 2,
          },
        ),
        ('add_dimension', {'kind': 'linear', 'segments_of': poly.id}),
        (
          'add_dimension',
          {
            'kind': 'angular',
            'vertex': [0, 0],
            'a': [10, 0],
            'b': [0, 10],
          },
        ),
        ('add_dimension', {'kind': 'radial', 'of': circle.id, 'diameter': true}),
        (
          'add_dimension',
          {
            'kind': 'ordinate',
            'point': [5, 7],
            'leader_end': [5, 12],
          },
        ),
        (
          'add_revision_cloud',
          {
            'pts': [
              [40, 40],
              [60, 40],
              [60, 60],
              [40, 60],
            ],
            'description': 'valve moved',
          },
        ),
        ('get_label_rules', <String, dynamic>{}),
        (
          'save_block',
          {
            'name': 'Valve box',
            'ids': [circle.id],
            'base': 'center',
          },
        ),
        ('list_blocks', <String, dynamic>{}),
        (
          'insert_block',
          {
            'name': 'Valve box',
            'points': [
              [100, 0],
              [120, 0],
            ],
            'rotation_deg': 90,
          },
        ),
        ('list_layers', <String, dynamic>{}),
      ]),
      (_) {
        final rc = c.project.entities.whereType<RevisionCloudEntity>().single;
        return FakeReply.tools([
          (
            'run_operation',
            {
              'name': 'update_extra_properties',
              'input': {
                'updates': [
                  {
                    'id': rc.id,
                    'set': {'rev': 'B', 'arc': 2},
                  },
                ],
              },
            },
          ),
          (
            'run_operation',
            {
              'name': 'delete_block',
              'input': {'name': 'Valve box'},
            },
          ),
        ]);
      },
    ]);
    expect(t.calls.every((x) => x.state == ToolCallState.done), isTrue, reason: '${fake.lastUserText(1)}\n${fake.lastUserText(2)}');
    expect(c.project.entities.whereType<DimensionEntity>(), hasLength(3), reason: 'one plus one per segment');
    expect(c.project.entities.whereType<AngularDimensionEntity>().single.angleDeg, closeTo(90, 1e-6));
    final radial = c.project.entities.whereType<RadialDimensionEntity>().single;
    expect(radial.diameter, isTrue);
    expect(radial.value, closeTo(8, 1e-9));
    expect(c.project.entities.whereType<OrdinateDimensionEntity>().single.xAxis, isTrue);
    final out = fake.lastUserText(1);
    expect(out, contains('90.00°'));
    expect(out, contains('X = 5.000 m'));
    expect(out, contains('revision "A"'));
    expect(out, contains('No label rule'));
    expect(out, contains('"Valve box": 1 items'));
    expect(c.project.entities.whereType<CircleEntity>(), hasLength(3), reason: 'the original and two insertions');
    expect(out, contains('DIMENSIONS'));
    final rc = c.project.entities.whereType<RevisionCloudEntity>().single;
    expect(rc.revision, 'B');
    expect(rc.arcLength, 2);
    expect(c.project.blocks.isEmpty, isTrue);
  });

  testWidgets('view and history: zoom, undo, redo, the history timeline and jumps', (tester) async {
    final scale = c.camera.scale;
    final (fake, t) = await turn(tester, [
      (_) => FakeReply.tools([
        for (var k = 0; k < 3; k++)
          (
            'create_entities',
            {
              'entities': [
                {
                  'type': 'text',
                  'p': [k * 10, 0],
                  'text': 'n$k',
                },
              ],
            },
          ),
        (
          'run_operation',
          {
            'name': 'zoom_view',
            'input': {'factor': 2},
          },
        ),
      ]),
      ops([
        ('undo', {'steps': 2}),
        ('redo', <String, dynamic>{}),
        ('get_history', <String, dynamic>{}),
      ]),
      ops([
        ('jump_to_history', {'index': 0}),
      ]),
    ]);
    expect(t.calls.every((x) => x.state == ToolCallState.done), isTrue, reason: fake.lastUserText(2));
    expect(c.camera.scale, closeTo(scale * 2, 1e-9));
    expect(fake.lastUserText(2), contains('Undid 2 steps'));
    expect(fake.lastUserText(2), contains('Redid 1 step'));
    expect(fake.lastUserText(2), contains('undone: redo brings it back'));
    expect(c.project.entities, isEmpty, reason: 'back to the opening state');
    expect(c.canRedo, isTrue);
  });

  testWidgets('tabs and files: the workspace through the host, attached and kept projects, versions, commands', (tester) async {
    await start(withHost: _WorkspaceHost());
    final ws = host as _WorkspaceHost;
    final other = Project()..meta.name = 'Attached farm';
    host.files['farm.oci.json'] = Uint8List.fromList(utf8.encode(jsonEncode(other.toJson())));
    final kept = Project()..meta.name = 'Kept garden';
    c.store.save(kept.meta.uid, kept.meta.name, jsonEncode(kept.toJson()), kind: 'autosave');
    c.project.meta.name = 'Versioned';
    c.saveJson();
    c.addEntity(TextEntity(id: id(), position: Pt.zero, text: 'x'));
    c.saveJson();
    final versions = c.store.versions(c.project.meta.uid);
    expect(versions, isNotEmpty);
    final (fake, t) = await turn(tester, [
      ops([
        ('list_tabs', <String, dynamic>{}),
        ('switch_tab', {'index': 1}),
        ('close_tab', {'index': 2}),
        ('new_project', <String, dynamic>{}),
        ('new_project', {'name': 'Second farm'}),
        ('open_attached_project', {'name': 'farm.oci.json'}),
        ('list_recent_projects', <String, dynamic>{}),
        ('open_recent_project', {'id': 'Kept garden'}),
        ('list_versions', <String, dynamic>{}),
        ('restore_version', {'version': versions.last.version}),
        ('list_commands', <String, dynamic>{}),
      ]),
    ], approve: (call) => Approval.apply);
    expect(t.calls.every((x) => x.state == ToolCallState.done), isTrue, reason: fake.lastUserText(1));
    final out = fake.lastUserText(1);
    expect(out, contains('0: Mine — on screen — yours'));
    expect(ws.active, 1);
    expect(ws.names, isNot(contains('Garden C')), reason: 'closed, after the user confirmed it');
    expect(t.calls.where((x) => x.state == ToolCallState.done && x.summary.contains('Close tab')), hasLength(1));
    expect(ws.created, 1);
    expect(host.opened.map((p) => p.meta.name), containsAll(['Second farm', 'Attached farm', 'Kept garden', 'Versioned']));
    expect(out, contains('Kept garden | autosave'));
    expect(out, contains('zoomAll (Zoom all): Z, ZE, ZA, ZOOM'));
  });

  testWidgets('terrain and site: contours, the model, profiles, downloads, georeference, images, vegetation', (tester) async {
    for (var i = 0; i <= 4; i++) {
      for (var j = 0; j <= 4; j++) {
        add(SpotHeightEntity(id: id(), position: Pt(i * 10.0, j * 10.0), elevation: 100 + i * 1.0 + j * 0.5));
      }
    }
    final scene = AerialScene();
    final png = Uint8List.fromList(img.encodePng(img.Image.fromBytes(width: scene.width, height: scene.height, bytes: scene.rgba().buffer, numChannels: 4)));
    final photo = add(ImageEntity(id: id(), origin: const Pt(200, 0), width: 20, height: 15, data: png, name: 'drone.png'));
    final loader = ProjectController.demUrlLoader;
    addTearDown(() => ProjectController.demUrlLoader = loader);
    ProjectController.demUrlLoader = (url) async {
      final u = Uri.parse(url);
      final lats = u.queryParameters['latitude']!.split(',');
      return jsonEncode({
        'elevation': [for (final _ in lats) 640.0],
      });
    };
    final (fake, t) = await turn(tester, [
      ops([
        ('generate_contours', {'interval_m': 1}),
        (
          'show_profile',
          {
            'pts': [
              [0, 0],
              [40, 0],
            ],
          },
        ),
        ('clear_profile', <String, dynamic>{}),
        ('set_georeference', {'mode': 'utm', 'zone': 23, 'north': false, 'easting_m': 500000, 'northing_m': 7500000}),
        ('get_georeference', <String, dynamic>{}),
        (
          'place_image',
          {
            'id': photo.id,
            'origin': [300, 0],
            'width_m': scene.widthM,
          },
        ),
        ('detect_vegetation', {'image': photo.id, 'preview_only': true}),
      ]),
      ops([
        ('detect_vegetation', {'image': photo.id}),
        ('download_elevations', {'source': 'openMeteo', 'spacing_m': 20, 'contours': false}),
        ('remove_own_terrain_data', <String, dynamic>{}),
      ]),
    ], approve: (call) => Approval.apply);
    expect(t.calls.every((x) => x.state == ToolCallState.done), isTrue, reason: '${fake.lastUserText(1)}\n${fake.lastUserText(2)}');
    final out = fake.lastUserText(1);
    expect(c.project.entities.whereType<ContourEntity>().where((x) => x.derived), isNotEmpty);
    expect(out, contains('Profile 40.0 m: from 100.00 m to 104.00 m'));
    expect(c.profilePath, isNull, reason: 'shown, then cleared');
    expect(out, contains('SIRGAS 2000 / UTM 23S'), reason: '1.6.0 PRD: the datum of a site in Brazil');
    expect(c.project.meta.georef?.zone, 23);
    final placed = c.project.byId(photo.id) as ImageEntity;
    expect(placed.origin, const Pt(300, 0));
    expect(placed.width, scene.widthM);
    expect(placed.height, closeTo(scene.widthM * 15 / 20, 1e-9), reason: 'the proportions kept');
    expect(out, contains('Preview (nothing added)'));
    final out2 = fake.lastUserText(2);
    expect(c.project.entities.whereType<AreaEntity>(), isNotEmpty, reason: out2);
    expect(out2, contains('elevation points from Open-Meteo'));
    expect(c.project.entities.whereType<SpotHeightEntity>().where((s) => !s.isDem), isEmpty, reason: 'the own data removed after the confirmation');
    expect(c.project.entities.whereType<SpotHeightEntity>().where((s) => s.isDem), isNotEmpty);
    // the georeference is an undo step like any change
    final before = c.historyIndex;
    expect(before, greaterThan(0));
  });

  testWidgets('imports: a PDF plan at its scale and an attached project', (tester) async {
    final src = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    src.newProject();
    await src.setLanguage('en', persist: false);
    src.addEntity(LineEntity(id: src.project.newId(), a: Pt.zero, b: const Pt(40, 0)));
    src.addEntity(PolylineEntity(id: src.project.newId(), points: [Pt.zero, const Pt(40, 0), const Pt(40, 30), const Pt(0, 30)], closed: true));
    final pdf = src.exporter().exportDrawing(DrawingFormat.pdf) as Uint8List;
    host.files['plan.pdf'] = pdf;
    final (fake, t) = await turn(tester, [
      ops([
        ('import_pdf_attachment', {'name': 'plan.pdf', 'scale': 200, 'texts': false}),
        ('import_pdf_attachment', {'name': 'missing.pdf'}),
      ]),
    ]);
    final out = fake.lastUserText(1);
    expect(t.calls.first.state, ToolCallState.done, reason: out);
    expect(out, contains('Imported page 1 of "plan.pdf" at 1:200'));
    expect(c.project.entities, isNotEmpty);
    expect(c.selection, isNotEmpty, reason: 'the plan is selected for the alignment');
    expect(t.calls.last.state, ToolCallState.failed);
    expect(out, contains('No attached file "missing.pdf"'));
  });

  testWidgets('run_operation takes the effect of the operation: approvals in ask mode, refusals in read-only and plan', (tester) async {
    final l = add(LineEntity(id: id(), a: Pt.zero, b: const Pt(10, 0)));
    final asked = <AgentToolCall>[];
    var (fake, t) = await turn(
      tester,
      [
        ops([
          (
            'offset_entities',
            {
              'ids': [l.id],
              'distance_m': 1,
            },
          ),
          (
            'offset_entities',
            {
              'ids': [l.id],
              'distance_m': 5,
            },
          ),
          ('list_layers', <String, dynamic>{}),
          ('offset_entities', {'ids': 'nope', 'distance_m': 1}),
          ('no_such_operation', <String, dynamic>{}),
        ]),
      ],
      permission: AgentPermission.ask,
      approve: (call) {
        asked.add(call);
        return asked.length == 1 ? Approval.apply : Approval.skip;
      },
    );
    expect(asked, hasLength(2), reason: 'only the changes are asked; reads and invalid calls are not');
    expect(asked.first.summary, 'Offset 1 items');
    expect(asked.first.effect, ToolEffect.write);
    expect(c.project.entities.whereType<LineEntity>(), hasLength(2), reason: 'the first applied, the second declined');
    var out = fake.lastUserText(1);
    expect(out, contains('declined'));
    expect(t.calls[2].effect, ToolEffect.read);
    expect(t.calls[2].state, ToolCallState.done);
    expect(out, contains('"input.ids" must be of type array'));
    expect(out, contains('Input of offset_entities: {ids*'));
    expect(out, contains('Unknown operation "no_such_operation"'));
    // read-only: changes refused without asking, reads run
    asked.clear();
    (fake, t) = await turn(
      tester,
      [
        ops([
          (
            'offset_entities',
            {
              'ids': [l.id],
              'distance_m': 1,
            },
          ),
          ('get_history', <String, dynamic>{}),
        ]),
      ],
      permission: AgentPermission.readOnly,
      approve: (call) {
        asked.add(call);
        return Approval.apply;
      },
    );
    expect(asked, isEmpty);
    expect(fake.lastUserText(1), contains('read-only'));
    expect(t.calls.last.state, ToolCallState.done);
    expect(c.project.entities.whereType<LineEntity>(), hasLength(2));
    // plan mode: no change before the plan is approved
    (fake, t) = await turn(tester, [
      ops([('undo', <String, dynamic>{})]),
    ], permission: AgentPermission.plan);
    expect(fake.lastUserText(1), contains('plan mode'));
    // auto: exports and confirmed operations still ask
    asked.clear();
    c.select([l.id]);
    (fake, t) = await turn(
      tester,
      [
        ops([
          ('selection_bom', {'csv': true}),
          ('remove_own_terrain_data', <String, dynamic>{}),
          ('selection_bom', <String, dynamic>{}),
        ]),
      ],
      approve: (call) {
        asked.add(call);
        return Approval.skip;
      },
    );
    expect(asked.map((x) => x.effect), [ToolEffect.export, ToolEffect.write], reason: 'the CSV file and the removal of the user\'s data are confirmed; the plain list is not');
    expect(t.calls.last.state, ToolCallState.done);
    final runOp = box.tools.firstWhere((x) => x.name == 'run_operation');
    expect(runOp.effectOf({'name': 'list_layers', 'input': <String, dynamic>{}}), ToolEffect.read);
    expect(
      runOp.effectOf({
        'name': 'clipboard',
        'input': {'action': 'copy'},
      }),
      ToolEffect.read,
    );
    expect(
      runOp.effectOf({
        'name': 'clipboard',
        'input': {'action': 'paste'},
      }),
      ToolEffect.write,
    );
    expect(
      runOp.mustConfirm({
        'name': 'close_tab',
        'input': {'index': 1},
      }),
      isTrue,
    );
  });

  testWidgets('run_command: aliases act, dialogs run headless, drawing tools say what to call', (tester) async {
    final l = add(LineEntity(id: id(), a: Pt.zero, b: const Pt(10, 0)));
    final asked = <AgentToolCall>[];
    c.select([l.id]);
    final snap = c.snap.enabled;
    var linesAfterArray = 0;
    FakeReply Function(Map<String, dynamic>) cmds(List<Map<String, dynamic>> calls) =>
        (_) => FakeReply.tools([for (final x in calls) ('run_command', x)]);
    final (fake, t) = await turn(
      tester,
      [
        cmds([
          {'command': 'z'},
          {'command': 'OS'},
          {
            'command': 'GRID',
            'input': {'on': false},
          },
          {'command': 'L'},
          {'command': 'polyline', 'activate_tool': true},
          {'command': 'ARRAY'},
          {
            'command': 'ARRAY',
            'input': {'rows': 1, 'cols': 3, 'col_spacing_m': 20},
          },
          {'command': 'CHK'},
          {'command': 'DENS'},
          {'command': '?'},
          {'command': 'XYZZY'},
          {'command': 'SAVE'},
          {'command': 'FIX'},
          {'command': 'INSERT'},
        ]),
        (_) {
          linesAfterArray = c.project.entities.whereType<LineEntity>().length;
          return FakeReply.tools([
            ('run_command', {'command': 'U'}),
            ('run_command', {'command': 'selectAll'}),
            ('run_command', {'command': 'E'}),
          ]);
        },
      ],
      approve: (call) {
        asked.add(call);
        return Approval.skip;
      },
    );
    final out = fake.lastUserText(1);
    expect(out, contains('whole drawing'));
    expect(c.snap.enabled, !snap);
    expect(c.showGrid, isFalse);
    expect(out, contains('do it with create_entities {type: "line"'));
    expect(c.activeTool, ToolId.polyline);
    expect(out, contains('The Array dialog runs array_entities'), reason: 'an array changes the project: without input it says what it needs');
    expect(linesAfterArray, 1 + 2, reason: 'the second ARRAY ran with its input on the selection');
    expect(out, contains('Design check:'));
    expect(out, contains('Commands of the command line'));
    expect(out, contains('Unknown command "XYZZY"'));
    expect(asked.map((x) => x.effect).toList(), [ToolEffect.export], reason: 'SAVE saves a file: confirmed even in auto mode (and declined here)');
    expect(out, contains('No message offers an automatic correction'));
    expect(out, contains('The Insert block dialog runs insert_block'));
    expect(t.calls.firstWhere((x) => x.input['command'] == 'z').effect, ToolEffect.read);
    expect(t.calls.firstWhere((x) => x.input['command'] == 'E').effect, ToolEffect.write);
    expect(c.project.entities, isEmpty, reason: 'U took back the array, ALL selected the line, E erased it');
  });

  testWidgets('settings: typed reads and writes, ranges, follow-ups, project settings undoable, view settings not', (tester) async {
    final hist = c.historyIndex;
    final (fake, t) = await turn(tester, [
      (_) => FakeReply.tools([
        ('get_setting', {'prefix': 'snap.'}),
        (
          'set_setting',
          {
            'values': {'snap.ortho': true, 'view.overlay': 'pressure', 'tool.outlet_spec': 'rotor', 'view.base_map_opacity': 0.5},
          },
        ),
        (
          'set_setting',
          {
            'values': {'units.flow': 'm3h', 'quote.markup_pct': 12.5, 'project.client': 'Fazenda Boa Vista'},
          },
        ),
        (
          'set_setting',
          {
            'values': {'params.maxZoneVelocity': 1.8},
          },
        ),
        (
          'set_setting',
          {
            'values': {'snap.grid_size_m': -1},
          },
        ),
        (
          'set_setting',
          {
            'values': {'view.overlay': 'nope'},
          },
        ),
        (
          'set_setting',
          {
            'values': {'view.scale': 3},
          },
        ),
        (
          'set_setting',
          {
            'values': {'snap.orto': true},
          },
        ),
        (
          'set_setting',
          {
            'values': {'tool.nozzle': 'nope'},
          },
        ),
        (
          'get_setting',
          {
            'keys': ['params.maxZoneVelocity', 'units.system', 'tool.nozzle'],
          },
        ),
      ]),
    ]);
    final out = fake.lastUserText(1);
    expect(out, contains('snap.ortho = false (boolean)'));
    expect(c.snap.ortho, isTrue);
    expect(c.overlay, OverlayMode.pressure);
    expect(c.baseMapOpacity, 0.5);
    expect(c.toolSettings.outletSpecId, 'rotor');
    expect(c.toolSettings.nozzleId, 'r1.5', reason: 'the first nozzle of the new emitter follows');
    expect(out, contains('tool.nozzle: "m50" → "r1.5" (follows tool.outlet_spec)'));
    expect(c.project.params.units.flow, FlowUnit.m3h);
    expect(c.project.proposal.markupPct, 12.5);
    expect(c.project.meta.client, 'Fazenda Boa Vista');
    expect(c.project.params.maxZoneVelocity, 1.8);
    expect(out, contains('snap.grid_size_m = -1 is outside 0.001 … 10000 m'));
    expect(out, contains('view.overlay must be one of none, velocity'));
    expect(out, contains('view.scale is read-only'));
    expect(out, contains('Unknown setting "snap.orto". Did you mean snap.ortho?'));
    expect(out, contains('Emitter "rotor" has no nozzle "nope"'));
    expect(out, contains('params.maxZoneVelocity = 1.8'));
    expect(out, contains('units.system = "custom"'));
    expect(c.historyIndex, hist + 2, reason: 'the project settings are one undo step, the parameters another; view and tool settings none');
    expect(t.calls[1].effect, ToolEffect.read, reason: 'view and tool settings change no project');
    expect(t.calls[2].effect, ToolEffect.write);
    c.undo();
    c.undo();
    expect(c.project.params.units.flow, FlowUnit.lph);
    expect(c.project.meta.client, isEmpty);
    expect(c.snap.ortho, isTrue, reason: 'not part of the project');
  });

  testWidgets('find_operations lists the groups, finds by words and describes the inputs', (tester) async {
    final (fake, _) = await turn(tester, [
      (_) => FakeReply.tools([
        ('find_operations', <String, dynamic>{}),
        ('find_operations', {'query': 'revision cloud'}),
        ('find_operations', {'group': 'history', 'limit': 2}),
        (
          'find_operations',
          {
            'names': ['trim_entity'],
          },
        ),
        ('find_operations', {'query': 'zzzz'}),
      ]),
    ]);
    final out = fake.lastUserText(1);
    expect(out, contains('edit: offset_entities, trim_entity'));
    expect(out, contains('## add_revision_cloud (annotate; write)'));
    expect(RegExp(r'## (\w+)').allMatches(out.split('## add_revision_cloud').first).length, lessThanOrEqualTo(1));
    expect(out, contains('Also: '));
    expect(out, contains('Input: {id*: string — Item to trim (id or name).; at*: [number] — A point on the part to remove (m).'));
    expect(out, contains('No operation matches "zzzz"'));
    expect(compactSchema({'type': 'object'}), '{}');
    expect(commandsListing().length, lessThan(16000), reason: 'run_command "?" fits in one tool result');
    final all = await box.tools.firstWhere((x) => x.name == 'get_setting').run(<String, dynamic>{});
    expect(all.text.length, lessThan(16000), reason: 'every setting at once fits in one tool result');
    expect(all.text, contains('settings, key = value'));
  });
}
