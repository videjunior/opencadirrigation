import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Every correction of the design assistant ([applyFix]) on the case it is
/// meant for and on the case where it has nothing to do, plus the parts of
/// the optimisation the advisor tests do not reach.
void main() {
  final t = I18n('pt');
  Project example([ExampleId id = ExampleId.orchard]) => buildExample(id, t.call, lang: 'pt');
  DesignResults design(Project p) => Designer(p, label: t.call).designAll();
  Advice advice(String code, {List<String> ids = const [], String? contextId, Pt? at, String value = ''}) =>
      Advice(code: code, raw: code, level: AdviceLevel.error, entityIds: ids, contextId: contextId, at: at, value: value);
  FixResult fix(Project p, Advice a, FixKind k, [DesignResults? r]) => applyFix(p, a, k, results: r, label: (k) => k, lang: 'pt');
  Advice found(List<Advice> list, String code) => list.firstWhere((a) => a.code == code, orElse: () => throw TestFailure('no $code in ${list.map((a) => a.code).toList()}'));

  test('clean segments drops vertices closer than the tolerance and keeps the true end', () {
    final p = Project();
    final pipe = PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(10, 0), const Pt(10.0001, 0), const Pt(20, 0), const Pt(20.0002, 0)], scope: HydraulicScope.mainline);
    p.entities.add(pipe);
    final a = found(buildAdvice(p), 'tiny_segment');
    expect(a.fixes, [FixKind.cleanSegments]);
    final res = fix(p, a, FixKind.cleanSegments);
    expect(res.ok, isTrue);
    expect(res.args['n'], '2');
    expect(pipe.points, [const Pt(0, 0), const Pt(10, 0), const Pt(20.0002, 0)]);
    expect(fix(p, a, FixKind.cleanSegments).key, 'fixfail.noChange');
    // a pipe made only of coincident points disappears
    final dot = PipeEntity(id: p.newId(), points: [const Pt(5, 5), const Pt(5, 5.0001)], scope: HydraulicScope.mainline);
    p.entities.add(dot);
    expect(fix(p, advice('tiny_segment', ids: [dot.id]), FixKind.cleanSegments).ok, isTrue);
    expect(p.byId(dot.id), isNull);
  });

  test('duplicated items keep one; duplicated zone names get numbers', () {
    final p = Project();
    final a = ControlValveEntity(id: p.newId(), position: const Pt(0, 0), zoneName: 'Zona A', name: 'Zona A');
    final b = ControlValveEntity(id: p.newId(), position: const Pt(0, 0), zoneName: 'Zona A', name: 'Zona A');
    p.entities.addAll([a, b]);
    final list = buildAdvice(p);
    final dup = found(list, 'duplicate_item');
    expect(dup.fixes, [FixKind.removeDuplicates]);
    expect(fix(p, dup, FixKind.removeDuplicates).args['n'], '1');
    expect(p.entities.whereType<ControlValveEntity>().map((v) => v.id), [a.id]);
    expect(fix(p, advice('duplicate_item', ids: [a.id]), FixKind.removeDuplicates).key, 'fixfail.notFound');
    // three valves called "Zona A" while "Zona A 2" is taken
    final c = ControlValveEntity(id: p.newId(), position: const Pt(50, 0), zoneName: 'Zona A', name: 'Zona A');
    final d = ControlValveEntity(id: p.newId(), position: const Pt(90, 0), zoneName: 'Zona A', name: 'Válvula D');
    final taken = ControlValveEntity(id: p.newId(), position: const Pt(120, 0), zoneName: 'Zona A 2');
    p.entities.addAll([c, d, taken]);
    final names = found(buildAdvice(p), 'duplicate_zone_name');
    expect(names.fixes, [FixKind.renameZone]);
    final res = fix(p, names, FixKind.renameZone);
    expect(res.ok, isTrue);
    expect(res.args['n'], '2');
    expect(a.zoneName, 'Zona A');
    expect(c.zoneName, 'Zona A 3');
    expect(c.name, 'Zona A 3', reason: 'a name that was the zone name follows it');
    expect(d.zoneName, 'Zona A 4');
    expect(d.name, 'Válvula D', reason: 'a name of its own is kept');
    expect(buildAdvice(p).where((x) => x.code == 'duplicate_zone_name'), isEmpty);
    expect(fix(p, advice('duplicate_zone_name', ids: [a.id]), FixKind.renameZone).key, 'fixfail.notFound');
  });

  test('calculated supply, automatic pipe sizes and pump speed', () {
    final p = example();
    final s = p.entities.whereType<WaterSupplyEntity>().first;
    s.calculatePressure = false;
    final res = fix(p, advice('supply_no_head', ids: [s.id]), FixKind.calculateSupply);
    expect(res.ok, isTrue);
    expect(s.calculatePressure, isTrue);
    expect(res.args['n'], s.name);
    expect(fix(p, advice('supply_no_head', ids: [s.id]), FixKind.calculateSupply).key, 'fixfail.noChange');
    // unlock every fixed pipe and lateral of a zone
    final valve = p.entities.whereType<ControlValveEntity>().first;
    for (final e in p.entities) {
      if (e is PipeEntity) e.computerSized = false;
      if (e is SpraylineEntity) e.computerSized = false;
    }
    final sized = fix(p, advice('cannot_meet_pressure_window', contextId: valve.id), FixKind.autoSizePipes);
    expect(sized.ok, isTrue);
    expect(int.parse(sized.args['n']!), greaterThan(3));
    expect(p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.mainline).every((e) => !e.computerSized), isTrue, reason: 'only the zone of the valve');
    expect(fix(p, advice('cannot_meet_pressure_window', contextId: valve.id), FixKind.autoSizePipes).key, 'fixfail.noChange');
    final main = p.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.mainline);
    expect(fix(p, advice('velocity_exceeded', ids: [main.id]), FixKind.autoSizePipes).ok, isTrue);
    expect(main.computerSized, isTrue);
    final pump = p.entities.whereType<PumpEntity>().first..speedRatio = 0.7;
    expect(fix(p, advice('pump_out_of_range', ids: [pump.id]), FixKind.resetPumpSpeed).args['n'], '1');
    expect(pump.speedRatio, 1);
    expect(fix(p, advice('pump_out_of_range', ids: [valve.id]), FixKind.resetPumpSpeed).key, 'fixfail.noChange');
  });

  test('a control valve too small for its zone is replaced by the smallest that carries the flow', () {
    final p = example();
    final valve = p.entities.whereType<ControlValveEntity>().first..valveSpecId = 'ev25';
    final r = design(p);
    final q = r.zones[valve.id]!.totalFlow;
    expect(q, greaterThan(p.catalog.valve('ev25')!.maxFlow), reason: 'the test needs an undersized valve');
    final a = buildAdvice(p, results: r).firstWhere((x) => x.fixes.contains(FixKind.resizeValve));
    expect(fix(p, a, FixKind.resizeValve).key, 'fixfail.needsResults');
    final res = fix(p, a, FixKind.resizeValve, r);
    expect(res.ok, isTrue);
    final spec = p.catalog.valve(valve.valveSpecId)!;
    expect(spec.id, isNot('ev25'));
    expect(q, inInclusiveRange(spec.minFlow, spec.maxFlow));
    expect(res.args['n'], spec.name);
    for (final other in p.catalog.valves.where((s) => s.enabled && s.kind == spec.kind && s.sizeMm < spec.sizeMm)) {
      expect(q > other.maxFlow || q < other.minFlow, isTrue, reason: '${other.id} would have been smaller');
    }
    // already the right one: nothing to offer
    expect(fix(p, a, FixKind.resizeValve, r).key, 'fixfail.noOption');
    expect(fix(p, advice('valve_flow_out_of_range'), FixKind.resizeValve, r).key, 'fixfail.notFound');
  });

  test('assign a catalogue model to every kind of item', () {
    final p = Project();
    final cat = p.catalog;
    final pipe = PipeEntity(id: p.newId(), points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.zone, pipeSpecId: 'gone');
    final pivot = PivotEntity(id: p.newId(), center: const Pt(100, 0), radiusM: 50)..pipeSpecId = 'gone';
    final valve = ControlValveEntity(id: p.newId(), position: const Pt(20, 0), zoneName: 'Z', valveSpecId: 'gone');
    final pump = PumpEntity(id: p.newId(), position: const Pt(30, 0), pumpSpecId: 'gone');
    final misc = MiscHydraulicEntity(id: p.newId(), position: const Pt(40, 0), valveSpecId: 'gone');
    final outlet = OutletEntity(id: p.newId(), position: const Pt(50, 0), outletSpecId: 'gone', nozzleId: 'gone', headM: 1);
    final lateral = SpraylineEntity(id: p.newId(), points: [const Pt(0, 5), const Pt(10, 5)], outletSpecId: 'micro', nozzleId: 'gone', headM: 1);
    final tape = TapeEntity(id: p.newId(), points: [const Pt(0, 9), const Pt(10, 9)], tapeSpecId: 'gone', inletHeadM: 1);
    p.entities.addAll([pipe, pivot, valve, pump, misc, outlet, lateral, tape]);
    FixResult assign(Entity e) => fix(p, advice('spec_missing', ids: [e.id]), FixKind.assignModel);
    expect(assign(pipe).args['n'], 'auto');
    expect(pipe.pipeSpecId, isNull);
    expect(pipe.computerSized, isTrue);
    expect(assign(pivot).ok, isTrue);
    expect(pivot.pipeSpecId, isNull);
    expect(assign(valve).ok, isTrue);
    final controls = cat.valves.where((s) => s.enabled && s.kind == ValveKind.control).toList()..sort((a, b) => a.sizeMm.compareTo(b.sizeMm));
    expect(valve.valveSpecId, controls.first.id, reason: 'without results the smallest control valve');
    expect(assign(pump).args['n'], cat.pump(pump.pumpSpecId)!.name);
    expect(assign(misc).ok, isTrue);
    expect(cat.valve(misc.valveSpecId)!.kind, isNot(ValveKind.control));
    expect(assign(outlet).ok, isTrue);
    final o = cat.outlet(outlet.outletSpecId)!;
    expect(o.nozzle(outlet.nozzleId), isNotNull);
    expect(outlet.headM, o.nozzle(outlet.nozzleId)!.defaultHeadM);
    expect(assign(lateral).ok, isTrue);
    expect(lateral.outletSpecId, 'micro', reason: 'the outlet it had is kept');
    expect(cat.outlet('micro')!.nozzle(lateral.nozzleId), isNotNull);
    expect(assign(tape).ok, isTrue);
    expect(cat.tape(tape.tapeSpecId), isNotNull);
    expect(tape.inletHeadM, cat.tape(tape.tapeSpecId)!.defaultInletHeadM);
    // with an empty catalogue nothing can be assigned
    final bare = Project(catalog: Catalog());
    final v2 = ControlValveEntity(id: bare.newId(), position: Pt.zero, zoneName: 'Z');
    final t2 = TapeEntity(id: bare.newId(), points: [Pt.zero, const Pt(1, 0)], tapeSpecId: 'x');
    bare.entities.addAll([v2, t2]);
    expect(fix(bare, advice('spec_missing', ids: [v2.id]), FixKind.assignModel).key, 'fixfail.noOption');
    expect(fix(bare, advice('spec_missing', ids: [t2.id]), FixKind.assignModel).key, 'fixfail.noOption');
    expect(fix(bare, advice('spec_missing'), FixKind.assignModel).key, 'fixfail.notFound');
    final text = TextEntity(id: bare.newId(), position: Pt.zero, text: 'x');
    bare.entities.add(text);
    expect(fix(bare, advice('spec_missing', ids: [text.id]), FixKind.assignModel).key, 'fixfail.noOption');
  });

  test('missing fittings come back from the generic list; crossing pipes are joined', () {
    final p = Project();
    final n = p.catalog.fittings.length;
    p.catalog.fittings.clear();
    final res = fix(p, advice('fitting_missing'), FixKind.addFittings);
    expect(res.ok, isTrue);
    expect(p.catalog.fittings.length, n);
    expect(res.args['n'], '$n');
    expect(fix(p, advice('fitting_missing'), FixKind.addFittings).key, 'fixfail.noChange');
    // two mainline pipes crossing without a junction
    final a = PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(100, 0)], scope: HydraulicScope.mainline);
    final b = PipeEntity(id: p.newId(), points: [const Pt(50, -20), const Pt(50, 20)], scope: HydraulicScope.mainline);
    p.entities.addAll([a, b]);
    final cross = found(buildAdvice(p), 'pipes_cross');
    expect(cross.fixes, [FixKind.joinCrossing]);
    expect(fix(p, advice('pipes_cross', ids: [a.id, b.id]), FixKind.joinCrossing).key, 'fixfail.notFound', reason: 'needs the crossing point');
    expect(fix(p, cross, FixKind.joinCrossing).ok, isTrue);
    final pipes = p.entities.whereType<PipeEntity>().toList();
    expect(pipes.length, 4);
    expect(pipes.where((e) => e.points.any((q) => q.distanceTo(const Pt(50, 0)) < 1e-9)).length, 4, reason: 'every piece meets at the crossing');
    expect(buildAdvice(p).where((x) => x.code == 'pipes_cross'), isEmpty);
  });

  test('settings out of range are restored one group at a time', () {
    final p = Project();
    final d = DesignParameters();
    p.params
      ..connectTolerance = 50
      ..maxZoneVariationPct = 500
      ..waterTempC = 300;
    expect(fix(p, advice('set_tolerance'), FixKind.resetSettings).key, 'fixed.resetSettings');
    expect(p.params.connectTolerance, d.connectTolerance);
    expect(p.params.maxZoneVariationPct, 500, reason: 'only the group of the message');
    expect(fix(p, advice('set_variation'), FixKind.resetSettings).ok, isTrue);
    expect(p.params.maxZoneVariationPct, d.maxZoneVariationPct);
    expect(fix(p, advice('set_temperature'), FixKind.resetSettings).ok, isTrue);
    expect(p.params.waterTempC, d.waterTempC);
    expect(fix(p, advice('something_else'), FixKind.resetSettings).key, 'fixfail.noChange');
  });

  test('disabled pipe sizes are enabled again, or the generic ones added', () {
    final p = Project();
    final laterals = p.catalog.pipes.where((s) => s.usage.contains(PipeUsage.lateral)).toList();
    for (final s in laterals) {
      s.enabled = false;
    }
    final res = fix(p, advice('no_pipes_for_usage', value: 'lateral'), FixKind.enablePipes);
    expect(res.args['n'], '${laterals.length}');
    expect(laterals.every((s) => s.enabled), isTrue);
    p.catalog.pipes.removeWhere((s) => s.usage.contains(PipeUsage.lateral));
    expect(p.catalog.pipesFor(PipeUsage.lateral), isEmpty);
    expect(fix(p, advice('no_pipes_for_usage', value: 'lateral'), FixKind.enablePipes).ok, isTrue);
    expect(p.catalog.pipesFor(PipeUsage.lateral), isNotEmpty);
    expect(fix(p, advice('no_pipes_for_usage', value: 'lateral'), FixKind.enablePipes).key, 'fixfail.noOption', reason: 'everything is there already');
    expect(fix(p, advice('no_pipes_for_usage', value: 'nonsense'), FixKind.enablePipes).key, 'fixfail.notFound');
  });

  test('supply limits below the design values are raised to them', () {
    final p = example();
    final s = p.entities.whereType<WaterSupplyEntity>().first
      ..calculatePressure = false
      ..designHeadM = 40
      ..maxHeadM = 30
      ..designFlow = 0.02
      ..maxFlow = 0.01;
    final a = found(buildAdvice(p), 'supply_limits');
    expect(a.level, AdviceLevel.warning);
    expect(fix(p, a, FixKind.fixSupplyLimits).ok, isTrue);
    expect(s.maxHeadM, 40);
    expect(s.maxFlow, 0.02);
    expect(buildAdvice(p).where((x) => x.code == 'supply_limits'), isEmpty);
    expect(fix(p, a, FixKind.fixSupplyLimits).key, 'fixfail.noChange');
  });

  test('flows: a new flow id that is free, durations and nothing to add', () {
    final p = example();
    final valve = p.entities.whereType<ControlValveEntity>().first;
    p.systemFlows
      ..clear()
      ..add(SystemFlow(id: 'sfm1', name: 'Manual', durationHours: 0));
    final res = fix(p, advice('valve_not_in_flow', ids: [valve.id]), FixKind.addMissingFlow);
    expect(res.ok, isTrue);
    expect(p.systemFlows.last.id, 'sfm2');
    expect(p.systemFlows.last.valveIds, {valve.id});
    expect(fix(p, advice('valve_not_in_flow', ids: [valve.id]), FixKind.addMissingFlow).key, 'fixfail.noChange');
    final dur = fix(p, advice('flow_duration'), FixKind.fixFlowDurations);
    expect(dur.args['n'], '1');
    expect(p.systemFlows.first.durationHours, 1);
    expect(fix(p, advice('flow_duration'), FixKind.fixFlowDurations).key, 'fixfail.noChange');
    expect(fix(p, advice('flow_empty'), FixKind.removeEmptyFlows).ok, isTrue, reason: 'the manual flow has no zone');
    expect(p.systemFlows.map((f) => f.id), ['sfm2']);
    expect(fix(p, advice('flow_empty'), FixKind.removeEmptyFlows).key, 'fixfail.noChange');
  });

  test('nominal emitter pressure for single outlets and tapes', () {
    final p = Project();
    final nz = p.catalog.outlet('micro')!.nozzles.first;
    final tp = p.catalog.tapes.first;
    final o = OutletEntity(id: p.newId(), position: Pt.zero, outletSpecId: 'micro', nozzleId: nz.id, headM: 99);
    final t2 = TapeEntity(id: p.newId(), points: [Pt.zero, const Pt(10, 0)], tapeSpecId: tp.id, inletHeadM: 99);
    final unknown = OutletEntity(id: p.newId(), position: const Pt(5, 5), outletSpecId: 'gone', headM: 99);
    p.entities.addAll([o, t2, unknown]);
    final res = fix(p, advice('emitter_head_range', ids: [o.id, t2.id, unknown.id]), FixKind.nominalEmitterHead);
    expect(res.args['n'], '2');
    expect(o.headM, nz.defaultHeadM);
    expect(t2.inletHeadM, tp.defaultInletHeadM);
    expect(unknown.headM, 99);
    expect(fix(p, advice('emitter_head_range', ids: [unknown.id]), FixKind.nominalEmitterHead).key, 'fixfail.noChange');
  });

  test('connect reports how far it looked when nothing is in reach', () {
    final p = example();
    final pump = p.entities.whereType<PumpEntity>().first;
    pump.position = pump.position + const Pt(0, 40);
    final res = fix(p, advice('unconnected', ids: [pump.id]), FixKind.connect);
    expect(res.ok, isFalse);
    expect(res.key, 'fixfail.nothingNear');
    expect(res.args['d'], connectReach(p).toStringAsFixed(2));
    expect(fix(p, advice('unconnected'), FixKind.connect).key, 'fixfail.notFound');
  });

  test('a pivot left off the mainline pulls the nearest pipe end to its centre', () {
    final p = Project();
    final pipe = PipeEntity(id: p.newId(), points: [const Pt(-300, 0), const Pt(-1.2, 0)], scope: HydraulicScope.mainline);
    final pivot = PivotEntity(id: p.newId(), center: Pt.zero, radiusM: 200, endThrowM: 0);
    p.entities.addAll([pipe, pivot, WaterSupplyEntity(id: p.newId(), position: const Pt(-300, 0))]);
    final plan = connectTarget(p, pivot)!;
    expect(identical(plan.moved, pipe), isTrue);
    expect(plan.to, Pt.zero);
    expect(fix(p, advice('unconnected', ids: [pivot.id]), FixKind.connect).ok, isTrue);
    expect(pipe.points.last, Pt.zero);
  });

  test('optimisation designs first when no baseline is given and switches to LP sizing', () async {
    final p = example();
    p.params.sizingMethod = SizingMethod.greedy;
    for (final e in p.entities.whereType<PipeEntity>()) {
      e.computerSized = false;
    }
    var designs = 0;
    Future<DesignResults?> run() async {
      designs++;
      return design(p);
    }

    final report = await runOptimize(p, run, options: const OptimizeOptions(resizeFixedPipes: true, choosePumps: false, resizeValves: false));
    expect(designs, 2, reason: 'the baseline and the optimised design');
    expect(report.applied.map((f) => f.key), containsAll(['fixed.autoSizePipes', 'fixed.lpSizing']));
    expect(p.params.sizingMethod, SizingMethod.lp);
    expect(p.entities.whereType<PipeEntity>().every((e) => e.computerSized), isTrue);
    expect(report.after.errors, 0);
    final fixReport = await runAutoFix(p, run, label: t.call, lang: 'pt');
    expect(fixReport.warnings, fixReport.remaining.where((a) => a.level == AdviceLevel.warning).length);
  });
}
