// 1.6.0 MOT+: the real operation of the zones at the pressure the mainline
// gives them, and the pilots of the zone and mainline valves (reducing,
// sustaining, both).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A supply at a fixed [supplyHead] (m) feeding one micro-sprinkler zone 100
/// m away; [onValve] sets up its valve.
Project opProject({double supplyHead = 10, bool real = true, void Function(ControlValveEntity v)? onValve, bool calculated = false}) {
  final p = Project();
  final block = generateBlock(
    p,
    BlockOptions(
      polygon: [Pt.zero, const Pt(40, 0), const Pt(40, 24), const Pt(0, 24)],
      direction: const Pt(1, 0),
      lateralSpacing: 4,
      outletSpecId: 'micro',
      nozzleId: 'm50',
      outletSpacing: 3.5,
      headM: 15,
      valveSpecId: 'ev50',
      zoneName: 'Zona 1',
    ),
  );
  p.entities.addAll(block.all);
  final valve = block.valve!;
  onValve?.call(valve);
  final supplyPos = valve.position + const Pt(-100, 0);
  p.entities.add(PipeEntity(id: 'main', points: [supplyPos, valve.position], scope: HydraulicScope.mainline, name: 'Main'));
  p.entities.add(WaterSupplyEntity(id: 'src', position: supplyPos, name: 'Mains', calculatePressure: calculated, designHeadM: supplyHead));
  p.params.realZoneOperation = real;
  return p;
}

ZoneOperation opOf(DesignResults r) => r.systemFlows.single.operation.single;

void main() {
  group('real operation of the zones', () {
    test('short of pressure: the zone delivers less, as the zone itself does at the pressure it gets', () {
      final p = opProject(supplyHead: 10);
      final d = Designer(p);
      final r = d.designAll();
      final f = r.systemFlows.single;
      expect(f.warnings.any((w) => w.startsWith('valve_pressure_deficit')), isTrue);
      final o = opOf(r);
      expect(o.designFlow, closeTo(r.zones.values.single.totalFlow, 1e-12));
      expect(o.flow, lessThan(0.98 * o.designFlow));
      expect(o.short, isTrue);
      expect(o.availableHead, lessThan(o.requiredHead));
      expect(o.availableHead, lessThan(10));
      // the zone analysed at the pressure it gets passes that very flow
      final again = d.analyzeZone(o.valveId, downstreamHead: o.downstreamHead);
      expect(again.totalFlow, closeTo(o.flow, 2e-3 * o.designFlow));
      expect(o.minPressure, closeTo(again.minOutletPressure, 1e-6));
      expect(o.eu, greaterThan(0));
    });

    test('a plain valve passes a surplus on; a reducing pilot keeps the design flow', () {
      final plain = opOf(Designer(opProject(supplyHead: 45)).designAll());
      expect(plain.regulates, isFalse);
      expect(plain.flow, greaterThan(1.05 * plain.designFlow));
      expect(plain.excess, isTrue);
      final held = opOf(Designer(opProject(supplyHead: 45, onValve: (v) => v.pilot = ValvePilot.reducing)).designAll());
      expect(held.regulates, isTrue);
      expect(held.flow, closeTo(held.designFlow, 5e-3 * held.designFlow));
      expect(held.excess, isFalse);
    });

    test('a sustaining pilot throttles the zone to keep the mainline before it', () {
      final free = opOf(Designer(opProject(supplyHead: 10)).designAll());
      final kept = opOf(Designer(opProject(supplyHead: 10, onValve: (v) => (v..pilot = ValvePilot.sustaining).pilotSustainM = 9.8)).designAll());
      expect(kept.availableHead, greaterThanOrEqualTo(9.8 - 0.02));
      expect(kept.flow, lessThan(free.flow));
    });

    test('off by default: no operation, no table; on, the results keep it and the report shows it', () {
      final off = Designer(opProject(supplyHead: 10, real: false)).designAll();
      expect(off.systemFlows.single.operation, isEmpty);
      expect(opProject(real: false).params.toJson().containsKey('realOp'), isFalse);
      final p = opProject(supplyHead: 10);
      expect(DesignParameters.fromJson(p.params.toJson()).realZoneOperation, isTrue);
      final r = Designer(p).designAll();
      final back = DesignResults.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(opOf(back).toJson()), jsonEncode(opOf(r).toJson()));
      final labels = ReportLabels(t: (k, [a]) => k, has: (_) => true, warning: (w) => w);
      final tb = buildReportTables(project: p, results: r, labels: labels).firstWhere((t) => t.key == 'operation');
      expect(tb.rows.single.length, tb.headers.length);
      expect(tb.warn.single, isTrue);
      expect(buildReportTables(project: p, results: off, labels: labels).where((t) => t.key == 'operation'), isEmpty);
    });

    test('on demand from a designed project, whatever the parameter says', () {
      final p = opProject(supplyHead: 10, real: false);
      final d = Designer(p);
      final r = d.designAll();
      final ops = d.realOperation(d.effectiveSystemFlows().single, r.systemFlows.single);
      expect(ops.single.flow, lessThan(ops.single.designFlow));
    });
  });

  group('pilot valves', () {
    test('the pilot is written only when there is one, and read back', () {
      final v = ControlValveEntity(id: 'v', position: Pt.zero);
      expect(v.toJson().keys, isNot(contains('pilot')));
      v
        ..pilot = ValvePilot.reducingSustaining
        ..pilotReduceM = 22
        ..pilotSustainM = 30;
      final back = Entity.fromJson(jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>) as ControlValveEntity;
      expect(back.pilot, ValvePilot.reducingSustaining);
      expect(back.pilotReduceM, 22);
      expect(back.pilotSustainM, 30);
      final m = MiscHydraulicEntity(id: 'm', position: Pt.zero, valveSpecId: 'gate50', pilot: ValvePilot.sustaining, pilotSustainM: 25);
      final mb = Entity.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>) as MiscHydraulicEntity;
      expect(mb.pilot, ValvePilot.sustaining);
      expect(mb.pilotSustainM, 25);
      expect(mb.clone().pilotSustainM, 25);
      expect(MiscHydraulicEntity(id: 'm', position: Pt.zero).toJson().keys, isNot(contains('pr')));
    });

    test('a reducing pilot set to a pressure holds the zone there and regulates', () {
      final p = opProject(supplyHead: 45, real: false, onValve: (v) => (v..pilot = ValvePilot.reducing).pilotReduceM = 22);
      final r = Designer(p).designAll();
      final z = r.zones.values.single;
      expect(z.downstreamHead, closeTo(22, 1e-9));
      final duty = r.systemFlows.single.valves.single;
      expect(duty.regulates, isTrue);
      expect(r.systemFlows.single.warnings.where((w) => w.startsWith('valve_pressure_excess')), isEmpty);
      // without the pilot the same valve passes the surplus on
      final plain = Designer(opProject(supplyHead: 45, real: false)).designAll();
      expect(plain.systemFlows.single.warnings.any((w) => w.startsWith('valve_pressure_excess')), isTrue);
    });

    test('a sustaining pilot asks the mainline for its setting at least', () {
      final base = Designer(opProject(real: false, calculated: true)).designAll();
      final need = base.zones.values.single.requiredUpstreamHead;
      final p = opProject(real: false, calculated: true, onValve: (v) => (v..pilot = ValvePilot.sustaining).pilotSustainM = need + 8);
      final r = Designer(p).designAll();
      expect(r.zones.values.single.requiredUpstreamHead, closeTo(need + 8, 1e-9));
      expect(r.systemFlows.single.valves.single.availableHead, greaterThanOrEqualTo(need + 8 - 0.02));
    });

    test('a pilot on a mainline valve makes it a PRV, a PSV or both, the PSV first', () {
      Project withGate(ValvePilot pilot) {
        final p = opProject(supplyHead: 40, real: false);
        final main = p.byId('main') as PipeEntity;
        p.entities.add(MiscHydraulicEntity(id: 'g', position: pointAlongPolyline(main.points, 50), valveSpecId: 'gate50', pilot: pilot, pilotReduceM: 25, pilotSustainM: 30));
        return p;
      }

      final none = NetworkBuilder(withGate(ValvePilot.none)).build();
      expect(none.links.where((l) => l.entityId == 'g').single.kind, GLinkKind.device);
      final red = NetworkBuilder(withGate(ValvePilot.reducing)).build();
      final prv = red.links.where((l) => l.entityId == 'g').single;
      expect(prv.kind, GLinkKind.prv);
      expect(prv.settingM, 25);
      final both = NetworkBuilder(withGate(ValvePilot.reducingSustaining)).build();
      final links = both.links.where((l) => l.entityId == 'g').toList();
      expect(links.map((l) => l.kind).toSet(), {GLinkKind.prv, GLinkKind.psv});
      final psv = links.firstWhere((l) => l.kind == GLinkKind.psv), prv2 = links.firstWhere((l) => l.kind == GLinkKind.prv);
      expect(psv.to, prv2.from, reason: 'the sustaining part comes first');
      expect(psv.settingM, 30);
      expect(both.unconnectedEntities, isEmpty);
      // the reducing part holds the line after it
      final r = Designer(withGate(ValvePilot.reducing)).designAll();
      final dev = r.systemFlows.single.devices.firstWhere((d) => d.entityId == 'g');
      expect(dev.status, 'active');
      expect(dev.downstreamPressure, closeTo(25, 0.01));
    });
  });
}
