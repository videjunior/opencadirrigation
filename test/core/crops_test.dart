import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/agronomy.dart' show cropKcTable;
import 'package:opencadirrigation/core/design/crops.dart';

/// FAO-56 crop coefficient curve and table against the worked examples of
/// FAO-56 (Examples 25, 27, 28, 41, 42, Box 15, Annex 7) and the localized
/// irrigation reduction of the FAO Irrigation Manual Module 9 (Example 1,
/// Table 1).
void main() {
  // dry beans at Kimberly, Idaho (FAO-56 Box 15, Example 28, Figure 36)
  const bean = KcCurve(kcIni: 0.15, kcMid: 1.19, kcEnd: 0.35, stages: CropStages(25, 25, 30, 20));

  group('Kc curve (FAO-56 eq. 66)', () {
    test('Example 28: Kc on days 20, 40, 70 and 95 for dry beans', () {
      expect(bean.at(20), closeTo(0.15, 1e-9));
      expect(bean.at(40), closeTo(0.77, 0.005));
      expect(bean.at(70), closeTo(1.19, 1e-9));
      expect(bean.at(95), closeTo(0.56, 0.005));
      expect(bean.seasonDays, 100);
      expect(bean.at(-1), 0);
      expect(bean.at(101), 0);
    });

    test('Figure 36: the ten-day Kc where the initial stage ends is 0.20', () {
      // days 21–30: five days at Kc ini, then the start of the development line
      expect(bean.mean(20, 30), closeTo(0.20, 0.005));
      // a whole stage averages its end values
      expect(bean.mean(25, 50), closeTo((0.15 + 1.19) / 2, 1e-9));
      expect(bean.mean(0, 100), closeTo((25 * 0.15 + 25 * (0.15 + 1.19) / 2 + 30 * 1.19 + 20 * (1.19 + 0.35) / 2) / 100, 1e-9));
      // and leaving the season counts the off-season Kc
      expect(bean.mean(90, 110), closeTo((10 * (bean.at(90) + 0.35) / 2) / 20, 1e-9));
    });

    test('Box 15: Kc mid adjusted for RHmin 30 % and u2 2.2 m/s, Kc end below 0.45 kept', () {
      expect(adjustKcForClimate(1.15, windSpeed2mMs: 2.2, rhMinPct: 30, heightM: 0.4), closeTo(1.19, 0.005));
      final c = const KcCurve(kcIni: 0.4, kcMid: 1.15, kcEnd: 0.35, stages: CropStages(20, 30, 40, 20)).adjustedForClimate(windSpeed2mMs: 2.2, rhMinPct: 30, heightM: 0.4);
      expect(c.kcMid, closeTo(1.19, 0.005));
      expect(c.kcEnd, 0.35);
    });

    test('Example 27: Kc mid of maize near Taipei (humid) and Mocha (arid)', () {
      expect(adjustKcForClimate(1.20, windSpeed2mMs: 1.3, rhMinPct: 75, heightM: 2), closeTo(1.07, 0.005));
      expect(adjustKcForClimate(1.20, windSpeed2mMs: 4.6, rhMinPct: 44, heightM: 2), closeTo(1.30, 0.005));
      // the limits of eq. 62 hold
      expect(adjustKcForClimate(1.20, windSpeed2mMs: 9, rhMinPct: 5, heightM: 20), adjustKcForClimate(1.20, windSpeed2mMs: 6, rhMinPct: 20, heightM: 10));
    });

    test('scaled, constant and restaged copies', () {
      expect(bean.scaled(0.5).at(70), closeTo(0.595, 1e-9));
      expect(bean.withKcIni(0.3).at(10), 0.3);
      expect(bean.withStages(const CropStages(10, 10, 10, 10)).seasonDays, 40);
      const k = KcCurve.constant(0.9);
      expect(k.at(-5), 0.9);
      expect(k.at(200), 0.9);
      expect(k.mean(0, 365), closeTo(0.9, 1e-12));
    });
  });

  group('Kc ini from the wetting interval (FAO-56 Annex 7)', () {
    test('Example 25 / 7-1: small vegetables, coarse soil, 20 mm twice a week, ETo 5 mm/day', () {
      // light wetting (Figure 29): eq. 7-3 gives 0.53 (Example 25 reads 0.55
      // from the figure; Example 7-1 prints 0.57)
      final light = kcIniFromWetting(etoMmDay: 5, wettingIntervalDays: 3.5, infiltrationDepthMm: 10, texture: SoilWettingTexture.coarse);
      expect(light, closeTo(0.55, 0.025));
      // heavy wetting on a coarse soil (Figure 30a): 0.75
      expect(kcIniFromWetting(etoMmDay: 5, wettingIntervalDays: 3.5, infiltrationDepthMm: 40, texture: SoilWettingTexture.coarse), closeTo(0.75, 0.005));
      // 20 mm interpolates (eq. 59): 0.60
      expect(kcIniFromWetting(etoMmDay: 5, wettingIntervalDays: 3.5, infiltrationDepthMm: 20, texture: SoilWettingTexture.coarse), closeTo(0.60, 0.01));
    });

    test('frequent wetting stays at 1.15 and partial wetting scales it (eqs. 60, 61)', () {
      expect(kcIniFromWetting(etoMmDay: 2, wettingIntervalDays: 0.5), closeTo(1.15, 1e-9));
      final full = kcIniFromWetting(etoMmDay: 4, wettingIntervalDays: 2, infiltrationDepthMm: 10);
      // 4 mm over the field wets 40 % of it with 10 mm
      expect(kcIniFromWetting(etoMmDay: 4, wettingIntervalDays: 2, infiltrationDepthMm: 4, wettedFraction: 0.4), closeTo(0.4 * full, 1e-9));
      // longer intervals and higher ETo lower Kc ini
      expect(kcIniFromWetting(etoMmDay: 4, wettingIntervalDays: 7), lessThan(full));
      expect(kcIniFromWetting(etoMmDay: 8, wettingIntervalDays: 2), lessThan(full));
    });
  });

  group('sparse cover and depletion fraction', () {
    test('Example 41: 30 % cover, 2 m tall, Kcb full 1.15 gives Kcb mid 0.75 (eq. 98)', () {
      expect(sparseCoverKc(kcFull: 1.15, groundCover: 0.3, fcEffective: 0.41, heightM: 2), closeTo(0.75, 0.005));
    });

    test('Example 42: tomatoes with 50 % cover give Kcb mid 0.95', () {
      expect(sparseCoverKc(kcFull: 1.17, groundCover: 0.5, fcEffective: 0.66, heightM: 0.75), closeTo(0.95, 0.01));
    });

    test('Table 22 note 2: p adjusted to ETc', () {
      expect(adjustDepletionFraction(0.55, 8), closeTo(0.43, 1e-9));
      expect(adjustDepletionFraction(0.5, 2), closeTo(0.62, 1e-9));
      expect(adjustDepletionFraction(0.75, 0), 0.8);
      expect(adjustDepletionFraction(0.2, 10), 0.1);
    });
  });

  group('localized irrigation (FAO Module 9)', () {
    test('Example 1: mature citrus, 70 % ground cover, peak ETc 7.1 mm/day', () {
      const etc = 7.1;
      expect(etc * localizedReductionFactor(0.7, method: LocalizedReductionMethod.kellerKarmeli), closeTo(5.8, 0.05));
      expect(etc * localizedReductionFactor(0.7, method: LocalizedReductionMethod.freemanGarzoli), closeTo(6.0, 0.05));
      expect(etc * localizedReductionFactor(0.7, method: LocalizedReductionMethod.decroix), closeTo(5.7, 0.05));
      expect(etc * localizedReductionFactor(0.7), closeTo(5.9, 0.05)); // Keller & Bliesner: 7.1·0.1·√70
    });

    test('Table 1: Kr by ground cover for the three tabulated methods', () {
      const kk = [0.12, 0.24, 0.35, 0.47, 0.59, 0.70, 0.82, 0.94, 1.00, 1.00];
      const fg = [0.10, 0.20, 0.30, 0.40, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00];
      const dc = [0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 1.00, 1.00];
      for (var i = 0; i < 10; i++) {
        final gc = (i + 1) / 10;
        expect(localizedReductionFactor(gc, method: LocalizedReductionMethod.kellerKarmeli), closeTo(kk[i], 0.01), reason: 'K&K $gc');
        expect(localizedReductionFactor(gc, method: LocalizedReductionMethod.freemanGarzoli), closeTo(fg[i], 0.01), reason: 'F&G $gc');
        expect(localizedReductionFactor(gc, method: LocalizedReductionMethod.decroix), closeTo(dc[i], 0.01), reason: 'Decroix $gc');
      }
      expect(localizedReductionFactor(1.5), 1);
      expect(localizedReductionFactor(0), 0);
    });
  });

  group('calendar', () {
    test('dry beans planted on 22 May: the decade of 11–20 June is the Figure 36 decade', () {
      final (kc, days) = periodKc(bean, DateTime.utc(2001, 5, 22), DateTime.utc(2001, 6, 11), DateTime.utc(2001, 6, 20));
      expect(days, 10);
      expect(kc, closeTo(0.20, 0.005));
      final months = monthlyKc(bean, DateTime.utc(2001, 5, 22), 2001, repeatsYearly: false);
      expect(months.map((m) => m.cropDays).toList(), [0, 0, 0, 0, 10, 30, 31, 29, 0, 0, 0, 0]);
      expect(months[4].meanKc, closeTo(0.15, 1e-9));
      // Σ Kc·days = the area under the curve
      final total = months.fold(0.0, (s, m) => s + m.kcDays);
      expect(total, closeTo(bean.mean(0, 100) * 100, 1e-9));
    });

    test('a perennial cycle covers the whole year and wraps around', () {
      final citrus = fao56Crops['crop.citrus']!;
      expect(citrus.stages!.total, 365);
      final months = monthlyKc(citrus.curve, DateTime.utc(2000, 1, 1), 2001);
      expect(months.fold(0, (s, m) => s + m.cropDays), 365);
      // a leap year still has a Kc every day
      expect(monthlyKc(citrus.curve, DateTime.utc(2000, 1, 1), 2024).fold(0, (s, m) => s + m.cropDays), 366);
      // an annual crop planted in October every year runs into the next year
      final maize = fao56Crops['crop.maize']!;
      final oct = monthlyKc(maize.curve, DateTime.utc(2000, 10, 1), 2001);
      expect(oct.where((m) => m.cropDays > 0).map((m) => m.month).toList(), [1, 2, 10, 11, 12]);
      expect(oct.fold(0, (s, m) => s + m.cropDays), maize.stages!.total);
    });

    test('daysIntoCycle', () {
      expect(daysIntoCycle(DateTime.utc(2001, 5, 21), DateTime.utc(2001, 5, 22), 100), isNull);
      expect(daysIntoCycle(DateTime.utc(2001, 5, 22), DateTime.utc(2001, 5, 22), 100), 0);
      expect(daysIntoCycle(DateTime.utc(2001, 8, 29), DateTime.utc(2001, 5, 22), 100), 99);
      expect(daysIntoCycle(DateTime.utc(2001, 8, 30), DateTime.utc(2001, 5, 22), 100), isNull);
      expect(daysIntoCycle(DateTime.utc(2003, 5, 23), DateTime.utc(2001, 5, 22), 100, repeatsYearly: true), 1);
    });
  });

  group('crop table', () {
    test('keeps every key and the values of the previous preset table', () {
      for (final e in cropKcTable.entries) {
        final c = fao56Crops[e.key];
        expect(c, isNotNull, reason: e.key);
        expect((c!.kcIni, c.kcMid, c.kcEnd), e.value, reason: e.key);
      }
    });

    test('entries are consistent', () {
      for (final c in fao56Crops.values) {
        expect(c.key, startsWith('crop.'));
        expect(fao56Crops[c.key], same(c));
        for (final v in [c.kcIni, c.kcMid, c.kcEnd]) {
          expect(v, inInclusiveRange(0.1, 1.3), reason: c.key);
        }
        if (c.kcbMid != null) expect(c.kcbMid!, lessThanOrEqualTo(c.kcMid + 1e-9), reason: c.key);
        if (c.rootDepthMinM != null) expect(c.rootDepthMinM!, lessThanOrEqualTo(c.rootDepthMaxM!), reason: c.key);
        if (c.depletionFraction != null) expect(c.depletionFraction!, inInclusiveRange(0.1, 0.8), reason: c.key);
        if (c.eceThreshold != null) expect(c.eceThreshold!, lessThan(c.eceMax!), reason: c.key);
        expect(c.curve.seasonDays, greaterThan(0));
        if (c.tabulated) expect(c.maxHeightM, isNotNull, reason: c.key);
      }
      expect(fao56Crops['crop.mango']!.tabulated, isFalse);
      expect(fao56Crops.length, greaterThanOrEqualTo(35));
    });

    test('salt tolerance slope b of FAO-29 Table 4 / FAO-56 Table 23', () {
      expect(fao56Crops['crop.cotton']!.eceSlope, closeTo(5.2, 0.05));
      expect(fao56Crops['crop.maize']!.eceSlope, closeTo(12.0, 0.1));
      expect(fao56Crops['crop.coffee']!.eceSlope, isNull);
    });

    test('evergreen crops without stage lengths keep Kc mid all year; Kcb curves follow Table 17', () {
      final coffee = fao56Crops['crop.coffee']!;
      expect(coffee.stages, isNull);
      expect(coffee.curve.at(100), 0.95);
      expect(fao56Crops['crop.tomato']!.basalCurve!.kcMid, 1.10);
      expect(fao56Crops['crop.alfalfa']!.basalCurve, isNull);
    });
  });
}
