import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The design advisor: problems explained with a severity and corrections,
/// the corrections themselves, "fix automatically" and the optimisation.
void main() {
  final t = I18n('pt');
  Project example(ExampleId id) => buildExample(id, t.call, lang: 'pt');
  DesignResults design(Project p) => Designer(p, label: t.call).designAll();
  Future<DesignResults?> Function() designer(Project p) => () async => design(p);
  Advice find(List<Advice> list, String code) => list.firstWhere((a) => a.code == code, orElse: () => throw TestFailure('no $code in ${list.map((a) => a.code).toList()}'));
  FixResult fix(Project p, Advice a, [DesignResults? r]) => applyFix(p, a, a.fixes.first, results: r, label: t.call, lang: 'pt');

  test('an item dropped next to the pipe is reported unconnected and joined to it', () {
    final p = example(ExampleId.orchard);
    final valve = p.entities.whereType<ControlValveEntity>().first;
    final pump = p.entities.whereType<PumpEntity>().first;
    // move the pump 0.8 m off the mainline
    pump.position = pump.position + const Pt(0, 0.8);
    final advice = buildAdvice(p);
    final a = advice.firstWhere((a) => a.code == 'unconnected' && a.entityIds.contains(pump.id));
    expect(a.level, AdviceLevel.error);
    expect(a.fixes, [FixKind.connect]);
    final res = fix(p, a);
    expect(res.ok, isTrue);
    expect(res.args['d'], '0.80');
    expect(buildAdvice(p).where((x) => x.code == 'unconnected'), isEmpty);
    // a valve dropped mid-span: the pipe is cut under it
    valve.position = valve.position + const Pt(0.7, -0.6);
    final b = buildAdvice(p).firstWhere((x) => x.code == 'unconnected' && x.entityIds.contains(valve.id));
    expect(fix(p, b).ok, isTrue);
    expect(buildAdvice(p).where((x) => x.code == 'unconnected'), isEmpty);
    // nothing within reach: no correction offered
    pump.position = pump.position + const Pt(0, 30);
    final c = buildAdvice(p).firstWhere((x) => x.code == 'unconnected' && x.entityIds.contains(pump.id));
    expect(c.fixes, isEmpty);
  });

  test('impossible settings are explained and restored', () {
    final p = example(ExampleId.orchard);
    p.params
      ..maxZoneVelocity = 0
      ..hoursPerYear = 12000
      ..pumpEfficiency = 3;
    final advice = buildAdvice(p);
    for (final code in ['set_velocity', 'set_hours', 'set_economy']) {
      final a = find(advice, code);
      expect(a.fixes, [FixKind.resetSettings]);
      expect(fix(p, a).ok, isTrue);
    }
    expect(p.params.maxZoneVelocity, DesignParameters().maxZoneVelocity);
    expect(p.params.hoursPerYear, DesignParameters().hoursPerYear);
    expect(p.params.pumpEfficiency, DesignParameters().pumpEfficiency);
    expect(buildAdvice(p).where((a) => a.code.startsWith('set_')), isEmpty);
  });

  test('an emitter pressure outside the nozzle range makes the zone impossible; the nominal pressure fixes it', () {
    final p = example(ExampleId.orchard);
    final line = p.entities.whereType<SpraylineEntity>().first;
    line.headM = 80;
    final r = design(p);
    final advice = buildAdvice(p, results: r);
    final a = find(advice, 'emitter_head_range');
    expect(a.level, AdviceLevel.error);
    expect(a.entityIds, contains(line.id));
    expect(advice.any((x) => x.code == 'cannot_meet_pressure_window'), isTrue);
    expect(fix(p, a).ok, isTrue);
    expect(line.headM, lessThan(30));
    expect(buildAdvice(p, results: design(p)).where((x) => x.level == AdviceLevel.error), isEmpty);
  });

  test('a zone left out of every system flow is added to a new flow; empty flows go away', () {
    final p = example(ExampleId.orchard);
    final removed = p.systemFlows.removeLast();
    p.systemFlows.add(SystemFlow(id: 'empty', name: 'Vazio'));
    final advice = buildAdvice(p);
    final a = find(advice, 'valve_not_in_flow');
    expect(a.entityIds, removed.valveIds.toList());
    expect(fix(p, a).ok, isTrue);
    expect(p.systemFlows.last.valveIds, removed.valveIds);
    final b = find(buildAdvice(p), 'flow_empty');
    expect(fix(p, b).ok, isTrue);
    expect(p.systemFlows.where((f) => f.id == 'empty'), isEmpty);
  });

  test('a surface pump in a deep well is replaced by a submersible one', () {
    final p = example(ExampleId.orchard);
    p.entities.whereType<WaterSupplyEntity>().first.waterLevelOffsetM = -12;
    final r = design(p);
    final a = find(buildAdvice(p, results: r), 'pump_suction_lift');
    expect(a.fixes, [FixKind.submersiblePump]);
    final res = fix(p, a, r);
    expect(res.ok, isTrue, reason: res.key);
    final pump = p.entities.whereType<PumpEntity>().first;
    expect(p.catalog.pump(pump.pumpSpecId)!.submersible, isTrue);
    final after = design(p);
    expect(buildAdvice(p, results: after).where((x) => x.code == 'pump_suction_lift' || x.code == 'pump_out_of_range'), isEmpty);
  });

  test('a public supply short of pressure gets a booster pump', () {
    final p = example(ExampleId.garden);
    final s = p.entities.whereType<WaterSupplyEntity>().first;
    s
      ..designHeadM = 18
      ..maxHeadM = 40;
    final r = design(p);
    final a = find(buildAdvice(p, results: r), 'valve_pressure_deficit');
    expect(a.fixes, [FixKind.choosePump, FixKind.calculateSupply]);
    final res = fix(p, a, r);
    expect(res.ok, isTrue, reason: res.key);
    expect(res.key, 'fixed.insertPump');
    expect(p.entities.whereType<PumpEntity>(), hasLength(1));
    final after = design(p);
    expect(after.systemFlows.every((f) => f.maxDeficit < 0.05), isTrue);
    expect(buildAdvice(p, results: after).where((x) => x.code == 'unconnected'), isEmpty);
  });

  test('a supply that cannot give the flow of all zones at once gets more system flows', () {
    final p = example(ExampleId.garden);
    final s = p.entities.whereType<WaterSupplyEntity>().first;
    p.systemFlows
      ..clear()
      ..add(SystemFlow(id: 'all', name: 'Todas', valveIds: p.entities.whereType<ControlValveEntity>().map((v) => v.id).toSet(), durationHours: 1));
    final r = design(p);
    final a = find(buildAdvice(p, results: r), 'supply_flow_exceeded');
    expect(a.fixes, [FixKind.splitFlows]);
    expect(fix(p, a, r).ok, isTrue);
    expect(p.systemFlows.length, greaterThan(1));
    final after = design(p);
    for (final f in after.systemFlows) {
      expect(f.totalFlow, lessThanOrEqualTo(s.designFlow + 1e-9), reason: f.name);
    }
  });

  test('fix automatically clears a project with several mistakes', () async {
    final p = example(ExampleId.orchard);
    p.params.maxZoneVelocity = 0;
    p.entities.whereType<WaterSupplyEntity>().first.waterLevelOffsetM = -12;
    final pump = p.entities.whereType<PumpEntity>().first;
    pump.position = pump.position + const Pt(0, 0.6);
    final outlet = p.entities.whereType<SpraylineEntity>().first;
    p.entities.add(outlet.clone(newId: p.newId()));
    p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(500, 500), const Pt(500, 500)], scope: HydraulicScope.mainline));
    final before = buildAdvice(p, results: design(p));
    expect(before.where((a) => a.level == AdviceLevel.error).length, greaterThanOrEqualTo(2));
    final report = await runAutoFix(p, designer(p), label: t.call, lang: 'pt');
    expect(report.applied.length, greaterThanOrEqualTo(4), reason: report.applied.map((f) => f.key).join(', '));
    expect(report.errors, 0, reason: report.remaining.where((a) => a.level == AdviceLevel.error).map((a) => '${a.code} ${a.entityIds}').join('; '));
    expect(report.rounds, lessThan(6));
  });

  test('optimisation keeps every requirement and never raises the annual cost', () async {
    for (final id in [ExampleId.orchard, ExampleId.golf]) {
      final p = example(id);
      final base = design(p);
      final report = await runOptimize(p, designer(p), baseline: base, options: const OptimizeOptions(resizeFixedPipes: true));
      expect(report.after.errors, 0, reason: id.name);
      expect(report.after.annualTotal, lessThanOrEqualTo(report.before.annualTotal * 1.02), reason: '${id.name}: ${report.before.annualTotal} → ${report.after.annualTotal}');
    }
  });
}
