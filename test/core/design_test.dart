import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

Project orchard({bool tape = false, bool slope = false}) {
  final p = Project();
  if (slope) {
    p.entities.add(ContourEntity(id: p.newId(), points: [const Pt(-50, -20), const Pt(200, -20)], elevation: 100));
    p.entities.add(ContourEntity(id: p.newId(), points: [const Pt(-50, 60), const Pt(200, 60)], elevation: 104));
  }
  final poly = [const Pt(0, 0), const Pt(120, 0), const Pt(120, 45), const Pt(0, 45)];
  final block = generateBlock(p, BlockOptions(
    polygon: poly,
    direction: const Pt(1, 0),
    lateralSpacing: 4,
    isTape: tape,
    tapeSpecId: 'drip16_16_50',
    outletSpecId: 'micro',
    nozzleId: 'm50',
    outletSpacing: 3.5,
    headM: 15,
    submainPosition: SubmainPosition.start,
    valveSpecId: 'ev80',
    valvePosition: ValvePosition.centre,
    submainStub: 1.5,
    zoneName: 'Zona 1',
  ));
  p.entities.addAll(block.all);
  final valve = block.valve!;
  // mainline from supply to the valve
  final supplyPos = valve.position + const Pt(-40, 0);
  p.entities.add(PipeEntity(id: p.newId(), points: [supplyPos, valve.position], scope: HydraulicScope.mainline));
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: supplyPos, name: 'Poço', calculatePressure: true));
  return p;
}

void main() {
  test('block generator lays out laterals, submain and valve', () {
    final p = orchard();
    final laterals = p.entities.whereType<SpraylineEntity>().toList();
    expect(laterals.length, 11); // 45/4 rows starting at 2 m
    expect(laterals.first.length, closeTo(120, 1e-6));
    expect(laterals.first.outletCount, 34);
    expect(p.entities.whereType<ControlValveEntity>().length, 1);
    expect(p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.zone).length, 2);
  });

  test('network builder connects everything', () {
    final p = orchard();
    final m = NetworkBuilder(p).build();
    expect(m.unconnectedEntities, isEmpty);
    expect(m.valveNodes.length, 1);
    final valveId = m.valveNodes.keys.first;
    expect(m.zoneLinks[valveId]!.length, greaterThan(11 * 30));
    expect(m.mainlineLinks.length, 1);
    expect(m.supplyNodes.length, 1);
  });

  test('zone analysis at fixed valve pressure', () {
    final p = orchard();
    final d = Designer(p);
    final valveId = d.model.valveNodes.keys.first;
    // give sizes first (velocity design) so analysis has pipes
    final z = d.sizeZone(valveId);
    expect(z.converged, isTrue);
    expect(z.outlets.length, greaterThan(0));
    expect(z.emitterCount, 11 * 34);
    // mean pressure at nominal 15 m
    final mean = z.outlets.fold<double>(0, (s, o) => s + o.pressure * o.count) / z.emitterCount;
    expect(mean, closeTo(15, 0.15));
    expect(z.withinWindow, isTrue, reason: z.warnings.join(','));
    expect(z.totalFlow / m3sPerLph, closeTo(11 * 34 * 50, 11 * 34 * 50 * 0.05));
    expect(z.uniformity.cu, greaterThan(95));
    // sizes written back
    for (final s in p.entities.whereType<SpraylineEntity>()) {
      expect(s.pipeSpecId, isNotNull);
    }
    final sub = p.entities.whereType<PipeEntity>().firstWhere((e) => e.name.startsWith('Submain'));
    expect(sub.pipeSpecId, isNotNull);
    expect(z.requiredUpstreamHead, greaterThan(z.downstreamHead));
  });

  test('full design with mainline and BOM', () {
    final p = orchard();
    final d = Designer(p);
    final r = d.designAll();
    expect(r.zones.length, 1);
    expect(r.systemFlows.length, 1);
    final sf = r.systemFlows.single;
    expect(sf.converged, isTrue);
    expect(sf.supplies.single.flow, closeTo(r.zones.values.single.totalFlow, 1e-6));
    expect(sf.valves.single.deficit, lessThan(0.05));
    expect(sf.supplies.single.requiredHead, greaterThan(r.zones.values.single.requiredUpstreamHead));
    expect(r.bom.where((b) => b.category == 'bom.pipes').isNotEmpty, isTrue);
    expect(r.bom.firstWhere((b) => b.category == 'bom.outlets').quantity, 11 * 34);
    expect(r.capitalCost, greaterThan(0));
    final main = p.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.mainline);
    expect(main.pipeSpecId, isNotNull);
    expect(sf.pipes.single.velocity, lessThanOrEqualTo(p.params.maxMainlineVelocity + 1e-6));
  });

  test('tape block on a slope', () {
    final p = orchard(tape: true, slope: true);
    final d = Designer(p);
    final r = d.designAll();
    final z = r.zones.values.single;
    expect(z.converged, isTrue);
    expect(z.outlets.length, greaterThan(0));
    expect(z.minOutletPressure, greaterThan(0));
    expect(z.uniformity.eu, greaterThan(80));
    expect(r.bom.any((b) => b.category == 'bom.tapes'), isTrue);
  });

  test('fixed supply pressure sizes mainline for deficit', () {
    final p = orchard();
    final s = p.entities.whereType<WaterSupplyEntity>().single;
    s.calculatePressure = false;
    s.designHeadM = 40;
    final d = Designer(p);
    final r = d.designAll();
    final sf = r.systemFlows.single;
    expect(sf.supplies.single.head, 40);
    expect(sf.valves.single.availableHead, greaterThanOrEqualTo(sf.valves.single.requiredHead - 0.05));
  });
  test('designAllAsync matches designAll, yields between steps and reports progress', () async {
    final sync = Designer(orchard(slope: true)).designAll();
    final d = Designer(orchard(slope: true));
    final seen = <DesignProgress>[];
    var yields = 0;
    final r = await d.designAllAsync(
      onProgress: seen.add,
      yieldControl: () async {
        yields++;
        await Future<void>.delayed(Duration.zero);
      },
    );
    // same design
    expect(r.zones.length, sync.zones.length);
    expect(r.systemFlows.length, sync.systemFlows.length);
    expect(r.bom.length, sync.bom.length);
    for (final e in r.zones.entries) {
      final z = sync.zones[e.key]!;
      expect(e.value.converged, z.converged);
      expect(e.value.minOutletPressure, closeTo(z.minOutletPressure, 1e-6));
      expect(e.value.totalFlow, closeTo(z.totalFlow, 1e-9));
      expect(e.value.requiredUpstreamHead, closeTo(z.requiredUpstreamHead, 1e-6));
    }
    // one yield per step: zones + mainline + flushing + surge + BOM (+ a split pass)
    expect(yields, greaterThanOrEqualTo(r.zones.length + 4));
    expect(seen.length, yields + 1);
    // stages in order, counters monotonic, ends complete
    expect(seen.first.stage, DesignStage.zones);
    expect(seen.first.zoneIndex, 1);
    expect(seen.first.zoneCount, 1);
    expect(seen.first.done, 0);
    final stages = seen.map((p) => p.stage).toList();
    expect(stages.indexOf(DesignStage.mainline), greaterThan(stages.lastIndexOf(DesignStage.zones)));
    expect(stages.indexOf(DesignStage.flushing), greaterThan(stages.indexOf(DesignStage.mainline)));
    expect(stages.indexOf(DesignStage.surge), greaterThan(stages.indexOf(DesignStage.flushing)));
    expect(stages.lastIndexOf(DesignStage.bom), seen.length - 1);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i].done, greaterThanOrEqualTo(seen[i - 1].done));
      expect(seen[i].fraction, inInclusiveRange(0, 1));
    }
    expect(seen.last.done, seen.last.total);
    expect(seen.last.fraction, 1);
  });

  test('designAllAsync analysis-only keeps existing sizes', () async {
    final p = orchard();
    Designer(p).designAll();
    final sized = {for (final e in p.entities.whereType<PipeEntity>()) e.id: e.pipeSpecId};
    final r = await Designer(p).designAllAsync(sizeZones: false, sizeMain: false);
    expect(r.method, 'analysis');
    expect({for (final e in p.entities.whereType<PipeEntity>()) e.id: e.pipeSpecId}, sized);
    expect(r.zones.values.single.converged, isTrue);
  });
}
