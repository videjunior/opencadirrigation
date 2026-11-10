import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/agent_tools_ops.dart' show OpTool;
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/design/agb_design.dart' show twoWireSpecOf;
import 'package:opencadirrigation/core/design/field_machines.dart';
import 'package:opencadirrigation/core/design/multi_pivot.dart';
import 'package:opencadirrigation/core/design/network_ops.dart' show wiringFlows;
import 'package:opencadirrigation/core/design/pump_house.dart';
import 'package:opencadirrigation/core/design/solar_design.dart';
import 'package:opencadirrigation/core/design/traveller.dart' show WindClass, gunPerformance;
import 'package:opencadirrigation/core/design/two_wire.dart';
import 'package:opencadirrigation/core/design/water_quality.dart';
import 'package:opencadirrigation/core/model/agb_settings.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

import 'support/fake_claude.dart';

/// The operations of the "machines" group (lib/app/ai/op_parts/agb.dart):
/// the pump house electrics, solar pumping, the water analysis and two-wire
/// wiring of the design (read, and changed as one undo step), several pivots
/// in a property, traveller lanes and furrow sets (reported, or drawn as one
/// undo step) and the field machines of the drawing. Each one is called as
/// the model calls it, through run_operation in the real agent loop, and its
/// numbers are checked by hand or against the engine module behind it.
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

const _machines = [
  'pump_house_electrics',
  'set_pump_house',
  'solar_design',
  'set_solar_design',
  'water_quality',
  'set_water_quality',
  'two_wire_system',
  'set_two_wire',
  'multi_pivot_layout',
  'traveller_lanes',
  'furrow_set',
  'field_machines',
];

void main() {
  late ProjectController c;
  late AgentToolbox box;

  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    box = AgentToolbox(c, host: _Host());
  });

  /// One turn of the scripted model running [ops] through run_operation (as
  /// the model reaches them: they are not sent as tools), then "done"; the
  /// results as the model reads them (a call keeps only their first line).
  Future<(String, AgentTurn)> turn(WidgetTester tester, List<(String, Map<String, dynamic>)> ops, {AgentPermission permission = AgentPermission.auto}) async {
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        for (final (name, input) in ops) ('run_operation', {'name': name, 'input': input}),
      ]),
      (_) => FakeReply.text('done'),
    ]);
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
            events: AgentEvents(approve: (call) async => Approval.apply),
          );
    });
    return (fake.lastUserText(1), out!);
  }

  /// The report of operation [name], which must succeed.
  Future<String> run(WidgetTester tester, String name, [Map<String, dynamic> input = const {}, AgentPermission permission = AgentPermission.auto]) async {
    final (text, t) = await turn(tester, [(name, input)], permission: permission);
    expect(t.calls.single.state, ToolCallState.done, reason: '$name: $text');
    return text;
  }

  /// The answer of operation [name] refusing [input]; the project is left as
  /// it was (no undo step, the settings and the drawing unchanged).
  Future<String> refused(WidgetTester tester, String name, Map<String, dynamic> input) async {
    final steps = c.historyIndex;
    final agb = jsonEncode(c.project.agb.toJson());
    final count = c.project.entities.length;
    final (text, t) = await turn(tester, [(name, input)]);
    expect(t.calls.single.state, ToolCallState.failed, reason: '$name accepted $input: $text');
    expect(c.historyIndex, steps, reason: 'a refused call adds no undo step');
    expect(jsonEncode(c.project.agb.toJson()), agb);
    expect(c.project.entities.length, count);
    return text;
  }

  /// [run] of a change: one undo step named after the operation.
  Future<String> change(WidgetTester tester, String name, Map<String, dynamic> input) async {
    final steps = c.historyIndex;
    final text = await run(tester, name, input);
    expect(c.historyIndex, steps + 1, reason: '$name is one undo step');
    expect(c.historyEntries.last.label, 'hist.aiTool|$name');
    return text;
  }

  Future<void> design(WidgetTester tester) async {
    await tester.runAsync(() => c.runDesign());
    expect(c.results, isNotNull, reason: c.lastMessage);
  }

  T add<T extends Entity>(T e) {
    c.project.entities.add(e);
    c.entitiesChanged();
    return e;
  }

  String id() => c.project.newId();

  /// The cells of the table row of [text] that starts with [first].
  List<String> row(String text, String first) => text.split('\n').firstWhere((l) => l.startsWith(first), orElse: () => fail('no row "$first" in:\n$text')).split(' | ');

  /// The table rows of [text] that start with [prefix].
  List<List<String>> rows(String text, String prefix) => [
    for (final l in text.split('\n'))
      if (l.startsWith(prefix)) l.split(' | '),
  ];

  double n(String cell) => double.parse(cell);

  /// The number after [label] in [text] ("source 150.0 kVA" → 150).
  double after(String text, String label) {
    final m = RegExp('${RegExp.escape(label)} (-?[0-9.]+)').firstMatch(text);
    if (m == null) fail('no "$label" in:\n$text');
    return double.parse(m.group(1)!);
  }

  testWidgets('the machines group: twelve operations the model finds by their group, the drawing ones a read with apply false', (tester) async {
    final ops = {for (final o in box.operations) o.name: o};
    for (final name in _machines) {
      final o = ops[name];
      expect(o, isA<OpTool>(), reason: name);
      expect((o! as OpTool).group, 'machines', reason: name);
      expect(o.describe(const {}), c.t('ai.op.$name').replaceAll('{n}', ''), reason: name);
      expect(o.effectOf(const {}), name.startsWith('set_') || {'multi_pivot_layout', 'traveller_lanes', 'furrow_set'}.contains(name) ? ToolEffect.write : ToolEffect.read, reason: name);
    }
    for (final name in ['multi_pivot_layout', 'traveller_lanes', 'furrow_set']) {
      expect(ops[name]!.effectOf(const {'apply': false}), ToolEffect.read, reason: name);
      expect(ops[name]!.effectOf(const {'apply': true}), ToolEffect.write, reason: name);
    }
    // the model finds them by their group
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        ('find_operations', {'group': 'machines', 'limit': 25}),
      ]),
      (_) => FakeReply.text('done'),
    ]);
    await tester.runAsync(() async {
      await AgentLoop(
        api: AnthropicClient(apiKey: 'sk-ant-test', transport: fake.call, sleep: (_) async {}),
        tools: box.tools,
      ).run(model: AiModel.opus55, system: 's', history: const [], user: AnthropicFormat.user([AiTextPart('go')]), permission: AgentPermission.auto, cancel: AiCancel());
    });
    final listing = fake.lastUserText(1);
    expect(listing, startsWith('12 operations match'));
    for (final name in _machines) {
      expect(listing, contains('## $name (machines;'), reason: name);
    }
  });

  testWidgets('pump house: a 75 kW pump 200 m away gets star-delta, 95 mm² and 150 kVA; every setting stored as one undo step and undone', (tester) async {
    // the IE3 efficiencies of 60 Hz mains, as the engine's own case
    c.project.params.mainsHz = 60;
    c.project.catalog.pumps.add(PumpSpec(id: 'p75', name: 'P75', points: [(0, 80), (100 * m3sPerM3h, 60), (200 * m3sPerM3h, 30)], efficiency: 0.75, powerKw: 75));
    final pump = add(PumpEntity(id: id(), name: 'Well pump', position: Pt.zero, pumpSpecId: 'p75'));
    final diesel = add(PumpEntity(id: id(), name: 'Diesel', position: const Pt(10, 0)));
    final area = add(AreaEntity(id: id(), name: 'Lawn', points: const [Pt(0, 0), Pt(50, 0), Pt(50, 50)]));

    // as the dialog shows it before it is switched on: the default feeder
    final first = await run(tester, 'pump_house_electrics');
    expect(first, contains('Settings (set_pump_house names): enabled false, voltage 380 V, supply ownTransformer, insulation pvc, method d, ambient_c reference'));
    expect(row(first, '${pump.id} Well pump')[8], '50');
    expect(first, contains(c.t('warn.agb_pump_no_power')), reason: 'the second pump has no power to size a motor for');
    expect(c.historyIndex, 0, reason: 'reading changes nothing');

    var text = await change(tester, 'set_pump_house', {
      'enabled': true,
      'pumps': {
        'Well pump': {'length_m': 200},
      },
    });
    final ph = c.project.agb.pumpHouse;
    expect(ph.enabled, isTrue);
    expect(ph.pumps.keys, [pump.id], reason: 'the pump named by its name');
    expect(ph.pumps[pump.id]!.lengthM, 200);
    expect(text, startsWith('Pump house settings changed; design results discarded (run_design again).\nSettings (set_pump_house names): enabled true'));
    // I = 75 kW / (√3 · 380 V · η · cos φ), × 1.15 service factor, × 7/3 star-delta start
    final cell = row(text, '${pump.id} Well pump');
    expect(cell[1], '75.0');
    expect(n(cell[2]), closeTo(ie3Efficiency(75), 0.0005));
    expect(cell[3], '0.87');
    final i = 75000 / (math.sqrt(3) * 380 * ie3Efficiency(75) * 0.87);
    expect(n(cell[4]), closeTo(137.3, 0.06));
    expect(n(cell[4]), closeTo(i, 0.051));
    expect(n(cell[5]), closeTo(i * 1.15, 0.051));
    expect(cell[6], 'starDelta');
    expect(n(cell[7]), closeTo(i * 7 / 3, 0.51));
    expect(cell[8], '200');
    // 70 mm² carries 151 A buried (NBR 5410 Tabela 36, D), below the 158 A of the design current
    expect(cell[9], '95.0');
    expect(cell[10], '50.0');
    expect(n(cell[11]), greaterThanOrEqualTo(n(cell[5])));
    expect(n(cell[12]), closeTo(3.01, 0.011));
    expect(cell[13], '7.5', reason: '7 % plus 0.005 %/m beyond 100 m');
    expect(n(cell[14]), lessThanOrEqualTo(10));
    expect(cell[16], '');
    // 112.5 kVA carries the load but lets the start dip more than 10 %
    expect(after(text, 'needs ≥'), closeTo(75 / (ie3Efficiency(75) * 0.87), 0.051));
    expect(after(text, 'source'), 150);
    expect(after(text, 'uk'), 3.5);
    expect(after(text, 'Ik3 at the source'), closeTo(6.84, 0.021));
    expect(text, contains('tariff group B'));

    // every other setting at once; the feeder keeps its length, a diesel engine stays out
    text = await change(tester, 'set_pump_house', {
      'voltage': 400,
      'supply': 'lowVoltage',
      'insulation': 'xlpe',
      'method': 'c',
      'ambient_c': 35,
      'grouping': 0.8,
      'service_factor': 1.25,
      'direct_max_kw': 7.5,
      'soft_multiple': 3.5,
      'default_length_m': 80,
      'max_running_drop_pct': 4,
      'uk_pct': 5,
      'loading_pct': 90,
      'other_kva': 10,
      'include_pivots': false,
      'clearing_s': 0.2,
      'upstream_mva': 250,
      'panel_cost': 1200,
      'transformer_cost': 9000,
      'pumps': {
        pump.id: {'starter': 'softStarter', 'motor_kw': 55, 'efficiency': 0.95, 'power_factor': 0.9},
        'Diesel': {'electric': false},
      },
    });
    final s = c.project.agb.pumpHouse;
    expect(
      [s.voltage, s.supply, s.insulation, s.method, s.ambientC, s.groupingFactor, s.serviceFactor, s.directMaxKw, s.softStartMultiple, s.defaultFeederM],
      [400, PowerSupplyKind.lowVoltage, CableInsulation.xlpe, CableMethod.c, 35, 0.8, 1.25, 7.5, 3.5, 80],
    );
    expect(
      [s.maxRunningDropPct, s.transformerUkPct, s.transformerLoadingPct, s.otherLoadsKva, s.includePivots, s.clearingTimeS, s.upstreamMva, s.panelCost, s.transformerCost],
      [4, 5, 90, 10, false, 0.2, 250, 1200, 9000],
    );
    final f = s.pumps[pump.id]!;
    expect([f.lengthM, f.starter, f.motorKw, f.efficiency, f.powerFactor, f.electric], [200, StarterKind.softStarter, 55, 0.95, 0.9, true]);
    expect(s.pumps[diesel.id]!.electric, isFalse);
    expect(text, contains('voltage 400 V, supply lowVoltage, insulation xlpe, method c, ambient_c 35, grouping 0.80, service_factor 1.25, direct_max_kw 7.5'));
    expect(text, contains('max_running_drop_pct 4.0 (0 = NBR 5410), uk_pct 5.0 (0 = typical), loading_pct 90, other_kva 10.0, include_pivots false.'));
    expect(text, isNot(contains('${diesel.id} Diesel')));
    expect(text, isNot(contains(c.t('warn.agb_pump_no_power'))), reason: 'the diesel engine is no longer a motor without power');
    final i2 = 55000 / (math.sqrt(3) * 400 * 0.95 * 0.9);
    final soft = row(text, '${pump.id} Well pump');
    expect([soft[1], soft[2], soft[3], soft[6], soft[8], soft[13]], ['55.0', '0.950', '0.90', 'softStarter', '200', '4.0']);
    expect(n(soft[4]), closeTo(i2, 0.051));
    expect(n(soft[5]), closeTo(i2 * 1.25, 0.051));
    expect(n(soft[7]), closeTo(i2 * 3.5, 0.51));
    // the utility's network: no source of its own, the short circuit of 250 MVA upstream
    expect(text, contains('Supply lowVoltage: demand ${fmt(10 * 0.9 + 55 / 0.95, 1)} kW / ${fmt(10 + 55 / (0.95 * 0.9), 1)} kVA'));
    expect(text, contains('installed ${fmt(55 + 10 * 0.9, 1)} kW, largest start ${fmt(55 / (0.95 * 0.9) * 3.5, 1)} kVA, source 0.0 kVA'));
    expect(after(text, 'Ik3 at the source'), closeTo(1.05 * 400 / (math.sqrt(3) * 1.1 * 400 * 400 / 250e6) / 1000, 0.05));

    // a diesel engine made electric again is a default feeder: it is not kept
    await change(tester, 'set_pump_house', {
      'pumps': {
        'Diesel': {'electric': true},
      },
    });
    expect(c.project.agb.pumpHouse.pumps.keys, [pump.id]);
    c.undo();
    expect(c.project.agb.pumpHouse.pumps[diesel.id]!.electric, isFalse);
    c.undo();
    expect(c.project.agb.pumpHouse.supply, PowerSupplyKind.ownTransformer, reason: 'one undo step');
    expect(c.project.agb.pumpHouse.voltage, 380);
    expect(c.project.agb.pumpHouse.pumps[pump.id]!.lengthM, 200);
    c.undo();
    expect(c.project.agb.pumpHouse.isDefault, isTrue);

    // what it refuses, before anything changes
    expect(await refused(tester, 'set_pump_house', {}), contains('Give at least one setting to change.'));
    expect(await refused(tester, 'set_pump_house', {'voltage': 50}), contains('"voltage" = 50.0 is outside 110.0 … 1000.0.'));
    expect(await refused(tester, 'set_pump_house', {'supply': 'windmill'}), contains('must be one of: ownTransformer, lowVoltage, generator'));
    expect(
      await refused(tester, 'set_pump_house', {
        'pumps': {'Lawn': <String, dynamic>{}},
      }),
      contains('"Lawn" is not a pump.'),
    );
    expect(
      await refused(tester, 'set_pump_house', {
        'pumps': {'Well pump': 5},
      }),
      contains('pumps["Well pump"] must be an object.'),
    );
    expect(
      await refused(tester, 'set_pump_house', {
        'pumps': {'Booster': <String, dynamic>{}},
      }),
      contains('No item "Booster"'),
    );
    expect(
      await refused(tester, 'set_pump_house', {
        'enabled': true,
        'pumps': {
          'Well pump': {'starter': 'manual'},
        },
      }),
      contains('"manual"'),
    );
    expect(c.project.agb.pumpHouse.isDefault, isTrue, reason: 'the valid "enabled" of a refused call is not kept');
    expect(area.id, isNotEmpty);
  });

  testWidgets('pump house: a starter name that does not exist is refused naming the starters, as every other wrong choice is', (tester) async {
    add(PumpEntity(id: id(), name: 'Well pump', position: Pt.zero));
    final text = await refused(tester, 'set_pump_house', {
      'pumps': {
        'Well pump': {'starter': 'manual'},
      },
    });
    expect(text, isNot(startsWith('The tool failed')));
    expect(text, contains('starter'));
    expect(text, contains('auto, direct, starDelta, softStarter, vfd'));
  });

  testWidgets('pump house on a designed pivot farm: the circuits of the heaviest flow and the pivot supply, as the engine works them out', (tester) async {
    loadExampleAction(c, ExampleId.pivot);
    final pivot = c.project.entities.whereType<PivotEntity>().first;
    // a machine with its electrical design: its supply joins the pump house
    pivot.machine.voltage = 440;
    c.entitiesChanged();
    await design(tester);
    await change(tester, 'set_pump_house', {'enabled': true});
    expect(c.results, isNull, reason: 'the results priced the old settings');
    await design(tester);
    final text = await run(tester, 'pump_house_electrics');
    final r = designPumpHouse(c.project, c.results);
    expect(r.circuits, isNotEmpty);
    expect(r.worstFlow, isNotEmpty);
    for (final x in r.circuits) {
      final cell = row(text, '${x.pumpId} ');
      expect(n(cell[1]), closeTo(x.motorKw, 0.051));
      expect(n(cell[4]), closeTo(x.currentA, 0.051));
      expect(cell[6], x.starter.name);
      expect(n(cell[9]), x.sectionMm2);
      expect(n(cell[12]), lessThanOrEqualTo(n(cell[13]) + 0.005), reason: 'the running drop within its limit');
    }
    expect(text, contains('Supply ownTransformer: demand ${fmt(r.demandKw, 1)} kW / ${fmt(r.runningKva, 1)} kVA (flow ${r.worstFlow}), installed ${fmt(r.installedKw, 1)} kW'));
    expect(after(text, 'source'), r.sourceKva);
    final supply = r.pivots.single;
    expect(supply.pivotId, pivot.id);
    final cell = row(text, '${pivot.id} ');
    expect(n(cell[1]), supply.spanCableMm2);
    expect(cell[3], supply.awg > 0 ? '${supply.awg}' : '-');
    expect(n(cell[4]), closeTo(supply.spanCurrentA, 0.051));
    expect(n(cell[6]), closeTo(supply.collectorRingA, 0.51));
    expect(n(cell[6]), closeTo(n(cell[4]), 0.51), reason: 'the collector ring carries the first span');
    expect(n(cell[10]), supply.transformerKva);
  });

  testWidgets('solar pumping: off, then grid-tied and off-grid on a designed pivot as the engine sizes them; the settings one undo step', (tester) async {
    expect(await run(tester, 'solar_design'), endsWith('Solar pumping is off (mode "off").'));
    expect(await refused(tester, 'set_solar_design', {}), contains('Give at least one setting to change.'));
    expect(await refused(tester, 'set_solar_design', {'module_wp': 5}), contains('"module_wp" = 5.0 is outside 10.0 … 1000.0.'));
    expect(await refused(tester, 'set_solar_design', {'billing_year': 2026.5}), contains('"input.billing_year" must be of type integer.'));

    var text = await change(tester, 'set_solar_design', {
      'mode': 'gridTied',
      'module_wp': 600,
      'module_area_m2': 2.7,
      'tilt_deg': 20,
      'azimuth_deg': 10,
      'oversize': 1.1,
      'soiling': 0.05,
      'converter_efficiency': 0.96,
      'motor_pump_efficiency': 0.6,
      'head_m': 40,
      'dc_ac_ratio': 1.25,
      'simultaneity': 0.3,
      'fio_b_pct': 30,
      'billing_year': 2027,
      'grandfathered': true,
      'module_price': 700,
      'inverter_price_per_kw': 900,
      'structure_price': 150,
    });
    final s = c.project.agb.solar;
    expect(
      [s.mode, s.moduleWp, s.moduleAreaM2, s.tiltDeg, s.azimuthFromEquatorDeg, s.oversize, s.soiling, s.converterEfficiency, s.motorPumpEfficiency],
      [SolarMode.gridTied, 600, 2.7, 20, 10, 1.1, 0.05, 0.96, 0.6],
    );
    expect(
      [s.headM, s.dcAcRatio, s.simultaneity, s.fioBSharePct, s.billingYear, s.grandfathered, s.modulePrice, s.inverterPricePerKw, s.structurePricePerModule],
      [40, 1.25, 0.3, 30, 2027, true, 700, 900, 150],
    );
    expect(text, startsWith('Solar settings changed; design results discarded (run_design again).\nSettings (set_solar_design names): mode gridTied, module_wp 600, module_area_m2 2.70, tilt_deg 20'));
    // nothing designed: no pumping energy to offset, so no module; the month table still has the year
    expect(text, contains('gridTied: 0 × 600 Wp = 0.00 kWp, 0 m², inverter 0.0 kW, tilt 20°, head 40.0 m, wire-to-water 0.600'));
    expect(text, contains('Fio B paid 0 %'), reason: 'access asked before 2023: no Fio B');
    expect(rows(text, 'Jan |'), hasLength(1));
    expect(rows(text, 'Dec |'), hasLength(1));
    expect(text, contains(c.t('warn.solar_no_demand')));
    // -1 is the latitude
    text = await change(tester, 'set_solar_design', {'tilt_deg': -1});
    expect(c.project.agb.solar.tiltDeg, isNull);
    expect(text, contains('tilt_deg latitude'));
    expect(text, contains('tilt ${fmt(siteLatitude(c.project).abs(), 0)}°'));
    c.undo();
    expect(c.project.agb.solar.tiltDeg, 20);
    c.undo();
    expect(c.project.agb.solar.isDefault, isTrue, reason: 'one undo step');

    // on a designed pivot: the array of the yearly pumping energy, the bill compensated
    loadExampleAction(c, ExampleId.pivot);
    await change(tester, 'set_solar_design', {'mode': 'gridTied'});
    await design(tester);
    text = await run(tester, 'solar_design');
    final grid = designSolar(c.project, c.results)!;
    expect(grid.modules, greaterThan(0));
    expect(text, contains('gridTied: ${grid.modules} × 550 Wp = ${fmt(grid.modules * 0.55, 2)} kWp, ${fmt(grid.modules * 2.6, 0)} m², inverter ${fmt(grid.modules * 0.55 / 1.2, 1)} kW'));
    expect(grid.generationKWh, greaterThanOrEqualTo(grid.consumptionKWh - 1e-6), reason: 'as much generated as the pumping uses');
    expect(text, contains('generation ${fmt(grid.generationKWh, 0)} kWh/a, pumping ${fmt(grid.consumptionKWh, 0)} kWh/a; used as generated 0, compensated ${fmt(grid.compensatedKWh, 0)}'));
    expect(text, contains('(Fio B paid 60 %)'), reason: 'the Fio B share of 2026 (Lei 14.300/2022 art. 27)');
    expect(
      text,
      contains('Energy cost on the grid ${fmt(grid.gridCost, 2)}, with the array ${fmt(grid.netCost, 2)}, saving ${fmt(grid.gridCost - grid.netCost, 2)} ${c.project.params.currency}/year.'),
    );
    for (var m = 0; m < 12; m++) {
      final cell = row(text, '${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m]} |');
      expect(n(cell[4]), closeTo(grid.months[m].generationKWh, 0.51));
    }

    // off-grid: the pump drive carries the motor and the month of largest need sizes the array
    await change(tester, 'set_solar_design', {'mode': 'offGrid', 'oversize': 1.2});
    await design(tester);
    text = await run(tester, 'solar_design');
    final off = designSolar(c.project, c.results)!;
    expect(off.criticalMonth, isNotNull);
    expect(text, contains('offGrid: ${off.modules} × 550 Wp = ${fmt(off.arrayKWp, 2)} kWp, ${fmt(off.areaM2, 0)} m², pump drive ${fmt(off.inverterKw, 1)} kW'));
    expect(text, contains('; critical month ${off.criticalMonth}.'));
    expect(text, isNot(contains('used as generated')));
    expect(n(row(text, 'Jun |')[3]), closeTo(off.months[5].pumpedM3Day, 0.051));
  });

  testWidgets('water quality: hazards, Langelier index, chlorine and acid by hand; the filters of a designed orchard; values cleared; one undo step', (tester) async {
    expect(await run(tester, 'water_quality'), endsWith('No analysis yet: give at least one value with set_water_quality.'));
    expect(await refused(tester, 'set_water_quality', {}), contains('Give at least one value to change.'));
    expect(await refused(tester, 'set_water_quality', {'ph': 15}), contains('"ph" = 15.0 is outside 0.0 … 14.0.'));
    expect(
      await refused(tester, 'set_water_quality', {
        'clear': ['colour'],
      }),
      contains('must be one of'),
    );

    var text = await change(tester, 'set_water_quality', {
      'source': 'reservoir',
      'ph': 7.9,
      'ec_ds_m': 0.9,
      'tss_mg_l': 70,
      'iron_mg_l': 0.8,
      'manganese_mg_l': 0.05,
      'calcium_mg_l': 80,
      'bicarbonate_mg_l': 250,
    });
    final w = c.project.agb.water;
    expect([w.source, w.ph, w.ecDsM, w.tssMgL, w.ironMgL, w.manganeseMgL, w.calciumMgL, w.bicarbonateMgL], [WaterSource.reservoir, 7.9, 0.9, 70, 0.8, 0.05, 80, 250]);
    expect(text, startsWith('Water analysis changed; design results discarded (run_design again).\nAnalysis (set_water_quality names): source reservoir, ph 7.900, ec_ds_m 0.900, tds_mg_l -'));
    // Nakayama (1982): 50-100 mg/L of suspended solids, pH 7-8, 500-2000 mg/L dissolved and 0.1-1.5 mg/L of iron are moderate
    expect(row(text, 'tss |'), ['tss', '70.000', 'moderate']);
    expect(row(text, 'ph |'), ['ph', '7.900', 'moderate']);
    expect(row(text, 'tds |'), ['tds', '576.000', 'moderate'], reason: 'TDS = 640 × EC');
    expect(row(text, 'mn |'), ['mn', '0.050', 'low']);
    expect(row(text, 'fe |'), ['fe', '0.800', 'moderate']);
    // TDS 576 mg/L, Ca 80, HCO3 250 mg/L at 25 °C: pHs 7.35
    expect(text, contains('Overall hazard moderate; Langelier index 0.55; dissolved solids 576 mg/L.'));
    // no design: no flow to filter; the drippers' 0.8 mm passage over 7 asks 114 µm, the 140 mesh of 106 µm
    expect(text, contains('Filtration for 0.0 m³/h: emitter passage 0.80 mm → opening 106 µm (140 mesh); media filters 0 × Ø 0 mm'));
    expect(text, contains('disc filter; filters drawn 0 (0.0 m³/h).'));
    // the oxidation demand 0.64 Fe + 1.3 Mn, plus the 1 mg/L residual
    expect(text, contains('Chlorination continuous: demand ${fmt(0.64 * 0.8 + 1.3 * 0.05, 2)} mg/L, dose ${fmt(0.64 * 0.8 + 1.3 * 0.05 + 1, 2)} mg/L'));
    final meq = acidToLowerPh(250 / 61.02, 7.9, 6.5);
    expect(meq, closeTo(1.632, 0.002));
    expect(text, contains('Acid to pH 6.5: ${fmt(meq, 2)} meq/L, ${fmt(acidMlPerM3(AcidProduct.sulfuric, meq), 1)} mL/m³ of sulfuric'));
    expect(text, contains(c.t('warn.water_scaling')));

    // the rest of the analysis and the treatment
    text = await change(tester, 'set_water_quality', {
      'tds_mg_l': 600,
      'sulfide_mg_l': 0.2,
      'bacteria_per_ml': 5000,
      'temperature_c': 20,
      'emitter_passage_mm': 1.5,
      'mesh_ratio': 8,
      'chlorination': 'intermittent',
      'residual_mg_l': 1.5,
      'shock_mg_l': 12,
      'shock_minutes': 60,
      'shocks_per_month': 2,
      'hypochlorite_pct': 12,
      'acid_target_ph': 6,
      'acid': 'phosphoric',
      'filter_cost': 500,
      'injector_cost': 300,
    });
    final w2 = c.project.agb.water;
    expect(
      [w2.tdsMgL, w2.sulfideMgL, w2.bacteriaPerMl, w2.temperatureC, w2.emitterPassageMm, w2.meshRatio, w2.chlorination, w2.chlorineResidualMgL],
      [600, 0.2, 5000, 20, 1.5, 8, ChlorinationMode.intermittent, 1.5],
    );
    expect([w2.shockMgL, w2.shockMinutes, w2.shocksPerMonth, w2.hypochloritePct, w2.acidTargetPh, w2.acid, w2.filterCost, w2.injectorCost], [12, 60, 2, 12, 6, AcidProduct.phosphoric, 500, 300]);
    expect(w2.ph, 7.9, reason: 'what is not given stays');
    // 1.5 mm over 8 = 187 µm: the 80 mesh of 180 µm
    expect(text, contains('emitter passage 1.50 mm → opening 180 µm (80 mesh)'));
    expect(text, contains('Chlorination intermittent: demand ${fmt(0.64 * 0.8 + 1.3 * 0.05 + 6 * 0.2, 2)} mg/L, dose ${fmt(0.64 * 0.8 + 1.3 * 0.05 + 6 * 0.2 + 12, 2)} mg/L'));
    expect(text, contains('Acid to pH 6.0: ${fmt(acidToLowerPh(250 / 61.02, 7.9, 6), 2)} meq/L'));
    expect(text, contains('mL/m³ of phosphoric'));

    // every value of the analysis cleared: nothing analysed
    text = await change(tester, 'set_water_quality', {
      'clear': ['ph', 'ec_ds_m', 'tds_mg_l', 'tss_mg_l', 'iron_mg_l', 'manganese_mg_l', 'sulfide_mg_l', 'calcium_mg_l', 'bicarbonate_mg_l', 'bacteria_per_ml', 'acid_target_ph'],
    });
    expect(c.project.agb.water.analysed, isFalse);
    expect(c.project.agb.water.acidTargetPh, isNull);
    expect(text, endsWith('No analysis yet: give at least one value with set_water_quality.'));
    expect(c.project.agb.water.chlorination, ChlorinationMode.intermittent, reason: 'the treatment stays');
    c.undo();
    expect(c.project.agb.water.ph, 7.9);
    c.undo();
    c.undo();
    expect(c.project.agb.water.isDefault, isTrue, reason: 'one undo step each');

    // the handler itself refuses a key the schema would let through
    final op = box.operations.firstWhere((o) => o.name == 'set_water_quality');
    Object? error;
    await tester.runAsync(() async {
      try {
        await op.run({
          'clear': ['colour'],
        });
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<ToolInputError>());
    expect((error! as ToolInputError).message, 'clear: "colour" is no value of the analysis.');
    expect(c.project.agb.water.isDefault, isTrue);

    // a designed orchard: the flow of the largest system flow, the filter it has drawn, a catalogue safety filter
    loadExampleAction(c, ExampleId.orchard);
    await change(tester, 'set_water_quality', {'source': 'reservoir', 'ph': 7.9, 'ec_ds_m': 0.9, 'tss_mg_l': 70, 'iron_mg_l': 0.8});
    await design(tester);
    text = await run(tester, 'water_quality');
    final r = designWaterQuality(c.project, c.results)!;
    expect(r.designFlowM3h, greaterThan(0));
    expect(r.drawnFilters, greaterThan(0), reason: 'the orchard has its filter drawn');
    final safe = c.project.catalog.valve(r.safetyFilterId)!;
    expect(
      text,
      contains(
        'Filtration for ${fmt(r.designFlowM3h, 1)} m³/h: emitter passage ${fmt(r.passageMm, 2)} mm → opening ${fmt(r.openingUm, 0)} µm (${r.mesh} mesh); '
        'media filters ${r.mediaTanks} × Ø ${fmt(r.tankDiameterM * 1000, 0)} mm at ${fmt(r.mediaFlux, 0)} m³/h/m² + disc filter (${r.safetyFilters} × ${safe.id} ${safe.name}); filters drawn ${r.drawnFilters}',
      ),
    );
    expect(r.mediaTanks, greaterThanOrEqualTo(2), reason: 'reservoir water: media filters, two at least');
    // continuous chlorine for the iron: the hypochlorite of the design flow
    expect(text, contains('hypochlorite ${fmt(r.designFlowM3h * (0.64 * 0.8 + 1) / 100, 2)} L/h'));
  });

  testWidgets('two-wire: the decoder path of a controller worked out by hand, the settings stored as one undo step', (tester) async {
    expect(await run(tester, 'two_wire_system'), endsWith('No controller or no wire route: draw the routes first (route_wires or create_entities type "wire").'));
    final wire = add(WireEntity(id: id(), points: const [Pt.zero, Pt(1000, 0)]));
    var text = await run(tester, 'two_wire_system');
    expect(text, contains('Decoders by outputs: none; grounding points 0; stations 0.'));
    expect(text, contains(c.t('warn.twowire_no_controller')));
    final ctl = add(ControllerEntity(id: id(), name: 'Ctrl', position: Pt.zero));
    for (final x in const [200.0, 400.0, 600.0, 800.0, 1000.0]) {
      add(ControlValveEntity(id: id(), position: Pt(x, 0), zoneName: 'Z${x ~/ 200}'));
    }
    text = await run(tester, 'two_wire_system');
    expect(text, startsWith('Settings (set_two_wire names): enabled false, output_volts 34.0, min_volts 24.0, idle_ma 1.00, solenoid_reach_m 30, ground_every_decoders 12, ground_every_m 150.'));
    // the farthest decoder opening with the other four holding: idle 1 mA per decoder + 0.37 / 0.22 A
    // on each 200 m stretch, both conductors, 10 % slack; the 4 mm² pair is the cheapest that keeps 24 V
    const drop = 2 * 200 * 1.1 * (1.255 + 1.034 + 0.813 + 0.592 + 0.371);
    final cell = row(text, '${ctl.id} |');
    expect(cell.sublist(1, 6), ['w4', '1000', '1100', '5', '5']);
    expect(n(cell[6]), closeTo(0.005 + 0.37 + 4 * 0.22, 0.0051));
    expect(n(cell[7]), closeTo(34 - drop * copperOhmPerKm(4) / 1000, 0.051));
    // grounded at the controller, every 150 m (150 … 900) and at the end
    expect(text, contains('Decoders by outputs: 5 × 1; grounding points 8; stations 5.'));
    expect(c.historyIndex, 0);

    expect(await refused(tester, 'set_two_wire', {}), contains('Give at least one setting to change.'));
    expect(
      await refused(tester, 'set_two_wire', {
        'decoder_prices': {'one': 80},
      }),
      contains('decoder_prices: "one" must be outputs → a price ≥ 0.'),
    );
    expect(
      await refused(tester, 'set_two_wire', {
        'decoder_prices': {'2': -1},
      }),
      contains('decoder_prices: "2" must be outputs → a price ≥ 0.'),
    );
    expect(
      await refused(tester, 'set_two_wire', {
        'decoder_prices': {'2': 'cheap'},
      }),
      contains('decoder_prices: "2"'),
    );
    expect(await refused(tester, 'set_two_wire', {'ground_every_decoders': 2.5}), contains('"input.ground_every_decoders" must be of type integer.'));

    text = await change(tester, 'set_two_wire', {
      'enabled': true,
      'output_volts': 30,
      'min_volts': 22,
      'idle_ma': 2,
      'solenoid_reach_m': 20,
      'ground_every_decoders': 3,
      'ground_every_m': 300,
      'decoder_prices': {'1': 85, '2': 120.5},
      'arrester_price': 40,
    });
    final s = c.project.agb.twoWire;
    expect([s.enabled, s.outputVolts, s.minVolts, s.decoderIdleMa, s.solenoidReachM, s.groundEveryDecoders, s.groundEveryM, s.arresterPrice], [true, 30, 22, 2, 20, 3, 300, 40]);
    expect(s.decoderPrices, {1: 85, 2: 120.5});
    expect(text, startsWith('Two-wire settings changed; design results discarded (run_design again).\nSettings (set_two_wire names): enabled true, output_volts 30.0, min_volts 22.0, idle_ma 2.00'));
    final r2 = designTwoWire(c.project, flows: wiringFlows(c.project), spec: twoWireSpecOf(s))!;
    final path = r2.paths.single;
    final cell2 = row(text, '${ctl.id} |');
    expect(cell2[1], path.wireId);
    expect(n(cell2[7]), closeTo(path.worstVolts, 0.051));
    expect(path.worstVolts, greaterThanOrEqualTo(22), reason: 'a wire that keeps the new minimum');
    // idle 2 mA per decoder now
    expect(n(cell2[6]), closeTo(0.010 + 0.37 + 4 * 0.22, 0.0051));
    // every 300 m now (300, 600, 900) besides the controller and the end; no stretch reaches 3 decoders before 300 m
    expect(r2.grounds, hasLength(5));
    expect(text, contains('grounding points 5; stations 5.'));
    c.undo();
    expect(c.project.agb.twoWire.isDefault, isTrue, reason: 'one undo step');
    expect(wire.points, hasLength(2));
  });

  testWidgets('several pivots: refused without a closed field, reported with apply false, drawn as one undo step with the mainline from the supply', (tester) async {
    final farm = add(AreaEntity(id: id(), name: 'Farm', points: const [Pt(0, 0), Pt(1000, 0), Pt(1000, 500), Pt(0, 500)]));
    final road = add(LineEntity(id: id(), name: 'Road', a: const Pt(0, -50), b: const Pt(1000, -50)));
    final old = add(PivotEntity(id: id(), name: 'Old pivot', center: const Pt(3000, 3000), radiusM: 100));
    final field = farm.points;

    expect(await refused(tester, 'multi_pivot_layout', {}), contains('Give "field": the id or name of the closed shape (area or closed polyline) of the property.'));
    c.select([old.id]);
    expect(await refused(tester, 'multi_pivot_layout', {}), contains('Give "field"'), reason: 'a pivot drawn is no property outline');
    c.select(const []);
    expect(await refused(tester, 'multi_pivot_layout', {'field': 'Road'}), contains('"Road" is not a closed shape (an area, a closed polyline or a circle) for the property.'));
    expect(
      await refused(tester, 'multi_pivot_layout', {
        'field': 'Farm',
        'obstacles': ['Road'],
      }),
      contains('obstacles: "Road" is not a closed shape.'),
    );
    expect(await refused(tester, 'multi_pivot_layout', {'field': 'Farm', 'max_pivots': 0}), contains('"max_pivots"'));

    /// The engine's arrangement with the options the operation builds.
    MultiPivotLayout expected({
      double depth = 8,
      double hours = 21,
      int minSpans = 2,
      int maxSpans = 12,
      double endThrow = 5,
      double clearance = 5,
      double minRadius = 100,
      int maxPivots = 12,
      double maxFlow = 0,
      Pt? supply,
      bool corners = false,
    }) => layoutPivots(
      field,
      MultiPivotOptions(
        obstacles: [for (final p in c.project.entities.whereType<PivotEntity>()) p.outline()],
        endThrowM: endThrow,
        clearanceM: clearance,
        minRadiusM: minRadius,
        maxPivots: maxPivots,
        minSpans: minSpans,
        maxSpans: math.max(maxSpans, minSpans),
        maxTotalFlow: maxFlow,
        grossDepthMm: depth,
        hoursPerCycle: hours,
        corners: corners,
        supply: supply,
      ),
    );

    /// The rows of the report: each machine's flow is its area × the depth over the hours.
    void checkRows(String text, MultiPivotLayout l, double depth, double hours) {
      for (var k = 0; k < l.pivots.length; k++) {
        final cell = row(text, '${k + 1} | ');
        final p = l.pivots[k];
        expect(cell.sublist(1, 5), [AgentToolbox.pt(p.center), fmt(p.irrigatedRadius, 1), '${p.spans.count}', fmt(p.sectorSweepDeg, 0)]);
        expect(n(cell[6]), closeTo(n(cell[5]) * 1e4 * depth / 1000 / hours, 0.11));
      }
    }

    String summary(MultiPivotLayout l) =>
        '${l.pivots.length} pivots (${l.strategy}) in ${farm.id}: ${fmt(l.irrigatedAreaM2 / 1e4, 2)} ha of 50.00 ha (${fmt(l.coverage * 100, 1)} %), total flow ${fmt(l.totalFlow * 3600, 1)} m³/h, mainline ${fmt(l.mainlineLengthM, 0)} m.';

    // apply false is a read: it runs in plan mode and changes nothing
    final read = await run(tester, 'multi_pivot_layout', {'field': 'Farm', 'max_spans': 4, 'depth_mm': 10, 'hours': 20, 'apply': false}, AgentPermission.plan);
    final l0 = expected(maxSpans: 4, depth: 10, hours: 20);
    expect(l0.pivots.length, greaterThanOrEqualTo(2));
    expect(read, startsWith(summary(l0)));
    checkRows(read, l0, 10, 20);
    expect(c.historyIndex, 0);
    expect(c.project.entities.whereType<PivotEntity>(), hasLength(1));
    final (_, planned) = await turn(tester, [
      ('multi_pivot_layout', {'field': 'Farm', 'max_spans': 4}),
    ], permission: AgentPermission.plan);
    expect(planned.calls.single.state, ToolCallState.refused, reason: 'drawing them is a change');

    // drawn from the selection, the flow of the water supply allowed: the smallest machines go
    final supply = add(WaterSupplyEntity(id: id(), position: const Pt(0, 250), maxFlow: l0.totalFlow * 0.6));
    c.select([farm.id]);
    final steps = c.historyIndex;
    final l1 = expected(maxSpans: 4, depth: 10, hours: 20, maxFlow: supply.maxFlow, supply: supply.position);
    final drawn = await run(tester, 'multi_pivot_layout', {'max_spans': 4, 'depth_mm': 10, 'hours': 20});
    expect(l1.totalFlow, lessThanOrEqualTo(supply.maxFlow + 1e-12));
    expect(l1.messages, contains('mpivot_flow_limit'));
    expect(c.historyIndex, steps + 1, reason: 'one undo step');
    expect(c.historyEntries.last.label, 'hist.aiTool|multi_pivot_layout');
    final made = c.project.entities.whereType<PivotEntity>().where((p) => p.id != old.id).toList();
    expect(made, hasLength(l1.pivots.length));
    expect(drawn, startsWith('Drawn: pivots ${made.map((p) => p.id).join(', ')} and ${l1.mainline.length} mainline pipes. ${summary(l1)}'));
    expect(drawn, contains(c.t('warn.mpivot_flow_limit')));
    checkRows(drawn, l1, 10, 20);
    for (var k = 0; k < made.length; k++) {
      final e = made[k];
      expect(e.name, '${c.t('tool.pivot')} ${k + 2}', reason: 'numbered after the pivot drawn');
      expect(e.center, l1.pivots[k].center);
      expect(e.radiusM, closeTo(l1.pivots[k].machineLength, 1e-9));
      expect(e.grossDepthMm, 10);
      expect(e.hoursPerCycle, 20);
    }
    final mains = c.project.entities.whereType<PipeEntity>().where((p) => p.scope == HydraulicScope.mainline).toList();
    expect(mains, hasLength(l1.pivots.length), reason: 'the tree joins the supply and every pivot point');
    expect(mains.first.points.first, supply.position);
    c.undo();
    expect([for (final p in c.project.entities.whereType<PivotEntity>()) p.id], [old.id]);
    expect(c.project.entities.whereType<PipeEntity>(), isEmpty);

    // every other option; no mainline, the flow typed instead of the supply's
    final l2 = expected(endThrow: 15, clearance: 20, minRadius: 150, maxPivots: 2, minSpans: 3, maxSpans: 2, corners: true, supply: supply.position);
    final other = await run(tester, 'multi_pivot_layout', {
      'field': farm.id,
      'end_throw_m': 15,
      'clearance_m': 20,
      'min_radius_m': 150,
      'max_pivots': 2,
      'min_spans': 3,
      'max_spans': 2,
      'max_flow_m3h': 0,
      'corners': true,
      'mainline': false,
    });
    expect(l2.pivots, hasLength(2));
    expect(other, startsWith('Drawn: pivots ${c.project.entities.whereType<PivotEntity>().skip(1).map((p) => p.id).join(', ')}. ${summary(l2)}'));
    expect(other, contains(c.t('warn.mpivot_max')));
    for (final p in l2.pivots) {
      expect(p.spans.count, 3, reason: 'max_spans below min_spans is raised to it');
    }
    expect(c.project.entities.whereType<PipeEntity>(), isEmpty);
    c.undo();

    // nothing fits: the report only, even with apply
    final none = await run(tester, 'multi_pivot_layout', {'field': 'Farm', 'min_radius_m': 2000});
    expect(none, startsWith('0 pivots (largest) in ${farm.id}: 0.00 ha of 50.00 ha (0.0 %)'));
    expect(none, contains(c.t('warn.mpivot_none')));
    expect([for (final p in c.project.entities.whereType<PivotEntity>()) p.id], [old.id]);
    expect(road.a, const Pt(0, -50));
  });

  testWidgets('traveller lanes: ten lanes 60 m apart across a 600 × 400 m field, drawn with their hydrant line and system flows as one undo step', (tester) async {
    final paddock = add(AreaEntity(id: id(), name: 'Paddock', points: const [Pt(0, 0), Pt(600, 0), Pt(600, 400), Pt(0, 400)]));
    final field = paddock.points;
    expect(await refused(tester, 'traveller_lanes', {}), contains('Give "field": the id or name of the closed shape (area or closed polyline) of the lanes.'));
    expect(await refused(tester, 'traveller_lanes', {'field': 'Paddock', 'gun': 'nope'}), contains('"nope" is not a gun of the catalogue.'));
    final gun = c.project.catalog.outlet('gun')!;
    expect(await refused(tester, 'traveller_lanes', {'field': 'Paddock', 'gun': 'gun', 'nozzle': 'zz'}), contains('"zz" is no nozzle of gun: ${gun.nozzles.map((x) => x.id).join(', ')}.'));
    expect(await refused(tester, 'traveller_lanes', {'field': 'Paddock', 'wind': 'storm'}), contains('must be one of: none, light, moderate, strong'));

    // the default gun (45 m³/h, 80 m wetted) in light wind: 75 % of 80 m → 60 m, across the longest edge
    final read = await run(tester, 'traveller_lanes', {'field': 'Paddock', 'apply': false});
    expect(read, startsWith('10 lanes across ${paddock.id} at 90°.'));
    final lanes = rows(read, 'Lane ');
    expect(lanes, hasLength(10));
    final template = TravellerEntity(id: '', start: Pt.zero, end: const Pt(100, 0));
    for (var k = 0; k < 10; k++) {
      final cell = lanes[k];
      // numbered from the east (the side the lane direction turns away from)
      final x = 570 - 60.0 * k;
      expect(cell[0], 'Lane ${k + 1}');
      expect(cell[1], AgentToolbox.pt(Pt(x, 0)), reason: 'hydrants on the edge, 60 m apart');
      // the run stops a wetted radius short of the far edge
      expect(cell[2], AgentToolbox.pt(Pt(x, 360)));
      expect([cell[3], cell[4], cell[6]], ['360', '60.0', '25.0']);
      final r = analyzeTravellerLane(
        c.project,
        template.clone()
          ..start = Pt(x, 0)
          ..end = Pt(x, 360),
      );
      expect(n(cell[8]), closeTo(50 + r.result.hoseFrictionM + 7 + 2.5, 0.051), reason: 'gun pressure + hose + drive + gun height');
      expect(n(cell[5]), closeTo(r.result.speedMPerMin, 0.0051));
    }
    expect(c.historyIndex, 0);

    // drawn from the selection with every setting of the reel
    c.select([paddock.id]);
    final steps = c.historyIndex;
    final drawn = await run(tester, 'traveller_lanes', {
      'angle_deg': 90,
      'gun_flow_m3h': 50,
      'wetted_diameter_m': 90,
      'gun_pressure_m': 45,
      'sector_deg': 270,
      'hose_m': 300,
      'hose_bore_mm': 110,
      'drive_loss_m': 6,
      'lane_width_m': 0,
      'depth_mm': 30,
      'wind': 'moderate',
      'setup_h': 1,
      'hours_per_day': 20,
      'machine': 'R1',
      'machine_cost': 30000,
      'hydrant_cost': 150,
    });
    expect(c.historyIndex, steps + 1, reason: 'one undo step');
    expect(c.historyEntries.last.label, 'hist.aiTool|traveller_lanes');
    final made = c.project.entities.whereType<TravellerEntity>().toList();
    final tpl = TravellerEntity(id: '', start: Pt.zero, end: const Pt(100, 0))
      ..gunFlow = 50 / 3600
      ..wettedDiameterM = 90
      ..gunPressureM = 45
      ..sectorDeg = 270
      ..hoseLengthM = 300
      ..hoseInnerMm = 110
      ..driveLossM = 6
      ..targetDepthMm = 30
      ..wind = WindClass.moderate
      ..setupHours = 1
      ..hoursPerDay = 20;
    var seq = 0;
    final engine = layoutTravellerLanes(c.project, field, tpl, angleDeg: 90, newId: () => 'x${seq++}');
    expect(made, hasLength(engine.length));
    expect(drawn, startsWith('Drawn lanes ${made.map((l) => l.id).join(', ')} and the hydrant line, one system flow each. ${made.length} lanes across ${paddock.id} at 90°.'));
    for (var k = 0; k < made.length; k++) {
      final l = made[k];
      expect(l.name, 'Lane ${k + 1}');
      expect(l.start, engine[k].start);
      expect(l.start.y, closeTo(0, 1e-9));
      expect(l.runLengthM, closeTo(300, 1e-9), reason: 'the hose length, shorter than the field less a wetted radius');
      expect([l.gunFlow * 3600, l.wettedDiameterM, l.gunPressureM, l.sectorDeg, l.hoseLengthM, l.hoseInnerMm, l.driveLossM, l.targetDepthMm], [closeTo(50, 1e-9), 90, 45, 270, 300, 110, 6, 30]);
      expect([l.wind, l.setupHours, l.hoursPerDay, l.machine, l.machineCost, l.hydrantCost, l.layer], [WindClass.moderate, 1, 20, 'R1', 30000, 150, Layers.travellers]);
      expect(c.project.systemFlows.where((f) => f.id == 'sf_${l.id}').single.valveIds, {l.id});
    }
    final line = c.project.entities.whereType<PipeEntity>().single;
    expect(line.scope, HydraulicScope.mainline);
    expect(line.points, [for (final l in made) l.start]);
    expect(c.project.systemFlows, hasLength(made.length), reason: 'nothing else to run: no flow of all the zones');
    c.undo();
    expect(c.project.entities.whereType<TravellerEntity>(), isEmpty);
    expect(c.project.entities.whereType<PipeEntity>(), isEmpty);
    expect(c.project.systemFlows, isEmpty);

    // the catalogue gun along the field, lanes 50 m apart, without the hydrant line or flows
    final along = await run(tester, 'traveller_lanes', {'field': 'Paddock', 'gun': 'gun', 'angle_deg': 0, 'lane_width_m': 50, 'hydrant_line': false, 'flows': false});
    final eight = c.project.entities.whereType<TravellerEntity>().toList();
    expect(eight, hasLength(8), reason: '400 m across in lanes of 50 m');
    expect(along, startsWith('Drawn lanes ${eight.map((l) => l.id).join(', ')}. 8 lanes across ${paddock.id} at 0°.'));
    for (var k = 0; k < 8; k++) {
      expect(eight[k].start, Pt(0, 25 + 50.0 * k));
      expect(eight[k].gunSpecId, 'gun');
      expect(eight[k].gunNozzleId, gun.nozzles.first.id, reason: 'the first nozzle of the gun');
    }
    final q = analyzeTravellerLane(c.project, eight.first).flow;
    expect(q, closeTo(gunPerformance(gun.nozzles.first, 50).$1, 1e-12), reason: 'the flow of the nozzle at the gun pressure');
    expect(c.project.entities.whereType<PipeEntity>(), isEmpty);
    expect(c.project.systemFlows, isEmpty);
  });

  testWidgets('furrow set: refused without a head line, reported by the FAO 45 balance, drawn with every value and its system flow as one undo step', (tester) async {
    final pump = add(PumpEntity(id: id(), name: 'Pump', position: const Pt(0, -20)));
    expect(await refused(tester, 'furrow_set', {}), contains('Give "line": a line or polyline for the head of the furrows.'));
    expect(await refused(tester, 'furrow_set', {'line': 'Pump'}), contains('Give "line"'));
    final head = add(LineEntity(id: id(), name: 'Head', a: const Pt(0, -10), b: const Pt(100, -10)));
    expect(await refused(tester, 'furrow_set', {'line': 'Head', 'spacing_m': 9}), contains('"spacing_m" = 9.0 is outside 0.2 … 5.0.'));
    c.select([head.id]);

    // 100 m of head line at 0.9 m: 111 furrows, all at once
    final read = await run(tester, 'furrow_set', {'apply': false});
    final r0 = analyzeFurrowSet(
      c.project,
      FurrowEntity(id: 'x', points: [head.a, head.b]),
      terrain: c.project.buildTerrain(),
    );
    expect([r0.furrows, r0.perSet, r0.sets], [111, 111, 1]);
    expect(
      read,
      startsWith(
        '111 furrows, 111 per set × 1 sets; ${fmt(r0.inflow * 1000, 2)} L/s per furrow (${fmt(r0.setFlow * 3600, 1)} m³/h per set), advance ${fmt(r0.advanceS / 60, 0)} min, cutoff ${fmt(r0.cutoffS / 60, 0)} min, '
        'irrigation of all ${fmt(r0.irrigationHours, 1)} h; Ea ${fmt(r0.efficiency * 100, 0)} %',
      ),
    );
    expect(r0.setFlow, closeTo(r0.inflow * 111, 1e-12));
    expect(c.historyIndex, 0);
    expect(c.project.entities.whereType<FurrowEntity>(), isEmpty);

    final drawn = await change(tester, 'furrow_set', {
      'line': 'Head',
      'right': true,
      'length_m': 150,
      'spacing_m': 0.9,
      'slope': 0.003,
      'family': 0.3,
      'manning': 0.05,
      'depth_mm': 70,
      'inflow_lps': 0,
      'per_set': 40,
      'gated': true,
      'pipe_bore_mm': 200,
      'pipe_cost': 12,
      'gate_cost': 3,
    });
    final f = c.project.entities.whereType<FurrowEntity>().single;
    expect(f.name, 'Furrow set 1');
    expect(f.layer, Layers.surface);
    expect(f.points, [head.a, head.b]);
    expect([f.leftSide, f.furrowLengthM, f.furrowSpacingM, f.slope, f.intakeFamily, f.manningN, f.requiredDepthMm, f.inflowLps], [false, 150, 0.9, 0.003, 0.3, 0.05, 70, 0]);
    expect([f.furrowsPerSet, f.gatedPipe, f.pipeInnerMm, f.pipeCostPerM, f.gateCost], [40, true, 200, 12, 3]);
    expect(c.project.systemFlows.where((x) => x.id == 'sf_${f.id}').single.valveIds, {f.id});
    final r1 = analyzeFurrowSet(c.project, f, terrain: c.project.buildTerrain());
    expect([r1.furrows, r1.perSet, r1.sets], [111, 40, 3], reason: '111 furrows in sets of 40');
    expect(drawn, startsWith('Drew furrow set ${f.id} with a system flow: 111 furrows, 40 per set × 3 sets; ${fmt(r1.inflow * 1000, 2)} L/s per furrow'));
    expect(drawn, contains('inlet head ${fmt(r1.inletHeadM, 2)} m.'));
    c.undo();
    expect(c.project.entities.whereType<FurrowEntity>(), isEmpty);
    expect(c.project.systemFlows, isEmpty);

    // a head ditch with siphons and the inflow given, without a flow
    final ditch = await change(tester, 'furrow_set', {'line': head.id, 'gated': false, 'inflow_lps': 1.5, 'flow': false});
    final d = c.project.entities.whereType<FurrowEntity>().single;
    expect([d.gatedPipe, d.inflowLps], [false, 1.5]);
    expect(ditch, startsWith('Drew furrow set ${d.id}: 111 furrows, 111 per set × 1 sets; 1.50 L/s per furrow (${fmt(1.5 / 1000 * 111 * 3600, 1)} m³/h per set)'));
    expect(ditch, contains('inlet head ${fmt(ditchInletHeadM, 2)} m.'));
    expect(c.project.systemFlows, isEmpty);
    expect(pump.position, const Pt(0, -20));
  });

  testWidgets('field machines: the lanes and furrow sets as drawn, then with the heads the design leaves at their inlets', (tester) async {
    expect(await run(tester, 'field_machines'), 'No traveller lane and no furrow set in the drawing (traveller_lanes, furrow_set).');
    final main = c.project.catalog.pipesFor(PipeUsage.mainline).last;
    add(WaterSupplyEntity(id: id(), position: Pt.zero, designHeadM: 80, calculatePressure: false));
    add(PipeEntity(id: id(), points: const [Pt(0, 0), Pt(400, 0), Pt(800, 0)], scope: HydraulicScope.mainline, pipeSpecId: main.id, computerSized: false));
    final a = add(TravellerEntity(id: id(), name: 'Lane A', start: const Pt(400, 0), end: const Pt(400, 300)));
    final b = add(TravellerEntity(id: id(), name: 'Lane B', start: const Pt(800, 0), end: const Pt(800, 300)));
    final f = add(FurrowEntity(id: id(), name: 'Furrows', points: [const Pt(800, 0), const Pt(800, -100)], furrowsPerSet: 40));
    c.project.systemFlows.addAll([
      SystemFlow(id: 'f1', name: 'Lane A', valveIds: {a.id}, durationHours: 10),
      SystemFlow(id: 'f2', name: 'Lane B', valveIds: {b.id}, durationHours: 10),
      SystemFlow(id: 'f3', name: 'Furrows', valveIds: {f.id}, durationHours: 10),
    ]);

    var text = await run(tester, 'field_machines');
    for (final l in [a, b]) {
      final cell = row(text, '${l.id} ${l.name} |');
      // 45 m³/h of the default gun, 25 mm on the 60 m lane over 300 m
      expect([cell[1], cell[2], cell[3], cell[4], cell[6]], ['A', '300', '60.0', '45.0', '25.0']);
      final r = analyzeTravellerLane(c.project, l);
      expect(n(cell[11]), closeTo(50 + r.result.hoseFrictionM + 7 + 2.5, 0.051));
      expect(cell[12], '-', reason: 'no design: no head available yet');
    }
    final set = row(text, '${f.id} Furrows |');
    expect(set.sublist(1, 4), ['111', '40', '3']);
    expect(set[13], '-');
    expect(text, endsWith('No design results: the hydrant pressures come with run_design.'));

    await design(tester);
    final steps = c.historyIndex;
    text = await run(tester, 'field_machines');
    final agb = c.results!.agb!;
    expect(agb.travellers, hasLength(2));
    for (final l in agb.travellers) {
      final cell = row(text, '${l.laneId} ${l.name} |');
      expect(l.availableHead!, greaterThan(l.requiredHead), reason: '80 m at the supply is enough');
      expect(n(cell[12]), closeTo(l.availableHead!, 0.051));
      expect(n(cell[11]), closeTo(l.requiredHead, 0.051));
    }
    final fr = agb.furrows.single;
    final cell = row(text, '${f.id} Furrows |');
    expect(n(cell[5]), closeTo(fr.setFlow * 3600, 0.051));
    expect(n(cell[12]), closeTo(fr.inletHeadM, 0.0051));
    expect(n(cell[13]), closeTo(fr.availableHead!, 0.051));
    expect(text, isNot(contains('No design results')));
    expect(c.historyIndex, steps, reason: 'reading changes nothing');
    expect(c.results, isNotNull, reason: 'nor discards the results');
  });
}
