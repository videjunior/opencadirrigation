import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/on_demand.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';

/// The network of FAO Irrigation and Drainage Paper 59, Box 1 and Table 2:
/// 24 sections, 19 hydrants of 10 L/s serving 3 ha each.
const _sections = [
  (1, 0, 1, 19, 60), (2, 1, 2, 18, 60), (3, 2, 3, 17, 50), (4, 3, 4, 16, 50), (5, 4, 5, 15, 50), (6, 5, 6, 14, 50), (7, 6, 7, 11, 40), (8, 7, 8, 8, 40),
  (9, 8, 9, 7, 40), (10, 9, 10, 6, 40), (11, 10, 11, 5, 40), (12, 11, 12, 5, 40), (13, 12, 13, 4, 40), (14, 13, 14, 3, 30), (15, 14, 15, 2, 20), (16, 15, 16, 1, 10),
  (17, 7, 17, 3, 30), (18, 17, 18, 3, 30), (19, 18, 19, 2, 20), (20, 19, 20, 1, 10), (21, 6, 21, 3, 30), (22, 21, 22, 2, 20), (23, 22, 23, 1, 10), (24, 8, 24, 1, 10),
];
const _hydrantNodes = [1, 2, 3, 4, 5, 9, 10, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24];

HydraulicNetwork _fao59({double head = 80}) {
  final net = HydraulicNetwork();
  net.addNode(HNode(id: 'n0', kind: HNodeKind.reservoir, fixedHead: head));
  for (var i = 1; i <= 24; i++) {
    net.addNode(HNode(id: 'n$i'));
  }
  for (final (s, a, b, _, _) in _sections) {
    net.addLink(HLink(id: 's$s', from: 'n$a', to: 'n$b', diameter: 0.25, length: 200, hazenC: 140));
  }
  return net;
}

void main() {
  group('normal quantile (AS 241)', () {
    test('matches reference quantiles', () {
      const ref = [
        (0.5, 0.0), (0.9, 1.2815515655446006), (0.95, 1.6448536269514715), (0.975, 1.9599639845400534), (0.99, 2.3263478740408408), (0.999, 3.090232306167813),
        (1e-10, -6.361340902404057), (0.02, -2.0537489106318225), (0.3, -0.5244005127080408),
      ];
      for (final (p, u) in ref) {
        expect(normalQuantile(p), closeTo(u, 1e-12), reason: 'p = $p');
      }
      expect(normalQuantile(0), double.negativeInfinity);
      expect(normalQuantile(1), double.infinity);
    });
  });

  group('MRG32k3a', () {
    test('reference sequence from the all-12345 state', () {
      final r = Mrg32k3a.fromState(List.filled(6, 12345));
      expect(r.nextDouble(), closeTo(0.12701112204657714, 1e-15));
      expect(r.nextDouble(), closeTo(0.3185275653967945, 1e-15));
      expect(r.nextDouble(), closeTo(0.3091860155832701, 1e-15));
    });

    test('seeded: reproducible, uniform, different seeds differ', () {
      final a = Mrg32k3a(1), b = Mrg32k3a(1), c = Mrg32k3a(2);
      expect(a.nextDouble(), closeTo(0.45917150087367564, 1e-15));
      final xs = [for (var i = 0; i < 20000; i++) b.nextDouble()];
      final again = Mrg32k3a(1)..nextDouble();
      expect(again.nextDouble(), xs[1]);
      final mean = xs.fold(0.0, (s, x) => s + x) / xs.length;
      final variance = xs.fold(0.0, (s, x) => s + (x - mean) * (x - mean)) / xs.length;
      expect(mean, closeTo(0.5, 0.01));
      expect(variance, closeTo(1 / 12, 0.003));
      expect(xs.every((x) => x > 0 && x < 1), isTrue);
      expect(c.nextDouble(), isNot(closeTo(0.45917150087367564, 1e-6)));
      final ints = Mrg32k3a(7);
      final counts = List.filled(5, 0);
      for (var i = 0; i < 5000; i++) {
        counts[ints.nextInt(5)]++;
      }
      expect(counts.every((n) => n > 900 && n < 1100), isTrue);
    });
  });

  group('Clément flows', () {
    test('FAO 59 Box 1 / Table 2: every section', () {
      final hydrants = [for (final n in _hydrantNodes) Hydrant(id: 'h$n', nodeId: 'n$n', discharge: 0.010, areaHa: 3)];
      final r = clementFlows(_fao59(), hydrants, options: const ClementOptions(u: 1.645, utilisation: 0.667, specificContinuousFlow: 0.327e-3, minSimultaneous: 4));
      // d = 10 L/s is 10.2 times the duty q_s·A = 0.981 L/s, above the 6–8
      // FAO 59 recommends at most: an informative code for every hydrant
      expect(r.codes, [for (final n in _hydrantNodes) 'clement_high_freedom:h$n']);
      // p = qs·A/(r·d) = 0.327·3/(0.667·10) = 0.147
      expect(r.probabilities['h1'], closeTo(0.147, 5e-4));
      for (final (s, _, _, n, q) in _sections) {
        final f = r.flows['s$s']!;
        expect(f.hydrants, n, reason: 'section $s');
        expect(f.flow * 1000, closeTo(q, 1e-9), reason: 'section $s');
      }
      // Box 1: N(0-1) = 5.33 hydrants, rounded up to 6
      final s1 = r.flows['s1']!;
      expect(s1.formulaFlow / 0.010, closeTo(5.33, 0.01));
      expect(s1.rule, ClementRule.formula);
      expect(r.flows['s8']!.rule, ClementRule.minimumOpen);
      expect(r.flows['s16']!.rule, ClementRule.allOpen);
      expect(r.sourceFlow['n0']! * 1000, closeTo(60, 1e-9));
      // elasticity e_R = Q / (qs·A) = 60 / (0.327·57)
      expect(r.elasticity, closeTo(60 / (0.327 * 57), 1e-9));
      // the exact quantile gives the same table
      final exact = clementFlows(_fao59(), hydrants, options: const ClementOptions(operatingQuality: 0.95, utilisation: 0.667, specificContinuousFlow: 0.327e-3));
      for (final (s, _, _, _, q) in _sections) {
        expect(exact.flows['s$s']!.flow * 1000, closeTo(q, 1e-9));
      }
      final back = ClementResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.flows['s7']!.flow, r.flows['s7']!.flow);
      expect(back.flows['s7']!.rule, r.flows['s7']!.rule);
    });

    test('unequal hydrants: the formula without rounding, and the extremity rules', () {
      final net = HydraulicNetwork()
        ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50))
        ..addNode(HNode(id: 'J'));
      net.addLink(HLink(id: 'a', from: 'R', to: 'J', diameter: 0.2, length: 100));
      final ds = [0.005, 0.005, 0.010, 0.010, 0.020, 0.020];
      final hydrants = [for (var i = 0; i < ds.length; i++) Hydrant(id: 'h$i', nodeId: 'J', discharge: ds[i], probability: 0.2)];
      final mean = 0.2 * ds.fold(0.0, (s, d) => s + d);
      final sd = math.sqrt(ds.fold(0.0, (s, d) => s + 0.2 * 0.8 * d * d));
      final f = clementFlows(net, hydrants, options: const ClementOptions(u: 1.645, minSimultaneous: 1)).flows['a']!;
      expect(f.meanFlow, closeTo(mean, 1e-12));
      expect(f.stdFlow, closeTo(sd, 1e-12));
      expect(f.flow, closeTo(mean + 1.645 * sd, 1e-12));
      expect(f.rule, ClementRule.formula);
      // N_min = 2: at least the two largest (40 L/s)
      final two = clementFlows(net, hydrants, options: const ClementOptions(u: 1.645, minSimultaneous: 2)).flows['a']!;
      expect(two.flow, closeTo(0.040, 1e-12));
      expect(two.rule, ClementRule.minimumOpen);
      // N_min = 6: every hydrant
      expect(clementFlows(net, hydrants, options: const ClementOptions(minSimultaneous: 6)).flows['a']!.flow, closeTo(0.070, 1e-12));
    });

    test('probabilities from hours, the head each hydrant needs, codes', () {
      final net = HydraulicNetwork()
        ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 60))
        ..addNode(HNode(id: 'J1', elevation: 5))
        ..addNode(HNode(id: 'J2', elevation: 10));
      net.addLink(HLink(id: 'a', from: 'R', to: 'J1', diameter: 0.15, length: 300, hazenC: 140));
      net.addLink(HLink(id: 'b', from: 'J2', to: 'J1', diameter: 0.10, length: 200, hazenC: 140));
      final r = clementFlows(net, const [
        Hydrant(id: 'h1', nodeId: 'J1', discharge: 0.010, hoursPerDay: 12, minPressure: 25),
        Hydrant(id: 'h2', nodeId: 'J2', discharge: 0.010, hoursPerDay: 30, minPressure: 20),
        Hydrant(id: 'hx', nodeId: 'nowhere', discharge: 0.01),
      ], options: const ClementOptions(utilisation: 0.75));
      expect(r.probabilities['h1'], closeTo(12 / 18, 1e-12));
      expect(r.probabilities['h2'], 1);
      expect(r.codes, containsAll(['clement_probability_over_one:h2', 'clement_unknown_node:hx']));
      // two hydrants (≤ N_min): sums
      expect(r.flows['a']!.flow, closeTo(0.020, 1e-12));
      expect(r.flows['b']!.flow, closeTo(0.010, 1e-12));
      expect(r.flows['b']!.downstreamNode, 'J2');
      final ha = hazenWilliamsLoss(flow: 0.020, diameter: 0.15, length: 300, c: 140);
      final hb = hazenWilliamsLoss(flow: 0.010, diameter: 0.10, length: 200, c: 140);
      expect(r.requiredHead['h1'], closeTo(5 + 25 + ha, 1e-9));
      expect(r.requiredHead['h2'], closeTo(10 + 20 + ha + hb, 1e-9));
      expect(r.sourceRequiredHead['R'], closeTo(10 + 20 + ha + hb, 1e-9));
      expect(r.criticalHydrant, 'h2');
    });

    test('a loop is reported and left out', () {
      final net = HydraulicNetwork()
        ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50))
        ..addNode(HNode(id: 'A'))
        ..addNode(HNode(id: 'B'));
      net.addLink(HLink(id: 'ra', from: 'R', to: 'A'));
      net.addLink(HLink(id: 'rb', from: 'R', to: 'B'));
      net.addLink(HLink(id: 'ab', from: 'A', to: 'B'));
      final r = clementFlows(net, const [Hydrant(id: 'h', nodeId: 'B', discharge: 0.01, probability: 0.5)]);
      expect(r.codes, contains('clement_looped:ab'));
      expect(r.flows.containsKey('ab'), isFalse);
      expect(r.flows['rb']!.flow, closeTo(0.01, 1e-12));
    });
  });

  group('random configurations', () {
    /// A at the source level is always fine, B 40 m up never gets 20 m.
    HydraulicNetwork twoHydrants() {
      final net = HydraulicNetwork()
        ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50))
        ..addNode(HNode(id: 'A'))
        ..addNode(HNode(id: 'B', elevation: 40));
      net.addLink(HLink(id: 'a', from: 'R', to: 'A', diameter: 0.1, length: 100, hazenC: 140));
      net.addLink(HLink(id: 'b', from: 'A', to: 'B', diameter: 0.1, length: 100, hazenC: 140));
      return net;
    }

    const hydrants = [Hydrant(id: 'hA', nodeId: 'A', discharge: 0.005, probability: 0.5), Hydrant(id: 'hB', nodeId: 'B', discharge: 0.005, probability: 0.5)];

    test('one hydrant per configuration: reliability, relative deficit, PUH', () {
      final net = twoHydrants();
      final r = checkRandomConfigurations(net, hydrants, options: const RandomCheckOptions(configurations: 100, upstreamDischarge: 0.005, seed: 3));
      final a = r.hydrants[0], b = r.hydrants[1];
      expect(r.configurations, 100);
      expect(a.open + b.open, 100);
      expect(r.meanOpen, 1);
      expect(r.meanDischarge, closeTo(0.005, 1e-15));
      expect(a.reliability, 1);
      expect(b.reliability, 0);
      expect(r.satisfiedConfigurations, a.open);
      expect(r.maxUnsatisfied, 1);
      // A alone open: 50 − hf(5 L/s) over 20 m
      final pa = 50 - hazenWilliamsLoss(flow: 0.005, diameter: 0.1, length: 100, c: 140);
      expect(a.minRelative, closeTo((pa - 20) / 20, 1e-6));
      expect(a.maxRelative, closeTo((pa - 20) / 20, 1e-6));
      final pb = 10 - 2 * hazenWilliamsLoss(flow: 0.005, diameter: 0.1, length: 100, c: 140);
      expect(b.maxDeficit, closeTo(20 - pb, 1e-6));
      expect(b.meanRelative, closeTo((pb - 20) / 20, 1e-6));
      // reproducible, and the network is left as it was
      final again = checkRandomConfigurations(net, hydrants, options: const RandomCheckOptions(configurations: 100, upstreamDischarge: 0.005, seed: 3));
      expect(again.hydrants[0].open, a.open);
      expect(net.nodes['A']!.demand, 0);
      final other = checkRandomConfigurations(net, hydrants, options: const RandomCheckOptions(configurations: 100, upstreamDischarge: 0.005, seed: 4));
      expect(other.hydrants[0].open + other.hydrants[1].open, 100);
      final back = RandomCheckResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.hydrants[1].reliability, 0);
      expect(back.satisfiedConfigurations, r.satisfiedConfigurations);
    });

    test('fixed discharge with equal hydrants opens Q/d of them', () {
      final net = _fao59();
      final hyd = [for (final n in _hydrantNodes) Hydrant(id: 'h$n', nodeId: 'n$n', discharge: 0.010, minPressure: 20)];
      final r = checkRandomConfigurations(net, hyd, options: const RandomCheckOptions(configurations: 40, upstreamDischarge: 0.050));
      expect(r.meanOpen, 5);
      expect(r.meanDischarge, closeTo(0.050, 1e-12));
      expect(r.hydrants.fold(0, (s, h) => s + h.open), 200);
      // a generous source: everything satisfied
      expect(r.satisfiedShare, 1);
      expect(r.hydrants.every((h) => h.reliability == 1), isTrue);
    });

    test('independent draws follow the probabilities', () {
      final r = checkRandomConfigurations(twoHydrants(), hydrants, options: const RandomCheckOptions(configurations: 2000, seed: 11), probabilities: const {'hA': 1, 'hB': 0.25});
      expect(r.hydrants[0].open, 2000);
      expect(r.hydrants[1].open / 2000, closeTo(0.25, 0.03));
      expect(r.configurations, 2000);
    });

    test('flow-limited hydrants deliver like an orifice below H_min', () {
      final net = twoHydrants();
      final r = checkRandomConfigurations(net, const [Hydrant(id: 'hB', nodeId: 'B', discharge: 0.005, probability: 1)], options: const RandomCheckOptions(configurations: 5, flowLimited: true));
      // p = 10 − hf_a(q) − hf_b(q), q = d·√(p/20): bisection on p
      double residual(double p) {
        final q = 0.005 * math.sqrt(p / 20);
        return 10 - 2 * hazenWilliamsLoss(flow: q, diameter: 0.1, length: 100, c: 140) - p;
      }

      var lo = 0.0, hi = 10.0;
      for (var i = 0; i < 80; i++) {
        final mid = (lo + hi) / 2;
        if (residual(mid) > 0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      final p = (lo + hi) / 2;
      final h = r.hydrants.single;
      expect(h.deliveredShare, closeTo(math.sqrt(p / 20), 1e-3));
      expect(h.maxDeficit, closeTo(20 - p, 1e-2));
      expect(h.reliability, 0);
    });

    test('codes for unknown nodes and a discharge above every hydrant', () {
      final r = checkRandomConfigurations(twoHydrants(), [...hydrants, const Hydrant(id: 'hx', nodeId: 'X', discharge: 0.01)], options: const RandomCheckOptions(configurations: 3, upstreamDischarge: 1));
      expect(r.codes, containsAll(['random_unknown_node:hx', 'random_discharge_above_total']));
      expect(r.meanOpen, 2);
      expect(checkRandomConfigurations(twoHydrants(), const []).codes, ['random_no_hydrants']);
    });
  });

  test('percentile is linear between order statistics', () {
    expect(percentile([1, 2, 3, 4, 5], 0.5), 3);
    expect(percentile([1, 2, 3, 4, 5], 0.1), closeTo(1.4, 1e-12));
    expect(percentile([], 0.5), 0);
    expect(percentile([7], 0.9), 7);
  });
}
