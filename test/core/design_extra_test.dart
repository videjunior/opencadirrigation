import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/fittings.dart';
import 'package:opencadirrigation/core/design/lp_sizing.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/pivot.dart';
import 'package:opencadirrigation/core/design/pump_selection.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Design-layer paths the other design tests do not reach: empty and
/// missing zones, the zone variation limit, devices inside a zone,
/// unreachable valves, missing fittings, the design check and network
/// builder messages, block layouts, schedules at fixed hours and
/// Darcy-Weisbach pivots.
void main() {
  final t = I18n('pt');

  /// A 60 × 30 m micro-sprinkler block fed from a supply 30 m away.
  Project block({SubmainPosition submain = SubmainPosition.start, ValvePosition valve = ValvePosition.centre, bool withSupply = true, double stub = 1.5}) {
    final p = Project();
    final b = generateBlock(p, BlockOptions(polygon: [const Pt(0, 0), const Pt(60, 0), const Pt(60, 30), const Pt(0, 30)], direction: const Pt(1, 0), lateralSpacing: 5, outletSpecId: 'micro', nozzleId: 'm50', outletSpacing: 3, headM: 15, submainPosition: submain, valvePosition: valve, submainStub: stub, valveSpecId: 'ev50', zoneName: 'A'));
    p.entities.addAll(b.all);
    if (withSupply) {
      final v = b.valve!.position;
      p.entities.add(PipeEntity(id: p.newId(), points: [v + const Pt(-30, 0), v], scope: HydraulicScope.mainline));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: v + const Pt(-30, 0), calculatePressure: true));
    }
    return p;
  }

  group('designer', () {
    test('progress text, emitter description and analysis without sizing', () {
      expect(const DesignProgress(stage: DesignStage.zones, done: 1, total: 6, zoneId: 'e3', zoneIndex: 2, zoneCount: 3).toString(), 'DesignProgress(zones 1/6 zone 2/3)');
      expect(const DesignProgress(stage: DesignStage.bom, done: 6, total: 6).toString(), 'DesignProgress(bom 6/6)');
      final e = EmitterCurve.fromNominal(flow: 50 * m3sPerLph, head: 16, x: 0.5);
      expect(describeEmitter(e, Units.metric.copyWith(flow: FlowUnit.lph)), 'q = 12.500·H^0.50');
      final p = block();
      final sized = Designer(p).designAll();
      final before = {for (final e in p.entities.whereType<PipeEntity>()) e.id: e.pipeSpecId};
      final r = Designer(p).analyzeAll();
      expect(r.method, 'analysis');
      expect({for (final e in p.entities.whereType<PipeEntity>()) e.id: e.pipeSpecId}, before);
      expect(r.zones.values.single.totalFlow, closeTo(sized.zones.values.single.totalFlow, 1e-9));
    });

    test('a missing valve and a valve without zone pipes give empty zones', () {
      final p = block();
      final d = Designer(p);
      final missing = d.analyzeZone('nope');
      expect(missing.warnings, ['valve_missing']);
      expect(missing.outlets, isEmpty);
      expect(missing.totalFlow, 0);
      final lone = ControlValveEntity(id: p.newId(), position: const Pt(-200, -200), zoneName: 'Solitária');
      p.entities.add(lone);
      final z = Designer(p).analyzeZone(lone.id);
      expect(z.warnings, contains(anyOf('zone_empty', 'valve_missing')));
      expect(z.zoneName, 'Solitária');
      final r = Designer(p).designAll();
      expect(r.zones[lone.id]?.outlets ?? const [], isEmpty);
    });

    test('the zone variation limit narrows the allowed pressure window around the nominal', () {
      final p = block();
      p.params.maxZoneVariationPct = 10;
      final z = Designer(p).designAll().zones.values.single;
      expect(z.nominalPressure, closeTo(15, 0.5));
      expect(z.allowedMin, greaterThanOrEqualTo(z.nominalPressure * 0.95 - 1e-9));
      expect(z.allowedMax, lessThanOrEqualTo(z.nominalPressure * 1.05 + 1e-9));
      expect(z.allowedVariationPct, lessThanOrEqualTo(10 + 1e-6));
      final wide = block();
      wide.params.maxZoneVariationPct = 0;
      final zw = Designer(wide).designAll().zones.values.single;
      expect(zw.allowedMax - zw.allowedMin, greaterThan(z.allowedMax - z.allowedMin));
    });

    test('a filter on the submain adds its loss to the zone', () {
      final plain = block(stub: 4);
      final withFilter = block(stub: 4);
      // the stub between the valve and the submain carries the whole zone
      final valvePos = withFilter.entities.whereType<ControlValveEntity>().single.position;
      final sub = withFilter.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.zone && (e.points.first.distanceTo(valvePos) < 1e-9 || e.points.last.distanceTo(valvePos) < 1e-9));
      final mid = Pt.lerp(sub.points.first, sub.points.last, 0.5);
      // insert a screen filter in the zone (split the stub under it)
      final pieces = [PipeEntity(id: withFilter.newId(), points: [sub.points.first, mid], scope: HydraulicScope.zone), PipeEntity(id: withFilter.newId(), points: [mid, sub.points.last], scope: HydraulicScope.zone)];
      withFilter.entities
        ..remove(sub)
        ..addAll(pieces)
        ..add(MiscHydraulicEntity(id: withFilter.newId(), position: mid, valveSpecId: 'filter_screen80', scope: HydraulicScope.zone));
      final m = NetworkBuilder(withFilter).build();
      expect(m.unconnectedEntities, isEmpty);
      expect(Designer(plain).designAll().zones.values.single.devices, isEmpty);
      final z = Designer(withFilter).designAll().zones.values.single;
      expect(z.converged, isTrue);
      final filter = withFilter.entities.whereType<MiscHydraulicEntity>().single;
      final d = z.devices.single;
      expect(d.entityId, filter.id);
      expect(d.flow, closeTo(z.totalFlow, 1e-9), reason: 'the whole zone passes the filter');
      expect(d.headLoss, closeTo(withFilter.catalog.valve('filter_screen80')!.loss.loss(z.totalFlow), 1e-6));
      expect(d.upstreamPressure - d.downstreamPressure, closeTo(d.headLoss, 1e-6));
    });

    test('a valve of a system flow that the mainline does not reach is reported', () {
      final p = block();
      final far = block(withSupply: false);
      for (final e in far.entities) {
        final c = e.translated(const Pt(0, 500));
        p.entities.add(c.clone(newId: p.newId()));
      }
      final valves = p.entities.whereType<ControlValveEntity>().toList();
      p.systemFlows
        ..clear()
        ..add(SystemFlow(id: 'f', name: 'Todas', valveIds: valves.map((v) => v.id).toSet()));
      final r = Designer(p).designAll();
      final w = r.systemFlows.single.warnings;
      expect(w.where((x) => x.startsWith('valve_unreachable:')).length, 1, reason: '$w');
    });

    test('a catalogue without fittings lists the missing ones by generic name', () {
      final p = block();
      p.catalog.fittings.clear();
      final r = Designer(p, label: t.call).designAll();
      final missing = r.messages.where((m) => m.startsWith('fitting_missing:')).toList();
      expect(missing, isNotEmpty);
      expect(missing.toSet().length, missing.length, reason: 'each name once');
      final lines = r.bom.where((b) => b.description.endsWith(' *')).toList();
      expect(lines, isNotEmpty);
      expect(lines.every((b) => b.unitCost == 0 && b.quantity > 0), isTrue);
    });
  });

  group('small helpers', () {
    test('generic fitting names', () {
      String tr(String k) => k;
      expect(genericFittingName(FittingKind.tee, 75, 50, tr), 'fit.tee 75 × 50 mm');
      expect(genericFittingName(FittingKind.elbow90, 63.5, 0, tr), 'fit.elbow90 63.5 mm');
      expect(genericFittingName(FittingKind.reducer, 50, 50.2, tr), 'fit.reducer 50 mm', reason: 'the same size twice is one size');
      expect(genericFittingName(FittingKind.coupler, 0, 0, tr), 'fit.coupler');
      expect(genericFittingName(FittingKind.endCap, 32, 0, t.call), startsWith(t('fit.endCap')));
    });

    test('largest size of an LP unit, delivery velocity and the extreme outlets', () {
      final a = PipeSpec(id: 'a', name: 'a', nominalMm: 75, innerDiameterMm: 70);
      final b = PipeSpec(id: 'b', name: 'b', nominalMm: 50, innerDiameterMm: 46);
      final lp = LpAssignment(feasible: true, fractions: {'u': [(a, 0.6), (b, 0.4)]}, heads: const []);
      expect(lp.largest('u'), same(a));
      expect(lp.largest('x'), isNull);
      expect(mainVelocity(0.01, 0.1), closeTo(velocity(flow: 0.01, diameter: 0.1), 1e-12));
      expect(mainVelocity(0.01, 0), 0);
      final z = Designer(block()).designAll().zones.values.single;
      expect(z.maxOutlet!.pressure, closeTo(z.maxOutletPressure, 1e-9));
      expect(z.minOutlet!.pressure, closeTo(z.minOutletPressure, 1e-9));
      expect(z.maxOutlet!.pressure, greaterThanOrEqualTo(z.minOutlet!.pressure));
    });
  });

  group('design check and network builder messages', () {
    test('laterals without a valve, dead-end submains and tiny segments', () {
      final p = Project();
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: Pt.zero));
      p.entities.add(SpraylineEntity(id: p.newId(), points: [const Pt(0, 10), const Pt(30, 10)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 3));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 20), const Pt(10, 20), const Pt(10.0001, 20), const Pt(20, 20)], scope: HydraulicScope.mainline));
      final rep = runDesignCheck(p);
      final codes = rep.issues.map((i) => i.code).toList();
      expect(codes, contains('no_valves'));
      expect(codes, contains('tiny_segment'));
      expect(rep.warnings, rep.issues.where((i) => i.severity == CheckSeverity.warning).length);
      expect(rep.warnings, greaterThanOrEqualTo(1));
      final tiny = rep.issues.firstWhere((i) => i.code == 'tiny_segment');
      final j = tiny.toJson();
      expect(j['code'], 'tiny_segment');
      expect(j['sev'], 'warning');
      expect(j['at'], [10.0001, 20.0]);
      expect(const CheckIssue('x', CheckSeverity.info).toJson().containsKey('at'), isFalse);
      // a zone pipe that ends with nothing on it
      final q = block();
      final sub = q.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.zone && (e.points.first - e.points.last).x.abs() < 1e-9);
      q.entities.add(PipeEntity(id: q.newId(), points: [sub.points.last, sub.points.last + const Pt(-10, 0)], scope: HydraulicScope.zone));
      expect(runDesignCheck(q).issues.where((i) => i.code == 'zone_dead_end'), isNotEmpty);
    });

    test('every missing catalogue model is reported by the check and by the network builder', () {
      final p = block();
      final pipe = p.entities.whereType<PipeEntity>().first..pipeSpecId = 'gone_pipe';
      final valve = p.entities.whereType<ControlValveEntity>().first..valveSpecId = 'gone_valve';
      final main = p.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.mainline);
      final mid = Pt.lerp(main.points.first, main.points.last, 0.5);
      final pump = PumpEntity(id: p.newId(), position: mid, pumpSpecId: 'gone_pump');
      final misc = MiscHydraulicEntity(id: p.newId(), position: Pt.lerp(main.points.first, main.points.last, 0.25), valveSpecId: 'gone_misc');
      final pivot = PivotEntity(id: p.newId(), center: const Pt(500, 500), radiusM: 100)..pipeSpecId = 'gone_pivot';
      final lateral = p.entities.whereType<SpraylineEntity>().first..outletSpecId = 'gone_outlet';
      final outlet = OutletEntity(id: p.newId(), position: const Pt(3, 3), outletSpecId: 'gone_outlet2');
      final tape = TapeEntity(id: p.newId(), points: [const Pt(0, 100), const Pt(10, 100)], tapeSpecId: 'gone_tape');
      p.entities.addAll([pump, misc, pivot, outlet, tape]);
      final missing = runDesignCheck(p).issues.where((i) => i.code == 'spec_missing').map((i) => i.value).toSet();
      expect(missing, containsAll(['gone_pipe', 'gone_valve', 'gone_pump', 'gone_pivot']));
      final m = NetworkBuilder(p).build();
      expect(m.warnings, containsAll(['outlet_spec_missing:${lateral.id}', 'outlet_spec_missing:${outlet.id}', 'tape_spec_missing:${tape.id}', 'pump_spec_missing:${pump.id}', 'valve_spec_missing:${misc.id}']));
      expect(m.unconnectedEntities, containsAll([lateral.id, tape.id]));
      expect(pipe.pipeSpecId, 'gone_pipe', reason: 'the check never changes the drawing');
      expect(valve.valveSpecId, 'gone_valve');
    });

    test('a junction with a fixed elevation sets the height of its node', () {
      final p = block();
      final main = p.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.mainline);
      final j = JunctionEntity(id: p.newId(), position: main.points.last, scope: HydraulicScope.mainline, fixedElevation: 123.4);
      p.entities.add(j);
      final m = NetworkBuilder(p).build();
      final node = m.nodes.values.firstWhere((n) => n.entityIds.contains(j.id));
      expect(node.fixedElevation, 123.4);
      expect(node.elevation, closeTo(123.4, 1e-9));
    });
  });

  group('block layouts', () {
    test('a centre submain feeds laterals both ways; the valve can sit at the end', () {
      final start = block();
      final centre = block(submain: SubmainPosition.centre, valve: ValvePosition.end);
      final nStart = start.entities.whereType<SpraylineEntity>().length;
      final laterals = centre.entities.whereType<SpraylineEntity>().toList();
      expect(laterals.length, nStart * 2, reason: 'every row split at the submain');
      for (final l in laterals) {
        expect(l.points.first.x, closeTo(30, 1e-9), reason: 'each half starts at the centre feed');
        expect(l.length, closeTo(30, 1e-9));
      }
      final sub = centre.entities.whereType<PipeEntity>().firstWhere((e) => e.name.startsWith('Submain') || e.points.every((q) => (q.x - 30).abs() < 1e-9));
      final top = sub.points.reduce((a, b) => a.y > b.y ? a : b);
      final v = centre.entities.whereType<ControlValveEntity>().single;
      expect(v.position.y, greaterThanOrEqualTo(top.y - 1e-9), reason: 'valve at the end of the submain');
      expect(Designer(centre).designAll().zones.values.single.withinWindow, isTrue);
    });

    test('guided (curved) blocks with the submain at the end or in the centre', () {
      for (final pos in [SubmainPosition.end, SubmainPosition.centre]) {
        final p = Project();
        final r = generateBlock(p, BlockOptions(polygon: [const Pt(0, 0), const Pt(100, 0), const Pt(100, 60), const Pt(0, 60)], direction: const Pt(1, 0), lateralSpacing: 10, outletSpecId: 'micro', nozzleId: 'm50', outletSpacing: 4, guide: [const Pt(-10, 5), const Pt(50, 15), const Pt(110, 5)], submainPosition: pos, valveSpecId: 'ev50', zoneName: 'Curva ${pos.name}'));
        expect(r.laterals, isNotEmpty, reason: pos.name);
        expect(r.submain, isNotNull, reason: pos.name);
        for (final l in r.laterals.cast<SpraylineEntity>()) {
          for (final q in l.points) {
            expect(q.x, inInclusiveRange(-1e-6, 100 + 1e-6));
            expect(q.y, inInclusiveRange(-1e-6, 60 + 1e-6));
          }
        }
        // rows that cross the whole block (the top row is clipped into two
        // short pieces by the curve, each fed from its own end)
        final full = r.laterals.cast<SpraylineEntity>().where((l) => (l.points.first.x - l.points.last.x).abs() > 45).toList();
        expect(full.length, greaterThanOrEqualTo(4), reason: pos.name);
        if (pos == SubmainPosition.centre) {
          expect(full.every((l) => (l.points.first.x - 50).abs() < 1e-6), isTrue, reason: 'both halves start at the middle');
        } else {
          expect(full.every((l) => (l.points.first.x - 100).abs() < 1e-6), isTrue, reason: 'fed from the far end');
        }
      }
    });
  });

  group('schedules, reports and pivots', () {
    test('a controller programme can keep the start hour of each flow', () {
      final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
      final r = Designer(p, label: t.call).designAll();
      p.systemFlows.first.startHour = 20;
      final kept = buildControllerProgram(p, r, startDate: DateTime(2026, 9, 21), days: 3, keepStartHours: true);
      final chained = buildControllerProgram(p, r, startDate: DateTime(2026, 9, 21), days: 3);
      final flow = p.systemFlows.first.id;
      expect(kept.entries.where((e) => e.flowId == flow).every((e) => e.startHour == 20), isTrue);
      expect(chained.entries.where((e) => e.flowId == flow).every((e) => e.startHour == 6), isTrue, reason: 'the first flow starts the day');
    });

    test('a programme has no entries without zones to water', () {
      final empty = Project();
      expect(buildControllerProgram(empty, null).entries, isEmpty, reason: 'no valve, no automatic flow');
      final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
      p.systemFlows.add(SystemFlow(id: 'vazio', name: 'Vazio', durationHours: 2));
      final prog = buildControllerProgram(p, null, startDate: DateTime(2026, 9, 21), days: 2);
      expect(prog.entries, isNotEmpty);
      expect(prog.entries.where((e) => e.flowId == 'vazio'), isEmpty, reason: 'a flow without zones is skipped');
      expect(prog.perFlowHours.containsKey('vazio'), isFalse);
      // without flows every valve runs in one automatic flow
      p.systemFlows.clear();
      final auto = buildControllerProgram(p, null, startDate: DateTime(2026, 9, 21), days: 1);
      expect(auto.entries.map((e) => e.flowId).toSet(), {'auto'});
      expect(auto.entries.single.zones.length, p.entities.whereType<ControlValveEntity>().length);
    });

    test('unconnected items are listed in the messages table', () {
      final p = block();
      final lone = OutletEntity(id: p.newId(), name: 'Aspersor solto', position: const Pt(500, 500), outletSpecId: 'micro', nozzleId: 'm50');
      p.entities.add(lone);
      final tables = buildReportTables(project: p, results: null, labels: ReportLabels(t: (k, [a]) => k, has: (_) => true, warning: (w) => w, entityName: (id) => p.byId(id)?.name ?? id), unconnected: {lone.id});
      final msg = tables.firstWhere((tb) => tb.key == 'messages');
      expect(msg.rows, [['msg.unconnectedItem', 'Aspersor solto']]);
      expect(msg.warn, [true]);
      expect(buildReportTables(project: p, results: null, labels: ReportLabels(t: (k, [a]) => k, has: (_) => true, warning: (w) => w), unconnected: {lone.id}, includeMessages: false).any((tb) => tb.key == 'messages'), isFalse);
    });

    test('a Darcy-Weisbach pivot agrees with Hazen-Williams for a smooth span pipe', () {
      const hw = PivotSpec(kind: PivotKind.pivot, lengthM: 400, endThrowM: 0, pipeInnerMm: 162, hazenC: 145, grossDepthMm: 8, hoursPerCycle: 24, endPressureM: 14);
      const dw = PivotSpec(kind: PivotKind.pivot, lengthM: 400, endThrowM: 0, pipeInnerMm: 162, grossDepthMm: 8, hoursPerCycle: 24, endPressureM: 14, method: FrictionMethod.darcyWeisbach, roughnessMm: 0.0015);
      final a = analyzePivot(hw, id: 'a', name: 'a');
      final b = analyzePivot(dw, id: 'b', name: 'b');
      expect(b.flow, closeTo(a.flow, 1e-12));
      expect(b.frictionLoss, greaterThan(0));
      expect((b.frictionLoss - a.frictionLoss).abs() / a.frictionLoss, lessThan(0.2));
      expect(b.inletHead, closeTo(14 + b.frictionLoss + b.elevationRise + dw.pipeHeightM + dw.machineLossM, 1e-9));
    });
  });
}
