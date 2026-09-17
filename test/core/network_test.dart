import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/lateral.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/hydraulics/sparse_solver.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  group('sparse solver', () {
    test('solves a small SPD system', () {
      final s = SparseSymmetricSystem(3);
      s.addDiagonal(0, 4);
      s.addDiagonal(1, 4);
      s.addDiagonal(2, 4);
      s.add(0, 1, -1);
      s.add(1, 2, -1);
      s.rhs[0] = 1;
      s.rhs[1] = 2;
      s.rhs[2] = 3;
      final x = s.solve();
      expect(4 * x[0] - x[1], closeTo(1, 1e-9));
      expect(-x[0] + 4 * x[1] - x[2], closeTo(2, 1e-9));
      expect(-x[1] + 4 * x[2], closeTo(3, 1e-9));
    });
  });

  group('network', () {
    test('single pipe from reservoir to demand node', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50, elevation: 0));
      net.addNode(HNode(id: 'J', elevation: 5, demand: 0.002));
      net.addLink(HLink(id: 'P', from: 'R', to: 'J', diameter: 0.05, length: 100, hazenC: 150));
      final r = net.solve();
      expect(r.converged, isTrue);
      final hf = hazenWilliamsLoss(flow: 0.002, diameter: 0.05, length: 100, c: 150);
      expect(r.links['P']!.flow, closeTo(0.002, 1e-7));
      expect(r.nodes['J']!.head, closeTo(50 - hf, 1e-4));
      expect(r.nodes['J']!.pressure, closeTo(45 - hf, 1e-4));
    });

    test('two reservoirs in a loop split the flow', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'A', kind: HNodeKind.reservoir, fixedHead: 60));
      net.addNode(HNode(id: 'B', kind: HNodeKind.reservoir, fixedHead: 60));
      net.addNode(HNode(id: 'J', demand: 0.01));
      net.addLink(HLink(id: 'a', from: 'A', to: 'J', diameter: 0.1, length: 200));
      net.addLink(HLink(id: 'b', from: 'B', to: 'J', diameter: 0.1, length: 200));
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.links['a']!.flow, closeTo(0.005, 1e-6));
      expect(r.links['b']!.flow, closeTo(0.005, 1e-6));
    });

    test('looped network conserves mass', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40));
      for (final id in ['1', '2', '3', '4']) {
        net.addNode(HNode(id: id, demand: 0.003));
      }
      net.addLink(HLink(id: 'r1', from: 'R', to: '1', diameter: 0.1, length: 50));
      net.addLink(HLink(id: 'l12', from: '1', to: '2', diameter: 0.075, length: 100));
      net.addLink(HLink(id: 'l23', from: '2', to: '3', diameter: 0.05, length: 100));
      net.addLink(HLink(id: 'l34', from: '3', to: '4', diameter: 0.05, length: 100));
      net.addLink(HLink(id: 'l41', from: '4', to: '1', diameter: 0.075, length: 100));
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.links['r1']!.flow, closeTo(0.012, 1e-6));
      // continuity at node 2
      final inflow = r.links['l12']!.flow - r.links['l23']!.flow;
      expect(inflow, closeTo(0.003, 1e-6));
      // energy around loop sums to zero
      final loop = r.links['l12']!.headLoss + r.links['l23']!.headLoss + r.links['l34']!.headLoss + r.links['l41']!.headLoss;
      expect(loop, closeTo(0, 1e-4));
    });

    test('pressure dependent emitters', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30));
      final e = EmitterCurve.fromNominal(flow: 4 * m3sPerLph, head: 10, x: 0.5);
      net.addNode(HNode(id: 'E', elevation: 0, emitter: e, emitterCount: 100));
      net.addLink(HLink(id: 'p', from: 'R', to: 'E', diameter: 0.05, length: 100));
      final r = net.solve();
      expect(r.converged, isTrue);
      final p = r.nodes['E']!.pressure;
      expect(r.links['p']!.flow, closeTo(e.flow(p) * 100, 1e-8));
      expect(p, lessThan(30));
      expect(p, greaterThan(25));
    });

    test('pump lifts water to demand node', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'S', kind: HNodeKind.reservoir, fixedHead: 0));
      net.addNode(HNode(id: 'P', elevation: 0));
      net.addNode(HNode(id: 'D', elevation: 20, demand: 0.01));
      final pump = PumpCurve.fit([(0, 60), (0.01, 50), (0.02, 30)]);
      net.addLink(HLink(id: 'pump', from: 'S', to: 'P', kind: HLinkKind.pump, pump: pump));
      net.addLink(HLink(id: 'main', from: 'P', to: 'D', diameter: 0.1, length: 300));
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.links['pump']!.flow, closeTo(0.01, 1e-6));
      expect(r.links['pump']!.pumpHead, closeTo(50, 1e-3));
      final hf = hazenWilliamsLoss(flow: 0.01, diameter: 0.1, length: 300, c: 150);
      expect(r.nodes['D']!.pressure, closeTo(50 - hf - 20, 1e-3));
    });

    test('PRV holds downstream pressure', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 80));
      net.addNode(HNode(id: 'U', elevation: 0));
      net.addNode(HNode(id: 'V', elevation: 0));
      net.addNode(HNode(id: 'D', elevation: 0, demand: 0.005));
      net.addLink(HLink(id: 'a', from: 'R', to: 'U', diameter: 0.1, length: 100));
      net.addLink(HLink(id: 'prv', from: 'U', to: 'V', kind: HLinkKind.prv, prvSetting: 30));
      net.addLink(HLink(id: 'b', from: 'V', to: 'D', diameter: 0.05, length: 50));
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.nodes['V']!.pressure, closeTo(30, 1e-3));
      expect(r.links['prv']!.flow, closeTo(0.005, 1e-6));
      expect(r.links['b']!.flow, closeTo(0.005, 1e-6));
    });

    test('device loss curve', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50));
      net.addNode(HNode(id: 'A', elevation: 0));
      net.addNode(HNode(id: 'B', elevation: 0, demand: 0.004));
      net.addLink(HLink(id: 'p', from: 'R', to: 'A', diameter: 0.05, length: 10));
      net.addLink(HLink(id: 'v', from: 'A', to: 'B', kind: HLinkKind.device, device: const DeviceLossCurve(k: 1e5, n: 2)));
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.links['v']!.headLoss, closeTo(1e5 * 0.004 * 0.004, 1e-4));
    });

    test('Darcy-Weisbach network converges', () {
      final net = HydraulicNetwork(options: const NetworkOptions(method: FrictionMethod.darcyWeisbach));
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30));
      net.addNode(HNode(id: 'J', elevation: 0, demand: 0.001));
      net.addLink(HLink(id: 'p', from: 'R', to: 'J', diameter: 0.032, length: 80, roughness: 3e-6));
      final r = net.solve();
      expect(r.converged, isTrue);
      final hf = darcyWeisbachLoss(flow: 0.001, diameter: 0.032, length: 80, roughness: 3e-6);
      expect(r.links['p']!.headLoss, closeTo(hf, 1e-4));
    });

    test('large branched network is fast', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 60));
      var prev = 'R';
      for (var i = 0; i < 2000; i++) {
        final id = 'n$i';
        net.addNode(HNode(id: id, demand: 1e-5));
        net.addLink(HLink(id: 'l$i', from: prev, to: id, diameter: 0.075, length: 5));
        if (i % 10 == 0) prev = id; // side branches every 10 nodes
      }
      final sw = Stopwatch()..start();
      final r = net.solve();
      sw.stop();
      expect(r.converged, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(8000));
    });
  });

  group('lateral', () {
    final emitter = EmitterCurve.fromNominal(flow: 2 * m3sPerLph, head: 10, x: 0.5);
    final spec = LateralSpec(length: 100, diameter: 0.0136, spacing: 0.5, emitter: emitter, hazenC: 140);

    test('friction loss agrees with Christiansen estimate', () {
      final r = analyzeLateralFromEnd(spec, 9.0);
      final n = spec.outletCount;
      expect(n, 200);
      final f = christiansenF(outlets: n);
      final est = f * hazenWilliamsLoss(flow: r.inletFlow, diameter: spec.diameter, length: 100, c: 140);
      expect(r.frictionLoss, closeTo(est, est * 0.05));
      expect(r.inletPressure, greaterThan(9.0));
    });

    test('inlet-pressure analysis is consistent', () {
      final r = analyzeLateralFromInlet(spec, 12.0);
      expect(r.inletPressure, closeTo(12.0, 1e-3));
      expect(r.minPressure, lessThan(12.0));
      expect(r.uniformity.cu, greaterThan(90));
    });

    test('mean pressure targeting', () {
      final r = analyzeLateralForMeanPressure(spec, 10.0);
      expect(r.meanPressure, closeTo(10.0, 1e-3));
    });

    test('downhill slope raises end pressure', () {
      final flat = analyzeLateralFromInlet(spec, 12.0);
      final down = analyzeLateralFromInlet(spec, 12.0, elevationAt: (d) => -0.02 * d);
      expect(down.endPressure, greaterThan(flat.endPressure));
    });

    test('max lateral length is monotonic', () {
      final l1 = maxLateralLength(spec, nominalPressure: 10, minPressure: 9, maxPressure: 11, maxLength: 500);
      final l2 = maxLateralLength(spec, nominalPressure: 10, minPressure: 8, maxPressure: 12, maxLength: 500);
      expect(l1, greaterThan(0));
      expect(l2, greaterThan(l1));
    });

    test('feed positions: centre feed is best on flat ground', () {
      final long = spec.copyWith(length: 200);
      final res = allowableFeedPositions(long, nominalPressure: 10, minPressure: 9, maxPressure: 11, steps: 11);
      final centre = res[5];
      final end = res[0];
      expect(centre.variation, lessThan(end.variation));
    });
  });

  group('emitters under negative pressure', () {
    final emitter = EmitterCurve.fromNominal(flow: 100 * m3sPerLph, head: 10);

    test('an emitter above the available head is closed, not a reservoir feeding the network', () {
      // Reservoir at 5 m head, emitter node at 10 m: no water can reach it,
      // so the pipe carries nothing and the node sits at the reservoir head.
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'r', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 5));
      net.addNode(HNode(id: 'a', elevation: 10, emitter: emitter, emitterCount: 10));
      net.addLink(HLink(id: 'p', from: 'r', to: 'a', diameter: 0.05, length: 50, hazenC: 150));
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.links['p']!.flow.abs() / m3sPerLph, lessThan(0.01));
      expect(r.nodes['a']!.head, closeTo(5, 1e-3));
      expect(r.nodes['a']!.emitterFlow, 0);
    });

    test('a closed emitter does not distort the pressure of the emitters that do flow', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'r', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 5));
      net.addNode(HNode(id: 'b', elevation: 2, emitter: emitter, emitterCount: 10));
      net.addNode(HNode(id: 'a', elevation: 10, emitter: emitter, emitterCount: 10));
      net.addLink(HLink(id: 'p1', from: 'r', to: 'b', diameter: 0.05, length: 50, hazenC: 150));
      net.addLink(HLink(id: 'p2', from: 'b', to: 'a', diameter: 0.05, length: 50, hazenC: 150));
      final r = net.solve();
      expect(r.converged, isTrue);
      final qb = r.nodes['b']!.emitterFlow;
      expect(qb, greaterThan(0));
      // mass balance: everything the reservoir sends leaves through b
      expect(r.links['p1']!.flow, closeTo(qb, qb * 1e-4));
      expect(r.links['p2']!.flow.abs(), lessThan(qb * 1e-4));
      // b sees the reservoir head minus the friction of p1 only
      final hf = hazenWilliamsLoss(flow: qb, diameter: 0.05, length: 50, c: 150);
      expect(r.nodes['b']!.pressure, closeTo(5 - 2 - hf, 1e-3));
      expect(r.nodes['a']!.emitterFlow, 0);
    });

    test('emitters reopen when the head rises above them', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'r', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 5));
      net.addNode(HNode(id: 'a', elevation: 10, emitter: emitter, emitterCount: 10));
      net.addLink(HLink(id: 'p', from: 'r', to: 'a', diameter: 0.05, length: 50, hazenC: 150));
      expect(net.solve().nodes['a']!.emitterFlow, 0);
      net.nodes['r']!.fixedHead = 30;
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.nodes['a']!.pressure, greaterThan(15));
      expect(r.nodes['a']!.emitterFlow, closeTo(r.links['p']!.flow, r.links['p']!.flow * 1e-4));
    });
  });
}
