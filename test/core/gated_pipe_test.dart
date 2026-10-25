import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/gated_pipe.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  test('level pipe without friction: every gate sees the inlet head and gets the same opening', () {
    final r = designGatedPipe(const GatedPipeSpec(outlets: 10, outletSpacingM: 0.76, targetFlow: 0.0015, pipeInnerMm: 2000, inletHeadM: 0.3));
    final area = 0.0015 / (0.61 * math.sqrt(2 * gravity * 0.3));
    for (final g in r.gates) {
      expect(g.headM, closeTo(0.3, 1e-6));
      expect(g.areaMm2, closeTo(area * 1e6, 1e-3));
      expect(g.diameterMm, closeTo(math.sqrt(4 * area / math.pi) * 1000, 1e-4));
    }
    expect(r.totalFlow, closeTo(0.015, 1e-15));
    expect(r.gates.first.pipeFlow, closeTo(0.015, 1e-15));
    expect(r.gates.last.pipeFlow, closeTo(0.0015, 1e-15));
    expect(r.gates.first.distanceM, closeTo(0.38, 1e-12));
  });

  test('friction and slope along the pipe, outlet by outlet', () {
    const s = GatedPipeSpec(outlets: 3, outletSpacingM: 10, targetFlow: 0.002, firstOutletM: 10, pipeInnerMm: 100, hazenC: 140, slope: 0.002, inletHeadM: 1.0);
    final r = designGatedPipe(s);
    double hf(double q, double l) => hazenWilliamsLoss(flow: q, diameter: 0.1, length: l, c: 140);
    final h1 = 1.0 + 0.02 - hf(0.006, 10);
    final h2 = h1 + 0.02 - hf(0.004, 10);
    final h3 = h2 + 0.02 - hf(0.002, 10);
    expect(r.gates[0].headM, closeTo(h1, 1e-12));
    expect(r.gates[1].headM, closeTo(h2, 1e-12));
    expect(r.gates[2].headM, closeTo(h3, 1e-12));
    expect(r.frictionLossM, closeTo(hf(0.006, 10) + hf(0.004, 10) + hf(0.002, 10), 1e-12));
    expect(r.elevationGainM, closeTo(0.06, 1e-12));
    // the hole is the smallest standard one large enough, partly closed
    for (final g in r.gates) {
      final a = 0.002 / (0.61 * math.sqrt(2 * gravity * g.headM));
      final hole = standardGateHolesMm.firstWhere((d) => math.pi / 4 * math.pow(d / 1000, 2) >= a);
      expect(g.holeMm, hole);
      expect(g.openingPct, closeTo(100 * a / (math.pi / 4 * math.pow(hole / 1000, 2)), 1e-9));
      expect(g.fullFlow, greaterThanOrEqualTo(0.002 - 1e-12));
    }
    expect(r.inletVelocity, closeTo(velocity(flow: 0.006, diameter: 0.1), 1e-12));
  });

  test('minimum inlet head: the critical gate passes its target through the largest hole', () {
    const s = GatedPipeSpec(outlets: 40, outletSpacingM: 1, targetFlow: 0.0012, pipeInnerMm: 150, slope: -0.001);
    final r = designGatedPipe(s);
    final aMax = math.pi / 4 * math.pow(0.0508, 2);
    final hNeed = math.pow(0.0012 / (0.61 * aMax), 2) / (2 * gravity);
    final critical = r.gates.reduce((a, b) => a.headM < b.headM ? a : b);
    expect(critical.headM, closeTo(hNeed, 1e-9));
    expect(critical.holeMm, 50.8);
    expect(critical.openingPct, closeTo(100, 1e-6));
    expect(r.inletHeadM, closeTo(r.minInletHeadM, 1e-12));
    expect(r.inletHeadOk, isTrue);
    // uphill pipe: the last gate is the critical one
    expect(critical.index, 40);
  });

  test('messages for a low inlet head and for holes too small', () {
    const base = GatedPipeSpec(outlets: 20, outletSpacingM: 1, targetFlow: 0.0012, pipeInnerMm: 150);
    final ok = designGatedPipe(base);
    final low = designGatedPipe(GatedPipeSpec(outlets: 20, outletSpacingM: 1, targetFlow: 0.0012, pipeInnerMm: 150, inletHeadM: ok.minInletHeadM * 0.8), id: 'gp');
    expect(low.warnings, containsAll(['gated_pipe_low_head:gp', 'gated_pipe_hole_too_small:gp']));
    expect(low.inletHeadOk, isFalse);
    expect(low.gates.last.holeMm, 0);
    final dry = designGatedPipe(const GatedPipeSpec(outlets: 5, outletSpacingM: 10, targetFlow: 0.001, pipeInnerMm: 100, slope: -0.05, inletHeadM: 0.5));
    expect(dry.warnings, contains('gated_pipe_no_head'));
    final none = designGatedPipe(const GatedPipeSpec(outlets: 5, outletSpacingM: 1, targetFlow: 0.001, holeDiametersMm: []));
    expect(none.warnings, contains('gated_pipe_no_holes'));
  });

  test('per-gate targets and JSON round trip', () {
    final r = designGatedPipe(const GatedPipeSpec(outlets: 3, outletSpacingM: 1, targetFlow: 0.001, targetFlows: [0.002, 0.0005], pipeInnerMm: 200, inletHeadM: 0.4));
    expect(r.gates.map((g) => g.targetFlow).toList(), [0.002, 0.0005, 0.001]);
    expect(r.totalFlow, closeTo(0.0035, 1e-15));
    final back = GatedPipeResult.fromJson(r.toJson());
    expect(back.gates.length, 3);
    expect(back.gates[1].areaMm2, closeTo(r.gates[1].areaMm2, 1e-9));
    expect(back.minInletHeadM, closeTo(r.minInletHeadM, 1e-12));
  });
}
