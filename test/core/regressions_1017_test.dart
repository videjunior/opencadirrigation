/// Defects found by the 2026-10-17 sweep, each pinned by a test that fails
/// without its fix (the network solver, the terrain and the densogram have
/// their own files: network_robustness_test, invariance_test,
/// densogram_test).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/lateral.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';

void main() {
  group('curves typed with repeated flows', () {
    test('two pump points at the same flow give a usable curve, not NaN', () {
      // "10@30; 10@25": the 2-point slope was (25 − 30)/0
      final c = PumpCurve.fit([(0.010, 30), (0.010, 25), (0.020, 10)]);
      for (final q in [0.0, 0.005, 0.010, 0.015]) {
        expect(c.head(q).isFinite, isTrue, reason: 'Q $q');
      }
      expect(c.head(0.010), closeTo(27.5, 1e-9), reason: 'the two readings averaged');
      final two = PumpCurve.fit([(0.010, 30), (0.010, 25)]);
      expect(two.head(0.010), closeTo(27.5, 1e-9));
      expect(two.shutoffHead.isFinite, isTrue);
    });

    test('a shutoff head alone gives a flat curve (no endless recursion)', () {
      final c = PumpCurve.fit([(0, 40)]);
      expect(c.head(0), 40);
      expect(c.head(0.01), 40);
    });

    test('a device loss fitted from samples at one flow is a K·Q² law through them', () {
      final d = DeviceLossCurve.fit([(0.004, 2.0), (0.004, 2.2)]);
      expect(d.k.isFinite && d.n.isFinite, isTrue);
      expect(d.loss(0.004), closeTo(2.1, 0.01));
      expect(d.n, 2);
    });
  });

  test('feed positions of a lateral that needs more than 3× the nominal pressure at its inlet', () {
    // 16 mm dripline, 2 L/h every 0.3 m, 360 m: fed at one end it needs an
    // inlet pressure far above 3 × 10 m; the bracket stopped there
    final spec = LateralSpec(length: 360, diameter: 0.0136, spacing: 0.3, emitter: EmitterCurve.fromNominal(flow: 2 / 3.6e6, head: 10, x: 0.5));
    final r = allowableFeedPositions(spec, nominalPressure: 10, minPressure: 5, maxPressure: 15, steps: 3);
    final end = r.first;
    expect(end.inletPressure, greaterThan(30), reason: 'the inlet is not capped at 3 × nominal');
    expect(end.minPressure, lessThan(10));
    expect(end.maxPressure, greaterThan(10));
    expect(end.ok, isFalse, reason: 'such a lateral is far outside the window');
  });
}
