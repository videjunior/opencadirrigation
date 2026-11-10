import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/op_parts/agr.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/design/catch_cans.dart';
import 'package:opencadirrigation/core/design/densogram.dart';
import 'package:opencadirrigation/core/design/fertigation_stages.dart';
import 'package:opencadirrigation/core/design/irrigation_programme.dart';
import 'package:opencadirrigation/core/design/runoff_potential.dart';
import 'package:opencadirrigation/core/design/soil_water_balance.dart';
import 'package:opencadirrigation/core/design/system_capacity.dart';
import 'package:opencadirrigation/core/io/inmet_csv.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';

import 'support/fake_claude.dart';

/// The agronomy operations of the AI assistant (lib/app/ai/op_parts/agr.dart:
/// daily water balance, runoff potential, capacity, irrigation programme and
/// its export, depth densogram, catch cans and field tests, fertigation by
/// stage, the user's crops and the station file) run through the scripted
/// model and the real agent loop on small projects: the numbers they report
/// are those of the engine modules they call, every change is one undo step,
/// the export is confirmed and written through the app's file sink, and each
/// says what is missing when it cannot run.
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
    ops = opsAgr(box);
    files.clear();
    approvals.clear();
    engFileSink = (c, name, mime, data) async => files[name] = data;
  });
  tearDown(() => engFileSink = saveFiles);

  /// One turn of the scripted model calling [calls] at once, then "done":
  /// the tool results the model read, and the turn.
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

  void allFailed(AgentTurn t) {
    for (final call in t.calls) {
      expect(call.state, ToolCallState.failed, reason: '${call.name}: ${call.result}');
    }
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

  List<Pt> rect(double x0, double y0, double w, double h) => [Pt(x0, y0), Pt(x0 + w, y0), Pt(x0 + w, y0 + h), Pt(x0, y0 + h)];

  /// A row of a table of the operations (engTable: cells joined by " | ",
  /// decimals as two places).
  String row(List<Object?> cells) => [for (final x in cells) x is double ? engN(x) : '${x ?? '-'}'].join(' | ');

  /// The hand case of FAO-56 chapter 8 (test/core/soil_water_balance_test.dart):
  /// one hectare, Kc 1, ETo 5 mm/day, no rain, TAW 100 mm, RAW 50 mm, Ea 0.8.
  AreaEntity handArea({String name = 'Plot'}) =>
      add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100), name: name, useWaterBalance: true, etoMmDay: 5, kc: 1, awcMmPerM: 100, rootDepthM: 1, mad: 0.5, efficiency: 0.8));

  /// Four 12F sprays (0.60 m³/h at 20 m) on a 10 × 10 m area at [x0]: 24 mm/h
  /// (one spray in the middle with [heads] 1: 6 mm/h).
  AreaEntity sprays(double x0, {String name = 'Lawn', String soil = 'soil.clay', int heads = 4}) {
    final a = add(AreaEntity(id: c.project.newId(), points: rect(x0, 0, 10, 10), name: name, soilKey: soil, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 150, rootDepthM: 0.3, mad: 0.5));
    final at = heads == 1 ? const [(5.0, 5.0)] : const [(2.5, 2.5), (7.5, 2.5), (2.5, 7.5), (7.5, 7.5)];
    for (final (x, y) in at) {
      add(OutletEntity(id: c.project.newId(), position: Pt(x0 + x, y), outletSpecId: 'spray', nozzleId: 's12', headM: 20));
    }
    return a;
  }

  /// A daily BDMEP export of INMET for [year] ([rain] mm every day), as the
  /// station file test of the reader writes it (test/core/inmet_csv_test.dart).
  String bdmep(int year, {String code = '83377', String name = 'BRASILIA', double rain = 1, bool latitude = true}) {
    String two(int v) => v.toString().padLeft(2, '0');
    final b = StringBuffer('Nome: $name\nCodigo Estacao: $code\n${latitude ? 'Latitude: -15.78\n' : ''}Longitude: -47.92\nAltitude: 1159.54\nSituacao: Operante\nPeriodicidade da Medicao: Diaria\n\n');
    b.writeln(
      'Data Medicao;PRECIPITACAO TOTAL, DIARIO(mm);TEMPERATURA MAXIMA, DIARIA(°C);TEMPERATURA MINIMA, DIARIA(°C);'
      'UMIDADE RELATIVA DO AR, MEDIA DIARIA(%);UMIDADE RELATIVA DO AR, MINIMA DIARIA(%);VENTO, VELOCIDADE MEDIA DIARIA(m/s);',
    );
    for (var d = DateTime.utc(year); d.year == year; d = d.add(const Duration(days: 1))) {
      b.writeln('${d.year}-${two(d.month)}-${two(d.day)};${rain.toString().replaceAll('.', ',')};28,1;18,2;70,5;45;2,1;');
    }
    return b.toString();
  }

  testWidgets('the agronomy operations: in the operations of the toolbox, effects, confirmations and approval summaries', (tester) async {
    const names = [
      'water_balance',
      'runoff_potential',
      'system_capacity',
      'irrigation_programme',
      'export_irrigation_programme',
      'depth_densogram',
      'virtual_catch_cans',
      'set_field_test',
      'field_test_evaluation',
      'delete_field_test',
      'fertigation_by_stage',
      'list_user_crops',
      'set_user_crop',
      'delete_user_crop',
      'import_station_climate',
    ];
    expect([for (final o in ops) o.name], names);
    final all = {for (final o in box.operations) o.name};
    expect(all, containsAll(names), reason: 'opsAgr is joined to AgentToolbox.operations');
    AgentTool op(String n) => ops.firstWhere((o) => o.name == n);
    // what only reads, unless it is asked to keep its settings
    for (final n in ['water_balance', 'irrigation_programme', 'fertigation_by_stage']) {
      expect(op(n).effectOf(const {}), ToolEffect.read, reason: n);
      expect(op(n).effectOf(const {'save': true}), ToolEffect.write, reason: n);
      expect(op(n).describe(const {'save': true}), isNot(op(n).describe(const {})), reason: '$n: saving is named in the approval');
    }
    for (final n in ['runoff_potential', 'system_capacity', 'depth_densogram', 'virtual_catch_cans', 'field_test_evaluation', 'list_user_crops']) {
      expect(op(n).effectOf(const {}), ToolEffect.read, reason: n);
    }
    for (final n in ['set_field_test', 'delete_field_test', 'set_user_crop', 'delete_user_crop', 'import_station_climate']) {
      expect(op(n).effectOf(const {}), ToolEffect.write, reason: n);
    }
    expect(op('export_irrigation_programme').effectOf(const {}), ToolEffect.export);
    // files and deletions are confirmed whatever the mode; plain changes are not
    for (final n in ['export_irrigation_programme', 'delete_field_test', 'delete_user_crop']) {
      expect(op(n).mustConfirm(const {'id': 'x'}), isTrue, reason: n);
    }
    for (final n in ['set_field_test', 'set_user_crop', 'import_station_climate', 'water_balance']) {
      expect(op(n).mustConfirm(const {'save': true}), isFalse, reason: n);
    }
    expect(op('water_balance').describe(const {'save': true}), 'Save the water balance settings of the area');
    expect(op('import_station_climate').describe(const {'name': 'a001.csv'}), 'Import the climate of the station file a001.csv');
    for (final o in ops) {
      expect(o.describe(const {}).startsWith('ai.op.'), isFalse, reason: '${o.name}: the summary is translated');
    }
  });

  testWidgets('water balance of an area with a typed Kc: the FAO-56 hand case, its options, and the settings kept as one undo step', (tester) async {
    final a = handArea();
    expect(c.project.climate, isNull, reason: 'the ETo typed on the area, no rain');
    final (text, t) = await turn(tester, [
      ('water_balance', {'area': 'Plot'}),
    ]);
    allDone(t);
    // 36 refills of 50 mm (62.5 mm gross) over the 365 days of the typical year
    expect(text, contains('Plot: 2001-01-01 … 2001-12-31 (365 days), typical year of the normals, depletion.'));
    expect(text, contains('ETc 1825 mm, ETa 1825 mm (100.0 %), rain 0 mm (effective 0), net irrigation 1800 mm, gross 2250 mm (22500 m³), deep percolation 0 mm.'));
    expect(text, contains('36 irrigations, 0 days of stress.'));
    expect(text, contains('date | depletion mm | net mm | gross mm\n2001-01-10 | 50.00 | 50.00 | 62.50\n2001-01-20 | 50.00 | 50.00 | 62.50'));
    expect(text, isNot(contains('relative yield')), reason: 'no Ky for a typed Kc');
    expect(text, isNot(contains('Messages:')));
    expect(c.historyIndex, 0, reason: 'reading the balance changes nothing');
    // every option, against the engine with the same settings, and the hand
    // values of the engine test where it has them
    final cases = <(Map<String, dynamic>, BalanceSettings, List<String>)>[
      // a week apart: whatever was used, 1825 mm in 53 events
      (
        {'trigger': 'interval', 'interval_days': 7},
        BalanceSettings(trigger: BalanceTrigger.interval, intervalDays: 7),
        ['interval.', 'net irrigation 1825 mm', '53 irrigations', '2001-01-01 | 5.00 | 5.00 | 6.25'],
      ),
      // half refills: 25 mm every 5 days
      ({'refill_pct': 50}, BalanceSettings(refillPct: 50), ['2001-01-10 | 50.00 | 25.00 | 31.25', '2001-01-15 | 50.00 | 25.00 | 31.25']),
      ({'initial_depletion_pct': 40, 'rain_events': 2}, BalanceSettings(initialDepletionPct: 40, rainEventsPerMonth: 2), ['2001-01-02 | 50.00 | 50.00 | 62.50']),
      // regulated deficit at 70 % of the available water in mid-season: named, and the stress it costs
      (
        {
          'allowed_depletion': [0, 0, 0.7, 0],
        },
        BalanceSettings(allowedDepletion: [0, 0, 0.7, 0]),
        ['depletion with deficit 0.00/0.00/0.70/0.00.', '24 irrigations', '2001-01-15 | 70.48 | 70.48 | 88.09', 'Messages: The crop spends days under water stress'],
      ),
      // rain only: dry from day 11, the yield down by Ky times the share of ETc lost
      ({'trigger': 'rainfed', 'ky': 1}, BalanceSettings(trigger: BalanceTrigger.rainfed, ky: 1), ['rainfed.', '0 irrigations, 354 days of stress, relative yield ']),
    ];
    for (final (input, settings, hand) in cases) {
      final (out, tc) = await turn(tester, [
        ('water_balance', {'area': a.id, 'events_limit': 3, ...input}),
      ]);
      allDone(tc);
      final r = areaWaterBalance(c.project, a, settings: settings)!;
      expect(out, contains('ETc ${engN(r.etcMm, 0)} mm, ETa ${engN(r.etaMm, 0)} mm (${engN(100 * r.relativeEt, 1)} %)'), reason: '$input');
      expect(out, contains('net irrigation ${engN(r.netMm, 0)} mm, gross ${engN(r.grossMm, 0)} mm (${engN(r.grossMm * 10, 0)} m³)'), reason: '$input');
      expect(out, contains('${r.events.length} irrigations, ${r.stressDays} days of stress'), reason: '$input');
      if (r.relativeYield != null) expect(out, contains('relative yield ${engN(100 * r.relativeYield!, 1)} % (Ky ${engN(r.ky!, 2)}).'), reason: '$input');
      if (r.events.length > 3) expect(out, contains('(${r.events.length - 3} more rows)'), reason: '$input');
      for (final e in r.events.take(3)) {
        expect(out, contains(row([e.date.toIso8601String().substring(0, 10), e.depletionMm, e.netMm, e.grossMm])), reason: '$input');
      }
      for (final h in hand) {
        expect(out, contains(h), reason: '$input');
      }
    }
    // with Ky 1 the relative yield is the relative ET (FAO-56 eq. 90)
    expect(
      areaWaterBalance(c.project, a, settings: BalanceSettings(trigger: BalanceTrigger.rainfed, ky: 1))!.relativeYield,
      closeTo(areaWaterBalance(c.project, a, settings: BalanceSettings(trigger: BalanceTrigger.rainfed))!.relativeEt, 1e-12),
    );
    final steps = c.historyIndex;
    expect(steps, 0, reason: 'reading the balance with other settings changes nothing');
    // the settings kept for the area: one undo step, the report then uses them
    final (saved, ts) = await turn(tester, [
      ('water_balance', {'area': a.id, 'trigger': 'interval', 'interval_days': 5, 'rain_events': 2, 'save': true}),
    ]);
    allDone(ts);
    expect(ts.calls.single.effect, ToolEffect.write);
    expect(saved, contains('Settings kept for the area (the report shows them).'));
    final kept = c.project.agronomy.balance[a.id]!;
    expect(kept.trigger, BalanceTrigger.interval);
    expect(kept.intervalDays, 5);
    expect(kept.rainEventsPerMonth, 2);
    expect(c.historyIndex, steps + 1);
    expect(c.historyEntries.last.label, 'hist.aiTool|water_balance');
    final (again, _) = await turn(tester, [
      ('water_balance', {'area': a.id}),
    ]);
    expect(again, contains('interval.'), reason: 'the kept settings are the defaults of the next call');
    expect(again, contains('${areaWaterBalance(c.project, a)!.events.length} irrigations'));
    c.undo();
    expect(c.project.agronomy.balance.containsKey(a.id), isFalse);
  });

  testWidgets('water balance: a year of the daily series, and what it answers without an area, a balance, a series or with a bad argument', (tester) async {
    final a = handArea();
    final fixed = add(AreaEntity(id: c.project.newId(), points: rect(200, 0, 50, 50), name: 'Fixed'));
    final thin = add(AreaEntity(id: c.project.newId(), points: const [Pt(300, 0), Pt(310, 0)], name: 'Thin', useWaterBalance: true, etoMmDay: 5, kc: 1));
    final supply = add(WaterSupplyEntity(id: c.project.newId(), position: const Pt(-10, -10)));
    final (bad, tb) = await turn(tester, [
      ('water_balance', {'area': a.id, 'year': 2019}),
      ('water_balance', {'area': fixed.id}),
      ('water_balance', {'area': thin.id}),
      ('water_balance', {'area': supply.id}),
      ('water_balance', {'area': 'Nowhere'}),
      (
        'water_balance',
        {
          'area': a.id,
          'allowed_depletion': [0, 0, 0.99, 0],
        },
      ),
      ('water_balance', {'area': a.id, 'interval_days': 0}),
      ('water_balance', {'area': a.id, 'trigger': 'weekly'}),
      ('water_balance', {}),
    ]);
    allFailed(tb);
    expect(bad, contains('The site climate has no daily series: download it or import a station file, or use year 0 (typical year).'));
    expect(bad, contains('Fixed has a fixed daily depth, no water balance'));
    expect(bad, contains('No balance for Thin.'));
    expect(bad, contains('"${supply.id}" is not an irrigated area.'));
    expect(bad, contains('No item "Nowhere"'));
    expect(bad, contains('"allowed_depletion" has 0.99, outside 0.0 … 0.95.'));
    expect(bad, contains('"interval_days" = 0.0 is outside 1.0 … 60.0.'));
    expect(bad, contains('must be one of: depletion, interval, rainfed'));
    expect(bad, contains('Missing "input.area"'));
    expect(c.project.agronomy.balance, isEmpty);
    // two years of a daily series: 2019 rains 15 mm a week
    final days = [for (var i = 0; i < 730; i++) (DateTime.utc(2018).add(Duration(days: i)), 5.0, DateTime.utc(2018).add(Duration(days: i)).year == 2019 && i % 7 == 0 ? 15.0 : 0.0)];
    c.project.climate = SiteClimate(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 0.0), daily: DailyClimate.fromDays(days));
    final (text, t) = await turn(tester, [
      ('water_balance', {'area': a.id, 'year': 2019}),
      ('water_balance', {'area': a.id, 'year': 2017}),
      ('water_balance', {'area': a.id, 'year': 0}),
    ]);
    expect(t.calls[0].state, ToolCallState.done, reason: t.calls[0].result);
    final y2019 = areaWaterBalance(c.project, a, settings: BalanceSettings(year: 2019))!;
    expect(y2019.rainMm, greaterThan(0));
    expect(text, contains('Plot: 2019-01-01 … 2019-12-31 (365 days), year 2019 of the daily series, depletion.'));
    expect(text, contains('rain ${engN(y2019.rainMm, 0)} mm (effective ${engN(y2019.effectiveRainMm, 0)}), net irrigation ${engN(y2019.netMm, 0)} mm'));
    expect(t.calls[1].state, ToolCallState.failed);
    expect(text, contains('No complete year 2017 in the daily series; years: 2018, 2019.'));
    expect(t.calls[2].state, ToolCallState.done);
    expect(text, contains('net irrigation 1800 mm'), reason: 'year 0 is the typical year of the normals');
  });

  testWidgets('runoff potential: the gallery pivot on clay station by station, the soil typed, sprinkler areas with cycle and soak, nothing to analyse', (tester) async {
    final (none, t0) = await turn(tester, [('runoff_potential', {})]);
    allDone(t0);
    expect(none, contains('Nothing to analyse: no machine and no sprinkler area with a soil class.'));
    loadExampleAction(c, ExampleId.pivot);
    final pv = c.project.entities.whereType<PivotEntity>().single;
    final field = c.project.entities.whereType<AreaEntity>().single;
    final (bare, t1) = await turn(tester, [('runoff_potential', {})]);
    allDone(t1);
    expect(bare, contains('${pv.name.isEmpty ? pv.id : pv.name}: no soil under the pivot point (set the soil of the area, or give family and storage_mm) or no flow.'));
    field
      ..soilKey = 'soil.clay'
      ..slopePct = 15;
    // a drive speed, so the design knows the depth of a pass at 100 % of the timer
    pv.machine.towerSpeedMPerMin = 2.4;
    await design(tester);
    final r = machineRunoff(c.project, pv, results: c.results)!;
    expect(r.depthAt100Mm, greaterThan(0), reason: 'the design gives the depth at 100 % of the timer');
    final (text, t) = await turn(tester, [
      ('runoff_potential', {'pivot': pv.id}),
    ]);
    allDone(t);
    expect(text, contains('${r.name}: intake family 0.15 in/h, surface storage 2.5 mm, ${engN(r.depthAt100Mm, 1)} mm a pass at 100 %.'));
    expect(text, contains('radius m | mean mm/h | peak mm/h | pass min | depth mm | runoff mm | runoff % | max depth mm | min timer %'));
    for (final w in r.rows) {
      expect(text, contains(row([w.radiusM, w.meanRateMmH, w.peakRateMmH, w.passMinutes, w.depthMm, w.runoffMm, w.runoffPct, w.maxDepthMm, w.minTimerPct == null ? '-' : engN(w.minTimerPct!, 0)])));
    }
    expect(r.worst.runoffMm, greaterThan(0.5), reason: 'the outer spans run off the sloping clay');
    // a sandy family typed, and the intake of a first irrigation after tillage
    final sandy = machineRunoff(c.project, pv, soil: const RunoffSoil(family: 2, surfaceStorageMm: 10), results: c.results)!;
    final first = machineRunoff(c.project, pv, results: c.results, laterIrrigations: false)!;
    final (typed, t2) = await turn(tester, [
      ('runoff_potential', {'pivot': pv.name.isEmpty ? pv.id : pv.name, 'family': 2, 'storage_mm': 10}),
      ('runoff_potential', {'pivot': pv.id, 'initial_irrigation': true}),
      ('runoff_potential', {'pivot': field.id}),
      ('runoff_potential', {'pivot': pv.id, 'family': 9}),
    ]);
    expect([for (final x in t2.calls) x.state], [ToolCallState.done, ToolCallState.done, ToolCallState.failed, ToolCallState.failed]);
    expect(typed, contains('intake family 2.00 in/h, surface storage 10.0 mm'));
    expect(sandy.worst.runoffMm, 0);
    expect(typed, contains(row([sandy.rows.last.radiusM, sandy.rows.last.meanRateMmH, sandy.rows.last.peakRateMmH, sandy.rows.last.passMinutes, sandy.rows.last.depthMm, 0.0, 0.0])));
    final w = first.rows.last;
    expect(typed, contains(row([w.radiusM, w.meanRateMmH, w.peakRateMmH, w.passMinutes, w.depthMm, w.runoffMm, w.runoffPct, w.maxDepthMm])));
    expect(typed, contains('"${field.id}" is not a pivot or linear.'));
    expect(typed, contains('"family" = 9.0 is outside 0.05 … 4.0.'));
    // the sprinkler areas of a new project: sprays on clay run off, one spray on sand does not
    c.newProject();
    final lawn = sprays(0);
    final sand = sprays(20, name: 'Sand bed', soil: 'soil.sand', heads: 1);
    final zones = {for (final z in zoneRunoff(c.project)) z.areaId: z};
    expect(zones.keys, unorderedEquals([lawn.id, sand.id]));
    expect(zones[lawn.id]!.rateMmH, closeTo(24, 1e-6));
    expect(zones[sand.id]!.maxRunMinutes.isFinite, isFalse, reason: 'the sand takes the rate of one spray');
    final (areas, t3) = await turn(tester, [('runoff_potential', {})]);
    allDone(t3);
    expect(areas, contains('Sprinkler areas:\narea | rate mm/h | intake mm/h | storage mm | depth mm | run h | runoff mm | max run min | cycles | soak min'));
    for (final z in zones.values) {
      expect(
        areas,
        contains(row([z.name, z.rateMmH, z.intakeMmH, z.surfaceStorageMm, z.depthMm, z.runHours, z.runoffMm, z.maxRunMinutes.isFinite ? engN(z.maxRunMinutes, 0) : '∞', z.cycles, z.soakMinutes])),
      );
    }
    expect(areas, contains('Lawn | 24.00 | 2.54 | 5.08 |'));
    expect(areas, contains('| ∞ | 1 | 0.00'));
  });

  testWidgets('system capacity: the gallery pivot keeps up in 24 h and is short in the 20-hour window the programme sets', (tester) async {
    final (none, t0) = await turn(tester, [('system_capacity', {})]);
    allDone(t0);
    expect(none, 'No area with a water need watered by a zone or machine.');
    loadExampleAction(c, ExampleId.pivot);
    final pv = c.project.entities.whereType<PivotEntity>().single;
    final name = pv.name.isNotEmpty ? pv.name : (pv.zoneName.isNotEmpty ? pv.zoneName : pv.id);
    final peak = 6 * 1.15 / 0.85; // ETo × Kc / Ea of the field
    final cap = systemCapacity(c.project);
    final m = cap.machines.single;
    expect(m.capacityMmDay, closeTo(8.5, 1e-9));
    final (text, t) = await turn(tester, [('system_capacity', {})]);
    allDone(t);
    expect(text, contains('Irrigation window 24.0 h a day; the flows need ${engN(cap.totalHours, 2)} h on the peak day: they fit.'));
    for (final f in cap.flows) {
      expect(text, contains('- ${f.name.isEmpty ? 'all zones' : f.name}: ${engN(f.hours, 2)} h'));
    }
    expect(text, endsWith('- machine $name: 8.50 mm/day in the window against a peak of ${engN(peak, 2)} mm/day (needs ${engN(peak * 24 / 8.5, 1)} h a day)'));
    // the window of the programme is the window of the check
    final (_, tp) = await turn(tester, [
      ('irrigation_programme', {'window_hours': 20, 'save': true}),
    ]);
    allDone(tp);
    expect(c.project.agronomy.programme.windowHours, 20);
    final short = systemCapacity(c.project);
    expect(short.machines.single.short, isTrue);
    final (late, t2) = await turn(tester, [('system_capacity', {})]);
    allDone(t2);
    expect(late, contains('Irrigation window 20.0 h a day; the flows need ${engN(short.totalHours, 2)} h on the peak day: THEY DO NOT FIT.'));
    expect(late, contains('- machine $name: ${engN(8.5 * 20 / 24, 2)} mm/day in the window against a peak of ${engN(peak, 2)} mm/day (needs ${engN(peak * 24 / 8.5, 1)} h a day) — SHORT'));
  });

  testWidgets('irrigation programme: window, cycle and soak, seasonal adjustment, stations and runs; kept as one undo step', (tester) async {
    loadExampleAction(c, ExampleId.garden);
    final (est, t0) = await turn(tester, [('irrigation_programme', {})]);
    allDone(t0);
    expect(est, startsWith('No design results: the flows are estimated from the catalogue; run_design for the real ones.'));
    for (final a in c.project.entities.whereType<AreaEntity>()) {
      a.soilKey = 'soil.clay';
    }
    await design(tester);
    final steps = c.historyIndex;
    // a look with other settings leaves the project's as they were
    final (look, t1) = await turn(tester, [
      ('irrigation_programme', {'window_start_hour': 20, 'window_hours': 1, 'days': 3, 'rows_limit': 2}),
    ]);
    allDone(t1);
    expect(look, isNot(contains('No design results')));
    expect(look, contains('Window 20.00 h + 1.0 h; busiest day uses '));
    expect(look, contains('Messages: The flows of the day do not fit the irrigation window'));
    expect(look, contains('more rows)'));
    expect(c.project.agronomy.programme.isDefault, isTrue, reason: 'the project keeps its own settings');
    expect(c.historyIndex, steps);
    // cycle and soak on the clay, typed seasonal shares, kept
    final pct = [for (var m = 1; m <= 12; m++) 10.0 * m];
    final (text, t) = await turn(tester, [
      ('irrigation_programme', {'cycle_soak': true, 'min_cycle_minutes': 4, 'max_cycles': 8, 'seasonal_pct': pct, 'in_reports': true, 'days': 2, 'save': true}),
    ]);
    allDone(t);
    expect(t.calls.single.effect, ToolEffect.write);
    final s = c.project.agronomy.programme;
    expect(s.cycleSoak, isTrue);
    expect(s.minCycleMinutes, 4);
    expect(s.maxCycles, 8);
    expect(s.seasonalPct, pct);
    expect(s.inReports, isTrue);
    expect(c.historyIndex, steps + 1);
    expect(text, contains('Settings kept.'));
    final prog = buildIrrigationProgramme(c.project, c.results, days: 2);
    expect(prog.cycles, isNotEmpty, reason: 'sprays on clay are split');
    expect(text, contains('Cycle and soak: ${prog.cycles.values.map((x) => '${engItemName(box, x.flowId)} ${x.cycles} × ${engN(x.runMinutes, 0)} min / ${engN(x.soakMinutes, 0)} min').join('; ')}.'));
    expect(text, contains('Seasonal adjustment (%): Jan 10, Feb 20, Mar 30, Apr 40, May 50, Jun 60, Jul 70, Aug 80, Sep 90, Oct 100, Nov 110, Dec 120.'));
    expect(text, contains('Window 6.00 h + 24.0 h; busiest day uses ${engN(prog.maxDailyWindowHours, 2)} h of it.'));
    expect(prog.stations, isNotEmpty);
    for (final st in prog.stations) {
      expect(
        text,
        contains(row([st.controller.isEmpty ? '-' : st.controller, st.station, st.name, st.areas.join(' + '), st.flowM3h, st.rateMmH, st.intervalDays, for (final x in st.minutesByMonth) engN(x, 0)])),
      );
    }
    expect(text.split('\n').where((l) => RegExp(r'^\d{4}-\d\d-\d\d \| ').hasMatch(l)), hasLength(prog.runs.length), reason: 'every run of the two days');
    for (final r in prog.runs) {
      expect(text, contains('| ${r.flowName} | ${r.cycle}/${r.cycles} | '));
    }
    // the seasonal shares from the requirement again
    final (auto, ta) = await turn(tester, [
      ('irrigation_programme', {'seasonal_auto': true, 'month': 7, 'save': true}),
    ]);
    allDone(ta);
    expect(c.project.agronomy.programme.seasonalPct, isNull);
    final july = buildIrrigationProgramme(c.project, c.results, days: 7, month: 7);
    expect(auto, contains('Seasonal adjustment (%): ${[for (var m = 0; m < 12; m++) '${engMonths[m]} ${engN(july.seasonalPct[m], 0)}'].join(', ')}.'));
    c.undo();
    expect(c.project.agronomy.programme.seasonalPct, pct);
    c.undo();
    expect(c.project.agronomy.programme.isDefault, isTrue, reason: 'one undo step a call');
    final (bad, tb) = await turn(tester, [
      (
        'irrigation_programme',
        {
          'seasonal_pct': [for (var m = 0; m < 12; m++) m == 5 ? 400 : 100],
        },
      ),
      ('irrigation_programme', {'window_hours': 0.5}),
      ('irrigation_programme', {'max_cycles': 30}),
    ]);
    allFailed(tb);
    expect(bad, contains('"seasonal_pct" has 400.0, outside 0.0 … 300.0.'));
    expect(bad, contains('"window_hours" = 0.5 is outside 1.0 … 24.0.'));
    expect(bad, contains('"max_cycles" = 30.0 is outside 1.0 … 24.0.'));
  });

  testWidgets("export irrigation programme: stations and runs as confirmed CSV files through the app's sink; nothing to export", (tester) async {
    final (none, t0) = await turn(tester, [('export_irrigation_programme', {})]);
    expect(t0.calls.single.state, ToolCallState.failed);
    expect(none, contains('(nothing to export: the areas need a crop or a daily depth and the flows zones).'));
    expect(files, isEmpty);
    approvals.clear();
    loadExampleAction(c, ExampleId.garden);
    await design(tester);
    final steps = c.historyIndex;
    final (text, t) = await turn(tester, [
      ('export_irrigation_programme', {}),
      ('export_irrigation_programme', {'what': 'runs', 'days': 3}),
    ]);
    allDone(t);
    expect(approvals.map((x) => x.name), ['export_irrigation_programme', 'export_irrigation_programme'], reason: 'files are confirmed even when changes apply automatically');
    final stem = engStem(c);
    final prog = buildIrrigationProgramme(c.project, c.results, days: 14);
    final stations = files['${stem}_programme_stations.csv'] as String;
    expect(stations, programmeStationsCsv(prog, t: c.t.call));
    expect(stations.split('\n').where((l) => l.isNotEmpty), hasLength(prog.stations.length + 2), reason: 'titles, stations and the seasonal line');
    expect(text, contains('Saved ${stem}_programme_stations.csv (${prog.stations.length} rows).'));
    final runs = files['${stem}_programme_runs.csv'] as String;
    final three = buildIrrigationProgramme(c.project, c.results, days: 3);
    expect(runs.split('\n').where((l) => l.isNotEmpty), hasLength(three.runs.length + 1));
    expect(runs, startsWith('\u{FEFF}'));
    expect(text, contains('Saved ${stem}_programme_runs.csv (${three.runs.length} rows).'));
    expect(c.historyIndex, steps, reason: 'an export changes nothing');
    // declined, and refused in read-only mode: no file
    files.clear();
    final (_, ts) = await turn(tester, [('export_irrigation_programme', {})], answer: Approval.skip);
    expect(ts.calls.single.state, ToolCallState.skipped);
    final (ro, tr) = await turn(tester, [('export_irrigation_programme', {})], permission: AgentPermission.readOnly);
    expect(tr.calls.single.state, ToolCallState.refused);
    expect(ro, contains('read-only'));
    expect(files, isEmpty);
  });

  testWidgets('depth densogram: one event of the programme over the garden, by area, the map shown; nothing without sprinklers', (tester) async {
    final (none, t0) = await turn(tester, [('depth_densogram', {})]);
    allDone(t0);
    expect(none, 'No sprinkler with a wetted radius in the drawing. (or no sprinkler zone runs in the programme).');
    loadExampleAction(c, ExampleId.garden);
    await design(tester);
    final steps = c.historyIndex;
    final d = depthDensogram(c.project, c.results, base: c.densogramOptions);
    expect(d.depth, isTrue);
    final s = d.stats;
    final (text, t) = await turn(tester, [('depth_densogram', {})]);
    allDone(t);
    expect(
      text,
      contains(
        'Depth of one event over ${engN(s.areaM2, 0)} m²: mean ${engN(s.mean, 2)} mm (least ${engN(s.min, 2)}, most ${engN(s.max, 2)}); CU ${engN(s.cu, 1)} %, DU ${engN(s.du, 1)} %, SC ${s.sc.isFinite ? engN(s.sc, 2) : '∞'}, dry ${engN(s.dryPct, 1)} %.',
      ),
    );
    expect(d.areas.length, greaterThan(1));
    expect(
      text,
      contains('By area: ${[for (final x in d.areas) '${x.name.isEmpty ? x.areaId : x.name} ${engN(x.stats.mean, 1)} mm, CU ${engN(x.stats.cu, 0)} %, DU ${engN(x.stats.du, 0)} %'].join('; ')}.'),
    );
    expect(text, isNot(contains('The map is shown')));
    expect(c.overlay, isNot(OverlayMode.densogram));
    // another month, shown on the drawing (a view change, no undo step)
    final july = depthDensogram(c.project, c.results, base: c.densogramOptions, month: 7);
    final (shown, t2) = await turn(tester, [
      ('depth_densogram', {'month': 7, 'show': true}),
    ]);
    allDone(t2);
    expect(shown, contains('mean ${engN(july.stats.mean, 2)} mm'));
    expect(shown, contains('The map is shown on the drawing.'));
    expect(c.overlay, OverlayMode.densogram);
    expect(c.densogramOptions.depthHours, eventHoursByEntity(c.project, c.results, month: 7));
    expect(c.historyIndex, steps);
    final (bad, tb) = await turn(tester, [
      ('depth_densogram', {'month': 13}),
    ]);
    allFailed(tb);
    expect(bad, contains('"month" = 13.0 is outside 1.0 … 12.0.'));
  });

  testWidgets('virtual catch cans: the expected readings of a grid over an area, of every zone or one; a wrong zone and too many cans refused', (tester) async {
    final lawn = sprays(0);
    final map = computeDensogram(c.project);
    final (text, t) = await turn(tester, [
      ('virtual_catch_cans', {'area': 'Lawn', 'hours': 0.5, 'rows_limit': 4}),
    ]);
    allDone(t);
    // nine cans every 3 m, half a spacing in: what each holds after half an hour
    final depths = [
      for (final y in const [1.5, 4.5, 7.5])
        for (final x in const [1.5, 4.5, 7.5]) map.rateAt(Pt(x, y)) * 0.5,
    ];
    final s = FieldStats.of(depths);
    expect(
      text,
      contains(
        '9 cans every 3.0 × 3.0 m in Lawn (3 columns), 0.50 h of every zone: mean ${engN(s.mean, 2)} mm (${engN(canVolumeMl(s.mean, 100), 0)} mL), least ${engN(s.min, 2)}, most ${engN(s.max, 2)}; CU ${engN(s.cu, 1)} %, DU ${engN(s.du, 1)} %.',
      ),
    );
    expect(text, contains('row | col | x | y | mm | mL\n${row([1, 1, 1.5, 1.5, depths[0], canVolumeMl(depths[0], 100)])}'));
    expect(text, contains(row([2, 1, 1.5, 4.5, depths[3], canVolumeMl(depths[3], 100)])));
    expect(text, contains('(5 more rows)'));
    expect(c.historyIndex, 0, reason: 'it changes nothing');
    // a turned grid with a wider mouth, against the engine's evaluation of the same grid
    final grid = canGridOver(lawn.points, id: 'virtual', dx: 2, dy: 4, angleDeg: 30, mouthMm: 200, hours: 2, areaId: lawn.id);
    final e = evaluateFieldTest(c.project, grid);
    final cans = [for (final x in e.predicted) ?x];
    final (turned, t2) = await turn(tester, [
      ('virtual_catch_cans', {'area': lawn.id, 'dx_m': 2, 'dy_m': 4, 'angle_deg': 30, 'mouth_mm': 200, 'hours': 2}),
    ]);
    allDone(t2);
    final ts = FieldStats.of(cans);
    expect(turned, contains('${cans.length} cans every 2.0 × 4.0 m in Lawn (${grid.cols} columns), 2.00 h of every zone: mean ${engN(ts.mean, 2)} mm (${engN(canVolumeMl(ts.mean, 200), 0)} mL)'));
    // one zone of the garden: the cans of its lawn under its own sprinklers only
    loadExampleAction(c, ExampleId.garden);
    await design(tester);
    final front = c.project.entities.whereType<AreaEntity>().first;
    final valves = c.project.entities.whereType<ControlValveEntity>().toList();
    final v1 = valves.first;
    final g1 = canGridOver(front.points, id: 'virtual', zoneId: v1.id, areaId: front.id);
    final e1 = evaluateFieldTest(c.project, g1, results: c.results);
    final z1 = FieldStats.of([for (final x in e1.predicted) ?x]);
    expect(z1.mean, greaterThan(0));
    final (zone, t3) = await turn(tester, [
      ('virtual_catch_cans', {'area': front.id, 'zone': v1.zoneName}),
      ('virtual_catch_cans', {'area': front.id, 'zone': front.id}),
    ]);
    expect(t3.calls.first.state, ToolCallState.done, reason: t3.calls.first.result);
    expect(zone, contains('1.00 h of ${v1.zoneName}: mean ${engN(z1.mean, 2)} mm'));
    expect(t3.calls.last.state, ToolCallState.failed);
    expect(zone, contains('"${front.id}" is not a zone valve.'));
    // a hectare every half metre is 40 000 cans
    c.newProject();
    final big = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100), name: 'Field'));
    final (many, t4) = await turn(tester, [
      ('virtual_catch_cans', {'area': big.id, 'dx_m': 0.5, 'dy_m': 0.5}),
      ('virtual_catch_cans', {'area': big.id, 'dx_m': 0.2}),
    ]);
    allFailed(t4);
    expect(many, contains('That grid has 40000 cans: use a wider spacing.'));
    expect(many, contains('"dx_m" = 0.2 is outside 0.5 … 50.0.'));
  });

  testWidgets('field tests: kept from a grid over the area, evaluated against the design, changed, deleted after confirmation; each one undo step', (tester) async {
    final lawn = sprays(0);
    final (empty, t0) = await turn(tester, [('field_test_evaluation', {})]);
    allDone(t0);
    expect(empty, 'No field test in the project (set_field_test keeps one).');
    // nine cans read in mL, 10 mm on average
    const mm = [8.0, 10.0, 12.0, 9.0, 11.0, 10.0, 10.0, 12.0, 8.0];
    final ml = [for (final d in mm) canVolumeMl(d, 100)];
    final (text, t) = await turn(tester, [
      ('set_field_test', {'area': 'Lawn', 'from_area': true, 'name': 'Front', 'date': '2026-11-01', 'hours': 0.5, 'values': ml}),
    ]);
    allDone(t);
    expect(c.historyIndex, 1, reason: 'one undo step');
    final ft = c.project.agronomy.fieldTests.single;
    expect(ft.id, startsWith('ft'));
    expect(ft.kind, FieldTestKind.cans);
    expect(ft.areaId, lawn.id);
    expect(ft.cols, 3);
    expect(ft.durationH, 0.5);
    expect(ft.values, ml);
    // CU = 100 (1 − Σ|x − x̄| / n x̄) = 100 (1 − 10/90)
    final m = FieldStats.of(mm);
    expect(m.cu, closeTo(100 * (1 - 10 / 90), 1e-9));
    expect(text, contains('Field test ${ft.id} "Front" (2026-11-01): catch cans, 9 readings.'));
    expect(text, contains('Measured: mean 10.00 mm (least 8.00, most 12.00); CU 88.9 %, DU ${engN(m.du, 1)} %, US ${engN(m.us, 1)} %; mean rate 20.00 mm/h.'));
    final e = evaluateFieldTest(c.project, ft);
    expect(e.predictedStats.count, 9);
    expect(
      text,
      contains(
        'Design at the same cans: mean ${engN(e.predictedStats.mean, 2)} mm, CU ${engN(e.predictedStats.cu, 1)} %, DU ${engN(e.predictedStats.du, 1)} %; measured/design ${engN(100 * e.meanRatio, 0)} %.',
      ),
    );
    // changed by id: the readings kept, the name and hours new
    final (changed, t2) = await turn(tester, [
      ('set_field_test', {'id': ft.id, 'name': 'Front lawn', 'hours': 1}),
    ]);
    allDone(t2);
    expect(c.historyIndex, 2);
    final ft2 = c.project.agronomy.fieldTests.single;
    expect(ft2.name, 'Front lawn');
    expect(ft2.durationH, 1);
    expect(ft2.values, ml);
    expect(ft2.date, '2026-11-01');
    expect(changed, contains('Field test ${ft.id} "Front lawn" (2026-11-01): catch cans, 9 readings.'));
    expect(changed, contains('mean rate 10.00 mm/h'));
    // on a triangle the cans outside are left out: the readings of those inside, or of every slot
    final tri = add(AreaEntity(id: c.project.newId(), points: const [Pt(20, 0), Pt(30, 0), Pt(20, 10)], name: 'Corner'));
    final grid = canGridOver(tri.points, id: 'g');
    final inside = grid.values.whereType<double>().length;
    expect(inside, inExclusiveRange(0, grid.values.length));
    final (corner, t3) = await turn(tester, [
      (
        'set_field_test',
        {
          'area': tri.id,
          'from_area': true,
          'values': [for (var k = 0; k < inside; k++) 50 + k],
        },
      ),
      (
        'set_field_test',
        {
          'area': tri.id,
          'from_area': true,
          'kind': 'cans',
          'values': [for (var k = 0; k < grid.values.length; k++) k == 0 ? -1 : 60],
        },
      ),
    ]);
    allDone(t3);
    expect(c.historyIndex, 4);
    final tests = c.project.agronomy.fieldTests;
    expect(tests, hasLength(3));
    expect(tests[1].values.whereType<double>(), [for (var k = 0; k < inside; k++) 50.0 + k]);
    expect(tests[1].values.where((v) => v == null), hasLength(grid.values.length - inside));
    expect(tests[2].values, hasLength(grid.values.length));
    expect(tests[2].values.first, isNull, reason: 'a negative reading is a lost can');
    expect(corner, contains('catch cans, $inside readings.'));
    expect(corner, contains('catch cans, ${grid.values.length - 1} readings.'));
    // the evaluation of one test, of every test
    final (one, t4) = await turn(tester, [
      ('field_test_evaluation', {'id': ft.id}),
    ]);
    allDone(t4);
    expect(one, startsWith('Field test ${ft.id} "Front lawn"'));
    expect(one, isNot(contains(tests[1].id)));
    final (every, _) = await turn(tester, [('field_test_evaluation', {})]);
    expect('\n$every'.split('\nField test ').length - 1, 3);
    // the refusals: nothing kept
    final (bad, tb) = await turn(tester, [
      ('set_field_test', {'id': 'ft_none', 'name': 'x'}),
      (
        'set_field_test',
        {
          'from_area': true,
          'values': [1, 2],
        },
      ),
      ('set_field_test', {'area': tri.id, 'from_area': true}),
      (
        'set_field_test',
        {
          'area': tri.id,
          'from_area': true,
          'values': [1, 2],
        },
      ),
      ('set_field_test', {'name': 'Nothing read'}),
      (
        'set_field_test',
        {
          'zone': lawn.id,
          'values': [1],
        },
      ),
      ('field_test_evaluation', {'id': 'ft_none'}),
      ('delete_field_test', {'id': 'ft_none'}),
    ]);
    allFailed(tb);
    expect(bad, contains('No field test "ft_none". Tests: ${tests.map((x) => x.id).join(', ')}.'));
    expect(bad, contains('from_area needs "area".'));
    expect(bad, contains('A grid laid over the area needs its readings: give "values" (virtual_catch_cans lists the cans).'));
    expect(bad, contains('The grid over the area has $inside cans (${grid.values.length} slots with those outside): give that many values.'));
    expect(bad, contains('The test has no readings: give "values".'));
    expect(bad, contains('"${lawn.id}" is not a zone valve.'));
    expect(c.historyIndex, 4);
    expect(approvals.map((x) => x.name), ['delete_field_test'], reason: 'a deletion is confirmed even when it fails afterwards');
    // deleted after confirmation, put back by undo
    approvals.clear();
    final (_, td) = await turn(tester, [
      ('delete_field_test', {'id': ft.id}),
    ], answer: Approval.skip);
    expect(td.calls.single.state, ToolCallState.skipped);
    expect(c.project.agronomy.fieldTests, hasLength(3));
    final (deleted, td2) = await turn(tester, [
      ('delete_field_test', {'id': ft.id}),
    ]);
    allDone(td2);
    expect(approvals.map((x) => x.name), ['delete_field_test', 'delete_field_test']);
    expect(deleted, contains('Field test ${ft.id} deleted.'));
    expect(c.project.agronomy.fieldTests.map((x) => x.id), isNot(contains(ft.id)));
    expect(c.historyIndex, 5);
    c.undo();
    expect(c.project.agronomy.fieldTests.first.name, 'Front lawn');
    c.undo();
    c.undo();
    c.undo();
    expect(c.project.agronomy.fieldTests.single.name, 'Front');
    c.undo();
    expect(c.project.agronomy.fieldTests, isEmpty);
  });

  testWidgets('field tests: a grid typed by its first can and columns, the emitter flows of a drip zone against its design flow', (tester) async {
    loadExampleAction(c, ExampleId.garden);
    await design(tester);
    final valves = c.project.entities.whereType<ControlValveEntity>().toList();
    final front = c.project.entities.whereType<AreaEntity>().first;
    final v1 = valves.first;
    final steps = c.historyIndex;
    // six cans in two rows from (2, 2), every 4 × 4 m, one lost
    final (cans, t) = await turn(tester, [
      (
        'set_field_test',
        {
          'name': 'Sprays',
          'zone': v1.id,
          'area': front.id,
          'origin': [2, 2],
          'cols': 3,
          'dx_m': 4,
          'dy_m': 4,
          'mouth_mm': 150,
          'values': [120, 140, null, 130, 125, 135],
        },
      ),
    ]);
    allDone(t);
    final ft = c.project.agronomy.fieldTests.single;
    expect(ft.origin, const Pt(2, 2));
    expect(ft.cols, 3);
    expect(ft.spacingXM, 4);
    expect(ft.canMouthMm, 150);
    expect(ft.zoneId, v1.id);
    expect(ft.position(4), const Pt(6, 6));
    expect(ft.values[2], isNull);
    final e = evaluateFieldTest(c.project, ft, results: c.results);
    expect(cans, contains('Field test ${ft.id} "Sprays": catch cans of ${v1.zoneName}, 5 readings.'));
    expect(cans, contains('Measured: mean ${engN(e.measuredStats.mean, 2)} mm'));
    expect(
      e.measuredStats.mean,
      closeTo(
        FieldStats.of([
          for (final v in const [120, 140, 130, 125, 135]) canDepthMm(v.toDouble(), 150),
        ]).mean,
        1e-9,
      ),
    );
    expect(cans, contains('Design at the same cans: mean ${engN(e.predictedStats.mean, 2)} mm'));
    // emitter flows of the dripline zone (L/h) against the zone's mean design flow
    final drip = valves.singleWhere((v) => v.position == const Pt(-1, 11), orElse: () => throw StateError('the dripline valve of the garden'));
    expect(c.results!.zones[drip.id]!.outlets, isNotEmpty);
    final (flows, t2) = await turn(tester, [
      (
        'set_field_test',
        {
          'kind': 'emitters',
          'zone': drip.zoneName,
          'values': [1.5, 1.6, 1.55, 1.45],
        },
      ),
    ]);
    allDone(t2);
    final em = c.project.agronomy.fieldTests.last;
    expect(em.kind, FieldTestKind.emitters);
    final ee = evaluateFieldTest(c.project, em, results: c.results);
    expect(ee.designMean, greaterThan(0));
    expect(flows, contains('Field test ${em.id}: emitter flows of ${drip.zoneName}, 4 readings.'));
    expect(ee.measuredStats.mean, closeTo(6.1 / 4, 1e-12));
    expect(
      flows,
      contains(
        'Measured: mean ${engN(ee.measuredStats.mean, 2)} L/h (least 1.45, most 1.60); CU ${engN(ee.measuredStats.cu, 1)} %, DU ${engN(ee.measuredStats.du, 1)} %, US ${engN(ee.measuredStats.us, 1)} %.',
      ),
    );
    expect(flows, isNot(contains('mean rate')));
    expect(flows, contains('Design mean flow of the zone ${engN(ee.designMean, 2)} L/h; measured/design ${engN(100 * ee.meanRatio, 0)} %.'));
    expect(c.historyIndex, steps + 2, reason: 'one undo step a test');
  });

  testWidgets('fertigation by stage: a tomato hectare split by water use, typed shares and products, kept as one undo step', (tester) async {
    final a = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100), name: 'Tomatoes', useWaterBalance: true, cropKey: 'crop.tomato', etoMmDay: 5, climateKc: false));
    final fixed = add(AreaEntity(id: c.project.newId(), points: rect(200, 0, 50, 50), name: 'Fixed'));
    final plan = FertigationStagePlan(doseKgHa: [100, 52, 60]);
    final f = fertigationSchedule(c.project, a, plan: plan)!;
    final (text, t) = await turn(tester, [
      (
        'fertigation_by_stage',
        {
          'area': 'Tomatoes',
          'dose_kg_ha': [100, 52, 60],
        },
      ),
    ]);
    allDone(t);
    expect(text, contains('Tomatoes (1.00 ha): N 100, P2O5 52, K2O 60 kg/ha; products urea 45-0-0, map 11-52-0, kcl 0-0-60; every 1 irrigation(s).'));
    // MAP and KCl first, their nitrogen counted, urea for the rest: (100 − 11)/0.45
    expect(
      text,
      contains(
        'Products of the cycle: urea ${engN(89 / 0.45, 1)} kg, map 100.0 kg, kcl 100.0 kg; ECw ${engN(a.ecwDsM, 2)} → up to ${engN(f.peakEcwDsM, 2)} dS/m while injecting (full-yield limit 1.67).',
      ),
    );
    expect(text, contains('stage | from | to | days | N kg/ha | P2O5 kg/ha | K2O kg/ha | fertigations | urea kg/event | map kg/event | kcl kg/event | stock L | L/h | g/L | ΔEC'));
    expect(f.stages, hasLength(4));
    for (final s in f.stages) {
      final d = s.start.toIso8601String().substring(0, 10), e = s.end.toIso8601String().substring(0, 10);
      expect(text, contains(row([fertStageNames[s.stage], d, e, s.days, ...s.kgHa, s.fertigations, ...s.productKgPerEvent, s.stockLPerEvent, s.injectionLph, s.concentrationGL, s.ecRiseDsM])));
    }
    expect(text, isNot(contains('Plan kept')));
    expect(c.project.agronomy.fertigation, isEmpty);
    // typed shares and products, every second irrigation, a stronger stock and a longer injection: kept
    final products = [
      {'name': 'can', 'n': 27},
      {'name': 'mkp', 'p2o5': 52, 'k2o': 34},
      {'name': 'sop', 'k2o': 50, 'ionic': true},
    ];
    final (kept, t2) = await turn(tester, [
      (
        'fertigation_by_stage',
        {
          'area': a.id,
          'dose_kg_ha': [120, 52, 100],
          'share_pct': [
            [10, 40, 10],
            [30, 30, 20],
            [40, 20, 40],
            [20, 10, 30],
          ],
          'products': products,
          'every_nth': 2,
          'stock_kg_l': 0.5,
          'injection_pct': 80,
          'save': true,
        },
      ),
    ]);
    allDone(t2);
    expect(c.historyIndex, 1, reason: 'one undo step');
    final pl = c.project.agronomy.fertigation[a.id]!;
    expect(pl.doseKgHa, [120, 52, 100]);
    expect(pl.sharePct, [
      [10, 40, 10],
      [30, 30, 20],
      [40, 20, 40],
      [20, 10, 30],
    ]);
    expect(pl.products.map((x) => x.name), ['can', 'mkp', 'sop']);
    expect(pl.products[1].k2oPct, 34);
    expect(pl.products.first.ionic, isTrue, reason: 'a product is a salt unless it says otherwise');
    expect(pl.everyNth, 2);
    expect(pl.stockKgPerL, 0.5);
    expect(pl.injectionPct, 80);
    final f2 = fertigationSchedule(c.project, a)!;
    expect(kept, contains('products can 27-0-0, mkp 0-52-34, sop 0-0-50; every 2 irrigation(s).'));
    expect(kept, contains('Products of the cycle: ${[for (var k = 0; k < 3; k++) '${pl.products[k].name} ${engN(f2.productTotalsKg[k], 1)} kg'].join(', ')};'));
    // the shares typed: 10 % of the nitrogen in the initial stage, 12 kg/ha
    expect(
      kept,
      contains('initial | ${f2.stages.first.start.toIso8601String().substring(0, 10)} | ${f2.stages.first.end.toIso8601String().substring(0, 10)} | ${f2.stages.first.days} | 12.00 | 20.80 | 10.00 |'),
    );
    expect(kept, contains('Plan kept for the area (the report shows it).'));
    // the shares from the water use again, without saving
    final (auto, t3) = await turn(tester, [
      ('fertigation_by_stage', {'area': a.id, 'share_auto': true}),
    ]);
    allDone(t3);
    final byUse = fertigationSchedule(c.project, a, plan: pl.copy()..sharePct = null)!;
    expect(
      auto,
      contains(
        'initial | ${byUse.stages.first.start.toIso8601String().substring(0, 10)} | ${byUse.stages.first.end.toIso8601String().substring(0, 10)} | ${byUse.stages.first.days} | ${engN(byUse.stages.first.kgHa[0])} |',
      ),
    );
    expect(c.project.agronomy.fertigation[a.id]!.sharePct, isNotNull, reason: 'not saved');
    // salty water: the injection takes it past what tomato keeps its yield with
    a.ecwDsM = 1.65;
    final (salty, tsalt) = await turn(tester, [
      (
        'fertigation_by_stage',
        {
          'area': a.id,
          'dose_kg_ha': [100, 52, 60],
          'share_auto': true,
        },
      ),
    ]);
    allDone(tsalt);
    // each warning says which stage it is about
    for (final stage in ['initial', 'development', 'mid', 'late']) {
      expect(salty, contains('The solution makes the water too saline for the crop ($stage)'));
    }
    c.undo();
    expect(c.project.agronomy.fertigation, isEmpty);
    // the refusals
    final (bad, tb) = await turn(tester, [
      ('fertigation_by_stage', {'area': fixed.id}),
      (
        'fertigation_by_stage',
        {
          'area': a.id,
          'share_pct': [
            [25, 25, 25],
            [25, 25, 25],
            [50, 50, 50],
          ],
        },
      ),
      (
        'fertigation_by_stage',
        {
          'area': a.id,
          'share_pct': [
            [25, 25, 25],
            [25, 25, 25],
            [25, 25, 25],
            [25, 25, 125],
          ],
        },
      ),
      (
        'fertigation_by_stage',
        {
          'area': a.id,
          'products': [products[0], products[1]],
        },
      ),
      (
        'fertigation_by_stage',
        {
          'area': a.id,
          'products': [null, products[1], products[2]],
        },
      ),
      ('fertigation_by_stage', {'area': a.id, 'every_nth': 31}),
    ]);
    allFailed(tb);
    expect(bad, contains('Fixed has no water balance (a crop or ETo and Kc): no stages to fertigate.'));
    expect(bad, contains('"share_pct" needs 4 rows of 3 numbers.'));
    expect(bad, contains('"share_pct[3]" has 125.0, outside 0.0 … 100.0.'));
    expect(bad, contains('"products" needs 3 objects (the products of N, P2O5 and K2O).'));
    expect(bad, contains('Each product is an object {name, n, p2o5, k2o, ionic}.'));
    expect(bad, contains('"every_nth" = 31.0 is outside 1.0 … 30.0.'));
    expect(c.historyIndex, 0, reason: 'the refusals change nothing');
  });

  // Skipped, a defect of the operation: agr.dart:554 reads a row of share_pct
  // with `!`, and the schema lets a null row through, so the call fails with
  // "The tool failed: Null check operator used on a null value" instead of the
  // message of line 553.
  testWidgets('fertigation by stage: a row of the shares left out is refused as a bad argument, not a crash', (tester) async {
    final a = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 100), name: 'Tomatoes', useWaterBalance: true, cropKey: 'crop.tomato', etoMmDay: 5, climateKc: false));
    final (text, t) = await turn(tester, [
      (
        'fertigation_by_stage',
        {
          'area': a.id,
          'share_pct': [
            [25, 25, 25],
            null,
            [25, 25, 25],
            [25, 25, 25],
          ],
        },
      ),
    ]);
    expect(t.calls.single.state, ToolCallState.failed);
    expect(text, contains('"share_pct" needs 4 rows of 3 numbers.'));
    expect(text, isNot(contains('The tool failed')));
  });

  testWidgets('user crops: added with every field and assigned to an area, listed, used by the balance, changed, deleted after confirmation; each one undo step', (tester) async {
    final orchard = add(AreaEntity(id: c.project.newId(), points: rect(0, 0, 100, 50), name: 'Orchard', crop: 'Mixed', useWaterBalance: true, etoMmDay: 5, kc: 0.9, awcMmPerM: 120));
    final (root, mad) = (orchard.rootDepthM, orchard.mad);
    final (none, t0) = await turn(tester, [('list_user_crops', {})]);
    allDone(t0);
    expect(none, 'No user crop (set_user_crop adds one).');
    final (text, t) = await turn(tester, [
      (
        'set_user_crop',
        {
          'name': ' Passion fruit ',
          'kc': [0.5, 1.05, 0.9],
          'stage_days': [30, 60, 150, 60],
          'planting_month': 9,
          'root_depth_m': 0.5,
          'depletion_fraction': 0.4,
          'height_m': 4,
          'perennial': true,
          'ece': [1.5, 10],
          'ky': 1.1,
          'source': 'Local bulletin',
          'assign_areas': ['Orchard'],
        },
      ),
    ]);
    allDone(t);
    expect(c.historyIndex, 1);
    final u = c.project.agronomy.userCrops.single;
    expect(u.id, 'passion_fruit');
    expect(u.key, 'user.passion_fruit');
    expect(u.name, 'Passion fruit');
    expect([u.kcIni, u.kcMid, u.kcEnd], [0.5, 1.05, 0.9]);
    expect([u.initialDays, u.developmentDays, u.midDays, u.lateDays], [30, 60, 150, 60]);
    expect(u.plantingMonth, 9);
    expect(u.perennial, isTrue);
    expect([u.eceThreshold, u.eceMax], [1.5, 10]);
    expect(u.ky, 1.1);
    expect(u.source, 'Local bulletin');
    expect(text, 'User crop user.passion_fruit (Passion fruit): Kc 0.50/1.05/0.90, 300 days, root 0.50 m, p 0.40. Assigned to Orchard; results discarded.');
    // the area takes it as the panel does
    final live = c.project.byId(orchard.id) as AreaEntity;
    expect(live.cropKey, 'user.passion_fruit');
    expect(live.crop, 'Passion fruit');
    expect(live.rootDepthM, 0.5);
    expect(live.mad, 0.4);
    expect(live.kc, 1.05);
    final (list, t1) = await turn(tester, [('list_user_crops', {})]);
    allDone(t1);
    expect(
      list,
      'key | name | Kc ini/mid/end | days ini/dev/mid/late | month | root m | p | h m | perennial | ECe 100%/0% | Ky | source | areas\n'
      'user.passion_fruit | Passion fruit | 0.50/1.05/0.90 | 30/60/150/60 | 9 | 0.50 | 0.40 | 4.00 | true | 1.5/10.0 | 1.10 | Local bulletin | Orchard',
    );
    // its Ky gives the balance of the area a yield estimate
    final r = areaWaterBalance(c.project, live)!;
    expect(r.ky, 1.1);
    final (wb, _) = await turn(tester, [
      ('water_balance', {'area': orchard.id}),
    ]);
    expect(wb, contains('(Ky 1.10)'));
    expect(wb, contains('${r.events.length} irrigations'));
    // changed by id (its name kept), an evergreen and a second crop of the same name
    final (more, t2) = await turn(tester, [
      (
        'set_user_crop',
        {
          'id': 'passion_fruit',
          'kc': [0.6, 1.1, 0.95],
        },
      ),
      (
        'set_user_crop',
        {
          'name': 'Passion fruit',
          'stage_days': [0, 0, 0, 0],
        },
      ),
    ]);
    allDone(t2);
    expect(c.historyIndex, 3);
    expect(more, contains('User crop user.passion_fruit (Passion fruit): Kc 0.60/1.10/0.95, 300 days'));
    expect(more, contains('User crop user.passion_fruit_2 (Passion fruit): Kc 0.60/1.00/0.80, 0 days (evergreen: Kc mid all year), root 0.60 m, p 0.50.'));
    expect(c.project.agronomy.userCrops.map((x) => x.id), ['passion_fruit', 'passion_fruit_2']);
    expect(c.project.agronomy.userCrops.first.name, 'Passion fruit');
    expect(c.project.agronomy.userCrops.first.ky, 1.1, reason: 'what is not given is kept');
    // the refusals change nothing
    final supply = add(WaterSupplyEntity(id: c.project.newId(), position: const Pt(-10, -10)));
    final (bad, tb) = await turn(tester, [
      (
        'set_user_crop',
        {
          'id': 'cocoa',
          'kc': const [1, 1, 1],
        },
      ),
      ('set_user_crop', {'ky': 1}),
      ('set_user_crop', {'name': '  '}),
      (
        'set_user_crop',
        {
          'name': 'Cocoa',
          'ece': [5, 3],
        },
      ),
      (
        'set_user_crop',
        {
          'name': 'Cocoa',
          'assign_areas': [supply.id],
        },
      ),
      (
        'set_user_crop',
        {
          'name': 'Cocoa',
          'kc': [0.5, 2.5, 1],
        },
      ),
      ('delete_user_crop', {'id': 'cocoa'}),
    ]);
    allFailed(tb);
    expect(bad, contains('No user crop "cocoa". Crops: passion_fruit, passion_fruit_2.'));
    expect(bad, contains('A new crop needs "name".'));
    expect(bad, contains('"ece": the zero-yield ECe must be above the threshold.'));
    expect(bad, contains('"${supply.id}" is not an irrigated area.'));
    expect(bad, contains('"kc" has 2.5, outside 0.0 … 2.0.'));
    expect(bad, contains('No user crop "cocoa". Crops: passion_fruit, passion_fruit_2.'));
    expect(c.project.agronomy.userCrops, hasLength(2));
    expect(c.historyIndex, 3);
    // deleted after confirmation: the area keeps the name and the Kc typed on it
    approvals.clear();
    final (gone, td) = await turn(tester, [
      ('delete_user_crop', {'id': 'passion_fruit'}),
      ('delete_user_crop', {'id': 'passion_fruit_2'}),
    ]);
    allDone(td);
    expect(approvals.map((x) => x.name), ['delete_user_crop', 'delete_user_crop'], reason: 'deletions are confirmed whatever the mode');
    expect(gone, contains('User crop user.passion_fruit deleted; areas now with the typed Kc: Orchard.'));
    expect(gone, contains('User crop user.passion_fruit_2 deleted.'));
    final after = c.project.byId(orchard.id) as AreaEntity;
    expect(after.cropKey, '');
    expect(after.crop, 'Passion fruit');
    expect(after.kc, 1.05);
    expect(c.project.agronomy.userCrops, isEmpty);
    c.undo();
    c.undo();
    expect(c.project.agronomy.userCrops.map((x) => x.id), ['passion_fruit', 'passion_fruit_2']);
    expect((c.project.byId(orchard.id) as AreaEntity).cropKey, 'user.passion_fruit');
    c.undo();
    c.undo();
    expect(c.project.agronomy.userCrops.single.kcIni, 0.5);
    c.undo();
    expect(c.project.agronomy.userCrops, isEmpty);
    final back = c.project.byId(orchard.id) as AreaEntity;
    expect(back.cropKey, '');
    expect(back.crop, 'Mixed');
    expect(back.kc, 0.9);
    expect(back.rootDepthM, root);
    expect(back.mad, mad);
    expect(back.useWaterBalance, isTrue);
  });

  testWidgets('user crops: assigning one discards the design results, as the areas change', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await design(tester);
    final block = c.project.entities.whereType<AreaEntity>().first;
    final (text, t) = await turn(tester, [
      ('set_user_crop', {'name': 'Cocoa'}),
    ]);
    allDone(t);
    expect(text, isNot(contains('results discarded')));
    expect(c.results, isNotNull, reason: 'a crop no area uses changes no result');
    final (assigned, t2) = await turn(tester, [
      (
        'set_user_crop',
        {
          'id': 'cocoa',
          'assign_areas': [block.id],
        },
      ),
    ]);
    allDone(t2);
    expect(assigned, contains('Assigned to ${block.name}; results discarded.'));
    expect(c.results, isNull);
    c.undo();
    expect(c.results, isNotNull, reason: 'undo brings the results back');
  });

  testWidgets('station file: an attached BDMEP year becomes the site climate in one undo step, with its daily series for the water balance', (tester) async {
    final a = handArea();
    final bytes = Uint8List.fromList(utf8.encode(bdmep(2019)));
    host.files['bdmep_83377.csv'] = bytes;
    final st = mergeStationFiles(readStationFiles(bytes)).single;
    final sc = stationClimate(st)!;
    final (text, t) = await turn(tester, [
      ('import_station_climate', {'name': 'BDMEP_83377.CSV'}),
    ]);
    allDone(t);
    expect(t.calls.single.summary, 'Import the climate of the station file BDMEP_83377.CSV');
    expect(c.historyIndex, 1);
    final climate = c.project.climate!;
    expect(climate.source, 'inmet');
    expect(climate.attribution, 'INMET BRASILIA (83377)');
    expect(climate.firstYear, 2019);
    for (var m = 0; m < 12; m++) {
      expect(climate.etoMmDay[m], closeTo(sc.etoMmDay[m], 1e-12));
      expect(climate.rainMm[m], closeTo(sc.rainMm[m], 1e-12));
    }
    expect(climate.rainMm.first, closeTo(31, 1e-9), reason: '1 mm every day of January');
    expect(climate.daily!.completeYears, [2019]);
    expect(text, contains('Site climate from INMET BRASILIA (83377), 2019-01-01 … 2019-12-31, 365 days (365 with ETo), 1 file(s).'));
    expect(text, contains('month | ETo mm/d | rain mm | dependable mm | RHmin % | u2 m/s'));
    expect(text, contains(row(['Jan', sc.etoMmDay[0], sc.rainMm[0], sc.dependableRainMm?[0] ?? '-', sc.rhMinPct?[0] ?? '-', sc.windSpeed2mMs?[0] ?? '-'])));
    expect(text, contains(row(['Dec', sc.etoMmDay[11], sc.rainMm[11], sc.dependableRainMm?[11] ?? '-', sc.rhMinPct?[11] ?? '-', sc.windSpeed2mMs?[11] ?? '-'])));
    expect(text, contains('The daily series (1 complete years) is kept for the water balance (water_balance year).'));
    // the year of the series drives the balance of the area
    final y = areaWaterBalance(c.project, a, settings: BalanceSettings(year: 2019))!;
    final (wb, tw) = await turn(tester, [
      ('water_balance', {'area': a.id, 'year': 2019}),
    ]);
    allDone(tw);
    expect(wb, contains('Plot: 2019-01-01 … 2019-12-31 (365 days), year 2019 of the daily series, depletion.'));
    expect(wb, contains('rain ${engN(y.rainMm, 0)} mm (effective ${engN(y.effectiveRainMm, 0)})'));
    expect(y.rainMm, closeTo(365, 1e-9));
    // an anemometer at 2 m: the wind is not brought down, the ETo rises
    final low = stationClimate(mergeStationFiles(readStationFiles(bytes, windHeightM: 2)).single)!;
    final (_, t2) = await turn(tester, [
      ('import_station_climate', {'name': 'bdmep_83377.csv', 'wind_height_m': 2, 'elevation_m': 500}),
    ]);
    allDone(t2);
    expect(c.project.climate!.windSpeed2mMs!.first, closeTo(low.windSpeed2mMs!.first, 1e-12));
    expect(c.project.climate!.etoMmDay.first, greaterThan(sc.etoMmDay.first));
    c.undo();
    expect(c.project.climate!.etoMmDay.first, closeTo(sc.etoMmDay.first, 1e-12));
    c.undo();
    expect(c.project.climate, isNull, reason: 'one undo step');
  });

  testWidgets('station file: a zip of two stations and the one chosen, the latitude typed, and what it answers without a readable file', (tester) async {
    final (nothing, t0) = await turn(tester, [
      ('import_station_climate', {'name': 'a.csv'}),
    ]);
    allFailed(t0);
    expect(nothing, contains('No file was attached in this conversation.'));
    final archive = Archive();
    for (final (name, text) in [('INMET_83377_2019.csv', bdmep(2019)), ('INMET_83377_2020.csv', bdmep(2020, rain: 2)), ('INMET_83378_2020.csv', bdmep(2020, code: '83378', name: 'GOIANIA'))]) {
      final b = latin1.encode(text.replaceAll('°', 'o'));
      archive.addFile(ArchiveFile(name, b.length, b));
    }
    host.files['stations.zip'] = Uint8List.fromList(ZipEncoder().encode(archive));
    host.files['notes.txt'] = Uint8List.fromList(utf8.encode('hello'));
    host.files['nolat.csv'] = Uint8List.fromList(utf8.encode(bdmep(2021, code: 'X1', name: 'FARM', latitude: false)));
    final (text, t) = await turn(tester, [
      ('import_station_climate', {'name': 'stations.zip'}),
    ]);
    allDone(t);
    // the station with most days, the other named
    expect(text, contains('Site climate from INMET BRASILIA (83377), 2019-01-01 … 2020-12-31, 731 days (731 with ETo), 2 file(s); other stations in the file: 83378.'));
    expect(c.project.climate!.daily!.completeYears, [2019, 2020]);
    final (goiania, t2) = await turn(tester, [
      ('import_station_climate', {'name': 'stations.zip', 'station': 'goiania'}),
      ('import_station_climate', {'name': 'stations.zip', 'station': '99999'}),
    ]);
    expect(t2.calls.first.state, ToolCallState.done);
    expect(goiania, contains('Site climate from INMET GOIANIA (83378), 2020-01-01 … 2020-12-31, 366 days'));
    expect(c.project.climate!.attribution, 'INMET GOIANIA (83378)');
    expect(t2.calls.last.state, ToolCallState.failed);
    expect(goiania, contains('No station "99999" in the file: 83377 BRASILIA, 83378 GOIANIA.'));
    expect(c.historyIndex, 2);
    // no latitude in the file nor a site: typed, it works
    final (nolat, t3) = await turn(tester, [
      ('import_station_climate', {'name': 'nolat.csv'}),
      ('import_station_climate', {'name': 'nolat.csv', 'latitude_deg': -15.78}),
      ('import_station_climate', {'name': 'notes.txt'}),
      ('import_station_climate', {'name': 'missing.csv'}),
      ('import_station_climate', {'name': 'nolat.csv', 'wind_height_m': 100}),
    ]);
    expect([for (final x in t3.calls) x.state], [ToolCallState.failed, ToolCallState.done, ToolCallState.failed, ToolCallState.failed, ToolCallState.failed]);
    expect(nolat, contains('FARM: no complete month with temperatures (or no latitude: give latitude_deg).'));
    expect(nolat, contains('Site climate from INMET FARM (X1), 2021-01-01 … 2021-12-31, 365 days (365 with ETo)'));
    expect(c.project.climate!.latitudeDeg, -15.78);
    expect(nolat, contains('"notes.txt" is not a station file this program reads (station_no_columns).'));
    expect(nolat, contains('No attached file "missing.csv". Attached: stations.zip, notes.txt, nolat.csv.'));
    expect(nolat, contains('"wind_height_m" = 100.0 is outside 0.5 … 50.0.'));
    expect(c.historyIndex, 3);
    c.undo();
    expect(c.project.climate!.attribution, 'INMET GOIANIA (83378)');
  });

  testWidgets('through find_operations and run_operation, as the model reaches them', (tester) async {
    handArea();
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        ('find_operations', {'query': 'daily water balance'}),
        (
          'run_operation',
          {
            'name': 'water_balance',
            'input': {'area': 'Plot', 'events_limit': 1},
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
    expect(text, contains('water_balance'));
    expect(text, contains('36 irrigations, 0 days of stress.'));
    expect(text, contains('(35 more rows)'));
  });
}
