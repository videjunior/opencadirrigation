import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/lateral.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/hydraulics/sparse_solver.dart';
import 'package:opencadirrigation/core/hydraulics/uniformity.dart';
import 'package:opencadirrigation/core/units.dart';

/// Hydraulic helpers not covered by hydraulics_test.dart / network_test.dart:
/// friction utilities, pump curve fits, uniformity classes, check valves,
/// closed links and the solver's degenerate inputs.
void main() {
  group('friction helpers', () {
    test('Hazen-Williams gradient is the loss of one metre and scales with length', () {
      final j = hazenWilliamsGradient(flow: 0.002, diameter: 0.05, c: 150);
      expect(j, closeTo(0.0217, 2e-4));
      expect(hazenWilliamsLoss(flow: 0.002, diameter: 0.05, length: 250, c: 150), closeTo(250 * j, 1e-9));
      // the resistance form hf = r·Q^1.852 gives the same loss
      final r = hazenWilliamsResistance(diameter: 0.05, length: 250, c: 150);
      expect(r * math.pow(0.002, 1.852), closeTo(250 * j, 1e-9));
      // reverse flow keeps the magnitude and flips the sign
      expect(hazenWilliamsGradient(flow: -0.002, diameter: 0.05, c: 150), closeTo(-j, 1e-12));
      expect(hazenWilliamsLoss(flow: 0, diameter: 0.05, length: 100, c: 150), 0);
    });

    test('velocity, flow for a velocity and the Reynolds number', () {
      final v = velocity(flow: 0.002, diameter: 0.05);
      expect(v, closeTo(0.002 / (math.pi * 0.05 * 0.05 / 4), 1e-12));
      expect(flowForVelocity(velocity: v, diameter: 0.05), closeTo(0.002, 1e-15));
      // Re = V·D/ν ≈ 50 700 for 2 L/s in 50 mm at 20 °C
      final re = reynolds(flow: 0.002, diameter: 0.05);
      expect(re, closeTo(v * 0.05 / 1.004e-6, 1e-6));
      expect(re, closeTo(50727, 5));
      expect(reynolds(flow: -0.002, diameter: 0.05), re, reason: 'the direction does not matter');
      expect(reynolds(flow: 0.002, diameter: 0.05, kinematicViscosity: 0.658e-6), greaterThan(re), reason: 'warmer water is less viscous');
    });

    test('Blasius matches Colebrook for smooth pipes below Re = 1e5', () {
      expect(blasius(1e5), closeTo(0.3164 / math.pow(1e5, 0.25), 1e-12));
      expect(blasius(1e5), closeTo(0.01779, 1e-5));
      for (final re in [5e3, 2e4, 1e5]) {
        final cb = colebrook(reynolds: re, relRoughness: 0);
        expect((blasius(re) - cb).abs() / cb, lessThan(0.03), reason: 'Re $re');
      }
    });

    test('frictionLoss dispatches to Hazen-Williams or Darcy-Weisbach', () {
      expect(frictionLoss(method: FrictionMethod.hazenWilliams, flow: 0.003, diameter: 0.06, length: 80, c: 140), closeTo(hazenWilliamsLoss(flow: 0.003, diameter: 0.06, length: 80, c: 140), 1e-12));
      expect(frictionLoss(method: FrictionMethod.darcyWeisbach, flow: 0.003, diameter: 0.06, length: 80, roughness: 7e-6), closeTo(darcyWeisbachLoss(flow: 0.003, diameter: 0.06, length: 80, roughness: 7e-6), 1e-12));
      expect(flowExponent(FrictionMethod.hazenWilliams), 1.852);
      expect(flowExponent(FrictionMethod.darcyWeisbach), inInclusiveRange(1.75, 2.0));
    });

    test('Hazen C converts to the roughness that gives the same Darcy factor (Colebrook)', () {
      const d = 0.1;
      final eps150 = hazenCToRoughness(150, d);
      final eps120 = hazenCToRoughness(120, d);
      final eps100 = hazenCToRoughness(100, d);
      expect(eps150, greaterThanOrEqualTo(0));
      expect(eps120, greaterThan(eps150), reason: 'a lower C is a rougher pipe');
      expect(eps100, greaterThan(eps120));
      // Colebrook with the returned roughness reproduces the HW friction factor at 1 m/s
      final q = flowForVelocity(velocity: 1, diameter: d);
      final f = hazenWilliamsLoss(flow: q, diameter: d, length: 1, c: 120) * 2 * gravity * d;
      expect(colebrook(reynolds: d / 1.004e-6, relRoughness: eps120 / d), closeTo(f, f * 1e-6));
      // and Darcy-Weisbach (Swamee-Jain) then agrees with Hazen-Williams within 2 %
      final dw = darcyWeisbachLoss(flow: q, diameter: d, length: 100, roughness: eps120);
      final hw = hazenWilliamsLoss(flow: q, diameter: d, length: 100, c: 120);
      expect((dw - hw).abs() / hw, lessThan(0.02));
    });
  });

  group('minor losses and devices', () {
    test('equivalent length of a fitting and the single-point device fit', () {
      // K·D/f: a K = 1 fitting in 50 mm pipe equals 2.5 m of pipe at f = 0.02
      expect(equivalentLength(k: 1, diameter: 0.05), closeTo(2.5, 1e-12));
      expect(equivalentLength(k: 1, diameter: 0.05, f: 0.025), closeTo(2.0, 1e-12));
      final one = DeviceLossCurve.fit([(0.002, 3.0)]);
      expect(one.n, 2);
      expect(one.loss(0.002), closeTo(3, 1e-9));
      expect(one.loss(0.004), closeTo(12, 1e-9));
    });
  });

  group('emitters', () {
    test('pressure-compensating flag and triangular sprinkler layouts', () {
      expect(const EmitterCurve(k: 1, x: 0.02).isPressureCompensating, isTrue);
      expect(EmitterCurve.fromNominal(flow: 1, head: 10).isPressureCompensating, isFalse);
      final square = gridOverlapCU(radius: 12, spacingAlong: 12, spacingBetween: 12);
      final triangle = gridOverlapCU(radius: 12, spacingAlong: 12, spacingBetween: 12, triangular: true);
      expect(triangle, isNot(closeTo(square, 1e-6)), reason: 'offset rows change the overlap');
      expect(triangle, inInclusiveRange(60, 100));
      expect(gridOverlapCU(radius: 0, spacingAlong: 12, spacingBetween: 12), 0);
    });
  });

  group('uniformity', () {
    test('ASAE classes by threshold', () {
      expect(UniformityStats.classify(99), 'excellent');
      expect(UniformityStats.classify(94), 'excellent');
      expect(UniformityStats.classify(93.9), 'good');
      expect(UniformityStats.classify(90), 'good');
      expect(UniformityStats.classify(85), 'fair');
      expect(UniformityStats.classify(80), 'fair');
      expect(UniformityStats.classify(75), 'poor');
      expect(UniformityStats.classify(70), 'poor');
      expect(UniformityStats.classify(69.9), 'unacceptable');
    });

    test('empty, non-finite and zero samples; JSON round trip', () {
      expect(UniformityStats.compute(const []).count, 0);
      expect(UniformityStats.compute([double.nan, double.infinity]).count, 0);
      final zeros = UniformityStats.compute([0, 0, 0]);
      expect(zeros.count, 3);
      expect(zeros.cu, 0);
      expect(zeros.qvar, 0);
      final one = UniformityStats.compute([4.0]);
      expect(one.cv, 0, reason: 'a single sample has no spread');
      expect(one.cu, closeTo(100, 1e-9));
      final s = UniformityStats.compute([3.6, 3.8, 4.0, 4.2, 4.4], manufacturerCv: 0.03);
      final back = UniformityStats.fromJson(s.toJson());
      expect(back.count, s.count);
      for (final (a, b) in [(back.mean, s.mean), (back.cu, s.cu), (back.du, s.du), (back.eu, s.eu), (back.us, s.us), (back.qvar, s.qvar), (back.cv, s.cv), (back.min, s.min), (back.max, s.max)]) {
        expect(a, closeTo(b, 1e-12));
      }
      expect(UniformityStats.fromJson(null).count, 0);
      // the low quarter of 8 values is the lowest 2
      final du = UniformityStats.compute([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(du.du, closeTo(100 * 1.5 / 4.5, 1e-9));
    });
  });

  group('pump curves', () {
    test('one point makes the EPANET three-point curve', () {
      final p = PumpCurve.fit([(0.01, 40)]);
      expect(p.head(0), closeTo(1.33 * 40, 1e-6));
      expect(p.head(0.01), closeTo(40, 1e-6));
      expect(p.head(0.02), closeTo(0, 1e-6));
      expect(p.runoutFlow, closeTo(0.02, 1e-6));
      expect(PumpCurve.fit(const []).head(0), 0);
      expect(PumpCurve.fit([(-1, 10), (0.01, -5)]).head(0.5), 0, reason: 'negative samples are ignored');
    });

    test('two points make a straight line whose runout follows the speed', () {
      final p = PumpCurve.fit([(0, 40), (0.01, 20)]);
      expect(p.a, 0);
      expect(p.head(0.005), closeTo(30, 1e-9));
      expect(p.runoutFlow, closeTo(0.02, 1e-12));
      // affinity laws: H(Q) = ω²·Hbase(Q/ω) → at half speed the runout halves
      final half = p.withSpeed(0.5);
      expect(half.head(0), closeTo(10, 1e-9));
      expect(half.runoutFlow, closeTo(0.01, 1e-12));
      expect(half.head(half.runoutFlow), closeTo(0, 1e-9));
      // the quadratic branch agrees
      final q = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]).withSpeed(0.8);
      expect(q.head(q.runoutFlow), closeTo(0, 1e-9));
      expect(const PumpCurve(a: 0, b: 10, c: 5).runoutFlow, double.infinity, reason: 'a rising line never reaches zero head');
    });

    test('JSON round trip keeps the speed ratio; older curves default to full speed', () {
      final p = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]).withSpeed(0.9);
      final back = PumpCurve.fromJson(p.toJson());
      expect(back.speedRatio, 0.9);
      for (final q in [0.0, 0.005, 0.015]) {
        expect(back.head(q), closeTo(p.head(q), 1e-9));
      }
      expect(PumpCurve.fromJson({'a': -1, 'b': 0, 'c': 30}).speedRatio, 1);
    });

    test('operating point: bracket expansion and a pump that cannot lift the static head', () {
      final pump = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]);
      const sys = SystemCurve(staticHead: 20, k: 30000, n: 2);
      // qMax far below the answer: the bracket doubles until it crosses
      final op = operatingPoint(pump, sys, qMax: 1e-4)!;
      expect(pump.head(op.$1), closeTo(sys.head(op.$1), 1e-6));
      expect(op.$1, greaterThan(1e-4));
      expect(operatingPoint(pump, const SystemCurve(staticHead: 80, k: 1000)), isNull);
    });
  });

  group('network: check valves, closed links and degenerate input', () {
    HydraulicNetwork twoTanks({required bool checkValve}) {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'A', kind: HNodeKind.reservoir, fixedHead: 50));
      net.addNode(HNode(id: 'B', kind: HNodeKind.reservoir, fixedHead: 60));
      net.addNode(HNode(id: 'J'));
      net.addLink(HLink(id: 'aj', from: 'A', to: 'J', diameter: 0.05, length: 100, checkValve: checkValve));
      net.addLink(HLink(id: 'jb', from: 'J', to: 'B', diameter: 0.05, length: 100));
      return net;
    }

    test('a check valve stops the reverse flow that an open pipe carries', () {
      final open = twoTanks(checkValve: false).solve();
      expect(open.converged, isTrue);
      expect(open.links['aj']!.flow, lessThan(-1e-4), reason: 'water runs from the higher tank B to A');
      expect(open.links['aj']!.status, LinkStatus.open);
      final checked = twoTanks(checkValve: true).solve();
      expect(checked.converged, isTrue);
      expect(checked.links['aj']!.status, LinkStatus.closed);
      expect(checked.links['aj']!.flow.abs(), lessThan(1e-6));
      expect(checked.nodes['J']!.head, closeTo(60, 1e-3), reason: 'J sits at the head of B');
    });

    test('a check valve reopens when the flow runs forward again', () {
      final net = twoTanks(checkValve: true);
      net.nodes['A']!.fixedHead = 70;
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.links['aj']!.status, LinkStatus.open);
      expect(r.links['aj']!.flow, greaterThan(1e-4));
      expect(r.links['jb']!.flow, closeTo(r.links['aj']!.flow, 1e-9));
    });

    test('a closed link carries nothing; initial flows only change the start', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 50));
      net.addNode(HNode(id: 'R2', kind: HNodeKind.reservoir, fixedHead: 80));
      net.addNode(HNode(id: 'J', demand: 0.001));
      net.addLink(HLink(id: 'p', from: 'R', to: 'J', diameter: 0.05, length: 100));
      net.addLink(HLink(id: 'x', from: 'R2', to: 'J', kind: HLinkKind.closed));
      final r = net.solve();
      expect(r.converged, isTrue);
      expect(r.links['x']!.status, LinkStatus.closed);
      // a closed link is a very large resistance (as in EPANET): a trace of
      // flow under 30 m of head, well below 1 mL/s
      expect(r.links['x']!.flow.abs(), lessThan(1e-6));
      expect(r.links['p']!.flow + r.links['x']!.flow, closeTo(0.001, 1e-9), reason: 'continuity at J');
      expect(r.nodes['J']!.head, closeTo(50 - hazenWilliamsLoss(flow: 0.001, diameter: 0.05, length: 100, c: 150), 1e-3));
      final warm = net.solve(initialFlows: {'p': 0.001, 'x': 0});
      expect(warm.converged, isTrue);
      expect(warm.nodes['J']!.head, closeTo(r.nodes['J']!.head, 1e-6));
      expect(warm.iterations, lessThanOrEqualTo(r.iterations));
    });

    test('a PRV stays open below its setting and closes against a higher downstream head', () {
      final low = HydraulicNetwork();
      low.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 20));
      low.addNode(HNode(id: 'U'));
      low.addNode(HNode(id: 'V'));
      low.addNode(HNode(id: 'D', demand: 0.002));
      low.addLink(HLink(id: 'a', from: 'R', to: 'U', diameter: 0.1, length: 50));
      low.addLink(HLink(id: 'prv', from: 'U', to: 'V', kind: HLinkKind.prv, prvSetting: 30));
      low.addLink(HLink(id: 'b', from: 'V', to: 'D', diameter: 0.05, length: 50));
      final r = low.solve();
      expect(r.converged, isTrue);
      expect(r.links['prv']!.status, LinkStatus.open);
      expect(r.nodes['V']!.pressure, lessThan(20));
      expect(r.links['prv']!.flow, closeTo(0.002, 1e-6));

      final back = HydraulicNetwork();
      back.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 40));
      back.addNode(HNode(id: 'U'));
      back.addNode(HNode(id: 'V'));
      back.addNode(HNode(id: 'T', kind: HNodeKind.reservoir, fixedHead: 70));
      back.addLink(HLink(id: 'a', from: 'R', to: 'U', diameter: 0.1, length: 50));
      back.addLink(HLink(id: 'prv', from: 'U', to: 'V', kind: HLinkKind.prv, prvSetting: 30));
      back.addLink(HLink(id: 'b', from: 'V', to: 'T', diameter: 0.1, length: 50));
      final rb = back.solve();
      expect(rb.links['prv']!.status, LinkStatus.closed);
      expect(rb.links['prv']!.flow.abs(), lessThan(1e-6), reason: 'a PRV does not let water flow backwards');
    });

    test('without any fixed head the solver warns instead of failing', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'a'));
      net.addNode(HNode(id: 'b'));
      net.addLink(HLink(id: 'p', from: 'a', to: 'b'));
      final r = net.solve();
      expect(r.warnings, contains('no_fixed_head_node'));
      expect(r.nodes.keys, containsAll(['a', 'b']));
    });

    test('the sparse solver isolates an unconnected unknown instead of dividing by zero', () {
      final s = SparseSymmetricSystem(3);
      s.addDiagonal(0, 2);
      s.addDiagonal(2, 5);
      s.add(0, 2, -1);
      s.rhs[0] = 1;
      s.rhs[2] = 4;
      final x = s.solve();
      expect(x.every((v) => v.isFinite), isTrue);
      expect(x[1], 0);
      expect(2 * x[0] - x[2], closeTo(1, 1e-9));
      expect(-x[0] + 5 * x[2], closeTo(4, 1e-9));
    });
  });

  group('laterals', () {
    final spec = LateralSpec(length: 100, diameter: 0.0136, spacing: 0.5, emitter: EmitterCurve.fromNominal(flow: 2 * m3sPerLph, head: 10), hazenC: 140);

    test('copyWith changes only what is given', () {
      final c = spec.copyWith(length: 50, endFlow: 1e-4);
      expect(c.length, 50);
      expect(c.endFlow, 1e-4);
      expect(c.diameter, spec.diameter);
      expect(c.spacing, spec.spacing);
      expect(c.outletCount, 100);
      expect(spec.copyWith(diameter: 0.016, spacing: 1).outletCount, 100);
    });

    test('a steep downhill lateral still finds the inlet pressure for a mean pressure', () {
      // 80 m of fall in 100 m: the mean from a guessed end pressure starts
      // below the target and the search has to widen its bracket
      final r = analyzeLateralForMeanPressure(spec, 10, elevationAt: (d) => -0.8 * d);
      expect(r.meanPressure, closeTo(10, 1e-3));
      expect(r.endPressure, greaterThan(r.inletPressure), reason: 'the fall raises the pressure downstream');
    });
  });
}
