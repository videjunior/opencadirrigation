import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_ops_cad.dart';
import 'package:opencadirrigation/app/ai/agent_ops_engineering.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ai_coverage.dart';
import 'package:opencadirrigation/app/ai/ops_cad_settings.dart' show aiSettings;
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/catalog_packs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

import 'support/fake_claude.dart';

/// The engineering operations of the AI assistant through the scripted model
/// and the real agent loop: the calculators of the Tools menu, the project
/// settings they edit, the machine of a pivot, the analyses of the network
/// with their options and "apply", the design management (alternatives,
/// programme, quote lines, check, reports), the catalogue and its packs,
/// the exports (always confirmed, written through the app's file sink) and
/// the automatic design with every option — every change one undo step —
/// and the coverage map of the engineering side.
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

void main() {
  late ProjectController c;
  late _Host host;
  late AgentToolbox box;
  late List<AgentTool> ops;
  final files = <String, Object>{};
  final approvals = <AgentToolCall>[];
  final saveFiles = engFileSink;

  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    host = _Host();
    box = AgentToolbox(c, host: host);
    ops = engineeringOperations(box);
    files.clear();
    approvals.clear();
    engFileSink = (c, name, mime, data) async => files[name] = data;
  });
  tearDown(() => engFileSink = saveFiles);

  /// One turn of the scripted model calling [calls] at once, then "done".
  Future<(String, AgentTurn)> turn(WidgetTester tester, List<(String, Map<String, dynamic>)> calls, {AgentPermission permission = AgentPermission.auto, Approval answer = Approval.apply}) async {
    final fake = FakeClaude([(_) => FakeReply.tools(calls), (_) => FakeReply.text('done')]);
    AgentTurn? out;
    await tester.runAsync(() async {
      out =
          await AgentLoop(
            api: AnthropicClient(apiKey: 'sk-ant-test', transport: fake.call, sleep: (_) async {}),
            tools: ops,
          ).run(
            model: AiModel.opus55,
            system: 's',
            history: const [],
            user: AnthropicFormat.user([AiTextPart('go')]),
            permission: permission,
            cancel: AiCancel(),
            events: AgentEvents(
              approve: (call) async {
                approvals.add(call);
                return answer;
              },
            ),
          );
    });
    return (fake.lastUserText(1), out!);
  }

  void allDone(AgentTurn t) {
    for (final call in t.calls) {
      expect(call.state, ToolCallState.done, reason: '${call.name}: ${call.result}');
    }
  }

  Future<void> design(WidgetTester tester) async {
    await tester.runAsync(() => c.runDesign());
    expect(c.results, isNotNull, reason: c.lastMessage);
  }

  AreaEntity area(List<Pt> pts, {String name = ''}) {
    final a = AreaEntity(id: c.project.newId(), points: pts, name: name);
    c.project.entities.add(a);
    c.entitiesChanged();
    return a;
  }

  List<Pt> rect(double x0, double y0, double w, double h) => [Pt(x0, y0), Pt(x0 + w, y0), Pt(x0 + w, y0 + h), Pt(x0, y0 + h)];

  testWidgets('the operations: unique names, descriptions, schemas, effects, summaries; the coverage routes exist', (tester) async {
    final names = [for (final o in ops) o.name];
    expect(names.toSet().length, names.length);
    expect(names.length, greaterThanOrEqualTo(50));
    final tools = {for (final t in box.tools) t.name};
    final cad = {for (final o in cadOperations(box)) o.name};
    for (final o in ops) {
      expect(tools.contains(o.name) || cad.contains(o.name), isFalse, reason: '${o.name} clashes with a tool or a drawing operation');
      expect(o.description.length, greaterThan(150), reason: o.name);
      expect(o.inputSchema['type'], 'object', reason: o.name);
      expect(o.inputSchema['additionalProperties'], isFalse, reason: o.name);
      expect(RegExp(r'^[a-z][a-z0-9_]+$').hasMatch(o.name), isTrue, reason: o.name);
      final summary = o.describe(const {});
      expect(summary.startsWith('ai.op.'), isFalse, reason: '${o.name}: $summary');
      if (o.name.startsWith('export_') || o.name == 'share_link') {
        expect(o.effectOf(const {}), ToolEffect.export, reason: o.name);
        expect(o.mustConfirm(const {}), isTrue, reason: '${o.name}: files are always confirmed');
      }
    }
    AgentTool op(String n) => ops.firstWhere((o) => o.name == n);
    expect(op('tariff_schedule').effectOf(const {}), ToolEffect.read);
    expect(op('tariff_schedule').effectOf(const {'apply': true}), ToolEffect.write);
    expect(op('air_valve_study').effectOf(const {'insert': true}), ToolEffect.write);
    expect(op('list_catalog_packs').effectOf(const {'url': 'https://example.com/index.json'}), ToolEffect.network);
    expect(op('design_alternatives').effectOf(const {'action': 'list'}), ToolEffect.read);
    expect(op('design_alternatives').mustConfirm(const {'action': 'restore', 'id': 'x'}), isTrue);
    expect(op('catalog_default').mustConfirm(const {'action': 'save'}), isTrue);
    // the whole catalogue replaced: confirmed whatever the mode (IA-14)
    expect(op('catalog_default').mustConfirm(const {'action': 'reset'}), isTrue);
    // an address outside the program's own site and repository: confirmed whatever the mode (IA-04)
    expect(op('list_catalog_packs').mustConfirm(const {'url': 'https://example.com/index.json'}), isTrue);
    expect(op('list_catalog_packs').mustConfirm(const {'url': 'https://opencadirrigation.com/catalogs/index.json'}), isFalse);
    expect(op('add_catalog_pack').mustConfirm(const {'url': 'https://example.com/x.oci.cat'}), isTrue);
    expect(op('add_catalog_pack').mustConfirm(const {'id': 'acme'}), isFalse);
    expect(op('list_catalog_packs').describe(const {'url': 'https://example.com/index.json'}), contains('example.com'));
    // every route of the engineering map reaches something that exists
    final allOps = {for (final o in box.operations) o.name};
    final settings = {for (final s in aiSettings(box)) s.key};
    for (final e in engineeringCoverage.entries) {
      expect(e.key, matches(RegExp(r'^(menu|panel|dialog):[\w.+]+$')), reason: e.key);
      final v = e.value;
      if (v.startsWith('tool:')) {
        expect(tools, contains(v.substring(5)), reason: e.key);
      } else if (v.startsWith('op:')) {
        expect(allOps, contains(v.substring(3)), reason: e.key);
      } else if (v.startsWith('n/a:')) {
        expect(v.length, greaterThan(15), reason: e.key);
      } else {
        expect(v, startsWith('setting:'), reason: e.key);
        expect(settings, contains(v.substring(8)), reason: e.key);
      }
      expect(coreCoverage.containsKey(e.key) || cadCoverage.containsKey(e.key), isFalse, reason: '${e.key} is mapped twice');
    }
    // every engineering operation is reached from the map
    final routed = {
      for (final v in aiCoverage.values)
        if (v.startsWith('op:')) v.substring(3),
    };
    for (final n in names) {
      expect(routed, contains(n), reason: '$n has no entry in the coverage map');
    }
  });

  testWidgets('calculators: lateral, pump, water hammer, solar pumping, wetted bulb, travelling gun, surface irrigation, gated pipe', (tester) async {
    final (text, t) = await turn(tester, [
      ('lateral_calculator', {'kind': 'tape', 'length_m': 120, 'inlet_head_m': 10, 'slope_pct': 1}),
      ('lateral_calculator', {'kind': 'emitter', 'emitter_spacing_m': 3, 'length_m': 60, 'inlet_head_m': 20}),
      ('pump_operating_point', {'static_head_m': 15, 'length_m': 300}),
      ('water_hammer_calculator', {'velocity_change_mps': 1.5, 'length_m': 800, 'closure_s': 1}),
      (
        'solar_pumping',
        {
          'daily_volume_m3': [40, 40, 35, 30, 25, 20, 20, 25, 30, 35, 40, 40],
          'head_m': 35,
          'latitude_deg': -20,
        },
      ),
      ('wetted_bulb', {'soil': 'sand', 'flow_lph': 4, 'volume_l': 12}),
      ('traveller_gun', {'target_depth_mm': 30, 'field_width_m': 400, 'wind': 'moderate'}),
      ('surface_irrigation', {'system': 'furrow', 'length_m': 200}),
      ('surface_irrigation', {'mode': 'evaluate', 'inflow_lps': 0.8, 'cutoff_min': 400}),
      ('gated_pipe', {'gates': 30, 'flow_per_gate_lps': 1.2, 'slope_pct': 0.2}),
    ]);
    allDone(t);
    expect(text, contains('Emitters:'));
    expect(text, contains('Longest lateral'));
    expect(text, contains('Shut-off head'));
    expect(text, contains('Wave speed'));
    expect(text, contains('Joukowsky'));
    expect(text, contains('Array:'));
    expect(text, contains('Critical month'));
    expect(text, contains('Wetted width'));
    expect(text, contains('Lane spacing'));
    expect(text, contains('Pressure at the hydrant'));
    expect(text, contains('Best inflow'));
    expect(text, contains('Application efficiency'));
    expect(text, contains('Inlet head used'));
    expect(c.historyIndex, 0, reason: 'the calculators change nothing');
    // the schema and the ranges are checked before anything runs
    final (bad, t2) = await turn(tester, [
      ('wetted_bulb', {'soil': 'mud'}),
      ('lateral_calculator', {'length_m': -5}),
      ('gated_pipe', {'gates': 3, 'colour': 'red'}),
    ]);
    expect(t2.calls.every((x) => x.state == ToolCallState.failed), isTrue);
    expect(bad, contains('must be one of'));
    expect(bad, contains('outside'));
    expect(bad, contains('Unknown field'));
  });

  testWidgets('water budget and site climate: hydrozones, cycle and soak, the climate typed and cleared, undo', (tester) async {
    final (none, t0) = await turn(tester, [('water_budget', {})]);
    expect(t0.calls.single.state, ToolCallState.failed);
    expect(none, contains('plant water use'));
    final a = area(rect(0, 0, 40, 25), name: 'Lawn')
      ..plantWaterUse = 'moderate'
      ..soilKey = 'soil.loam';
    final (text, t) = await turn(tester, [
      ('water_budget', {'eto_mm_year': 1400}),
      (
        'set_site_climate',
        {
          'eto_mm_day': [6, 6, 5.5, 4.5, 3.5, 3, 3, 4, 5, 5.5, 6, 6.5],
          'rain_mm': [200, 180, 150, 60, 30, 10, 10, 15, 50, 120, 160, 210],
        },
      ),
    ]);
    allDone(t);
    expect(text, contains('MAWA'));
    expect(text, contains('Lawn'));
    expect(text, contains('Cycle and soak'));
    expect(c.project.climate!.etoMmDay.first, 6);
    expect(c.project.climate!.source, 'manual');
    expect(a.plantWaterUse, 'moderate');
    final (budget, _) = await turn(tester, [('water_budget', {})]);
    expect(
      budget,
      contains('ETo ${fmt(6 * 31 + 6 * 28 + 5.5 * 31 + 4.5 * 30 + 3.5 * 31 + 3 * 30 + 3 * 31 + 4 * 31 + 5 * 30 + 5.5 * 31 + 6 * 30 + 6.5 * 31, 0)} mm/year'),
      reason: 'the year of the site climate',
    );
    c.undo();
    expect(c.project.climate, isNull, reason: 'one undo step');
    await turn(tester, [
      (
        'set_site_climate',
        {
          'eto_mm_day': [for (var m = 0; m < 12; m++) 5],
        },
      ),
    ]);
    expect(c.project.climate, isNotNull);
    await turn(tester, [
      ('set_site_climate', {'clear': true}),
    ]);
    expect(c.project.climate, isNull);
  });

  testWidgets('currency: converted at the reference rate or kept, undone; refused in plan mode, declined in ask mode', (tester) async {
    final from = c.project.params.currencyCode;
    final to = from == 'EUR' ? 'USD' : 'EUR';
    final price = c.project.catalog.pipes.first.costPerM;
    final (text, t) = await turn(tester, [
      ('set_currency', {'code': to}),
    ]);
    allDone(t);
    expect(c.project.params.currencyCode, to);
    expect(c.project.catalog.pipes.first.costPerM, isNot(closeTo(price, 1e-9)));
    expect(text, contains('prices converted'));
    c.undo();
    expect(c.project.params.currencyCode, from);
    expect(c.project.catalog.pipes.first.costPerM, closeTo(price, 1e-9));
    await turn(tester, [
      ('set_currency', {'code': 'JPY', 'convert_prices': false, 'symbol': '¥'}),
    ]);
    expect(c.project.params.currencyCode, 'JPY');
    expect(c.project.params.currency, '¥');
    expect(c.project.catalog.pipes.first.costPerM, closeTo(price, 1e-9));
    // in plan mode a change is refused; in ask mode the user may decline it
    final (plan, tp) = await turn(tester, [
      ('set_currency', {'code': 'BRL'}),
    ], permission: AgentPermission.plan);
    expect(tp.calls.single.state, ToolCallState.refused);
    expect(plan, contains('plan mode'));
    final (_, ta) = await turn(
      tester,
      [
        ('set_currency', {'code': 'BRL'}),
      ],
      permission: AgentPermission.ask,
      answer: Approval.skip,
    );
    expect(ta.calls.single.state, ToolCallState.skipped);
    expect(approvals.last.summary, 'Change the currency to BRL');
    expect(c.project.params.currencyCode, 'JPY');
  });

  testWidgets('pivot machine: read, changed as one undo step, the prescription saved as a confirmed file', (tester) async {
    loadExampleAction(c, ExampleId.pivot);
    await design(tester);
    final pivot = c.project.entities.whereType<PivotEntity>().first;
    final (read, t) = await turn(tester, [
      ('pivot_machine', {'pivot': pivot.id}),
    ]);
    allDone(t);
    expect(read, contains('## Package'));
    expect(read, contains('## Drive and timer'));
    expect(read, contains('Nozzle chart'));
    final steps = c.historyIndex;
    final (changed, t2) = await turn(tester, [
      (
        'set_pivot_machine',
        {
          'pivot': pivot.id,
          'timer_pct': 50,
          'tower_speed_m_min': 2.4,
          'voltage': 480,
          'vri_sectors': [
            [0, 90, 12],
            [90, 180, 20],
          ],
        },
      ),
    ]);
    allDone(t2);
    expect(changed, contains('Speed at 100 %'));
    var live = c.project.byId(pivot.id) as PivotEntity;
    expect(live.machine.timerPct, 50);
    expect(live.machine.vriSectors, hasLength(2));
    expect(c.historyIndex, steps + 1);
    final (saved, t3) = await turn(tester, [
      ('export_vri_prescription', {'pivot': pivot.id, 'compass': true}),
    ]);
    allDone(t3);
    expect(approvals.single.name, 'export_vri_prescription', reason: 'files are confirmed even when changes apply automatically');
    final csv = files.entries.single;
    expect(csv.key, endsWith('_vri.csv'));
    expect((csv.value as String).split('\n').where((l) => l.trim().isNotEmpty).length, greaterThan(2));
    expect(saved, contains('Saved'));
    c.undo();
    live = c.project.byId(pivot.id) as PivotEntity;
    expect(live.machine.timerPct, 100);
    expect(live.machine.vriSectors, isEmpty);
    // wrong inputs are refused before anything changes
    final (bad, t4) = await turn(tester, [
      ('set_pivot_machine', {'pivot': pivot.id, 'tyre_size': 'big'}),
      ('set_pivot_machine', {'pivot': pivot.id, 'end_gun_spec': 'rotor'}),
    ]);
    expect(t4.calls.every((x) => x.state == ToolCallState.failed), isTrue);
    expect(bad, contains('not a tyre size'));
    expect(bad, contains('not a gun'));
    expect(c.historyIndex, steps);
  });

  testWidgets('network analyses with their options: on demand, criticality, transients, 24 hours, air valves, calibration, fertigation', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await design(tester);
    final steps = c.historyIndex;
    final valve = c.project.entities.whereType<ControlValveEntity>().first;
    final (text, t) = await turn(tester, [
      (
        'on_demand_study',
        {
          'quality_pct': 90,
          'hours': {valve.id: 10},
          'random_configurations': 50,
        },
      ),
      ('criticality_study', {'pressure_driven': false}),
      (
        'transient_study',
        {
          'scenarios': ['valveClosure', 'pumpTrip'],
          'closure_s': 3,
          'pipes_limit': 5,
        },
      ),
      ('eps_day', {'price_per_kwh': 0.2, 'peak_factor': 2}),
      ('air_valve_study', {'max_spacing_m': 300, 'combination': false}),
      ('calibrate_roughness', {}),
      ('fertigation_plan', {'dose_kg_ha': 30, 'venturi_differential_m': 8}),
    ]);
    allDone(t);
    expect(text, contains('U(Pq)'));
    expect(text, contains('Random check'));
    expect(text, contains('total demand'));
    expect(text, contains('valveClosure'));
    expect(text, contains('Day:'));
    expect(text, contains('places'));
    expect(text, contains('Measuring points'));
    expect(text, contains('Plan: pre-wetting'));
    expect(text, contains('Venturi'));
    expect(c.historyIndex, steps, reason: 'the analyses change nothing');
    // a reading of the pressure at the valve: the fit, then applied
    final (cal, t2) = await turn(tester, [
      (
        'calibrate_roughness',
        {
          'pressures': [
            {'point': valve.id, 'head_m': 25, 'sigma_m': 0.3},
          ],
        },
      ),
    ]);
    allDone(t2);
    expect(cal, contains('C scale'));
    expect(c.historyIndex, steps);
  });

  testWidgets('apply options are one undo step each: tariff schedule, energy grouping, wire routes, air valves', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await tester.runAsync(() async {
      await AgentLoop(
        api: AnthropicClient(
          apiKey: 'sk-ant-test',
          transport: FakeClaude([
            (_) => FakeReply.tools([
              ('set_system_flows', {'mode': 'one_at_a_time', 'first_start_hour': 6}),
            ]),
            (_) => FakeReply.text('ok'),
          ]).call,
          sleep: (_) async {},
        ),
        tools: box.tools,
      ).run(model: AiModel.opus55, system: 's', history: const [], user: AnthropicFormat.user([AiTextPart('go')]), permission: AgentPermission.auto, cancel: AiCancel());
    });
    expect(c.project.systemFlows, hasLength(2));
    await design(tester);
    final starts = [for (final f in c.project.systemFlows) f.startHour];
    final (tariff, t) = await turn(tester, [
      (
        'tariff_schedule',
        {
          'base_price_per_kwh': 0.5,
          'bands': [
            {'from_h': 17, 'to_h': 22, 'price_per_kwh': 2, 'peak': true},
          ],
          'discount': 'custom',
          'custom_discount_pct': 70,
          'apply': true,
        },
      ),
    ]);
    allDone(t);
    expect(tariff, contains('Applied'));
    expect(tariff, contains('Discount blocks'));
    c.undo();
    expect([for (final f in c.project.systemFlows) f.startHour], starts);
    await design(tester);
    final steps = c.historyIndex;
    final (eg, t2) = await turn(tester, [
      ('energy_grouping_study', {'max_hours': 20, 'exact': false, 'apply': true}),
    ]);
    allDone(t2);
    expect(eg, contains('Applied'));
    expect(c.historyIndex, steps + 1, reason: 'one undo step');
    c.undo();
    expect(c.project.systemFlows, hasLength(2));
    final controllers = c.project.entities.whereType<ControllerEntity>().length;
    if (controllers > 0) {
      final wires = c.project.entities.whereType<WireEntity>().length;
      final (wr, t3) = await turn(tester, [
        ('wire_routing_study', {'mode': 'steiner', 'volts': 30, 'apply': true}),
      ]);
      allDone(t3);
      expect(wr, contains('Applied'));
      expect(wr, contains('Two-wire'));
      c.undo();
      expect(c.project.entities.whereType<WireEntity>().length, wires);
    }
    final valves = c.project.entities.whereType<MiscHydraulicEntity>().length;
    final (av, t4) = await turn(tester, [
      ('air_valve_study', {'max_spacing_m': 100, 'insert': true}),
    ]);
    allDone(t4);
    final added = c.project.entities.whereType<MiscHydraulicEntity>().length - valves;
    if (av.contains('Inserted')) {
      expect(added, greaterThan(0));
      c.undo();
      expect(c.project.entities.whereType<MiscHydraulicEntity>().length, valves);
    } else {
      expect(added, 0);
    }
    // the analyses that need results say so
    c.clearResults();
    final (need, t5) = await turn(tester, [('on_demand_study', {}), ('tariff_schedule', {})]);
    expect(t5.calls.every((x) => x.state == ToolCallState.failed), isTrue);
    expect(need, contains('run_design'));
  });

  testWidgets('densogram: options kept for the dialog, the map shown, the grid saved as a confirmed CSV', (tester) async {
    loadExampleAction(c, ExampleId.garden);
    final (text, t) = await turn(tester, [
      ('densogram', {'profile': 'elliptical', 'cell_m': 1, 'wind_mps': 2, 'wind_bearing_deg': 90, 'show': true}),
      ('export_densogram_csv', {}),
    ]);
    allDone(t);
    expect(text, contains('CU'));
    expect(text, contains('DU'));
    expect(c.densogramOptions.profile.name, 'elliptical');
    expect(c.densogramOptions.windTowardsDeg, closeTo(0, 1e-9), reason: 'towards the east');
    expect(c.overlay, OverlayMode.densogram);
    expect(approvals.map((x) => x.name), ['export_densogram_csv']);
    expect(files.keys.single, endsWith('_densogram.csv'));
    expect((files.values.single as String), startsWith('x;y;mm_h'));
  });

  testWidgets('design management: alternatives, controller programme, quote lines, check, results, reports, grade line', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await design(tester);
    final (text, t) = await turn(tester, [
      ('design_alternatives', {'action': 'save', 'name': 'PVC mains'}),
      ('controller_program', {'days': 3}),
      ('export_controller_program', {'days': 7}),
      (
        'set_quote_extras',
        {
          'action': 'add',
          'items': [
            {'description': 'Design fee', 'quantity': 1, 'unit_price': 900},
            {'description': 'Commissioning', 'unit': 'day', 'quantity': 2, 'unit_price': 300},
          ],
        },
      ),
      ('design_check', {}),
      ('show_report_tab', {'tab': 'bom'}),
      ('hydraulic_grade_line', {}),
    ]);
    allDone(t);
    expect(c.project.scenarios.single.name, 'PVC mains');
    expect(text, contains('PVC mains'));
    expect(text, contains('needs'));
    expect(files.keys.single, endsWith('_schedule.csv'));
    expect(approvals.map((x) => x.name), ['export_controller_program']);
    expect(c.project.proposal.extras.map((x) => x.description), ['Design fee', 'Commissioning']);
    expect(text, contains('Design check:'));
    expect(c.showReports, isTrue);
    expect(c.reportTab, 4);
    expect(text, contains('HGL start'));
    // the quote lines, one undo step a call
    await turn(tester, [
      (
        'set_quote_extras',
        {
          'action': 'update',
          'index': 0,
          'items': [
            {'description': 'Design', 'unit_price': 1000},
          ],
        },
      ),
    ]);
    expect(c.project.proposal.extras.first.unitPrice, 1000);
    c.undo();
    expect(c.project.proposal.extras.first.unitPrice, 900);
    // the programme's durations applied, then undone
    final durations = [for (final f in c.project.systemFlows) f.durationHours];
    final (prog, tp) = await turn(tester, [
      ('controller_program', {'apply_durations': true}),
    ]);
    if (tp.calls.single.state == ToolCallState.done) {
      expect(prog, contains('Applied'));
      c.undo();
      expect([for (final f in c.project.systemFlows) f.durationHours], durations);
    }
    // an alternative restored (confirmed), then deleted
    await design(tester);
    final pipes = c.project.entities.whereType<PipeEntity>().length;
    c.project.entities.removeWhere((e) => e is PipeEntity && e.scope == HydraulicScope.mainline);
    c.entitiesChanged();
    final (restored, t2) = await turn(tester, [
      ('design_alternatives', {'action': 'restore', 'id': 'PVC mains'}),
    ]);
    allDone(t2);
    expect(restored, contains('Restored'));
    expect(approvals.last.name, 'design_alternatives');
    expect(c.project.entities.whereType<PipeEntity>().length, pipes);
    expect(c.results, isNotNull, reason: 'its results come back with it');
    await turn(tester, [
      ('design_alternatives', {'action': 'delete', 'id': 'PVC mains'}),
    ]);
    expect(c.project.scenarios, isEmpty);
    c.undo();
    expect(c.project.scenarios, hasLength(1));
    await turn(tester, [('clear_results', {})]);
    expect(c.results, isNull);
  });

  testWidgets('catalogue: fittings, detail fields, duplicates, nozzle curve and profile, imports, exports, packs, default', (tester) async {
    final cat = c.project.catalog;
    final rotor = cat.outlet('rotor')!;
    final nozzle = rotor.nozzles.first;
    final pump = cat.pumps.first;
    final pipe = cat.pipes.first;
    final nFittings = cat.fittings.length, nPipes = cat.pipes.length;
    final (text, t) = await turn(tester, [
      (
        'catalog_fittings',
        {
          'action': 'add',
          'item': {'kind': 'tee', 'size_mm': 63, 'size2_mm': 32, 'cost': 7.5, 'name': 'Tee 63×32'},
        },
      ),
      ('catalog_item_details', {'kind': 'emitter', 'id': 'rotor', 'nozzle': nozzle.id, 'cv': 0.06, 'flow_tol_pct': 8}),
      (
        'catalog_item_details',
        {
          'kind': 'pump',
          'id': pump.id,
          'efficiency_points': [
            [5, 55],
            [10, 68],
          ],
          'finame': '1234567',
        },
      ),
      ('duplicate_catalog_item', {'kind': 'pipe', 'id': pipe.id, 'name': 'Copy of the pipe'}),
      (
        'fit_nozzle_curve',
        {
          'outlet': 'rotor',
          'nozzle': nozzle.id,
          'rows': [
            [20, 800, 11],
            [30, 980, 12],
            [40, 1130, 12.8],
          ],
        },
      ),
      (
        'set_nozzle_profile',
        {
          'outlet': 'rotor',
          'nozzle': nozzle.id,
          'rows': [
            [0, 4],
            [3, 4.4],
            [6, 3.5],
            [9, 2],
            [12, 0],
          ],
        },
      ),
    ]);
    allDone(t);
    final live = c.project.catalog;
    expect(live.fittings.length, nFittings + 1);
    expect(live.fittings.last.size2Mm, 32);
    expect(live.outlet('rotor')!.nozzle(nozzle.id)!.cv, 0.06);
    expect(live.outlet('rotor')!.nozzle(nozzle.id)!.flowTolBelow, closeTo(0.08, 1e-9));
    expect(live.pump(pump.id)!.efficiencyPoints.last.$2, closeTo(0.68, 1e-9));
    expect(live.finame[pump.id], '1234567');
    expect(live.pipes.length, nPipes + 1);
    expect(live.pipes.last.name, 'Copy of the pipe');
    expect(live.outlet('rotor')!.nozzle(nozzle.id)!.curve.flow(30) / m3sPerLph, closeTo(980, 30));
    expect(live.outlet('rotor')!.nozzle(nozzle.id)!.profile, isNotEmpty);
    expect(text, contains('worst flow error'));
    // six changes, six undo steps
    for (var k = 0; k < 6; k++) {
      c.undo();
    }
    expect(c.project.catalog.fittings.length, nFittings);
    expect(c.project.catalog.pipes.length, nPipes);
    expect(c.project.catalog.outlet('rotor')!.nozzle(nozzle.id)!.profile, isEmpty);
    // an attached catalogue file is merged
    final extra = Catalog()..pipes.add(PipeSpec(id: 'pipe_from_sheet', name: 'Sheet pipe 75', nominalMm: 75, innerDiameterMm: 69, costPerM: 12));
    host.files['supplier.json'] = Uint8List.fromList(utf8.encode(CatalogIo.exportJson(extra)));
    final (imp, ti) = await turn(tester, [
      ('import_catalog_attachment', {'name': 'supplier.json'}),
    ]);
    allDone(ti);
    expect(imp, contains('1 items'));
    expect(c.project.catalog.pipe('pipe_from_sheet'), isNotNull);
    // exports: four files, each confirmed
    final (exp, te) = await turn(tester, [
      ('export_catalog', {'format': 'json'}),
      ('export_catalog', {'format': 'csv', 'group': 'valves'}),
      ('export_catalog', {'format': 'xlsx'}),
      ('export_catalog', {'format': 'pack', 'brand': 'Acme', 'name': 'Acme 2026'}),
    ]);
    allDone(te);
    expect(approvals, hasLength(4));
    expect(files.keys, containsAll(['catalog.json', 'catalog_valves.csv', 'catalog.xlsx', 'acme_2026$catalogPackExtension']));
    expect(files['catalog.xlsx'], isA<Uint8List>());
    expect(exp, contains('Saved'));
    // the default catalogue: saved and forgotten (preferences, confirmed), reset (undo step)
    approvals.clear();
    await turn(tester, [
      ('catalog_default', {'action': 'save'}),
      ('catalog_default', {'action': 'forget'}),
    ]);
    expect(approvals.map((x) => x.name), ['catalog_default', 'catalog_default']);
    final (reset, tr) = await turn(tester, [
      ('catalog_default', {'action': 'reset'}),
    ]);
    allDone(tr);
    expect(reset, contains('default'));
    expect(c.project.catalog.pipe('pipe_from_sheet'), isNull);
    c.undo();
    expect(c.project.catalog.pipe('pipe_from_sheet'), isNotNull);
  });

  testWidgets('manufacturer packs: the bundled ones listed, one added as one undo step, an unknown one refused', (tester) async {
    final packs = await tester.runAsync(() => loadBundledCatalogPacks());
    expect(packs, isNotEmpty);
    final pack = packs!.first;
    final (list, t) = await turn(tester, [('list_catalog_packs', {})]);
    allDone(t);
    expect(list, contains(pack.id));
    expect(list, contains('not added'));
    final items = c.project.catalog.itemCount;
    final (added, t2) = await turn(tester, [
      ('add_catalog_pack', {'id': pack.id}),
    ]);
    allDone(t2);
    expect(added, contains('items added'));
    expect(c.project.catalog.itemCount, greaterThan(items));
    c.undo();
    expect(c.project.catalog.itemCount, items);
    final (bad, t3) = await turn(tester, [
      ('add_catalog_pack', {'id': 'no_such_pack'}),
    ]);
    expect(t3.calls.single.state, ToolCallState.failed);
    expect(bad, contains('No pack'));
  });

  testWidgets('exports: the PDF sheet set with details and charts, the PNG, R12, GPX, text report, the share link', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await design(tester);
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final (text, t) = await turn(tester, [
      (
        'export_sheet_pdf',
        {
          'page': 'a2',
          'split': 'zones',
          'details': ['all'],
          'charts': true,
          'include_reports': true,
          'windows': [
            {
              'bbox': [0, 0, 40, 40],
              'title': 'Pump',
            },
          ],
        },
      ),
      ('export_sheet_png', {'dpi': 72, 'page': 'a4'}),
      ('export_more_formats', {'format': 'dxf_r12'}),
      ('export_more_formats', {'format': 'report_txt'}),
      ('share_link', {'include_link': true}),
    ]);
    allDone(t);
    expect(approvals.map((x) => x.name), ['export_sheet_pdf', 'export_sheet_png', 'export_more_formats', 'export_more_formats', 'share_link']);
    final pdf = files.entries.firstWhere((e) => e.key.endsWith('.pdf')).value as Uint8List;
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    final png = files.entries.firstWhere((e) => e.key.endsWith('.png')).value as Uint8List;
    expect(png.sublist(1, 4), utf8.encode('PNG'));
    // the R12 file is bytes in code page 1252, as its header says
    expect(latin1.decode(files.entries.firstWhere((e) => e.key.endsWith('_r12.dxf')).value as Uint8List), contains('ANSI_1252'));
    expect(files.keys.where((k) => k.endsWith('.txt')), hasLength(1));
    expect(text, contains('detail sheets'));
    expect(clip, startsWith('https://opencadirrigation.com/'));
    expect(text, contains(clip!.length > 4000 ? 'Share link' : clip!));
    // GPX needs the georeference; the user may decline a file
    final (gpx, t2) = await turn(tester, [
      ('export_more_formats', {'format': 'gpx'}),
    ]);
    expect(t2.calls.single.state, ToolCallState.failed);
    expect(gpx, contains('georeference'));
    files.clear();
    final (_, t3) = await turn(tester, [('export_sheet_png', {})], answer: Approval.skip);
    expect(t3.calls.single.state, ToolCallState.skipped);
    expect(files, isEmpty);
    // read-only: no file
    final (ro, t4) = await turn(tester, [
      ('export_catalog', {'format': 'json'}),
    ], permission: AgentPermission.readOnly);
    expect(t4.calls.single.state, ToolCallState.refused);
    expect(ro, contains('read-only'));
    expect(files, isEmpty);
  });

  testWidgets('automatic design with every option: layout, templates, field blocks, tree rings, pivot fit; each one undo step', (tester) async {
    final supply = WaterSupplyEntity(id: c.project.newId(), position: const Pt(-10, -10));
    c.project.entities.add(supply);
    c.entitiesChanged();
    final lawn = area(rect(0, 0, 60, 40), name: 'Lawn');
    final cat = c.project.catalog;
    final zonePipe = cat.pipesFor(PipeUsage.zone).first.id;
    final valve = cat.valves.firstWhere((v) => v.kind == ValveKind.control && v.enabled).id;
    final before = c.project.entities.length;
    final (text, t) = await turn(tester, [
      (
        'layout_sprinklers_advanced',
        {'area': lawn.id, 'corner_angle_deg': 30, 'relax_iterations': 2, 'zoning': true, 'heads_per_zone': 6, 'routing': true, 'placement': 'manifold', 'profile': 'elliptical'},
      ),
    ]);
    allDone(t);
    expect(text, contains('heads of'));
    expect(text, contains('zones'));
    final outlets = c.project.entities.whereType<OutletEntity>().toList();
    expect(outlets, isNotEmpty);
    expect(outlets.map((o) => o.zoneName).toSet().length, greaterThan(1));
    c.undo();
    expect(c.project.entities.length, before);
    final (tpl, t2) = await turn(tester, [
      (
        'sports_template_advanced',
        {
          'kind': 'pitch',
          'rows': 4,
          'center': [300, 0],
        },
      ),
    ]);
    allDone(t2);
    expect(tpl, contains('heads over'));
    expect(c.project.entities.whereType<AreaEntity>().length, 2, reason: 'the turf area of the pitch');
    c.undo();
    final field = area(rect(0, 200, 200, 100), name: 'Field');
    final (blocks, t3) = await turn(tester, [
      ('subdivide_field_advanced', {'area': field.id, 'lateral': 'tape', 'submain_pipe': zonePipe, 'valve': valve, 'stub_m': 2, 'min_block_width_m': 20, 'max_block_area_m2': 6000}),
    ]);
    allDone(t3);
    expect(blocks, contains('blocks'));
    final submains = c.project.entities.whereType<PipeEntity>().where((p) => p.scope == HydraulicScope.zone && p.pipeSpecId == zonePipe);
    expect(submains, isNotEmpty);
    expect(c.project.entities.whereType<ControlValveEntity>().every((v) => v.valveSpecId == valve), isTrue);
    c.undo();
    final grove = area(rect(400, 0, 40, 30), name: 'Grove');
    final (rings, t4) = await turn(tester, [
      ('tree_rings_advanced', {'area': grove.id, 'plant_spacing_m': 5, 'row_spacing_m': 6, 'kind': 'drippers', 'drippers_per_tree': 2, 'submain': 'centre', 'zone_name': 'Trees'}),
    ]);
    allDone(t4);
    expect(rings, contains('trees'));
    expect(c.project.entities.whereType<ControlValveEntity>().map((v) => v.zoneName), contains('Trees'));
    c.undo();
    final farm = area(rect(1000, 0, 800, 800), name: 'Farm');
    final (pv, t5) = await turn(tester, [
      (
        'fit_pivot_advanced',
        {
          'area': farm.id,
          'spans_m': [50],
          'overhangs_m': [0, 10],
          'max_spans': 6,
        },
      ),
    ]);
    allDone(t5);
    expect(pv, contains('Pivot'));
    final p = c.project.entities.whereType<PivotEntity>().single;
    expect(p.radiusM, lessThanOrEqualTo(6 * 50 + 10 + 1e-6));
    c.undo();
    expect(c.project.entities.whereType<PivotEntity>(), isEmpty);
  });

  testWidgets('through find_operations and run_operation, as the model reaches them', (tester) async {
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        ('find_operations', {'query': 'solar pumping'}),
        (
          'run_operation',
          {
            'name': 'wetted_bulb',
            'input': {'soil': 'clay', 'flow_lph': 2},
          },
        ),
      ]),
      (_) => FakeReply.text('done'),
    ]);
    await tester.runAsync(() async {
      await AgentLoop(
        api: AnthropicClient(apiKey: 'sk-ant-test', transport: fake.call, sleep: (_) async {}),
        tools: box.tools,
      ).run(model: AiModel.opus55, system: 's', history: const [], user: AnthropicFormat.user([AiTextPart('go')]), permission: AgentPermission.auto, cancel: AiCancel());
    });
    final text = fake.lastUserText(1);
    expect(text, contains('solar_pumping'));
    expect(text, contains('Wetted width'));
  });
}
