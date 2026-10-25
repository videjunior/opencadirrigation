import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/soils.dart';

/// Soil table against its sources: NEH Part 652 Table 2-1 (AWC), Rawls,
/// Brakensiek & Saxton (1982) means, FAO-56 Table 19, the SWAT/EPA intake
/// and surface accumulation table and NEH Section 15 Chapter 11 Table 11-4,
/// plus the USDA texture triangle.
void main() {
  test('the 12 USDA texture classes are keyed soil.<name>', () {
    expect(soilTable.length, 12);
    for (final t in SoilTexture.values) {
      expect(soilTable['soil.${t.name}']!.texture, t);
      expect(soilOf(t).key, 'soil.${t.name}');
    }
  });

  test('NEH 652 Table 2-1: typical AWC in mm/m and within its range', () {
    expect(soilOf(SoilTexture.loam).awcMmPerM, closeTo(166.7, 0.05)); // 2.0 in/ft
    expect(soilOf(SoilTexture.siltLoam).awcMmPerM, closeTo(200.0, 0.05)); // 2.4 in/ft
    expect(soilOf(SoilTexture.sand).awcMmPerM, closeTo(20.8, 0.05)); // 0.25 in/ft
    expect(soilOf(SoilTexture.loam).awcRangeMmPerM, (160, 180));
    for (final s in soilTable.values) {
      final (lo, hi) = s.awcRangeMmPerM;
      expect(s.awcMmPerM, inInclusiveRange(lo - 0.5, hi + 0.5), reason: s.key);
    }
    expect(soilOf(SoilTexture.loam).totalAvailableWaterMm(0.6), closeTo(100, 0.05));
    expect(soilOf(SoilTexture.loam).totalAvailableWaterMm(0.6, awcMmPerM: 120), closeTo(72, 1e-9));
  });

  test('Rawls et al. (1982) means and FAO-56 Table 19 ranges', () {
    final loam = soilOf(SoilTexture.loam);
    expect(loam.fieldCapacity, 0.270);
    expect(loam.wiltingPoint, 0.117);
    expect(loam.availableWaterFraction, closeTo(0.153, 1e-9));
    expect(loam.fao56Awc, (0.13, 0.18));
    expect(loam.ksatMmH, 13.2);
    // the Rawls field capacities fall in the FAO-56 ranges, and so do the
    // wilting points but for clay (0.272 against 0.20–0.24)
    for (final s in soilTable.values) {
      if (s.fao56FieldCapacity == null) continue;
      expect(s.fieldCapacity, inInclusiveRange(s.fao56FieldCapacity!.$1, s.fao56FieldCapacity!.$2), reason: s.key);
      expect(s.wiltingPoint, inInclusiveRange(s.fao56WiltingPoint!.$1, s.fao56WiltingPoint!.$2 + (s.texture == SoilTexture.clay ? 0.035 : 0)), reason: s.key);
    }
    // FAO-56 does not list three classes
    expect(soilOf(SoilTexture.clayLoam).fao56Awc, isNull);
    // conductivity falls from sand to clay
    final ks = [for (final t in [SoilTexture.sand, SoilTexture.loamySand, SoilTexture.sandyLoam, SoilTexture.loam, SoilTexture.siltLoam, SoilTexture.sandyClayLoam, SoilTexture.clayLoam, SoilTexture.siltyClayLoam, SoilTexture.sandyClay, SoilTexture.siltyClay, SoilTexture.clay]) soilOf(t).ksatMmH];
    for (var i = 1; i < ks.length; i++) {
      expect(ks[i], lessThan(ks[i - 1]));
    }
    expect(soilOf(SoilTexture.silt).estimatedFromNeighbours, contains('ksat'));
  });

  test('SWAT/EPA Table 3: basic intake rate and allowable surface accumulation', () {
    expect(soilOf(SoilTexture.clay).basicIntakeMmH, closeTo(0.10 * 25.4, 1e-9));
    expect(soilOf(SoilTexture.loam).basicIntakeMmH, closeTo(0.35 * 25.4, 1e-9));
    expect(soilOf(SoilTexture.sand).basicIntakeMmH, closeTo(0.60 * 25.4, 1e-9));
    // classes outside the table follow the NEH 652 intake groups
    expect(soilOf(SoilTexture.siltLoam).basicIntakeMmH, soilOf(SoilTexture.loam).basicIntakeMmH);
    expect(soilOf(SoilTexture.sandyClayLoam).basicIntakeMmH, soilOf(SoilTexture.clayLoam).basicIntakeMmH);
    expect(allowableSurfaceAccumulationMm(SoilTexture.loam, 2), closeTo(0.30 * 25.4, 1e-9));
    expect(allowableSurfaceAccumulationMm(SoilTexture.loam, 5), closeTo(0.25 * 25.4, 1e-9));
    expect(allowableSurfaceAccumulationMm(SoilTexture.loam, 10), closeTo(0.21 * 25.4, 1e-9));
    expect(allowableSurfaceAccumulationMm(SoilTexture.loam, 20), closeTo(0.17 * 25.4, 1e-9));
    expect(allowableSurfaceAccumulationMm(SoilTexture.sand, -2), closeTo(0.40 * 25.4, 1e-9));
  });

  test('NEH 15-11 Table 11-4: maximum sprinkler application rates by slope', () {
    expect(maxSprinklerApplicationRateMmH(SoilTexture.clayLoam, 3), closeTo(0.15 * 25.4, 1e-9));
    expect(maxSprinklerApplicationRateMmH(SoilTexture.siltLoam, 10), closeTo(0.30 * 25.4, 1e-9));
    expect(maxSprinklerApplicationRateMmH(SoilTexture.sandyLoam, 6, compactSubsoil: true), closeTo(0.50 * 25.4, 1e-9));
    expect(maxSprinklerApplicationRateMmH(SoilTexture.sand, 1, cover: SoilCover.grass), closeTo(2.5 * 25.4, 1e-9));
    expect(maxSprinklerApplicationRateMmH(SoilTexture.sand, 1, cover: SoilCover.bare), closeTo(1.5 * 25.4, 1e-9));
    expect(maxSprinklerApplicationRateMmH(SoilTexture.clay, 30), closeTo(0.06 * 25.4, 1e-9));
    expect(maxSprinklerApplicationRateMmH(SoilTexture.loam, 4, largeDrops: true), closeTo(0.5 * 0.75 * 25.4, 1e-9));
  });

  test('USDA texture triangle', () {
    expect(usdaTextureClass(92, 3), SoilTexture.sand);
    expect(usdaTextureClass(82, 6), SoilTexture.loamySand);
    expect(usdaTextureClass(65, 10), SoilTexture.sandyLoam);
    expect(usdaTextureClass(40, 20), SoilTexture.loam);
    expect(usdaTextureClass(20, 15), SoilTexture.siltLoam);
    expect(usdaTextureClass(5, 5), SoilTexture.silt);
    expect(usdaTextureClass(60, 25), SoilTexture.sandyClayLoam);
    expect(usdaTextureClass(35, 32), SoilTexture.clayLoam);
    expect(usdaTextureClass(10, 32), SoilTexture.siltyClayLoam);
    expect(usdaTextureClass(50, 40), SoilTexture.sandyClay);
    expect(usdaTextureClass(10, 50), SoilTexture.siltyClay);
    expect(usdaTextureClass(30, 50), SoilTexture.clay);
    expect(usdaTextureClass(80, 30), isNull);
    expect(usdaTextureClass(-1, 30), isNull);
    // every valid composition gets a class
    for (var sand = 0; sand <= 100; sand += 5) {
      for (var clay = 0; clay <= 100 - sand; clay += 5) {
        expect(usdaTextureClass(sand.toDouble(), clay.toDouble()), isNotNull, reason: 'sand $sand clay $clay');
      }
    }
  });
}
