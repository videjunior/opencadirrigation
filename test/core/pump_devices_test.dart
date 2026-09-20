import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/pump_selection.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Every mainline device of the catalog in series between a tank and one
/// micro-sprinkler zone: tank → pump → check valve → screen filter → meter →
/// backflow preventer → gate valve → air valve → PRV → zone valve.
Project series({String pump = 'pump_mid', bool calculated = true, double prvSetting = 40}) {
  final p = Project();
  final poly = [const Pt(0, 0), const Pt(120, 0), const Pt(120, 45), const Pt(0, 45)];
  final block = generateBlock(p, BlockOptions(
    polygon: poly,
    direction: const Pt(1, 0),
    lateralSpacing: 4,
    isTape: false,
    tapeSpecId: 'drip16_16_50',
    outletSpecId: 'micro',
    nozzleId: 'm50',
    outletSpacing: 3.5,
    headM: 15,
    submainPosition: SubmainPosition.start,
    valveSpecId: 'ev50',
    valvePosition: ValvePosition.centre,
    submainStub: 1.5,
    zoneName: 'Zona 1',
  ));
  p.entities.addAll(block.all);
  final valve = block.valve!;
  final supplyPos = valve.position + const Pt(-100, 0);
  p.entities.add(PipeEntity(id: 'main', points: [supplyPos, valve.position], scope: HydraulicScope.mainline, name: 'Main'));
  p.entities.add(WaterSupplyEntity(id: 'tank', position: supplyPos, name: 'Tank', calculatePressure: calculated, designHeadM: 0, waterLevelOffsetM: 1.5));
  var x = supplyPos.x + 5;
  p.entities.add(PumpEntity(id: 'pump', position: Pt(x, supplyPos.y), pumpSpecId: pump, name: 'Pump'));
  for (final id in ['check100', 'filter_screen80', 'meter50', 'backflow50', 'gate50', 'air50', 'prv80']) {
    x += 5;
    p.entities.add(MiscHydraulicEntity(id: 'dev_$id', position: Pt(x, supplyPos.y), valveSpecId: id, name: id, settingM: id.startsWith('prv') ? prvSetting : 0));
  }
  return p;
}

DeviceResult device(SystemFlowResult f, String entityId) => f.devices.firstWhere((d) => d.entityId == entityId);

void main() {
  group('mainline devices in series', () {
    test('every device connects, splits the pipe and reports its own head loss', () {
      final p = series();
      final m = NetworkBuilder(p).build();
      expect(m.unconnectedEntities, isEmpty);
      expect(m.warnings, isEmpty);
      // one link per device plus the pipe pieces between them
      expect(m.mainlineLinks.where((l) => m.linkById(l)!.kind != GLinkKind.pipe).length, 8);
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      expect(f.converged, isTrue);
      expect(f.devices.length, 8);
      final q = f.totalFlow;
      final cat = p.catalog;
      // fixed-K devices: h = K·v²/2g of the catalog curve at the flow
      for (final id in ['check100', 'meter50', 'backflow50', 'gate50']) {
        final d = device(f, 'dev_$id');
        expect(d.flow, closeTo(q, 1e-9), reason: id);
        expect(d.headLoss, closeTo(cat.valve(id)!.loss.loss(q), 1e-6), reason: id);
        expect(d.headLoss, greaterThan(0), reason: id);
        expect(d.upstreamPressure - d.downstreamPressure, closeTo(d.headLoss, 1e-6), reason: id);
      }
      // the filter follows its quadratic curve; the air valve is lossless
      final filter = device(f, 'dev_filter_screen80');
      expect(filter.headLoss, closeTo(2.5 * (q / (60 * m3sPerM3h)) * (q / (60 * m3sPerM3h)), 1e-6));
      expect(device(f, 'dev_air50').headLoss, lessThan(0.01));
      // meter 2" at 18.7 m³/h: K = 7 → about 2.5 m
      expect(device(f, 'dev_meter50').headLoss, closeTo(2.5, 0.2));
      // the zone valve loss is part of the zone's required upstream head
      final z = r.zones.values.single;
      expect(z.requiredUpstreamHead - z.downstreamHead, closeTo(cat.valve('ev50')!.loss.loss(z.totalFlow), 1e-6));
      expect(z.withinWindow, isTrue);
    });

    test('a PRV regulates to its setting only when the upstream pressure exceeds it', () {
      final low = Designer(series(pump: 'pump_small')).designAll().systemFlows.single;
      expect(device(low, 'dev_prv80').status, 'open');
      final high = Designer(series(pump: 'pump_big')).designAll().systemFlows.single;
      final prv = device(high, 'dev_prv80');
      expect(prv.status, 'active');
      expect(prv.downstreamPressure, closeTo(40, 0.05));
      expect(prv.upstreamPressure, greaterThan(40));
    });

    test('the pump adds the head of its curve at the flow and follows the affinity laws', () {
      final p = series();
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final d = device(f, 'pump');
      final curve = p.catalog.pump('pump_mid')!.curve;
      expect(d.pumpHead, closeTo(curve.head(d.flow), 1e-6));
      expect(d.downstreamPressure - d.upstreamPressure, closeTo(d.pumpHead, 1e-6));
      final slow = series();
      (slow.byId('pump') as PumpEntity).speedRatio = 0.8;
      final ds = device(Designer(slow).designAll().systemFlows.single, 'pump');
      expect(ds.pumpHead, closeTo(curve.withSpeed(0.8).head(ds.flow), 1e-6));
      expect(ds.pumpHead, lessThan(d.pumpHead));
      // upstream side found from the supply even when the pipe is drawn backwards
      final rev = series();
      final main = rev.byId('main') as PipeEntity;
      main.points = main.points.reversed.toList();
      final dr = device(Designer(rev).designAll().systemFlows.single, 'pump');
      expect(dr.flow, closeTo(d.flow, 1e-9));
      expect(dr.pumpHead, closeTo(d.pumpHead, 1e-6));
    });

    test('a calculated supply never runs below zero: an oversized pump shows as surplus, not as negative pressure', () {
      final p = series(pump: 'pump_big');
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final s = f.supplies.single;
      expect(s.calculated, isTrue);
      expect(s.head, 0);
      expect(s.requiredHead, lessThan(0));
      expect(s.surplusHead, closeTo(-s.requiredHead, 1e-9));
      expect(s.surplusHead, greaterThan(10));
      // physical pressures: the pump inlet sees the tank water level, the
      // valve gets more than it needs and the pump duty stays consistent
      final pump = device(f, 'pump');
      expect(pump.upstreamPressure, closeTo(1.4, 0.2)); // tank level 1.5 m minus 5 m of pipe
      expect(pump.upstreamPressure, greaterThanOrEqualTo(0));
      expect(f.valves.single.availableHead, greaterThan(f.valves.single.requiredHead + 5));
      expect(f.maxDeficit, lessThan(0));
      expect(f.warnings, isNot(contains(startsWith('pump_out_of_range'))));
      final duty = worstPumpDuty(r, 'tank')!;
      expect(duty.head, closeTo(s.requiredHead + pump.pumpHead, 1e-6));
      expect(duty.head, greaterThan(0));
      for (final seg in f.pipes) {
        expect(seg.pressureStart, greaterThanOrEqualTo(-1e-6), reason: seg.pipeName);
        expect(seg.pressureEnd, greaterThanOrEqualTo(-1e-6), reason: seg.pipeName);
      }
    });

    test('an undersized pump leaves a positive required pressure at the supply and a range warning', () {
      final p = series(pump: 'pump_small');
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final s = f.supplies.single;
      expect(s.requiredHead, greaterThan(0));
      expect(s.head, closeTo(s.requiredHead, 1e-9));
      expect(s.surplusHead, 0);
      expect(f.maxDeficit, lessThan(0.05));
      expect(f.warnings, contains('pump_out_of_range:pump'));
      expect(device(f, 'pump').pumpHead, greaterThan(0));
    });

    test('changing the pump changes the mainline results', () {
      final a = Designer(series(pump: 'pump_c5')).designAll().systemFlows.single;
      final b = Designer(series(pump: 'pump_c7_5')).designAll().systemFlows.single;
      expect(device(b, 'pump').pumpHead, greaterThan(device(a, 'pump').pumpHead + 1));
      expect(b.valves.single.availableHead, greaterThan(a.valves.single.availableHead + 1));
      expect(b.supplies.single.surplusHead, greaterThan(a.supplies.single.surplusHead + 1));
      expect(b.annualEnergyCost, greaterThan(a.annualEnergyCost));
      expect(device(b, 'pump').downstreamPressure, greaterThan(device(a, 'pump').downstreamPressure + 1));
    });

    test('a fixed supply at atmospheric pressure lets the pump curve set every pressure', () {
      final p = series(pump: 'pump_mid', calculated: false, prvSetting: 60);
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final s = f.supplies.single;
      expect(s.calculated, isFalse);
      expect(s.head, 0);
      final pump = device(f, 'pump');
      expect(pump.upstreamPressure, closeTo(1.4, 0.2)); // tank level 1.5 m minus 5 m of pipe
      expect(f.valves.single.availableHead, greaterThan(f.valves.single.requiredHead));
      expect(s.surplusHead, closeTo(-f.maxDeficit, 1e-6));
    });
  });

  group('default catalog pumps', () {
    test('a graded range of centrifugal and submersible pumps with consistent curves and motors', () {
      final cat = Catalog.defaultCatalog();
      expect(cat.pumps.length, greaterThanOrEqualTo(17));
      expect(cat.pumps.map((p) => p.id), containsAll(['pump_c1', 'pump_small', 'pump_c5', 'pump_c7_5', 'pump_mid', 'pump_c20', 'pump_big', 'pump_c50', 'pump_c100', 'pump_s3', 'pump_sub', 'pump_s25']));
      expect(cat.pumps.map((p) => p.id).toSet().length, cat.pumps.length);
      for (final p in cat.pumps) {
        expect(p.powerKw, greaterThan(0), reason: p.id);
        expect(p.maxFlow, greaterThan(0), reason: p.id);
        expect(p.points.length, greaterThanOrEqualTo(4), reason: p.id);
        // curve falls monotonically and still delivers head at the maximum flow
        var last = p.curve.head(0);
        expect(last, greaterThan(0), reason: p.id);
        for (var i = 1; i <= 20; i++) {
          final h = p.curve.head(p.maxFlow * i / 20);
          expect(h, lessThan(last), reason: '${p.id} @ $i/20');
          last = h;
        }
        expect(p.curve.head(p.maxFlow), greaterThan(0), reason: p.id);
        expect(p.curve.runoutFlow, greaterThan(p.maxFlow), reason: p.id);
        // the duty point (third sample) fits the rated motor with the 1.15 service factor
        final (q, h) = p.points[2];
        expect(shaftPower(flow: q, head: h, efficiency: p.efficiency) / 1000, lessThanOrEqualTo(p.powerKw * 1.15), reason: p.id);
        // the fit passes close to the catalogue samples
        for (final (qs, hs) in p.points) {
          expect(p.curve.head(qs), closeTo(hs, 0.08 * hs + 0.5), reason: '${p.id} @ ${qs / m3sPerM3h} m³/h');
        }
      }
      // the names carry the duty point in the three base languages
      for (final lang in ['pt', 'en', 'es']) {
        final c = Catalog.defaultCatalog(lang: lang);
        expect(c.pump('pump_c7_5')!.name, contains('28 m³/h'));
        expect(c.pump('pump_s25')!.name, contains('80 m'));
      }
    });

    test('the device list covers 1" to 6" and every kind', () {
      final cat = Catalog.defaultCatalog();
      expect(cat.valves.map((v) => v.id), containsAll(['ev150', 'prv100', 'gate80', 'gate150', 'check50', 'check80', 'filter_disc80', 'filter_disc100', 'filter_screen100', 'filter_screen150', 'meter80', 'meter100', 'backflow80', 'air25', 'air80']));
      expect(cat.valves.map((v) => v.id).toSet().length, cat.valves.length);
      for (final k in ValveKind.values) {
        if (k == ValveKind.other) continue;
        expect(cat.valves.any((v) => v.kind == k), isTrue, reason: k.name);
      }
      // take-offs exist for every size a sprinkler line can use (50 mm lines included)
      expect(cat.fittings.any((f) => f.kind == FittingKind.takeOff && f.sizeMm == 50), isTrue);
      expect(cat.fittings.any((f) => f.kind == FittingKind.tapeEnd && f.sizeMm == 40), isTrue);
    });

    test('pump selection ranks the graded range for a duty', () {
      final cat = Catalog.defaultCatalog();
      final cands = rankPumps(cat, flow: 18 * m3sPerM3h, head: 32, staticHead: 20, hoursPerYear: 2000, costPerKwh: 0.75);
      expect(cands.first.suitable, isTrue);
      expect(cands.first.parallelCount, 1);
      // the cheapest suitable single unit for 18 m³/h @ 32 m is the 5 hp pump
      expect(cands.first.spec.id, 'pump_c5');
      expect(cands.where((c) => c.suitable).length, greaterThan(5));
    });
  });
}
