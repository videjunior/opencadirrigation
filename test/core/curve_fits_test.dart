import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/curve_fits.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/units.dart';

/// The curves read off a chart, fitted against known curves, and the
/// catalogue entries they make (1.7.0 DGZ).
void main() {
  // H = 40 − 2·10⁴·Q² (Q m³/s): 40 m at shutoff, 22 m at 0.03 m³/s (108 m³/h)
  double head(double q) => 40 - 2e4 * q * q;
  final headPts = [for (var i = 0; i <= 6; i++) (i * 0.005, head(i * 0.005))];

  group('pump', () {
    test('a parabola is found again, its gaps are nil and its range is the chart’s', () {
      final f = fitPumpChart(head: headPts);
      expect(f.curve!.throughPoints, isFalse);
      expect(f.curve!.a, closeTo(-2e4, 1e-6));
      expect(f.curve!.b, closeTo(0, 1e-6));
      expect(f.curve!.c, closeTo(40, 1e-9));
      expect(f.maxGap, lessThan(1e-9));
      expect(f.rmsGap, lessThan(1e-9));
      expect(f.topHead, 40);
    });

    test('a curve with a flat top goes through the points; the gaps are those of the curve', () {
      // flat to 0.01 m³/s, then falling: no parabola stands for it
      final pts = [(0.0, 30.0), (0.005, 30.0), (0.01, 30.0), (0.015, 26.0), (0.02, 18.0), (0.025, 6.0)];
      final f = fitPumpChart(head: pts);
      expect(f.curve!.throughPoints, isTrue);
      expect(f.maxGap, lessThan(1e-9));
    });

    test('the efficiency of a shaft power curve: η = ρgQH/P, by hand at the best point', () {
      // at Q = 0.02 m³/s: H = 32 m; with η = 0.75 the shaft power is
      // 998.2 · 9.80665 · 0.02 · 32 / 0.75 = 8 353.28 W
      final f = fitPumpChart(head: headPts, power: const [(0.0, 3.1), (0.02, 8.35328), (0.01, 5.27806), (0.06, 9.0)]);
      expect(f.efficiencyFromPower, isTrue);
      expect(f.efficiency, hasLength(2), reason: 'no flow at shutoff; 0.06 m³/s is beyond the head curve');
      expect(f.efficiency.last.$2, closeTo(0.75, 1e-5));
      // at 0.01 m³/s: H = 38 m, P = 5.27806 kW → η = 0.705
      expect(f.efficiency.first.$2, closeTo(998.2 * 9.80665 * 0.01 * 38 / 5278.06, 1e-9));
      expect(f.rejectedEfficiency, 1);
      expect(f.bestEfficiency, closeTo(0.75, 1e-5));
      expect(f.maxPowerKw, 9.0);
      // the chart's own efficiency curve wins over the power curve
      final g = fitPumpChart(head: headPts, efficiency: const [(0.01, 0.6), (0.02, 0.7)], power: const [(0.01, 5), (0.02, 8)]);
      expect(g.efficiencyFromPower, isFalse);
      expect(g.efficiency.last.$2, 0.7);
      // an efficiency above 1 (a misread power axis) is left out
      final bad = fitPumpChart(head: headPts, power: const [(0.01, 0.5), (0.02, 0.6)]);
      expect(bad.efficiency, isEmpty);
      expect(bad.rejectedEfficiency, 2);
    });

    test('a click a hair below an axis reads zero; farther below, the point is left out', () {
      expect(cleanChartPoints(const [(-0.0001, 40.0), (0.03, 22.0), (0.01, -5.0)]), [(0.0, 40.0), (0.03, 22.0)]);
      expect(cleanChartPoints(const [(double.nan, 1.0), (1.0, 2.0)]), [(1.0, 2.0)]);
      expect(cleanChartPoints(const [(0.0, 2.0), (1.0, 2.0)], positive: true), [(1.0, 2.0)]);
    });

    test('a new pump from the chart; an existing one updated; the refusals', () {
      final cat = Catalog.defaultCatalog();
      final n = cat.pumps.length;
      final f = fitPumpChart(head: headPts, efficiency: const [(0.005, 0.4), (0.02, 0.74), (0.03, 0.66)], npsh: const [(0.01, 2.0), (0.03, 4.5)], power: const [(0.005, 3.5), (0.03, 9.4)]);
      final p = putPumpChart(cat, f, name: ' Chart pump ');
      expect(cat.pumps, hasLength(n + 1));
      expect(cat.pump(p.id), same(p));
      expect(p.name, 'Chart pump');
      expect(p.points, headPts);
      expect(p.curve.head(0.015), closeTo(head(0.015), 1e-9));
      expect(p.minFlow, 0);
      expect(p.maxFlow, closeTo(0.03, 1e-15));
      expect(p.efficiency, 0.74);
      expect(p.efficiencyAt(0.02), closeTo(0.74, 1e-12));
      expect(p.npshrAt(0.02), closeTo(3.25, 1e-12));
      expect(p.powerKw, 9.4, reason: 'the largest shaft power read');
      // an update: only the curves read change, a rated power stays
      p.powerKw = 11;
      final again = putPumpChart(
        cat,
        fitPumpChart(efficiency: const [(0.01, 0.5), (0.03, 0.7)], power: const [(0.01, 4), (0.03, 10)]),
        pumpId: p.id,
      );
      expect(again, same(p));
      expect(p.points, headPts);
      expect(p.efficiencyPoints, const [(0.01, 0.5), (0.03, 0.7)]);
      expect(p.powerKw, 11);
      expect(cat.pumps, hasLength(n + 1));
      expect(() => putPumpChart(cat, fitPumpChart(head: headPts.take(2).toList()), name: 'x'), throwsA(isA<ChartApplyError>().having((e) => e.code, 'code', 'pump_head')));
      expect(() => putPumpChart(cat, f, pumpId: 'nope'), throwsA(isA<ChartApplyError>().having((e) => e.code, 'code', 'no_item')));
      expect(() => putPumpChart(cat, fitPumpChart(), name: 'x'), throwsA(isA<ChartApplyError>().having((e) => e.code, 'code', 'pump_empty')));
    });
  });

  group('outlet', () {
    // a dripper of 4 L/h at 10 m, x = 0.5: q = 4·√(H/10) L/h
    double q(double h) => 4 * math.sqrt(h / 10) * m3sPerLph;
    final pts = [
      for (final h in [5.0, 10.0, 15.0, 20.0, 30.0]) (h, q(h)),
    ];

    test('q = k·Hˣ is found again; noisy readings land near it', () {
      final f = fitEmitterChart(pts);
      expect(f.isUsable, isTrue);
      expect(f.curve.x, closeTo(0.5, 1e-9));
      expect(f.curve.k, closeTo(4 * m3sPerLph / math.sqrt(10), 1e-15));
      expect(f.fit.maxFlowError, lessThan(1e-9));
      expect(f.gaps.every((g) => g.abs() < 1e-9), isTrue);
      expect((f.minHead, f.maxHead), (5.0, 30.0));
      final noisy = fitEmitterChart([for (var i = 0; i < pts.length; i++) (pts[i].$1, pts[i].$2 * (i.isEven ? 1.02 : 0.98))]);
      expect(noisy.curve.x, closeTo(0.5, 0.05));
      expect(noisy.fit.maxFlowError, closeTo(0.02, 0.012));
      // a pressure-compensating dripper: the exponent near zero
      final pc = fitEmitterChart([
        for (final h in [8.0, 12.0, 20.0, 30.0]) (h, 2.0 * m3sPerLph * math.pow(h / 10, 0.03)),
      ]);
      expect(pc.curve.x, closeTo(0.03, 1e-9));
      expect(fitEmitterChart(const [(10.0, 0.0001)]).isUsable, isFalse, reason: 'one point fits no law');
    });

    test('a new outlet, a nozzle and a tape updated, keeping their radius and compensation', () {
      final cat = Catalog.defaultCatalog();
      final f = fitEmitterChart(pts);
      final o = putNewOutlet(cat, f, name: 'Chart dripper', kind: OutletKind.dripper, nozzleName: '4 L/h');
      expect(cat.outlet(o.id), same(o));
      final nz = o.nozzles.single;
      expect(nz.name, '4 L/h');
      expect(nz.id, '${o.id}_n1');
      expect((nz.minHeadM, nz.maxHeadM, nz.defaultHeadM), (5.0, 30.0, 17.5));
      expect(nz.curve.flow(10) / m3sPerLph, closeTo(4, 1e-9));
      final sprinkler = cat.outlets.firstWhere((x) => x.nozzles.first.curve.radiusA > 0).nozzles.first;
      final ra = sprinkler.curve.radiusA, rb = sprinkler.curve.radiusB;
      putNozzleCurve(sprinkler, f);
      expect((sprinkler.curve.k, sprinkler.curve.x, sprinkler.curve.radiusA, sprinkler.curve.radiusB), (f.curve.k, f.curve.x, ra, rb));
      final tape = cat.tapes.first..emitter = cat.tapes.first.emitter.compensatingFrom(6);
      putTapeEmitter(tape, f);
      expect(tape.emitter.x, closeTo(0.5, 1e-9));
      expect(tape.emitter.compensationHead, 6);
      expect(() => putNewOutlet(cat, fitEmitterChart(const []), name: 'x'), throwsA(isA<ChartApplyError>().having((e) => e.code, 'code', 'emitter_fit')));
    });
  });

  group('profile', () {
    // the catch-can rows of the profile dialog's example (distance m, mm/h)
    const rows = [(0.0, 4.1), (2.0, 4.4), (4.0, 4.0), (6.0, 3.1), (8.0, 1.8), (10.0, 0.6), (11.0, 0.0)];

    test('distance over the wetted radius, rate over its largest value: the densogram’s form', () {
      final f = fitProfileChart(rows);
      expect(f.isUsable, isTrue);
      expect(f.radiusM, 10, reason: 'the farthest distance with water');
      expect(f.peakRate, 4.4);
      expect(f.profile!.first.$1, 0);
      expect(f.profile!.first.$2, closeTo(4.1 / 4.4, 1e-12));
      expect(f.profile![1], (0.2, 1.0));
      expect(f.profile!.last.$1, 1.0);
      expect(f.profile!.last.$2, closeTo(0.6 / 4.4, 1e-12));
      expect(f.profile, profileFromTable(rows));
      final nz = Catalog.defaultCatalog().outlets.first.nozzles.first;
      putNozzleProfile(nz, f);
      expect(nz.profile, f.profile);
      expect(() => putNozzleProfile(nz, fitProfileChart(const [(1.0, 2.0)])), throwsA(isA<ChartApplyError>().having((e) => e.code, 'code', 'profile')));
      expect(fitEmitterChart(const []).isUsable, isFalse);
      expect(EmitterCurve.fit(const []).k, 0);
    });
  });
}
