import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/effective_rain.dart';

/// Effective rainfall against the published examples and tables: USDA-NRCS
/// NEH Part 623 Chapter 2 (eqs. 2-84, 2-85, Table 2-43 and its worked
/// example), FAO Training Manual 3 (Brouwer & Heibloem 1986, section 4.2 and
/// 4.3) and the FAO/AGLW and simplified USDA-SCS formulas.
void main() {
  group('USDA-SCS TR-21 (NEH 623 chapter 2)', () {
    test('worked example: ETc 7.6 in, rain 4.7 in', () {
      // Pe = 3.70 in for D = 3 in (eq. 2-84)
      expect(effectiveRainUsdaScsInches(4.7, 7.6, netDepthIn: 3), closeTo(3.70, 0.01));
      // D = 2 in: the equation gives SF = 0.92 (the table rounds it to 0.93,
      // hence the printed 3.44)
      expect(usdaScsStorageFactor(2 * 25.4), closeTo(0.922, 0.001));
      expect(effectiveRainUsdaScsInches(4.7, 7.6, netDepthIn: 2), closeTo(3.44, 0.03));
    });

    test('Table 2-43 cells for 3 in of soil water storage', () {
      // (rain, ETc) → Pe, inches
      const cells = <(double, double, double)>[(0.5, 2, 0.32), (1.0, 4, 0.74), (2.0, 5, 1.51), (4.0, 6, 2.95), (4.0, 10, 3.68), (8.0, 6, 5.34), (8.0, 10, 6.68)];
      for (final (p, etc, pe) in cells) {
        expect(effectiveRainUsdaScsInches(p, etc), closeTo(pe, 0.011), reason: 'P $p, ETc $etc');
      }
    });

    test('effective rain never exceeds the rain nor ETc (NEH 623 note to Table 2-43)', () {
      // 1 in of rain with 10 in of ETc: the equation gives 1.04, the table 1.00
      expect(effectiveRainUsdaScsInches(1.0, 10), closeTo(1.00, 1e-9));
      // 4 in of rain with 1 in of ETc: the table cell is the raw 2.23, which
      // its note reduces to the ETc
      expect(effectiveRainUsdaScsInches(4.0, 1), closeTo(1.0, 1e-9));
      expect(effectiveRainUsdaScsMm(101.6, 25.4), lessThanOrEqualTo(25.4));
      expect(effectiveRainUsdaScsMm(0, 100), 0);
      expect(effectiveRainUsdaScsMm(2, 100), 0); // below ~2.8 mm the fit is negative
    });

    test('storage factors of Table 2-43 follow eq. 2-85 to the table rounding', () {
      const table = <(double, double)>[(0.75, 0.72), (1.0, 0.77), (1.5, 0.86), (2.0, 0.93), (2.5, 0.97), (3.0, 1.00), (4.0, 1.02), (5.0, 1.04), (6.0, 1.06), (7.0, 1.07)];
      for (final (d, sf) in table) {
        expect(usdaScsStorageFactor(d * 25.4), closeTo(sf, 0.015), reason: 'D $d in');
      }
      // outside the table the factor is held at its ends
      expect(usdaScsStorageFactor(5), usdaScsStorageFactor(0.75 * 25.4));
      expect(usdaScsStorageFactor(400), usdaScsStorageFactor(7 * 25.4));
    });
  });

  group('FAO formulas', () {
    test('FAO Training Manual 3, section 4.2: monthly rain to effective rain', () {
      const answers = <(double, double)>[(35, 11), (90, 47), (116, 68), (5, 0), (260, 183), (75, 35)];
      for (final (p, pe) in answers) {
        expect(effectiveRainFaoEmpiricalMm(p), closeTo(pe, 0.5), reason: 'P $p');
      }
    });

    test('FAO Training Manual 3, section 4.3: irrigation water need IN = ETc − Pe', () {
      const etc = <double>[69, 123, 180, 234, 180];
      const rain = <double>[20, 38, 40, 80, 16];
      const pe = <double>[2, 13, 14, 39, 0];
      const need = <double>[67, 110, 166, 195, 180];
      for (var i = 0; i < 5; i++) {
        final e = effectiveRainMm(EffectiveRainMethod.faoEmpirical, rain[i], etcMm: etc[i]);
        expect(e, closeTo(pe[i], 0.5));
        expect(etc[i] - e, closeTo(need[i], 0.5));
      }
    });

    test('FAO/AGLW dependable rain and the simplified USDA-SCS formula', () {
      expect(effectiveRainFaoDependableMm(70), closeTo(32, 1e-9));
      expect(effectiveRainFaoDependableMm(70.0001), closeTo(32, 1e-3)); // continuous at 70 mm
      expect(effectiveRainFaoDependableMm(100), closeTo(56, 1e-9));
      expect(effectiveRainFaoDependableMm(10), 0);
      expect(effectiveRainUsdaScsSimplifiedMm(100), closeTo(84, 1e-9));
      expect(effectiveRainUsdaScsSimplifiedMm(250), closeTo(150, 1e-9));
      expect(effectiveRainUsdaScsSimplifiedMm(300), closeTo(155, 1e-9));
    });

    test('method dispatch, caps and fixed percentage', () {
      expect(effectiveRainMm(EffectiveRainMethod.fixedPercentage, 100, fraction: 0.8), closeTo(80, 1e-9));
      expect(effectiveRainMm(EffectiveRainMethod.fixedPercentage, 100, fraction: 0.8, etcMm: 50), closeTo(50, 1e-9));
      expect(effectiveRainMm(EffectiveRainMethod.total, 100, etcMm: 50), 100);
      expect(effectiveRainMm(EffectiveRainMethod.none, 100), 0);
      // TR-21 without ETc falls back on the simplified formula
      expect(effectiveRainMm(EffectiveRainMethod.usdaScs, 100), closeTo(84, 1e-9));
      expect(effectiveRainMm(EffectiveRainMethod.usdaScs, 4.7 * 25.4, etcMm: 7.6 * 25.4), closeTo(3.70 * 25.4, 0.3));
    });

    test('part of a month: the whole-month value prorated by days', () {
      expect(effectiveRainForPartOfMonthMm(EffectiveRainMethod.faoEmpirical, monthRainMm: 100, days: 15, monthDays: 30), closeTo(27.5, 1e-9));
      expect(effectiveRainForPartOfMonthMm(EffectiveRainMethod.faoEmpirical, monthRainMm: 100, days: 0, monthDays: 30), 0);
    });
  });

  group('dependable rain', () {
    test('rain exceeded in four years out of five (Weibull plotting positions)', () {
      final xs = [for (var i = 1; i <= 9; i++) i.toDouble()];
      expect(rainExceededWithProbability(xs, 0.8), closeTo(2, 1e-9));
      expect(rainExceededWithProbability(xs, 0.5), closeTo(5, 1e-9));
      expect(rainExceededWithProbability(xs.reversed.toList(), 0.2), closeTo(8, 1e-9));
      expect(rainExceededWithProbability([30, 10], 0.8), 10);
      expect(rainExceededWithProbability(const [], 0.8), isNull);
    });
  });
}
