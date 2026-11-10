import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/state/new_project_prefs.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/design/reservoir.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

import 'support/fake_claude.dart';

class _Host implements AgentHost {
  @override
  AgentPermission permission = AgentPermission.auto;
  @override
  bool stopped = false;
  @override
  String notes = '';
  @override
  final Map<String, Uint8List> files = {};
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
  bool openTab(Project p) => false;
}

/// Operations of the AI assistant for the model, reservoirs and pump
/// stations, through the scripted model and the real agent loop: the
/// islands of an irrigated area (set, and cut by a shape), a project file
/// inserted into the open one, what new projects start with on this device,
/// the reservoir of a water supply with its study, a pump item made a
/// station of several pumps with the duty of each after a design, and the
/// zones run at the pressure the mainline really gives them. A change is
/// one undo step, and a call that cannot be done says why and changes
/// nothing.
void main() {
  late ProjectController c;
  late _Host host;
  late AgentToolbox box;

  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    host = _Host();
    box = AgentToolbox(c, host: host);
  });
  tearDown(() {
    for (final k in const [newProjectParamsPref, newProjectCurrencyPref, newProjectHzPref, newProjectUnitsPref]) {
      removePref(k);
    }
  });

  /// One turn of the scripted model calling [calls] at once, then "done":
  /// what went back to the model (the whole answers) and the turn.
  Future<(String, AgentTurn)> turn(WidgetTester tester, List<(String, Map<String, dynamic>)> calls) async {
    final fake = FakeClaude([(_) => FakeReply.tools(calls), (_) => FakeReply.text('done')]);
    AgentTurn? out;
    await tester.runAsync(() async {
      out = await AgentLoop(
        api: AnthropicClient(apiKey: 'sk-ant-test', transport: fake.call, sleep: (_) async {}),
        tools: box.operations,
      ).run(model: AiModel.opus55, system: 's', history: const [], user: AnthropicFormat.user([AiTextPart('go')]), permission: AgentPermission.auto, cancel: AiCancel(), events: AgentEvents());
    });
    return (fake.lastUserText(1), out!);
  }

  /// The answer of the one operation called, which was carried out.
  Future<String> done(WidgetTester tester, String name, Map<String, dynamic> input) async {
    final (text, t) = await turn(tester, [(name, input)]);
    expect(t.calls.single.state, ToolCallState.done, reason: '$name: $text');
    return text;
  }

  /// What the one operation called answers when it refuses; the project is
  /// as it was (no undo step).
  Future<String> refused(WidgetTester tester, String name, Map<String, dynamic> input) async {
    final steps = c.historyEntries.length;
    final before = jsonEncode(c.project.toJson()['entities']);
    final (text, t) = await turn(tester, [(name, input)]);
    expect(t.calls.single.state, ToolCallState.failed, reason: '$name: $text');
    expect(c.historyEntries.length, steps, reason: name);
    expect(jsonEncode(c.project.toJson()['entities']), before, reason: name);
    return text;
  }

  T add<T extends Entity>(T e) {
    c.project.entities.add(e);
    c.entitiesChanged();
    return e;
  }

  List<Pt> rect(double x0, double y0, double w, double h) => [Pt(x0, y0), Pt(x0 + w, y0), Pt(x0 + w, y0 + h), Pt(x0, y0 + h)];
  List<List<double>> pts(List<Pt> p) => [
    for (final q in p) [q.x, q.y],
  ];

  testWidgets('set_area_holes: the islands leave the surface of the area, [] puts it back, one undo step each', (tester) async {
    final a = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100), name: 'Field'));
    expect(a.area, 10000);
    final steps = c.historyEntries.length;
    final said = await done(tester, 'set_area_holes', {
      'area': a.id,
      'holes': [pts(rect(10, 10, 20, 10)), pts(rect(50, 50, 10, 10))],
    });
    expect(a.holes, [rect(10, 10, 20, 10), rect(50, 50, 10, 10)]);
    expect(a.area, 10000 - 200 - 100);
    expect(a.grossArea, 10000);
    expect(said, contains('${a.id} «Field»: 0.9700 ha irrigated of 1.0000 ha inside the outline, 2 island(s), 4 vertices'));
    expect(c.historyEntries.length, steps + 1);
    c.undo();
    expect((c.project.byId(a.id)! as AreaEntity).holes, isEmpty);
    c.redo();
    final again = c.project.byId(a.id)! as AreaEntity;
    expect(again.holes, hasLength(2));
    // by name, and no islands
    final cleared = await done(tester, 'set_area_holes', {'area': 'Field', 'holes': <Object>[]});
    expect((c.project.byId(a.id)! as AreaEntity).holes, isEmpty);
    expect(cleared, contains('1.0000 ha irrigated, 4 vertices'));
  });

  testWidgets('set_area_holes refuses what is not an island of an area', (tester) async {
    final a = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100)));
    final j = add(JunctionEntity(id: c.project.newId(), position: const Pt(5, 5)));
    expect(await refused(tester, 'set_area_holes', {'area': j.id, 'holes': <Object>[]}), contains('not an irrigated area'));
    expect(await refused(tester, 'set_area_holes', {'area': a.id, 'holes': 'none'}), contains('"input.holes" must be of type array'));
    expect(
      await refused(tester, 'set_area_holes', {
        'area': a.id,
        'holes': [pts(rect(90, 90, 20, 20))],
      }),
      contains('"holes[0]" is not inside the outline of ${a.id}'),
    );
    expect(
      await refused(tester, 'set_area_holes', {
        'area': a.id,
        'holes': [
          pts(rect(10, 10, 5, 5)),
          [
            [20, 20],
            [30, 30],
            [40, 40],
          ],
        ],
      }),
      contains('"holes[1]" encloses no surface'),
    );
    expect(
      await refused(tester, 'set_area_holes', {
        'area': a.id,
        'holes': [
          [
            [20, 20],
            [30, 30],
          ],
        ],
      }),
      contains('holes[0]'),
    );
    expect(a.holes, isEmpty);
  });

  testWidgets('subtract_from_area: a polygon inside becomes an island; a drawn shape is used up unless kept', (tester) async {
    final a = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100), name: 'Field'));
    final steps = c.historyEntries.length;
    final said = await done(tester, 'subtract_from_area', {'pts': pts(rect(40, 40, 10, 10))});
    var now = c.project.byId(a.id)! as AreaEntity;
    expect(now.holes, hasLength(1));
    expect(now.area, closeTo(9900, 1e-6));
    expect(said, startsWith('1 area(s) after the cut:'));
    expect(said, contains('0.9900 ha irrigated of 1.0000 ha inside the outline, 1 island(s)'));
    expect(c.historyEntries.length, steps + 1);
    c.undo();
    expect((c.project.byId(a.id)! as AreaEntity).holes, isEmpty);
    // a closed polyline drawn in the project: cut, and deleted with the same undo step
    final pond = add(PolylineEntity(id: c.project.newId(), points: rect(10, 10, 20, 20), closed: true));
    final withShape = await done(tester, 'subtract_from_area', {'shape': pond.id, 'area': 'Field'});
    now = c.project.byId(a.id)! as AreaEntity;
    expect(now.area, closeTo(9600, 1e-6));
    expect(c.project.byId(pond.id), isNull);
    expect(withShape, contains('; the shape ${pond.id} was deleted'));
    c.undo();
    expect(c.project.byId(pond.id), isNotNull);
    expect((c.project.byId(a.id)! as AreaEntity).holes, isEmpty);
    // kept when asked
    final kept = await done(tester, 'subtract_from_area', {'shape': pond.id, 'keep_shape': true});
    expect(c.project.byId(pond.id), isNotNull);
    expect(kept, isNot(contains('was deleted')));
    expect((c.project.byId(a.id)! as AreaEntity).holes, hasLength(1));
  });

  testWidgets('subtract_from_area refuses a cut that changes nothing, a target that is not an area and a locked layer', (tester) async {
    final a = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100)));
    final j = add(JunctionEntity(id: c.project.newId(), position: const Pt(5, 5)));
    expect(await refused(tester, 'subtract_from_area', {'pts': pts(rect(500, 500, 10, 10))}), contains('No irrigated area meets the shape.'));
    expect(await refused(tester, 'subtract_from_area', {'pts': pts(rect(40, 40, 10, 10)), 'area': j.id}), contains('not an irrigated area'));
    expect(await refused(tester, 'subtract_from_area', {'area': a.id}), contains('Give "shape"'));
    expect(await refused(tester, 'subtract_from_area', {'shape': j.id}), contains('is not a closed shape'));
    // inside an island already: nothing left to take
    await done(tester, 'subtract_from_area', {'pts': pts(rect(40, 40, 20, 20))});
    expect(await refused(tester, 'subtract_from_area', {'pts': pts(rect(45, 45, 5, 5)), 'area': a.id}), contains('does not cut the area'));
    // the layer of the area locked
    c.project.layerNamed(a.layer).locked = true;
    expect(await refused(tester, 'subtract_from_area', {'pts': pts(rect(5, 5, 10, 10))}), contains('Areas on locked layers: ${a.id}'));
  });

  testWidgets('insert_project: the items of an attached project file come in with new ids, selected, as one undo step', (tester) async {
    final other = ProjectController()..autosaveEnabled = false;
    other.newProject();
    other.project.entities
      ..add(AreaEntity(id: other.project.newId(), points: rect(0, 0, 30, 20), name: 'Orchard'))
      ..add(JunctionEntity(id: other.project.newId(), position: const Pt(5, 5)));
    host.files['Orchard.oci.json'] = Uint8List.fromList(utf8.encode(other.saveJson()));
    host.files['notes.txt'] = Uint8List.fromList(utf8.encode('not a project'));
    final mine = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 10, 10)));
    final steps = c.historyEntries.length;
    final said = await done(tester, 'insert_project', {
      'name': 'orchard.oci.json',
      'offset': [100, 50],
    });
    final added = c.project.entities.where((e) => e.id != mine.id).toList();
    expect(added, hasLength(2));
    final area = added.whereType<AreaEntity>().single;
    expect(area.name, 'Orchard');
    expect(area.points, rect(100, 50, 30, 20));
    expect(added.whereType<JunctionEntity>().single.position, const Pt(105, 55));
    expect(c.selection.toSet(), {for (final e in added) e.id});
    expect(said, contains('From orchard.oci.json:'));
    expect(said, contains('moved by'));
    expect(said, endsWith('Now selected.'));
    expect(c.historyEntries.length, steps + 1);
    c.undo();
    expect(c.project.entities.map((e) => e.id), [mine.id]);
    // without an offset the items stay where they were drawn
    expect(await done(tester, 'insert_project', {'name': 'Orchard.oci.json'}), contains('as drawn'));
    expect(c.project.entities.whereType<AreaEntity>().firstWhere((e) => e.name == 'Orchard').points, rect(0, 0, 30, 20));
  });

  testWidgets('insert_project refuses a file that was not attached and one that is not a project', (tester) async {
    expect(await refused(tester, 'insert_project', {'name': 'a.oci.json'}), contains('No file was attached in this conversation.'));
    host.files['notes.txt'] = Uint8List.fromList(utf8.encode('not a project'));
    expect(await refused(tester, 'insert_project', {'name': 'a.oci.json'}), contains('No attached file "a.oci.json". Attached: notes.txt.'));
    expect(await refused(tester, 'insert_project', {'name': 'notes.txt'}), contains('is not an OpenCADIrrigation project file'));
  });

  testWidgets('new_project_defaults: shown, kept on this device and forgotten', (tester) async {
    expect(c.hasNewProjectChoices, isFalse);
    final shown = await done(tester, 'new_project_defaults', const {});
    expect(shown, '${c.newProjectDefaultsText()} (no choice kept on this device)');
    c.project.params.mainsHz = 50;
    final saved = await done(tester, 'new_project_defaults', {'action': 'save'});
    expect(c.hasNewProjectChoices, isTrue);
    expect(getPref(newProjectHzPref), '50');
    expect(saved, c.newProjectDefaultsText());
    expect(saved, isNot(contains('no choice kept')));
    final cleared = await done(tester, 'new_project_defaults', {'action': 'clear'});
    expect(c.hasNewProjectChoices, isFalse);
    expect(getPref(newProjectHzPref), isNull);
    expect(cleared, endsWith('(no choice kept on this device)'));
    expect(await refused(tester, 'new_project_defaults', {'action': 'reset'}), isNotEmpty);
  });

  testWidgets('set_reservoir and reservoir_study: an excavated reservoir of a water supply, its volume and curve, and its removal', (tester) async {
    final s = add(WaterSupplyEntity(id: c.project.newId(), position: const Pt(-10, 10)));
    final pond = add(PolylineEntity(id: c.project.newId(), points: rect(0, 0, 40, 30), closed: true));
    expect(await done(tester, 'reservoir_study', {'supply': s.id}), '${s.id} has no reservoir (set_reservoir gives it one).');
    final steps = c.historyEntries.length;
    final said = await done(tester, 'set_reservoir', {
      'supply': s.id,
      'outline': pond.id,
      'kind': 'excavated',
      'full_level_m': 100,
      'bottom_m': 97,
      'side_slope': 2,
      'min_level_m': 98,
      'initial_level_m': 99.5,
      'inflow_m3h': 36,
    });
    final r = (c.project.byId(s.id)! as WaterSupplyEntity).reservoir!;
    expect((r.outlineId, r.kind, r.fullLevelM, r.bottomM, r.sideSlope, r.minLevelM, r.initialLevelM), (pond.id, ReservoirKind.excavated, 100.0, 97.0, 2.0, 98.0, 99.5));
    expect(r.inflow, closeTo(0.01, 1e-12));
    expect(c.historyEntries.length, steps + 1);
    // the numbers of the answer are those of the engine's study
    final st = reservoirStudy(c.project, c.project.byId(s.id)! as WaterSupplyEntity)!;
    expect(st.bottom, 97);
    // 40 × 30 at the top, sides 2:1 over 3 m: 28 × 18 at the bottom
    expect(st.volume, greaterThan(28 * 18 * 3));
    expect(st.volume, lessThan(40 * 30 * 3));
    expect(st.usableVolume, lessThan(st.volume));
    expect(said, startsWith('${s.id}: reservoir excavated bounded by ${pond.id}, full at 100.00 m; bottom 97.00 m, '));
    expect(said, contains('${st.volume.round()} m³ full'));
    expect(said, contains('${st.usableVolume.round()} m³ usable'));
    final study = await done(tester, 'reservoir_study', {'supply': s.id});
    expect(study, startsWith('Reservoir of ${s.id}: bottom 97.00 m, full 100.00 m, lowest operating 98.00 m;'));
    expect(study, contains('No design results: run_design gives the daily demand.'));
    expect(study, contains('Inflow'));
    expect(study, contains('level m'));
    // the stage curve of the study, a row per level, up to the full volume
    expect(st.curve.length, greaterThan(3));
    for (final row in st.curve) {
      expect(study, contains(row.level.toStringAsFixed(2)), reason: 'level ${row.level}');
    }
    expect(study, contains('${st.curve.last.volume.round()}'));
    // one field changed: the others stay
    await done(tester, 'set_reservoir', {'supply': s.id, 'full_level_m': 101});
    final r2 = (c.project.byId(s.id)! as WaterSupplyEntity).reservoir!;
    expect((r2.outlineId, r2.kind, r2.fullLevelM, r2.bottomM), (pond.id, ReservoirKind.excavated, 101.0, 97.0));
    // removed, and undone
    expect(await done(tester, 'set_reservoir', {'supply': s.id, 'remove': true}), startsWith('${s.id}: no reservoir now.'));
    expect((c.project.byId(s.id)! as WaterSupplyEntity).reservoir, isNull);
    c.undo();
    expect((c.project.byId(s.id)! as WaterSupplyEntity).reservoir?.fullLevelM, 101);
  });

  testWidgets('set_reservoir refuses a supply that is not one, a missing or open outline, an unknown kind and a locked layer', (tester) async {
    final s = add(WaterSupplyEntity(id: c.project.newId(), position: const Pt(-10, 10)));
    final j = add(JunctionEntity(id: c.project.newId(), position: const Pt(5, 5)));
    final line = add(PolylineEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(10, 0)]));
    final pond = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 40, 30)));
    expect(await refused(tester, 'set_reservoir', {'supply': j.id, 'outline': pond.id}), contains('${j.id} is not a water supply.'));
    expect(await refused(tester, 'reservoir_study', {'supply': j.id}), contains('${j.id} is not a water supply.'));
    expect(await refused(tester, 'set_reservoir', {'supply': s.id}), contains('Give "outline"'));
    expect(await refused(tester, 'set_reservoir', {'supply': s.id, 'outline': line.id}), contains('${line.id} is not a closed polyline or an area.'));
    expect(await refused(tester, 'set_reservoir', {'supply': s.id, 'outline': pond.id, 'kind': 'lake'}), isNotEmpty);
    c.project.layerNamed(s.layer).locked = true;
    expect(await refused(tester, 'set_reservoir', {'supply': s.id, 'outline': pond.id}), contains('${s.id} is on the locked layer'));
    expect((c.project.byId(s.id)! as WaterSupplyEntity).reservoir, isNull);
  });

  testWidgets('set_pump_station and pump_stations: a pump item made a station of three pumps, and the duty of each after a design', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    final pump = c.project.entities.whereType<PumpEntity>().single;
    final model = c.project.catalog.pump(pump.pumpSpecId)!.name;
    expect(await done(tester, 'pump_stations', const {}), 'No pump item stands for a station (set_pump_station makes one).');
    final single = await done(tester, 'pump_stations', {'pump': pump.id});
    expect(single, contains('a single pump ($model).'));
    expect(single, endsWith('No design results: run_design gives the duty of every pump.'));
    final steps = c.historyEntries.length;
    final said = await done(tester, 'set_pump_station', {
      'pump': pump.id,
      'units': [
        <String, dynamic>{},
        {'spec': pump.pumpSpecId, 'standby': true},
      ],
      'arrangement': 'parallel',
    });
    final st = (c.project.byId(pump.id)! as PumpEntity).station!;
    expect((st.units.length, st.dutyCount, st.standbyCount, st.arrangement, st.staged), (2, 2, 1, PumpArrangement.parallel, true));
    expect(said, contains('2 duty + 1 standby in parallel, staged by the flow: 1 $model (lead, duty); 2 $model (duty); 3 $model (standby).'));
    expect(said, endsWith('Results discarded: run the design again.'));
    expect(c.historyEntries.length, steps + 1);
    // after a design: what each pump of the station does in the system flow
    await tester.runAsync(() => c.runDesign());
    expect(c.results, isNotNull, reason: c.lastMessage);
    final duty = c.results!.systemFlows.expand((f) => f.stations).where((d) => d.entityId == pump.id).first;
    final report = await done(tester, 'pump_stations', const {});
    expect(report, contains('2 duty + 1 standby in parallel'));
    expect(report, contains('${duty.running} of ${duty.duty} duty pumps on'));
    expect(report, contains('standby'));
    expect(report, isNot(contains('No design results')));
    for (final head in ['pump', 'model', 'state', 'head m', 'efficiency %', 'kW']) {
      expect(report, contains(head));
    }
    // all duty pumps always on, in series; then no pumps after the lead: a single pump again
    await done(tester, 'set_pump_station', {'pump': pump.id, 'arrangement': 'series', 'staged': false});
    final st2 = (c.project.byId(pump.id)! as PumpEntity).station!;
    expect((st2.units.length, st2.arrangement, st2.staged), (2, PumpArrangement.series, false));
    expect(c.results, isNull, reason: 'the results go with the change');
    expect(await done(tester, 'set_pump_station', {'pump': pump.id, 'units': <Object>[], 'arrangement': 'parallel', 'staged': true}), contains('a single pump ($model).'));
    expect((c.project.byId(pump.id)! as PumpEntity).station, isNull);
    c.undo();
    expect((c.project.byId(pump.id)! as PumpEntity).station?.units, hasLength(2));
  });

  testWidgets('set_pump_station refuses what is not a pump, a model the catalogue does not have and a locked layer', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    final pump = c.project.entities.whereType<PumpEntity>().single;
    final valve = c.project.entities.whereType<ControlValveEntity>().first;
    expect(await refused(tester, 'set_pump_station', {'pump': valve.id}), contains('${valve.id} is not a pump item.'));
    expect(await refused(tester, 'pump_stations', {'pump': valve.id}), contains('${valve.id} is not a pump item.'));
    expect(
      await refused(tester, 'set_pump_station', {
        'pump': pump.id,
        'units': [
          {'spec': 'no-such-pump'},
        ],
      }),
      contains('units[0]: no catalogue pump "no-such-pump"'),
    );
    expect(await refused(tester, 'set_pump_station', {'pump': pump.id, 'arrangement': 'triangle'}), isNotEmpty);
    c.project.layerNamed(pump.layer).locked = true;
    expect(
      await refused(tester, 'set_pump_station', {
        'pump': pump.id,
        'units': <Object>[<String, dynamic>{}],
      }),
      contains('${pump.id} is on the locked layer'),
    );
    expect((c.project.byId(pump.id)! as PumpEntity).station, isNull);
  });

  testWidgets('real_zone_operation: every zone of a designed project at the pressure the mainline gives it', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    expect(await refused(tester, 'real_zone_operation', const {}), isNotEmpty, reason: 'no design results yet');
    await tester.runAsync(() => c.runDesign());
    expect(c.results, isNotNull, reason: c.lastMessage);
    final flows = c.results!.systemFlows;
    final all = await done(tester, 'real_zone_operation', const {});
    for (final f in flows) {
      expect(all, contains('${f.name}:'));
    }
    for (final head in ['zone', 'design m³/h', 'real m³/h', 'delivered %', 'needs m', 'gets m', 'EU %', 'status']) {
      expect(all, contains(head));
    }
    final zones = [for (final v in c.project.entities.whereType<ControlValveEntity>()) v.zoneName];
    expect(zones, isNotEmpty);
    for (final z in zones) {
      expect(all, contains(z), reason: 'the zone $z');
    }
    // one flow by its name, and a flow that does not exist
    final one = await done(tester, 'real_zone_operation', {'flow': flows.first.name});
    expect(one, startsWith('${flows.first.name}:'));
    expect(await refused(tester, 'real_zone_operation', {'flow': 'no such flow'}), isNotEmpty);
  });
}
