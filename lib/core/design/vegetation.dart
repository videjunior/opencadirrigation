/// Detection of vegetated areas — lawns, planted beds, trees and shrubs — in
/// an aerial image: the satellite base map on screen or an aerial photo
/// placed in the drawing. The outlines come out in world metres, ready to
/// become the irrigated areas of a design ([vegetationEntities]). Plain image
/// processing, linear in the number of pixels: no service, no network, no
/// trained model.
///
/// The pipeline and its defaults:
///
/// 1. Working raster. The image is averaged down in blocks to at most
///    [VegetationImage.defaultMaxPixels] pixels and no finer than
///    [VegetationImage.defaultMinPixelM] on the ground: finer pixels add time,
///    not accuracy, to the outline of an irrigated area, and the preview has
///    to stay live on a phone. Transparent pixels (map tiles not loaded) carry
///    no data and count as the edge of the image.
/// 2. Vegetation index: excess green ExG = 2g − r − b on the chromatic
///    coordinates r = R/(R + G + B)… (Woebbecke et al., 1995), the sum damped
///    by [VegetationImage.darkDamping] so that the random hue of near-black
///    pixels (deep shadow, compression noise) does not read as green, and
///    capped by twice the excess of green over blue: turquoise pools, sky
///    reflections and blue shadows on paving have green well above red (a
///    high ExG) but no more green than blue, while leaves reflect clearly
///    more green than blue (the cap never binds on them). A 3 × 3 median
///    takes the noise out without moving the edges.
///    ExG rather than VARI = (G − R)/(G + R − B) (Gitelson et al., 2002):
///    VARI divides by a difference that crosses zero on grey and bluish
///    pixels (paving, roofs, shadows, water) and has to be clipped, so its
///    histogram has no stable shape to threshold; ExG is bounded, linear in
///    the chromatic coordinates and independent of the illumination level,
///    and ExG thresholded by Otsu's method is the classic vegetation mask of
///    RGB images (compared with the other colour indices by Meyer & Neto,
///    2008).
/// 3. Threshold: Otsu (1979) on the histogram of the index — again below it
///    when its lower class is green too (a park or a golf course filling the
///    view: two shades of grass) — kept within
///    [VegetationImage.autoThresholdRange] (a view that is all paving has a
///    single mode, which Otsu would split), plus the user's offset
///    [VegetationOptions.thresholdOffset].
/// 4. Clean-up: a majority filter (the binary median: a pixel takes the
///    class of most of its neighbours within [VegetationOptions.cleanM])
///    removes specks and lines narrower than about that radius and fills
///    gaps as narrow. Unlike an opening and a closing it does not move a
///    boundary: along a ragged edge it adds as many pixels as it takes away,
///    where an opening shaves the ones that stick out.
/// 5. Trees and shrubs against turf: canopy is rough and darker — leaves and
///    their shadows change the brightness from one decimetre to the next,
///    while mown grass is even. The texture is the share of the brightness
///    steps over 0.2 m, between vegetated pixels of a 1 m window, larger than
///    a tenth of their brightness ([VegetationImage.roughStep]): relative, so
///    a lawn in the shade of a building stays smooth, and a share rather
///    than a mean, so the line of a shadow across a lawn (a few large steps
///    among many small ones) is not texture; pixels of paving do not count,
///    so neither is the edge of a lawn. A pixel is canopy when that share
///    over [VegetationImage.roughShareRef] plus its darkness, weighted by
///    [VegetationImage.darknessWeight], passes 1 ([VegetationOptions.treeBias]
///    shifts the limit). The canopy mask is cleaned by the majority of its
///    vegetated neighbours ([VegetationOptions.canopyCleanM]).
/// 6. Patches: the 8-connected components of every class kept, those under
///    [VegetationOptions.minAreaM2] left out. Holes: the 4-connected rest of
///    the image enclosed by a patch (paths, paving, buildings, pools, or a
///    patch of the other class); those under [VegetationOptions.minHoleM2]
///    are covered by the patch.
/// 7. Outlines: marching squares walked round every patch and hole from its
///    first pixel (saddles resolved by the connectivity, so outlines never
///    cross), mapped to world coordinates through the four corners of the
///    image (bilinear: exact for the rectangles of the base map view and of a
///    placed image), smoothed without shrinkage (Taubin, 1995) and simplified
///    by Douglas–Peucker (1973) with a tolerance in metres
///    ([VegetationOptions.simplifyM]).
///
/// An [AreaEntity] has no holes: [vegetationEntities] makes the outline of a
/// patch the irrigated area and every hole that is paving, a building or
/// water a closed polyline on the drawing layer — select the area with its
/// exclusions and the automatic head layout leaves them out. A hole filled by
/// a patch of the other class kept is not repeated: that patch is an area of
/// its own, nested in the outer one (whose measured area then includes it).
///
/// What it cannot see: lawns in deep shadow or dry and straw-coloured (lower
/// the threshold), lawn under tree canopy (seen as canopy), the texture of
/// crowns in soft, resampled imagery (seen as turf: move the canopy limit),
/// green water, artificial turf and green roofs (seen as vegetation); and the
/// outlines are only as good as the imagery (its date, resolution and fit to
/// the drawing).
///
/// References: Woebbecke, Meyer, Von Bargen & Mortensen, "Color indices for
/// weed identification under various soil, residue, and lighting
/// conditions", Trans. ASAE 38(1), 1995; Otsu, "A threshold selection method
/// from gray-level histograms", IEEE Trans. SMC 9(1), 1979; Meyer & Neto,
/// "Verification of color vegetation indices for automated crop imaging
/// applications", Comput. Electron. Agric. 63(2), 2008; Gitelson, Kaufman,
/// Stark & Rundquist, "Novel algorithms for remote estimation of vegetation
/// fraction", Remote Sens. Environ. 80(1), 2002; Taubin, "Curve and surface
/// smoothing without shrinkage", ICCV 1995; Douglas & Peucker, "Algorithms
/// for the reduction of the number of points required to represent a
/// digitized line or its caricature", Cartographica 10(2), 1973.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'water_budget.dart' show mweloEfficiencyDrip, mweloEfficiencySpray;

/// What a detected outline covers.
enum VegetationClass {
  /// Lawns and other smooth, light green cover (sprays and rotors).
  turf,

  /// Trees, shrubs and planted beds: dark, rough canopy (drip, bubblers).
  trees,

  /// Every kind of vegetation as one class (the split turned off).
  vegetation,
}

/// Settings of [detectVegetation]. The defaults suit gardens, parks and
/// sports grounds seen at 5–30 cm per pixel.
class VegetationOptions {
  VegetationOptions({
    this.thresholdOffset = 0,
    this.split = true,
    this.keepTurf = true,
    this.keepTrees = true,
    this.treeBias = 0,
    this.minAreaM2 = 5,
    this.minHoleM2 = 4,
    this.simplifyM = 0.25,
    this.smoothing = 2,
    this.cleanM = 0.2,
    this.canopyCleanM = 0.3,
    this.maxPatches = 400,
  });

  /// Added to the automatic (Otsu) threshold of the vegetation index (ExG):
  /// negative takes in paler, drier or shaded green, positive keeps only
  /// lush green.
  double thresholdOffset;

  /// Whether trees and shrubs are told apart from turf; otherwise every
  /// outline is [VegetationClass.vegetation] and the keep flags are ignored.
  bool split;
  bool keepTurf;
  bool keepTrees;

  /// Shifts the limit of the canopy score: negative calls more pixels trees
  /// and shrubs, positive fewer.
  double treeBias;

  /// Patches smaller than this are left out (m²).
  double minAreaM2;

  /// Holes smaller than this are covered by the patch round them (m²).
  double minHoleM2;

  /// Douglas–Peucker tolerance (m); 0 keeps every boundary vertex.
  double simplifyM;

  /// Taubin smoothing passes over the pixel boundary before the
  /// simplification (0 = the raw marching squares outline).
  int smoothing;

  /// Radius of the majority filter of the vegetation mask (m): specks and
  /// lines narrower than about this go, gaps as narrow close.
  double cleanM;

  /// Radius of the majority filter of the canopy mask (m).
  double canopyCleanM;

  /// Most patches traced, the largest first.
  int maxPatches;

  VegetationOptions copy() => VegetationOptions(
    thresholdOffset: thresholdOffset,
    split: split,
    keepTurf: keepTurf,
    keepTrees: keepTrees,
    treeBias: treeBias,
    minAreaM2: minAreaM2,
    minHoleM2: minHoleM2,
    simplifyM: simplifyM,
    smoothing: smoothing,
    cleanM: cleanM,
    canopyCleanM: canopyCleanM,
    maxPatches: maxPatches,
  );

  /// Sums up the settings (a result is computed again when this changes).
  String get key => [thresholdOffset, split, keepTurf, keepTrees, treeBias, minAreaM2, minHoleM2, simplifyM, smoothing, cleanM, canopyCleanM, maxPatches].join('|');
}

/// The image analysed: the working raster with the vegetation index of every
/// pixel and the automatic threshold, ready for any number of
/// [detectVegetation] runs with different settings.
class VegetationImage {
  VegetationImage._(this.width, this.height, this.corners, this.rgb, this.valid, this.index, this.luma, this.validCount, this.pixelAreaM2, this.otsuThreshold, this.separability);

  /// Most pixels of the working raster (about 1100 × 1100): the whole
  /// pipeline runs in a fraction of a second, also in a phone's browser.
  static const defaultMaxPixels = 1200000;

  /// Finest ground resolution kept (m per pixel).
  static const defaultMinPixelM = 0.05;

  /// Range of the automatic threshold (ExG): below it grey and brown surfaces
  /// with a colour cast pass for vegetation, above it pale lawns are lost.
  static const autoThresholdRange = (0.04, 0.20);

  /// Added to R + G + B (0–765) in the denominator of the index.
  static const darkDamping = 30.0;

  /// Mean index above which a class of pixels is vegetation: grey, brown and
  /// sandy surfaces, even with the colour cast of a satellite mosaic, stay
  /// below (see [autoThresholdRange] and the second Otsu split).
  static const greenFloor = 0.08;

  /// The canopy score of a vegetated pixel is `share/roughShareRef +
  /// darknessWeight·(brightnessRef − brightness)/brightnessRef`, canopy
  /// above 1: `share` is the part of the brightness steps over 0.2 m in a
  /// 1 m window larger than [roughStep] times their brightness (+10), the
  /// brightness the mean luma (0–255) of the window. Mown turf scores about
  /// 0–0.3 in the sun and 0.6–0.9 in deep shade, tree crowns 1.1–1.9.
  static const roughStep = 0.1;
  static const roughShareRef = 0.4;
  static const darknessWeight = 0.3;
  static const brightnessRef = 100.0;

  final int width, height;

  /// World corners of the raster: bottom-left, bottom-right, top-right,
  /// top-left (as [ImageEntity.corners] and the base map snapshot).
  final List<Pt> corners;

  /// Colour of every pixel (R, G, B), for the preview.
  final Uint8List rgb;

  /// 1 where the pixel has data (opaque).
  final Uint8List valid;

  /// Excess green of every pixel, 3 × 3 median (−1 without data).
  final Float32List index;

  /// Brightness (luma, 0–255).
  final Float32List luma;
  final int validCount;

  /// Ground area of a pixel (m²).
  final double pixelAreaM2;

  /// Otsu's threshold of the index, before the limits.
  final double otsuThreshold;

  /// Otsu's separability (between-class over total variance, 0–1): low
  /// when vegetation and the rest have no distinct colours.
  final double separability;

  /// Ground size of a pixel (m).
  double get pixelSizeM => math.sqrt(pixelAreaM2);

  /// The threshold used with no offset: Otsu's, within [autoThresholdRange].
  double get autoThreshold => otsuThreshold.clamp(autoThresholdRange.$1, autoThresholdRange.$2).toDouble();

  /// Otsu's threshold fell outside [autoThresholdRange].
  bool get thresholdLimited => otsuThreshold < autoThresholdRange.$1 || otsuThreshold > autoThresholdRange.$2;

  /// Side of the blocks a [width] × [height] image placed on [corners] is
  /// averaged in: enough to stay within [maxPixels] and no finer than
  /// [minPixelM] on the ground.
  static int blockFactor(int width, int height, List<Pt> corners, {int maxPixels = defaultMaxPixels, double minPixelM = defaultMinPixelM}) {
    if (width <= 0 || height <= 0) return 1;
    var f = math.sqrt(width * height / math.max(1, maxPixels)).ceil();
    final a = _quadArea(corners);
    if (a > 0 && minPixelM > 0) f = math.max(f, (minPixelM / math.sqrt(a / (width * height))).round());
    return math.max(1, math.min(f, math.min(width, height)));
  }

  /// Size of the working raster of a [width] × [height] image (to decode it
  /// straight to that size, as a browser can).
  static (int, int) workingSize(int width, int height, List<Pt> corners, {int maxPixels = defaultMaxPixels, double minPixelM = defaultMinPixelM}) {
    final f = blockFactor(width, height, corners, maxPixels: maxPixels, minPixelM: minPixelM);
    return (math.max(1, width ~/ f), math.max(1, height ~/ f));
  }

  /// Decodes a PNG, JPEG (or any format `package:image` reads) placed on
  /// [corners]. Throws `FormatException('image_unreadable')`.
  factory VegetationImage.fromEncoded(Uint8List bytes, List<Pt> corners, {int maxPixels = defaultMaxPixels, double minPixelM = defaultMinPixelM}) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) throw const FormatException('image_unreadable');
    var im = decoded;
    if (im.format != img.Format.uint8 || im.hasPalette || (im.numChannels != 3 && im.numChannels != 4)) im = im.convert(format: img.Format.uint8, numChannels: 4);
    return VegetationImage.fromPixels(im.toUint8List(), im.width, im.height, corners, channels: im.numChannels, maxPixels: maxPixels, minPixelM: minPixelM);
  }

  /// Raw 8-bit RGB ([channels] 3) or RGBA (4, alpha under 128 = no data)
  /// pixels, rows top to bottom, placed on [corners].
  factory VegetationImage.fromPixels(Uint8List data, int width, int height, List<Pt> corners, {int channels = 4, int maxPixels = defaultMaxPixels, double minPixelM = defaultMinPixelM}) {
    if (corners.length != 4) throw ArgumentError.value(corners.length, 'corners', 'four corners expected');
    if (channels != 3 && channels != 4) throw ArgumentError.value(channels, 'channels');
    if (width <= 0 || height <= 0 || data.length < width * height * channels) throw const FormatException('image_unreadable');
    final f = blockFactor(width, height, corners, maxPixels: maxPixels, minPixelM: minPixelM);
    final w = math.max(1, width ~/ f), h = math.max(1, height ~/ f);
    // the blocks cover the image but for the last f − 1 columns and rows at most
    final quad = f == 1 ? List.of(corners) : _subQuad(corners, w * f / width, h * f / height);
    final n = w * h;
    final rgb = Uint8List(3 * n), valid = Uint8List(n);
    final half = (f * f + 1) ~/ 2;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var r = 0, g = 0, b = 0, cnt = 0;
        for (var dy = 0; dy < f; dy++) {
          var p = ((y * f + dy) * width + x * f) * channels;
          for (var dx = 0; dx < f; dx++, p += channels) {
            if (channels == 4 && data[p + 3] < 128) continue;
            r += data[p];
            g += data[p + 1];
            b += data[p + 2];
            cnt++;
          }
        }
        if (cnt == 0 || cnt < half) continue;
        final i = y * w + x;
        rgb[3 * i] = (r / cnt).round();
        rgb[3 * i + 1] = (g / cnt).round();
        rgb[3 * i + 2] = (b / cnt).round();
        valid[i] = 1;
      }
    }
    return VegetationImage._analyse(w, h, quad, rgb, valid);
  }

  static VegetationImage _analyse(int w, int h, List<Pt> quad, Uint8List rgb, Uint8List valid) {
    final n = w * h;
    final raw = Float32List(n), luma = Float32List(n);
    var validCount = 0;
    for (var i = 0; i < n; i++) {
      final r = rgb[3 * i].toDouble(), g = rgb[3 * i + 1].toDouble(), b = rgb[3 * i + 2].toDouble();
      luma[i] = 0.299 * r + 0.587 * g + 0.114 * b;
      if (valid[i] == 0) continue;
      validCount++;
      final s = r + g + b + darkDamping;
      raw[i] = math.min(2 * g - r - b, 2 * (g - b)) / s;
    }
    // 3 × 3 median over the pixels with data: the noise goes, the edges stay
    // where they are (a mean would move them by up to a pixel whenever the
    // threshold is not halfway between the two surfaces either side)
    final index = Float32List(n);
    final win = Float64List(9);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (valid[i] == 0) {
          index[i] = -1;
          continue;
        }
        var c = 0;
        for (var yy = math.max(0, y - 1); yy <= math.min(h - 1, y + 1); yy++) {
          for (var xx = math.max(0, x - 1); xx <= math.min(w - 1, x + 1); xx++) {
            final j = yy * w + xx;
            if (valid[j] == 0) continue;
            // insertion into the sorted window
            final v = raw[j];
            var k = c++;
            while (k > 0 && win[k - 1] > v) {
              win[k] = win[k - 1];
              k--;
            }
            win[k] = v;
          }
        }
        index[i] = c.isOdd ? win[c ~/ 2] : (win[c ~/ 2 - 1] + win[c ~/ 2]) / 2;
      }
    }
    final (otsu, sep) = _otsu(index, valid, validCount);
    final pa = n == 0 ? 0.0 : _quadArea(quad) / n;
    return VegetationImage._(w, h, quad, rgb, valid, index, luma, validCount, pa, otsu, sep);
  }

  /// World point of the raster position ([x], [y]) (0…[width], 0…[height],
  /// y down; pixel centres at +0.5).
  Pt toWorld(double x, double y) => _bilinear(corners, x / width, y / height);

  /// Raster position (fractions of the width and height, y down) of the
  /// world point [p]: the inverse of [toWorld], for the preview.
  (double, double) toUnit(Pt p) {
    final tl = corners[3], tr = corners[2], br = corners[1], bl = corners[0];
    final a = tr - tl, b = bl - tl, c = tl - tr - bl + br, d = p - tl;
    final det = a.cross(b);
    if (det.abs() < 1e-18) return (0, 0);
    // affine guess (exact for a parallelogram), then Newton on the bilinear map
    var u = d.cross(b) / det, v = a.cross(d) / det;
    if (c.length > 1e-9 * (a.length + b.length)) {
      for (var k = 0; k < 8; k++) {
        final f = a * u + b * v + c * (u * v) - d;
        final ju = a + c * v, jv = b + c * u;
        final j = ju.cross(jv);
        if (j.abs() < 1e-18) break;
        final du = f.cross(jv) / j, dv = ju.cross(f) / j;
        u -= du;
        v -= dv;
        if (du.abs() + dv.abs() < 1e-12) break;
      }
    }
    return (u, v);
  }
}

/// A gap inside a patch.
class VegetationHole {
  const VegetationHole(this.outline, this.area, {required this.exclusion});

  /// World metres, counter-clockwise.
  final List<Pt> outline;
  final double area;

  /// Paving, a building, water or bare ground (an exclusion of the irrigated
  /// area) rather than a patch of another class kept as an area of its own.
  final bool exclusion;
}

/// A vegetated patch found in the image.
class VegetationPatch {
  const VegetationPatch({required this.cls, required this.outline, required this.holes, required this.grossArea, required this.area, required this.meanIndex, required this.touchesEdge});
  final VegetationClass cls;

  /// Outer boundary, world metres, counter-clockwise.
  final List<Pt> outline;
  final List<VegetationHole> holes;

  /// Inside the outline (m²): what an [AreaEntity] of the outline measures.
  final double grossArea;

  /// The outline less its holes (m²).
  final double area;

  /// Mean vegetation index (ExG) of its pixels.
  final double meanIndex;

  /// Reaches the border of the image (or a part without data): the patch
  /// may go on beyond the view.
  final bool touchesEdge;
}

/// A note on a detection: `warn.<code>` with [args].
class VegetationMessage {
  const VegetationMessage(this.code, [this.args = const {}]);
  final String code;
  final Map<String, String> args;

  @override
  String toString() => args.isEmpty ? code : '$code$args';
}

/// Class of every working pixel in [VegetationResult.pixels].
abstract final class VegetationPixel {
  static const none = 0;

  /// In a turf (or, without the split, a vegetation) patch.
  static const turf = 1;
  static const trees = 2;

  /// Vegetation of no patch kept: under the minimum area or of a class
  /// turned off.
  static const leftOut = 3;
  static const noData = 4;
}

/// What [detectVegetation] found.
class VegetationResult {
  const VegetationResult({
    required this.patches,
    required this.threshold,
    required this.vegetatedFraction,
    required this.dropped,
    required this.messages,
    required this.pixels,
    required this.width,
    required this.height,
  });

  /// The patches kept, largest first.
  final List<VegetationPatch> patches;

  /// Threshold of the index used (automatic plus the offset).
  final double threshold;

  /// Share of the pixels with data that are vegetation (0–1).
  final double vegetatedFraction;

  /// Patches left out for being under the minimum area.
  final int dropped;
  final List<VegetationMessage> messages;

  /// [VegetationPixel] of every pixel of the working raster.
  final Uint8List pixels;
  final int width, height;

  Iterable<VegetationPatch> of(VegetationClass c) => patches.where((p) => p.cls == c);

  /// Net area (m²) of the patches of class [c].
  double areaOf(VegetationClass c) => of(c).fold(0.0, (s, p) => s + p.area);

  /// The holes that become exclusions.
  Iterable<VegetationHole> get exclusions => patches.expand((p) => p.holes.where((h) => h.exclusion));
}

/// Finds the vegetated patches of [im] (see the library comment). Pass
/// [georeferenced] false for an image whose scale is not known to be true
/// (areas and the minimum area then use the drawing's scale).
VegetationResult detectVegetation(VegetationImage im, VegetationOptions o, {bool georeferenced = true}) {
  final w = im.width, h = im.height, n = w * h;
  final px = im.pixelSizeM, pa = im.pixelAreaM2;
  final valid = im.valid;
  int radius(double m) => px > 0 && m > 0 ? math.min(60, (m / px).round()) : 0;
  final threshold = im.autoThreshold + o.thresholdOffset;

  // vegetation mask
  var v = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (valid[i] != 0 && im.index[i] > threshold) v[i] = 1;
  }
  v = _majority(v, valid, w, h, radius(o.cleanM));
  var vegCount = 0;
  for (var i = 0; i < n; i++) {
    if (valid[i] == 0) {
      v[i] = 0;
    } else if (v[i] != 0) {
      vegCount++;
    }
  }

  // classes kept, each a mask
  final kept = <(VegetationClass, Uint8List)>[];
  if (!o.split) {
    kept.add((VegetationClass.vegetation, v));
  } else {
    // the majority among the vegetated pixels only: at the rim of a crown on
    // paving the window is half paving, which is neither canopy nor turf
    final t = _majority(_canopy(im, v, o.treeBias), v, w, h, radius(o.canopyCleanM));
    final g = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (v[i] == 0) {
        t[i] = 0;
      } else if (t[i] == 0) {
        g[i] = 1;
      }
    }
    if (o.keepTurf) kept.add((VegetationClass.turf, g));
    if (o.keepTrees) kept.add((VegetationClass.trees, t));
  }

  // patches of every class: components over the minimum area (a patch of a
  // few pixels has no outline worth drawing, whatever the minimum area; nor
  // is a speck under a quarter of a square metre worth counting)
  final minPx = math.max(4.0, pa > 0 ? o.minAreaM2 / pa : 0.0);
  final speckPx = math.max(4.0, pa > 0 ? 0.25 / pa : 0.0);
  var dropped = 0;
  final comps = <_Regions>[];
  for (final (_, m) in kept) {
    final r = _regions(m, w, h, valid, eight: true);
    for (var k = 0; k < r.length; k++) {
      if (r.count[k] >= minPx) continue;
      if (r.count[k] >= speckPx) dropped++;
      r.keep[k] = false;
    }
    for (var i = 0; i < n; i++) {
      final l = r.label[i];
      if (l > 0 && !r.keep[l - 1]) {
        m[i] = 0;
        r.label[i] = 0;
      }
    }
    comps.add(r);
  }

  // holes of every patch, and the outlines
  final minHolePx = pa > 0 ? o.minHoleM2 / pa : 0.0;
  final candidates = <(int, int, VegetationClass, double)>[]; // class index, component, class, area
  final holesOf = <List<List<(int, bool)>>>[];
  final bgOf = <_Regions>[];
  for (var c = 0; c < kept.length; c++) {
    final m = kept[c].$2, r = comps[c];
    final inside = Uint8List(n), other = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (valid[i] != 0 && m[i] == 0) inside[i] = 1;
    }
    for (var d = 0; d < kept.length; d++) {
      if (d == c) continue;
      final md = kept[d].$2;
      for (var i = 0; i < n; i++) {
        if (md[i] != 0) other[i] = 1;
      }
    }
    final bg = _regions(inside, w, h, valid, eight: false);
    final otherCount = Int32List(bg.length);
    for (var i = 0; i < n; i++) {
      final l = bg.label[i];
      if (l > 0 && other[i] != 0) otherCount[l - 1]++;
    }
    final holes = List.generate(r.length, (_) => <(int, bool)>[]);
    for (var k = 0; k < bg.length; k++) {
      if (bg.edge[k] || bg.count[k] < minHolePx || bg.count[k] == 0) continue;
      final above = bg.first[k] - w;
      if (above < 0) continue;
      final owner = r.label[above];
      if (owner <= 0) continue;
      holes[owner - 1].add((k, otherCount[k] < 0.9 * bg.count[k]));
    }
    holesOf.add(holes);
    bgOf.add(bg);
    for (var k = 0; k < r.length; k++) {
      if (r.keep[k]) candidates.add((c, k, kept[c].$1, r.count[k] * pa));
    }
  }
  candidates.sort((a, b) => b.$4.compareTo(a.$4));
  final messages = <VegetationMessage>[];
  if (candidates.length > o.maxPatches) messages.add(VegetationMessage('veg_tooMany', {'n': '${candidates.length}', 'max': '${o.maxPatches}'}));
  final traced = candidates.take(math.max(0, o.maxPatches)).toList();

  final sums = [for (var c = 0; c < kept.length; c++) Float64List(comps[c].length)];
  for (var c = 0; c < kept.length; c++) {
    final l = comps[c].label, s = sums[c];
    for (var i = 0; i < n; i++) {
      if (l[i] > 0) s[l[i] - 1] += im.index[i];
    }
  }
  final patches = <VegetationPatch>[];
  final shown = [for (var c = 0; c < kept.length; c++) Uint8List(comps[c].length)];
  var edgePatches = 0;
  for (final (c, k, cls, _) in traced) {
    final r = comps[c], bg = bgOf[c];
    final id = k + 1;
    final first = r.first[k];
    final outline = _ring(im, rasterRegionOutline(w, h, (i) => r.label[i] == id, first % w, first ~/ w, eightConnected: true), o);
    if (outline.length < 3) continue;
    final holes = <VegetationHole>[];
    for (final (hk, exclusion) in holesOf[c][k]) {
      final hid = hk + 1, hf = bg.first[hk];
      final ring = _ring(im, rasterRegionOutline(w, h, (i) => bg.label[i] == hid, hf % w, hf ~/ w, eightConnected: false), o);
      if (ring.length >= 3) holes.add(VegetationHole(ring, polygonArea(ring).abs(), exclusion: exclusion));
    }
    final gross = polygonArea(outline).abs();
    final net = math.max(0.0, gross - holes.fold(0.0, (s, x) => s + x.area));
    if (r.edge[k]) edgePatches++;
    shown[c][k] = 1;
    patches.add(VegetationPatch(cls: cls, outline: outline, holes: holes, grossArea: gross, area: net, meanIndex: sums[c][k] / r.count[k], touchesEdge: r.edge[k]));
  }

  // class of every pixel, for the preview
  final pixels = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (valid[i] == 0) {
      pixels[i] = VegetationPixel.noData;
    } else if (v[i] != 0) {
      pixels[i] = VegetationPixel.leftOut;
    }
  }
  for (var c = 0; c < kept.length; c++) {
    final code = kept[c].$1 == VegetationClass.trees ? VegetationPixel.trees : VegetationPixel.turf;
    final l = comps[c].label, s = shown[c];
    for (var i = 0; i < n; i++) {
      if (l[i] > 0 && s[l[i] - 1] != 0) pixels[i] = code;
    }
  }

  // notes
  final vegFraction = im.validCount == 0 ? 0.0 : vegCount / im.validCount;
  if (!georeferenced) messages.add(const VegetationMessage('veg_noGeoref'));
  if (w < 48 || h < 48) messages.add(VegetationMessage('veg_imageSmall', {'w': '$w', 'h': '$h'}));
  if (px > 1) messages.add(VegetationMessage('veg_coarse', {'m': px.toStringAsFixed(1)}));
  final noData = n == 0 ? 1.0 : 1 - im.validCount / n;
  if (noData > 0.2) messages.add(VegetationMessage('veg_noData', {'p': (100 * noData).toStringAsFixed(0)}));
  if (im.validCount > 0) {
    if (vegFraction < 0.01) {
      messages.add(const VegetationMessage('veg_fewPixels'));
    } else if (vegFraction > 0.9) {
      messages.add(const VegetationMessage('veg_mostlyGreen'));
    }
    // Otsu splitting the grey of the paving, or two modes hardly apart (a
    // threshold limited from above only means lush green)
    if (im.separability < 0.45 || im.otsuThreshold < VegetationImage.autoThresholdRange.$1) messages.add(const VegetationMessage('veg_lowContrast'));
  }
  if (edgePatches > 0) messages.add(VegetationMessage('veg_edge', {'n': '$edgePatches'}));
  return VegetationResult(patches: patches, threshold: threshold, vegetatedFraction: vegFraction, dropped: dropped, messages: messages, pixels: pixels, width: w, height: h);
}

/// Agronomic starting values of an irrigated area of class [c]. Turf: Kc
/// 0.85 (FAO-56 table 12, warm-season turf at mid season), a 0.3 m root
/// zone, sprinklers at the spray efficiency of the water budget, high water
/// use; trees and shrubs: Kc 0.6 (the top of the moderate water-use range of
/// the water budget), 0.4 m roots, drip at its efficiency wetting half the
/// ground, moderate water use. As the lawns and shrub beds of the garden
/// example; the user refines them in the properties.
void applyVegetationPreset(AreaEntity a, VegetationClass c) {
  switch (c) {
    case VegetationClass.turf:
      a
        ..kc = 0.85
        ..rootDepthM = 0.3
        ..efficiency = mweloEfficiencySpray
        ..irrigationMethod = 'sprinkler'
        ..plantWaterUse = 'high';
    case VegetationClass.trees:
      a
        ..kc = 0.6
        ..rootDepthM = 0.4
        ..efficiency = mweloEfficiencyDrip
        ..irrigationMethod = 'localized'
        ..wettedFraction = 0.5
        ..plantWaterUse = 'moderate';
    case VegetationClass.vegetation:
      break;
  }
}

/// The entities of [patches] for project [p]: an irrigated [AreaEntity] per
/// patch (AREAS layer, named `<name(class)> <n>`, the count going on from
/// the areas already so named, with [applyVegetationPreset]) and, when
/// [exclusions], a closed polyline on the drawing layer per hole that is an
/// exclusion, named [exclusionName] (area name, number within the area). The
/// caller adds them to the drawing (one undo step).
List<Entity> vegetationEntities(
  Project p,
  Iterable<VegetationPatch> patches, {
  required String Function(VegetationClass c) name,
  required String Function(String area, int n) exclusionName,
  bool exclusions = true,
}) {
  final out = <Entity>[];
  final last = <String, int>{};
  int highest(String base) {
    final re = RegExp('^${RegExp.escape(base)} (\\d+)\$');
    var m = 0;
    for (final e in p.entities) {
      final g = re.firstMatch(e.name.trim());
      if (g != null) m = math.max(m, int.tryParse(g.group(1)!) ?? 0);
    }
    return m;
  }

  for (final patch in patches) {
    if (patch.outline.length < 3) continue;
    final base = name(patch.cls);
    final k = last[base] = (last[base] ?? highest(base)) + 1;
    final a = AreaEntity(id: p.newId(), points: List.of(patch.outline), name: '$base $k', crop: base);
    applyVegetationPreset(a, patch.cls);
    out.add(a);
    if (!exclusions) continue;
    var j = 0;
    for (final hole in patch.holes) {
      if (!hole.exclusion || hole.outline.length < 3) continue;
      out.add(PolylineEntity(id: p.newId(), layer: Layers.drawing, points: List.of(hole.outline), closed: true, name: exclusionName(a.name, ++j)));
    }
  }
  if (out.isNotEmpty) p.layerNamed(Layers.areas);
  if (out.any((e) => e is PolylineEntity)) p.layerNamed(Layers.drawing);
  return out;
}

/// The working raster tinted by class, as RGBA rows of at most [maxSide]
/// pixels a side: lawns light green, trees and shrubs dark green,
/// vegetation left out yellow, no data dark grey.
(Uint8List, int, int) vegetationPreview(VegetationImage im, VegetationResult r, {int maxSide = 560}) {
  final step = math.max(1, (math.max(im.width, im.height) / math.max(1, maxSide)).ceil());
  final w = math.max(1, im.width ~/ step), h = math.max(1, im.height ~/ step);
  final out = Uint8List(4 * w * h);
  const tints = <int, (int, int, int)>{VegetationPixel.turf: (124, 255, 92), VegetationPixel.trees: (0, 150, 110), VegetationPixel.leftOut: (255, 214, 64), VegetationPixel.noData: (40, 44, 50)};
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * step) * im.width + x * step, o = 4 * (y * w + x);
      var red = im.rgb[3 * i], green = im.rgb[3 * i + 1], blue = im.rgb[3 * i + 2];
      final cls = r.pixels.length == im.width * im.height ? r.pixels[i] : VegetationPixel.none;
      final tint = tints[cls];
      if (tint != null) {
        final a = cls == VegetationPixel.noData ? 1.0 : 0.5;
        red = (red * (1 - a) + tint.$1 * a).round();
        green = (green * (1 - a) + tint.$2 * a).round();
        blue = (blue * (1 - a) + tint.$3 * a).round();
      }
      out[o] = red;
      out[o + 1] = green;
      out[o + 2] = blue;
      out[o + 3] = 255;
    }
  }
  return (out, w, h);
}

// ---------------------------------------------------------------- raster helpers

double _quadArea(List<Pt> q) => q.length == 4 ? polygonArea(q).abs() : 0;

/// Bilinear map of the unit square onto [q] (bottom-left, bottom-right,
/// top-right, top-left) with v measured down from the top edge.
Pt _bilinear(List<Pt> q, double u, double v) {
  final tl = q[3], tr = q[2], br = q[1], bl = q[0];
  final top = tl + (tr - tl) * u, bottom = bl + (br - bl) * u;
  return top + (bottom - top) * v;
}

/// The part of [q] from its top-left corner to the fractions [u], [v] of
/// its sides, in the same corner order.
List<Pt> _subQuad(List<Pt> q, double u, double v) => [_bilinear(q, 0, v), _bilinear(q, u, v), _bilinear(q, u, 0), _bilinear(q, 0, 0)];

/// Otsu's threshold of the index over the pixels with data and its
/// separability (Otsu's measure: between-class over total variance of the
/// first split, 0–1). When the class below that split is green itself — a
/// park, a golf course or a pitch filling the view, two shades of grass
/// split from each other — Otsu again below it finds the paving, sand or
/// soil if there is any; if there is none (all lawn), the lower limit of the
/// range. Between two separate modes the threshold is the middle of the
/// empty stretch (every split there is as good).
(double, double) _otsu(Float32List index, Uint8List valid, int count) {
  const bins = 400, lo = -1.0, hi = 1.0;
  if (count == 0) return (0.1, 0);
  final hist = Float64List(bins);
  for (var i = 0; i < index.length; i++) {
    if (valid[i] == 0) continue;
    hist[((index[i] - lo) / (hi - lo) * bins).floor().clamp(0, bins - 1)]++;
  }
  double centre(int k) => lo + (k + 0.5) * (hi - lo) / bins;
  double edge(int k) => lo + (k + 1) * (hi - lo) / bins;
  // Otsu over the bins below [end]: the last bin of the lower class, its
  // mean and the separability
  (int, double, double) split(int end) {
    var n = 0.0, sum = 0.0, sum2 = 0.0;
    for (var k = 0; k < end; k++) {
      final c = centre(k);
      n += hist[k];
      sum += hist[k] * c;
      sum2 += hist[k] * c * c;
    }
    var w0 = 0.0, s0 = 0.0, best = -1.0, at = -1, last = -1;
    for (var k = 0; k < end - 1; k++) {
      w0 += hist[k];
      s0 += hist[k] * centre(k);
      final w1 = n - w0;
      if (w0 == 0 || w1 == 0) continue;
      final m0 = s0 / w0, m1 = (sum - s0) / w1;
      final between = w0 * w1 * (m0 - m1) * (m0 - m1);
      if (between > best * (1 + 1e-9)) {
        best = between;
        at = last = k;
      } else if (between >= best * (1 - 1e-9)) {
        last = k; // the same split across an empty stretch of the histogram
      }
    }
    if (at < 0 || n == 0) return (-1, 0, 0);
    final total = sum2 / n - (sum / n) * (sum / n);
    at = (at + last) ~/ 2;
    var c0 = 0.0, a0 = 0.0;
    for (var k = 0; k <= at; k++) {
      c0 += hist[k];
      a0 += hist[k] * centre(k);
    }
    return (at, c0 > 0 ? a0 / c0 : 0, total > 1e-12 ? (best / (n * n) / total).clamp(0.0, 1.0) : 0);
  }

  final (at, m0, separability) = split(bins);
  var t = at < 0 ? 0.1 : edge(at);
  if (at >= 0 && m0 > VegetationImage.greenFloor) {
    final (at2, m00, _) = split(at + 1);
    t = at2 >= 0 && m00 < VegetationImage.greenFloor ? edge(at2) : VegetationImage.autoThresholdRange.$1;
  }
  return (t, separability);
}

/// Canopy among the vegetated pixels [v]: the share of large relative
/// brightness steps plus the darkness, over the vegetated pixels of a window
/// of about 1 m (see the library comment, step 5).
Uint8List _canopy(VegetationImage im, Uint8List v, double bias) {
  final w = im.width, h = im.height, n = w * h, l = im.luma;
  final px = im.pixelSizeM > 0 ? im.pixelSizeM : 0.1;
  final step = math.max(1, (0.2 / px).round());
  final r = (0.5 / px).round().clamp(1, 12);
  final cnt = Float32List(n), sl = Float32List(n), big = Float32List(n), steps = Float32List(n);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (v[i] == 0) continue;
      cnt[i] = 1;
      final li = l[i];
      sl[i] = li;
      var s = 0, b = 0;
      if (x + step < w && v[i + step] != 0) {
        final lj = l[i + step];
        s++;
        if ((li - lj).abs() > VegetationImage.roughStep * ((li + lj) / 2 + 10)) b++;
      }
      if (y + step < h && v[i + step * w] != 0) {
        final lj = l[i + step * w];
        s++;
        if ((li - lj).abs() > VegetationImage.roughStep * ((li + lj) / 2 + 10)) b++;
      }
      steps[i] = s.toDouble();
      big[i] = b.toDouble();
    }
  }
  final c = _boxSum(cnt, w, h, r), s1 = _boxSum(sl, w, h, r), s2 = _boxSum(big, w, h, r), s3 = _boxSum(steps, w, h, r);
  final out = Uint8List(n);
  final limit = 1 + bias;
  for (var i = 0; i < n; i++) {
    if (v[i] == 0 || c[i] <= 0) continue;
    final share = s3[i] > 0 ? s2[i] / s3[i] : 0.0;
    final dark = (VegetationImage.brightnessRef - s1[i] / c[i]) / VegetationImage.brightnessRef;
    if (share / VegetationImage.roughShareRef + VegetationImage.darknessWeight * dark > limit) out[i] = 1;
  }
  return out;
}

/// Sums of [a] over the (2[r] + 1)² window round every pixel (clipped at the
/// border): two running sums, rows then columns.
Float32List _boxSum(Float32List a, int w, int h, int r) {
  final tmp = Float32List(w * h), out = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var s = 0.0;
    for (var x = 0; x < math.min(r, w); x++) {
      s += a[row + x];
    }
    for (var x = 0; x < w; x++) {
      if (x + r < w) s += a[row + x + r];
      if (x - r - 1 >= 0) s -= a[row + x - r - 1];
      tmp[row + x] = s;
    }
  }
  for (var x = 0; x < w; x++) {
    var s = 0.0;
    for (var y = 0; y < math.min(r, h); y++) {
      s += tmp[y * w + x];
    }
    for (var y = 0; y < h; y++) {
      if (y + r < h) s += tmp[(y + r) * w + x];
      if (y - r - 1 >= 0) s -= tmp[(y - r - 1) * w + x];
      out[y * w + x] = s;
    }
  }
  return out;
}

/// Majority filter of the mask [m]: a pixel with data is set when more than
/// half of the pixels with data of the (2[r] + 1)² window round it are (box
/// sums, linear time whatever the radius). Windows are clipped at the border
/// of the image, so a patch cut by the view keeps its straight edge.
Uint8List _majority(Uint8List m, Uint8List valid, int w, int h, int r) {
  if (r <= 0) return m;
  final n = w * h;
  final set = Float32List(n), data = Float32List(n);
  for (var i = 0; i < n; i++) {
    if (m[i] != 0) set[i] = 1;
    if (valid[i] != 0) data[i] = 1;
  }
  final s = _boxSum(set, w, h, r), c = _boxSum(data, w, h, r);
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (valid[i] != 0 && 2 * s[i] > c[i] + 1e-3) out[i] = 1;
  }
  return out;
}

/// Connected regions of the pixels where [inside] is set.
class _Regions {
  _Regions(this.label);

  /// Region of every pixel (1-based; 0 = none).
  final Int32List label;

  /// Per region (index = label − 1): pixels, first pixel in raster order,
  /// whether it reaches the border of the image or a pixel without data,
  /// whether it is kept.
  final List<int> count = [], first = [];
  final List<bool> edge = [], keep = [];
  int get length => count.length;
}

_Regions _regions(Uint8List inside, int w, int h, Uint8List valid, {required bool eight}) {
  final n = w * h;
  final out = _Regions(Int32List(n));
  final label = out.label;
  final queue = Int32List(n);
  for (var s = 0; s < n; s++) {
    if (inside[s] == 0 || label[s] != 0) continue;
    final id = out.length + 1;
    var head = 0, tail = 0;
    queue[tail++] = s;
    label[s] = id;
    var edge = false;
    while (head < tail) {
      final p = queue[head++];
      final x = p % w, y = p ~/ w;
      for (var k = 0; k < 4; k++) {
        final xx = x + (k == 0 ? -1 : (k == 1 ? 1 : 0)), yy = y + (k == 2 ? -1 : (k == 3 ? 1 : 0));
        if (xx < 0 || yy < 0 || xx >= w || yy >= h) {
          edge = true;
          continue;
        }
        final j = yy * w + xx;
        if (valid[j] == 0) edge = true;
        if (inside[j] != 0 && label[j] == 0) {
          label[j] = id;
          queue[tail++] = j;
        }
      }
      if (!eight) continue;
      for (var k = 0; k < 4; k++) {
        final xx = x + (k & 1 == 0 ? -1 : 1), yy = y + (k < 2 ? -1 : 1);
        if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
        final j = yy * w + xx;
        if (inside[j] != 0 && label[j] == 0) {
          label[j] = id;
          queue[tail++] = j;
        }
      }
    }
    out.count.add(tail);
    out.first.add(s);
    out.edge.add(edge);
    out.keep.add(true);
  }
  return out;
}

// ---------------------------------------------------------------- outlines

/// Outer boundary of a region of a [width] × [height] raster, walked by
/// marching squares over the pixel centres: a vertex at the middle of every
/// pixel edge between the region and the rest, as x, y pairs in raster
/// coordinates (x right, y down, pixel centres at +0.5; the area enclosed is
/// the pixel count less an eighth of a pixel per convex corner, plus one per
/// concave corner). [inside] tells the pixels of the region by index
/// (y·width + x); ([x0], [y0]) is its first pixel in raster order. Two region
/// pixels touching at a corner are joined when [eightConnected] (8-connected
/// patches), apart otherwise (4-connected holes), so the outlines of a patch
/// and of its holes agree and never cross. The walk starts in the cell
/// above-left of the first pixel, where only that pixel is inside, and ends
/// back there: the outer boundary, holes not included.
Float64List rasterRegionOutline(int width, int height, bool Function(int index) inside, int x0, int y0, {required bool eightConnected}) {
  final w = width, h = height, eight = eightConnected;
  bool at(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && inside(y * w + x);
  final out = <double>[];
  var cx = x0 - 1, cy = y0 - 1, entry = 2;
  final limit = 4 * (w + 2) * (h + 2);
  for (var steps = 0; steps < limit; steps++) {
    final code = (at(cx, cy) ? 8 : 0) | (at(cx + 1, cy) ? 4 : 0) | (at(cx + 1, cy + 1) ? 2 : 0) | (at(cx, cy + 1) ? 1 : 0);
    final exit = _exit(code, entry, eight);
    switch (exit) {
      case 0:
        out
          ..add(cx + 1.0)
          ..add(cy + 0.5);
        cy--;
        entry = 2;
      case 1:
        out
          ..add(cx + 1.5)
          ..add(cy + 1.0);
        cx++;
        entry = 3;
      case 2:
        out
          ..add(cx + 1.0)
          ..add(cy + 1.5);
        cy++;
        entry = 0;
      case 3:
        out
          ..add(cx + 0.5)
          ..add(cy + 1.0);
        cx--;
        entry = 1;
      default:
        return Float64List.fromList(out); // off the boundary: cannot happen
    }
    if (cx == x0 - 1 && cy == y0 - 1 && entry == 2) break;
  }
  return Float64List.fromList(out);
}

/// Side (0 top, 1 right, 2 bottom, 3 left) through which the boundary
/// leaves a cell of corner pattern [code] (8 top-left, 4 top-right, 2
/// bottom-right, 1 bottom-left inside) entered through [entry]; -1 off the
/// boundary.
int _exit(int code, int entry, bool eight) {
  switch (code) {
    case 1 || 14:
      return entry == 3 ? 2 : 3;
    case 2 || 13:
      return entry == 2 ? 1 : 2;
    case 3 || 12:
      return entry == 3 ? 1 : 3;
    case 4 || 11:
      return entry == 0 ? 1 : 0;
    case 6 || 9:
      return entry == 0 ? 2 : 0;
    case 7 || 8:
      return entry == 0 ? 3 : 0;
    case 5: // top-right and bottom-left inside
      return eight ? const [3, 2, 1, 0][entry] : const [1, 0, 3, 2][entry];
    case 10: // top-left and bottom-right inside
      return eight ? const [1, 0, 3, 2][entry] : const [3, 2, 1, 0][entry];
  }
  return -1;
}

/// World outline of the raster boundary [raw]: smoothed, simplified (the
/// tolerance halved until the polygon does not cross itself; the raw walk
/// never does) and counter-clockwise.
List<Pt> _ring(VegetationImage im, Float64List raw, VegetationOptions o) {
  final pts = <Pt>[for (var k = 0; k + 1 < raw.length; k += 2) im.toWorld(raw[k], raw[k + 1])];
  if (pts.length < 3) return const [];
  final smooth = _taubin(pts, o.smoothing);
  final target = polygonArea(smooth).abs();
  List<Pt>? best;
  final floor = 0.25 * im.pixelSizeM;
  for (var tol = o.simplifyM; tol > floor; tol /= 2) {
    final s = _keepArea(_simplifyRing(smooth, tol), target);
    if (s.length >= 3 && _simple(s)) {
      best = s;
      break;
    }
  }
  best ??= _simple(smooth) ? smooth : pts;
  return polygonArea(best) < 0 ? best.reversed.toList() : best;
}

/// [p] moved out (or in) along its edges' normals by the area it lacks
/// against [target] over its perimeter: Douglas–Peucker keeps vertices of the
/// outline, so its chords cut the rounded corners and the bends and the
/// polygon comes out a fraction of a pixel smaller all round (about 2 % of a
/// lawn of 400 m²); the offset gives that area back.
List<Pt> _keepArea(List<Pt> p, double target) {
  final n = p.length;
  if (n < 3) return p;
  final a = polygonArea(p);
  var perimeter = 0.0;
  for (var i = 0; i < n; i++) {
    perimeter += p[i].distanceTo(p[(i + 1) % n]);
  }
  if (perimeter <= 0 || a == 0) return p;
  final d = (target - a.abs()) / perimeter;
  if (d.abs() < 1e-9) return p;
  final sign = a > 0 ? 1.0 : -1.0;
  return [
    for (var i = 0; i < n; i++)
      () {
        final prev = p[(i + n - 1) % n], cur = p[i], next = p[(i + 1) % n];
        final e1 = (cur - prev).normalized, e2 = (next - cur).normalized;
        // outward normals (right of the edges of a counter-clockwise polygon)
        final n1 = Pt(e1.y, -e1.x) * sign, n2 = Pt(e2.y, -e2.x) * sign;
        final den = 1 + n1.dot(n2);
        return cur + (den < 0.25 ? (n1 + n2).normalized * d : (n1 + n2) * (d / den));
      }(),
  ];
}

/// Taubin's λ|μ smoothing of a closed ring (λ = 0.5, μ = −0.53): the
/// staircase of the pixels goes, the area stays.
List<Pt> _taubin(List<Pt> p, int passes) {
  if (passes <= 0 || p.length < 8) return p;
  var a = p;
  for (var k = 0; k < passes; k++) {
    a = _laplace(_laplace(a, 0.5), -0.53);
  }
  return a;
}

List<Pt> _laplace(List<Pt> p, double f) {
  final n = p.length;
  return [for (var i = 0; i < n; i++) p[i] + ((p[(i + n - 1) % n] + p[(i + 1) % n]) * 0.5 - p[i]) * f];
}

/// Douglas–Peucker on a closed ring, split at the vertex farthest from the
/// first one and at the vertex farthest from that; at least four vertices
/// stay (a patch smaller than the tolerance keeps its extremes).
List<Pt> _simplifyRing(List<Pt> p, double tol) {
  final n = p.length;
  if (tol <= 0 || n <= 4) return p;
  var a = 0, far = -1.0;
  for (var i = 0; i < n; i++) {
    final d = p[i].distanceTo(p[0]);
    if (d > far) {
      far = d;
      a = i;
    }
  }
  var b = a;
  far = -1;
  for (var i = 0; i < n; i++) {
    final d = p[i].distanceTo(p[a]);
    if (d > far) {
      far = d;
      b = i;
    }
  }
  if (a == b) return p;
  final keep = Uint8List(n);
  keep[a] = 1;
  keep[b] = 1;
  for (final (s, e) in [(a, b), (b, a)]) {
    _dp(p, s, e, tol, keep);
    if (keep.where((k) => k != 0).length < 4) _dp(p, s, e, 0, keep, once: true);
  }
  return [
    for (var i = 0; i < n; i++)
      if (keep[i] != 0) p[i],
  ];
}

/// Marks the vertices Douglas–Peucker keeps between [s] and [e] (forward,
/// wrapping); with [once], only the farthest one.
void _dp(List<Pt> p, int s, int e, double tol, Uint8List keep, {bool once = false}) {
  final n = p.length;
  final stack = <int>[s, e];
  while (stack.isNotEmpty) {
    final end = stack.removeLast(), start = stack.removeLast();
    var best = -1;
    var dmax = tol;
    for (var k = (start + 1) % n; k != end; k = (k + 1) % n) {
      final d = distanceToSegment(p[k], p[start], p[end]);
      if (d > dmax) {
        dmax = d;
        best = k;
      }
    }
    if (best < 0) continue;
    keep[best] = 1;
    if (once) return;
    stack
      ..add(start)
      ..add(best)
      ..add(best)
      ..add(end);
  }
}

/// Whether the closed ring [p] does not cross itself (checked up to 1500
/// vertices; longer rings come from the walk, which never crosses).
bool _simple(List<Pt> p) {
  final n = p.length;
  if (n < 3) return false;
  if (n > 1500) return true;
  final minX = Float64List(n), maxX = Float64List(n), minY = Float64List(n), maxY = Float64List(n);
  for (var i = 0; i < n; i++) {
    final a = p[i], b = p[(i + 1) % n];
    minX[i] = math.min(a.x, b.x);
    maxX[i] = math.max(a.x, b.x);
    minY[i] = math.min(a.y, b.y);
    maxY[i] = math.max(a.y, b.y);
  }
  for (var i = 0; i < n; i++) {
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue;
      if (minX[j] > maxX[i] || maxX[j] < minX[i] || minY[j] > maxY[i] || maxY[j] < minY[i]) continue;
      if (segmentIntersection(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n]) != null) return false;
    }
  }
  return true;
}
