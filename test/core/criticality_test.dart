import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/criticality.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';

/// Root of f on [lo, hi] by bisection (f(lo) > 0 > f(hi)).
double _root(double Function(double) f, double lo, double hi) {
  for (var i = 0; i < 100; i++) {
    final m = (lo + hi) / 2;
    if (f(m) > 0) {
      lo = m;
    } else {
      hi = m;
    }
  }
  return (lo + hi) / 2;
}

double _hf(double q, double d, double l, [double c = 140]) => hazenWilliamsLoss(flow: q, diameter: d, length: l, c: c);

void main() {
  test('copyNetwork is deep and filters nodes and links', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30))
      ..addNode(HNode(id: 'A', demand: 0.001, emitter: const EmitterCurve(k: 1e-4, x: 0.5)))
      ..addNode(HNode(id: 'B', demand: 0.002));
    net.addLink(HLink(id: 'a', from: 'R', to: 'A', diameter: 0.1, length: 50, hazenC: 130));
    net.addLink(HLink(id: 'b', from: 'A', to: 'B'));
    final c = copyNetwork(net);
    c.nodes['A']!.demand = 9;
    c.links.first.hazenC = 1;
    expect(net.nodes['A']!.demand, 0.001);
    expect(net.links.first.hazenC, 130);
    expect(c.nodes['A']!.emitter, net.nodes['A']!.emitter);
    final part = copyNetwork(net, keepNodes: {'R', 'A'});
    expect(part.nodes.keys, ['R', 'A']);
    expect(part.links.map((l) => l.id), ['a']);
    expect(copyNetwork(net, keepLink: (l) => l.id != 'a').links.map((l) => l.id), ['b']);
    expect(nodesReachingSource(net), {'R', 'A', 'B'});
    expect(nodesReachingSource(net, removed: {'b'}), {'R', 'A'});
  });

  test('pressure-driven demand: full above the requirement, orifice below', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30))
      ..addNode(HNode(id: 'J', elevation: 10, demand: 0.0005));
    net.addLink(HLink(id: 'p', from: 'R', to: 'J', diameter: 0.05, length: 200, hazenC: 140));
    // with the full 4 L/s on top of 0.5 L/s the pressure falls to 20 − hf(4.5) < 15
    expect(20 - _hf(0.0045, 0.05, 200), lessThan(15));
    final r = solvePressureDriven(net, const [PressureDemand(nodeId: 'J', demand: 0.004, requiredPressure: 15)]);
    final p = _root((p) => 20 - _hf(0.0005 + 0.004 * math.sqrt(p / 15), 0.05, 200) - p, 0, 20);
    expect(r.reduced, {'J'});
    expect(r.result.nodes['J']!.pressure, closeTo(p, 1e-3));
    expect(r.delivered['J'], closeTo(0.004 * math.sqrt(p / 15), 1e-6));
    expect(r.unmet, closeTo(0.004 - 0.004 * math.sqrt(p / 15), 1e-6));
    expect(r.settled, isTrue);
    // restored
    expect(net.nodes['J']!.demand, 0.0005);
    expect(net.nodes['J']!.emitter, isNull);
    // a small demand is delivered in full
    final ok = solvePressureDriven(net, const [PressureDemand(nodeId: 'J', demand: 0.0005, requiredPressure: 15)]);
    expect(ok.reduced, isEmpty);
    expect(ok.delivered['J'], 0.0005);
    expect(ok.result.nodes['J']!.pressure, closeTo(20 - _hf(0.001, 0.05, 200), 1e-4));
  });

  test('tree: closing a pipe cuts off what is downstream, without a solution', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50))
      ..addNode(HNode(id: 'N1', demand: 0.002))
      ..addNode(HNode(id: 'N2', demand: 0.003))
      ..addNode(HNode(id: 'N3', demand: 0.001));
    net.addLink(HLink(id: 'a', from: 'R', to: 'N1', diameter: 0.1, length: 100));
    net.addLink(HLink(id: 'b', from: 'N1', to: 'N2', diameter: 0.08, length: 100));
    net.addLink(HLink(id: 'c', from: 'N1', to: 'N3', diameter: 0.05, length: 100));
    final r = analyzeCriticality(net, requiredPressure: const {'N1': 20, 'N2': 20, 'N3': 20});
    expect(r.tree, isTrue);
    expect(r.totalDemand, closeTo(0.006, 1e-12));
    final byLink = {for (final s in r.scenarios) s.linkId: s};
    expect(byLink['a']!.cutOffNodes, ['N1', 'N2', 'N3']);
    expect(byLink['a']!.cutOffDemand, closeTo(0.006, 1e-12));
    expect(byLink['b']!.cutOffNodes, ['N2']);
    expect(byLink['c']!.cutOffDemand, closeTo(0.001, 1e-12));
    expect(byLink.values.every((s) => !s.solved && s.deficits.isEmpty && s.unmetDemand == 0), isTrue);
    expect(r.ranked.map((s) => s.linkId), ['a', 'b', 'c']);
    // re-solved instead, the same losses
    final solved = analyzeCriticality(net, requiredPressure: const {'N1': 20, 'N2': 20, 'N3': 20}, treeShortcut: false);
    expect(solved.scenarios.every((s) => s.solved && s.converged), isTrue);
    expect(solved.scenarios.firstWhere((s) => s.linkId == 'b').cutOffDemand, closeTo(0.003, 1e-12));
  });

  test('loop: the other way round keeps the nodes connected, at a lower pressure', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40))
      ..addNode(HNode(id: 'N1', demand: 0.004))
      ..addNode(HNode(id: 'N2', demand: 0.002));
    net.addLink(HLink(id: 'a', from: 'R', to: 'N1', diameter: 0.1, length: 400, hazenC: 140));
    net.addLink(HLink(id: 'b', from: 'N1', to: 'N2', diameter: 0.05, length: 300, hazenC: 140));
    net.addLink(HLink(id: 'c', from: 'R', to: 'N2', diameter: 0.1, length: 600, hazenC: 140));
    final req = {'N1': 30.0, 'N2': 20.0};
    final r = analyzeCriticality(net, requiredPressure: req, linkIds: const ['a', 'zz']);
    expect(r.tree, isFalse);
    expect(r.codes, ['criticality_unknown_link:zz']);
    final s = r.scenarios.single;
    expect(s.cutOffNodes, isEmpty);
    expect(s.solved, isTrue);
    // a closed: R → c → N2 → b → N1, by hand
    final h2 = 40 - _hf(0.006, 0.1, 600);
    final h1 = h2 - _hf(0.004, 0.05, 300);
    expect(h1, lessThan(30));
    final d1 = s.deficits.firstWhere((d) => d.nodeId == 'N1');
    expect(d1.pressure, closeTo(h1, 1e-3));
    expect(d1.deficit, closeTo(30 - h1, 1e-3));
    // the pressure-driven delivery of N1, by hand
    final p1 = _root(
      (p) {
        final q1 = 0.004 * math.sqrt(p / 30);
        final p2 = 40 - _hf(0.002 + q1, 0.1, 600);
        // N2 itself stays above its 20 m here
        return p2 - _hf(q1, 0.05, 300) - p;
      },
      0,
      40,
    );
    expect(s.unmetDemand, closeTo(0.004 - 0.004 * math.sqrt(p1 / 30), 2e-6));
    expect(d1.delivered, closeTo(0.004 * math.sqrt(p1 / 30), 2e-6));
    expect(net.links.length, 3);
    final back = CriticalityResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.scenarios.single.unmetDemand, closeTo(s.unmetDemand, 1e-15));
    expect(back.scenarios.single.deficits.single.nodeId, 'N1');
  });

  test('emitter outflow lost to lower pressures counts as unmet demand', () {
    final net = HydraulicNetwork()
      ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 30))
      ..addNode(HNode(id: 'A'))
      ..addNode(HNode(id: 'E', emitter: EmitterCurve.fromNominal(flow: 0.002, head: 20)));
    net.addLink(HLink(id: 'a1', from: 'R', to: 'A', diameter: 0.1, length: 100));
    net.addLink(HLink(id: 'a2', from: 'R', to: 'A', diameter: 0.1, length: 100));
    net.addLink(HLink(id: 'e', from: 'A', to: 'E', diameter: 0.04, length: 100));
    final r = analyzeCriticality(net, linkIds: const ['a1']);
    final base = net.solve().nodes['E']!.emitterFlow;
    expect(r.totalDemand, closeTo(base, 1e-9));
    final s = r.scenarios.single;
    expect(s.cutOffNodes, isEmpty);
    expect(s.unmetDemand, greaterThan(0));
    expect(s.unmetDemand, lessThan(base * 0.05));
  });
}
