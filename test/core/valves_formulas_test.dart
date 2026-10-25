import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  group('variable-speed pumps', vfdTests);
  group('Scobey and Manning', () {
    test('Scobey: 4.1e-3·Ks·L·Q^1.9/D^4.9 (2.59e-3·Ks·L·V^1.9/D^1.1) and its resistance form', () {
      // 100 mm galvanised steel lateral with couplers (Ks 0.42), 1.5 m/s, 100 m
      const d = 0.1, v = 1.5, l = 100.0;
      final q = flowForVelocity(velocity: v, diameter: d);
      final expected = 4.1e-3 * 0.42 * l * math.pow(q, 1.9) / math.pow(d, 4.9);
      expect(scobeyLoss(flow: q, diameter: d, length: l, ks: 0.42), closeTo(expected, 1e-9));
      expect(expected, closeTo(2.59e-3 * 0.42 * l * math.pow(v, 1.9) / math.pow(d, 1.1), 0.01));
      expect(expected, closeTo(2.96, 0.01)); // m per 100 m
      // aluminium with couplers (Ks 0.40) is about Hazen-Williams C 120-130
      final hw120 = hazenWilliamsLoss(flow: q, diameter: d, length: l, c: 120), hw130 = hazenWilliamsLoss(flow: q, diameter: d, length: l, c: 130);
      expect(scobeyLoss(flow: q, diameter: d, length: l, ks: 0.40), inInclusiveRange(hw130, hw120 * 1.1));
      expect(scobeyLoss(flow: -q, diameter: d, length: l, ks: 0.42), closeTo(-expected, 1e-9));
      expect(frictionLoss(method: FrictionMethod.scobey, flow: q, diameter: d, length: l, scobeyKs: 0.42), closeTo(expected, 1e-9));
    });

    test('Manning: 10.29·n²·L·Q²/D^(16/3)', () {
      const q = 0.02, d = 0.15, l = 500.0, n = 0.012;
      final expected = 10.29 * n * n * l * q * q / math.pow(d, 16 / 3);
      expect(manningLoss(flow: q, diameter: d, length: l, n: n), closeTo(expected, 1e-12));
      expect(frictionLoss(method: FrictionMethod.manning, flow: q, diameter: d, length: l, manningN: n), closeTo(expected, 1e-12));
      expect(flowExponent(FrictionMethod.manning), 2.0);
      expect(flowExponent(FrictionMethod.scobey), 1.9);
    });

    test('the solver uses them: one pipe between two reservoirs carries the flow of the law', () {
      for (final (method, ks, n) in [(FrictionMethod.scobey, 0.40, 0.0), (FrictionMethod.manning, 0.0, 0.011)]) {
        final net = HydraulicNetwork(options: NetworkOptions(method: method))
          ..addNode(HNode(id: 'a', kind: HNodeKind.reservoir, fixedHead: 30))
          ..addNode(HNode(id: 'b', kind: HNodeKind.reservoir, fixedHead: 10))
          ..addLink(HLink(id: 'p', from: 'a', to: 'b', diameter: 0.1, length: 800, scobeyKs: ks, manningN: n));
        final r = net.solve();
        expect(r.converged, isTrue);
        final q = r.links['p']!.flow;
        final hf = method == FrictionMethod.scobey ? scobeyLoss(flow: q, diameter: 0.1, length: 800, ks: ks) : manningLoss(flow: q, diameter: 0.1, length: 800, n: n);
        expect(hf, closeTo(20, 1e-3), reason: method.name);
      }
    });

    test('catalogue materials give their coefficients', () {
      final cat = Catalog.defaultCatalog();
      expect(cat.pipe('pvc100')!.scobeyKs, 0.32);
      expect(cat.pipe('pvc100')!.manningN, 0.009);
      expect(cat.pipe('steel150')!.scobeyKs, 0.42);
      expect(cat.pipe('steel150')!.manningN, 0.012);
    });
  });

  group('pressure sustaining and flow control valves', () {
    // reservoir 60 m → 1000 m of 100 mm pipe → B → valve → 10 m pipe → reservoir 0 m
    HydraulicNetwork net(HLink valve) => HydraulicNetwork()
      ..addNode(HNode(id: 'r1', kind: HNodeKind.reservoir, fixedHead: 60))
      ..addNode(HNode(id: 'b'))
      ..addNode(HNode(id: 'c'))
      ..addNode(HNode(id: 'r2', kind: HNodeKind.reservoir, fixedHead: 0))
      ..addLink(HLink(id: 'p1', from: 'r1', to: 'b', diameter: 0.1, length: 1000, hazenC: 130))
      ..addLink(valve)
      ..addLink(HLink(id: 'p2', from: 'c', to: 'r2', diameter: 0.1, length: 10, hazenC: 130));
    final loss = DeviceLossCurve.fromK(3, 0.1);

    test('a PSV holds the upstream pressure at its setting and limits the flow accordingly', () {
      final r = net(HLink(id: 'v', from: 'b', to: 'c', kind: HLinkKind.psv, prvSetting: 40, device: loss)).solve();
      expect(r.converged, isTrue);
      expect(r.nodes['b']!.pressure, closeTo(40, 1e-3));
      expect(r.links['v']!.status, LinkStatus.active);
      final q = r.links['p1']!.flow;
      expect(hazenWilliamsLoss(flow: q, diameter: 0.1, length: 1000, c: 130), closeTo(20, 1e-3));
      expect(r.links['v']!.flow, closeTo(q, 1e-9));
      // a setting below what the line keeps anyway: the valve is just open
      final open = net(HLink(id: 'v', from: 'b', to: 'c', kind: HLinkKind.psv, prvSetting: 1, device: loss)).solve();
      expect(open.links['v']!.status, LinkStatus.open);
      expect(open.nodes['b']!.pressure, greaterThan(1));
    });

    test('an FCV lets its flow setting through, or less when the head is not there', () {
      const setting = 4 * m3sPerLps;
      final r = net(HLink(id: 'v', from: 'b', to: 'c', kind: HLinkKind.fcv, fcvFlow: setting, device: loss)).solve();
      expect(r.converged, isTrue);
      expect(r.links['v']!.status, LinkStatus.active);
      // a vanishing conductance across the valve keeps both sides tied (1e-8)
      expect(r.links['p1']!.flow, closeTo(setting, 1e-6));
      expect(r.nodes['b']!.pressure, greaterThan(r.nodes['c']!.pressure));
      // asking for more than the line can carry: open, the natural flow
      final big = net(HLink(id: 'v', from: 'b', to: 'c', kind: HLinkKind.fcv, fcvFlow: 1, device: loss)).solve();
      expect(big.converged, isTrue);
      expect(big.links['v']!.status, LinkStatus.open);
      expect(big.links['p1']!.flow, lessThan(1));
      expect(big.links['p1']!.flow, greaterThan(setting));
    });

    test('a hydrant flow limiter in a project limits the flow of its branch', () {
      final t = I18n('pt');
      final p = Project();
      p.entities.addAll([
        WaterSupplyEntity(id: 'w', position: Pt.zero, calculatePressure: false, designHeadM: 50, maxHeadM: 50),
        PipeEntity(id: 'm', points: [Pt.zero, const Pt(200, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc75', computerSized: false),
        MiscHydraulicEntity(id: 'h', position: const Pt(200, 0), valveSpecId: 'fcv50', settingFlow: 6 * m3sPerM3h),
        PipeEntity(id: 'm2', points: [const Pt(200, 0), const Pt(220, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc75', computerSized: false),
        ControlValveEntity(id: 'v', position: const Pt(220, 0), zoneName: 'Z', valveSpecId: 'ev50'),
        PipeEntity(id: 'z', points: [const Pt(220, 0), const Pt(220, 30)], scope: HydraulicScope.zone, pipeSpecId: 'pe50', computerSized: false),
        for (var i = 0; i < 10; i++) SpraylineEntity(id: 's$i', points: [Pt(220, 2 + i * 3.0), Pt(260, 2 + i * 3.0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 3, offset: 1.5),
      ]);
      final r = Designer(p, label: (k) => t(k)).designAll();
      final flow = r.systemFlows.single;
      expect(flow.devices.where((d) => d.entityId == 'h').single.flow, lessThanOrEqualTo(6 * m3sPerM3h + 1e-9));
    });
  });
}

void vfdTests() {
  test('a variable-speed pump holds its outlet pressure flow after flow; NPSH and efficiency curves', () {
    final t = I18n('en');
    final p = buildExampleProject(t.call, lang: 'en');
    final pump = p.entities.whereType<PumpEntity>().first;
    final spec = p.catalog.pump(pump.pumpSpecId)!;
    // the full-speed outlet pressure of the plain design, then ask for less
    final plain = Designer(p, label: (k) => t(k)).designAll();
    final dev0 = plain.systemFlows.first.devices.firstWhere((d) => d.entityId == pump.id);
    expect(dev0.speedRatio, 1);
    // below the full-speed outlet by half the smallest surplus at the valves,
    // so every valve still gets its pressure
    final surplus = plain.systemFlows.expand((f) => f.valves).map((v) => v.availableHead - v.requiredHead).reduce(math.min);
    expect(surplus, greaterThan(0.5));
    final target = dev0.downstreamPressure - surplus / 2;
    pump.targetPressureM = target;
    final r = Designer(p, label: (k) => t(k)).designAll();
    for (final f in r.systemFlows) {
      final d = f.devices.firstWhere((x) => x.entityId == pump.id);
      if (f.warnings.any((w) => w.startsWith('vfd_'))) continue;
      expect(d.speedRatio, lessThan(1));
      expect(d.downstreamPressure, closeTo(target, 0.1), reason: f.name);
    }
    // efficiency from the curve at the homologous flow; NPSH grows with n²
    spec.efficiencyPoints = [(0.001, 0.5), (0.01, 0.7), (0.02, 0.6)];
    spec.npshPoints = [(0.005, 2), (0.015, 4)];
    expect(spec.efficiencyAt(0.01), closeTo(0.7, 1e-12));
    expect(spec.efficiencyAt(0.008, speed: 0.8), closeTo(0.7, 1e-12));
    expect(spec.npshrAt(0.01), closeTo(3, 1e-12));
    expect(spec.npshrAt(0.008, speed: 0.8), closeTo(3 * 0.64, 1e-12));
    expect(spec.npshrAt(0.02), closeTo(5, 1e-12)); // extended past the last point
    final back = PumpSpec.fromJson(spec.toJson());
    expect(back.efficiencyPoints, spec.efficiencyPoints);
    expect(back.npshPoints, spec.npshPoints);
    expect(npshAvailable(inletPressure: 0, elevation: 0, tempC: 20), closeTo(10.33 - 0.238, 0.01));
    expect(vapourHead(20), closeTo(0.238, 0.002));
    // a pump that needs more NPSH than the inlet has is reported
    spec.npshPoints = [(0.0, 30), (1.0, 30)];
    pump.targetPressureM = 0;
    final starved = Designer(p, label: (k) => t(k)).designAll();
    expect(starved.systemFlows.expand((f) => f.warnings).any((w) => w.startsWith('pump_npsh:')), isTrue);
  });
}
