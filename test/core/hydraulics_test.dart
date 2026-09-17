import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/hydraulics/uniformity.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  group('friction', () {
    test('Hazen-Williams matches textbook value', () {
      // 100 m of 50 mm pipe, C=150, Q = 2 L/s -> J ≈ 0.0329 m/m
      final hf = hazenWilliamsLoss(flow: 0.002, diameter: 0.05, length: 100, c: 150);
      expect(hf, closeTo(2.17, 0.05));
    });
    test('Darcy-Weisbach agrees with Hazen-Williams for smooth PVC', () {
      final hw = hazenWilliamsLoss(flow: 0.002, diameter: 0.05, length: 100, c: 150);
      final dw = darcyWeisbachLoss(flow: 0.002, diameter: 0.05, length: 100, roughness: 1.5e-6);
      expect((hw - dw).abs() / hw, lessThan(0.12));
    });
    test('laminar friction factor', () {
      expect(darcyFrictionFactor(reynolds: 1000, relRoughness: 0), closeTo(0.064, 1e-9));
    });
    test('Swamee-Jain close to Colebrook', () {
      final sj = swameeJain(reynolds: 1e5, relRoughness: 1e-4);
      final cb = colebrook(reynolds: 1e5, relRoughness: 1e-4);
      expect((sj - cb).abs() / cb, lessThan(0.01));
    });
    test('transitional regime is continuous', () {
      final f1 = darcyFrictionFactor(reynolds: 1999.9, relRoughness: 1e-4);
      final f2 = darcyFrictionFactor(reynolds: 2000.1, relRoughness: 1e-4);
      final f3 = darcyFrictionFactor(reynolds: 3999.9, relRoughness: 1e-4);
      final f4 = darcyFrictionFactor(reynolds: 4000.1, relRoughness: 1e-4);
      expect((f1 - f2).abs(), lessThan(0.002));
      expect((f3 - f4).abs(), lessThan(0.002));
    });
    test('transitional cubic matches the turbulent slope at Re = 4000 (EPANET)', () {
      // Dunlop's polynomial evaluated with y2, y3 at Re = 4000 gives the same
      // value and derivative as Swamee-Jain there; with y2 at the actual Re
      // the slopes differ by an order of magnitude.
      for (final rr in [1e-5, 1e-4, 1e-3]) {
        final below = (darcyFrictionFactor(reynolds: 4000, relRoughness: rr) - darcyFrictionFactor(reynolds: 3999.99, relRoughness: rr)) / 0.01;
        final above = (darcyFrictionFactor(reynolds: 4000.01, relRoughness: rr) - darcyFrictionFactor(reynolds: 4000, relRoughness: rr)) / 0.01;
        expect(below, closeTo(above, above.abs() * 0.01), reason: 'ε/D = $rr');
      }
      expect(darcyFrictionFactor(reynolds: 2000, relRoughness: 1e-3), closeTo(0.032, 1e-6));
      expect(darcyFrictionFactor(reynolds: 4000, relRoughness: 1e-3), closeTo(swameeJain(reynolds: 4000, relRoughness: 1e-3), 1e-9));
    });
    test('Christiansen F factor table values', () {
      expect(christiansenF(outlets: 1, m: 1.852), closeTo(1.0, 0.01));
      expect(christiansenF(outlets: 10, m: 1.852), closeTo(0.402, 0.005));
      expect(christiansenF(outlets: 100, m: 1.852), closeTo(0.356, 0.005));
      expect(christiansenF(outlets: 20, m: 1.852, firstOutletAtHalfSpacing: true), closeTo(0.36, 0.01));
    });
    test('Scaloppi adjustment reduces to F when r=1', () {
      expect(scaloppiF(outlets: 30, r: 1), closeTo(christiansenF(outlets: 30), 1e-12));
    });
    test('equivalent diameter of parallel laterals', () {
      expect(equivalentDiameterParallel(0.016, 10) * 1000, closeTo(38.4, 0.3));
    });
  });

  group('emitter', () {
    test('power law and inverse', () {
      final e = EmitterCurve.fromNominal(flow: 4 * m3sPerLph, head: 10, x: 0.5);
      expect(e.flow(10) / m3sPerLph, closeTo(4, 1e-9));
      expect(e.headForFlow(4 * m3sPerLph), closeTo(10, 1e-6));
      final (lo, hi) = e.headWindow(10, below: 0.05, above: 0.05);
      expect(lo, closeTo(9.025, 1e-3));
      expect(hi, closeTo(11.025, 1e-3));
    });
    test('fit recovers exponent', () {
      final e = EmitterCurve.fit([(10, 2.0), (20, 2.83), (30, 3.46)]);
      expect(e.x, closeTo(0.5, 0.02));
    });
    test('precipitation rate', () {
      final pr = precipitationRate(flow: 1000 * m3sPerLph, spacingAlong: 10, spacingBetween: 10);
      expect(precipitationMmPerHour(pr), closeTo(10, 1e-6));
    });
    test('head-to-head overlap gives high CU', () {
      expect(gridOverlapCU(radius: 10, spacingAlong: 10, spacingBetween: 10), greaterThan(80));
      expect(gridOverlapCU(radius: 10, spacingAlong: 18, spacingBetween: 18), lessThan(70));
    });
  });

  group('uniformity', () {
    test('perfectly uniform flows', () {
      final s = UniformityStats.compute(List.filled(20, 4.0), manufacturerCv: 0.0);
      expect(s.cu, closeTo(100, 1e-9));
      expect(s.du, closeTo(100, 1e-9));
      expect(s.eu, closeTo(100, 1e-9));
    });
    test('known spread', () {
      final s = UniformityStats.compute([3.6, 3.8, 4.0, 4.2, 4.4], manufacturerCv: 0.03, emittersPerPlant: 1);
      expect(s.mean, closeTo(4.0, 1e-9));
      expect(s.cu, closeTo(94, 0.1));
      expect(s.qvar, closeTo(18.18, 0.1));
      expect(s.eu, lessThan(s.du));
    });
  });

  group('pump', () {
    test('quadratic fit through points', () {
      final p = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]);
      expect(p.head(0), closeTo(50, 1e-6));
      expect(p.head(0.02), closeTo(30, 1e-6));
      expect(p.runoutFlow, greaterThan(0.02));
    });
    test('operating point', () {
      final p = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]);
      final s = const SystemCurve(staticHead: 20, k: 30000, n: 2);
      final op = operatingPoint(p, s, qMax: 0.05)!;
      expect(p.head(op.$1), closeTo(s.head(op.$1), 1e-6));
    });
    test('capital recovery factor', () {
      expect(capitalRecoveryFactor(0.1, 10), closeTo(0.1627, 1e-3));
    });
  });

  group('minor losses and water hammer', () {
    test('K to flow form', () {
      final m = minorLossFlowCoefficient(k: 1, diameter: 0.1);
      final h = minorLoss(k: 1, flow: 0.01, diameter: 0.1);
      expect(m * 0.01 * 0.01, closeTo(h, 1e-12));
    });
    test('device curve fit', () {
      final d = DeviceLossCurve.fit([(0.001, 1.0), (0.002, 4.0), (0.004, 16.0)]);
      expect(d.n, closeTo(2, 1e-6));
    });
    test('PVC celerity in expected range', () {
      final a = waveCelerity(diameter: 0.1, wallThickness: 0.004, material: PipeMaterial.pvc);
      expect(a, inInclusiveRange(300, 600));
      expect(joukowskySurgeHead(celerity: a, velocityChange: 1.5), greaterThan(50));
    });
  });

  group('units', () {
    test('round trip', () {
      const u = Units.us;
      expect(u.flowFromSi(u.flowToSi(10)), closeTo(10, 1e-9));
      expect(u.pressureFromHead(u.pressureToHead(30)), closeTo(30, 1e-9));
      expect(Units.metric.pressureFromHead(10), closeTo(10, 1e-9));
      expect(Units.us.pressureFromHead(10), closeTo(14.22, 0.01));
    });
    test('fmt never prints scientific notation in reports', () {
      expect(fmt(1.5e6, 0), '1500000');
      expect(fmt(1234567.891), '1234567.89');
      expect(fmt(3e-5), '0.00');
      expect(fmt(3e-5, 6), '0.000030');
      expect(fmt(-1e-15), '0.00'); // rounding residue is not "-0.00"
      expect(fmt(-0.004, 2), '0.00');
      expect(fmt(-0.006, 2), '-0.01');
      expect(fmt(0), '0.00');
      expect(fmt(12.345, 1), '12.3');
      expect(fmt(double.nan), '-');
      expect(fmt(double.infinity), '∞');
      expect(fmt(5e-5).contains('e'), isFalse);
    });
  });
}
