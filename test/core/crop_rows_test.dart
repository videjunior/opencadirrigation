// every test reads one or more fields of a third of a megapixel: more than
// the default 30 s when the machine is busy
@Timeout(Duration(minutes: 4))
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/crop_rows.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Colours of the synthetic fields (R, G, B).
const _soil = (152.0, 108.0, 74.0), _canopy = (45.0, 88.0, 38.0);

/// A field of rows drawn from the world: rows along [dirDeg] (counter-
/// clockwise from east) every [spacing] m, their centres on the lines
/// p·n = [offset] + k·spacing (n = (−sin θ, cos θ)), a canopy band
/// [canopy] × spacing wide (or, with [plantSpacing], elliptic crowns of
/// [crown] × plantSpacing along the row, staggered from row to row), plants
/// missing at random with [missing], uniform noise of ±[noise] grey levels;
/// [rows] false paints soil only and [blobs] random round crowns instead.
CropRowRaster field({
  double dirDeg = 0,
  double spacing = 3,
  double mpp = 0.25,
  int w = 600,
  int h = 500,
  double canopy = 0.45,
  double noise = 20,
  double offset = 0.37,
  double missing = 0,
  double plantSpacing = 0,
  double crown = 0.8,
  bool rows = true,
  int blobs = 0,
  (double, double, double) canopyColour = _canopy,
  (double, double, double) gapColour = _soil,
  int seed = 1,
  double x0 = 1000,
  double y0 = -500,
  double? imageryPixelM,
}) {
  final rnd = math.Random(seed);
  final world = Bounds(x0, y0, x0 + w * mpp, y0 + h * mpp);
  final px = Uint8List(w * h * 4);
  final th = dirDeg * math.pi / 180;
  final d = Pt(math.cos(th), math.sin(th)), n = Pt(-math.sin(th), math.cos(th));
  // the random crowns painted first, each over its own box of pixels
  final crowned = Uint8List(w * h);
  for (var i = 0; i < blobs; i++) {
    final c = Pt(world.minX + rnd.nextDouble() * world.width, world.minY + rnd.nextDouble() * world.height);
    final r = 1 + 3 * rnd.nextDouble();
    final px0 = math.max(0, ((c.x - r - world.minX) / mpp).floor()), px1 = math.min(w - 1, ((c.x + r - world.minX) / mpp).ceil());
    final py0 = math.max(0, ((world.maxY - c.y - r) / mpp).floor()), py1 = math.min(h - 1, ((world.maxY - c.y + r) / mpp).ceil());
    for (var y = py0; y <= py1; y++) {
      for (var x = px0; x <= px1; x++) {
        if (Pt(world.minX + (x + 0.5) * mpp, world.maxY - (y + 0.5) * mpp).distanceTo(c) <= r) crowned[y * w + x] = 1;
      }
    }
  }
  for (var j = 0; j < h; j++) {
    for (var i = 0; i < w; i++) {
      final q = Pt(world.minX + (i + 0.5) * mpp, world.maxY - (j + 0.5) * mpp);
      var inCanopy = false;
      if (rows) {
        final u = q.dot(n) - offset;
        final k = (u / spacing).round();
        final du = (u - k * spacing).abs();
        final half = canopy * spacing / 2;
        if (plantSpacing <= 0) {
          inCanopy = du <= half;
          if (inCanopy && missing > 0 && math.Random(k * 100003 + (q.dot(d) / 2).floor()).nextDouble() < missing) inCanopy = false;
        } else {
          final t = q.dot(d) + (k.isOdd ? plantSpacing / 2 : 0);
          final m = (t / plantSpacing).round();
          final dt = (t - m * plantSpacing).abs();
          final r = crown * plantSpacing / 2;
          final gone = missing > 0 && math.Random(k * 100003 + m).nextDouble() < missing;
          inCanopy = !gone && (du / half) * (du / half) + (dt / r) * (dt / r) <= 1;
        }
      }
      if (crowned[j * w + i] == 1) inCanopy = true;
      final (r, g, b) = inCanopy ? canopyColour : gapColour;
      final l = (rnd.nextDouble() * 2 - 1) * noise;
      int ch(double v) => (v + l + (rnd.nextDouble() * 2 - 1) * noise * 0.3).round().clamp(0, 255);
      final o = 4 * (j * w + i);
      px[o] = ch(r);
      px[o + 1] = ch(g);
      px[o + 2] = ch(b);
      px[o + 3] = 255;
    }
  }
  return CropRowRaster(px, w, h, world, imageryPixelM: imageryPixelM);
}

List<Pt> rect(Bounds b, [double inset = 2]) => [Pt(b.minX + inset, b.minY + inset), Pt(b.maxX - inset, b.minY + inset), Pt(b.maxX - inset, b.maxY - inset), Pt(b.minX + inset, b.maxY - inset)];

/// Smallest difference between two line directions (degrees, mod 180).
double angleError(double a, double b) {
  final d = (a - b).abs() % 180;
  return math.min(d, 180 - d);
}

/// Largest distance (in spacings) from a row line found to the nearest true
/// row centre (p·n = offset + k·spacing, n across [dirDeg]), measured at the
/// middle of every piece of row in the field. (Not from the offsets: they
/// are counted from the world origin along the normal found, which a
/// thousandth of a degree turns by metres at coordinates of millions.)
double phaseError(CropRowResult r, double dirDeg, double offset, double spacing) {
  final th = dirDeg * math.pi / 180;
  final n = Pt(-math.sin(th), math.cos(th));
  var worst = 0.0;
  for (final l in r.rowLines) {
    final f = (Pt.lerp(l[0], l[1], 0.5).dot(n) - offset) / spacing;
    worst = math.max(worst, (f - f.round()).abs());
  }
  return worst;
}

/// The rows of a field as the truth gives them: lines with at least
/// max(1 m, half a spacing) inside the outline.
int trueRows(List<Pt> outline, List<List<Pt>> holes, double dirDeg, double spacing, double offset) => cropRowLines(outline, holes, dirDeg, spacing, offset).$1.length;

/// Accuracy asked of the reading (the brief: ±1° and ±3 % of the spacing).
const maxAngleError = 1.0, maxSpacingError = 0.03;

void main() {
  group('direction and spacing of synthetic fields', () {
    for (final (dir, sp) in const [(0.0, 3.0), (12.3, 3.5), (45.0, 4.0), (89.6, 2.5), (90.0, 3.0), (133.7, 6.0), (171.2, 7.5), (178.9, 2.0), (60.0, 10.0)]) {
      test('rows at $dir° every $sp m', () async {
        final im = field(dirDeg: dir, spacing: sp);
        final outline = rect(im.world);
        final r = await detectCropRows(im, outline);
        expect(r.verdict, CropRowVerdict.rows);
        expect(angleError(r.directionDeg, dir), lessThan(maxAngleError));
        expect((r.spacingM - sp).abs() / sp, lessThan(maxSpacingError));
        // in fact far closer on clean straight rows
        expect(angleError(r.directionDeg, dir), lessThan(0.1));
        expect((r.spacingM - sp).abs() / sp, lessThan(0.002));
        expect(r.directionDeg, inInclusiveRange(0, 180));
        expect(r.confidence, greaterThan(0.9));
        expect(phaseError(r, dir, 0.37, sp), lessThan(0.08), reason: 'the lines lie on the canopy bands');
        expect((r.rows - trueRows(outline, const [], dir, sp, 0.37)).abs(), lessThanOrEqualTo(1));
        expect(r.groundCover, isNotNull);
        expect(r.groundCover!, closeTo(0.45, 0.05));
        expect(r.plantSpacingM, isNull, reason: 'a hedgerow has no plant spacing to see');
      });
    }

    test('heavy noise, missing plants, an irregular outline with a hole, rows not through the origin, far coordinates', () async {
      const dir = 23.4, sp = 3.6, offset = 1.234;
      final im = field(dirDeg: dir, spacing: sp, noise: 60, missing: 0.3, offset: offset, x0: 512345, y0: 7456789, w: 640, h: 560, seed: 7);
      final b = im.world;
      // an L-shaped field with a square hole
      final outline = [Pt(b.minX + 5, b.minY + 5), Pt(b.maxX - 5, b.minY + 5), Pt(b.maxX - 5, b.minY + 70), Pt(b.minX + 80, b.minY + 70), Pt(b.minX + 80, b.maxY - 5), Pt(b.minX + 5, b.maxY - 5)];
      final hole = [Pt(b.minX + 30, b.minY + 30), Pt(b.minX + 55, b.minY + 30), Pt(b.minX + 55, b.minY + 55), Pt(b.minX + 30, b.minY + 55)];
      final r = await detectCropRows(im, outline, holes: [hole]);
      expect(r.verdict, CropRowVerdict.rows);
      expect(angleError(r.directionDeg, dir), lessThan(maxAngleError));
      expect((r.spacingM - sp).abs() / sp, lessThan(maxSpacingError));
      expect(phaseError(r, dir, offset, sp), lessThan(0.1));
      expect((r.rows - trueRows(outline, [hole], dir, sp, offset)).abs(), lessThanOrEqualTo(1));
      // no row line crosses the hole
      for (final l in r.rowLines) {
        expect(pointInPolygon(Pt.lerp(l[0], l[1], 0.5), hole), isFalse);
        expect(pointInPolygon(Pt.lerp(l[0], l[1], 0.5), outline), isTrue);
      }
    });

    test('an orchard of separate crowns: rows, plant spacing and ground cover', () async {
      const dir = 27.0, sp = 6.0, ps = 3.0;
      final im = field(dirDeg: dir, spacing: sp, plantSpacing: ps, crown: 0.85, canopy: 0.6, missing: 0.05);
      final r = await detectCropRows(im, rect(im.world));
      expect(r.verdict, CropRowVerdict.rows);
      expect(angleError(r.directionDeg, dir), lessThan(maxAngleError));
      expect((r.spacingM - sp).abs() / sp, lessThan(maxSpacingError));
      expect(r.plantSpacingM, isNotNull);
      expect((r.plantSpacingM! - ps).abs() / ps, lessThan(0.05));
      expect(r.plantPeriodicity, greaterThanOrEqualTo(plantPeriodicityMin));
      // crowns: ellipses of π/4 · 0.6 · 0.85 of the cell, 5 % missing
      expect(r.groundCover!, closeTo(math.pi / 4 * 0.6 * 0.85 * 0.95, 0.04));
    });

    test('ground cover follows the width of the canopy band', () async {
      for (final cover in const [0.25, 0.65]) {
        final im = field(dirDeg: 35, spacing: 4, canopy: cover);
        final r = await detectCropRows(im, rect(im.world));
        expect(r.groundCover, isNotNull, reason: '$cover');
        expect(r.groundCover!, closeTo(cover, 0.05), reason: '$cover');
      }
    });

    test('a closed canopy whose narrow alleys lie in its shade: the rows are the wide sunlit band', () async {
      const dir = 75.0, sp = 5.0;
      // the canopy band (70 % of the spacing) lit, the alleys shaded: darker and greener
      final im = field(dirDeg: dir, spacing: sp, canopy: 0.3, canopyColour: (18, 48, 22), gapColour: (88, 128, 60), offset: 0.5);
      final r = await detectCropRows(im, rect(im.world));
      expect(r.verdict, CropRowVerdict.rows);
      // the narrow dark bands are centred on 0.5 + k·5: the rows half a spacing over
      expect(phaseError(r, dir, 0.5 + sp / 2, sp), lessThan(0.08));
      expect(r.swapped, isTrue);
      expect(r.bandShare, closeTo(0.7, 0.08));
      // the other band when asked
      final other = await detectCropRows(im, rect(im.world), options: const CropRowOptions(otherBand: true));
      expect(phaseError(other, dir, 0.5, sp), lessThan(0.08));
      expect(other.swapped, isFalse);
      expect((other.rows - r.rows).abs(), lessThanOrEqualTo(1));
    });

    test('other band moves the rows half a spacing on a field of rows on soil', () async {
      final im = field(dirDeg: 110, spacing: 3.2);
      final a = await detectCropRows(im, rect(im.world));
      final b = await detectCropRows(im, rect(im.world), options: const CropRowOptions(otherBand: true));
      expect(phaseError(a, 110, 0.37, 3.2), lessThan(0.08));
      expect(phaseError(b, 110, 0.37 + 1.6, 3.2), lessThan(0.08));
      expect(b.groundCover, isNotNull);
      expect(b.groundCover!, closeTo(1 - a.groundCover!, 0.02), reason: 'the canopy is the other class');
    });
  });

  group('fields without rows', () {
    test('bare soil with noise: no rows', () async {
      final im = field(rows: false, noise: 30);
      final r = await detectCropRows(im, rect(im.world));
      expect(r.verdict, CropRowVerdict.none);
      expect(r.confidence, lessThan(confidenceUncertain));
      expect(r.rowLines, isEmpty);
      expect(r.messages.map((m) => m.code), contains('noRows'));
    });

    test('scattered round crowns (a closed or random canopy): no rows', () async {
      for (final seed in const [3, 4]) {
        final im = field(rows: false, blobs: 900, noise: 15, seed: seed);
        final r = await detectCropRows(im, rect(im.world));
        expect(r.confidence, lessThan(confidenceUncertain), reason: 'seed $seed: ${r.verdict} ${r.confidence}');
        expect(r.found, isFalse);
      }
    });

    test('a flat image: nothing to read', () async {
      final im = field(rows: false, noise: 0);
      final r = await detectCropRows(im, rect(im.world));
      expect(r.verdict, CropRowVerdict.noData);
      expect(r.messages.map((m) => m.code), contains('flat'));
    });

    test('imagery too coarse for the rows: said, and no rows read', () async {
      // rows 2 m apart in imagery of 1 m a pixel (upsampled to 0.25 m)
      final im = field(dirDeg: 30, spacing: 2, imageryPixelM: 1.0);
      final r = await detectCropRows(im, rect(im.world));
      expect(r.found, isFalse);
      expect(r.messages.map((m) => m.code), contains('coarse'));
      final coarse = r.messages.firstWhere((m) => m.code == 'coarse');
      expect(coarse.args['s'], closeTo(3, 1e-9), reason: 'three pixels of the imagery');
    });

    test('an outline outside the image, a tiny field, a degenerate outline', () async {
      final im = field(dirDeg: 0, spacing: 3);
      final far = rect(Bounds(im.world.maxX + 100, im.world.maxY + 100, im.world.maxX + 200, im.world.maxY + 200));
      expect((await detectCropRows(im, far)).verdict, CropRowVerdict.noData);
      final c = im.world.center;
      // 8 m across: too small for rows from 3 m (it must hold 2.5 of the widest searched)
      final tiny = [c, c + const Pt(8, 0), c + const Pt(8, 8), c + const Pt(0, 8)];
      final small = await detectCropRows(im, tiny, options: const CropRowOptions(minSpacingM: 3, maxSpacingM: 12));
      expect(small.verdict, CropRowVerdict.noData);
      expect(small.messages.map((m) => m.code), contains('tooSmall'));
      expect((await detectCropRows(im, [c, c + const Pt(1, 1), c + const Pt(2, 2)])).verdict, CropRowVerdict.noData);
    });
  });

  test('stops when asked, and says how far it got', () async {
    final im = field(dirDeg: 10, spacing: 3);
    var calls = 0;
    await expectLater(detectCropRows(im, rect(im.world), cancelled: () => ++calls > 1), throwsA(isA<CropRowsCancelled>()));
    final seen = <double>[];
    await detectCropRows(im, rect(im.world), progress: seen.add);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
    expect(seen.every((p) => p >= 0 && p <= 1), isTrue);
  });

  group('frame', () {
    final small = [const Pt(0, 0), const Pt(200, 0), const Pt(200, 150), const Pt(0, 150)];
    test('a small field at six pixels to the closest spacing, or at the imagery\'s own pixel', () {
      final f = cropRowFrame(small, const CropRowOptions(minSpacingM: 1.5));
      expect(f.window, isFalse);
      expect(f.pixelM, closeTo(0.25, 1e-9));
      expect(f.world.minX, lessThan(0));
      expect(f.world.maxX, greaterThan(200));
      expect(cropRowFrame(small, const CropRowOptions(minSpacingM: 1.5), imageryPixelM: 0.6).pixelM, 0.6);
    });

    test('a larger field coarser, up to a quarter of the closest spacing; beyond, a window inside it', () {
      final mid = [const Pt(0, 0), const Pt(500, 0), const Pt(500, 450), const Pt(0, 450)];
      final f = cropRowFrame(mid, const CropRowOptions(minSpacingM: 1.5));
      expect(f.window, isFalse);
      expect(f.pixelM, greaterThan(0.25));
      expect(f.pixelM, lessThanOrEqualTo(1.5 / 4));
      expect(f.width * f.height, lessThanOrEqualTo(cropRowMaxPixels * 1.01));
      // an L-shaped field of 2 km: a window round its widest inner point
      final big = [const Pt(0, 0), const Pt(2000, 0), const Pt(2000, 400), const Pt(400, 400), const Pt(400, 2000), const Pt(0, 2000)];
      final w = cropRowFrame(big, const CropRowOptions(minSpacingM: 1.5));
      expect(w.window, isTrue);
      expect(w.pixelM, closeTo(0.25, 1e-9));
      expect(w.width * w.height, lessThanOrEqualTo(cropRowMaxPixels * 1.01));
      expect(math.max(w.width, w.height), lessThanOrEqualTo(cropRowMaxSide + 1));
      expect(pointInPolygon(w.world.center, big), isTrue);
    });
  });

  test('row lines: clipped to the outline and its holes, short pieces not counted', () {
    final outline = [const Pt(0, 0), const Pt(100, 0), const Pt(100, 50), const Pt(0, 50)];
    final hole = [const Pt(40, 10), const Pt(60, 10), const Pt(60, 40), const Pt(40, 40)];
    // rows along x every 5 m from y = 2.5
    final (offsets, lines) = cropRowLines(outline, [hole], 0, 5, 2.5);
    expect(offsets, [2.5, 7.5, 12.5, 17.5, 22.5, 27.5, 32.5, 37.5, 42.5, 47.5]);
    // the rows between y 10 and 40 are cut in two by the hole
    expect(lines.length, 10 + 6);
    final cut = rowSegments(outline, [hole], 0, [20]);
    expect(cut.length, 2);
    for (final (seg, (x0, x1)) in [(cut[0], (0.0, 40.0)), (cut[1], (60.0, 100.0))]) {
      expect(seg[0].x, closeTo(x0, 1e-9));
      expect(seg[1].x, closeTo(x1, 1e-9));
      expect(seg[0].y, closeTo(20, 1e-9));
    }
    // a line that only grazes a corner is not a row
    final tri = [const Pt(0, 0), const Pt(10, 0), const Pt(0, 10)];
    // rows along y (90°) at x = 1, 5, 9: p·n = −x
    expect(cropRowLines(tri, const [], 90, 4, 3).$1.map((v) => v.round()), [-5, -1], reason: 'x = 9 cuts 1 m, under half the spacing: no row');
  });

  group('the project', () {
    test('apply sets the area\'s rows, ground cover and guide lines; the row direction is kept, turned and mirrored with the area', () async {
      final im = field(dirDeg: 33.3, spacing: 3.5);
      final outline = rect(im.world);
      final r = await detectCropRows(im, outline);
      final p = Project();
      final a = AreaEntity(id: p.newId(), points: outline);
      p.entities.add(a);
      final made = applyCropRows(p, a, r, guides: true);
      expect(a.rowDirectionDeg, closeTo(33.3, maxAngleError));
      expect(a.rowSpacingM, closeTo(3.5, 3.5 * maxSpacingError));
      expect(a.groundCover, closeTo(0.45, 0.05));
      expect(made.length, r.rowLines.length);
      expect(made.every((e) => e is LineEntity && e.layer == cropRowLayer), isTrue);
      expect(p.findLayer(cropRowLayer)?.color, cropRowLayerColor);
      expect(p.entities.length, 1 + made.length);
      expect(storedRowDirection(a)!.angle, closeTo(degToRad(a.rowDirectionDeg!), 1e-12));
      expect(storedRowSpacing(a), a.rowSpacingM);
      expect(storedPlantSpacing(a), isNull);
      expect(storedRowDirection(LineEntity(id: 'x', a: Pt.zero, b: const Pt(1, 0))), isNull);
      // the project file keeps it
      final back = Entity.fromJson(a.toJson()) as AreaEntity;
      expect(back.rowDirectionDeg, a.rowDirectionDeg);
      expect(
        AreaEntity(id: 'b', points: outline).toJson().containsKey('rdir'),
        isFalse,
        reason: 'written only when set',
      );
      expect(a.clone().rowDirectionDeg, a.rowDirectionDeg);
      // a turn of 100° turns the rows; a mirror about the x axis mirrors them
      expect(a.transformed(Affine.rotation(degToRad(100))).rowDirectionDeg, closeTo((a.rowDirectionDeg! + 100) % 180, 1e-9));
      expect(a.transformed(Affine.mirror(Pt.zero, const Pt(1, 0))).rowDirectionDeg, closeTo(180 - a.rowDirectionDeg!, 1e-9));
      expect(a.translated(const Pt(5, 5)).rowDirectionDeg, a.rowDirectionDeg);
      // only guides on an outline that is not an area
      final pl = PolylineEntity(id: p.newId(), points: outline, closed: true);
      expect(applyCropRows(p, pl, r, guides: false), isEmpty);
      // nothing from a reading without rows
      final none = await detectCropRows(field(rows: false), outline);
      expect(applyCropRows(p, a, none, guides: true), isEmpty);
    });

    test('the area a drawn block lies in', () {
      final p = Project();
      final big = AreaEntity(id: 'a', points: [const Pt(0, 0), const Pt(100, 0), const Pt(100, 100), const Pt(0, 100)]);
      final inner = AreaEntity(id: 'b', points: [const Pt(10, 10), const Pt(40, 10), const Pt(40, 40), const Pt(10, 40)]);
      p.entities.addAll([big, inner]);
      expect(areaHolding(p, [const Pt(15, 15), const Pt(20, 15), const Pt(20, 20)])?.id, 'b', reason: 'the smallest that holds it');
      expect(areaHolding(p, [const Pt(60, 60), const Pt(70, 60), const Pt(70, 70)])?.id, 'a');
      expect(areaHolding(p, [const Pt(160, 60), const Pt(170, 60), const Pt(170, 70)]), isNull);
    });

    test('the preview picture is the raster at most the size asked', () {
      final im = field(w: 300, h: 200, mpp: 0.5);
      final (px, w, h) = cropRowPreview(im, maxSide: 100);
      expect((w, h), (100, 67));
      expect(px.length, w * h * 4);
      expect(px[3], 255);
    });

    test('options keep a usable range', () {
      final o = const CropRowOptions(minSpacingM: 0.01, maxSpacingM: 0.02).sane;
      expect(o.minSpacingM, 0.3);
      expect(o.maxSpacingM, closeTo(0.45, 1e-9));
      expect(const CropRowOptions(minSpacingM: double.nan, maxSpacingM: 500).sane.maxSpacingM, 60);
    });
  });
}
