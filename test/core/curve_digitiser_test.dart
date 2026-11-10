import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/curve_digitiser.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

/// The calibration of a picture of a chart (1.7.0 DGZ): two points per axis
/// give the general affine mapping, so straight, rotated and sheared
/// pictures read right, linear and logarithmic axes; a calibration that
/// cannot give one says why; the units of the axes; the points of a
/// session in the catalogue's units; CSV and clipboard text.
void main() {
  AxisCalibration cal(Pt p1, double v1, Pt p2, double v2, [AxisScale s = AxisScale.linear]) => AxisCalibration(p1: p1, v1: v1, p2: p2, v2: v2, scale: s);

  void near(Pt a, Pt b, [double tol = 1e-7]) {
    expect(a.distanceTo(b), lessThan(tol), reason: '($a) vs ($b)');
  }

  group('mapping', () {
    test('a straight picture: the values by hand', () {
      // X: 0 at px 100, 60 at px 700; Y: 0 at py 500, 80 at py 100
      final (m, err) = ChartMapping.solve(cal(const Pt(100, 500), 0, const Pt(700, 500), 60), cal(const Pt(100, 500), 0, const Pt(100, 100), 80));
      expect(err, isNull);
      final (x, y) = m!.valueAt(const Pt(400, 300));
      expect(x, closeTo(30, 1e-12)); // (400 − 100) / 600 · 60
      expect(y, closeTo(40, 1e-12)); // (500 − 300) / 400 · 80
      near(m.pixelOf(45, 20)!, const Pt(550, 400));
      near(m.xDirection, const Pt(1, 0));
      near(m.yDirection, const Pt(0, -1), 1e-12);
      expect(m.xRatePerPixel, closeTo(0.1, 1e-12));
    });

    // pixel of chart values (X, Y) on a picture drawn with [map]
    void roundTrip(Pt Function(double x, double y) map, {AxisScale xs = AxisScale.linear, AxisScale ys = AxisScale.linear, required List<(double, double)> xs1, required List<(double, double)> ys1}) {
      double coord(double v, AxisScale s) => s == AxisScale.log ? math.log(v) / math.ln10 : v;
      Pt img(double x, double y) => map(coord(x, xs), coord(y, ys));
      // the horizontal axis points lie on one horizontal line of the chart,
      // the vertical ones on one vertical line, as on a real axis
      final (x1, x2) = (xs1[0].$1, xs1[1].$1);
      final yAt = xs1[0].$2;
      final (y1, y2) = (ys1[0].$2, ys1[1].$2);
      final xAt = ys1[0].$1;
      final (m, err) = ChartMapping.solve(cal(img(x1, yAt), x1, img(x2, yAt), x2, xs), cal(img(xAt, y1), y1, img(xAt, y2), y2, ys));
      expect(err, isNull);
      final rnd = math.Random(7);
      for (var i = 0; i < 40; i++) {
        final x = xs == AxisScale.log ? math.pow(10, rnd.nextDouble() * 3).toDouble() : rnd.nextDouble() * 100;
        final y = ys == AxisScale.log ? math.pow(10, rnd.nextDouble() * 2 - 1).toDouble() : rnd.nextDouble() * 50 - 5;
        final (gx, gy) = m!.valueAt(img(x, y));
        expect(gx, closeTo(x, 1e-9 * math.max(1, x)), reason: 'x at $i');
        expect(gy, closeTo(y, 1e-9 * math.max(1, y.abs())), reason: 'y at $i');
        near(m.pixelOf(x, y)!, img(x, y), 1e-6);
      }
    }

    test('a picture rotated by 25°: the clicks follow the axes and the values are exact', () {
      const th = 25 * math.pi / 180;
      Pt map(double x, double y) {
        final px = 7 * x, py = -9 * y; // picture rows go down
        return Pt(320 + px * math.cos(th) - py * math.sin(th), 610 + px * math.sin(th) + py * math.cos(th));
      }

      roundTrip(map, xs1: const [(10, 0), (90, 0)], ys1: const [(0, 5), (0, 45)]);
      final (m, _) = ChartMapping.solve(cal(map(10, 0), 10, map(90, 0), 90), cal(map(0, 5), 5, map(0, 45), 45));
      near(m!.xDirection, const Pt(0.9063077870366499, 0.42261826174069944), 1e-12); // (cos 25°, sin 25°)
    });

    test('a sheared scan (axes 78° apart) and the axes clicked away from the origin', () {
      Pt map(double x, double y) => Pt(100 + 5 * x + 1.2 * y, 600 + 0.3 * x - 4 * y);
      roundTrip(map, xs1: const [(20, 10), (80, 10)], ys1: const [(30, 0), (30, 40)]);
    });

    test('logarithmic axes, alone or together; a value reads as a power of ten', () {
      Pt map(double u, double v) => Pt(100 + 200 * u, 500 - 150 * v);
      roundTrip(map, xs: AxisScale.log, ys: AxisScale.log, xs1: const [(1, 0.1), (1000, 0.1)], ys1: const [(1, 0.1), (1, 10)]);
      roundTrip(map, xs: AxisScale.log, xs1: const [(1, 0), (100, 0)], ys1: const [(1, 0), (1, 40)]);
      roundTrip(map, ys: AxisScale.log, xs1: const [(0, 1), (60, 1)], ys1: const [(0, 0.1), (0, 10)]);
      // 1 at px 100, 1000 at px 700: px 400 is 10^1.5 by hand
      final (m, _) = ChartMapping.solve(cal(const Pt(100, 500), 1, const Pt(700, 500), 1000, AxisScale.log), cal(const Pt(100, 500), 0, const Pt(100, 100), 10));
      expect(m!.valueAt(const Pt(400, 500)).$1, closeTo(31.6227766, 1e-6));
      expect(m.pixelOf(-1, 5), isNull, reason: 'no place for a negative value on a log axis');
    });

    test('a calibration that gives no mapping says why', () {
      final x = cal(const Pt(100, 500), 0, const Pt(700, 500), 60);
      final y = cal(const Pt(100, 500), 0, const Pt(100, 100), 80);
      expect(ChartMapping.solve(AxisCalibration(), y).$2, CalibrationError.incomplete);
      expect(ChartMapping.solve(AxisCalibration(p1: const Pt(1, 1), p2: const Pt(9, 9), v1: 1), y).$2, CalibrationError.incomplete);
      expect(ChartMapping.solve(cal(const Pt(100, 500), 0, const Pt(101, 500.5), 60), y).$2, CalibrationError.samePoints);
      expect(ChartMapping.solve(x, cal(const Pt(100, 500), 10, const Pt(100, 100), 10)).$2, CalibrationError.sameValues);
      expect(ChartMapping.solve(cal(const Pt(100, 500), 0, const Pt(700, 500), 60, AxisScale.log), y).$2, CalibrationError.logValues);
      // the vertical axis clicked along the horizontal one (5° apart)
      final along = cal(const Pt(100, 500), 0, Pt(100 + 400 * math.cos(5 * math.pi / 180), 500 - 400 * math.sin(5 * math.pi / 180)), 80);
      expect(ChartMapping.solve(x, along).$2, CalibrationError.parallel);
      // 12° apart is still a (badly sheared) chart
      final steep = cal(const Pt(100, 500), 0, Pt(100 + 400 * math.cos(12 * math.pi / 180), 500 - 400 * math.sin(12 * math.pi / 180)), 80);
      expect(ChartMapping.solve(x, steep).$2, isNull);
      expect(ChartMapping.solve(x, y).$2, isNull);
    });
  });

  group('units', () {
    test('every axis unit converts to the engine’s and back', () {
      double si(ChartQuantity q, String code, double v) => AxisUnit.of(q, code)!.toSi(v);
      expect(si(ChartQuantity.flow, 'm3h', 36), closeTo(0.01, 1e-15));
      expect(si(ChartQuantity.flow, 'lps', 5), closeTo(0.005, 1e-15));
      expect(si(ChartQuantity.flow, 'lpm', 60), closeTo(0.001, 1e-15));
      expect(si(ChartQuantity.flow, 'gpm', 100), closeTo(0.00630902, 1e-12));
      expect(si(ChartQuantity.head, 'bar', 1), closeTo(10.19716, 1e-5));
      expect(si(ChartQuantity.head, 'psi', 10), closeTo(7.030696, 1e-5));
      expect(si(ChartQuantity.head, 'kPa', 98.0665), closeTo(10, 1e-12));
      expect(si(ChartQuantity.power, 'hp', 1), closeTo(0.745699872, 1e-12));
      expect(si(ChartQuantity.power, 'cv', 10), closeTo(7.3549875, 1e-12));
      expect(si(ChartQuantity.efficiency, 'pct', 75), closeTo(0.75, 1e-15));
      expect(si(ChartQuantity.rate, 'inh', 1), closeTo(25.4, 1e-12));
      expect(si(ChartQuantity.distance, 'ft', 10), closeTo(3.048, 1e-12));
      for (final q in ChartQuantity.values) {
        for (final u in AxisUnit.all(q)) {
          expect(u.fromSi(u.toSi(12.5)), closeTo(12.5, 1e-9), reason: u.id);
          expect(u.label, isNotEmpty);
        }
      }
      expect(AxisUnit.of(ChartQuantity.flow, 'nope'), isNull);
      expect(defaultAxisUnit(ChartQuantity.flow, Units.metric).code, 'm3h');
      expect(defaultAxisUnit(ChartQuantity.flow, Units.metric, kind: CurveKind.emitter).code, 'lph');
      expect(defaultAxisUnit(ChartQuantity.flow, Units.us).code, 'gpm');
      expect(defaultAxisUnit(ChartQuantity.head, Units.us).code, 'psi');
      expect(defaultAxisUnit(ChartQuantity.power, Units.us).code, 'hp');
    });
  });

  group('session', () {
    DigitiserSession calibrated(CurveKind kind, {bool swapped = false}) {
      final s = DigitiserSession.start(kind, swapped: swapped);
      s.x
        ..p1 = const Pt(100, 500)
        ..v1 = 0
        ..p2 = const Pt(700, 500)
        ..v2 = 60;
      s.active.y
        ..p1 = const Pt(100, 500)
        ..v1 = 0
        ..p2 = const Pt(100, 100)
        ..v2 = 80;
      return s;
    }

    test('a pump’s points in m³/h and m become m³/s and metres, sorted by flow', () {
      final s = calibrated(CurveKind.pump);
      expect(s.active.role, CurveRole.head);
      expect(s.series.keys, [CurveRole.head, CurveRole.efficiency, CurveRole.npsh, CurveRole.power]);
      s.active.pixels.addAll(const [Pt(700, 300), Pt(100, 100), Pt(400, 200)]);
      expect(s.values(), [(0.0, 80.0), (30.0, 60.0), (60.0, 40.0)]);
      final si = s.si();
      expect(si[1].$1, closeTo(30 / 3600, 1e-15));
      expect(si[1].$2, closeTo(60, 1e-12));
      expect(s.si(CurveRole.efficiency), isEmpty, reason: 'its vertical axis is not calibrated');
      expect(s.mapping(CurveRole.efficiency).$2, CalibrationError.incomplete);
      // an undo copy is a deep copy
      final before = s.copy();
      s.active.pixels.clear();
      expect(before.active.pixels, hasLength(3));
    });

    test('an outlet’s chart reads as (pressure, flow) whichever axis holds the flow', () {
      final s = calibrated(CurveKind.emitter); // pressure (m) along, flow (L/h) up
      expect((s.xUnit.quantity, s.active.yUnit.quantity), (ChartQuantity.head, ChartQuantity.flow));
      s.active.pixels.add(const Pt(400, 300)); // 30 m, 40 L/h
      expect(s.si().single.$1, closeTo(30, 1e-12));
      expect(s.si().single.$2, closeTo(40 * m3sPerLph, 1e-15));
      final w = s.withSwapped(true); // flow along, pressure up: the same clicks
      expect((w.xUnit.quantity, w.active.yUnit.quantity), (ChartQuantity.flow, ChartQuantity.head));
      w.xUnit = const AxisUnit(ChartQuantity.flow, 'lph');
      w.active.yUnit = const AxisUnit(ChartQuantity.head, 'mH2O');
      expect(w.si().single.$1, closeTo(40, 1e-12), reason: '40 m up the side');
      expect(w.si().single.$2, closeTo(30 * m3sPerLph, 1e-15), reason: '30 L/h along the bottom');
    });

    test('CSV and clipboard text of the points', () {
      final curves = <CurveColumns>[
        (name: 'Head', x: 'm³/h', y: 'm', points: const [(0.0, 52.5), (30.0, 41.25)]),
        (name: 'Efficiency', x: 'm³/h', y: '%', points: const [(30.0, 71.0)]),
      ];
      final csv = curvePointsCsv(curves);
      expect(csv.startsWith('\u{FEFF}curve;x;y;x unit;y unit\n'), isTrue);
      expect(csv, contains('"Head";0;52.5;"m³/h";"m"\n'));
      expect(csv, contains('"Head";30;41.25;"m³/h";"m"\n'));
      expect(csv, contains('"Efficiency";30;71;"m³/h";"%"\n'));
      expect(
        curvePointsCsv([
          (name: 'A', x: 'x', y: 'y', points: const [(1 / 3, 1234.56789)]),
        ]),
        contains('0.333333;1234.57;'),
      );
      final tsv = curvePointsTsv(curves, decimalSeparator: ',');
      expect(tsv, contains('m³/h\tm\n0\t52,5\n30\t41,25\n'));
      expect(tsv, contains('Efficiency\t\t\nm³/h\t%\n30\t71\n'));
    });
  });
}
