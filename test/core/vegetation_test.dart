import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/design/vegetation.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

import '../support/aerial_scene.dart';

/// The patch of class [c] whose outline holds the scene point [p].
VegetationPatch patchAt(VegetationResult r, VegetationClass c, Pt p, {Pt origin = Pt.zero, double rotationDeg = 0}) {
  final q = AerialScene.place(p, origin: origin, rotationDeg: rotationDeg);
  return r.patches.firstWhere((x) => x.cls == c && pointInPolygon(q, x.outline), orElse: () => throw StateError('no ${c.name} patch at $p'));
}

/// Largest distance from a vertex of [a] to the outline of [b].
double farthest(List<Pt> a, List<Pt> b) {
  var worst = 0.0;
  for (final p in a) {
    var d = double.infinity;
    for (var i = 0; i < b.length; i++) {
      d = math.min(d, distanceToSegment(p, b[i], b[(i + 1) % b.length]));
    }
    worst = math.max(worst, d);
  }
  return worst;
}

Matcher within(double expected, double fraction) => closeTo(expected, expected * fraction);

/// Pixels of the regions of [inside] (4- or 8-connected) for the outline
/// check: labels, 1-based.
Int32List labelsOf(List<bool> inside, int w, int h, {required bool eight}) {
  final l = Int32List(w * h);
  var id = 0;
  for (var s = 0; s < w * h; s++) {
    if (!inside[s] || l[s] != 0) continue;
    l[s] = ++id;
    final stack = [s];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final x = p % w, y = p ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if ((dx == 0 && dy == 0) || (!eight && dx != 0 && dy != 0)) continue;
          final xx = x + dx, yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
          final j = yy * w + xx;
          if (inside[j] && l[j] == 0) {
            l[j] = id;
            stack.add(j);
          }
        }
      }
    }
  }
  return l;
}

/// The pixels a region encloses: those the rest of the raster cannot reach
/// from outside it (moving 8-connected when [eightOutside]).
List<bool> enclosed(List<bool> region, int w, int h, {required bool eightOutside}) {
  final pw = w + 2, ph = h + 2;
  final out = List.filled(pw * ph, false)..[0] = true;
  bool inRegion(int x, int y) => x >= 1 && y >= 1 && x <= w && y <= h && region[(y - 1) * w + x - 1];
  final stack = [0];
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final x = p % pw, y = p ~/ pw;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if ((dx == 0 && dy == 0) || (!eightOutside && dx != 0 && dy != 0)) continue;
        final xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= pw || yy >= ph) continue;
        final j = yy * pw + xx;
        if (out[j] || inRegion(xx, yy)) continue;
        out[j] = true;
        stack.add(j);
      }
    }
  }
  return [
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++) !out[(y + 1) * pw + x + 1],
  ];
}

/// A grey image of [w] × [h] pixels with sensor noise and no vegetation.
Uint8List paving(int w, int h, {int seed = 3}) {
  final rnd = math.Random(seed);
  final out = Uint8List(4 * w * h);
  for (var i = 0; i < w * h; i++) {
    final l = 130 + rnd.nextInt(17) - 8;
    out[4 * i] = l + 2;
    out[4 * i + 1] = l;
    out[4 * i + 2] = l - 3;
    out[4 * i + 3] = 255;
  }
  return out;
}

void main() {
  final scene = AerialScene();
  final rgba = scene.rgba();
  final im = VegetationImage.fromPixels(rgba, scene.width, scene.height, scene.corners());
  final r = detectVegetation(im, VegetationOptions());
  final treeArea = [AerialScene.circleArea(AerialScene.treeInLawn.$2), for (final t in AerialScene.trees) AerialScene.circleArea(t.$2)];

  group('the synthetic garden', () {
    test('working raster: 10 cm pixels, an automatic threshold between paving and lawn', () {
      expect(im.width, scene.width);
      expect(im.height, scene.height);
      expect(im.pixelSizeM, closeTo(0.1, 1e-9));
      expect(im.validCount, im.width * im.height);
      expect(im.autoThreshold, inInclusiveRange(0.08, 0.2));
      expect(im.separability, greaterThan(0.8));
      expect(r.messages, isEmpty, reason: '${r.messages}');
    });

    test('two lawns and three tree crowns, the areas within a few per cent', () {
      expect(r.of(VegetationClass.turf), hasLength(2));
      expect(r.of(VegetationClass.trees), hasLength(3));
      final a = patchAt(r, VegetationClass.turf, const Pt(6, 6));
      expect(a.grossArea, within(384, 0.02));
      expect(a.area, within(384 - 12 - treeArea[0], 0.03));
      final b = patchAt(r, VegetationClass.turf, const Pt(44, 6));
      expect(b.grossArea, within(AerialScene.lawnBArea, 0.02));
      expect(b.holes, isEmpty);
      for (final (k, (c, _)) in [AerialScene.treeInLawn, ...AerialScene.trees].indexed) {
        final t = patchAt(r, VegetationClass.trees, c);
        expect(t.grossArea, within(treeArea[k], 0.08), reason: 'crown $k');
        expect(polygonCentroid(t.outline).distanceTo(c), lessThan(0.15));
        expect(t.meanIndex, greaterThan(r.threshold));
        expect(t.touchesEdge, isFalse);
      }
      // the outlines are counter-clockwise and simplified
      for (final p in r.patches) {
        expect(polygonArea(p.outline), greaterThan(0));
        expect(p.outline.length, lessThan(40));
      }
      expect(a.outline, hasLength(4), reason: 'a rectangle comes out as four corners');
    });

    test('holes: the patio is an exclusion of lawn A, the crown in it a nested area', () {
      final a = patchAt(r, VegetationClass.turf, const Pt(6, 6));
      expect(a.holes, hasLength(2));
      final patio = a.holes.singleWhere((h) => h.exclusion);
      expect(patio.area, within(12, 0.05));
      expect(pointInPolygon(polygonCentroid(AerialScene.patio), patio.outline), isTrue);
      final crown = a.holes.singleWhere((h) => !h.exclusion);
      expect(pointInPolygon(AerialScene.treeInLawn.$1, crown.outline), isTrue);
      expect(crown.area, within(patchAt(r, VegetationClass.trees, AerialScene.treeInLawn.$1).grossArea, 0.05));
      expect(r.exclusions, hasLength(1));
    });

    test('shade on a lawn stays turf; paving, soil, the pool and the tree shadow are not vegetation', () {
      final b = patchAt(r, VegetationClass.turf, const Pt(39, 16));
      expect(pointInPolygon(const Pt(44, 16), b.outline), isTrue, reason: 'the sunny and the shaded half are one lawn');
      for (final p in [polygonCentroid(AerialScene.soil), polygonCentroid(AerialScene.pool), const Pt(39.5, 26.4), const Pt(20, 32), const Pt(30, 2)]) {
        expect(r.patches.where((x) => pointInPolygon(p, x.outline)), isEmpty, reason: '$p');
      }
      // vegetation: the two lawns, the crowns and the speck (≈ 32 % of the view)
      final expected = (384 - 12 + AerialScene.lawnBArea + treeArea.skip(1).fold(0.0, (s, a) => s + a) + 2.25) / (48 * 36);
      expect(r.vegetatedFraction, within(expected, 0.05));
    });

    test('the green speck of 2.25 m² is under the minimum area; a lower minimum keeps it', () {
      final speck = polygonCentroid(AerialScene.speck);
      expect(r.patches.where((x) => pointInPolygon(speck, x.outline)), isEmpty);
      expect(r.dropped, greaterThanOrEqualTo(1));
      final at = (r.height - 1 - (speck.y / 0.1).floor()) * r.width + (speck.x / 0.1).floor();
      expect(r.pixels[at], VegetationPixel.leftOut);
      final low = detectVegetation(im, VegetationOptions(minAreaM2: 1));
      expect(patchAt(low, VegetationClass.turf, speck).grossArea, within(2.25, 0.15));
      // a minimum above lawn B leaves lawn A only
      final high = detectVegetation(im, VegetationOptions(minAreaM2: 200));
      expect(high.patches, hasLength(1));
      expect(high.patches.single.grossArea, within(384, 0.02));
    });

    test('lawns only: the crown in lawn A becomes an exclusion, the crowns on paving go', () {
      final lawns = detectVegetation(im, VegetationOptions(keepTrees: false));
      expect(lawns.patches.map((p) => p.cls).toSet(), {VegetationClass.turf});
      expect(lawns.patches, hasLength(2));
      final a = patchAt(lawns, VegetationClass.turf, const Pt(6, 6));
      expect(a.holes.where((h) => h.exclusion), hasLength(2));
      final trees = detectVegetation(im, VegetationOptions(keepTurf: false));
      expect(trees.patches, hasLength(3));
      expect(trees.patches.every((p) => p.cls == VegetationClass.trees), isTrue);
    });

    test('without the split every patch is vegetation and the crown is part of lawn A', () {
      final all = detectVegetation(im, VegetationOptions(split: false));
      expect(all.patches.map((p) => p.cls).toSet(), {VegetationClass.vegetation});
      expect(all.patches, hasLength(4));
      final a = patchAt(all, VegetationClass.vegetation, const Pt(6, 6));
      expect(a.holes, hasLength(1));
      expect(a.area, within(384 - 12, 0.02));
    });

    test('the tree limit moves the split: a large bias takes the crowns for turf', () {
      final none = detectVegetation(im, VegetationOptions(treeBias: 2));
      expect(none.of(VegetationClass.trees), isEmpty);
      final more = detectVegetation(im, VegetationOptions(treeBias: -0.2));
      expect(more.areaOf(VegetationClass.trees), greaterThanOrEqualTo(r.areaOf(VegetationClass.trees)));
    });

    test('the threshold offset: lower takes in more, higher less', () {
      final low = detectVegetation(im, VegetationOptions(thresholdOffset: -0.05));
      final high = detectVegetation(im, VegetationOptions(thresholdOffset: 0.1));
      expect(low.threshold, closeTo(r.threshold - 0.05, 1e-9));
      expect(low.vegetatedFraction, greaterThanOrEqualTo(r.vegetatedFraction));
      expect(high.vegetatedFraction, lessThan(r.vegetatedFraction));
      // far above every green: nothing
      final none = detectVegetation(im, VegetationOptions(thresholdOffset: 2));
      expect(none.patches, isEmpty);
      expect(none.messages.map((m) => m.code), contains('veg_fewPixels'));
    });

    test('simplification: a larger tolerance, fewer vertices, the outline within it', () {
      final raw = detectVegetation(im, VegetationOptions(simplifyM: 0));
      final coarse = detectVegetation(im, VegetationOptions(simplifyM: 0.6));
      for (final c in [AerialScene.trees.first.$1, const Pt(44, 6)]) {
        final cls = c == const Pt(44, 6) ? VegetationClass.turf : VegetationClass.trees;
        final p0 = patchAt(raw, cls, c), p1 = patchAt(r, cls, c), p2 = patchAt(coarse, cls, c);
        expect(p0.outline.length, greaterThan(p1.outline.length));
        expect(p1.outline.length, greaterThanOrEqualTo(p2.outline.length));
        // every vertex of the detailed outline lies within the tolerance of
        // the simplified one (plus the area-keeping offset of a pixel)
        expect(farthest(p0.outline, p1.outline), lessThan(0.25 + 0.1));
        expect(farthest(p0.outline, p2.outline), lessThan(0.6 + 0.1));
        // the area is kept
        expect(p2.grossArea, within(p0.grossArea, 0.02));
      }
      // no smoothing: the raw marching squares outline, vertices on the
      // middles of the pixel edges
      final stair = detectVegetation(im, VegetationOptions(simplifyM: 0, smoothing: 0));
      final b = patchAt(stair, VegetationClass.turf, const Pt(44, 6));
      for (final p in b.outline) {
        final fx = (p.x / 0.1 * 2).round(), fy = (p.y / 0.1 * 2).round();
        expect((p.x / 0.1 * 2 - fx).abs() + (p.y / 0.1 * 2 - fy).abs(), lessThan(1e-6), reason: '$p');
      }
    });

    test('a rotated placement maps every outline through the corners', () {
      const origin = Pt(1000, -250);
      const rot = 30.0;
      final turned = VegetationImage.fromPixels(rgba, scene.width, scene.height, scene.corners(origin: origin, rotationDeg: rot));
      expect(turned.pixelSizeM, closeTo(0.1, 1e-9));
      final t = detectVegetation(turned, VegetationOptions());
      expect(t.patches, hasLength(r.patches.length));
      for (var k = 0; k < r.patches.length; k++) {
        final a = r.patches[k], b = t.patches[k];
        expect(b.cls, a.cls);
        expect(b.grossArea, closeTo(a.grossArea, a.grossArea * 1e-6));
        expect(b.area, closeTo(a.area, a.area * 1e-6 + 1e-9));
        expect(polygonCentroid(b.outline).distanceTo(AerialScene.place(polygonCentroid(a.outline), origin: origin, rotationDeg: rot)), lessThan(1e-6));
        expect(b.holes.length, a.holes.length);
      }
      expect(patchAt(t, VegetationClass.turf, const Pt(6, 6), origin: origin, rotationDeg: rot).grossArea, within(384, 0.02));
      // raster position of a world point and back
      final (u, v) = turned.toUnit(turned.toWorld(120.5, 33.25));
      expect(u * turned.width, closeTo(120.5, 1e-9));
      expect(v * turned.height, closeTo(33.25, 1e-9));
    });

    test('any quadrilateral: the bilinear map and its inverse agree', () {
      final quad = [const Pt(0, 0), const Pt(50, 3), const Pt(47, 41), const Pt(-4, 35)];
      final q = VegetationImage.fromPixels(rgba, scene.width, scene.height, quad);
      for (final (x, y) in [(0.0, 0.0), (480.0, 360.0), (13.5, 200.25), (400.0, 7.0)]) {
        final (u, v) = q.toUnit(q.toWorld(x, y));
        expect(u, closeTo(x / q.width, 1e-9));
        expect(v, closeTo(y / q.height, 1e-9));
      }
      expect(q.toWorld(0, 0), quad[3]);
      expect(q.toWorld(480, 360), quad[1]);
      expect(q.pixelAreaM2, closeTo(polygonArea(quad).abs() / (480 * 360), 1e-12));
    });

    test('PNG and JPEG decode to the same patches', () {
      final image = img.Image.fromBytes(width: scene.width, height: scene.height, bytes: rgba.buffer, numChannels: 4);
      final png = VegetationImage.fromEncoded(img.encodePng(image), scene.corners());
      final pr = detectVegetation(png, VegetationOptions());
      expect(pr.patches, hasLength(r.patches.length));
      for (var k = 0; k < r.patches.length; k++) {
        expect(pr.patches[k].grossArea, closeTo(r.patches[k].grossArea, 1e-9));
      }
      final jpeg = VegetationImage.fromEncoded(img.encodeJpg(image, quality: 80), scene.corners());
      final jr = detectVegetation(jpeg, VegetationOptions());
      expect(jr.of(VegetationClass.turf), hasLength(2));
      expect(jr.of(VegetationClass.trees), hasLength(3));
      expect(patchAt(jr, VegetationClass.turf, const Pt(6, 6)).grossArea, within(384, 0.03));
      expect(() => VegetationImage.fromEncoded(Uint8List.fromList([1, 2, 3, 4]), scene.corners()), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'image_unreadable')));
    });

    test('a fine or large image is averaged in blocks: the pixel budget and the finest resolution', () {
      expect(VegetationImage.blockFactor(4000, 3000, AerialScene(widthM: 40, heightM: 30, pixelM: 0.01).corners()), 5, reason: '1 cm pixels averaged to 5 cm');
      expect(VegetationImage.blockFactor(4000, 3000, AerialScene(widthM: 400, heightM: 300).corners()), 4, reason: '12 MP within 1.2 MP');
      expect(VegetationImage.workingSize(4001, 3002, AerialScene(widthM: 400, heightM: 300).corners()), (1000, 750));
      final small = VegetationImage.fromPixels(rgba, scene.width, scene.height, scene.corners(), maxPixels: 50000);
      expect(small.width, 240);
      expect(small.pixelSizeM, closeTo(0.2, 1e-9));
      final sr = detectVegetation(small, VegetationOptions());
      expect(patchAt(sr, VegetationClass.turf, const Pt(6, 6)).grossArea, within(384, 0.03));
      expect(patchAt(sr, VegetationClass.turf, const Pt(44, 6)).grossArea, within(AerialScene.lawnBArea, 0.03));
      expect(sr.of(VegetationClass.trees).length, 3);
      // the last columns that do not fill a block are cut, the corners follow
      final odd = VegetationImage.fromPixels(rgba, 479, 359, AerialScene(widthM: 47.9, heightM: 35.9).corners(), maxPixels: 50000);
      expect(odd.width, 239);
      expect(odd.corners[1].x, closeTo(47.8, 1e-9));
      expect(odd.corners[3].y, closeTo(35.9, 1e-9));
      expect(odd.corners[0].y, closeTo(0.1, 1e-9));
    });
  });

  group('a park filling the view', () {
    /// 60 × 45 m at 15 cm: pale rough all round, a lush fairway band, a sand
    /// bunker of 4.5 m radius in it ([fairway] false: rough everywhere).
    VegetationImage park({bool fairway = true, bool bunker = true}) {
      const w = 400, h = 300;
      final rnd = math.Random(5);
      final px = Uint8List(4 * w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          var c = (110, 125, 85); // rough, ExG ≈ 0.16
          if (fairway && x >= 100 && x < 300) c = (85, 150, 55); // ExG ≈ 0.5
          if (bunker && math.pow(x + 0.5 - 200, 2) + math.pow(y + 0.5 - 150, 2) <= 30 * 30) c = (200, 190, 160); // ExG ≈ 0.03
          final l = rnd.nextInt(9) - 4, k = 4 * (y * w + x);
          px[k] = c.$1 + l;
          px[k + 1] = c.$2 + l;
          px[k + 2] = c.$3 + l;
          px[k + 3] = 255;
        }
      }
      return VegetationImage.fromPixels(px, w, h, AerialScene(widthM: 60, heightM: 45).corners());
    }

    test('Otsu again below the split of two greens: both are vegetation, the bunker a hole', () {
      final im = park();
      expect(im.otsuThreshold, inInclusiveRange(0.05, 0.13), reason: 'between the sand and the rough, not between the rough and the fairway');
      final r = detectVegetation(im, VegetationOptions(split: false));
      expect(r.patches, hasLength(1));
      final p = r.patches.single;
      expect(p.touchesEdge, isTrue);
      expect(p.holes.single.exclusion, isTrue);
      expect(p.holes.single.area, within(math.pi * 4.5 * 4.5, 0.05));
      expect(p.area, within(60 * 45 - math.pi * 4.5 * 4.5, 0.01));
      expect(r.messages.map((m) => m.code), containsAll(['veg_mostlyGreen', 'veg_edge']));
      expect(r.messages.map((m) => m.code), isNot(contains('veg_lowContrast')), reason: 'the bunker stands out of the grass');
    });

    test('all lawn: the lower limit, one patch over the whole view', () {
      final im = park(fairway: false, bunker: false);
      expect(im.autoThreshold, VegetationImage.autoThresholdRange.$1);
      final r = detectVegetation(im, VegetationOptions());
      expect(r.patches.single.cls, VegetationClass.turf);
      expect(r.patches.single.grossArea, within(60 * 45, 0.005));
      expect(r.vegetatedFraction, 1);
    });
  });

  group('notes', () {
    test('no georeference, a small image, coarse pixels', () {
      expect(detectVegetation(im, VegetationOptions(), georeferenced: false).messages.map((m) => m.code), contains('veg_noGeoref'));
      final tiny = AerialScene(widthM: 4, heightM: 3);
      final t = detectVegetation(VegetationImage.fromPixels(tiny.rgba(), tiny.width, tiny.height, tiny.corners()), VegetationOptions());
      expect(t.messages.map((m) => m.code), contains('veg_imageSmall'));
      final coarse = AerialScene(pixelM: 1.5);
      final c = detectVegetation(VegetationImage.fromPixels(coarse.rgba(), coarse.width, coarse.height, coarse.corners()), VegetationOptions());
      expect(c.messages.where((m) => m.code == 'veg_coarse').single.args['m'], '1.5');
    });

    test('tiles missing on the right: no data there, the lawn cut by it reaches the edge', () {
      final part = scene.rgba(transparentRight: 0.25);
      final pi = VegetationImage.fromPixels(part, scene.width, scene.height, scene.corners());
      expect(pi.validCount, closeTo(0.75 * scene.width * scene.height, scene.height));
      final pr = detectVegetation(pi, VegetationOptions());
      final codes = pr.messages.map((m) => m.code);
      expect(codes, containsAll(['veg_noData', 'veg_edge']));
      final b = patchAt(pr, VegetationClass.turf, const Pt(34, 5));
      expect(b.touchesEdge, isTrue);
      expect(b.outline.every((p) => p.x <= 36 + 0.15), isTrue);
      expect(pr.pixels.last, VegetationPixel.noData);
      // a crown wholly in the part without data is not there
      expect(pr.patches.where((x) => pointInPolygon(AerialScene.trees.last.$1, x.outline)), isEmpty);
    });

    test('no vegetation at all: few pixels, low contrast, no patch', () {
      final p = detectVegetation(VegetationImage.fromPixels(paving(200, 150), 200, 150, AerialScene(widthM: 20, heightM: 15).corners()), VegetationOptions());
      expect(p.patches, isEmpty);
      expect(p.messages.map((m) => m.code), containsAll(['veg_fewPixels', 'veg_lowContrast']));
    });

    test('too many patches: the largest are kept', () {
      final few = detectVegetation(im, VegetationOptions(maxPatches: 2));
      expect(few.patches, hasLength(2));
      expect(few.patches.first.grossArea, greaterThan(few.patches.last.grossArea));
      expect(few.messages.where((m) => m.code == 'veg_tooMany').single.args, {'n': '5', 'max': '2'});
    });
  });

  group('into the design', () {
    test('areas named per class going on from the drawing, presets, exclusions on the drawing layer', () {
      final p = Project();
      p.entities.add(AreaEntity(id: p.newId(), points: sceneRect(0, 0, 1, 1), name: 'Gramado 2'));
      final out = vegetationEntities(p, r.patches, name: (c) => c == VegetationClass.turf ? 'Gramado' : 'Arbustos', exclusionName: (a, n) => 'Exclusão $n ($a)');
      final areas = out.whereType<AreaEntity>().toList();
      expect(areas.map((a) => a.name), ['Gramado 3', 'Gramado 4', 'Arbustos 1', 'Arbustos 2', 'Arbustos 3']);
      expect(areas.every((a) => a.layer == Layers.areas), isTrue);
      final lawn = areas.first;
      expect(lawn.points, r.patches.first.outline);
      expect(lawn.area, closeTo(r.patches.first.grossArea, 1e-9));
      expect(lawn.crop, 'Gramado');
      expect(lawn.kc, 0.85);
      expect(lawn.irrigationMethod, 'sprinkler');
      expect(lawn.plantWaterUse, 'high');
      final shrubs = areas.last;
      expect(shrubs.irrigationMethod, 'localized');
      expect(shrubs.plantWaterUse, 'moderate');
      expect(shrubs.wettedFraction, 0.5);
      final ex = out.whereType<PolylineEntity>().single;
      expect(ex.closed, isTrue);
      expect(ex.layer, Layers.drawing);
      expect(ex.name, 'Exclusão 1 (Gramado 3)');
      expect(polygonArea(ex.points).abs(), within(12, 0.05));
      expect(out.map((e) => e.id).toSet(), hasLength(out.length));
      expect(p.findLayer(Layers.areas), isNotNull);
      // without exclusions: the areas only
      expect(vegetationEntities(p, r.patches, name: (c) => c.name, exclusionName: (a, n) => '', exclusions: false).whereType<PolylineEntity>(), isEmpty);
    });

    test('the preview raster tints the classes', () {
      final (px, w, h) = vegetationPreview(im, r, maxSide: 240);
      expect((w, h), (240, 180));
      expect(px.length, 4 * w * h);
      // the middle of lawn A (scene (16, 15)) is tinted light green: greener than the photo
      final row = ((36 - 15) / 0.2).floor(), col = (16 / 0.2).floor();
      final i = 4 * (row * w + col), src = 3 * (2 * row * im.width + 2 * col);
      expect(px[i + 1], greaterThan(im.rgb[src + 1]));
      expect(px[i + 3], 255);
    });
  });

  test('marching squares: the outline of every region holds exactly the pixels it encloses', () {
    final rnd = math.Random(11);
    var regions = 0;
    for (var it = 0; it < 400; it++) {
      final w = 1 + rnd.nextInt(13), h = 1 + rnd.nextInt(13);
      final density = 0.2 + 0.6 * rnd.nextDouble();
      final mask = [for (var i = 0; i < w * h; i++) rnd.nextDouble() < density];
      for (final eight in [true, false]) {
        final l = labelsOf(mask, w, h, eight: eight);
        for (final id in {
          for (final v in l)
            if (v > 0) v,
        }) {
          final region = [for (final v in l) v == id];
          final first = region.indexOf(true);
          final ring = rasterRegionOutline(w, h, (i) => l[i] == id, first % w, first ~/ w, eightConnected: eight);
          final poly = [for (var k = 0; k < ring.length; k += 2) Pt(ring[k], ring[k + 1])];
          // the rest of the raster moves with the other connectivity
          final inside = enclosed(region, w, h, eightOutside: !eight);
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              expect(pointInPolygon(Pt(x + 0.5, y + 0.5), poly), inside[y * w + x], reason: 'it $it, ${eight ? 8 : 4}-connected region $id, pixel ($x, $y)');
            }
          }
          expect(poly.map((p) => '${p.x},${p.y}').toSet(), hasLength(poly.length), reason: 'no vertex twice');
          regions++;
        }
      }
    }
    expect(regions, greaterThan(2000));
    // one pixel: a diamond of half a pixel
    final one = rasterRegionOutline(3, 3, (i) => i == 4, 1, 1, eightConnected: true);
    expect(polygonArea([for (var k = 0; k < one.length; k += 2) Pt(one[k], one[k + 1])]).abs(), 0.5);
  });
}
