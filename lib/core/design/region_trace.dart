/// The outline of one region of an aerial image from a point inside it — a
/// field, a lawn, a pond, a roof — for the AI assistant: a model locates
/// things on a picture to a few pixels, while the edge of a field is wanted
/// to a fraction of a metre. The region is grown from the seed over the
/// pixels of similar colour and texture, at the tolerance where its area
/// stops growing (before it leaks into the next field), cleaned, and its
/// outline traced, smoothed and simplified in world metres. Plain image
/// processing, linear in the number of pixels: no service, no trained model.
///
/// The pipeline and its defaults ([RegionTraceOptions]):
///
/// 1. Features: CIE L*a*b* of every pixel (D65), averaged over a box of
///    about [RegionTraceOptions.blurM] — crop rows, furrows and the grain of
///    the imagery go, while a straight edge stays where it is — and the
///    local contrast of the lightness over the same box (rough canopy
///    against smooth turf). Transparent pixels (no imagery) are walls.
/// 2. Reference: the median features of a disc of
///    [RegionTraceOptions.seedRadiusM] around the seed; the spread of the
///    disc about it tells a seed on an edge.
/// 3. Cost: the colour difference of every pixel to the reference, in steps
///    of half a ΔE (lightness weighted 0.75: shade changes it most), and the
///    least, over the paths from the seed disc, of the largest difference
///    along the path (a priority flood on the four neighbours with a bucket
///    queue). The region at tolerance T is every pixel whose path cost is at
///    most T — the flood fill at T — for every T at once.
/// 4. Tolerance: the area against T. Past the first T that holds the seed
///    disc, the region fills its field while the area grows fast, then
///    grows slowly (a plateau: only the blended pixels of the edge join) and
///    leaks when it jumps across a gap of the boundary into the next field
///    or reaches the edge of the image. The tolerance is the end of the
///    first plateau, before a jump of a quarter within 2 ΔE and before the
///    area passes one and a half times what it was on the plateau; without a
///    plateau, the flattest point (no clear boundary). Or
///    [RegionTraceOptions.tolerance] when given.
/// 5. Clean-up: a majority filter of about [RegionTraceOptions.cleanM]
///    (specks and a ragged edge), the region of the seed kept, and the holes
///    inside it (trees, a shed, wet spots) filled and reported.
/// 6. Outline: [rasterRegionOutline] round the region and
///    [rasterOutlineRing] to world metres (Taubin smoothing, Douglas–Peucker
///    within [RegionTraceOptions.simplifyM], the area kept).
///
/// What it cannot do: tell apart two fields of the same crop with no
/// visible boundary between them, follow an edge hidden under tree crowns
/// or a shadow, or be more exact than the imagery (its date, resolution and
/// fit to the drawing).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/geometry.dart';
import 'vegetation.dart' show rasterOutlineRing, rasterRegionOutline;

/// Settings of [traceRegion].
class RegionTraceOptions {
  const RegionTraceOptions({this.tolerance, this.blurM = 1.0, this.seedRadiusM = 2.0, this.cleanM = 1.0, this.textureWeight = 0.5, this.minHoleM2 = 4, this.simplifyM, this.smoothing = 2});

  /// Colour tolerance in ΔE (null: automatic).
  final double? tolerance;

  /// Size of the box the colours are averaged over (m).
  final double blurM;

  /// Radius of the disc around the seed that gives the reference colour.
  final double seedRadiusM;

  /// Radius of the majority filter (m).
  final double cleanM;

  /// Weight of the local contrast against the colour.
  final double textureWeight;

  /// Holes smaller than this are filled without being reported (m²).
  final double minHoleM2;

  /// Douglas–Peucker tolerance of the outline (m; null: a pixel, at least
  /// 0.25 m).
  final double? simplifyM;

  /// Taubin passes over the outline.
  final int smoothing;
}

/// A traced region.
class RegionTrace {
  const RegionTrace({
    required this.outline,
    required this.areaM2,
    required this.pixels,
    required this.tolerance,
    required this.automatic,
    required this.clearBoundary,
    required this.touchesEdge,
    this.touchesNoData = false,
    required this.seedSpread,
    required this.curve,
    this.leakTolerance,
    this.leakAreaM2,
    this.holes = const [],
    this.holeCount = 0,
    this.holeAreaM2 = 0,
  });

  /// World outline, counter-clockwise (empty when nothing could be traced).
  final List<Pt> outline;

  /// Area of the region's pixels (m²), holes filled.
  final double areaM2;
  final int pixels;

  /// Tolerance used (ΔE) and whether it was found automatically.
  final double tolerance;
  final bool automatic;

  /// The area stopped growing before the tolerance (a boundary all round);
  /// false: no plateau, the tolerance is the flattest point found.
  final bool clearBoundary;

  /// The region reaches the edge of the image: it may go on beyond.
  final bool touchesEdge;

  /// The region reaches a part of the image without imagery (tiles that
  /// did not load): it may go on there.
  final bool touchesNoData;

  /// Spread of the colours of the seed disc about their median (ΔE): large
  /// when the seed lies on an edge or on a small object.
  final double seedSpread;

  /// The tolerance at which the region would jump (ΔE) and its area then.
  final double? leakTolerance;
  final double? leakAreaM2;

  /// (tolerance ΔE, area m²) along the area curve, for the text.
  final List<(double, double)> curve;

  /// World outlines of the largest holes filled (at least
  /// [RegionTraceOptions.minHoleM2]), largest first, and the count and area
  /// of all of them.
  final List<List<Pt>> holes;
  final int holeCount;
  final double holeAreaM2;
}

/// The seed is not on the image, or where it has no imagery.
class RegionTraceError implements Exception {
  const RegionTraceError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Size of a cost step (ΔE).
const _step = 0.5;

/// Cost of a pixel without imagery (a wall).
const _wall = 255;

/// Traces the region around pixel ([seedX], [seedY]) (from the top-left
/// corner; pixel i spans [i, i + 1]) of the [width] × [height] RGBA image
/// [rgba], whose pixels are [pixelM] metres on the ground and whose image
/// coordinates [toWorld] maps to the world.
RegionTrace traceRegion(
  Uint8List rgba,
  int width,
  int height, {
  required double seedX,
  required double seedY,
  required double pixelM,
  required Pt Function(double x, double y) toWorld,
  RegionTraceOptions o = const RegionTraceOptions(),
}) {
  final w = width, h = height, n = w * h;
  if (rgba.length < 4 * n) throw ArgumentError('rgba holds ${rgba.length} bytes for $w × $h pixels');
  if (seedX < 0 || seedY < 0 || seedX >= w || seedY >= h) throw const RegionTraceError('The point is outside the image.');
  final sx = seedX.floor(), sy = seedY.floor();
  // 1. features
  final fe = _Features.of(rgba, w, h, pixelM, o.blurM);
  final valid = fe.valid, ml = fe.l, ma = fe.a, mb = fe.b, tex = fe.tex, count = fe.count, rb = fe.radius;
  if (valid[sy * w + sx] == 0) throw const RegionTraceError('The point lies where the map has no imagery.');
  // 2. reference: the median features of the seed disc
  final rs = (o.seedRadiusM / pixelM).round().clamp(1, 25);
  final disc = <int>[];
  for (var y = math.max(0, sy - rs); y <= math.min(h - 1, sy + rs); y++) {
    for (var x = math.max(0, sx - rs); x <= math.min(w - 1, sx + rs); x++) {
      final i = y * w + x;
      if (valid[i] == 1 && (x - sx) * (x - sx) + (y - sy) * (y - sy) <= rs * rs) disc.add(i);
    }
  }
  double median(Iterable<double> v) {
    final s = v.toList()..sort();
    return s.isEmpty ? 0 : s[s.length ~/ 2];
  }

  var refL = median(disc.map((i) => ml[i])), refA = median(disc.map((i) => ma[i])), refB = median(disc.map((i) => mb[i])), refT = median(disc.map((i) => tex[i]));
  final wt = o.textureWeight;
  double dist(int i) {
    final dl = 0.75 * (ml[i] - refL), da = ma[i] - refA, db = mb[i] - refB, dt = wt * (tex[i] - refT);
    return math.sqrt(dl * dl + da * da + db * db + dt * dt);
  }

  final seedSpread = median(disc.map(dist));
  // 3. cost levels and the minimax flood from the disc, and 4. the
  // tolerance. A point in an odd spot of its region (between crop rows, on
  // a darker patch) gives a reference off the region's colour and an edge
  // off the middle of the blend: once the region is found, the median of
  // its core is the reference of a second flood.
  final lev = Uint8List(n), cost = Uint8List(n), queued = Uint8List(n);
  final head = Int32List(256), next = Int32List(n), hist = Int32List(256);
  final area = Float64List(256);
  final px2 = pixelM * pixelM;
  final minArea = math.max(20, 2 * disc.length);
  const win = 4; // 2 ΔE
  double growth(int k) => area[k] <= 0 ? double.infinity : (area[math.min(254, k + win)] - area[k]) / area[k];
  final auto = o.tolerance == null;
  var edgeLevel = _wall, gapLevel = _wall, k0 = 0, chosen = 0, plateau = -1;
  var clear = false;
  int? leak;
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < n; i++) {
      lev[i] = valid[i] == 0 ? _wall : math.min(254, (dist(i) / _step).round());
    }
    cost.fillRange(0, n, _wall);
    queued.fillRange(0, n, 0);
    head.fillRange(0, 256, -1);
    hist.fillRange(0, 256, 0);
    void push(int q, int level) {
      next[q] = head[level];
      head[level] = q;
      queued[q] = 1;
    }

    for (final i in disc) {
      if (queued[i] == 0) push(i, lev[i]);
    }
    edgeLevel = _wall;
    gapLevel = _wall;
    for (var level = 0; level < _wall; level++) {
      while (head[level] >= 0) {
        final p = head[level];
        head[level] = next[p];
        cost[p] = level;
        hist[level]++;
        final x = p % w, y = p ~/ w;
        final edge = x == 0 || y == 0 || x == w - 1 || y == h - 1;
        var gap = false;
        // the four neighbours, inline (the hot loop)
        for (var k = 0; k < 4; k++) {
          final int q;
          if (k == 0) {
            if (x == 0) continue;
            q = p - 1;
          } else if (k == 1) {
            if (x == w - 1) continue;
            q = p + 1;
          } else if (k == 2) {
            if (y == 0) continue;
            q = p - w;
          } else {
            if (y == h - 1) continue;
            q = p + w;
          }
          final lq = lev[q];
          if (lq == _wall) {
            gap = true;
          } else if (queued[q] == 0) {
            push(q, lq > level ? lq : level);
          }
        }
        if (edge && level < edgeLevel) edgeLevel = level;
        if (gap && level < gapLevel) gapLevel = level;
      }
    }
    var acc = 0;
    for (var k = 0; k < 256; k++) {
      acc += hist[k];
      area[k] = acc.toDouble();
    }
    k0 = 0;
    while (k0 < 254 && area[k0] < minArea) {
      k0++;
    }
    clear = false;
    leak = null;
    plateau = -1;
    if (!auto) {
      chosen = (o.tolerance! / _step).round().clamp(0, 254);
      break;
    }
    for (var k = k0; k <= 250; k++) {
      if (growth(k) < 0.06) {
        plateau = k;
        break;
      }
    }
    if (plateau >= 0) {
      clear = true;
      // where the growth ends: a jump (across a gap of the boundary), or
      // half as much again as on the plateau (creeping into the next field)
      final cap = 1.5 * area[plateau];
      var stop = 250;
      for (var k = plateau; k < 250; k++) {
        if (area[k + 1] > cap) {
          stop = k + 1;
          break;
        }
        if (growth(k) > 0.25) {
          var j = k + 1;
          while (j < k + win && area[j] <= 1.12 * area[k]) {
            j++;
          }
          stop = j;
          break;
        }
      }
      leak = stop < 250 ? stop : null;
      // The colours are averaged over a box, so across an edge they blend
      // over its width: the edge itself is where a pixel is half the one
      // colour and half the other, halfway between the field's own cost and
      // the cost of what lies beyond (the weakest side sets [stop]).
      var half = area[plateau] / 2, own = 0;
      while (own < plateau && area[own] < half) {
        own++;
      }
      chosen = math.max(plateau, ((own + stop) / 2).floor());
      if (chosen >= stop) chosen = math.max(plateau, stop - 1);
    } else {
      // no plateau: the flattest point
      chosen = k0;
      var best = double.infinity;
      for (var k = k0; k <= 250; k++) {
        final g = growth(k);
        if (g < best) {
          best = g;
          chosen = k;
        }
      }
    }
    if (pass == 1 || plateau < 0) break;
    // the reference again, from the core of the region found
    final stride = math.max(1, area[plateau] ~/ 4000);
    final core = <int>[];
    var seen = 0;
    for (var i = 0; i < n; i++) {
      if (cost[i] <= plateau && seen++ % stride == 0) core.add(i);
    }
    if (core.length < 20) break;
    final nl = median(core.map((i) => ml[i])), na = median(core.map((i) => ma[i])), nb = median(core.map((i) => mb[i])), nt = median(core.map((i) => tex[i]));
    final dl = 0.75 * (nl - refL), da = na - refA, db = nb - refB;
    if (dl * dl + da * da + db * db < 4) break;
    refL = nl;
    refA = na;
    refB = nb;
    refT = nt;
  }
  // the next jump past the tolerance, for the text
  if (leak == null) {
    for (var k = chosen + 1; k < 250; k++) {
      if (area[k] > 1.25 * area[chosen]) {
        leak = k;
        break;
      }
    }
  }
  final touches = edgeLevel <= chosen, gaps = gapLevel <= chosen;
  // 5. clean-up
  var mask = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (cost[i] <= chosen) mask[i] = 1;
  }
  final rm = (o.cleanM / pixelM).round().clamp(1, 10);
  final ones = _boxSum(_asFloat(mask), w, h, rm);
  final around = rm == rb ? count : _boxSum(_asFloat(valid), w, h, rm);
  for (var i = 0; i < n; i++) {
    if (valid[i] == 1) mask[i] = 2 * ones[i] > around[i] ? 1 : 0;
  }
  // the region of the seed (or of the disc pixel nearest it)
  var start = -1;
  if (mask[sy * w + sx] == 1) {
    start = sy * w + sx;
  } else {
    var bestD = 1 << 30;
    for (final i in disc) {
      final d = (i % w - sx) * (i % w - sx) + (i ~/ w - sy) * (i ~/ w - sy);
      if (mask[i] == 1 && d < bestD) {
        bestD = d;
        start = i;
      }
    }
  }
  if (start < 0) {
    return RegionTrace(
      outline: const [],
      areaM2: 0,
      pixels: 0,
      tolerance: chosen * _step,
      automatic: auto,
      clearBoundary: clear,
      touchesEdge: touches,
      touchesNoData: gaps,
      seedSpread: seedSpread,
      curve: const [],
    );
  }
  final region = Uint8List(n);
  final stack = <int>[start];
  region[start] = 1;
  void grow(int q) {
    if (mask[q] == 1 && region[q] == 0) {
      region[q] = 1;
      stack.add(q);
    }
  }

  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final x = p % w, y = p ~/ w;
    if (x > 0) grow(p - 1);
    if (x < w - 1) grow(p + 1);
    if (y > 0) grow(p - w);
    if (y < h - 1) grow(p + w);
  }
  mask = Uint8List(0);
  // holes: what the outside (8-connected, from the border) does not reach
  final outside = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final x = i % w, y = i ~/ w;
    if ((x == 0 || y == 0 || x == w - 1 || y == h - 1) && region[i] == 0 && outside[i] == 0) {
      outside[i] = 1;
      stack.add(i);
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final px = p % w, py = p ~/ w;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final qx = px + dx, qy = py + dy;
            if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
            final q = qy * w + qx;
            if (region[q] == 0 && outside[q] == 0) {
              outside[q] = 1;
              stack.add(q);
            }
          }
        }
      }
    }
  }
  final holeIds = Int32List(n)..fillRange(0, n, -1);
  final holeSizes = <int>[], holeFirst = <int>[];
  for (var i = 0; i < n; i++) {
    if (region[i] == 1 || outside[i] == 1 || holeIds[i] >= 0) continue;
    final id = holeSizes.length;
    var size = 0;
    holeIds[i] = id;
    stack.add(i);
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      size++;
      final x = p % w, y = p ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final qx = x + dx, qy = y + dy;
          if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
          final q = qy * w + qx;
          if (region[q] == 0 && outside[q] == 0 && holeIds[q] < 0) {
            holeIds[q] = id;
            stack.add(q);
          }
        }
      }
    }
    holeSizes.add(size);
    holeFirst.add(i);
  }
  var pixels = 0;
  for (var i = 0; i < n; i++) {
    if (region[i] == 1 || holeIds[i] >= 0) {
      region[i] = 1;
      pixels++;
    }
  }
  // 6. outlines
  var first = 0;
  while (region[first] == 0) {
    first++;
  }
  final simplify = o.simplifyM ?? math.max(0.25, pixelM);
  final ring = rasterOutlineRing(rasterRegionOutline(w, h, (i) => region[i] == 1, first % w, first ~/ w, eightConnected: false), toWorld, pixelM: pixelM, smoothing: o.smoothing, simplifyM: simplify);
  final order = [for (var k = 0; k < holeSizes.length; k++) k]..sort((a, b) => holeSizes[b].compareTo(holeSizes[a]));
  final holes = <List<Pt>>[];
  var holeCount = 0;
  var holeArea = 0.0;
  for (final k in order) {
    final a = holeSizes[k] * px2;
    holeArea += a;
    if (a < o.minHoleM2) continue;
    holeCount++;
    if (holes.length < 8) {
      final hr = rasterOutlineRing(
        rasterRegionOutline(w, h, (i) => holeIds[i] == k, holeFirst[k] % w, holeFirst[k] ~/ w, eightConnected: true),
        toWorld,
        pixelM: pixelM,
        smoothing: o.smoothing,
        simplifyM: simplify,
      );
      if (hr.length >= 3) holes.add(hr);
    }
  }
  final curve = <(double, double)>[
    for (final k in {if (chosen > 4) chosen ~/ 2, chosen, ?leak})
      if (k >= 0 && k < 255) (k * _step, area[k] * px2),
  ];
  return RegionTrace(
    outline: ring,
    areaM2: pixels * px2,
    pixels: pixels,
    tolerance: chosen * _step,
    automatic: auto,
    clearBoundary: clear,
    touchesEdge: touches,
    touchesNoData: gaps,
    seedSpread: seedSpread,
    curve: curve,
    leakTolerance: leak == null ? null : leak * _step,
    leakAreaM2: leak == null ? null : area[leak] * px2,
    holes: holes,
    holeCount: holeCount,
    holeAreaM2: holeArea,
  );
}

// ---------------------------------------------------------------- every region of an image

/// Settings of [traceRegions].
class RegionsOptions {
  const RegionsOptions({
    this.minAreaM2 = 2000,
    this.minWidthM = 10,
    this.seedSpacingM,
    this.maxRegions = 40,
    this.includeEdge = false,
    this.blurM = 1.5,
    this.seedRadiusM = 2.5,
    this.cleanM = 1.5,
    this.textureWeight = 0.5,
    this.minHoleM2 = 25,
    this.simplifyM,
    this.smoothing = 2,
  });

  /// Regions smaller than this are left out (m²).
  final double minAreaM2;

  /// Regions narrower than this on average (2 × area / perimeter) are left
  /// out: roads, tracks, hedges, ditches.
  final double minWidthM;

  /// Distance between the seeds (m; null: half the side of [minAreaM2], at
  /// least 12 m).
  final double? seedSpacingM;
  final int maxRegions;

  /// Keep the regions the edge of the image cuts.
  final bool includeEdge;

  /// As in [RegionTraceOptions].
  final double blurM, seedRadiusM, cleanM, textureWeight, minHoleM2;
  final double? simplifyM;
  final int smoothing;
}

/// A region found by [traceRegions].
class FoundRegion {
  const FoundRegion({
    required this.outline,
    required this.areaM2,
    required this.perimeterM,
    required this.tolerance,
    required this.seed,
    required this.touchesEdge,
    this.holeCount = 0,
    this.holeAreaM2 = 0,
  });

  /// World outline, counter-clockwise.
  final List<Pt> outline;

  /// Area of its pixels (m², holes filled) and the length of its outline.
  final double areaM2, perimeterM;

  /// Tolerance it was grown to (ΔE).
  final double tolerance;

  /// The seed it grew from (world).
  final Pt seed;
  final bool touchesEdge;
  final int holeCount;
  final double holeAreaM2;

  /// Mean width: 2 × area / perimeter (m).
  double get meanWidthM => perimeterM <= 0 ? 0 : 2 * areaM2 / perimeterM;
}

/// What [traceRegions] found, and how many regions it left out and why.
class RegionsResult {
  const RegionsResult(this.regions, {required this.seeds, required this.small, required this.thin, required this.unclear, required this.edge, required this.truncated});
  final List<FoundRegion> regions;

  /// Seeds grown (one per region tried).
  final int seeds;

  /// Left out: smaller than the minimum, narrower than the minimum width,
  /// without a clear boundary, cut by the edge of the image.
  final int small, thin, unclear, edge;

  /// Stopped at [RegionsOptions.maxRegions].
  final bool truncated;
}

/// Every region of the [width] × [height] RGBA image [rgba] (pixels of
/// [pixelM] metres, mapped to the world by [toWorld]) as [traceRegion]
/// would trace it from a point inside: seeds on a grid, the most uniform
/// first, each grown over the pixels no earlier region took (they are
/// walls), its flood stopped as soon as the tolerance is decided; the
/// regions large, wide and whole enough kept, largest first. Every
/// [yieldEvery] of work it lets the event loop run (a browser keeps
/// painting and a Stop button works); [cancelled] ends it early with what
/// it found.
Future<RegionsResult> traceRegions(
  Uint8List rgba,
  int width,
  int height, {
  required double pixelM,
  required Pt Function(double x, double y) toWorld,
  RegionsOptions o = const RegionsOptions(),
  Duration yieldEvery = const Duration(milliseconds: 80),
  bool Function()? cancelled,
}) async {
  final w = width, h = height, n = w * h;
  if (rgba.length < 4 * n) throw ArgumentError('rgba holds ${rgba.length} bytes for $w × $h pixels');
  final fe = _Features.of(rgba, w, h, pixelM, o.blurM);
  final valid = fe.valid, ml = fe.l, ma = fe.a, mb = fe.b, tex = fe.tex;
  final covered = Uint8List(n), skip = Uint8List(n);
  final stamp = Int32List(n), lvl = Uint8List(n), next = Int32List(n), visited = Int32List(n);
  final head = Int32List(256);
  final area = Float64List(256);
  final px2 = pixelM * pixelM;
  final rs = (o.seedRadiusM / pixelM).round().clamp(1, 25);
  final rm = (o.cleanM / pixelM).round().clamp(1, 10);
  final step = math.max(6, ((o.seedSpacingM ?? math.max(12.0, math.sqrt(o.minAreaM2) / 2)) / pixelM).round());
  // seeds where the averaged colours change least first: inside a region,
  // textured or not, rather than on its edge
  final int gr = math.max(1, fe.radius);
  double grad(int i) {
    final int x = i % w, y = i ~/ w;
    final int l = i - math.min(gr, x), r = i + math.min(gr, w - 1 - x), u = i - w * math.min(gr, y), d = i + w * math.min(gr, h - 1 - y);
    return (ml[r] - ml[l]).abs() + (ma[r] - ma[l]).abs() + (mb[r] - mb[l]).abs() + (ml[d] - ml[u]).abs() + (ma[d] - ma[u]).abs() + (mb[d] - mb[u]).abs();
  }

  final seeds = <int>[
    for (var y = step ~/ 2; y < h; y += step)
      for (var x = step ~/ 2; x < w; x += step)
        if (valid[y * w + x] == 1) y * w + x,
  ];
  final order = {for (final i in seeds) i: grad(i)};
  seeds.sort((a, b) => order[a]!.compareTo(order[b]!));
  final maxVisit = (0.9 * n).round();
  const win = 4;
  final found = <FoundRegion>[];
  var small = 0, thin = 0, unclear = 0, edge = 0, tried = 0, id = 0;
  var truncated = false;
  double median(Iterable<double> v) {
    final s = v.toList()..sort();
    return s.isEmpty ? 0 : s[s.length ~/ 2];
  }

  final clock = Stopwatch()..start();
  for (final s in seeds) {
    if (covered[s] == 1 || skip[s] == 1) continue;
    if (clock.elapsed > yieldEvery) {
      await Future<void>.delayed(Duration.zero);
      clock.reset();
      if (cancelled?.call() ?? false) break;
    }
    if (found.length >= o.maxRegions) {
      truncated = true;
      break;
    }
    id++;
    tried++;
    final sx = s % w, sy = s ~/ w;
    final disc = <int>[
      for (var y = math.max(0, sy - rs); y <= math.min(h - 1, sy + rs); y++)
        for (var x = math.max(0, sx - rs); x <= math.min(w - 1, sx + rs); x++)
          if (valid[y * w + x] == 1 && covered[y * w + x] == 0 && (x - sx) * (x - sx) + (y - sy) * (y - sy) <= rs * rs) y * w + x,
    ];
    if (disc.isEmpty) continue;
    var refL = median(disc.map((i) => ml[i])), refA = median(disc.map((i) => ma[i])), refB = median(disc.map((i) => mb[i])), refT = median(disc.map((i) => tex[i]));
    int lev(int i) {
      final dl = 0.75 * (ml[i] - refL), da = ma[i] - refA, db = mb[i] - refB, dt = o.textureWeight * (tex[i] - refT);
      return math.min(254, (math.sqrt(dl * dl + da * da + db * db + dt * dt) / _step).round());
    }

    void push(int q, int level) {
      next[q] = head[level];
      head[level] = q;
      stamp[q] = id;
    }

    final minPix = math.max(20, 2 * disc.length);
    var nv = 0, edgeLevel = _wall, plateau = -1, stop = -1, k0 = -1, level = 0;
    // A seed in an odd spot of its region (between crop rows, on a darker
    // patch) gives a reference off the region's colour and an edge off the
    // middle of the blend: once the region is found, the median of its core
    // is the reference of a second flood.
    for (var pass = 0; pass < 2; pass++) {
      if (pass == 1) id++;
      head.fillRange(0, 256, -1);
      for (final i in disc) {
        if (stamp[i] != id) push(i, lev(i));
      }
      nv = 0;
      edgeLevel = _wall;
      plateau = -1;
      stop = -1;
      k0 = -1;
      level = 0;
      for (; level < _wall && stop < 0; level++) {
        while (head[level] >= 0) {
          final p = head[level];
          head[level] = next[p];
          lvl[p] = level;
          visited[nv++] = p;
          final x = p % w, y = p ~/ w;
          var atEdge = x == 0 || y == 0 || x == w - 1 || y == h - 1;
          for (var k = 0; k < 4; k++) {
            final int q;
            if (k == 0) {
              if (x == 0) continue;
              q = p - 1;
            } else if (k == 1) {
              if (x == w - 1) continue;
              q = p + 1;
            } else if (k == 2) {
              if (y == 0) continue;
              q = p - w;
            } else {
              if (y == h - 1) continue;
              q = p + w;
            }
            if (valid[q] == 0) {
              atEdge = true;
            } else if (covered[q] == 0 && stamp[q] != id) {
              final lq = lev(q);
              push(q, lq > level ? lq : level);
            }
          }
          if (atEdge && level < edgeLevel) edgeLevel = level;
        }
        area[level] = nv.toDouble();
        if (k0 < 0 && nv >= minPix) k0 = level;
        // the window after level k is complete: decide on k
        final k = level - win;
        if (k0 >= 0 && k >= k0 && area[k] > 0) {
          final g = (area[level] - area[k]) / area[k];
          if (plateau < 0) {
            if (g < 0.06) plateau = k;
          } else if (area[level] > 1.5 * area[plateau]) {
            var j = plateau + 1;
            while (j < level && area[j] <= 1.5 * area[plateau]) {
              j++;
            }
            stop = j;
          } else if (g > 0.25) {
            var j = k + 1;
            while (j < level && area[j] <= 1.12 * area[k]) {
              j++;
            }
            stop = j;
          }
        }
        if (nv > maxVisit) break;
      }
      if (pass == 1 || plateau < 0) break;
      final core = [
        for (var t = 0; t < nv; t += math.max(1, nv ~/ 4000))
          if (lvl[visited[t]] <= plateau) visited[t],
      ];
      if (core.length < 20) break;
      final nl = median(core.map((i) => ml[i])), na = median(core.map((i) => ma[i])), nb = median(core.map((i) => mb[i])), nt = median(core.map((i) => tex[i]));
      final dl = 0.75 * (nl - refL), da = na - refA, db = nb - refB;
      if (dl * dl + da * da + db * db < 4) break;
      refL = nl;
      refA = na;
      refB = nb;
      refT = nt;
    }
    if (plateau < 0) {
      // no boundary seen: its uniform core is not tried again
      unclear++;
      final core = (k0 < 0 ? 0 : k0) + win;
      for (var t = 0; t < nv; t++) {
        if (lvl[visited[t]] <= core) skip[visited[t]] = 1;
      }
      continue;
    }
    if (stop < 0) {
      // the flood ended first (the whole image, or the cap): where the area
      // jumped in the levels it reached
      final last = math.min(level, 254);
      stop = last;
      for (var k = plateau; k < last; k++) {
        if (area[k + 1] > 1.5 * area[plateau] || (area[k] > 0 && (area[math.min(last, k + win)] - area[k]) / area[k] > 0.25)) {
          var j = k + 1;
          while (j < last && area[j] <= 1.12 * area[k]) {
            j++;
          }
          stop = j;
          break;
        }
      }
    }
    var own = 0;
    while (own < plateau && area[own] < area[plateau] / 2) {
      own++;
    }
    var chosen = math.max(plateau, ((own + stop) / 2).floor());
    if (chosen >= stop) chosen = math.max(plateau, stop - 1);
    final touches = edgeLevel <= chosen;
    // the region in a crop of the image around it, cleaned
    var x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (var t = 0; t < nv; t++) {
      final p = visited[t];
      if (lvl[p] > chosen) continue;
      final x = p % w, y = p ~/ w;
      x0 = math.min(x0, x);
      y0 = math.min(y0, y);
      x1 = math.max(x1, x);
      y1 = math.max(y1, y);
    }
    if (x1 < 0) continue;
    final m = rm + 2;
    x0 = math.max(0, x0 - m);
    y0 = math.max(0, y0 - m);
    x1 = math.min(w - 1, x1 + m);
    y1 = math.min(h - 1, y1 + m);
    final cw = x1 - x0 + 1, ch = y1 - y0 + 1, cn = cw * ch;
    var mask = Uint8List(cn);
    final cvalid = Uint8List(cn);
    for (var y = 0; y < ch; y++) {
      for (var x = 0; x < cw; x++) {
        final p = (y + y0) * w + x + x0;
        if (valid[p] == 1 && covered[p] == 0) cvalid[y * cw + x] = 1;
      }
    }
    for (var t = 0; t < nv; t++) {
      final p = visited[t];
      if (lvl[p] <= chosen) mask[(p ~/ w - y0) * cw + p % w - x0] = 1;
    }
    final ones = _boxSum(_asFloat(mask), cw, ch, rm), around = _boxSum(_asFloat(cvalid), cw, ch, rm);
    for (var i = 0; i < cn; i++) {
      mask[i] = cvalid[i] == 1 && 2 * ones[i] > around[i] ? 1 : 0;
    }
    // the component of the seed (or of the disc pixel nearest it)
    var start = -1, best = 1 << 30;
    for (final i in [s, ...disc]) {
      final x = i % w - x0, y = i ~/ w - y0;
      if (x < 0 || y < 0 || x >= cw || y >= ch || mask[y * cw + x] == 0) continue;
      final d = (i % w - sx) * (i % w - sx) + (i ~/ w - sy) * (i ~/ w - sy);
      if (d < best) {
        best = d;
        start = y * cw + x;
      }
    }
    if (start < 0) {
      unclear++;
      skip[s] = 1;
      continue;
    }
    final region = _component(mask, cw, ch, start);
    mask = Uint8List(0);
    // holes as large as a region of their own stay out: a field the soil
    // around it encloses is not part of the soil
    final (holes, holeArea) = _fillHoles(region, cw, ch, px2, o.minHoleM2, maxFillM2: o.minAreaM2);
    var pixels = 0, first = -1;
    for (var i = 0; i < cn; i++) {
      if (region[i] == 1) {
        pixels++;
        if (first < 0) first = i;
      }
    }
    final areaM2 = pixels * px2;
    final ring = rasterOutlineRing(
      rasterRegionOutline(cw, ch, (i) => region[i] == 1, first % cw, first ~/ cw, eightConnected: false),
      (x, y) => toWorld(x + x0, y + y0),
      pixelM: pixelM,
      smoothing: o.smoothing,
      simplifyM: o.simplifyM ?? math.max(0.5, pixelM),
    );
    final perimeter = ring.length < 3 ? 0.0 : polylineLength([...ring, ring.first]);
    final r = FoundRegion(
      outline: ring,
      areaM2: areaM2,
      perimeterM: perimeter,
      tolerance: chosen * _step,
      seed: toWorld(sx + 0.5, sy + 0.5),
      touchesEdge: touches,
      holeCount: holes,
      holeAreaM2: holeArea,
    );
    final keep = ring.length >= 3 && areaM2 >= o.minAreaM2 && r.meanWidthM >= o.minWidthM && (o.includeEdge || !touches);
    if (!keep) {
      if (ring.length < 3 || areaM2 < o.minAreaM2) {
        small++;
      } else if (r.meanWidthM < o.minWidthM) {
        thin++;
      } else {
        edge++;
      }
    } else {
      found.add(r);
    }
    // a kept region is a wall for the next ones; one left out is not tried again
    final mark = keep ? covered : skip;
    for (var y = 0; y < ch; y++) {
      for (var x = 0; x < cw; x++) {
        if (region[y * cw + x] == 1) mark[(y + y0) * w + x + x0] = 1;
      }
    }
  }
  found.sort((a, b) => b.areaM2.compareTo(a.areaM2));
  return RegionsResult(found, seeds: tried, small: small, thin: thin, unclear: unclear, edge: edge, truncated: truncated);
}

/// The 4-connected component of [mask] (w × h) holding [start].
Uint8List _component(Uint8List mask, int w, int h, int start) {
  final region = Uint8List(w * h);
  final stack = <int>[start];
  region[start] = 1;
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final x = p % w, y = p ~/ w;
    for (var k = 0; k < 4; k++) {
      final int q;
      if (k == 0) {
        if (x == 0) continue;
        q = p - 1;
      } else if (k == 1) {
        if (x == w - 1) continue;
        q = p + 1;
      } else if (k == 2) {
        if (y == 0) continue;
        q = p - w;
      } else {
        if (y == h - 1) continue;
        q = p + w;
      }
      if (mask[q] == 1 && region[q] == 0) {
        region[q] = 1;
        stack.add(q);
      }
    }
  }
  return region;
}

/// Fills the holes of [region] (w × h) in place: what the outside
/// (8-connected, from the border) does not reach, up to [maxFillM2] a hole.
/// Returns the holes filled of at least [minHoleM2] and the area of all
/// those filled (m²).
(int, double) _fillHoles(Uint8List region, int w, int h, double px2, double minHoleM2, {double maxFillM2 = double.infinity}) {
  final n = w * h;
  final outside = Uint8List(n);
  final stack = <int>[];
  void reach(int i) {
    if (region[i] == 0 && outside[i] == 0) {
      outside[i] = 1;
      stack.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    reach(x);
    reach((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    reach(y * w);
    reach(y * w + w - 1);
  }
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final x = p % w, y = p ~/ w;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final qx = x + dx, qy = y + dy;
        if (qx >= 0 && qy >= 0 && qx < w && qy < h) reach(qy * w + qx);
      }
    }
  }
  // the holes, one flood each
  var count = 0;
  var total = 0.0;
  final seen = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (region[i] == 1 || outside[i] == 1 || seen[i] == 1) continue;
    var size = 0;
    seen[i] = 1;
    stack.add(i);
    final hole = <int>[];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      size++;
      hole.add(p);
      final x = p % w, y = p ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final qx = x + dx, qy = y + dy;
          if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
          final q = qy * w + qx;
          if (region[q] == 0 && outside[q] == 0 && seen[q] == 0) {
            seen[q] = 1;
            stack.add(q);
          }
        }
      }
    }
    if (size * px2 > maxFillM2) continue;
    for (final p in hole) {
      region[p] = 1;
    }
    total += size * px2;
    if (size * px2 >= minHoleM2) count++;
  }
  return (count, total);
}

/// The features of every pixel: whether it has imagery, its CIE L*a*b*
/// (D65) averaged over a box of about blurM, and the local contrast of the
/// lightness over the same box.
class _Features {
  _Features._(this.w, this.h, this.radius, this.valid, this.l, this.a, this.b, this.tex, this.count);
  final int w, h, radius;
  final Uint8List valid;
  final Float32List l, a, b, tex;

  /// Pixels with imagery in the box around every pixel.
  final Float32List count;

  factory _Features.of(Uint8List rgba, int w, int h, double pixelM, double blurM) {
    final n = w * h;
    final valid = Uint8List(n);
    final l = Float32List(n), aa = Float32List(n), bb = Float32List(n), l2 = Float32List(n);
    final lin = Float64List(256);
    for (var k = 0; k < 256; k++) {
      final v = k / 255.0;
      lin[k] = v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }
    double f(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
    for (var i = 0; i < n; i++) {
      if (rgba[4 * i + 3] < 128) continue;
      valid[i] = 1;
      final r = lin[rgba[4 * i]], g = lin[rgba[4 * i + 1]], b = lin[rgba[4 * i + 2]];
      final fx = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
      final fy = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
      final fz = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
      final lv = 116 * fy - 16;
      l[i] = lv;
      aa[i] = 500 * (fx - fy);
      bb[i] = 200 * (fy - fz);
      l2[i] = lv * lv;
    }
    final rb = (blurM / pixelM).round().clamp(0, 25);
    final count = _boxSum(_asFloat(valid), w, h, rb);
    Float32List mean(Float32List v) {
      final s = _boxSum(_masked(v, valid), w, h, rb);
      for (var i = 0; i < n; i++) {
        s[i] = count[i] > 0 ? s[i] / count[i] : 0;
      }
      return s;
    }

    final ml = mean(l), ma = mean(aa), mb = mean(bb), ml2 = mean(l2);
    final tex = Float32List(n);
    for (var i = 0; i < n; i++) {
      tex[i] = math.sqrt(math.max(0, ml2[i] - ml[i] * ml[i]));
    }
    return _Features._(w, h, rb, valid, ml, ma, mb, tex, count);
  }
}

Float32List _asFloat(Uint8List v) {
  final out = Float32List(v.length);
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i].toDouble();
  }
  return out;
}

Float32List _masked(Float32List v, Uint8List valid) {
  final out = Float32List(v.length);
  for (var i = 0; i < v.length; i++) {
    if (valid[i] == 1) out[i] = v[i];
  }
  return out;
}

/// Sums of [a] over the (2r + 1)² box around every pixel, cut at the edges
/// of the image: two running sums, along the rows and then the columns.
Float32List _boxSum(Float32List a, int w, int h, int r) {
  if (r <= 0) return Float32List.fromList(a);
  final tmp = Float32List(w * h), out = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var s = 0.0;
    for (var x = 0; x <= math.min(w - 1, r); x++) {
      s += a[row + x];
    }
    for (var x = 0; x < w; x++) {
      tmp[row + x] = s;
      final add = x + r + 1, drop = x - r;
      if (add < w) s += a[row + add];
      if (drop >= 0) s -= a[row + drop];
    }
  }
  for (var x = 0; x < w; x++) {
    var s = 0.0;
    for (var y = 0; y <= math.min(h - 1, r); y++) {
      s += tmp[y * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = s;
      final add = y + r + 1, drop = y - r;
      if (add < h) s += tmp[add * w + x];
      if (drop >= 0) s -= tmp[drop * w + x];
    }
  }
  return out;
}
