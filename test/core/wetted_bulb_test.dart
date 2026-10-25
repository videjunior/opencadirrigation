import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/wetted_bulb.dart';

/// Wetted bulb and wetted area against Schwartzman & Zur (1986) as
/// restated by Cruz-Bautista et al. (2016), the Keller & Bliesner (1990)
/// table and the FAO Irrigation Manual Module 9 examples (eqs. 8 and 10).
void main() {
  group('Schwartzman & Zur (1986)', () {
    test('a 4 L/h emitter applying 8 L in a loam (Ks 13.2 mm/h)', () {
      // W = 1.82·V^0.22·(Ks/q)^−0.17, Z = 2.54·V^0.63·(Ks/q)^0.45 in SI
      final b = schwartzmanZurBulb(flowLph: 4, volumeL: 8, ksatMmH: 13.2);
      final r = (13.2 / 3.6e6) / (4 / 3.6e6);
      expect(b.widthM, closeTo(1.82 * math.pow(0.008, 0.22) * math.pow(r, -0.17), 1e-12));
      expect(b.widthM, closeTo(0.514, 0.001));
      expect(b.depthM, closeTo(0.208, 0.001));
      expect(b.extrapolated, isFalse);
      expect(b.areaM2, closeTo(math.pi * b.widthM * b.widthM / 4, 1e-12));
    });

    test('sand wets narrow and deep, more water wets more, more flow spreads wider', () {
      final loam = schwartzmanZurBulb(flowLph: 4, volumeL: 8, ksatMmH: 13.2);
      final sand = schwartzmanZurBulb(flowLph: 4, volumeL: 8, ksatMmH: 210);
      expect(sand.widthM, closeTo(0.321, 0.001));
      expect(sand.depthM, closeTo(0.721, 0.001));
      expect(sand.widthM, lessThan(loam.widthM));
      expect(sand.depthM, greaterThan(loam.depthM));
      final more = schwartzmanZurBulb(flowLph: 4, volumeL: 16, ksatMmH: 13.2);
      expect(more.widthM, greaterThan(loam.widthM));
      expect(more.depthM, greaterThan(loam.depthM));
      final faster = schwartzmanZurBulb(flowLph: 8, volumeL: 8, ksatMmH: 13.2);
      expect(faster.widthM, greaterThan(loam.widthM));
      expect(faster.depthM, lessThan(loam.depthM));
      // outside the experiments (clay, 1 L/h) the estimate is flagged
      expect(schwartzmanZurBulb(flowLph: 1, volumeL: 4, ksatMmH: 0.6).extrapolated, isTrue);
      expect(schwartzmanZurBulb(flowLph: 4, volumeL: 0, ksatMmH: 13.2).widthM, 0);
    });
  });

  group('Keller & Bliesner (1990) table of a 4 L/h emitter', () {
    test('wetted widths by texture, profile and depth', () {
      expect(kellerBliesnerWettedWidthM(texture: BulbTexture.medium), 0.9);
      expect(kellerBliesnerWettedWidthM(texture: BulbTexture.fine, profile: BulbProfile.layered, depthM: 1.5), 2.4);
      expect(kellerBliesnerWettedWidthM(texture: BulbTexture.coarse, profile: BulbProfile.stratified, depthM: 1.125), closeTo(1.1, 1e-9));
      expect(kellerBliesnerWettedWidthM(texture: BulbTexture.coarse, depthM: 3), 0.8);
    });
  });

  group('percentage of wetted area (FAO Module 9)', () {
    test('eq. 10: 5 emitters 1.2 m apart wetting 2.26 m on 6 × 6 m trees give 38 %', () {
      expect(percentWettedArea(emittersPerPlant: 5, emitterSpacingM: 1.2, wettedWidthM: 2.26, plantSpacingM: 6, rowSpacingM: 6), closeTo(37.7, 0.05));
    });

    test('eq. 10 as printed for emitters 2 m apart wetting 1.81 m: 60 %, or 44 % counting only Se\' = 0.8·W', () {
      expect(percentWettedArea(emittersPerPlant: 6, emitterSpacingM: 2, wettedWidthM: 1.81, plantSpacingM: 6, rowSpacingM: 6, limitSpacingToWettedWidth: false), closeTo(60.3, 0.05));
      expect(percentWettedArea(emittersPerPlant: 6, emitterSpacingM: 2, wettedWidthM: 1.81, plantSpacingM: 6, rowSpacingM: 6), closeTo(100 * 6 * 0.8 * 1.81 * 1.81 / 36, 1e-9));
    });

    test('a continuous dripline wets W/Sr; the result never exceeds 100 %', () {
      expect(percentWettedAreaOfLaterals(lateralsPerRow: 1, emitterSpacingM: 0.5, wettedWidthM: 0.8, rowSpacingM: 1.5), closeTo(100 * 0.8 / 1.5, 1e-9));
      expect(percentWettedAreaOfLaterals(lateralsPerRow: 2, emitterSpacingM: 0.3, wettedWidthM: 1.0, rowSpacingM: 1.2), 100);
      expect(percentWettedArea(emittersPerPlant: 1, emitterSpacingM: 1, wettedWidthM: 1, plantSpacingM: 0, rowSpacingM: 1), 0);
    });

    test('eq. 8, Example 5: emitters per tree for Pw 50 % and 60 % with 4 m² each', () {
      expect(emittersPerPlantForWettedArea(targetPercent: 50, plantSpacingM: 6, rowSpacingM: 6, wettedAreaM2: 4), 5);
      expect(emittersPerPlantForWettedArea(targetPercent: 60, plantSpacingM: 6, rowSpacingM: 6, wettedAreaM2: 4), 6);
      expect(emittersPerPlantForWettedArea(targetPercent: 50, plantSpacingM: 4, rowSpacingM: 2, wettedAreaM2: 2), 2);
    });
  });
}
