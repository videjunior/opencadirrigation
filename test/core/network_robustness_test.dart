/// Convergence of the network solver where the emitters work near zero
/// pressure, pumps near their shutoff head and pressure reducing valves near
/// their setting: cases that used to cycle (emitters flipping open/closed at
/// every iteration, a pump locked closed after one bad step) and a fixed set
/// of random tree networks whose solutions must satisfy continuity and the
/// head-loss laws, not only report convergence.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';

/// Worst continuity error (fraction of the largest flow) and worst pipe
/// head-loss error (m) of a solution.
(double, double) residuals(HydraulicNetwork net, NetworkResult r) {
  final balance = <String, double>{for (final id in net.nodes.keys) id: 0};
  var largest = 1e-6;
  for (final l in net.links) {
    final q = r.links[l.id]!.flow;
    balance[l.from] = balance[l.from]! - q;
    balance[l.to] = balance[l.to]! + q;
    largest = math.max(largest, q.abs());
  }
  var continuity = 0.0, energy = 0.0;
  for (final n in net.nodes.values) {
    if (n.kind == HNodeKind.reservoir) continue;
    final nr = r.nodes[n.id]!;
    continuity = math.max(continuity, (balance[n.id]! - n.demand - nr.emitterFlow).abs() / largest);
    if (n.emitter != null) {
      // one-way law: no flow below the emitter, the law above it
      final p = nr.head - n.elevation - n.emitterOffset;
      if (p < -1e-3) expect(nr.emitterFlow, 0, reason: 'emitter ${n.id} under negative pressure');
    }
  }
  for (final l in net.links) {
    final lr = r.links[l.id]!;
    if (l.kind != HLinkKind.pipe || lr.status == LinkStatus.closed) continue;
    final hf = hazenWilliamsLoss(flow: lr.flow, diameter: l.diameter, length: l.length, c: l.hazenC) + (l.minorK > 0 ? minorLoss(k: l.minorK, flow: lr.flow, diameter: l.diameter) : 0);
    energy = math.max(energy, (hf - (r.nodes[l.from]!.head - r.nodes[l.to]!.head)).abs());
  }
  return (continuity, energy);
}

/// Random tree fed by a reservoir, sometimes through a pump, with pipes sized
/// for their downstream nominal flow as a designer would, emitters of every
/// kind (pressure compensating, orifice, laminar), demands, check valves and
/// nodes above the hydraulic grade line.
HydraulicNetwork randomNetwork(int seed) {
  final rnd = math.Random(seed);
  final net = HydraulicNetwork();
  final pumped = rnd.nextBool();
  final reservoirHead = pumped ? rnd.nextDouble() * 5 : 10 + rnd.nextDouble() * 70;
  net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, elevation: reservoirHead, fixedHead: reservoirHead));
  var root = 'R';
  if (pumped) {
    net.addNode(HNode(id: 'P'));
    final h0 = 20 + rnd.nextDouble() * 60, q1 = 0.002 + rnd.nextDouble() * 0.03;
    net.addLink(HLink(id: 'pump', from: 'R', to: 'P', kind: HLinkKind.pump, pump: PumpCurve.fit([(0, h0), (q1, h0 * 0.8), (2 * q1, h0 * 0.4)])));
    root = 'P';
  }
  const exponents = [0.0, 0.02, 0.45, 0.5, 0.55, 1.0];
  final ids = [root];
  final parent = <String, String>{};
  final nominal = <String, double>{};
  for (var i = 0; i < 3 + rnd.nextInt(40); i++) {
    final id = 'N$i';
    parent[id] = ids[rnd.nextInt(ids.length)];
    final x = exponents[rnd.nextInt(exponents.length)];
    final hasEmitters = rnd.nextDouble() < 0.6;
    final q = (2 + rnd.nextDouble() * 2000) / 3.6e6, h = 10 + rnd.nextDouble() * 20;
    final count = 1 + rnd.nextInt(50);
    final demand = rnd.nextDouble() < 0.1 ? rnd.nextDouble() * 0.001 : 0.0;
    net.addNode(HNode(
      id: id,
      elevation: rnd.nextDouble() * 40 - 5,
      demand: demand,
      emitter: hasEmitters ? EmitterCurve(k: q / math.pow(h, x), x: x) : null,
      emitterCount: count,
      emitterOffset: hasEmitters && rnd.nextBool() ? rnd.nextDouble() : 0,
    ));
    nominal[id] = (hasEmitters ? count * q : 0) + demand;
    ids.add(id);
  }
  double downstream(String id) => nominal[id]! + [for (final c in parent.keys.where((c) => parent[c] == id)) downstream(c)].fold(0.0, (a, b) => a + b);
  const sizes = [0.016, 0.02, 0.025, 0.032, 0.04, 0.05, 0.063, 0.075, 0.09, 0.11, 0.125, 0.16, 0.2, 0.25];
  for (final id in ids.skip(1)) {
    final q = downstream(id);
    net.addLink(HLink(
      id: 'L$id',
      from: parent[id]!,
      to: id,
      diameter: sizes.firstWhere((d) => velocity(flow: q, diameter: d) <= 2.5, orElse: () => 0.3),
      length: 2 + rnd.nextDouble() * 200,
      hazenC: 120 + rnd.nextDouble() * 30,
      checkValve: rnd.nextDouble() < 0.1,
      minorK: rnd.nextDouble() < 0.3 ? rnd.nextDouble() * 5 : 0,
    ));
  }
  return net;
}

void main() {
  test('a pump near its shutoff head feeding many emitters near zero pressure converges to the operating point', () {
    final pump = PumpCurve.fit([(0, 60), (0.010, 50), (0.020, 30)]);
    final em = EmitterCurve.fromNominal(flow: 0.0002, head: 20);
    for (final (z, length) in [(55.0, 200.0), (55.0, 1000.0), (40.0, 200.0)]) {
      final net = HydraulicNetwork()
        ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 0))
        ..addNode(HNode(id: 'P'))
        ..addNode(HNode(id: 'J', elevation: z))
        ..addLink(HLink(id: 'pump', from: 'R', to: 'P', kind: HLinkKind.pump, pump: pump))
        ..addLink(HLink(id: 'main', from: 'P', to: 'J', diameter: 0.05, length: length, hazenC: 140));
      for (var i = 0; i < 100; i++) {
        net
          ..addNode(HNode(id: 'E$i', elevation: z, emitter: em))
          ..addLink(HLink(id: 'l$i', from: 'J', to: 'E$i', diameter: 0.02, length: 5, hazenC: 140));
      }
      final r = net.solve();
      expect(r.converged, isTrue, reason: 'z $z, L $length (it used to flip the emitters open/closed for 200 iterations)');
      // reference: the total flow where pump head − main loss feeds 100
      // identical branches (bisection on each)
      double branch(double hj) {
        var lo = 0.0, hi = em.flow(math.max(hj - z, 0));
        for (var i = 0; i < 100; i++) {
          final m = (lo + hi) / 2;
          final he = hj - hazenWilliamsLoss(flow: m, diameter: 0.02, length: 5, c: 140);
          if (em.flow(math.max(he - z, 0)) > m) {
            lo = m;
          } else {
            hi = m;
          }
        }
        return (lo + hi) / 2;
      }

      var lo = 1e-9, hi = pump.runoutFlow;
      for (var i = 0; i < 200; i++) {
        final m = (lo + hi) / 2;
        final hj = pump.head(m) - hazenWilliamsLoss(flow: m, diameter: 0.05, length: length, c: 140);
        if (100 * branch(hj) > m) {
          lo = m;
        } else {
          hi = m;
        }
      }
      expect(r.links['pump']!.flow, closeTo((lo + hi) / 2, (lo + hi) / 2 * 1e-3), reason: 'z $z, L $length');
      expect(r.nodes['J']!.head, lessThanOrEqualTo(pump.shutoffHead), reason: 'no node above what the pump can lift');
    }
  });

  test('a pump that one iteration would see running backwards reopens', () {
    // lifting 3 m of reservoir water to emitters 23–26 m up: the first
    // iterations ask more head than the pump has and closed it for good
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, elevation: 3.2, fixedHead: 3.2))
      ..addNode(HNode(id: 'P'))
      ..addNode(HNode(id: 'A', elevation: 26.4, emitter: EmitterCurve.fromNominal(flow: 0.0003, head: 15), emitterCount: 26, emitterOffset: 0.5))
      ..addNode(HNode(id: 'B', elevation: 25.7, emitter: EmitterCurve.fromNominal(flow: 0.0001, head: 15), emitterCount: 13))
      ..addLink(HLink(id: 'pump', from: 'R', to: 'P', kind: HLinkKind.pump, pump: PumpCurve.fit([(0, 45), (0.006, 36), (0.012, 18)])))
      ..addLink(HLink(id: 'a', from: 'P', to: 'A', diameter: 0.075, length: 90))
      ..addLink(HLink(id: 'b', from: 'A', to: 'B', diameter: 0.075, length: 92));
    final r = net.solve();
    expect(r.converged, isTrue);
    expect(r.links['pump']!.flow, greaterThan(0.001), reason: 'the pump lifts the water');
    expect(r.links['pump']!.status, LinkStatus.open);
    final (continuity, energy) = residuals(net, r);
    expect(continuity, lessThan(1e-4));
    expect(energy, lessThan(1e-3));
  });

  test('pressure compensating emitters on a hill: the high ones are dry, the starved ones share the water', () {
    final pc = EmitterCurve.fromNominal(flow: 2 / 3.6e6, head: 10, x: 0.02);
    final net = HydraulicNetwork()..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 20));
    var previous = 'R';
    for (var i = 0; i < 40; i++) {
      // a lateral climbing 0.6 m per 2 m: the last outlets are above the
      // grade line, those before them barely get water
      net
        ..addNode(HNode(id: 'n$i', elevation: 0.6 * i, emitter: pc, emitterCount: 20))
        ..addLink(HLink(id: 's$i', from: previous, to: 'n$i', diameter: 0.0136, length: 2, hazenC: 140));
      previous = 'n$i';
    }
    final r = net.solve();
    expect(r.converged, isTrue, reason: 'pressure compensating emitters near zero pressure used to flip at every iteration');
    final (continuity, energy) = residuals(net, r);
    expect(continuity, lessThan(1e-4));
    expect(energy, lessThan(1e-3));
    expect(r.nodes['n0']!.emitterFlow, closeTo(20 * 2 / 3.6e6, 20 * 2 / 3.6e6 * 0.05), reason: 'full flow where the pressure is there');
    expect(r.nodes['n39']!.emitterFlow, 0, reason: 'above the grade line: dry');
  });

  test('an open pressure reducing valve whose inlet is just above the setting stays open', () {
    // inlet 30.05 m, setting 30 m, but the fully open valve already loses
    // 0.5 m: the outlet cannot reach the setting, so the valve must stay
    // open (EPANET checks the outlet head, not the inlet) instead of
    // claiming 30 m downstream
    final valve = DeviceLossCurve.fit([(0.002, 0.125), (0.004, 0.5)]);
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30.05))
      ..addNode(HNode(id: 'U'))
      ..addNode(HNode(id: 'D', demand: 0.004))
      ..addLink(HLink(id: 'feed', from: 'R', to: 'U', diameter: 0.5, length: 1))
      ..addLink(HLink(id: 'prv', from: 'U', to: 'D', kind: HLinkKind.prv, prvSetting: 30, device: valve));
    final r = net.solve();
    expect(r.converged, isTrue);
    expect(r.links['prv']!.status, LinkStatus.open);
    expect(r.nodes['D']!.head, closeTo(30.05 - 0.5, 0.01));
  });

  test('a check valve fitted as a device stops reverse flow', () {
    // tank A (50 m) → check valve → J ← tank B (60 m): B must not drain into
    // A through the valve (it let 25 L/s run backwards)
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'A', kind: HNodeKind.reservoir, fixedHead: 50))
      ..addNode(HNode(id: 'B', kind: HNodeKind.reservoir, fixedHead: 60))
      ..addNode(HNode(id: 'J', demand: 0.001))
      ..addLink(HLink(id: 'cv', from: 'A', to: 'J', kind: HLinkKind.device, device: DeviceLossCurve.fromK(2, 0.1), checkValve: true))
      ..addLink(HLink(id: 'b', from: 'B', to: 'J', diameter: 0.1, length: 100));
    final r = net.solve();
    expect(r.converged, isTrue);
    expect(r.links['cv']!.status, LinkStatus.closed);
    expect(r.links['cv']!.flow.abs(), lessThan(1e-6));
    expect(r.links['b']!.flow, closeTo(0.001, 1e-6), reason: 'B feeds the demand alone');
    // the other way round the valve opens
    final open = HydraulicNetwork()
      ..addNode(HNode(id: 'A', kind: HNodeKind.reservoir, fixedHead: 60))
      ..addNode(HNode(id: 'J', demand: 0.001))
      ..addLink(HLink(id: 'cv', from: 'A', to: 'J', kind: HLinkKind.device, device: DeviceLossCurve.fromK(2, 0.1), checkValve: true));
    final ro = open.solve();
    expect(ro.links['cv']!.flow, closeTo(0.001, 1e-6));
  });

  test('random sized networks converge to solutions that satisfy continuity and the loss laws', () {
    var iterations = 0;
    for (var seed = 0; seed < 300; seed++) {
      final net = randomNetwork(seed);
      final r = net.solve();
      iterations += r.iterations;
      expect(r.converged, isTrue, reason: 'seed $seed');
      final (continuity, energy) = residuals(net, r);
      expect(continuity, lessThan(1e-3), reason: 'seed $seed continuity');
      expect(energy, lessThan(1e-2), reason: 'seed $seed head loss');
    }
    expect(iterations / 300, lessThan(25), reason: 'a handful of Newton steps, not hundreds');
  });
}
